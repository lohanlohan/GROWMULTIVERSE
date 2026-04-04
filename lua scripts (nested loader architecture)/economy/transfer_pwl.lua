-- MODULE
-- transfer_pwl.lua — /transfer: kirim PWL (premium currency) ke player lain

local M = {}
local Utils = _G.Utils

local TOKEN_ID   = 20234
local TOKEN_NAME = getItem(TOKEN_ID):getName()

registerLuaCommand({
    command      = "transfer",
    roleRequired = 0,
    description  = "Transfer your " .. TOKEN_NAME .. " to another player.",
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = Utils.parseArgs(fullCommand)
    if args[1]:lower() ~= "/transfer" then return false end

    local targetName = args[2]
    local amount     = tonumber(args[3])

    if not targetName or not amount or amount <= 0 then
        Utils.msg(player, "`4Usage: /transfer <playerName> <amount>")
        return true
    end

    -- cari player exact match (case insensitive)
    local target
    for _, p in ipairs(getServerPlayers()) do
        if p:getCleanName():lower() == targetName:lower() then
            target = p; break
        end
    end

    if not target then
        Utils.msg(player, "`4Player '" .. targetName .. "' not found or offline.")
        player:onTextOverlay("`4Failed")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if target:getCleanName():lower() == player:getCleanName():lower() then
        Utils.msg(player, "`4You cannot transfer to yourself.")
        player:onTextOverlay("`4Failed")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if player:getCoins() < amount then
        Utils.msg(player, "`4Not enough " .. TOKEN_NAME .. ".")
        player:onTextOverlay("`4Failed")
        player:playAudio("bleep_fail.wav")
        return true
    end

    player:setCoins(player:getCoins() - amount)
    target:setCoins(target:getCoins() + amount)

    Utils.msg(player,  "You sent `w" .. amount .. "`` " .. TOKEN_NAME .. " to `w" .. target:getName() .. "``.")
    Utils.msg(target,  "You received `w" .. amount .. "`` " .. TOKEN_NAME .. " from `w" .. player:getName() .. "``.")
    player:onTextOverlay("`2Success")
    player:playAudio("coin_flip.wav")
    target:playAudio("cash_register.wav")
    return true
end)

return M
