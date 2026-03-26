-- MODULE: AutoSurgeon Subsystem for Hospital
-- Handles panels: Auto Surgeon Owner, Storage, Player
-- Requires: hospital.lua (parent) untuk shared functions & constants

local AutoSurgeon = {}

local MaladySystem = rawget(_G, "MaladySystem") or require("malady_rng")

-- Local fallback constants to avoid nil globals during reload race.
local MIN_CURE_PRICE_WL = tonumber(rawget(_G, "MIN_CURE_PRICE_WL")) or 3
local MAX_TOOL_STORAGE = tonumber(rawget(_G, "MAX_TOOL_STORAGE")) or 1000
local CURE_TAX_WL = tonumber(rawget(_G, "CURE_TAX_WL")) or 2
local AUTO_SURGEON_ID = tonumber(rawget(_G, "AUTO_SURGEON_ID")) or 14666
local WORLD_LOCK_ID = tonumber(rawget(_G, "WORLD_LOCK_ID")) or 242

local ALL_SURGICAL_TOOLS = rawget(_G, "ALL_SURGICAL_TOOLS") or {
    1258, 1260, 1262, 1264, 1266, 1268, 1270,
    4308, 4310, 4312, 4314, 4316, 4318
}

local TOOL_REQUIREMENT = rawget(_G, "TOOL_REQUIREMENT") or {}
if next(TOOL_REQUIREMENT) == nil then
    for _, maladyType in pairs(MaladySystem.MALADY or {}) do
        TOOL_REQUIREMENT[maladyType] = {}
        for _, toolID in ipairs(ALL_SURGICAL_TOOLS) do
            TOOL_REQUIREMENT[maladyType][toolID] = 1
        end
    end
end

local MALADY_UI_VIAL = rawget(_G, "MALADY_UI_VIAL") or {}
local MALADY_UI_RNG = rawget(_G, "MALADY_UI_RNG") or {}
local MALADY_ICON = rawget(_G, "MALADY_ICON") or {}
local MALADY_UNLOCK_LEVEL = rawget(_G, "MALADY_UNLOCK_LEVEL") or {}

local BTN_BIND_PREFIX = tostring(rawget(_G, "BTN_BIND_PREFIX") or "v5m_bind_")
local BTN_TOOL_PREFIX = tostring(rawget(_G, "BTN_TOOL_PREFIX") or "v5m_tool_")
local BTN_WITHDRAW_TOOL_PREFIX = tostring(rawget(_G, "BTN_WITHDRAW_TOOL_PREFIX") or "v5m_withdraw_tool_")
local BTN_OPEN_STORAGE = tostring(rawget(_G, "BTN_OPEN_STORAGE") or "v5m_open_storage_panel")
local BTN_STORAGE_BACK = tostring(rawget(_G, "BTN_STORAGE_BACK") or "v5m_storage_back")
local BTN_WITHDRAW_WL = tostring(rawget(_G, "BTN_WITHDRAW_WL") or "v5m_withdraw_station_wl")
local BTN_CLOSE_OWNER = tostring(rawget(_G, "BTN_CLOSE_OWNER") or "v5m_close_station_owner")
local BTN_CURE_MALADY = tostring(rawget(_G, "BTN_CURE_MALADY") or "v5m_cure_malady_station")

local function getStation(worldName, x, y)
    local fn = rawget(_G, "getStation")
    if type(fn) == "function" then return fn(worldName, x, y) end
    return nil
end

local function saveStation(worldName, x, y, data)
    local fn = rawget(_G, "saveStation")
    if type(fn) == "function" then fn(worldName, x, y, data) end
end

local function deleteStationData(worldName, x, y)
    local fn = rawget(_G, "deleteStationData")
    if type(fn) == "function" then fn(worldName, x, y) end
end

local function getHospitalState(worldName)
    local fn = rawget(_G, "getHospitalState")
    if type(fn) == "function" then return fn(worldName) end
    return { level = 1 }
end

local function getPlayerItemAmount(player, itemID)
    local fn = rawget(_G, "getPlayerItemAmount")
    if type(fn) == "function" then return tonumber(fn(player, itemID)) or 0 end
    if player and player.getItemAmount then
        return tonumber(player:getItemAmount(itemID)) or 0
    end
    return 0
