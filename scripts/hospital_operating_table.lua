-- MODULE: OperatingTable Subsystem for Hospital
-- Handles Operating Table capacity, Surg-Bot lifecycle, and surgery resolution.

local OperatingTable = {}
local _statusBubbleGate = {}

local function getConfig(name, fallback)
    local value = rawget(_G, name)
    if value == nil then return fallback end
    return value
end

local function getWorldName(world, player)
    local fn = rawget(_G, "getWorldName")
    if type(fn) == "function" then
        return tostring(fn(world, player) or "")
    end
    if type(player) == "userdata" and player.getWorldName then
        return tostring(player:getWorldName() or "")
    end
    if type(world) == "userdata" and world.getName then
        return tostring(world:getName() or "")
    end
    return ""
end

local function getAllWorldTiles(world)
    local fn = rawget(_G, "getAllWorldTiles")
    if type(fn) == "function" then
        local rows = fn(world)
        if type(rows) == "table" then return rows end
    end
    if type(world) == "userdata" and world.getTiles then
        local rows = world:getTiles()
        if type(rows) == "table" then return rows end
    end
    return {}
end

local function loadHospital(worldName)
    local fn = rawget(_G, "loadHospital")
    if type(fn) == "function" then return fn(worldName) end
    return { level = 1, operating_tables = {} }
end

local function saveHospital(worldName, state)
    local fn = rawget(_G, "saveHospital")
    if type(fn) == "function" then fn(worldName, state) end
end

local function isEffectiveDoctor(world, worldName, userID, player)
    local fn = rawget(_G, "isEffectiveDoctor")
    if type(fn) == "function" then return fn(world, worldName, userID, player) end
    return false
end

local function getUserID(player)
    local fn = rawget(_G, "getUserID")
    if type(fn) == "function" then return tonumber(fn(player)) or 0 end
    if type(player) == "userdata" and player.getUserID then
        return tonumber(player:getUserID()) or 0
    end
    return 0
end

local function recordHospitalTreatment(worldName, maladyType, isSuccess)
    local fn = rawget(_G, "recordHospitalTreatment")
    if type(fn) == "function" then fn(worldName, maladyType, isSuccess) end
end

function OperatingTable.getOperatingTableCapacityByLevel(level)
    local required = getConfig("REQUIRED_OPERATING_TABLES", {})
    local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
    local base = tonumber(required[safeLevel]) or 0
    return math.max(1, base + 1)
end

function OperatingTable.getOperatingPatientDurationByLevel(level)
    local minSec = tonumber(getConfig("OPERATING_TABLE_DURATION_MIN_SEC", (24 * 60 + 5) * 60)) or ((24 * 60 + 5) * 60)
    local maxSec = tonumber(getConfig("OPERATING_TABLE_DURATION_MAX_SEC", (28 * 60 + 10) * 60)) or ((28 * 60 + 10) * 60)
    local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
    local bonus = math.floor(((safeLevel - 1) * 5) / 2) * 60
    return math.max(minSec, math.min(maxSec, minSec + bonus))
end

function OperatingTable.getOperatingRowKey(x, y)
    return tostring(math.floor(tonumber(x) or 0)) .. ":" .. tostring(math.floor(tonumber(y) or 0))
end

local function getSurgBotNameForTable(x, y)
    return "Surg-Bot " .. tostring(math.floor(tonumber(x) or 0)) .. ":" .. tostring(math.floor(tonumber(y) or 0))
end

local function formatDuration(seconds)
    local s = math.max(0, math.floor(tonumber(seconds) or 0))
    local h = math.floor(s / 3600)
    s = s - (h * 3600)
    local m = math.floor(s / 60)
    s = s - (m * 60)
    return string.format("%02dh %02dm %02ds", h, m, s)
end

