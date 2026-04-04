-- MODULE
-- anti_consumable.lua — Register Anti Consumable playmod (mod ID -721)

local M = {}

local antiConsumID = registerLuaPlaymod({
    modID            = -721,
    modName          = "Anti Consumable",
    onAddMessage     = "are you full?",
    onRemoveMessage  = "now you are hungry",
    iconID           = 540,
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if clickedPlayer
        and clickedPlayer:getUserID() ~= player:getUserID()
        and clickedPlayer:hasMod(antiConsumID)
    then
        return true
    end
end)

return M
