-- Freeze Wand Script

local FREEZE_WAND_ID = 274

local freezeWandModData = {
    modID = 4454, 
    modName = "Frozen!", 
    onAddMessage = "You have been frozen! You cannot move.", 
    onRemoveMessage = "You have thawed out and can move again.", 
    iconID = FREEZE_WAND_ID, -- Menggunakan Item ID
    changeSkin = {180, 255, 255, 255}, 
    modState = {StateFlags.STATE_FROZEN}
}

local freezeWandModID = registerLuaPlaymod(freezeWandModData)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == FREEZE_WAND_ID then -- Menggunakan Item ID
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        if player:changeItem(itemID, -1, 0) then
            clickedPlayer:addMod(freezeWandModID, 10) 
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0) 
            player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats tidak terdefinisi di skrip ini.
            world:updateClothing(clickedPlayer) 
            clickedPlayer:playAudio("freeze.wav") 
            return true
        end
        return true
    end
    return false
end)