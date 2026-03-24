-- MODULE
print("(Loaded) debug-command")

local ROLE_DEVELOPER = 51

local debugCommandData = {
    command = "debug",
    roleRequired = ROLE_DEVELOPER,
    description = "Show debug info to developer console"
}

local debugAliasCommandData = {
    command = "debugs",
    roleRequired = ROLE_DEVELOPER,
    description = "Alias for debug command"
}

registerLuaCommand(debugCommandData)
registerLuaCommand(debugAliasCommandData)

local function safeName(player)
    return (player and player.getName and player:getName()) or "Unknown"
end

local function safeUID(player)
    return (player and player.getUserID and player:getUserID()) or -1
end

local function safeWorldName(world, player)
    if world and world.getName then
        return world:getName()
    end
    if player and player.getWorldName then
        return player:getWorldName()
    end
    return "UNKNOWN"
end

local function safePosX(player)
    return (player and player.getPosX and player:getPosX()) or 0
end

local function safePosY(player)
    return (player and player.getPosY and player:getPosY()) or 0
end

local function safeGems(player)
    return (player and player.getGems and player:getGems()) or 0
end

onPlayerCommandCallback(function(world, player, fullCommand)
    if type(fullCommand) ~= "string" then return false end

    local cmd, args = fullCommand:match("^(%S+)%s*(.*)$")
    if not cmd then return false end
    cmd = cmd:lower():gsub("^/", "")

    if cmd ~= "debug" and cmd ~= "debugs" then
        return false
    end

    if not player or not player.hasRole or not player:hasRole(ROLE_DEVELOPER) then
        if player and player.onConsoleMessage then
            player:onConsoleMessage("`4Unknown command. `oEnter `$/help `ofor a list of valid commands.")
        end
        return true
    end

    local isSignalJammed = (world and world.hasFlag and world:hasFlag(1)) and "YES" or "NO"

    player:onConsoleMessage("`9[DEBUG]`o Name: `w" .. safeName(player))
    player:onConsoleMessage("`9[DEBUG]`o UID: `w" .. tostring(safeUID(player)))
    player:onConsoleMessage("`9[DEBUG]`o World: `w" .. safeWorldName(world, player))
    player:onConsoleMessage("`9[DEBUG]`o Position: `wX=" .. tostring(safePosX(player)) .. "`o, `wY=" .. tostring(safePosY(player)))
    player:onConsoleMessage("`9[DEBUG]`o Gems: `w" .. tostring(safeGems(player)))
    player:onConsoleMessage("`9[DEBUG]`o Signal Jammer: `w" .. isSignalJammed)

    if args and args ~= "" then
        player:onConsoleMessage("`9[DEBUG]`o Note: `w" .. args)
    end

    return true
end)

print("(Ready) debug-command")
