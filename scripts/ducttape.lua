-- Duct Tape Script

local DUCT_TAPE_ID = 408 -- Fixed Item ID

local ductTapeId = 0
local ductTapeDuration = 10*60

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == DUCT_TAPE_ID then -- Menggunakan Item ID
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        if clickedPlayer:hasMod(ductTapeId) then
            player:onTalkBubble(player:getNetID(), "`wThis player is already silenced.``", 1)
            return true
        end
        if player:changeItem(itemID, -1, 0) then
            clickedPlayer:addMod(ductTapeId, ductTapeDuration)
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
            -- player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats tidak terdefinisi di skrip ini.
            world:updateClothing(clickedPlayer)
            clickedPlayer:playAudio("already_used.wav")
            return true
        end
        return true
    end
    return false
end)