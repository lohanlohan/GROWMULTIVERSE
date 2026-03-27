local coin_reward = 1 --jumlah coin yg mau lu ksih

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= 25152 then --target item
        return false
    end

    if clickedPlayer == nil then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addCoins(coin_reward)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        player:updateStats(world, PlayerStats.ConsumablesUsed, 1)
        return true
    end

    return true
end)