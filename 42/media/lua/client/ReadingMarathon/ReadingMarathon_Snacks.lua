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

-- ---------- Decision ----------

-- El agua la maneja el juego: el motor tiene autoDrink() y la opcion
-- "Auto Drink", que bebe sin cortar la accion en curso. El mod solo come.
function RM.shouldEat(playerObj)
    if RM.getHunger(playerObj) < RM.hungerThreshold then return false end
    -- No comer si ya esta lleno (el juego bloquea la accion igual).
    if playerObj:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 then return false end
    return true
end

-- Que snack conviene comer ahora, si hace falta alguno.
function RM.getPendingSnack(playerObj, session)
    if session.eatFails >= RM.maxNeedFails then return nil end
    if not RM.shouldEat(playerObj) then return nil end
    return RM.findSnack(playerObj)
end
