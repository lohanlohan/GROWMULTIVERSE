-- MODULE
-- cursewand.lua — Curse Wand consumable (item 278), mod -93, 5min, sends to HELL

local M = {}

local CURSE_WAND_ID      = 278
local CURSE_MOD_ID       = -93
local CURSE_DURATION_SEC = 5 * 60

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= CURSE_WAND_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if clickedPlayer:hasMod(CURSE_MOD_ID) then
        player:onTalkBubble(player:getNetID(), "`wThis player is already cursed.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(CURSE_MOD_ID, CURSE_DURATION_SEC)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        clickedPlayer:enterWorld("HELL", "")
    end

    return true
end)

return M