local function buildOperatingStatusText(row, now)
    if tostring(row.status or "") == "active" then
        local remain = math.max(0, (tonumber(row.expire_at) or 0) - now)
        return "`2Operating Table``\n`w" .. formatDuration(remain) .. " to finish surgery``"
    end

    local nextSpawn = tonumber(row.next_spawn_at) or 0
    if nextSpawn > now then
        local remain = math.max(0, nextSpawn - now)
        return "`9Operating Table``\n`wNext Surg-Bot in " .. formatDuration(remain) .. "``"
    end

    return "`4Operating Table``\n`wOUT OF ORDER``"
end

local function emitOperatingStatusBubble(world, x, y, row, now)
    if type(world) ~= "userdata" or not world.onCreateChatBubble then return end
    local interval = tonumber(getConfig("OPERATING_STATUS_BUBBLE_INTERVAL_SEC", 5)) or 5
    local key = tostring(getWorldName(world)) .. ":" .. OperatingTable.getOperatingRowKey(x, y)
    local gate = _statusBubbleGate[key]
    local text = buildOperatingStatusText(row, now)

    if type(gate) == "table" then
        local nextAt = tonumber(gate.next_at) or 0
        local lastText = tostring(gate.text or "")
        if now < nextAt and lastText == text then return end
    end

    _statusBubbleGate[key] = { next_at = now + interval, text = text }
    local tx = math.floor(tonumber(x) or 0)
    local ty = math.floor(tonumber(y) or 0)

    -- Some runtimes interpret bubble coordinates as tile-space,
    -- others expect pixel-space. Emit both to maximize compatibility.
    pcall(function()
        world:onCreateChatBubble(tx, ty, text, 0)
    end)
    pcall(function()
        world:onCreateChatBubble((tx * 32) + 16, (ty * 32) + 16, text, 0)
    end)
end

function OperatingTable.debugEmitOperatingStatusBubble(world, x, y)
    if type(world) ~= "userdata" then return false end
    local worldName = getWorldName(world)
    if worldName == "" then return false end
    local now = os.time()
    local state = loadHospital(worldName)
    local row = OperatingTable.getOperatingStateRow(state, x, y, now)

    -- Bypass gate for manual debug ping.
    local key = tostring(worldName) .. ":" .. OperatingTable.getOperatingRowKey(x, y)
    _statusBubbleGate[key] = nil
    emitOperatingStatusBubble(world, x, y, row, now)
    return true
end

function OperatingTable.getOperatingStateRow(state, x, y, now)
    state.operating_tables = state.operating_tables or {}
    local key = OperatingTable.getOperatingRowKey(x, y)
    local row = state.operating_tables[key]
    if type(row) ~= "table" then
        row = {
            status = "idle",
            spawned_at = 0,
            expire_at = 0,
            next_spawn_at = tonumber(now) or 0,
            npc_name = ""
        }
        state.operating_tables[key] = row
    end
    row.status = tostring(row.status or "idle")
    row.spawned_at = tonumber(row.spawned_at) or 0
    row.expire_at = tonumber(row.expire_at) or 0
    row.next_spawn_at = tonumber(row.next_spawn_at) or (tonumber(now) or 0)
    row.npc_name = tostring(row.npc_name or "")
    return row, key
end

local function findOperatingTileByPlayer(world, target)
    local operatingTableID = tonumber(getConfig("OPERATING_TABLE_ID", 14662)) or 14662
    if type(world) ~= "userdata" or type(target) ~= "userdata" then return nil end
    local tx = math.floor((tonumber(target:getPosX()) or 0) / 32)
    local ty = math.floor((tonumber(target:getPosY()) or 0) / 32)
    local tile = world:getTile(tx, ty)
    if not tile or tile:getTileID() ~= operatingTableID then return nil end
    return tile
end

