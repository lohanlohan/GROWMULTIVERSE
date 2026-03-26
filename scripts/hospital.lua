-- MODULE

local MaladySystem = require("malady_rng.plua")

local HospitalSystem = {}

-- =======================================================
-- CONFIG
-- =======================================================

local ROLE_DEVELOPER = 51

local RECEPTION_DESK_ID = 14668
local AUTO_SURGEON_ID   = 14666
local WORLD_LOCK_ID     = 242
local WORLD_KEY_ID      = 1424

local MIN_CURE_PRICE_WL = 3
local CURE_TAX_WL       = 2
local MAX_TOOL_STORAGE  = 1000

local HOSPITAL_LEVELS = {
    [1] = { next_level = 2, required_surgeries = 25,  upgrade_gems = 1000000,  upgrade_wl = 1000  },
    [2] = { next_level = 3, required_surgeries = 50,  upgrade_gems = 10000000, upgrade_wl = 10000 },
    [3] = { next_level = nil, required_surgeries = 0, upgrade_gems = 0,        upgrade_wl = 0     }
}

local MALADY_UNLOCK_LEVEL = {
    CHICKEN_FEET         = 1,
    GRUMBLETEETH         = 1,
    TORN_PUNCHING_MUSCLE = 2,
    GEMS_CUTS            = 2,
    AUTOMATION_CURSE     = 3,
    BROKEN_HEARTS        = 3,
    CHAOS_INFECTION      = 4,
    LUPUS                = 4,
    BRAINWORMS           = 4,
    MOLDY_GUTS           = 4,
    ECTO_BONES           = 4,
    FATTY_LIVER          = 4
}

-- Icon per malady di owner panel
-- Vile Vial maladies pakai icon vial mereka sendiri
-- RNG maladies pakai placeholder (ganti iconID sesuai kebutuhan)
local MALADY_ICON = {
    CHICKEN_FEET         = 14668, -- placeholder
    GRUMBLETEETH         = 14668, -- placeholder
    TORN_PUNCHING_MUSCLE = 14668, -- placeholder
    GEMS_CUTS            = 14668, -- placeholder
    AUTOMATION_CURSE     = 20704,
    BROKEN_HEARTS        = 14668, -- placeholder
    CHAOS_INFECTION      = 8538,
    LUPUS                = 8544,
    BRAINWORMS           = 8542,
    MOLDY_GUTS           = 8540,
    ECTO_BONES           = 8546,
    FATTY_LIVER          = 8548,
}

-- Urutan tampil di UI: vile vial dulu, RNG di bawahnya
local MALADY_UI_VIAL = {
    MaladySystem.MALADY.CHAOS_INFECTION,
    MaladySystem.MALADY.LUPUS,
    MaladySystem.MALADY.BRAINWORMS,
    MaladySystem.MALADY.MOLDY_GUTS,
    MaladySystem.MALADY.ECTO_BONES,
    MaladySystem.MALADY.FATTY_LIVER,
}

local MALADY_UI_RNG = {
    MaladySystem.MALADY.CHICKEN_FEET,
    MaladySystem.MALADY.GRUMBLETEETH,
    MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    MaladySystem.MALADY.GEMS_CUTS,
    MaladySystem.MALADY.BROKEN_HEARTS,
    MaladySystem.MALADY.AUTOMATION_CURSE,
}

local ALL_SURGICAL_TOOLS = {
    1258, 1260, 1262, 1264, 1266, 1268, 1270,
    4308, 4310, 4312, 4314, 4316, 4318
}

local TOOL_REQUIREMENT = {}
for _, maladyType in pairs(MaladySystem.MALADY) do
    TOOL_REQUIREMENT[maladyType] = {}
    for _, toolID in ipairs(ALL_SURGICAL_TOOLS) do
        TOOL_REQUIREMENT[maladyType][toolID] = 1
    end
end

local AUTO_SURGEON_MALADY_ORDER = {
    MaladySystem.MALADY.CHICKEN_FEET,
    MaladySystem.MALADY.GRUMBLETEETH,
    MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    MaladySystem.MALADY.GEMS_CUTS,
    MaladySystem.MALADY.AUTOMATION_CURSE,
    MaladySystem.MALADY.BROKEN_HEARTS,
    MaladySystem.MALADY.CHAOS_INFECTION,
    MaladySystem.MALADY.LUPUS,
    MaladySystem.MALADY.BRAINWORMS,
    MaladySystem.MALADY.MOLDY_GUTS,
    MaladySystem.MALADY.ECTO_BONES,
    MaladySystem.MALADY.FATTY_LIVER
}

local DLG_RECEPTION      = "reception_desk_panel_v5m"
local DLG_MANAGE_DOCTORS = "hosp_manage_doctors_v5m"
local DLG_OWNER          = "autosurgeon_owner_panel_v5m"
local DLG_STORAGE        = "autosurgeon_storage_panel_v5m"
local DLG_PLAYER         = "autosurgeon_player_panel_v5m"

local BTN_BIND_PREFIX          = "v5m_bind_"
local BTN_TOOL_PREFIX          = "v5m_tool_"
local BTN_WITHDRAW_TOOL_PREFIX = "v5m_withdraw_tool_"
local BTN_ADD_DOCTOR_PREFIX    = "v5m_add_dr_"
local BTN_REMOVE_DOCTOR_PREFIX = "v5m_rm_dr_"

local BTN_MANAGE_DOCTORS     = "v5m_manage_doctors"
local BTN_UPGRADE_HOSPITAL   = "v5m_upgrade_hospital"
local BTN_LEADERBOARD        = "v5m_leaderboard"
local BTN_CLOSE_RECEPTION    = "v5m_close_reception"
local BTN_DEV_RESET_HOSPITAL = "v5m_dev_reset_hospital"
local BTN_DOCTORS_BACK       = "v5m_doctors_back"

local BTN_OPEN_STORAGE  = "v5m_open_storage_panel"
local BTN_STORAGE_BACK  = "v5m_storage_back"
local BTN_WITHDRAW_WL   = "v5m_withdraw_station_wl"
local BTN_CLOSE_OWNER   = "v5m_close_station_owner"
local BTN_CURE_MALADY   = "v5m_cure_malady_station"

-- =======================================================
-- STORAGE LAYER  (JSON - hospital_data.json)
-- =======================================================

local HOSPITAL_JSON = "hospital_data.json"

local function readHospitalDB()
    if not file.exists(HOSPITAL_JSON) then return { worlds = {}, stations = {} } end
    local data = json.decode(file.read(HOSPITAL_JSON)) or {}
    if type(data.worlds)   ~= "table" then data.worlds   = {} end
    if type(data.stations) ~= "table" then data.stations = {} end
    return data
