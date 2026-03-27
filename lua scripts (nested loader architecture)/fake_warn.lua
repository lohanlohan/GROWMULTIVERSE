-- MODULE
-- fake_warn.lua — /fakewarn: send fake warning notification to player(s)

local M = {}

local ROLE_DEV = 51

registerLuaCommand({ command = "fakewarn", roleRequired = ROLE_DEV, description = "Send a fake warning to a player or all." })

local function normalizeName(name)
    return name:lower():gsub("`.", ""):gsub("^@", ""):gsub("%b[]", ""):gsub("^dr%.", ""):gsub(" of legend", ""):gsub("_%d+$", ""):gsub("%s+", "")
end

local function findPlayer(name)
    local needle = normalizeName(name)
    for _, p in ipairs(getServerPlayers()) do
        if normalizeName(p:getName()):find(needle, 1, true) == 1 then return p end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "fakewarn" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end

    local targetName, reason = args:match("^(%S+)%s+(.+)$")

    if targetName == "all" then
        if not reason then
            player:onConsoleMessage("Usage: /fakewarn all <reason>")
            return true
        end
        for _, target in ipairs(getServerPlayers()) do
            target:sendVariant({ "OnAddNotification", "interface/atomic_button.rttex",
                "`4Warning: ``" .. reason, "audio/hub_open.wav", 0 })
            target:onConsoleMessage("`4Warning: " .. reason)
        end
        player:onConsoleMessage("Sent fake warning to all players!")
        return true
    end

    if not targetName or not reason then
        player:onConsoleMessage("Usage: /fakewarn <playerName/all> <reason>")
        return true
    end

    local target = findPlayer(targetName)
    if not target then
        player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
        return true
    end

    target:sendVariant({ "OnAddNotification", "interface/atomic_button.rttex",
        "`4Warning: ``" .. reason, "audio/hub_open.wav", 0 })
    target:onConsoleMessage("`4Warning: " .. reason)
    player:onConsoleMessage("Sent fake warning to " .. target:getName() .. "!")
    return true
end)

return M
