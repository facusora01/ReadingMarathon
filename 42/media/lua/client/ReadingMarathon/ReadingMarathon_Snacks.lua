-- ============================================================
--  Reading Marathon v1.0 - Build 42
--  Que cuenta como "snack" y como se elige uno del inventario.
-- ============================================================

ReadingMarathon = ReadingMarathon or {}
local RM = ReadingMarathon

-- Cualquier comida con estos FoodType cuenta como snack (todos los caramelos
-- y chocolates del juego usan Candy).
RM.SNACK_FOODTYPES = {
    ["Candy"] = true,
    ["Chocolate"] = true,
}

-- Lista blanca por tipo de item. Otros mods pueden agregar entradas:
--   ReadingMarathon.SNACK_TYPES["Base.MiSnack"] = true
RM.SNACK_TYPES = {}
local function addSnacks(list)
    for _, name in ipairs(list) do
        RM.SNACK_TYPES["Base." .. name] = true
    end
end

-- Papas fritas, galletitas, snacks salados
addSnacks({
    "Crisps", "Crisps2", "Crisps3", "Crisps4",
    "TortillaChips", "TortillaChipsBaked",
    "Crackers", "GrahamCrackers", "Pretzel", "Popcorn",
    "Peanuts", "GranolaBar", "BeefJerky", "DehydratedMeatStick",
})

-- Dulces, chocolates y galletitas dulces
addSnacks({
    "Chocolate", "Chocolate_HeartBox", "ChocolateCoveredCoffeeBeans",
    "CookieChocolateChip", "CookieJelly", "CookiesChocolate",
    "CookiesOatmeal", "CookiesShortbread", "CookiesSugar", "ScoutCookies",
    "Biscuit", "CrispyRiceSquare", "LemonBar", "ChocoCakes", "Cupcake",
    "QuaggaCakes", "Marshmallows", "Lollipop", "Painauchocolat",
    "DoughnutChocolate", "DoughnutFrosted", "DoughnutJelly", "DoughnutPlain",
    "MuffinFruit", "MuffinGeneric", "FudgeePop", "Popsicle",
})

local function safeBool(item, method)
    local ok, val = pcall(function() return item[method](item) end)
    return ok and val == true
end

function RM.isSnack(item)
    if not item then return false end
    if not instanceof(item, "Food") then return false end
    if safeBool(item, "isRotten") then return false end
    if safeBool(item, "isFrozen") then return false end
    if item:getHungerChange() >= 0 then return false end

    if RM.SNACK_TYPES[item:getFullType()] then return true end

    local ok, foodType = pcall(function() return item:getFoodType() end)
    if ok and foodType and RM.SNACK_FOODTYPES[foodType] then return true end

    return false
end

-- Elige el snack mas contundente disponible, asi corta la lectura lo menos
-- posible.
function RM.findSnack(playerObj)
    local best, bestScore = nil, nil
    RM.forEachInventoryItem(playerObj, function(item)
        if not RM.isSnack(item) then return end
        local score = -item:getHungerChange()
        if not best or score > bestScore then
            best, bestScore = item, score
        end
    end)
    return best
end

-- B42 usa getStats():get(CharacterStat.HUNGER); getHunger() queda de respaldo.
function RM.getHunger(playerObj)
    local stats = playerObj:getStats()
    local ok, value = pcall(function() return stats:get(CharacterStat.HUNGER) end)
    if ok and value then return value end
    ok, value = pcall(function() return stats:getHunger() end)
    if ok and value then return value end
    return 0
end

-- ---------- Agua ----------

-- Un envase del que se pueda beber ya mismo: agua no contaminada y con algo
-- adentro. ISDrinkFromBottle necesita si o si un fluid container.
function RM.isDrinkableWater(item)
    if not item then return false end

    local container = item:getFluidContainer()
    if not container then return false end

    -- FluidContainer:isFilledWithCleanWater() ya cubre agua + no vacio + no
    -- contaminada, que es exactamente lo que hace falta.
    local ok, clean = pcall(function() return container:isFilledWithCleanWater() end)
    if ok and clean ~= nil then return clean == true end

    -- Respaldo por si esa API no esta.
    local okWater, isWater = pcall(function() return item:isWaterSource() end)
    if not okWater or not isWater then return false end

    local okEmpty, empty = pcall(function() return container:isEmpty() end)
    if not okEmpty or empty then return false end

    local okTainted, tainted = pcall(function() return container:isTainted() end)
    if okTainted and tainted then return false end

    return true
end

-- Elige el envase con menos agua, para ir vaciando los que estan por la mitad.
function RM.findWater(playerObj)
    local best, bestAmount = nil, nil
    RM.forEachInventoryItem(playerObj, function(item)
        if not RM.isDrinkableWater(item) then return end
        -- getAmount(), no getFluidAmount(): eso ultimo es de Resource, no de
        -- FluidContainer, y devolvia nil silenciosamente dentro del pcall.
        local ok, amount = pcall(function() return item:getFluidContainer():getAmount() end)
        if not ok or not amount then return end
        if not best or amount < bestAmount then
            best, bestAmount = item, amount
        end
    end)
    return best
end

function RM.getThirst(playerObj)
    local ok, value = pcall(function()
        return playerObj:getStats():get(CharacterStat.THIRST)
    end)
    if ok and value then return value end
    return 0
end

function RM.shouldDrink(playerObj)
    return RM.getThirst(playerObj) >= RM.thirstThreshold
end

-- Cuanto tomar: lo justo para la sed, como hace el menu del juego.
function RM.getDrinkPercent(playerObj, waterItem)
    local ok, percent = pcall(function()
        local available = waterItem:getFluidContainer():getAmount()
        if available <= 0 then return 1 end
        local units = math.min(RM.getThirst(playerObj) * 2, available)
        return units / available
    end)
    if ok and percent and percent > 0 then return percent end
    return 1
end

-- ---------- Decision ----------

function RM.shouldEat(playerObj)
    if RM.getHunger(playerObj) < RM.hungerThreshold then return false end
    -- No comer si ya esta lleno (el juego bloquea la accion igual).
    if playerObj:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 then return false end
    return true
end

-- Que necesita el personaje ahora mismo: "drink" | "eat" | nil.
-- La sed va primero porque aprieta mas rapido que el hambre.
function RM.getPendingNeed(playerObj, session)
    if session.drinkFails < RM.maxNeedFails and RM.shouldDrink(playerObj) then
        local water = RM.findWater(playerObj)
        if water then return "drink", water end
    end
    if session.eatFails < RM.maxNeedFails and RM.shouldEat(playerObj) then
        local snack = RM.findSnack(playerObj)
        if snack then return "eat", snack end
    end
    return nil, nil
end
