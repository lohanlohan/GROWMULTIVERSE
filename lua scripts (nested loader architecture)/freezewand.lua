-- MODULE
-- freezewand.lua — Freeze Wand consumable (item 274), freeze 10s

local M = {}

local FREEZE_WAND_ID = 274

local StateFlags = {
    STATE_NO_CLIP = 0,
    STATE_DOUBLE_JUMP = 1,
    STATE_INVISIBLE = 2,
    STATE_NO_HAND = 3,
    STATE_NO_EYE = 4,
    STATE_NO_BODY = 5,
    STATE_DEVIL_HORNS = 6,
    STATE_GOLDEN_HALO = 7,
    STATE_FROZEN = 11,
    STATE_CURSED = 12,
    STATE_DUCT_TAPED = 13,
    STATE_CIGAR = 14,
    STATE_SHINING = 15,
    STATE_ZOMBIE = 16,
    STATE_RED_BODY = 17,
    STATE_HAUNTED_SHADOWS = 18,
    STATE_GEIGER_RADIATION = 19,
    STATE_SPOTLIGHT = 20,
    STATE_YELLOW_BODY = 21,
    STATE_PINEAPPLE_FLAG = 22,
    STATE_FLYING_PINEAPPLE = 23,
    STATE_SUPER_SUPPORTER_NAME = 24,
    STATE_SUPER_PINEAPPLE = 25,
    STATE_BUBBLE = 26,
    STATE_SOAKED = 27
}

local freezeWandModData = {
    modID = 4454,
    modName = "Frozen!",
    onAddMessage = "You have been frozen! You cannot move.",
    onRemoveMessage = "You have thawed out and can move again.",
    iconID = FREEZE_WAND_ID,
    changeSkin = {180, 255, 255, 255},
    modState = {StateFlags.STATE_FROZEN}
}

local freezeWandModID = registerLuaPlaymod(freezeWandModData)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= FREEZE_WAND_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(freezeWandModID, 10)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        world:updateClothing(clickedPlayer)
        clickedPlayer:playAudio("freeze.wav")
    end

    return true
end)

return M