end

local function writeHospitalDB(data)
    file.write(HOSPITAL_JSON, json.encode(data))
end

local function stationKey(worldName, x, y)
    return tostring(worldName) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

-- Hospital world state
local function loadHospital(worldName)
    local db = readHospitalDB()
    local w = db.worlds[tostring(worldName)]
    if type(w) == "table" and w.level then
        if type(w.doctors)      ~= "table" then w.doctors      = {} end
        if type(w.doctor_stats) ~= "table" then w.doctor_stats = {} end
        return w
    end
    return { level = 1, progress = 0, doctors = {}, doctor_stats = {} }
end

local function saveHospital(worldName, data)
    local db = readHospitalDB()
    db.worlds[tostring(worldName)] = {
        level        = tonumber(data.level) or 1,
        progress     = tonumber(data.progress) or 0,
        doctors      = type(data.doctors)      == "table" and data.doctors      or {},
        doctor_stats = type(data.doctor_stats) == "table" and data.doctor_stats or {},
    }
    writeHospitalDB(db)
end

-- Station record
local function getStation(worldName, x, y)
    local db = readHospitalDB()
    local s = db.stations[stationKey(worldName, x, y)]
    if type(s) == "table" and s.price_wl ~= nil then
        if type(s.storage) ~= "table" then s.storage = {} end
        return s
    end
    return nil
end

local function saveStation(worldName, x, y, data)
    local db = readHospitalDB()
    db.stations[stationKey(worldName, x, y)] = {
        malady_type = tostring(data.malady_type or ""),
        enabled     = tonumber(data.enabled) or 0,
        price_wl    = tonumber(data.price_wl) or MIN_CURE_PRICE_WL,
        earned_wl   = tonumber(data.earned_wl) or 0,
        storage     = type(data.storage) == "table" and data.storage or {},
    }
    writeHospitalDB(db)
end

local function deleteStationData(worldName, x, y)
    local db = readHospitalDB()
    db.stations[stationKey(worldName, x, y)] = nil
    writeHospitalDB(db)
end

-- =======================================================
-- HELPERS
-- =======================================================

local function getUserID(player)
    if type(player) ~= "userdata" then return 0 end
    return tonumber(player:getUserID()) or 0
end

local function getWorldName(world, player)
    if type(player) == "userdata" and player.getWorldName then
        return tostring(player:getWorldName() or "")
    end
    if type(world) ~= "userdata" then return "" end
    return tostring(world:getName() or "")
end

local function isWorldOwner(world, player)
    if type(world) ~= "userdata" then return false end
    if type(player) ~= "userdata" then return false end
    return world:hasAccess(player) == true
end

local function safeHasRole(player, role)
    if type(player) ~= "userdata" then return false end
    return player:hasRole(role) == true
end

local function safeBubble(player, text)
    if player and player.onTalkBubble and player.getNetID then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function safeConsole(player, text)
    if player and player.onConsoleMessage then
        player:onConsoleMessage(text)
    end
end

local function getPlayerItemAmount(player, itemID)
    if player.getItemAmount then
        return tonumber(player:getItemAmount(itemID)) or 0
    end
    if player.getInventoryItems then
        local items = player:getInventoryItems()
        if type(items) == "table" then
            for _, inv in pairs(items) do
                if inv and inv.getItemID and inv:getItemID() == itemID then
                    return tonumber(inv:getItemCount()) or 0
                end
            end
        end
    end
    if player.getItemCount then
        return tonumber(player:getItemCount(itemID)) or 0
    end
    return 0
end

local function safeItemID(value)
    if type(value) == "number" then return math.floor(value) end
    if type(value) == "string" then
        local digits = value:match("%-?%d+")
        if digits then return tonumber(digits) or 0 end
    end
    return 0
end

local function extractButtonSuffix(buttonName, prefix)
    if type(buttonName) ~= "string" then return "" end
    local result = buttonName:gsub("^" .. prefix, "")
    return result  -- discard gsub count to prevent tonumber(str, base) error
end

