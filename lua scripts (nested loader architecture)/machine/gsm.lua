-- MODULE
-- gsm.lua — /gsm: Global System Message broadcast to all players

local M = {}

local ROLE_DEV = 51

registerLuaCommand({ command = "gsm", roleRequired = ROLE_DEV, description = "Global System Message." })

onPlayerCommandCallback(function(world, player, full)
    local cmd, message = full:match("^(%S+)%s*(.*)")
    if cmd ~= "gsm" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown Command. `oEnter /? for a list of valid commands.")
        return true
    end

    if not message or message == "" then
        player:onConsoleMessage("`oUsage: /gsm <message>")
        return true
    end

    for _, p in ipairs(getServerPlayers()) do
        p:onConsoleMessage("`4Global System Message`o: " .. message)
        p:playAudio("sungate.wav")
    end

    return true
end)

return M
