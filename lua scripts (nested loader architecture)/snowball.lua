-- MODULE
-- snowball.lua — Snowball consumable (item 1368), freeze 30s

local M = {}

local SNOWBALL_ID = 1368
local FREEZE_DURATION_SECONDS = 2
local NINJA_STEALTH_MOD_ID = 290

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

local snowballModData = {
    modID = 4455,
    modName = "Frozen!",
    onAddMessage = "Your body has turned to ice. You can't move!",
    onRemoveMessage = "You've thawed out.",
    iconID = SNOWBALL_ID,
    changeSkin = {0, 175, 255, 255},
    modState = {StateFlags.STATE_FROZEN}
}

local snowballModID = registerLuaPlaymod(snowballModData)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= SNOWBALL_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(snowballModID, FREEZE_DURATION_SECONDS)
        clickedPlayer:addMod(NINJA_STEALTH_MOD_ID, FREEZE_DURATION_SECONDS)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        world:updateClothing(clickedPlayer)
        clickedPlayer:playAudio("freeze.wav")
    end

    return true
end)

return M
