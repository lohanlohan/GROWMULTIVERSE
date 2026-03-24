-- BALOON script
local floatingModData = {
    modID = -338, -- Unique negative ID to avoid conflicts
    modName = "Enhanced Floating Effect",
    onAddMessage = "You're soaring upward!",
    onRemoveMessage = "Back to normal gravity.",
    iconID = 338, -- Fallback item ID for Balloon
    changeGravity = -500 -- Strong upward floating effect
}

-- Check if getEnumItem is available and ITEM_BALLOON exists
local balloonItem = getEnumItem and getEnumItem("ITEM_BALLOON")
if balloonItem then
    floatingModData.iconID = balloonItem:getID()
end

-- Register the playmod
registerLuaPlaymod(floatingModData)

-- Handle the consumable item usage
onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == 338 then -- Check if the item is Balloon (ID 338)
        if not player then
            return false
        end
        if player:changeItem(itemID, -1, 0) then -- Consume one balloon
            player:addMod(-338, 3) -- Apply the mod for 3 seconds
            world:useItemEffect(player:getNetID(), itemID, player:getNetID(), 0) -- Play item effect
            player:onTalkBubble(player:getNetID(), "`wJump-High added``", 1) -- Show message
            player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- Update stats
            world:updateClothing(player) -- Update player visuals
            return true -- Prevent default action
        end
    end
    return false
end)

-- Example of handling timing without sleep using onTick
local activeMods = {} -- Table to track active mods for players

onTick(function()
    for playerName, modInfo in pairs(activeMods) do
        local player = getPlayerByName(playerName)
        if player and modInfo.expiry > os.time() then
            -- Mod is still active, do nothing
        else
            -- Mod has expired, remove it
            if player then
                player:removeMod(-338) -- Assuming removeMod exists; if not, let it expire naturally
                player:onTalkBubble(player:getNetID(), "`wFloating effect ended``", 1)
                world:updateClothing(player)
            end
            activeMods[playerName] = nil -- Clear from tracking
        end
    end
end)

-- Modify the consumable callback to track mod duration
onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == 338 then -- Check if the item is Balloon (ID 338)
        if not player then
            return false
        end
        if player:changeItem(itemID, -1, 0) then -- Consume one balloon
            local playerName = player:getName()
            player:addMod(-338, 3) -- Apply the mod for 3 seconds
            activeMods[playerName] = { expiry = os.time() + 3 } -- Track mod with expiry time
            world:useItemEffect(player:getNetID(), itemID, player:getNetID(), 0) -- Play item effect
            player:onTalkBubble(player:getNetID(), "`wJump-High added``", 1) -- Show message
            player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- Update stats
            world:updateClothing(player) -- Update player visuals
            return true -- Prevent default action
        end
    end
    return false
end)