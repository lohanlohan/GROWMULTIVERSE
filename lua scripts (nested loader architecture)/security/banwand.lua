-- MODULE
-- banwand.lua — Ban Wand consumable (item 732), mod -95 "Banned Zone", 10s, sends to EXIT

local M = {}

local BAN_WAND_ID      = 732
local BAN_MOD_ID       = -95
local BAN_DURATION_SEC = 10
local DEV_ROLE_ID      = 51

local banWandModID = registerLuaPlaymod({
    modID          = BAN_MOD_ID,
    modName        = "Banned Zone",
    onAddMessage   = "You have been banished!",
    onRemoveMessage= "The banishment ended.",
    iconID         = BAN_WAND_ID,
    changeSkin     = {255, 0, 0, 255},
    modState       = {},
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= BAN_WAND_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if clickedPlayer:hasRole(DEV_ROLE_ID) then
        player:onTalkBubble(player:getNetID(), "`4Cannot ban a Developer.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(banWandModID, BAN_DURATION_SEC)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        clickedPlayer:playAudio("buzz.wav")
        clickedPlayer:onConsoleMessage("`4You have been banished from this world!")
        clickedPlayer:enterWorld("EXIT", "")
    end

    return true
end)

return M
