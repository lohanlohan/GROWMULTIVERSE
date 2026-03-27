-- Register Command
registerLuaCommand({
    command = "gsm",
    roleRequired = 51, -- sesuaikan (ADMIN / MOD / OWNER)
    description = "Global System Message"
})

-- Command Callbac
onPlayerCommandCallback(function(world, player, fullCommand)
    local worldName = world:getName()
    local playerName = player:getName()
    local cmd, message = fullCommand:match("^(%S+)%s*(.*)")
    if cmd ~= "gsm" then return false end

    -- Permission check
    if not player:hasRole(51) then
        player:onConsoleMessage("`4Unknown Command.`o Enter /? for a list of valid commands.")
        return true
    end

    -- Usage check
    if not message or message == "" then
        player:onConsoleMessage("`oUsage: /gsm <message>")
        return true
    end

    -- Super Broadcast ke semua player
    for _, p in ipairs(getServerPlayers()) do
        p:onConsoleMessage("`4Global System Message`o: ".. message)
        p:playAudio("sungate.wav")
    end

    return true
end)
