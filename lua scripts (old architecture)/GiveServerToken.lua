local serverTokenID = 20234
local giveCommand = "givetoken"
local removeCommand = "removetoken"

local Roles = {
    ROLE_DEVELOPER = 51,
}

registerLuaCommand({
    command = giveCommand,
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Give server token to a player."
})

registerLuaCommand({
    command = removeCommand,
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Remove server token from a player."
})

local function findPlayerByNameInsensitive(inputName)
    local target = string.lower(inputName)
    for _, p in ipairs(getServerPlayers()) do
        if string.lower(p:getCleanName()) == target then
            return p
        end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, args = fullCommand:match("^(%S+)%s*(.*)$")
    if command ~= giveCommand and command ~= removeCommand then return false end

    if not player:hasRole(Roles.ROLE_DEVELOPER) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local targetName, amountStr = args:match("^(%S+)%s+(%S+)$")
    if not targetName or not amountStr then
        player:onConsoleMessage("Usage: /" .. command .. " <playerName> <amount>")
        player:playAudio("thwoop.wav")
        return true
    end

    local amount = tonumber(amountStr)
    if not amount or amount <= 0 then
        player:onConsoleMessage("`4Invalid amount. `oMust be a positive number.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local target = findPlayerByNameInsensitive(targetName)
    if not target then
        player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if command == giveCommand then
        target:addCoins(amount)
        player:onConsoleMessage("Gave " .. amount .. " " .. getItem(serverTokenID):getName() .. " to " .. target:getName() .. "!")
        target:onConsoleMessage("Developer " .. player:getName() .. " gave you `2" .. amount .. " `o" .. getItem(serverTokenID):getName() .. "!")
        player:playAudio("piano_nice.wav")
        target:playAudio("success.wav")
    else
        target:removeCoins(amount, 0)
        player:onConsoleMessage("Removed " .. amount .. " " .. getItem(serverTokenID):getName() .. " from " .. target:getName() .. "!")
        target:onConsoleMessage("Developer " .. player:getName() .. " removed `4" .. amount .. " `o" .. getItem(serverTokenID):getName() .. " from your balance!")
        player:playAudio("piano_nice.wav")
        target:playAudio("loser.wav")
    end
    
    return true
end)