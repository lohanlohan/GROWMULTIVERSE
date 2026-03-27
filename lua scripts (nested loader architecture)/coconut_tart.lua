-- MODULE
-- coconut_tart.lua — Coconut Tart (item 7056): EXP Boost x10 selama 10 menit

local M = {}

local ITEM_ID = 7056

local MOD_ID = registerLuaPlaymod({
    modID           = 7056,
    modName         = "Coconut Tart Boost",
    iconID          = ITEM_ID,
    changeSkin      = {255, 255, 200, 255},
    onAddMessage    = "`2EXP Boost x10 activated!",
    onRemoveMessage = "`wEXP Boost has expired.",
    expMultiplier   = 10,
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= ITEM_ID then return false end

    if clickedPlayer ~= player then
        player:onTalkBubble(player:getNetID(), "`wUse Coconut Tart on yourself.", 0)
        return true
    end

    if not player:changeItem(ITEM_ID, -1, 0) then return true end

    player:addMod(MOD_ID, 600)
    world:useItemEffect(player:getNetID(), ITEM_ID, player:getNetID(), 0)
    player:onTalkBubble(player:getNetID(), "`2EXP Boost x10 for 10 minutes!", 0)
    player:playAudio("consume.wav")
    return true
end)

return M
