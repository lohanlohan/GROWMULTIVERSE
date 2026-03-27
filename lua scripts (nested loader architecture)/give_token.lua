-- MODULE
-- give_token.lua — /givetoken /removetoken: give or remove server tokens (coins) to player

local M = {}
local Config = _G.Config

local SERVER_TOKEN_ID = 20234
local ROLE_DEV        = 51

registerLuaCommand({ command = "givetoken",   roleRequired = ROLE_DEV, description = "Give server token to a player." })
registerLuaCommand({ command = "removetoken", roleRequired = ROLE_DEV, description = "Remove server token from a player." })

local function findPlayer(name)
    local needle = name:lower()
    for _, p in ipairs(getServerPlayers()) do
        if p:getCleanName():lower() == needle then return p end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "givetoken" and cmd ~= "removetoken" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local targetName, amountStr = args:match("^(%S+)%s+(%S+)$")
    if not targetName or not amountStr then
        player:onConsoleMessage("Usage: /" .. cmd .. " <playerName> <amount>")
        return true
    end

    local amount = tonumber(amountStr)
    if not amount or amount <= 0 then
        player:onConsoleMessage("`4Invalid amount. Must be a positive number.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local target = findPlayer(targetName)
    if not target then
        player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local tokenName = getItem(SERVER_TOKEN_ID) and getItem(SERVER_TOKEN_ID):getName() or "Server Token"

    if cmd == "givetoken" then
        target:addCoins(amount)
        player:onConsoleMessage("Gave " .. amount .. " " .. tokenName .. " to " .. target:getName() .. "!")
        target:onConsoleMessage("Developer " .. player:getName() .. " gave you `2" .. amount .. " `o" .. tokenName .. "!")
        player:playAudio("piano_nice.wav")
        target:playAudio("success.wav")
    else
        target:removeCoins(amount, 0)
        player:onConsoleMessage("Removed " .. amount .. " " .. tokenName .. " from " .. target:getName() .. "!")
        target:onConsoleMessage("Developer " .. player:getName() .. " removed `4" .. amount .. " `o" .. tokenName .. " from your balance!")
        player:playAudio("piano_nice.wav")
        target:playAudio("loser.wav")
    end

    return true
end)

return M
