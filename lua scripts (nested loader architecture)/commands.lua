-- MODULE
-- commands.lua — Player utility commands (ported from roles-example.lua system)

local M = {}

local Roles = {
    ROLE_NONE = 0,
    ROLE_VIP = 1,
    ROLE_SUPER_VIP = 2,
    ROLE_MODERATOR = 3,
    ROLE_ADMIN = 4,
    ROLE_COMMUNITY_MANAGER = 5,
    ROLE_CREATOR = 6,
    ROLE_GOD = 7,
    ROLE_DEVELOPER = 51,
}

local TELEPORT_COOLDOWN_SECONDS = 25
local worldHistory = {}
local warpCooldownUntil = {}
local backCooldownUntil = {}

local function getUID(player)
    if player == nil or player.getUserID == nil then
        return -1
    end
    return player:getUserID()
end

local function trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$")
end

local function normalizeWorldName(worldName)
    return trim(worldName):upper()
end

local function normalizeDoorID(doorID)
    return trim(doorID):upper()
end

local function ensureHistory(player)
    local uid = getUID(player)
    if uid < 0 then
        return nil
    end
    if worldHistory[uid] == nil then
        worldHistory[uid] = { current = "", previous = "" }
    end
    return worldHistory[uid]
end

local function hasCooldownBypassRole(player)
    return player:hasRole(Roles.ROLE_DEVELOPER)
end

local function getCooldownRemaining(player, cooldownStore)
    if hasCooldownBypassRole(player) then
        return 0
    end

    local uid = getUID(player)
    if uid < 0 then
        return 0
    end

    local expiresAt = (cooldownStore and cooldownStore[uid]) or 0
    local remaining = expiresAt - os.time()
    if remaining < 0 then
        return 0
    end

    return remaining
end

local function startCooldown(player, cooldownStore)
    if hasCooldownBypassRole(player) then
        return
    end

    local uid = getUID(player)
    if uid < 0 then
        return
    end

    cooldownStore[uid] = os.time() + TELEPORT_COOLDOWN_SECONDS
end

local function canUseFeatureCommands(player)
    return player:hasRole(Roles.ROLE_VIP) or player:hasRole(Roles.ROLE_DEVELOPER)
end

local function forceRespawn(world, player)
    local activeWorld = world or player:getWorld()
    if activeWorld == nil or activeWorld.kill == nil then
        player:onConsoleMessage("`4Respawn is unavailable in this world state.")
        return false
    end

    activeWorld:kill(player)
    return true
end

local function warpPlayer(player, worldName, doorID)
    local targetWorld = normalizeWorldName(worldName)
    if targetWorld == "" then
        player:onConsoleMessage("`4Oops: `6You must enter a valid world name!``")
        return false
    end

    local targetDoor = normalizeDoorID(doorID or "")
    player:enterWorld(targetWorld, targetDoor)

    if targetDoor ~= "" then
        player:onTextOverlay("`0Magically warping to world `#" .. targetWorld .. "`0 (`wdoor: " .. targetDoor .. "`0)...")
    else
        player:onTextOverlay("`0Magically warping to world `#" .. targetWorld .. "`0...")
    end

    return true
end

registerLuaCommand({ command = "warp", roleRequired = Roles.ROLE_VIP, description = "Warp to another world." })
registerLuaCommand({ command = "back", roleRequired = Roles.ROLE_VIP, description = "Return to your previous world." })
registerLuaCommand({ command = "res", roleRequired = Roles.ROLE_VIP, description = "Respawn your character instantly." })
registerLuaCommand({ command = "respawn", roleRequired = Roles.ROLE_VIP, description = "Respawn your character instantly." })

onPlayerEnterWorldCallback(function(world, player)
    local history = ensureHistory(player)
    if history == nil then
        return false
    end

    local worldName = ""
    if world ~= nil and world.getName ~= nil then
        worldName = normalizeWorldName(world:getName())
    else
        worldName = normalizeWorldName(player:getWorldName())
    end

    if worldName ~= "" and history.current ~= worldName then
        history.previous = history.current
        history.current = worldName
    end

    return false
end)

onPlayerDisconnectCallback(function(player)
    local uid = getUID(player)
    if uid < 0 then
        return
    end

    worldHistory[uid] = nil
    warpCooldownUntil[uid] = nil
    backCooldownUntil[uid] = nil
end)

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)$")
    if cmd == nil then
        return false
    end

    cmd = cmd:lower():gsub("^/", "")
    if cmd ~= "warp" and cmd ~= "back" and cmd ~= "res" and cmd ~= "respawn" then
        return false
    end

    if not canUseFeatureCommands(player) then
        player:onConsoleMessage("`4You do not have permission to use this command.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if cmd == "warp" then
        local remaining = getCooldownRemaining(player, warpCooldownUntil)
        if remaining > 0 then
            player:onConsoleMessage("`4Please wait `w" .. tostring(remaining) .. "s`4 before using /warp again.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        local worldName, doorID = args:match("^(%S+)%s*(%S*)$")
        if worldName == nil or trim(worldName) == "" then
            player:onConsoleMessage("`oUsage: `w/warp <worldName> [doorID]")
            player:playAudio("thwoop.wav")
            return true
        end

        if warpPlayer(player, worldName, doorID) then
            startCooldown(player, warpCooldownUntil)
        end
        return true
    end

    if cmd == "back" then
        local remaining = getCooldownRemaining(player, backCooldownUntil)
        if remaining > 0 then
            player:onConsoleMessage("`4Please wait `w" .. tostring(remaining) .. "s`4 before using /back again.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        local history = ensureHistory(player)
        if history == nil or history.previous == "" then
            player:onConsoleMessage("`4No previous world found for /back.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        if warpPlayer(player, history.previous, "") then
            startCooldown(player, backCooldownUntil)
        end
        return true
    end

    if forceRespawn(world, player) then
        player:onTextOverlay("`2Respawned successfully.")
    else
        player:playAudio("bleep_fail.wav")
    end
    return true
end)

M.Roles = Roles
_G.RolesExample = Roles

return M
