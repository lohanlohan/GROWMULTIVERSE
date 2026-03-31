-- MODULE
-- commands.lua — Player utility commands (ported from roles-example.lua system)

local M = {}

local ROLE_NONE = 0
local ROLE_DEVELOPER = 51
local PlayerSubscriptions = {
    TYPE_SUPER_SUPPORTER = 1,
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

local function getCooldownRemaining(player, cooldownStore)
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
    local uid = getUID(player)
    if uid < 0 then
        return
    end

    cooldownStore[uid] = os.time() + TELEPORT_COOLDOWN_SECONDS
end

local function canUseFeatureCommands(player)
    return player:getSubscription(PlayerSubscriptions.TYPE_SUPER_SUPPORTER) ~= nil
end

local function isDeveloper(player)
    return player ~= nil and player.hasRole ~= nil and player:hasRole(ROLE_DEVELOPER)
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

registerLuaCommand({ command = "warp", roleRequired = ROLE_NONE, description = "Warp to another world." })
registerLuaCommand({ command = "back", roleRequired = ROLE_NONE, description = "Return to your previous world." })
registerLuaCommand({ command = "res", roleRequired = ROLE_NONE, description = "Respawn your character instantly." })
registerLuaCommand({ command = "respawn", roleRequired = ROLE_NONE, description = "Respawn your character instantly." })

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
        player:onConsoleMessage("`oThis command is only available for`$ Super Supporter`o players.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if cmd == "warp" then
        if not isDeveloper(player) then
            local remaining = getCooldownRemaining(player, warpCooldownUntil)
            if remaining > 0 then
                player:onConsoleMessage("`oPlease wait `w" .. tostring(remaining) .. "s`o before using`$ /warp`o again.")
                player:playAudio("bleep_fail.wav")
                return true
            end
        end

        local worldName, doorID = args:match("^(%S+)%s*(%S*)$")
        if worldName == nil or trim(worldName) == "" then
            player:onConsoleMessage("`oUsage: `w/warp <worldName> [doorID]")
            player:playAudio("thwoop.wav")
            return true
        end

        if warpPlayer(player, worldName, doorID) and not isDeveloper(player) then
            startCooldown(player, warpCooldownUntil)
        end
        return true
    end

    if cmd == "back" then
        if not isDeveloper(player) then
            local remaining = getCooldownRemaining(player, backCooldownUntil)
            if remaining > 0 then
                player:onConsoleMessage("`oPlease wait `w" .. tostring(remaining) .. "s`o before using`$ /back`o again.")
                player:playAudio("bleep_fail.wav")
                return true
            end
        end

        local history = ensureHistory(player)
        if history == nil or history.previous == "" then
            player:onConsoleMessage("`oNo previous world found for`$ /back`o.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        if warpPlayer(player, history.previous, "") and not isDeveloper(player) then
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

return M
