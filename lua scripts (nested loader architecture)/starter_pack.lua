-- MODULE
-- starter_pack.lua — Starter pack untuk player baru saat register

local M = {}
local Config = _G.Config

onPlayerRegisterCallback(function(world, player)
    local pack = Config.STARTER_PACK

    for i, item in ipairs(pack.ITEMS) do
        world:useItemEffect(player:getNetID(), item.itemID, 0, 250 * (i + 1))
        if not player:changeItem(item.itemID, item.itemCount, 0) then
            player:changeItem(item.itemID, item.itemCount, 1)
        end
    end

    player:addGems(pack.GEMS, 1, 0)
    player:onTalkBubble(player:getNetID(), "Received the Starter Pack! You have " .. player:getGems() .. " Gems!", 1)
end)

return M
