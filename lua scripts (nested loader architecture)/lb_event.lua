-- MODULE
-- lb_event.lua — /lbevent: wealth leaderboard event management

local M = {}

local ADMIN_ROLE = 51
local EXCLUDE_ROLES = { [51] = true }

local ITEMS = { WL = 242, DL = 1796, BGL = 7188, BBGL = 20628 }
local VALUES = { [242]=1, [1796]=100, [7188]=10000, [20628]=1000000 }
local MIN_WEALTH  = 1000
local REWARD_TITLE = 100

local eventState = {
    enabled     = false,
    winnerName  = nil,
    winnerWealth = 0,
    scanResults = {},
}

local function formatNumber(n)
    if not n then return "0" end
    local s = tostring(math.floor(n))
    while true do
        local res, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
        s = res
    end
    return s
end

local function isExcluded(player)
    if not player then return true end
    for roleID in pairs(EXCLUDE_ROLES) do
        if player:hasRole(roleID) then return true end
    end
    return false
end

local function getWealth(player)
    if not player or isExcluded(player) then return 0 end
    local total = 0
    for itemID, value in pairs(VALUES) do
        total = total + ((player:getItemAmount(itemID) or 0) * value)
    end
    return total
end

local function scanAll()
    local results, excluded = {}, 0
    for _, p in ipairs(getServerPlayers() or {}) do
        if p and p.getCleanName then
            if isExcluded(p) then
                excluded = excluded + 1
            else
                local w = getWealth(p)
                if w >= MIN_WEALTH then
                    results[#results+1] = { name = p:getCleanName(), wealth = w, player = p }
                end
            end
        end
    end
    table.sort(results, function(a, b) return a.wealth > b.wealth end)
    return results, excluded
end

local function broadcastAll(msg)
    for _, p in ipairs(getServerPlayers()) do p:onConsoleMessage(msg) end
end

local function startEvent(player)
    if eventState.enabled then
        player:onConsoleMessage("`4An event is already running!")
        player:playAudio("bleep_fail.wav")
        return true
    end
    eventState.enabled = true
    eventState.winnerName = nil
    eventState.winnerWealth = 0
    for _, p in ipairs(getServerPlayers()) do
        p:onConsoleMessage("`2Leaderboard Event Started!")
        if isExcluded(p) then p:onConsoleMessage("`8(You are excluded from leaderboard due to admin role)") end
        p:playAudio("success.wav")
    end
    return true
end

local function stopEvent(player)
    if not eventState.enabled then
        player:onConsoleMessage("`4No event is currently running!")
        player:playAudio("bleep_fail.wav")
        return true
    end
    eventState.enabled = false
    broadcastAll("`4Leaderboard Event Stopped!")
    for _, p in ipairs(getServerPlayers()) do p:playAudio("piano_nice.wav") end
    return true
end

local function finishEvent(player)
    if not eventState.enabled then
        player:onConsoleMessage("`4No event is currently running!")
        player:playAudio("bleep_fail.wav")
        return true
    end
    local results, excludedCount = scanAll()
    eventState.enabled = false
    eventState.scanResults = results
    broadcastAll("`6Leaderboard Event Finished!")
    for _, p in ipairs(getServerPlayers()) do
        if excludedCount > 0 then p:onConsoleMessage("`8(" .. excludedCount .. " admins excluded)") end
        p:playAudio("piano_nice.wav")
    end
    local winner = results[1]
    if winner then
        eventState.winnerName   = winner.name
        eventState.winnerWealth = winner.wealth
        if winner.player and REWARD_TITLE then
            if not winner.player:hasTitle(REWARD_TITLE) then
                winner.player:addTitle(REWARD_TITLE)
            end
        end
        local msg = string.format("`6WINNER: %s with `2%s WL`6!", winner.name, formatNumber(winner.wealth))
        for _, p in ipairs(getServerPlayers()) do p:onConsoleMessage(msg); p:playAudio("success.wav") end
    else
        broadcastAll("`4No players qualified for this event.")
    end
    return true
end

local function resetEvent(player)
    eventState.enabled = false
    eventState.winnerName = nil
    eventState.winnerWealth = 0
    eventState.scanResults = {}
    player:onConsoleMessage("`eEvent has been reset.")
    player:playAudio("piano_nice.wav")
    return true
end

local function showLeaderboard(player)
    local results, excludedCount = scanAll()
    local d = {}
    d[#d+1] = "add_label_with_icon|big|`wWealth Leaderboard|left|242|\n"
    d[#d+1] = "add_spacer|small|\n"
    if eventState.enabled then
        d[#d+1] = "add_textbox|`6EVENT ACTIVE|left|\n"
        d[#d+1] = "add_spacer|small|\n"
    end
    if eventState.winnerName then
        d[#d+1] = string.format("add_textbox|`6Last Winner: %s - %s WL|left|\n",
            eventState.winnerName, formatNumber(eventState.winnerWealth))
        d[#d+1] = "add_spacer|small|\n"
    end
    if excludedCount > 0 then
        d[#d+1] = string.format("add_textbox|`8(%d admin%s excluded)|left|\n",
            excludedCount, excludedCount > 1 and "s" or "")
        d[#d+1] = "add_spacer|small|\n"
    end
    d[#d+1] = "add_label|medium|`6Top 10 Richest Players|\n"
    for i = 1, math.min(10, #results) do
        local entry = results[i]
        d[#d+1] = string.format("add_textbox|`e#%d `w%s - `2%s WL|left|\n", i, entry.name, formatNumber(entry.wealth))
    end
    if #results == 0 then
        d[#d+1] = "add_textbox|`cNo players found with minimum wealth|left|\n"
    end
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_button|refresh|`2Refresh|noflags|\n"
    d[#d+1] = "add_quick_exit|\n"
    d[#d+1] = "end_dialog|leaderboard_dialog|||\n"
    player:onDialogRequest(table.concat(d))
    player:playAudio("audio/click.wav", 0)
end

registerLuaCommand({ command = "lbevent", roleRequired = 0, description = "Leaderboard event management." })

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "lbevent" then return false end

    if not args or args == "" then showLeaderboard(player); return true end

    local isAdmin = player:hasRole(ADMIN_ROLE)
    local sub = args:lower()

    if sub == "start" then
        if not isAdmin then player:onConsoleMessage("`4You don't have permission!"); player:playAudio("bleep_fail.wav"); return true end
        return startEvent(player)
    elseif sub == "stop" or sub == "off" then
        if not isAdmin then player:onConsoleMessage("`4You don't have permission!"); player:playAudio("bleep_fail.wav"); return true end
        return stopEvent(player)
    elseif sub == "finish" then
        if not isAdmin then player:onConsoleMessage("`4You don't have permission!"); player:playAudio("bleep_fail.wav"); return true end
        return finishEvent(player)
    elseif sub == "reset" then
        if not isAdmin then player:onConsoleMessage("`4You don't have permission!"); player:playAudio("bleep_fail.wav"); return true end
        return resetEvent(player)
    else
        player:onConsoleMessage("`4Usage: /lbevent [start|stop|finish|reset]")
        return true
    end
end)

onPlayerDialogCallback(function(world, player, data)
    if data.dialog_name ~= "leaderboard_dialog" then return false end
    if data.buttonClicked == "refresh" then showLeaderboard(player); return true end
    return false
end)

return M
