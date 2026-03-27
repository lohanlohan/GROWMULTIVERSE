-- MODULE
-- antidote.lua — Antidote (item 782): sembuhkan irradiated mod

local M = {}

local ITEM_ID          = 782
local IRRADIATED_MOD   = -25
local CURE_DURATION_SEC = 1

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= ITEM_ID then return false end

    if clickedPlayer == nil then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if not clickedPlayer:hasMod(IRRADIATED_MOD) then
        player:onTalkBubble(player:getNetID(), "`wThis player is already cured.``", 1)
        return true
    end

    if not player:changeItem(itemID, -1, 0) then return true end

    clickedPlayer:removeMod(IRRADIATED_MOD, CURE_DURATION_SEC)
    world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
    return true
end)

return M
