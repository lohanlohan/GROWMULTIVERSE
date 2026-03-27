onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    local fireworksItemID = 834 -- Fixed Item ID

    if itemID ~= fireworksItemID then return false end  

    if player:changeItem(itemID, -1, 0) then
        local x, y = player:getPosX(), player:getPosY()

        for _, clickedPlayer in pairs(world:getPlayers()) do
            -- NOTE: Dibiarkan menggunakan clickedPlayer untuk konsistensi, 
            -- meskipun ini seharusnya player (sendiri) untuk effect area.
            clickedPlayer:onParticleEffect(41, x - 64, y - 128, 20, 30, 100)    --41,40
            clickedPlayer:onParticleEffect(40, x, y - 256, 25, 35, 100)
        end

        player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats tidak terdefinisi di skrip ini.
        world:updateClothing(player)
        return true
    end

    return false  
end)