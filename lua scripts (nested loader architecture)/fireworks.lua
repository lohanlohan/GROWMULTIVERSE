-- MODULE
-- fireworks.lua — Fireworks consumable (item 834), particle effect for all players in world

local M = {}

local FIREWORKS_ID = 834

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= FIREWORKS_ID then return false end

    if player:changeItem(itemID, -1, 0) then
        local x, y = player:getPosX(), player:getPosY()

        for _, p in pairs(world:getPlayers()) do
            p:onParticleEffect(41, x - 64, y - 128, 20, 30, 100)
            p:onParticleEffect(40, x,      y - 256, 25, 35, 100)
        end

        world:updateClothing(player)
        return true
    end

    return false
end)

return M
