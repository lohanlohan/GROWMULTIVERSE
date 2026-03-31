-- MODULE
-- role_inject.lua — Consumable role injectors
--   25036 = Developer Role Inject → setRole(51)
--   25038 = Default Role Inject   → setRole(0)

local M = {}

local DEVELOPER_ROLE_INJECT = 25036
local DEFAULT_ROLE_INJECT   = 25038
local ROLE_DEVELOPER        = 51

local function isDeveloper(player)
    return player ~= nil and player.hasRole ~= nil and player:hasRole(ROLE_DEVELOPER)
end

local function isRoleInjectItem(itemID)
    return itemID == DEVELOPER_ROLE_INJECT or itemID == DEFAULT_ROLE_INJECT
end

local function getDropDialogItemID(dialogContent)
    local id = dialogContent:match("embed_data|itemID|(%d+)")
        or dialogContent:match("itemID|(%d+)|")
        or dialogContent:match("add_label_with_icon|big|[^\n]*|left|(%d+)|")
    return id and tonumber(id) or nil
end

local function isRestrictedDropDialog(dialogContent)
    if type(dialogContent) ~= "string" then
        return false
    end

    if not dialogContent:find("end_dialog|drop_item", 1, true)
        and not dialogContent:find("dialog_name|drop_item", 1, true)
    then
        return false
    end

    local itemID = getDropDialogItemID(dialogContent)
    return itemID ~= nil and isRoleInjectItem(itemID)
end

local function canUseOnSelf(player, clickedPlayer)
    if clickedPlayer == nil or clickedPlayer.getUserID == nil then
        player:onTalkBubble(player:getNetID(), "Must be used on a person", 1)
        return false
    end

    if clickedPlayer:getUserID() ~= player:getUserID() then
        player:onTalkBubble(player:getNetID(), "This item can only be used on yourself", 1)
        return false
    end

    return true
end

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == DEVELOPER_ROLE_INJECT then
        if not canUseOnSelf(player, clickedPlayer) then
            return true
        end

        player:changeItem(DEVELOPER_ROLE_INJECT, -1, 0)
        player:setRole(51)
        player:onConsoleMessage("`2[Role Inject] Developer role applied (ID: 51).")
        return true
    end

    if itemID == DEFAULT_ROLE_INJECT then
        if not canUseOnSelf(player, clickedPlayer) then
            return true
        end

        player:changeItem(DEFAULT_ROLE_INJECT, -1, 0)
        player:setRole(0)
        player:onConsoleMessage("`o[Role Inject] Role reset to Default (ID: 0).")
        return true
    end

    return false
end)

-- Block native drop confirmation dialog before user can press OK.
onPlayerVariantCallback(function(player, variant, delay, netID)
    if variant[1] ~= "OnDialogRequest" then
        return false
    end

    if isDeveloper(player) then
        return false
    end

    local dialogContent = tostring(variant[2] or "")
    if not isRestrictedDropDialog(dialogContent) then
        return false
    end

    player:onTextOverlay("You can't drop that")
    player:playAudio("bleep_fail.wav")
    return true
end)

onPlayerDropCallback(function(world, player, itemID, itemCount)
    if not isRoleInjectItem(itemID) then
        return false
    end

    if isDeveloper(player) then
        return false
    end

    player:onTextOverlay("You can't drop that")
    player:playAudio("bleep_fail.wav")
    return true
end)

-- Nperma callback: block trading role inject items.
onPlayerTradeCallback(function(world, player1, player2, items1, items2)
    local function hasRoleInject(items)
        if type(items) ~= "table" then
            return false
        end

        for _, invItem in pairs(items) do
            if invItem and invItem.getItemID and isRoleInjectItem(invItem:getItemID()) then
                return true
            end
        end

        return false
    end

    local p1HasInject = hasRoleInject(items1)
    local p2HasInject = hasRoleInject(items2)

    if not p1HasInject and not p2HasInject then
        return false
    end

    local p1Allowed = (not p1HasInject) or isDeveloper(player1)
    local p2Allowed = (not p2HasInject) or isDeveloper(player2)
    if p1Allowed and p2Allowed then
        return false
    end

    if p1HasInject and not isDeveloper(player1) then
        player1:onConsoleMessage("`oUntradable items can't be advertised on billboards")
        player1:onConsoleMessage("`4This item cannot be traded.")
        player1:playAudio("bleep_fail.wav")
    end

    if p2HasInject and not isDeveloper(player2) then
        player2:onConsoleMessage("`oUntradable items can't be advertised on billboards")
        player2:onConsoleMessage("`4This item cannot be traded.")
        player2:playAudio("bleep_fail.wav")
    end

    return true
end)

return M
