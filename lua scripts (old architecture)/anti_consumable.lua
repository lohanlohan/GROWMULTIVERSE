local anti_consum_mod_data = {
	modID = -721, 
	modName = "Anti Consumable",
	onAddMessage = "are you full?", 
	onRemoveMessage = "now you are hungry", 
	iconID = 540
	}

local antiConsumID = registerLuaPlaymod(anti_consum_mod_data)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
	if clickedPlayer and clickedPlayer:getUserID() ~= player:getUserID() and clickedPlayer:hasMod(antiConsumID) then
		return true
	end
end)