-- Roles Example script

Roles = {
    ROLE_NONE = 0,
    ROLE_VIP = 1,
    ROLE_SUPER_VIP = 2,
    ROLE_MODERATOR = 3,
    ROLE_ADMIN = 4,
    ROLE_COMMUNITY_MANAGER = 5,
    ROLE_CREATOR = 6,
    ROLE_GOD = 7,
    ROLE_DEVELOPER = 51
}

local warp = {
    command = "warp",
    roleRequired = Roles.ROLE_VIP,
    description = "This command allows you to warp to another world"
}

local backCommandData = {
    command = "back",
    roleRequired = Roles.ROLE_VIP,
    description = "Return to your previous world"
}

local resCommandData = {
    command = "res",
    roleRequired = Roles.ROLE_VIP,
    description = "Respawn your character instantly"
}

local respawnCommandData = {
    command = "respawn",
    roleRequired = Roles.ROLE_VIP,
    description = "Respawn your character instantly"
}

local removePlaymodsCommandData = {
    command = "removeplaymods",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Remove all playmods from a player"
}

registerLuaCommand(warp)
registerLuaCommand(backCommandData)
registerLuaCommand(resCommandData)
registerLuaCommand(respawnCommandData)
registerLuaCommand(removePlaymodsCommandData)

---------------------------------------
-- WARP FUNCTION
---------------------------------------

local worldHistory = {} -- [userID] = { current = "WORLD", previous = "WORLD" }
local warpCooldownUntil = {} -- [userID] = unix timestamp
local backCooldownUntil = {} -- [userID] = unix timestamp
local TELEPORT_COOLDOWN_SECONDS = 25

local function getUserID(player)
    if not player or not player.getUserID then
        return -1
    end
    return player:getUserID()
end

local function normalizeWorldName(worldName)
    if type(worldName) ~= "string" then
        return ""
    end
    return worldName:upper()
end

local function normalizeDoorID(doorID)
    if type(doorID) ~= "string" then
        return ""
    end
    return doorID:upper()
end

local function trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$")
end

local function ensureHistory(player)
    local uid = getUserID(player)
    if uid < 0 then
        return nil
    end
    if not worldHistory[uid] then
        worldHistory[uid] = { current = "", previous = "" }
    end
    return worldHistory[uid]
end

local function hasCooldownBypassRole(player)
    if not player then
        return false
    end

    if player.getRoles then
        local roles = player:getRoles() or {}
        for i = 1, #roles do
            local roleEntry = roles[i]
            local roleID = nil

            if type(roleEntry) == "number" then
                roleID = roleEntry
            elseif type(roleEntry) == "table" then
                roleID = roleEntry.roleID or roleEntry.id
            end

            if type(roleID) == "number" and roleID > 10 then
                return true
            end
        end
    end

    if player.hasRole and player:hasRole(Roles.ROLE_DEVELOPER) then
        return true
    end

    return false
end

local function getCooldownRemaining(player, cooldownStore)
    if hasCooldownBypassRole(player) then
        return 0
    end

    local uid = getUserID(player)
    if uid < 0 then
        return 0
    end

    local now = os.time()
    local expiresAt = (cooldownStore and cooldownStore[uid]) or 0
    local remaining = expiresAt - now

    if remaining < 0 then
        return 0
    end

    return remaining
end

local function startCooldown(player, cooldownStore)
    if hasCooldownBypassRole(player) then
        return
    end

    local uid = getUserID(player)
    if uid < 0 then
        return
    end

    if cooldownStore then
        cooldownStore[uid] = os.time() + TELEPORT_COOLDOWN_SECONDS
    end
end

local function canUseFeatureCommands(player)
    if not player or not player.hasRole then
        return false
    end
    return player:hasRole(Roles.ROLE_VIP) or player:hasRole(Roles.ROLE_DEVELOPER)
end

local function isDeveloper(player)
    if not player or not player.hasRole then
        return false
    end
    return player:hasRole(Roles.ROLE_DEVELOPER)
end

local function forceRespawn(world, player)
    if not player then
        return false
    end

    local activeWorld = world
    if (not activeWorld) and player.getWorld then
        activeWorld = player:getWorld()
    end

    if not activeWorld or not activeWorld.kill then
        return false
    end

    -- Real death flow: player dies first, then server respawn handles it.
    activeWorld:kill(player)
    return true
end

local function removeAllPlaymods(player)
    if not player or not player.setPlaymodStatus then
        return false
    end
    
    -- Set playmod status to 0 to remove all playmods
    player:setPlaymodStatus(0)
    return true
end

onPlayerEnterWorldCallback(function(world, player)
    local history = ensureHistory(player)
    if not history then
        return false
    end

    local worldName = ""
    if world and world.getName then
        worldName = normalizeWorldName(world:getName())
    elseif player and player.getWorldName then
        worldName = normalizeWorldName(player:getWorldName())
    end

    if worldName ~= "" and history.current ~= worldName then
        history.previous = history.current
        history.current = worldName
    end

    return false
end)

