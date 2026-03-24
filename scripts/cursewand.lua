-- Curse Wand Script

local CURSE_WAND_ID = 278 -- Fixed Item ID

local curse_mod_id = -93
local curse_duration_sec = 5 * 60

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == CURSE_WAND_ID then -- Menggunakan Item ID
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        if clickedPlayer:hasMod(curse_mod_id) then
            player:onTalkBubble(player:getNetID(), "`wThis player is already cursed.``", 1)
            return true
        end
        if player:changeItem(itemID, -1, 0) then
            clickedPlayer:addMod(curse_mod_id, curse_duration_sec)
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
            player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats tidak terdefinisi di skrip ini.
            clickedPlayer:enterWorld("HELL", "")
            return true
        end
        return true
    end
    return false
end)