end

local function safeBubble(player, text)
    local fn = rawget(_G, "safeBubble")
    if type(fn) == "function" then
        fn(player, text)
        return
    end
    if player and player.onTalkBubble and player.getNetID then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function getOwnerNetGain(priceWL)
    local fn = rawget(_G, "getOwnerNetGain")
    if type(fn) == "function" then return tonumber(fn(priceWL)) or 0 end
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local gain = safePrice - CURE_TAX_WL
    return gain < 0 and 0 or gain
end

local function extractButtonSuffix(buttonName, prefix)
    local fn = rawget(_G, "extractButtonSuffix")
    if type(fn) == "function" then return tostring(fn(buttonName, prefix) or "") end
    if type(buttonName) ~= "string" then return "" end
    local result = buttonName:gsub("^" .. prefix, "")
    return result
end

-- =======================================================
-- STATION MANAGEMENT
-- =======================================================

function AutoSurgeon.ensureStation(worldName, x, y)
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

function AutoSurgeon.setStationMalady(worldName, x, y, maladyType)
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    station.malady_type = tostring(maladyType)
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.setStationEnabled(worldName, x, y, enabled)
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    station.enabled = enabled and 1 or 0
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.setStationPrice(worldName, x, y, priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    station.price_wl = safePrice
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
    local station = getStation(worldName, x, y)
    if not station then return 0 end
    local storage = station.storage or {}
    return tonumber(storage["t" .. tostring(toolID)]) or 0
end

function AutoSurgeon.addStationTool(worldName, x, y, toolID, amount)
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.min(MAX_TOOL_STORAGE, current + math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.removeStationTool(worldName, x, y, toolID, amount)
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.max(0, current - math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType)
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

function AutoSurgeon.getStationPossibleCures(worldName, x, y, maladyType)
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

function AutoSurgeon.consumeStationTools(worldName, x, y, maladyType)
    local req = TOOL_REQUIREMENT[maladyType]
    if not req then return end
    local station = AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    for toolID, need in pairs(req) do
        local current = tonumber(storage["t" .. tostring(toolID)]) or 0
        storage["t" .. tostring(toolID)] = math.max(0, current - need)
    end
    station.storage = storage
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.addStationEarnedWL(worldName, x, y, amount)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = (tonumber(station.earned_wl) or 0) + math.max(0, math.floor(tonumber(amount) or 0))
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.clearStationEarnedWL(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = 0
    saveStation(worldName, x, y, station)
end

function AutoSurgeon.deleteStation(worldName, x, y)
    deleteStationData(worldName, x, y)
end

function AutoSurgeon.refreshStationOperationalState(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    local maladyType = tostring(station.malady_type or "")
    if maladyType == "" then return end
    if not AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
        AutoSurgeon.setStationEnabled(worldName, x, y, false)
    end
end

function AutoSurgeon.getToolStorageLabel(worldName, x, y, toolID)
    return tostring(AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)) .. "/1k"
end

function AutoSurgeon.hasAnyStationStock(worldName, x, y)
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

function AutoSurgeon.canBreakAutoSurgeon(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return true end
    if (tonumber(station.earned_wl) or 0) > 0 then return false end
    if AutoSurgeon.hasAnyStationStock(worldName, x, y) then return false end
    return true
end

function AutoSurgeon.tryDepositToolToStation(player, worldName, x, y, toolID)
    local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
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
    AutoSurgeon.addStationTool(worldName, x, y, toolID, depositAmount)
    safeBubble(player, "`2Deposited " .. tostring(depositAmount) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

function AutoSurgeon.tryWithdrawToolFromStation(player, worldName, x, y, toolID)
    local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
    if current <= 0 then
        safeBubble(player, "`4There is no stock for this tool.")
        return false
    end
    player:changeItem(toolID, current, 0)
    AutoSurgeon.removeStationTool(worldName, x, y, toolID, current)
    safeBubble(player, "`2Withdrew " .. tostring(current) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

-- =======================================================
-- PANEL: AUTO SURGEON STORAGE
-- =======================================================

function AutoSurgeon.showAutoSurgeonStoragePanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_storage_v5m_" .. tostring(x) .. "_" .. tostring(y)
    AutoSurgeon.ensureStation(worldName, x, y)

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
                AutoSurgeon.getToolStorageLabel(worldName, x, y, toolID), toolID
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
        if data["buttonClicked"] ~= BTN_STORAGE_BACK then return true end
        AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
        return true
    end)
end

-- =======================================================
-- PANEL: AUTO SURGEON OWNER
-- =======================================================

function AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_owner_v5m_" .. tostring(x) .. "_" .. tostring(y)
    AutoSurgeon.ensureStation(worldName, x, y)
    AutoSurgeon.refreshStationOperationalState(worldName, x, y)
    local station = getStation(worldName, x, y)

    local maladyType = tostring(station.malady_type or "")
    local enabled    = tonumber(station.enabled) == 1
    local priceWL    = tonumber(station.price_wl) or MIN_CURE_PRICE_WL
    local earnedWL   = tonumber(station.earned_wl) or 0
    local cureCount  = maladyType ~= "" and AutoSurgeon.getStationPossibleCures(worldName, x, y, maladyType) or 0

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
                AutoSurgeon.getToolStorageLabel(worldName, x, y, toolID), toolID
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

        local btn = tostring(data["buttonClicked"] or "")
        local newEnabled = data["station_enabled"] == "1"
        local newPrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(data["station_price_wl"]) or MIN_CURE_PRICE_WL))

        AutoSurgeon.setStationEnabled(worldName, x, y, newEnabled)
        AutoSurgeon.setStationPrice(worldName, x, y, newPrice)

        if btn:match("^" .. BTN_BIND_PREFIX) then
            local newMalady = extractButtonSuffix(btn, BTN_BIND_PREFIX)
            AutoSurgeon.setStationMalady(worldName, x, y, newMalady)
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            safeBubble(cbPlayer, "`2Station bound to " .. (MaladySystem.MALADY_DISPLAY[newMalady] or newMalady) .. ".")
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn:match("^" .. BTN_TOOL_PREFIX) then
            local toolID = tonumber(extractButtonSuffix(btn, BTN_TOOL_PREFIX)) or 0
            if toolID > 0 then
                AutoSurgeon.tryDepositToolToStation(cbPlayer, worldName, x, y, toolID)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            end
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn == BTN_OPEN_STORAGE then
            AutoSurgeon.showAutoSurgeonStoragePanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn == BTN_WITHDRAW_WL then
            local stationNow = getStation(worldName, x, y)
            local wlToWithdraw = tonumber(stationNow and stationNow.earned_wl) or 0
            if wlToWithdraw <= 0 then
                safeBubble(cbPlayer, "`4No World Locks to withdraw.")
            else
                cbPlayer:changeItem(WORLD_LOCK_ID, wlToWithdraw, 0)
                AutoSurgeon.clearStationEarnedWL(worldName, x, y)
                safeBubble(cbPlayer, "`2Withdrew " .. tostring(wlToWithdraw) .. " WL from station earnings.")
            end
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        return true
    end)
end

-- =======================================================
-- PANEL: AUTO SURGEON PLAYER
-- =======================================================

function AutoSurgeon.showAutoSurgeonPlayerPanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_player_v5m_" .. tostring(x) .. "_" .. tostring(y)
    MaladySystem.refreshPlayerState(player)
    AutoSurgeon.ensureStation(worldName, x, y)
    AutoSurgeon.refreshStationOperationalState(worldName, x, y)
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

    player:onDialogRequest(table.concat(dialog, "\n"), 0, function(_, cbPlayer, data)
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
        if not AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
            AutoSurgeon.setStationEnabled(worldName, x, y, false)
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
        AutoSurgeon.consumeStationTools(worldName, x, y, maladyType)
        AutoSurgeon.addStationEarnedWL(worldName, x, y, getOwnerNetGain(priceWL))
        AutoSurgeon.refreshStationOperationalState(worldName, x, y)
        safeBubble(cbPlayer, "`2Your malady has been cured.")
        return true
    end)
end

return AutoSurgeon
