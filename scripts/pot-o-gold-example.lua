-- Pot-O-Gold Gems Drop Example script

math.randomseed(os.time())

onTileBreakCallback(function(world, player, tile)
    local tileID = tile:getTileID();
    if tileID == 542 then -- Pot O' Gold
        world:onLoot(player, tile, math.random(1, 100))
        world:addXP(player, tile:getTileItem():getRarity())
        return true
    end
    return false
end)
