local CONFIG = {
    command = "lbevent",
    adminRole = 51,
    excludeRoles = {
        [51] = true,
    },
    items = {
        WL = 242,
        DL = 1796,
        BGL = 7188,
        BBGL = 20628
    },
    values = {
        [242] = 1,
        [1796] = 100,
        [7188] = 10000,
        [20628] = 1000000
    },
    event = {
        enabled = false,
        winner = nil,
        winnerName = nil,
        winnerWealth = 0,
        rewardTitle = 100,
        minWealth = 1000,
    },
    messages = {
        noPermission = "`4You don't have permission to use this command!",
        eventAlreadyRunning = "`4An event is already running!",
        eventNotRunning = "`4No event is currently running!",
        eventStarted = "`2Leaderboard Event Started!",
        eventFinished = "`6Leaderboard Event Finished!",
        eventStopped = "`4Leaderboard Event Stopped!",
        eventReset = "`eEvent has been reset.",
        winnerAnnouncement = "`6WINNER: %s with `2%s WL`6!",
        noQualifiers = "`4No players qualified for this event.",
        usage = "`4Usage: /lbevent [start|stop|finish|reset|off]",
        adminExcluded = "`8(Admins excluded from leaderboard)",
    }
}

local eventState = {
    enabled = false,
    winner = nil,
    winnerName = nil,
    winnerWealth = 0,
    scanResults = {}
}

local function formatNumber(n)
    if not n then return "0" end
    local formatted = tostring(math.floor(n))
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function isPlayerExcluded(player)
    if not player then return true end
    for roleID, _ in pairs(CONFIG.excludeRoles) do
        if player:hasRole(roleID) then
            return true
        end
    end
    return false
end

local function getPlayerWealth(player)
    if not player then return 0 end
    if isPlayerExcluded(player) then
        return 0
    end
    local total = 0
    for itemID, value in pairs(CONFIG.values) do
        local amount = player:getItemAmount(itemID)
        total = total + (amount * value)
    end
    return total
end

local function scanAllPlayers()
    local allPlayers = getAllPlayers()
    if not allPlayers then return {} end
    local results = {}
    local excludedCount = 0
    for _, p in ipairs(allPlayers) do
        if p and p.getCleanName then
            if isPlayerExcluded(p) then
                excludedCount = excludedCount + 1
                goto continue
            end
            local wealth = getPlayerWealth(p)
            if wealth >= CONFIG.event.minWealth then
                table.insert(results, {
                    name = p:getCleanName(),
                    wealth = wealth,
                    player = p
                })
            end
            ::continue::
        end
    end
    table.sort(results, function(a, b)
        return a.wealth > b.wealth
    end)
    return results, excludedCount
end

local function findWinner(results)
    if not results or #results == 0 then return nil end
    return results[1]
end

local function startEvent(player)
    if eventState.enabled then
        player:onConsoleMessage(CONFIG.messages.eventAlreadyRunning)
        player:playAudio("bleep_fail.wav")
        return true
    end
    eventState.enabled = true
    eventState.winner = nil
    eventState.winnerName = nil
    eventState.winnerWealth = 0
    local players = getServerPlayers()
    for _, p in ipairs(players) do
        p:onConsoleMessage(CONFIG.messages.eventStarted)
        if isPlayerExcluded(p) then
            p:onConsoleMessage("`8(You are excluded from leaderboard due to admin role)")
        end
        p:playAudio("success.wav")
    end
    return true
end

local function stopEvent(player)
    if not eventState.enabled then
        player:onConsoleMessage(CONFIG.messages.eventNotRunning)
        player:playAudio("bleep_fail.wav")
        return true
    end
    eventState.enabled = false
    local players = getServerPlayers()
    for _, p in ipairs(players) do
        p:onConsoleMessage(CONFIG.messages.eventStopped)
        p:playAudio("piano_nice.wav")
    end
    return true
end

local function finishEvent(player)
    if not eventState.enabled then
        player:onConsoleMessage(CONFIG.messages.eventNotRunning)
        player:playAudio("bleep_fail.wav")
        return true
    end
    local results, excludedCount = scanAllPlayers()
    local winner = findWinner(results)
    eventState.enabled = false
    eventState.scanResults = results
    local players = getServerPlayers()
    for _, p in ipairs(players) do
        p:onConsoleMessage(CONFIG.messages.eventFinished)
        if excludedCount > 0 then
            p:onConsoleMessage("`8(" .. excludedCount .. " admins excluded from leaderboard)")
        end
        p:playAudio("piano_nice.wav")
    end
    if winner then
        eventState.winner = winner.player
        eventState.winnerName = winner.name
        eventState.winnerWealth = winner.wealth
        if winner.player and CONFIG.event.rewardTitle then
            if not winner.player:hasTitle(CONFIG.event.rewardTitle) then
                winner.player:addTitle(CONFIG.event.rewardTitle)
            end
        end
        local msg = string.format(CONFIG.messages.winnerAnnouncement, 
            winner.name, formatNumber(winner.wealth))
        for _, p in ipairs(players) do
            p:onConsoleMessage(msg)
            p:playAudio("success.wav")
        end
    else
        for _, p in ipairs(players) do
            p:onConsoleMessage(CONFIG.messages.noQualifiers)
        end
    end
    return true
