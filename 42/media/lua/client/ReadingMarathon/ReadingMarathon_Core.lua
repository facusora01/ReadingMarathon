-- ============================================================
--  Reading Marathon v1.0 - Build 42
--  Estado, deteccion de sillon y utilidades compartidas.
-- ============================================================

ReadingMarathon = ReadingMarathon or {}
local RM = ReadingMarathon

RM.VERSION = "1.0"

-- ---------- Configuracion (editable) ----------
-- Hambre (0..1) a partir de la cual el personaje come un snack.
-- 0.22 ~ moodle "Peckish".
RM.hungerThreshold = 0.22
-- Si es false, vale cualquier asiento (sillas de cocina, bancos, etc).
RM.requireComfySeat = true
-- Cada cuantos ticks se revisa el estado de la maraton.
RM.checkEveryTicks = 10
-- Cuantos intentos fallidos de comer antes de dejar de intentarlo.
RM.maxEatFails = 3

-- Sesiones activas por numero de jugador: [playerNum] = { ... }
RM.sessions = {}

-- ---------- Helpers ----------

-- Lee una propiedad del sprite de un IsoObject sin romperse si no existe.
function RM.getObjectProp(obj, key)
    if not obj then return nil end
    local ok, val = pcall(function()
        local props = obj:getProperties()
        if props and props:has(key) then
            return props:get(key)
        end
        return nil
    end)
    if ok then return val end
    return nil
end

-- Sillones (grandes y chicos). En B42 los sofas tienen CustomName = Couch y
-- tanto sofas como sillones individuales tienen BedType = averageBed, mientras
-- que las sillas de comedor / bancos usan badBed o badChair.
RM.COMFY_CUSTOM_NAMES = {
    ["Couch"] = true,
    ["Sofa"] = true,
    ["Armchair"] = true,
    ["Loveseat"] = true,
}

function RM.isComfySeat(obj)
    if not obj then return false end

    local customName = RM.getObjectProp(obj, "CustomName")
    if customName and RM.COMFY_CUSTOM_NAMES[customName] then return true end

    if RM.getObjectProp(obj, "BedType") == "averageBed" then return true end

    -- Ultimo recurso para muebles de otros mods: el nombre del sprite.
    local ok, spriteName = pcall(function()
        local sprite = obj:getSprite()
        return sprite and sprite:getName() or nil
    end)
    if ok and spriteName then
        spriteName = string.lower(spriteName)
        if string.find(spriteName, "sofa", 1, true)
        or string.find(spriteName, "couch", 1, true)
        or string.find(spriteName, "armchair", 1, true) then
            return true
        end
    end

    return false
end

function RM.getSeat(playerObj)
    if not playerObj then return nil end
    if not playerObj:isSittingOnFurniture() then return nil end
    return playerObj:getSitOnFurnitureObject()
end

-- Devuelve: ok, motivo ("notSitting" | "notCouch")
function RM.canStart(playerObj)
    local seat = RM.getSeat(playerObj)
    if not seat then return false, "notSitting" end
    if RM.requireComfySeat and not RM.isComfySeat(seat) then return false, "notCouch" end
    return true, nil
end

-- ---------- Libros ----------

-- Mismo criterio que usa el juego para mostrar el menu "Read".
function RM.isLiteratureItem(item)
    if not item then return false end
    if item:getCategory() ~= "Literature" then return false end
    if item:canBeWrite() then return false end
    if item:hasModData() and item:getModData().printMedia then return false end
    return true
end

-- Un item se puede leer ahora mismo con provecho?
function RM.isReadableNow(playerObj, item)
    if not RM.isLiteratureItem(item) then return false end
    if item:hasTag(ItemTag.UNINTERESTING) then return false end

    local isPicture = item:hasTag(ItemTag.PICTURE) or item:hasTag(ItemTag.PICTUREBOOK)
    if playerObj:hasTrait(CharacterTrait.ILLITERATE) and not isPicture then return false end

    -- Libros de skill: ni demasiado dificiles ni ya superados.
    local skillBook = SkillBook[item:getSkillTrained()]
    if skillBook and skillBook.perk then
        local level = playerObj:getPerkLevel(skillBook.perk)
        if item:getLvlSkillTrained() ~= -1 and item:getLvlSkillTrained() > level + 1 then return false end
        if item:getMaxLevelTrained() ~= -1 and item:getMaxLevelTrained() <= level then return false end
    end

    -- Ya terminado.
    local pages = item:getNumberOfPages()
    if pages > 0 and playerObj:getAlreadyReadPages(item:getFullType()) >= pages then
        return false
    end

    -- Libro de recetas ya aprendido.
    local recipes = item:getLearnedRecipes()
    if recipes and not recipes:isEmpty() and playerObj:getAlreadyReadBook():contains(item:getFullType()) then
        return false
    end

    -- Lectura de ocio leida hace poco.
    if item:hasModData() and item:getModData().literatureTitle
    and playerObj:isLiteratureRead(item:getModData().literatureTitle) then
        return false
    end

    return true
end

-- Recorre el inventario del jugador (incluyendo bolsos) aplicando fn(item).
function RM.forEachInventoryItem(playerObj, fn)
    local visited = {}
    local function scan(container, depth)
        if not container or depth > 3 or visited[container] then return end
        visited[container] = true
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            fn(item)
            if instanceof(item, "InventoryContainer") then
                scan(item:getItemContainer(), depth + 1)
            end
        end
    end
    scan(playerObj:getInventory(), 0)
end

-- Lista de libros pendientes, ordenada: skill > recetas > ocio.
function RM.collectBooks(playerObj, session)
    local books = {}
    RM.forEachInventoryItem(playerObj, function(item)
        if session and session.read[item:getID()] then return end
        if RM.isReadableNow(playerObj, item) then
            table.insert(books, item)
        end
    end)

    local function priority(item)
        if SkillBook[item:getSkillTrained()] then return 1 end
        local recipes = item:getLearnedRecipes()
        if recipes and not recipes:isEmpty() then return 2 end
        return 3
    end

    table.sort(books, function(a, b)
        local pa, pb = priority(a), priority(b)
        if pa ~= pb then return pa < pb end
        return a:getName() < b:getName()
    end)

    return books
end
