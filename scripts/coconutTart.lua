local COCONUT_TART_ID = 7056

-- Playmod EXP Boost
local expBoostMod = registerLuaPlaymod({
    modID = 7056,
    modName = "Coconut Tart Boost",
    iconID = COCONUT_TART_ID,
    changeSkin = {255, 255, 200, 255},
    onAddMessage = "`2EXP Boost x10 activated!",
    onRemoveMessage = "`wEXP Boost has expired.",
    expMultiplier = 10
})

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= COCONUT_TART_ID then
        return false
    end

    -- harus dipakai ke diri sendiri
    if clickedPlayer ~= player then
        player:onTalkBubble(
            player:getNetID(),
            "`wUse Coconut Tart on yourself.",
            0
        )
        return true
    end

    -- konsumsi item
    if not player:changeItem(COCONUT_TART_ID, -1, 0) then
        return true
    end

    -- tambah buff (10 menit)
    player:addMod(expBoostMod, 600)

    -- efek visual + feedback
    world:useItemEffect(
        player:getNetID(),
        COCONUT_TART_ID,
        player:getNetID(),
        0
    )

    player:onTalkBubble(
        player:getNetID(),
        "`2EXP Boost x10 for 10 minutes!",
        0
    )

    player:playAudio("consume.wav")

    return true
end)
