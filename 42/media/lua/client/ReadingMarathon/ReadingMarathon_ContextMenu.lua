-- ============================================================
--  Reading Marathon v1.0 - Build 42
--  Agrega "Read Marathon" justo debajo de "Read".
-- ============================================================

ReadingMarathon = ReadingMarathon or {}
local RM = ReadingMarathon

local function onStart(items, playerNum)
    RM.start(playerNum)
end

local function onStop(items, playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if playerObj then
        ISTimedActionQueue.clear(playerObj)
    end
    RM.stop(playerNum, "IGUI_ReadingMarathon_Stopped", false)
end

function RM.addContextOption(context, items, playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    if RM.isRunning(playerNum) then
        context:addOption(getText("ContextMenu_ReadingMarathon_Stop"), items, onStop, playerNum)
        return
    end

    local option = context:addOption(getText("ContextMenu_ReadingMarathon"), items, onStart, playerNum)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()

    local canStart, reason = RM.canStart(playerObj)
    if not canStart then
        option.notAvailable = true
        tooltip.description = getText(reason == "notCouch"
            and "ContextMenu_ReadingMarathon_NeedCouch"
            or "ContextMenu_ReadingMarathon_NeedSit")
    else
        local books = RM.collectBooks(playerObj)
        if #books == 0 then
            option.notAvailable = true
            tooltip.description = getText("ContextMenu_ReadingMarathon_NoBooks")
        else
            tooltip.description = getText("ContextMenu_ReadingMarathon_Tooltip", #books)
        end
    end

    option.toolTip = tooltip
end

-- Se engancha al menu de literatura del juego para quedar pegado a "Read".
local originalLiteratureMenu = ISInventoryPaneContextMenu.doLiteratureMenu
if originalLiteratureMenu then
    ISInventoryPaneContextMenu.doLiteratureMenu = function(context, items, player)
        originalLiteratureMenu(context, items, player)
        local ok, err = pcall(RM.addContextOption, context, items, player)
        if not ok then print("[ReadingMarathon] ERROR menu: " .. tostring(err)) end
    end
else
    print("[ReadingMarathon] ERROR: doLiteratureMenu no encontrada.")
end
