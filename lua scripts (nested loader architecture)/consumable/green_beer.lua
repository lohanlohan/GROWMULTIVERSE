-- MODULE
-- green_beer.lua — Green Beer (item 540): buff Envious + double jump + shining

local M = {}

local MOD_ID = registerLuaPlaymod({
    modID                 = -1100,
    modName               = "Envious",
    onAddMessage          = "It ain't easy being you.",
    onRemoveMessage       = "Healthy color restored.",
    iconID                = 540,
    changeSkin            = {52, 235, 107, 255},
    modState              = {1, 15},  -- STATE_DOUBLE_JUMP, STATE_SHINING
    changeMovementSpeed   = 500,
    changeAcceleration    = 0,
    changeGravity         = 0,
    changePunchStrength   = 0,
    changeBuildRange      = 0,
    changePunchRange      = 0,
    changeWaterMovementSpeed = 0,
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= 540 then return false end

    if clickedPlayer == nil then
        player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
        return true
    end

    if player:changeItem(itemID, -1, 0) then
        clickedPlayer:addMod(MOD_ID, 10)
        world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
        world:updateClothing(clickedPlayer)
    end
    return true
end)

return M
