-- MODULE
-- give_level.lua — /givelevel: set player level (role 51)

local M = {}

local ROLE_DEV = 51

registerLuaCommand({ command = "givelevel", roleRequired = ROLE_DEV, description = "Set a specific level for a player." })

local function findPlayer(name)
    local needle = name:lower()
    for _, p in ipairs(getServerPlayers()) do
        if p:getCleanName():lower() == needle then return p end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)")
    if not cmd or cmd:lower() ~= "givelevel" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Access denied. `oDeveloper role required.")
        player:playAudio("audio/bleep_fail.wav")
        return true
    end

    local targetName, levelStr = args:match("^(%S+)%s*(%S+)$")
    if not targetName or not levelStr then
        player:onConsoleMessage("`4Usage: /givelevel <GrowID> <level>")
        player:playAudio("audio/bleep_fail.wav")
        return true
    end

    local level = tonumber(levelStr)
    if not level or level < 0 or level > 999 then
        player:onConsoleMessage("`4Invalid level! `oLevel must be a number between 0 and 999.")
        player:playAudio("audio/bleep_fail.wav")
        return true
    end

    local target = findPlayer(targetName)
    if not target then
        player:onConsoleMessage("`4Player '" .. targetName .. "' not found or not online.")
        player:playAudio("audio/bleep_fail.wav")
        return true
    end

    if target.setLevel then
        target:setLevel(level)
        player:onConsoleMessage(string.format("`2Successfully set %s's level to `6%d`2.", target:getName(), level))
        player:playAudio("audio/success.wav")
        target:onConsoleMessage(string.format("`2Your level has been set to `6%d`2 by Admin %s.", level, player:getName()))
    else
        player:onConsoleMessage("`4Error: `oFunction 'setLevel' not available.")
        player:playAudio("audio/bleep_fail.wav")
    end

    return true
end)

return M
