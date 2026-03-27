-- MODULE
-- firewand.lua — Fire Wand consumable (item 276), mod -94 "Burning", sends to HELL

local M = {}

local FIRE_WAND_ID      = 276
local FIRE_MOD_ID       = -94
local FIRE_DURATION_SEC = 30

local fireWandModID = registerLuaPlaymod({
    modID          = FIRE_MOD_ID,
    modName        = "Burning",
    onAddMessage   = "You are burning!",
    onRemoveMessage= "The fire has gone out.",
    iconID         = FIRE_WAND_ID,
    changeSkin     = {255, 128, 0, 255},
    modState       = {},
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= FIRE_WAND_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if clickedPlayer:hasMod(fireWandModID) then
        player:onTalkBubble(player:getNetID(), "`wThis player is already burning.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(fireWandModID, FIRE_DURATION_SEC)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        clickedPlayer:playAudio("fireworks.wav")
        clickedPlayer:onConsoleMessage("`4You have been incinerated and sent to HELL!")
        clickedPlayer:enterWorld("HELL", "")
    end

    return true
end)

return M