local function getOwnerNetGain(priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local gain = safePrice - CURE_TAX_WL
    return gain < 0 and 0 or gain
end

-- =======================================================
-- WORLD TILE HELPERS
-- =======================================================

local function getAllWorldTiles(world)
    if world.getTiles then
        local tiles = world:getTiles()
        if type(tiles) == "table" then return tiles end
    end
    local sizeX, sizeY
    if world.getSizeX then sizeX = tonumber(world:getSizeX())
    elseif world.getWorldSizeX then sizeX = tonumber(world:getWorldSizeX()) end
    if world.getSizeY then sizeY = tonumber(world:getSizeY())
    elseif world.getWorldSizeY then sizeY = tonumber(world:getWorldSizeY()) end
    local result = {}
    if sizeX and sizeY then
        for x = 0, sizeX - 1 do
            for y = 0, sizeY - 1 do
                local tile = world:getTile(x, y)
                if tile then result[#result + 1] = tile end
            end
        end
    end
    return result
end

local function countReceptionDesks(world)
    local count = 0
    for _, tile in pairs(getAllWorldTiles(world)) do
        if tile and tile:getTileID() == RECEPTION_DESK_ID then count = count + 1 end
    end
    return count
end

local function countAutoSurgeons(world)
    local count = 0
    for _, tile in pairs(getAllWorldTiles(world)) do
        if tile and tile:getTileID() == AUTO_SURGEON_ID then count = count + 1 end
    end
    return count
end

local function hasHospitalInWorld(world)
    return countReceptionDesks(world) > 0 or countAutoSurgeons(world) > 0
end

-- =======================================================
-- HOSPITAL WORLD STATE
-- =======================================================

local function getHospitalState(worldName)
    return loadHospital(worldName)
end

local function setHospitalState(worldName, level, progress)
    local state = loadHospital(worldName)
    state.level    = tonumber(level) or 1
    state.progress = tonumber(progress) or 0
    saveHospital(worldName, state)
end

local function resetHospitalState(worldName)
    local db = readHospitalDB()
    db.worlds[tostring(worldName)] = nil
    local prefix = tostring(worldName) .. ":"
    for k in pairs(db.stations) do
        if k:sub(1, #prefix) == prefix then db.stations[k] = nil end
    end
    writeHospitalDB(db)
end

-- isDoctor checks registered doctors only (not owner — owner is handled separately)
local function isDoctor(worldName, userID)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    return doctors["u" .. tostring(userID)] ~= nil
end

-- isEffectiveDoctor = owner OR registered doctor
local function isEffectiveDoctor(world, worldName, userID, player)
    if player and isWorldOwner(world, player) then return true end
    return isDoctor(worldName, userID)
end

-- doctors stored as ["u{uid}"] = displayName
local function addDoctor(worldName, userID, displayName)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = tostring(displayName or "Unknown")
    saveHospital(worldName, state)
end

local function removeDoctor(worldName, userID)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = nil
    saveHospital(worldName, state)
end

local function countDoctors(worldName)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    local n = 0
    for _ in pairs(doctors) do n = n + 1 end
    return n
end

local function addDoctorSurgery(worldName, userID)
    local state = loadHospital(worldName)
    local stats = state.doctor_stats or {}
    local key = "u" .. tostring(userID)
    stats[key] = (tonumber(stats[key]) or 0) + 1
    state.doctor_stats = stats
    saveHospital(worldName, state)
end

local function getDoctorLeaderboard(worldName)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    local stats = state.doctor_stats or {}
    local list = {}
    for key, name in pairs(doctors) do
        local uidStr = key:gsub("^u", "")
        local uid = tonumber(uidStr) or 0
        list[#list + 1] = { uid = uid, name = tostring(name), surgeries = tonumber(stats[key]) or 0 }
    end
    table.sort(list, function(a, b) return a.surgeries > b.surgeries end)
    return list
end

local function getHospitalProgressText(level, progress)
    local levelData = HOSPITAL_LEVELS[level]
    if not levelData or not levelData.next_level then return "MAX LEVEL" end
    return tostring(progress) .. "/" .. tostring(levelData.required_surgeries)
end

local function addHospitalProgressIfPossible(worldName, amount)
    local state = loadHospital(worldName)
    local level     = tonumber(state.level) or 1
    local progress  = tonumber(state.progress) or 0
    local levelData = HOSPITAL_LEVELS[level]
    if not levelData or not levelData.next_level then return false end
    if progress >= tonumber(levelData.required_surgeries) then return false end
    local nextProgress = math.min(
        tonumber(levelData.required_surgeries),
        progress + math.max(0, math.floor(tonumber(amount) or 0))
    )
    state.progress = nextProgress
    saveHospital(worldName, state)
    return true
end

-- =======================================================
-- STATION STATE
-- =======================================================

local function ensureStation(worldName, x, y)
    local existing = getStation(worldName, x, y)
    if existing then return existing end

    local storage = {}
    for _, toolID in ipairs(ALL_SURGICAL_TOOLS) do
        storage["t" .. tostring(toolID)] = 0
    end

    local newStation = {
        malady_type = "",
        enabled     = 0,
        price_wl    = MIN_CURE_PRICE_WL,
        earned_wl   = 0,
        storage     = storage
    }

    saveStation(worldName, x, y, newStation)
    return newStation
end

local function setStationMalady(worldName, x, y, maladyType)
    local station = ensureStation(worldName, x, y)
    station.malady_type = tostring(maladyType)
    saveStation(worldName, x, y, station)
end

local function setStationEnabled(worldName, x, y, enabled)
    local station = ensureStation(worldName, x, y)
    station.enabled = enabled and 1 or 0
    saveStation(worldName, x, y, station)
end

local function setStationPrice(worldName, x, y, priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local station = ensureStation(worldName, x, y)
    station.price_wl = safePrice
    saveStation(worldName, x, y, station)
end

local function getStationToolAmount(worldName, x, y, toolID)
    local station = getStation(worldName, x, y)
    if not station then return 0 end
    local storage = station.storage or {}
    return tonumber(storage["t" .. tostring(toolID)]) or 0
end

local function addStationTool(worldName, x, y, toolID, amount)
    local station = ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.min(MAX_TOOL_STORAGE, current + math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function removeStationTool(worldName, x, y, toolID, amount)
    local station = ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.max(0, current - math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function stationHasEnoughTools(worldName, x, y, maladyType)
    local req = TOOL_REQUIREMENT[maladyType]
    if not req then return false end
    local station = getStation(worldName, x, y)
    if not station then return false end
    local storage = station.storage or {}
    for toolID, need in pairs(req) do
        if (tonumber(storage["t" .. tostring(toolID)]) or 0) < need then
            return false
        end
    end
    return true
end

local function getStationPossibleCures(worldName, x, y, maladyType)
    local req = TOOL_REQUIREMENT[maladyType]
    if not req then return 0 end
    local station = getStation(worldName, x, y)
    if not station then return 0 end
    local storage = station.storage or {}
    local minCount = nil
    for toolID, need in pairs(req) do
        local have     = tonumber(storage["t" .. tostring(toolID)]) or 0
        local possible = math.floor(have / need)
        if not minCount or possible < minCount then minCount = possible end
    end
    return minCount or 0
end

local function consumeStationTools(worldName, x, y, maladyType)
    local req = TOOL_REQUIREMENT[maladyType]
    if not req then return end
    local station = ensureStation(worldName, x, y)
    local storage = station.storage or {}
    for toolID, need in pairs(req) do
        local current = tonumber(storage["t" .. tostring(toolID)]) or 0
        storage["t" .. tostring(toolID)] = math.max(0, current - need)
    end
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function addStationEarnedWL(worldName, x, y, amount)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = (tonumber(station.earned_wl) or 0) + math.max(0, math.floor(tonumber(amount) or 0))
    saveStation(worldName, x, y, station)
end

local function clearStationEarnedWL(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = 0
    saveStation(worldName, x, y, station)
end

local function deleteStation(worldName, x, y)
    deleteStationData(worldName, x, y)
end

local function countStationRowsInWorld(worldName)
    local db = readHospitalDB()
    local prefix = tostring(worldName) .. ":"
    local n = 0
    for k in pairs(db.stations) do
        if k:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end

local function refreshStationOperationalState(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    local maladyType = tostring(station.malady_type or "")
    if maladyType == "" then return end
    if not stationHasEnoughTools(worldName, x, y, maladyType) then
        setStationEnabled(worldName, x, y, false)
    end
end

local function getToolStorageLabel(worldName, x, y, toolID)
    return tostring(getStationToolAmount(worldName, x, y, toolID)) .. "/1k"
end

local function hasAnyStationStock(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return false end
    local storage = station.storage or {}
    for i = 1, #ALL_SURGICAL_TOOLS do
        if (tonumber(storage["t" .. tostring(ALL_SURGICAL_TOOLS[i])]) or 0) > 0 then
            return true
        end
    end
    return false
end

local function canBreakAutoSurgeon(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return true end
    if (tonumber(station.earned_wl) or 0) > 0 then return false end
    if hasAnyStationStock(worldName, x, y) then return false end
    return true
end

local function tryDepositToolToStation(player, worldName, x, y, toolID)
    local current = getStationToolAmount(worldName, x, y, toolID)
    if current >= MAX_TOOL_STORAGE then
        safeBubble(player, "`4This tool storage is already full.")
        return false
    end
    local haveTool = getPlayerItemAmount(player, toolID)
    if haveTool <= 0 then
        safeBubble(player, "`4You do not have this tool in inventory.")
        return false
    end
    local freeSpace     = MAX_TOOL_STORAGE - current
    local depositAmount = math.min(haveTool, freeSpace)
    if depositAmount <= 0 then
        safeBubble(player, "`4This tool storage is already full.")
        return false
    end
    player:changeItem(toolID, -depositAmount, 0)
    addStationTool(worldName, x, y, toolID, depositAmount)
    safeBubble(player, "`2Deposited " .. tostring(depositAmount) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

local function tryWithdrawToolFromStation(player, worldName, x, y, toolID)
    local current = getStationToolAmount(worldName, x, y, toolID)
    if current <= 0 then
        safeBubble(player, "`4There is no stock for this tool.")
        return false
    end
    player:changeItem(toolID, current, 0)
    removeStationTool(worldName, x, y, toolID, current)
    safeBubble(player, "`2Withdrew " .. tostring(current) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

-- =======================================================
-- PANELS
-- =======================================================

local showAutoSurgeonOwnerPanel
local showAutoSurgeonStoragePanel
local showManageDoctorsPanel
local showDoctorReceptionPanel

local function tryUpgradeHospital(player, world)
    local worldName = getWorldName(world, player)
    local state     = getHospitalState(worldName)
    local level     = tonumber(state.level) or 1
    local progress  = tonumber(state.progress) or 0
    local levelData = HOSPITAL_LEVELS[level]

    if not levelData or not levelData.next_level then
        safeBubble(player, "`4Hospital is already at max level.")
        return
    end
    if progress < tonumber(levelData.required_surgeries) then
        safeBubble(player, "`4Not enough surgery progress to upgrade yet.")
        return
    end
    if (tonumber(player:getGems()) or 0) < tonumber(levelData.upgrade_gems) then
        safeBubble(player, "`4Not enough Gems to upgrade the hospital.")
        return
    end

    safeBubble(player, "`oWL upgrade check is not connected yet in this build.")

    player:removeGems(tonumber(levelData.upgrade_gems), 1, 1)
    setHospitalState(worldName, tonumber(levelData.next_level), 0)
    safeBubble(player, "`2Hospital upgraded to level " .. tostring(levelData.next_level) .. "!")
end

local function showReceptionDeskPanel(world, player)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    MaladySystem.refreshPlayerState(player)
    local worldName    = getWorldName(world, player)
    local state        = getHospitalState(worldName)
    local level        = tonumber(state.level) or 1
    local progress     = tonumber(state.progress) or 0
    local progressText = getHospitalProgressText(level, progress)
    local doctorCount  = countDoctors(worldName)
    local levelData    = HOSPITAL_LEVELS[level]
    local ownerAccess  = isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER)
    local statusText   = MaladySystem.getStatusText(player)

    local dialog = {
        "set_default_color|`o",
        "set_bg_color|0,0,0,180|",
        "add_label_with_icon|big|Reception Desk|left|" .. tostring(RECEPTION_DESK_ID) .. "|",
        "add_smalltext|`wWorld: `o" .. worldName .. "|",
        "add_smalltext|`wHospital Level: `o" .. tostring(level) .. "|",
        "add_smalltext|`wProgress: `o" .. progressText .. "|",
        "add_smalltext|`wRegistered Doctors: `o" .. tostring(doctorCount) .. "|",
        "add_smalltext|`wYour Status: " .. statusText .. "|",
        "add_spacer|small|"
    }

    if levelData and levelData.next_level then
        dialog[#dialog + 1] = "add_smalltext|`wNext Upgrade: `oLevel " .. tostring(levelData.next_level) .. "|"
        dialog[#dialog + 1] = "add_smalltext|`wUpgrade Cost: `o" .. tostring(levelData.upgrade_gems) .. " Gems + " .. tostring(levelData.upgrade_wl) .. " WL|"
    else
        dialog[#dialog + 1] = "add_smalltext|`2Hospital is at max level.|"
    end

    dialog[#dialog + 1] = "add_spacer|small|"

    if ownerAccess then
        dialog[#dialog + 1] = "add_button|" .. BTN_MANAGE_DOCTORS   .. "|Manage Doctors|noflags|0|0|"
        dialog[#dialog + 1] = "add_button|" .. BTN_UPGRADE_HOSPITAL .. "|Upgrade Hospital|noflags|0|0|"
        dialog[#dialog + 1] = "add_button|" .. BTN_LEADERBOARD      .. "|Leaderboard|noflags|0|0|"
        dialog[#dialog + 1] = "add_button|" .. BTN_CLOSE_RECEPTION  .. "|Close|noflags|0|0|"
        if safeHasRole(player, ROLE_DEVELOPER) then
            dialog[#dialog + 1] = "add_spacer|small|"
            dialog[#dialog + 1] = "add_button|" .. BTN_DEV_RESET_HOSPITAL .. "|`4DEV: Reset Hospital|noflags|0|0|"
        end
    else
        dialog[#dialog + 1] = "add_button|" .. BTN_CLOSE_RECEPTION .. "|Close|noflags|0|0|"
    end

    dialog[#dialog + 1] = "add_quick_exit|"
    dialog[#dialog + 1] = "end_dialog|" .. DLG_RECEPTION .. "|||"

    player:onDialogRequest(table.concat(dialog, "\n"), 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= DLG_RECEPTION then return end
        local btn = data["buttonClicked"]

        if btn == BTN_MANAGE_DOCTORS and (isWorldOwner(cbWorld, cbPlayer) or safeHasRole(cbPlayer, ROLE_DEVELOPER)) then
            showManageDoctorsPanel(cbWorld, cbPlayer, worldName)
            return true
        end
        if btn == BTN_UPGRADE_HOSPITAL and (isWorldOwner(cbWorld, cbPlayer) or safeHasRole(cbPlayer, ROLE_DEVELOPER)) then
            tryUpgradeHospital(cbPlayer, cbWorld)
            showReceptionDeskPanel(cbWorld, cbPlayer)
            return true
        end
        if btn == BTN_LEADERBOARD and (isWorldOwner(cbWorld, cbPlayer) or safeHasRole(cbPlayer, ROLE_DEVELOPER)) then
            showDoctorReceptionPanel(cbWorld, cbPlayer, worldName)
            return true
        end
        if btn == BTN_CLOSE_RECEPTION then
            return true
        end
        if btn == BTN_DEV_RESET_HOSPITAL and safeHasRole(cbPlayer, ROLE_DEVELOPER) then
            resetHospitalState(worldName)
            safeBubble(cbPlayer, "`4Hospital reset to level 1.")
            showReceptionDeskPanel(cbWorld, cbPlayer)
            return true
        end

        return true
    end)
end

showManageDoctorsPanel = function(world, player, worldName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local state   = getHospitalState(worldName)
    local doctors = state.doctors or {}

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|0,0,0,180|\n"
    d = d .. "add_label_with_icon|big|Manage Doctors|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
    d = d .. "add_smalltext|`wWorld Owner is always a doctor.|\n"
    d = d .. "add_spacer|small|\n"

    -- Section: current registered doctors
    d = d .. "add_label|small|`wRegistered Doctors:|left|\n"
    local hasDoctors = false
    for key, name in pairs(doctors) do
        hasDoctors = true
        local uid = key:gsub("^u", "")
        d = d .. "add_button|" .. BTN_REMOVE_DOCTOR_PREFIX .. uid .. "|`4Remove: " .. tostring(name) .. "|noflags|0|0|\n"
    end
    if not hasDoctors then
        d = d .. "add_smalltext|`7No registered doctors yet.|\n"
    end

    d = d .. "add_spacer|small|\n"

    -- Section: players in world that can be added as doctor
    d = d .. "add_label|small|`wPlayers In World (click to add as doctor):|left|\n"
    local players = world:getPlayers()
    local anyAddable = false
    if type(players) == "table" then
        for _, p in pairs(players) do
            local pid  = getUserID(p)
            local pkey = "u" .. tostring(pid)
            -- Skip owner and already-doctors
            if not isWorldOwner(world, p) and not doctors[pkey] then
                anyAddable = true
                local pname = tostring(p.getName and p:getName() or pid)
                d = d .. "add_button|" .. BTN_ADD_DOCTOR_PREFIX .. pid .. "|`2Add: " .. pname .. "|noflags|0|0|\n"
            end
        end
    end
    if not anyAddable then
        d = d .. "add_smalltext|`7No eligible players in this world.|\n"
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_DOCTORS_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. DLG_MANAGE_DOCTORS .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= DLG_MANAGE_DOCTORS then return end
        local btn = data["buttonClicked"]

        if btn and btn:match("^" .. BTN_ADD_DOCTOR_PREFIX) then
            local uid = tonumber(extractButtonSuffix(btn, BTN_ADD_DOCTOR_PREFIX)) or 0
            if uid > 0 then
                local targetName = tostring(uid)
                local targetPlayer = nil
                local wPlayers = cbWorld:getPlayers()
                if type(wPlayers) == "table" then
                    for _, p in pairs(wPlayers) do
                        if getUserID(p) == uid then
                            targetName = tostring(p.getName and p:getName() or uid)
                            targetPlayer = p
                            break
                        end
                    end
                end
                addDoctor(worldName, uid, targetName)
                safeBubble(cbPlayer, "`2" .. targetName .. " is now a registered doctor.")
                if targetPlayer then
                    safeBubble(targetPlayer, "`2You have been registered as a doctor at this hospital!")
                end
            end
            showManageDoctorsPanel(cbWorld, cbPlayer, worldName)
            return true
        end

        if btn and btn:match("^" .. BTN_REMOVE_DOCTOR_PREFIX) then
            local uid = tonumber(extractButtonSuffix(btn, BTN_REMOVE_DOCTOR_PREFIX)) or 0
            if uid > 0 then
                removeDoctor(worldName, uid)
                safeBubble(cbPlayer, "`4Doctor removed.")
                local wPlayers = cbWorld:getPlayers()
                if type(wPlayers) == "table" then
                    for _, p in pairs(wPlayers) do
                        if getUserID(p) == uid then
                            safeConsole(p, "`4You have been removed as a doctor from this hospital.")
                            break
                        end
                    end
                end
            end
            showManageDoctorsPanel(cbWorld, cbPlayer, worldName)
            return true
        end

        if btn == BTN_DOCTORS_BACK then
            showReceptionDeskPanel(cbWorld, cbPlayer)
            return true
        end

        return true
    end)
end

showDoctorReceptionPanel = function(world, player, worldName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "hosp_doctor_panel_v5m"
    local uid = getUserID(player)
    local leaderboard = getDoctorLeaderboard(worldName)

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|0,0,0,180|\n"
    d = d .. "add_label_with_icon|big|Doctor Panel|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
    d = d .. "add_smalltext|`wWorld: `o" .. worldName .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`wTop Doctors:|left|\n"

    if #leaderboard == 0 then
        d = d .. "add_smalltext|`7No surgery records yet.|\n"
    else
        for rank, entry in ipairs(leaderboard) do
            local youTag = (entry.uid == uid) and " `e(You)" or ""
            d = d .. "add_smalltext|`w#" .. rank .. " `o" .. entry.name .. " `7- `2" .. tostring(entry.surgeries) .. " surgeries" .. youTag .. "|\n"
        end
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_doctor_close|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end
        return true
    end)
end

showAutoSurgeonStoragePanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_storage_v5m_" .. tostring(x) .. "_" .. tostring(y)
    ensureStation(worldName, x, y)

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaaaaa|\n"
    d = d .. "set_bg_color|0,0,0,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Storage|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_smalltext|`wClick a tool to withdraw all stock for that tool.|\n"
    d = d .. "add_spacer|small|\n"

    for rowStart = 1, #ALL_SURGICAL_TOOLS, 5 do
        local rowEnd = math.min(rowStart + 4, #ALL_SURGICAL_TOOLS)
        for i = rowStart, rowEnd do
            local toolID = ALL_SURGICAL_TOOLS[i]
            d = d .. string.format(
                "add_button_with_icon|%s%d|%s|staticBlueFrame|%d|0|left|\n",
                BTN_WITHDRAW_TOOL_PREFIX, toolID,
                getToolStorageLabel(worldName, x, y, toolID), toolID
            )
        end
        d = d .. "add_custom_break|\n"
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "add_button|" .. BTN_STORAGE_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end
        local btn = data["buttonClicked"]

        if btn and btn:match("^" .. BTN_WITHDRAW_TOOL_PREFIX) then
            local toolID = tonumber(extractButtonSuffix(btn, BTN_WITHDRAW_TOOL_PREFIX)) or 0
            if toolID > 0 then
                tryWithdrawToolFromStation(cbPlayer, worldName, x, y, toolID)
                refreshStationOperationalState(worldName, x, y)
            end
            showAutoSurgeonStoragePanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end
        if btn == BTN_STORAGE_BACK then
            showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        return true
    end)
end

showAutoSurgeonOwnerPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_owner_v5m_" .. tostring(x) .. "_" .. tostring(y)
    ensureStation(worldName, x, y)
    refreshStationOperationalState(worldName, x, y)
    local station = getStation(worldName, x, y)

    local maladyType = tostring(station.malady_type or "")
    local enabled    = tonumber(station.enabled) == 1
    local priceWL    = tonumber(station.price_wl) or MIN_CURE_PRICE_WL
    local earnedWL   = tonumber(station.earned_wl) or 0
    local cureCount  = maladyType ~= "" and getStationPossibleCures(worldName, x, y, maladyType) or 0

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaaaaa|\n"
    d = d .. "set_bg_color|0,0,0,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_smalltext|`wStation World: `o" .. worldName .. "|\n"
    d = d .. "add_smalltext|`wBound Malady: `o" .. (maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not set") .. "|\n"
    d = d .. "add_smalltext|`wPossible Cures: `o" .. tostring(cureCount) .. "|\n"
    d = d .. "add_smalltext|`wPrice of One Cure: `o" .. tostring(priceWL) .. " WL|\n"
    d = d .. "add_smalltext|`wWorld Tax: `o" .. tostring(CURE_TAX_WL) .. " WL|\n"
    d = d .. "add_smalltext|`wOwner Net Gain: `o" .. tostring(getOwnerNetGain(priceWL)) .. " WL|\n"
    d = d .. "add_smalltext|`wEarned WL Ready To Withdraw: `o" .. tostring(earnedWL) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_text_input|station_price_wl|Price WL|" .. tostring(priceWL) .. "|4|\n"
    d = d .. "add_checkbox|station_enabled|Enable Auto Surgeon Station|" .. (enabled and "1" or "0") .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`wChoose Illness|\n"
    d = d .. "add_smalltext|`oVile Vial Maladies:|\n"

    for i = 1, #MALADY_UI_VIAL do
        local m = MALADY_UI_VIAL[i]
        local icon = MALADY_ICON[m] or 2
        local label = (maladyType == m and "`2" or "`w") .. (MaladySystem.MALADY_DISPLAY[m] or m)
        d = d .. "add_button_with_icon|" .. BTN_BIND_PREFIX .. m .. "|" .. label .. "|staticBlueFrame|" .. icon .. "|0|left|\n"
    end
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oActivity Maladies:|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "set_custom_spacing|x:20;y:0|\n"

    local function rngLabel(m)
        local color = maladyType == m and "`2" or "`w"
        local name  = MaladySystem.MALADY_DISPLAY[m] or m
        if #name > 8 then name = name:sub(1, 8):gsub("%s+$", "") .. "..." end
        return color .. name
    end

    for i = 1, 3 do
        local m = MALADY_UI_RNG[i]
        local icon = MALADY_ICON[m] or 2
        d = d .. "add_button_with_icon|" .. BTN_BIND_PREFIX .. m .. "|" .. rngLabel(m) .. "|staticBlueFrame|" .. icon .. "|0|left|\n"
    end
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    for i = 4, #MALADY_UI_RNG do
        local m = MALADY_UI_RNG[i]
        local icon = MALADY_ICON[m] or 2
        d = d .. "add_button_with_icon|" .. BTN_BIND_PREFIX .. m .. "|" .. rngLabel(m) .. "|staticBlueFrame|" .. icon .. "|0|left|\n"
    end
    d = d .. "add_custom_break|\n"
    d = d .. "set_custom_spacing|x:0;y:0|\n"

    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|medium|`wSurgical Tools Storage|left|1260|\n"
    d = d .. "add_spacer|small|\n"

    for rowStart = 1, #ALL_SURGICAL_TOOLS, 5 do
        local rowEnd = math.min(rowStart + 4, #ALL_SURGICAL_TOOLS)
        for i = rowStart, rowEnd do
            local toolID = ALL_SURGICAL_TOOLS[i]
            d = d .. string.format(
                "add_button_with_icon|%s%d|%s|staticBlueFrame|%d|0|left|\n",
                BTN_TOOL_PREFIX, toolID,
                getToolStorageLabel(worldName, x, y, toolID), toolID
            )
        end
        d = d .. "add_custom_break|\n"
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "add_button|" .. BTN_OPEN_STORAGE .. "|Storage|noflags|0|0|\n"
    d = d .. "add_button|" .. BTN_WITHDRAW_WL  .. "|Withdraw World Locks|noflags|0|0|\n"
    d = d .. "add_button|" .. BTN_CLOSE_OWNER  .. "|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end
        local btn      = data["buttonClicked"]
        local newEnabled = data["station_enabled"] == "1"
        local newPrice   = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(data["station_price_wl"]) or MIN_CURE_PRICE_WL))

        setStationEnabled(worldName, x, y, newEnabled)
        setStationPrice(worldName, x, y, newPrice)

        if btn and btn:match("^" .. BTN_BIND_PREFIX) then
            local newMalady = extractButtonSuffix(btn, BTN_BIND_PREFIX)
            setStationMalady(worldName, x, y, newMalady)
            refreshStationOperationalState(worldName, x, y)
            safeBubble(cbPlayer, "`2Station bound to " .. (MaladySystem.MALADY_DISPLAY[newMalady] or newMalady) .. ".")
            showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end
        if btn and btn:match("^" .. BTN_TOOL_PREFIX) then
            local toolID = tonumber(extractButtonSuffix(btn, BTN_TOOL_PREFIX)) or 0
            if toolID > 0 then
                tryDepositToolToStation(cbPlayer, worldName, x, y, toolID)
                refreshStationOperationalState(worldName, x, y)
            end
            showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end
        if btn == BTN_OPEN_STORAGE then
            showAutoSurgeonStoragePanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end
        if btn == BTN_WITHDRAW_WL then
            local stationNow   = getStation(worldName, x, y)
            local wlToWithdraw = tonumber(stationNow and stationNow.earned_wl) or 0
            if wlToWithdraw <= 0 then
                safeBubble(cbPlayer, "`4No World Locks to withdraw.")
            else
                cbPlayer:changeItem(WORLD_LOCK_ID, wlToWithdraw, 0)
                clearStationEarnedWL(worldName, x, y)
                safeBubble(cbPlayer, "`2Withdrew " .. tostring(wlToWithdraw) .. " WL from station earnings.")
            end
            showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end
        -- BTN_CLOSE_OWNER atau quick_exit: simpan settings lalu tutup
        return true
    end)
end

local function showAutoSurgeonPlayerPanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_player_v5m_" .. tostring(x) .. "_" .. tostring(y)
    MaladySystem.refreshPlayerState(player)
    ensureStation(worldName, x, y)
    refreshStationOperationalState(worldName, x, y)
    local station    = getStation(worldName, x, y)
    local maladyType = tostring(station.malady_type or "")
    local enabled    = tonumber(station.enabled) == 1
    local priceWL    = tonumber(station.price_wl) or MIN_CURE_PRICE_WL

    local dialog = {
        "set_default_color|`o",
        "set_bg_color|0,0,0,180|",
        "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|",
        "add_smalltext|`wThis station cures: `o" .. (maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not configured") .. "|",
        "add_smalltext|`wPrice of One Cure: `o" .. tostring(priceWL) .. " WL|",
        "add_smalltext|`wYour Status: " .. MaladySystem.getStatusText(player) .. "|",
        "add_spacer|small|",
        "add_button|" .. BTN_CURE_MALADY .. "|Cure Malady|noflags|0|0|",
        "add_quick_exit|",
        "end_dialog|" .. dlgName .. "|||"
    }

    player:onDialogRequest(table.concat(dialog, "\n"), 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end
        if data["buttonClicked"] ~= BTN_CURE_MALADY then return true end

        MaladySystem.refreshPlayerState(cbPlayer)
        local activeMalady = MaladySystem.getActiveMalady(cbPlayer)

        if not activeMalady then
            safeBubble(cbPlayer, "`4You do not have any malady that requires treatment.")
            return true
        end
        if MaladySystem.isRecovering(cbPlayer) then
            safeBubble(cbPlayer, "`4You are recovering and cannot use Auto Surgeon right now.")
            return true
        end
        if maladyType == "" then
            safeBubble(cbPlayer, "`4This Auto Surgeon Station is not configured yet.")
            return true
        end
        if tostring(activeMalady) ~= maladyType then
            safeBubble(cbPlayer, "`4This station does not treat your malady.")
            return true
        end

        local hospitalState = getHospitalState(worldName)
        local hospitalLevel = tonumber(hospitalState.level) or 1
        local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[maladyType]) or 999
        if hospitalLevel < requiredLevel then
            safeBubble(cbPlayer, "`4This malady treatment has not been unlocked for this hospital yet.")
            return true
        end
        if not enabled then
            safeBubble(cbPlayer, "`4This Auto Surgeon Station is currently disabled.")
            return true
        end
        if not stationHasEnoughTools(worldName, x, y, maladyType) then
            setStationEnabled(worldName, x, y, false)
            safeBubble(cbPlayer, "`4This Auto Surgeon Station does not have enough surgical tools to operate.")
            return true
        end
        if getPlayerItemAmount(cbPlayer, WORLD_LOCK_ID) < priceWL then
            safeBubble(cbPlayer, "`4You do not have enough World Locks to pay for this treatment.")
            return true
        end

        local ok, reason = MaladySystem.cureFromAutoSurgeon(cbPlayer)
        if not ok then
            safeBubble(cbPlayer, "`4Auto Surgeon cure failed: " .. tostring(reason))
            return true
        end

        cbPlayer:changeItem(WORLD_LOCK_ID, -priceWL, 0)
        consumeStationTools(worldName, x, y, maladyType)
        addStationEarnedWL(worldName, x, y, getOwnerNetGain(priceWL))
        refreshStationOperationalState(worldName, x, y)
        safeBubble(cbPlayer, "`2Your malady has been cured.")
        return true
    end)
end

-- =======================================================
-- CALLBACKS
-- =======================================================

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() == RECEPTION_DESK_ID then
        local worldName = getWorldName(world, player)
        local uid = getUserID(player)
        if isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER) then
            showReceptionDeskPanel(world, player)
        elseif isDoctor(worldName, uid) then
            showDoctorReceptionPanel(world, player, worldName)
        elseif world:hasAccess(player) then
            safeBubble(player, "`4You are not registered as a doctor at this hospital!")
        else
            showReceptionDeskPanel(world, player)
        end
        return true
    end
    if tile:getTileID() == AUTO_SURGEON_ID then
        local worldName = getWorldName(world, player)
        local x = tile:getPosX()
        local y = tile:getPosY()
        -- Cek jarak: player harus dekat station
        -- getPosX() mungkin pixel (÷32) atau tile coords langsung — dual-check keduanya
        -- Offset kanan lebih besar (+4) karena getPosX() = ujung kiri player, bukan center
        local pxRaw = math.floor(player:getPosX() or 0)
        local pyRaw = math.floor(player:getPosY() or 0)
        local pxTile = math.floor(pxRaw / 32)
        local pyTile = math.floor(pyRaw / 32)
        local closeAsPixels = (pxTile - x) >= -8 and (pxTile - x) <= 17 and math.abs(pyTile - y) <= 6
        local closeAsTiles  = (pxRaw - x) >= -8 and (pxRaw - x) <= 17 and math.abs(pyRaw - y) <= 6
        if not closeAsPixels and not closeAsTiles then
            safeBubble(player, "`4You need to stand next to the Auto Surgeon Station.")
            return true
        end
        ensureStation(worldName, x, y)
        if isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER) then
            showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
        else
            showAutoSurgeonPlayerPanel(world, player, worldName, x, y)
        end
        return true
    end
    return false
end)

onTilePlaceCallback(function(world, player, tile, placingID)
    local itemID = safeItemID(placingID)

    if itemID == RECEPTION_DESK_ID then
        if countReceptionDesks(world) >= 1 then
            safeBubble(player, "`4Only one Reception Desk can exist in a world.")
            return true
        end
    end

    if itemID == AUTO_SURGEON_ID then
        if countReceptionDesks(world) < 1 then
            safeBubble(player, "`4A Reception Desk must be placed first before adding Auto Surgeon Stations.")
            return true
        end
        if countAutoSurgeons(world) >= 12 then
            safeBubble(player, "`4Maximum 12 Auto Surgeon Stations allowed per world.")
            return true
        end
    end

    return false
end)

-- onTilePunchCallback: prevent punching to completion when tiles are protected
-- (return true = prevent break/damage accumulation, tile stays intact)
onTilePunchCallback(function(world, player, tile)
    local worldName = getWorldName(world, player)
    local x = tile:getPosX()
    local y = tile:getPosY()

    if tile:getTileID() == RECEPTION_DESK_ID then
        if countAutoSurgeons(world) > 0 then
            safeBubble(player, "`4Remove all Auto Surgeon Stations before breaking the Reception Desk.")
            return true
        end
    end

    if tile:getTileID() == AUTO_SURGEON_ID then
        if not canBreakAutoSurgeon(worldName, x, y) then
            safeBubble(player, "`4Empty the Auto Surgeon storage and withdraw earnings before breaking.")
            return true
        end
    end

    if tile:getTileID() == WORLD_LOCK_ID then
        if hasHospitalInWorld(world) then
            safeBubble(player, "`4Cannot break the World Lock while a hospital is active in this world.")
            return true
        end
    end

    return false
end)

-- onTileBreakCallback: cleanup after allowed break (no prevention here)
onTileBreakCallback(function(world, player, tile)
    local worldName = getWorldName(world, player)

    if tile:getTileID() == RECEPTION_DESK_ID then
        resetHospitalState(worldName)
    end

    if tile:getTileID() == AUTO_SURGEON_ID then
        deleteStation(worldName, tile:getPosX(), tile:getPosY())
    end
end)

-- (Nperma only) Block trading World Lock out of a hospital world
onPlayerTradeCallback(function(world, player1, player2, items1, items2)
    if not hasHospitalInWorld(world) then return end
    local function hasWL(items)
        if type(items) ~= "table" then return false end
        for _, item in pairs(items) do
            if item and item.getItemID and item:getItemID() == WORLD_KEY_ID then
                return true
            end
        end
        return false
    end
    if hasWL(items1) or hasWL(items2) then
        safeBubble(player1, "`4Cannot trade the World Key while a hospital is active in this world.")
        safeBubble(player2, "`4Cannot trade the World Key while a hospital is active in this world.")
        return true
    end
end)

onPlayerSurgeryCallback(function(world, surgeon, rewardID, rewardCount, targetPlayer)
    if MaladySystem.getActiveMalady(surgeon) == MaladySystem.MALADY.BROKEN_HEARTS then
        return true -- block: patient tidak sembuh, hospital progress tidak naik
    end

    local worldName = getWorldName(world, surgeon)

    if targetPlayer and MaladySystem.hasActiveMalady(targetPlayer) then
        local ok, reason = MaladySystem.cureFromManualSurgery(targetPlayer)
        if ok then
            safeConsole(targetPlayer, "`2Your malady has been cured by surgery.")
        else
            safeConsole(targetPlayer, "`4Malady cure failed: " .. tostring(reason))
        end
    end

    if isEffectiveDoctor(world, worldName, getUserID(surgeon), surgeon) then
        local added = addHospitalProgressIfPossible(worldName, 1)
        if added then safeConsole(surgeon, "`2Hospital progress increased by 1.") end
        addDoctorSurgery(worldName, getUserID(surgeon))
    end

    MaladySystem.tryInfectFromTrigger(surgeon, MaladySystem.TRIGGER_SOURCE.SURGERY)
end)

-- =======================================================
-- DEV COMMANDS
-- =======================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    local parts = {}
    for token in (fullCommand or ""):gmatch("%S+") do
        parts[#parts + 1] = token
    end
    local cmd = string.lower(parts[1] or "")

    if cmd ~= "hospitaltest" and cmd ~= "/hospitaltest" then
        return false
    end
    if not safeHasRole(player, ROLE_DEVELOPER) then
        safeBubble(player, "`4Developer only test command.")
        return true
    end

    local sub = string.lower(parts[2] or "help")

    if sub == "help" then
        safeConsole(player, "`w/hospitaltest panel `o= open reception panel")
        safeConsole(player, "`w/hospitaltest owner `o= open owner panel while standing on station")
        safeConsole(player, "`w/hospitaltest infect chicken/torn/grumble/gems/auto/broken")
        safeConsole(player, "`w/hospitaltest clear")
        safeConsole(player, "`w/hospitaltest state")
        safeConsole(player, "`w/hospitaltest addprogress")
        safeConsole(player, "`w/hospitaltest stationstate")
        return true
    end

    if sub == "panel" then
        showReceptionDeskPanel(world, player)
        return true
    end

    if sub == "owner" then
        local px   = math.floor((player:getPosX() or 0) / 32)
        local py   = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if not tile or tile:getTileID() ~= AUTO_SURGEON_ID then
            safeBubble(player, "`4Stand on an Auto Surgeon Station first.")
            return true
        end
        local worldName = getWorldName(world)
        showAutoSurgeonOwnerPanel(world, player, worldName, tile:getPosX(), tile:getPosY())
        return true
    end

    if sub == "infect" then
        local which = string.lower(parts[3] or "")
        local maladyMap = {
            chicken = MaladySystem.MALADY.CHICKEN_FEET,
            torn    = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
            grumble = MaladySystem.MALADY.GRUMBLETEETH,
            gems    = MaladySystem.MALADY.GEMS_CUTS,
            auto    = MaladySystem.MALADY.AUTOMATION_CURSE,
            broken  = MaladySystem.MALADY.BROKEN_HEARTS
        }
        local maladyType = maladyMap[which]
        if not maladyType then
            safeBubble(player, "`4Unknown malady test key.")
            return true
        end
        local ok, reason = MaladySystem.forceInfect(player, maladyType, "ADMIN", false)
        safeConsole(player, "forceInfect => " .. tostring(ok) .. " / " .. tostring(reason))
        return true
    end

    if sub == "clear" then
        local ok = MaladySystem.clearMalady(player, "ADMIN")
        safeConsole(player, "clearMalady => " .. tostring(ok))
        return true
    end

    if sub == "state" then
        MaladySystem.debugState(player)
        local worldName = getWorldName(world, player)
        local state = getHospitalState(worldName)
        safeConsole(player, "`wHospital Level: `o" .. tostring(state.level))
        safeConsole(player, "`wHospital Progress: `o" .. tostring(state.progress))
        safeConsole(player, "`wDoctors: `o" .. tostring(countDoctors(worldName)))
        return true
    end

    if sub == "addprogress" then
        local added = addHospitalProgressIfPossible(getWorldName(world, player), 1)
        if added then
            safeBubble(player, "`2Added hospital progress by 1.")
        else
            safeBubble(player, "`4Could not add progress. Maybe hospital is full or max level.")
        end
        return true
    end

    if sub == "stationstate" then
        local px   = math.floor((player:getPosX() or 0) / 32)
        local py   = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if not tile or tile:getTileID() ~= AUTO_SURGEON_ID then
            safeBubble(player, "`4Stand on an Auto Surgeon Station first.")
            return true
        end
        local station = getStation(getWorldName(world), tile:getPosX(), tile:getPosY())
        if not station then
            safeBubble(player, "`4Station data not found.")
            return true
        end
        safeConsole(player, "`wStation Malady: `o" .. tostring(station.malady_type))
        safeConsole(player, "`wEnabled: `o" .. tostring(station.enabled))
        safeConsole(player, "`wPrice WL: `o" .. tostring(station.price_wl))
        safeConsole(player, "`wEarned WL: `o" .. tostring(station.earned_wl))
        return true
    end

    return true
end)

return HospitalSystem
