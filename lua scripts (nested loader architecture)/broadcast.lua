-- MODULE
-- broadcast.lua — Role-based server broadcasts: /lsb /osb /ssb /scsb

local M = {}

local ROLE = {
    LORD           = 2,
    OVERLORD       = 3,
    SUPREME        = 4,
    MODERATOR      = 6,
    SERVER_CREATOR = 12,
    DEVELOPER      = 51,
}

local SFX = {
    LSB  = { "audio/terraform.wav", "audio/beep.wav" },
    OSB  = { "audio/friend_logon.wav", "audio/beep.wav" },
    SSB  = { "audio/double_chance.wav", "audio/beep.wav" },
    MODS = "audio/secret.wav",
    SC   = "audio/already_used.wav",
}

local BROADCAST_COST = {
    lsb = { perPlayer = 100, maxCost = 500000 },
    osb = { perPlayer = 200, maxCost = 1000000 },
    ssb = { perPlayer = 400, maxCost = 2000000 },
}

-- Groups define who can use each command and which sfx plays
local GROUPS = {
    lsb  = { roles = { ROLE.LORD, ROLE.OVERLORD, ROLE.SUPREME }, sfx = SFX.LSB },
    osb  = { roles = { ROLE.OVERLORD, ROLE.SUPREME },            sfx = SFX.OSB },
    ssb  = { roles = { ROLE.SUPREME },                           sfx = SFX.SSB },
    scsb = { roles = { ROLE.SERVER_CREATOR, ROLE.DEVELOPER },    sfx = SFX.SC  },
}

registerLuaCommand({ command = "lsb",  roleRequired = ROLE.LORD,           description = "Lord / Overlord / Supreme Broadcast" })
registerLuaCommand({ command = "osb",  roleRequired = ROLE.OVERLORD,       description = "Overlord / Supreme Broadcast" })
registerLuaCommand({ command = "ssb",  roleRequired = ROLE.SUPREME,        description = "Supreme Broadcast" })
registerLuaCommand({ command = "scsb", roleRequired = ROLE.SERVER_CREATOR, description = "Server Creator / Developer Broadcast" })

-- ============================================================================
-- HELPERS
-- ============================================================================
local function allPlayers()
    if type(getServerPlayers) == "function" then return getServerPlayers() end
    return {}
end

local function hasAny(player, roles)
    if not player or not player.hasRole then return false end
    for _, r in ipairs(roles) do
        if player:hasRole(r) then return true end
    end
    return false
end

local function pickSfx(soundFile)
    if type(soundFile) == "table" then return soundFile[1] or "audio/beep.wav" end
    if type(soundFile) == "string" and soundFile ~= "" then return soundFile end
    return "audio/beep.wav"
end

local function playSfx(player, soundFile)
    if not player or not player.sendAction or not soundFile then return end
    if type(soundFile) == "table" then
        for _, f in ipairs(soundFile) do
            if type(f) == "string" and f ~= "" then
                player:sendAction("action|play_sfx\nfile|" .. f .. "\ndelayMS|0")
            end
        end
    elseif type(soundFile) == "string" and soundFile ~= "" then
        player:sendAction("action|play_sfx\nfile|" .. soundFile .. "\ndelayMS|0")
    end
end

local function calcCost(cmd, onlineCount)
    local cfg = BROADCAST_COST[cmd]
    if not cfg then return 0 end
    return math.min(cfg.perPlayer * math.max(onlineCount, 0), cfg.maxCost)
end

local function tagFor(cmd, player)
    if cmd == "lsb" then
        if hasAny(player, { ROLE.LORD, ROLE.OVERLORD, ROLE.SUPREME }) then
            return "`eLord-Broadcast"
        end
    elseif cmd == "osb" then
        if hasAny(player, { ROLE.OVERLORD, ROLE.SUPREME }) then
            return "`4Overlord-Broadcast"
        end
    elseif cmd == "ssb" then
        if player:hasRole(ROLE.SUPREME) then return "`bSupreme-Broadcast" end
    elseif cmd == "scsb" then
        if player:hasRole(ROLE.DEVELOPER)      then return "`@Developer" end
        if player:hasRole(ROLE.SERVER_CREATOR) then return "`@Server-Creator" end
    end
    return nil
end

-- ============================================================================
-- BROADCAST LOGIC
-- ============================================================================
local function broadcastAll(sender, tag, msg, soundFile, usedGems, world)
    local sname = sender:getName()
    local wname = sender:getWorldName()
    local suid  = sender:getUserID()
    local isJammed = world and world:hasFlag(1) or false
    local displayWorld = isJammed and "`4JAMMED`o" or wname

    local text = string.format("`5** [%s`5] ** from (%s`5) in [`$%s`5] ** : `$%s",
        tag, sname, displayWorld, msg)

    local currentGems = sender:getGems() or 0
    sender:onConsoleMessage(string.format(
        ">> %s `osent. Used `$%d Gems`o. `o(%d left)", tag, usedGems, currentGems))

    for _, p in ipairs(allPlayers()) do
        p:onConsoleMessage(text)
        playSfx(p, soundFile)
    end
end

local function atomicNoticeAll(sender, tag, msg)
    local sname = sender:getName()
    local title = string.format("`0[%s]`w %s\n`w%s", tag, sname, msg)

    sender:onConsoleMessage(">> " .. tag .. " sent.")

    for _, p in ipairs(allPlayers()) do
        if p and p.sendVariant then
            p:sendVariant({
                "OnAddNotification",
                "interface/large/atomic_button.rttex",
                title,
                pickSfx(SFX.SC),
                0
            })
        end
    end
end

-- ============================================================================
-- COMMAND HANDLER
-- ============================================================================
onPlayerCommandCallback(function(world, player, full)
    if type(full) ~= "string" then return false end
    local rawCmd, msg = full:match("^(%S+)%s*(.*)$")
    if not rawCmd then return false end
    local cmd  = rawCmd:lower():gsub("^/", "")
    local meta = GROUPS[cmd]
    if not meta then return false end

    msg = (msg or ""):gsub("^%s+", "")
    if msg == "" then
        player:onConsoleMessage("Usage: /" .. cmd .. " <message>")
        return true
    end

    if not hasAny(player, meta.roles) then
        player:onConsoleMessage("`4Unknown command. `oEnter `$/help `ofor a list of valid commands.")
        return true
    end

    local tag = tagFor(cmd, player)
    if not tag then
        player:onConsoleMessage("`4Unknown command. `oEnter `$/help `ofor a list of valid commands.")
        return true
    end

    local usedGems = 0
    if BROADCAST_COST[cmd] then
        usedGems = calcCost(cmd, #allPlayers())
        local currentGems = player:getGems() or 0
        if currentGems < usedGems then
            player:onConsoleMessage(string.format(
                "`4Not enough Gems. Need `$%d Gems`o, you have `$%d Gems`o.", usedGems, currentGems))
            return true
        end
        if not player:removeGems(usedGems, 1, 1) then
            player:onConsoleMessage("`4Failed to deduct Gems. Please try again.")
            return true
        end
    end

    if cmd == "scsb" then
        atomicNoticeAll(player, tag, msg)
    else
        broadcastAll(player, tag, msg, meta.sfx, usedGems, world)
    end

    return true
end)

return M