function OperatingTable.processOperatingTablesInWorld(world, now)
    if type(world) ~= "userdata" then return end
    local worldName = getWorldName(world)
    if worldName == "" then return end

    local spawnInterval = tonumber(getConfig("SURGBOT_SPAWN_INTERVAL_SEC", 24 * 60 * 60)) or (24 * 60 * 60)
    local operatingTableID = tonumber(getConfig("OPERATING_TABLE_ID", 14662)) or 14662

    local state = loadHospital(worldName)
    local level = tonumber(state.level) or 1
    local durationSec = OperatingTable.getOperatingPatientDurationByLevel(level)
    local changed = false
    local activeTableKeys = {}

    for _, tile in pairs(getAllWorldTiles(world)) do
        if tile and tile:getTileID() == operatingTableID then
            local x = tile:getPosX()
            local y = tile:getPosY()
            local row, key = OperatingTable.getOperatingStateRow(state, x, y, now)
            activeTableKeys[key] = true

            if row.status == "active" then
                if now >= row.expire_at then
                    if row.npc_name ~= "" and world.findNPCByName and world.removeNPC then
                        local npc = world:findNPCByName(row.npc_name)
                        if npc then world:removeNPC(npc) end
                    end
                    row.status = "idle"
                    row.spawned_at = 0
                    row.expire_at = 0
                    row.next_spawn_at = now + spawnInterval
                    row.npc_name = ""
                    changed = true
                    recordHospitalTreatment(worldName, nil, false)
                end
            elseif now >= row.next_spawn_at then
                if world.createNPC then
                    local npcName = getSurgBotNameForTable(x, y)
                    if world.findNPCByName and world.removeNPC then
                        local existingNpc = world:findNPCByName(npcName)
                        if existingNpc then world:removeNPC(existingNpc) end
                    end
                    local npc = world:createNPC(npcName, x, y)
                    if npc then
                        row.status = "active"
                        row.spawned_at = now
                        row.expire_at = now + durationSec
                        row.next_spawn_at = now + spawnInterval
                        row.npc_name = npcName
                        changed = true
                    end
                end
            end

            emitOperatingStatusBubble(world, x, y, row, now)
        end
    end

    for key in pairs(state.operating_tables or {}) do
        if not activeTableKeys[key] then
            state.operating_tables[key] = nil
            changed = true
        end
    end

    if changed then saveHospital(worldName, state) end
end

function OperatingTable.resolveOperatingTableSurgery(world, surgeon, targetPlayer)
    if type(world) ~= "userdata" or type(surgeon) ~= "userdata" or type(targetPlayer) ~= "userdata" then
        return false
    end

    local spawnInterval = tonumber(getConfig("SURGBOT_SPAWN_INTERVAL_SEC", 24 * 60 * 60)) or (24 * 60 * 60)
    local tableTile = findOperatingTileByPlayer(world, targetPlayer)
    if not tableTile then return false end

    local worldName = getWorldName(world, surgeon)
    local doctorAllowed = isEffectiveDoctor(world, worldName, getUserID(surgeon), surgeon)
    if not doctorAllowed then return false end

    local now = os.time()
    local state = loadHospital(worldName)
    local row = OperatingTable.getOperatingStateRow(state, tableTile:getPosX(), tableTile:getPosY(), now)
    if row.status ~= "active" then return false end

    row.status = "idle"
    row.spawned_at = 0
    row.expire_at = 0
    row.next_spawn_at = now + spawnInterval

    if row.npc_name ~= "" and world.findNPCByName and world.removeNPC then
        local npc = world:findNPCByName(row.npc_name)
        if npc then world:removeNPC(npc) end
    end
    row.npc_name = ""

    saveHospital(worldName, state)
    recordHospitalTreatment(worldName, nil, true)
    return true
end

function OperatingTable.clearOperatingTable(world, worldName, x, y)
    local state = loadHospital(worldName)
    local key = OperatingTable.getOperatingRowKey(x, y)
    _statusBubbleGate[tostring(worldName) .. ":" .. key] = nil
    local row = state.operating_tables and state.operating_tables[key] or nil

    if row and type(row) == "table" and row.npc_name and row.npc_name ~= "" and type(world) == "userdata" and world.findNPCByName and world.removeNPC then
        local npc = world:findNPCByName(row.npc_name)
        if npc then world:removeNPC(npc) end
    end

    if state.operating_tables then
        state.operating_tables[key] = nil
        saveHospital(worldName, state)
    end
end

return OperatingTable
