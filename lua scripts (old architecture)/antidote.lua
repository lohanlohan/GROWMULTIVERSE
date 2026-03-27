local irradiated_mod_id = -25
local curse_duration_sec = 1
local antidote_id = 782

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= antidote_id then
        return false
    end

    if clickedPlayer == nil then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if not clickedPlayer:hasMod(irradiated_mod_id) then
        player:onTalkBubble(player:getNetID(), "`wThis player is already cured.``", 1)
        return true
    end

    if not player:changeItem(itemID, -1, 0) then
        return true
    end

    clickedPlayer:removeMod(irradiated_mod_id, curse_duration_sec)
    world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
    player:updateStats(world, PlayerStats.ConsumablesUsed, 1)
    return true
end)