onPlayerDisconnectCallback(function(player)
    local uid = getUserID(player)
    if uid >= 0 then
        worldHistory[uid] = nil
        warpCooldownUntil[uid] = nil
        backCooldownUntil[uid] = nil
    end
end)

local function warpPlayer(player, worldName, doorID)
    if not worldName or worldName == "" then
        player:onConsoleMessage("`4Oops: `6You must enter a world name!``")
        return false
    end

    if not player.enterWorld then
        player:onConsoleMessage("`4Warp is unavailable on this server build.`")
        return false
    end

    local targetWorld = normalizeWorldName(trim(worldName))
    local targetDoor = normalizeDoorID(trim(doorID or ""))

    if targetWorld == "" then
        player:onConsoleMessage("`4Oops: `6You must enter a valid world name!``")
        return false
    end

    if targetDoor ~= "" then
        player:enterWorld(targetWorld, targetDoor)
    else
        player:enterWorld(targetWorld, "")
    end

    -- Use enterWorld directly so /warp behavior is controlled by this script.
    if player.onTextOverlay then
        if targetDoor ~= "" then
            player:onTextOverlay("`0Magically warping to world `#" .. targetWorld .. "`0 (`wdoor: " .. targetDoor .. "`0)...")
        else
            player:onTextOverlay("`0Magically warping to world `#" .. targetWorld .. "`0...")
        end
    end
    return true
end

---------------------------------------
-- COMMAND CALLBACK
---------------------------------------

onPlayerCommandCallback(function(world, player, command)
    if type(command) ~= "string" then
        return false
    end

    local rawCmd, args = command:match("^(%S+)%s*(.*)$")
    if not rawCmd then
        return false
    end

    local cmd = rawCmd:lower():gsub("^/", "")
    args = (args or ""):gsub("^%s+", "")

    if cmd == backCommandData.command then
        if not canUseFeatureCommands(player) then
            player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
            return true
        end

        local cooldownLeft = getCooldownRemaining(player, backCooldownUntil)
        if cooldownLeft > 0 then
            player:onConsoleMessage("`oPlease wait `w" .. cooldownLeft .. "`os before using `$/back `oagain.")
            return true
        end

        local history = ensureHistory(player)
        local targetWorld = history and normalizeWorldName(history.previous) or ""
        if targetWorld == "" then
            player:onConsoleMessage("`oNo previous world found for `$/back`o.")
            return true
        end

        
        player:enterWorld(targetWorld, "")
        startCooldown(player, backCooldownUntil)

        if player.onTextOverlay then
            player:onTextOverlay("`0Magically back to world `#" .. targetWorld .. "`0...")
        end
        return true
    end

    if cmd == resCommandData.command or cmd == respawnCommandData.command then
        if not canUseFeatureCommands(player) then
            player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
            return true
        end

        if forceRespawn(world, player) then
            player:onConsoleMessage("`oYou died and respawned.`")
        else
            player:onConsoleMessage("`4Failed to respawn. world:kill(player) is unavailable.")
        end
        return true
    end
    
    if cmd == warp.command then
        local isHighRole = hasCooldownBypassRole(player)
        if not player:hasRole(warp.roleRequired) and not isHighRole then
            player:onConsoleMessage("`4Oops: `6You need `#VIP`` role to use this command!``")
            return true
        end

        local cooldownLeft = getCooldownRemaining(player, warpCooldownUntil)
        if cooldownLeft > 0 then
            player:onConsoleMessage("`oPlease wait `w" .. cooldownLeft .. "`os before using `$/warp `oagain.")
            return true
        end

        if args == "" then
            player:onConsoleMessage("`oUsage: `$/warp <world> `oor `$/warp <world>|<doorID>``")
            return true
        end

        local worldTarget = args
        local doorTarget = ""
        local splitWorld, splitDoor = args:match("^([^|]*)|(.+)$")

        if splitWorld then
            if not isHighRole then
                player:onConsoleMessage("`4Only roles above ID 10 can use door target syntax: /warp <world>|<doorID>.")
                return true
            end

            worldTarget = trim(splitWorld)
            doorTarget = trim(splitDoor)
            if doorTarget == "" then
                player:onConsoleMessage("`4Invalid syntax. Use /warp <world>|<doorID> or /warp |<doorID>.")
                return true
            end

            if worldTarget == "" then
                if player.getWorldName then
                    worldTarget = trim(player:getWorldName() or "")
                end
                if worldTarget == "" then
                    player:onConsoleMessage("`4Failed to detect current world for /warp |<doorID>.")
                    return true
                end
            end
        end

        if warpPlayer(player, worldTarget, doorTarget) then
            startCooldown(player, warpCooldownUntil)
        end
        return true
    end
    
    if cmd == removePlaymodsCommandData.command then
        if not isDeveloper(player) then
            player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
            return true
        end

        if removeAllPlaymods(player) then
            player:onConsoleMessage("`2All playmods have been removed!")
        else
            player:onConsoleMessage("`4Failed to remove playmods. setPlaymodStatus() is unavailable.")
        end
        return true
    end
    
    return false
end)