end

local function resetEvent(player)
    eventState.enabled = false
    eventState.winner = nil
    eventState.winnerName = nil
    eventState.winnerWealth = 0
    eventState.scanResults = {}
    player:onConsoleMessage(CONFIG.messages.eventReset)
    player:playAudio("piano_nice.wav")
    return true
end

local function offEvent(player)
    return stopEvent(player)
end

local function showLeaderboard(player)
    local results, excludedCount = scanAllPlayers()
    local dialog = {}
    table.insert(dialog, "add_label_with_icon|big|`wWealth Leaderboard|left|242|\n")
    table.insert(dialog, "add_spacer|small|\n")
    if eventState.enabled then
        table.insert(dialog, "add_textbox|`6EVENT ACTIVE|left|\n")
        table.insert(dialog, "add_spacer|small|\n")
    end
    if eventState.winnerName then
        table.insert(dialog, string.format(
            "add_textbox|`6Last Winner: %s - %s WL|left|\n",
            eventState.winnerName,
            formatNumber(eventState.winnerWealth)
        ))
        table.insert(dialog, "add_spacer|small|\n")
    end
    if excludedCount > 0 then
        table.insert(dialog, string.format(
            "add_textbox|`8(%d admin%s excluded)|left|\n",
            excludedCount,
            excludedCount > 1 and "s" or ""
        ))
        table.insert(dialog, "add_spacer|small|\n")
    end
    table.insert(dialog, "add_label|medium|`6Top 10 Richest Players|\n")
    local max = math.min(10, #results)
    for i = 1, max do
        local data = results[i]
        table.insert(dialog, string.format(
            "add_textbox|`e#%d `w%s - `2%s WL|left|\n",
            i,
            data.name,
            formatNumber(data.wealth)
        ))
    end
    if #results == 0 then
        table.insert(dialog, "add_textbox|`cNo players found with minimum wealth|left|\n")
    end
    table.insert(dialog, "add_spacer|small|\n")
    table.insert(dialog, "add_button|refresh|`2Refresh|noflags|\n")
    table.insert(dialog, "add_quick_exit|\n")
    table.insert(dialog, "end_dialog|leaderboard_dialog|||\n")
    player:onDialogRequest(table.concat(dialog))
    player:playAudio("audio/click.wav", 0)
end

registerLuaCommand({
    command = CONFIG.command,
    description = "Leaderboard event management",
    roleRequired = 0
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)$")
    if cmd ~= CONFIG.command then
        return false
    end
    if not args or args == "" then
        showLeaderboard(player)
        return true
    end
    local subCmd = args:lower()
    local isAdmin = player:hasRole(CONFIG.adminRole)
    if subCmd == "start" then
        if not isAdmin then
            player:onConsoleMessage(CONFIG.messages.noPermission)
            player:playAudio("bleep_fail.wav")
            return true
        end
        return startEvent(player)
    elseif subCmd == "stop" then
        if not isAdmin then
            player:onConsoleMessage(CONFIG.messages.noPermission)
            player:playAudio("bleep_fail.wav")
            return true
        end
        return stopEvent(player)
    elseif subCmd == "finish" then
        if not isAdmin then
            player:onConsoleMessage(CONFIG.messages.noPermission)
            player:playAudio("bleep_fail.wav")
            return true
        end
        return finishEvent(player)
    elseif subCmd == "reset" then
        if not isAdmin then
            player:onConsoleMessage(CONFIG.messages.noPermission)
            player:playAudio("bleep_fail.wav")
            return true
        end
        return resetEvent(player)
    elseif subCmd == "off" then
        if not isAdmin then
            player:onConsoleMessage(CONFIG.messages.noPermission)
            player:playAudio("bleep_fail.wav")
            return true
        end
        return offEvent(player)
    else
        player:onConsoleMessage(CONFIG.messages.usage)
        player:playAudio("thwoop.wav")
        return true
    end
end)

onPlayerDialogCallback(function(world, player, data)
    if data.dialog_name ~= "leaderboard_dialog" then
        return false
    end
    if data.buttonClicked == "refresh" then
        showLeaderboard(player)
        return true
    end
    return false
end)