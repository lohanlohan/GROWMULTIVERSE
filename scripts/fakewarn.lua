-- fakewarn script

local fakewarnCommand = {
    command = "fakewarn",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Pranking the players by fake warning them lol"
}

registerLuaCommand(fakewarnCommand)

local function normalizeName(name)
    name = name:lower():gsub("`.", "")
    name = name:gsub("^@", "")
    name = name:gsub("%b[]", "")
    name = name:gsub("^dr%.", "")
    name = name:gsub(" of legend", "")
    name = name:gsub("_%d+$", "")
    name = name:gsub("%s+", "")
    return name
end

local function findPlayerByNameInsensitive(inputName)
    local target = normalizeName(inputName)
    for _, p in ipairs(getServerPlayers()) do
        local playerNameNorm = normalizeName(p:getName())
        if playerNameNorm:find(target, 1, true) == 1 then
            return p
        end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local command, args = fullCommand:match("^(%S+)%s*(.*)$")
    if command ~= fakewarnCommand.command then return false end

    local targetName, reason = args:match("^(%S+)%s+(.+)$")
    
    if targetName == "all" then
        if not reason then
            player:onConsoleMessage("Usage: /" .. command .. " all <reason>")
            return true
        end

        for _, target in ipairs(getServerPlayers()) do
            target:sendVariant({"OnAddNotification", "interface\\atomic_button.rttex", 
                "`4Warning: ``" .. reason, "audio\\hub_open.wav", 0})
            target:onConsoleMessage("`4Warning: " .. reason)
        end

        player:onConsoleMessage("You have sent a fake warning to all players!")
        return true
    end

    if not targetName or not reason then
        player:onConsoleMessage("Usage: /" .. command .. " <playerName/all> <reason>")
        return true
    end

    local target = findPlayerByNameInsensitive(targetName)
    if not target then
        player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
        return true
    end

    target:sendVariant({"OnAddNotification", "interface\\atomic_button.rttex", 
        "`4Warning: ``" .. reason, "audio\\hub_open.wav", 0})
    target:onConsoleMessage("`4Warning: " .. reason)

    player:onConsoleMessage("You have sent a fake warning to " .. target:getName() .. "!")
    return true
end)