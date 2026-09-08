-- ============================================================
--  Reading Marathon v1.0 - Build 42
--  Motor de la maraton: encola lecturas una tras otra y mete
--  un snack en el medio cuando el personaje tiene hambre.
-- ============================================================

ReadingMarathon = ReadingMarathon or {}
local RM = ReadingMarathon

local function halo(playerObj, textKey, good, arg)
    local text = arg and getText(textKey, arg) or getText(textKey)
    if good then
        HaloTextHelper.addGoodText(playerObj, text)
    else
        HaloTextHelper.addBadText(playerObj, text)
    end
end

-- ---------- Ciclo de vida ----------

function RM.start(playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    if RM.sessions[playerNum] then return end

    local ok, reason = RM.canStart(playerObj)
    if not ok then
        halo(playerObj, reason == "notCouch" and "IGUI_ReadingMarathon_NeedCouch" or "IGUI_ReadingMarathon_NeedSit", false)
        return
    end

    local session = {
        playerObj = playerObj,
        read = {},              -- [itemID] = true, para no releer lo mismo
        booksRead = 0,
        snacksEaten = 0,
        eatFails = 0,
        interrupted = false,    -- lo corto el jugador -> termina la maraton
        selfInterrupt = false,  -- lo corto el mod para comer
        currentAction = nil,    -- la lectura en curso, para poder cortarla
    }
    RM.sessions[playerNum] = session

    local books = RM.collectImportantBooks(playerObj, session)
    if #books == 0 then
        RM.sessions[playerNum] = nil
        halo(playerObj, "IGUI_ReadingMarathon_NoBooks", false)
        return
    end

    halo(playerObj, "IGUI_ReadingMarathon_Started", true, #books)
    RM.step(playerNum)
end

function RM.stop(playerNum, textKey, good)
    local session = RM.sessions[playerNum]
    RM.sessions[playerNum] = nil
    if not session or not textKey then return end
    local playerObj = session.playerObj
    if playerObj and not playerObj:isDead() then
        halo(playerObj, textKey, good, session.booksRead)
    end
end

function RM.isRunning(playerNum)
    return RM.sessions[playerNum] ~= nil
end

-- ---------- Acciones ----------

local function queueRead(playerNum, session, playerObj, item, forFun)
    session.read[item:getID()] = true
    if forFun then
        halo(playerObj, "IGUI_ReadingMarathon_Boredom", true)
    end

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)

    local action = ISReadABook:new(playerObj, item, 150)
    session.currentAction = action

    local originalPerform = action.perform
    action.perform = function(self)
        local s = RM.sessions[playerNum]
        if s then
            s.booksRead = s.booksRead + 1
            s.currentAction = nil
        end
        originalPerform(self)
    end

    local originalStop = action.stop
    action.stop = function(self)
        local s = RM.sessions[playerNum]
        if s then
            s.currentAction = nil
            if s.selfInterrupt then
                -- Lo cortamos nosotros para comer: el libro vuelve a la lista
                -- y se retoma solo (ISReadABook arranca en startPage).
                s.selfInterrupt = false
                s.read[item:getID()] = nil
            else
                s.interrupted = true
            end
        end
        originalStop(self)
    end

    ISTimedActionQueue.add(action)
end

-- Comer nunca se marca como currentAction, asi no se interrumpe a si mismo.
local function queueEat(playerNum, session, playerObj, snack)
    session.eatFails = session.eatFails + 1
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, snack)

    local action = ISEatFoodAction:new(playerObj, snack, 1)
    local originalPerform = action.perform
    action.perform = function(self)
        local s = RM.sessions[playerNum]
        if s then
            s.eatFails = 0
            s.snacksEaten = s.snacksEaten + 1
        end
        originalPerform(self)
    end

    local originalStop = action.stop
    action.stop = function(self)
        local s = RM.sessions[playerNum]
        if s then s.interrupted = true end
        originalStop(self)
    end

    ISTimedActionQueue.add(action)
    halo(playerObj, "IGUI_ReadingMarathon_Snack", true)
end

-- ---------- Maquina de estados ----------

function RM.step(playerNum)
    local session = RM.sessions[playerNum]
    if not session then return end

    local playerObj = session.playerObj
    if not playerObj or playerObj:isDead() then
        RM.sessions[playerNum] = nil
        return
    end

    if session.interrupted then
        return RM.stop(playerNum, "IGUI_ReadingMarathon_Interrupted", false)
    end
    if not RM.getSeat(playerObj) then
        return RM.stop(playerNum, "IGUI_ReadingMarathon_StoodUp", false)
    end
    if playerObj:tooDarkToRead() then
        return RM.stop(playerNum, "IGUI_ReadingMarathon_TooDark", false)
    end
    if playerObj:isAsleep() then
        return RM.stop(playerNum, "IGUI_ReadingMarathon_Interrupted", false)
    end

    -- Ocupado: si esta leyendo y le agarro hambre, se corta la lectura ahora
    -- mismo en vez de esperar a que termine el libro.
    if ISTimedActionQueue.isPlayerDoingAction(playerObj) then
        if RM.interruptToSatisfyNeeds and session.currentAction and not session.selfInterrupt then
            if RM.getPendingSnack(playerObj, session) then
                session.selfInterrupt = true
                local ok = pcall(function() session.currentAction:forceStop() end)
                if not ok then session.selfInterrupt = false end
            end
        end
        return
    end

    -- Hambre antes de seguir leyendo. El agua la maneja el juego (Auto Drink).
    local snack = RM.getPendingSnack(playerObj, session)
    if snack then
        queueEat(playerNum, session, playerObj, snack)
        return
    end

    -- Muy aburrido: si tiene algo de ocio a mano, se toma un respiro.
    if RM.isBored(playerObj) then
        local funBooks = RM.collectBoredomBooks(playerObj, session)
        if #funBooks > 0 then
            queueRead(playerNum, session, playerObj, funBooks[1], true)
            return
        end
    end

    -- El resto de la maraton es solo lo que suma XP o recetas.
    local books = RM.collectImportantBooks(playerObj, session)
    if #books == 0 then
        return RM.stop(playerNum, "IGUI_ReadingMarathon_Finished", true)
    end

    queueRead(playerNum, session, playerObj, books[1])
end

-- ---------- Loop ----------

local tickCounter = 0

-- Kahlua (el Lua de PZ) no expone next(), asi que se recorre con pairs.
local function hasSessions()
    for _ in pairs(RM.sessions) do
        return true
    end
    return false
end

local function onTick()
    if not hasSessions() then return end
    tickCounter = tickCounter + 1
    if tickCounter < RM.checkEveryTicks then return end
    tickCounter = 0

    for playerNum, _ in pairs(RM.sessions) do
        local ok, err = pcall(RM.step, playerNum)
        if not ok then
            print("[ReadingMarathon] ERROR: " .. tostring(err))
            RM.sessions[playerNum] = nil
        end
    end
end

Events.OnTick.Add(onTick)

print("[ReadingMarathon] v" .. RM.VERSION .. " cargado.")
