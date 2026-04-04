-- MODULE
-- consumable_coin.lua — Consumable Coin (item 25152): beri coin ke player lain

local M = {}

local ITEM_ID    = 25152
local COIN_REWARD = 1

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= ITEM_ID then return false end

    if clickedPlayer == nil then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addCoins(COIN_REWARD)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
    end
    return true
end)

return M
