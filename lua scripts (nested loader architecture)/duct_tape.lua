-- MODULE
-- duct_tape.lua — Duct Tape consumable (item 408), mod 0 (silence), 10 minutes

local M = {}

local DUCT_TAPE_ID      = 408
local DUCT_TAPE_MOD_ID  = 0        -- built-in silence mod
local DUCT_TAPE_DURATION = 10 * 60

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= DUCT_TAPE_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if clickedPlayer:hasMod(DUCT_TAPE_MOD_ID) then
        player:onTalkBubble(player:getNetID(), "`wThis player is already silenced.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(DUCT_TAPE_MOD_ID, DUCT_TAPE_DURATION)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        world:updateClothing(clickedPlayer)
        clickedPlayer:playAudio("already_used.wav")
    end

    return true
end)

return M
