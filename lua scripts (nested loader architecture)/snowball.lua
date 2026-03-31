-- MODULE
-- freezewand.lua — Freeze Wand consumable (item 274), mod 4454 "Frozen!", 10s

local M = {}

local FREEZE_WAND_ID = 1368

-- StateFlags.STATE_FROZEN not available in new arch, modState omitted
local freezeWandModID = registerLuaPlaymod({
    modID          = 4454,
    modName        = "Frozen!",
    onAddMessage   = "Your body has turned to ice. You can't move!",
    onRemoveMessage= "You've thawed out.",
    iconID         = FREEZE_WAND_ID,
    changeSkin     = {180, 255, 255, 255},
    modState       = {274},
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= FREEZE_WAND_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(freezeWandModID, 2)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        world:updateClothing(clickedPlayer)
        clickedPlayer:playAudio("freeze.wav")
    end

    return true
end)

return M
