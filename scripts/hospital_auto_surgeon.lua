-- MODULE: AutoSurgeon Subsystem for Hospital
-- Handles panels: Auto Surgeon Owner, Storage, Player
-- Requires: hospital.lua (parent) untuk shared functions & constants

local AutoSurgeon = {}

local MaladySystem = rawget(_G, "MaladySystem") or require("malady_rng")

-- Local fallback constants to avoid nil globals during reload race.
local MIN_CURE_PRICE_WL = tonumber(rawget(_G, "MIN_CURE_PRICE_WL")) or 2
local MAX_TOOL_STORAGE = tonumber(rawget(_G, "MAX_TOOL_STORAGE")) or 1000
local CURE_TAX_RATE = 0.30
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
local MALADY_ICON_VISUAL = rawget(_G, "MALADY_ICON_VISUAL") or {}
local MALADY_UNLOCK_LEVEL = rawget(_G, "MALADY_UNLOCK_LEVEL") or {}

local BTN_BIND_PREFIX = tostring(rawget(_G, "BTN_BIND_PREFIX") or "v5m_bind_")
local BTN_TOOL_PREFIX = tostring(rawget(_G, "BTN_TOOL_PREFIX") or "v5m_tool_")
local BTN_WITHDRAW_TOOL_PREFIX = tostring(rawget(_G, "BTN_WITHDRAW_TOOL_PREFIX") or "v5m_withdraw_tool_")
local BTN_OPEN_STORAGE = tostring(rawget(_G, "BTN_OPEN_STORAGE") or "v5m_open_storage_panel")
local BTN_STORAGE_BACK = tostring(rawget(_G, "BTN_STORAGE_BACK") or "v5m_storage_back")
local BTN_WITHDRAW_WL = tostring(rawget(_G, "BTN_WITHDRAW_WL") or "v5m_withdraw_station_wl")
local BTN_CLOSE_OWNER = tostring(rawget(_G, "BTN_CLOSE_OWNER") or "v5m_close_station_owner")
local BTN_CURE_MALADY = tostring(rawget(_G, "BTN_CURE_MALADY") or "v5m_cure_malady_station")
local BTN_OWNER_CONFIRM = tostring(rawget(_G, "BTN_OWNER_CONFIRM") or "v5m_owner_confirm")
local BTN_CHOOSE_ILLNESS = tostring(rawget(_G, "BTN_CHOOSE_ILLNESS") or "v5m_choose_illness")
local BTN_PICKER_BACK = tostring(rawget(_G, "BTN_PICKER_BACK") or "v5m_picker_back")
local BTN_TOOL_PANEL_ADD = tostring(rawget(_G, "BTN_TOOL_PANEL_ADD") or "v5m_tool_panel_add")
local BTN_TOOL_PANEL_REMOVE = tostring(rawget(_G, "BTN_TOOL_PANEL_REMOVE") or "v5m_tool_panel_remove")
local BTN_TOOL_PANEL_BACK = tostring(rawget(_G, "BTN_TOOL_PANEL_BACK") or "v5m_tool_panel_back")

local MALADY_PICKER_LABEL = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = "Torn Muscle",
    [MaladySystem.MALADY.GEMS_CUTS] = "Gem Cuts",
    [MaladySystem.MALADY.CHICKEN_FEET] = "Chicken Feet",
    [MaladySystem.MALADY.GRUMBLETEETH] = "Grumbleteeth",
    [MaladySystem.MALADY.BROKEN_HEARTS] = "Broken Hearts",
    [MaladySystem.MALADY.CHAOS_INFECTION] = "Chaos Infection",
    [MaladySystem.MALADY.BRAINWORMS] = "Brainworms",
    [MaladySystem.MALADY.MOLDY_GUTS] = "Moldy Guts",
    [MaladySystem.MALADY.ECTO_BONES] = "Ecto-Bones",
    [MaladySystem.MALADY.FATTY_LIVER] = "Fatty Liver",
    [MaladySystem.MALADY.LUPUS] = "Lupus",
    [MaladySystem.MALADY.AUTOMATION_CURSE] = "Automation Curse"
}

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
    local tax = math.max(1, math.ceil(safePrice * CURE_TAX_RATE))
    local gain = safePrice - tax
    return gain < 0 and 0 or gain
end

local function getWorldTaxWL(priceWL)
    local fn = rawget(_G, "getWorldTaxWL")
    if type(fn) == "function" then return tonumber(fn(priceWL)) or 0 end
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    return math.max(1, math.ceil(safePrice * CURE_TAX_RATE))
end

local function extractButtonSuffix(buttonName, prefix)
    local fn = rawget(_G, "extractButtonSuffix")
    if type(fn) == "function" then return tostring(fn(buttonName, prefix) or "") end
    if type(buttonName) ~= "string" then return "" end
    local result = buttonName:gsub("^" .. prefix, "")
    return result
end

local function getUnlockedAutoSurgeonMaladies(level)
    local fn = rawget(_G, "getUnlockedAutoSurgeonMaladies")
    if type(fn) == "function" then
        local list = fn(level)
        if type(list) == "table" then return list end
    end

    local merged = {}
    local pools = { MALADY_UI_RNG, MALADY_UI_VIAL }
    local currentLevel = math.max(1, math.floor(tonumber(level) or 1))
    for p = 1, #pools do
        local arr = pools[p]
        for i = 1, #arr do
            local m = arr[i]
            local need = tonumber(MALADY_UNLOCK_LEVEL[m]) or 999
            if currentLevel >= need then
                merged[#merged + 1] = m
            end
        end
    end
    return merged
end

local function getVisualIconString(maladyType)
    local visualMap = rawget(_G, "MALADY_ICON_VISUAL") or MALADY_ICON_VISUAL or {}
    local visual = visualMap[maladyType]
    if type(visual) == "string" and visual ~= "" then return visual end
    return nil
end

local function getMaladyIconID(maladyType)
    local iconMap = rawget(_G, "MALADY_ICON") or MALADY_ICON or {}
    return tonumber(iconMap[maladyType]) or AUTO_SURGEON_ID
end

local function getItemNameByID(itemID)
    if type(getItem) == "function" then
        local itemObj = getItem(itemID)
        if itemObj and itemObj.getName then
            return tostring(itemObj:getName())
        end
    end
    return "Tool #" .. tostring(itemID)
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

function AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    toolID = tonumber(toolID) or 0
    if toolID <= 0 then
        AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
        return
    end

    local dlgName = "autosurgeon_tool_panel_v5m_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(toolID)
    local toolName = getItemNameByID(toolID)
    local inBag = getPlayerItemAmount(player, toolID)
    local inStation = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|" .. tostring(toolName) .. "|left|" .. tostring(toolID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou have `$" .. tostring(inBag) .. "`2 " .. tostring(toolName) .. "`o in your backpack.|\n"
    d = d .. "add_text_input|tool_add_amount|Amount to add:|" .. tostring(math.max(0, inBag)) .. "|3|\n"
    d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_ADD .. "|textLabel:Add;middle_colour:431888895;border_colour:431888895;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou have `$" .. tostring(inStation) .. "/1k`2 " .. tostring(toolName) .. "`o stored in the machine.|\n"
    d = d .. "add_text_input|tool_remove_amount|Amount to remove:|" .. tostring(math.max(0, inStation)) .. "|3|\n"
    d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_REMOVE .. "|textLabel:Remove;middle_colour:80543231;border_colour:80543231;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_TOOL_PANEL_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end

        local btn = tostring(data["buttonClicked"] or "")
        if btn == BTN_TOOL_PANEL_BACK then
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn == BTN_TOOL_PANEL_ADD then
            local requested = math.max(1, math.floor(tonumber(data["tool_add_amount"]) or 0))
            local haveTool = getPlayerItemAmount(cbPlayer, toolID)
            local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            local freeSpace = MAX_TOOL_STORAGE - current
            local depositAmount = math.min(requested, haveTool, freeSpace)

            if depositAmount <= 0 then
                if current >= MAX_TOOL_STORAGE then
                    safeBubble(cbPlayer, "`4This tool storage is already full.")
                else
                    safeBubble(cbPlayer, "`4You do not have enough tools in inventory.")
                end
            else
                cbPlayer:changeItem(toolID, -depositAmount, 0)
                AutoSurgeon.addStationTool(worldName, x, y, toolID, depositAmount)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                safeBubble(cbPlayer, "`2Added " .. tostring(depositAmount) .. "x " .. tostring(toolName) .. ".")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(cbWorld, cbPlayer, worldName, x, y, toolID)
            return true
        end

        if btn == BTN_TOOL_PANEL_REMOVE then
            local requested = math.max(1, math.floor(tonumber(data["tool_remove_amount"]) or 0))
            local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            local withdrawAmount = math.min(requested, current)

            if withdrawAmount <= 0 then
                safeBubble(cbPlayer, "`4There is no stock for this tool.")
            else
                cbPlayer:changeItem(toolID, withdrawAmount, 0)
                AutoSurgeon.removeStationTool(worldName, x, y, toolID, withdrawAmount)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                safeBubble(cbPlayer, "`2Removed " .. tostring(withdrawAmount) .. "x " .. tostring(toolName) .. ".")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(cbWorld, cbPlayer, worldName, x, y, toolID)
            return true
        end

        return true
    end)
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
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Storage|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_smalltext|`oClick a tool to withdraw all stock for that tool.|\n"
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
-- PANEL: AUTO SURGEON ILLNESS PICKER
-- =======================================================

function AutoSurgeon.showAutoSurgeonIllnessPickerPanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "autosurgeon_picker_v5m_" .. tostring(x) .. "_" .. tostring(y)
    local station = getStation(worldName, x, y) or AutoSurgeon.ensureStation(worldName, x, y)
    local selected = tostring(station.malady_type or "")
    local hospitalState = getHospitalState(worldName)
    local hospitalLevel = tonumber(hospitalState.level) or 1

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_smalltext|`oPick which illness this Auto Surgeon Station can cure:|\n"
    d = d .. "add_spacer|small|\n"

    local unlockedMaladies = getUnlockedAutoSurgeonMaladies(hospitalLevel)
    local perRow = 4
    local rowCount = math.max(1, math.floor((#unlockedMaladies + perRow - 1) / perRow))
    local pickerBottomPad = 30 + (rowCount * 92)

    d = d .. "add_custom_margin|x:34;y:0|\n"
    for i = 1, #unlockedMaladies do
        local m = unlockedMaladies[i]
        local btnName = BTN_BIND_PREFIX .. tostring(m)
        local displayName = tostring(MALADY_PICKER_LABEL[m] or MaladySystem.MALADY_DISPLAY[m] or m)
        local visual = getVisualIconString(m)
        local labelColor = selected == m and "`2" or "`o"

        if visual then
            d = d .. "add_custom_button|" .. btnName .. "|" .. visual .. "image_size:32,32;width:0.05;|\n"
            d = d .. "add_custom_label|" .. labelColor .. displayName .. "|target:" .. btnName .. ";top:1.32;left:0.62;size:tiny;|\n"
        else
            local iconID = getMaladyIconID(m)
            d = d .. "add_button_with_icon|" .. btnName .. "|" .. labelColor .. displayName .. "|" .. tostring(iconID) .. "|\n"
        end

        d = d .. "add_custom_margin|x:86;y:0|\n"
        if (i % perRow) == 0 then
            d = d .. "reset_placement_x|\n"
            d = d .. "add_custom_margin|x:34;y:92|\n"
        end
    end
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_margin|x:0;y:" .. tostring(pickerBottomPad) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_PICKER_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end

        local btn = tostring(data["buttonClicked"] or "")
        if btn == BTN_PICKER_BACK then
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        local newMalady = nil
        if btn:match("^" .. BTN_BIND_PREFIX) then
            newMalady = extractButtonSuffix(btn, BTN_BIND_PREFIX)
        else
            -- Some UI skins send custom-button clicks via keyed fields instead of buttonClicked.
            local function isTruthyChoice(value, keyName)
                if value == nil then return false end
                local v = string.lower(tostring(value))
                if v == "" or v == "0" or v == "false" or v == "off" or v == "no" or v == "nil" then
                    return false
                end
                if keyName and (v == string.lower(tostring(keyName))) then
                    return true
                end
                return true
            end

            for i = 1, #unlockedMaladies do
                local candidate = tostring(unlockedMaladies[i])
                local key = BTN_BIND_PREFIX .. candidate
                local raw = data[key]
                if isTruthyChoice(raw, key) then
                    newMalady = candidate
                    break
                end
            end

            -- Fallback: scan all payload keys that start with bind prefix.
            if (not newMalady or newMalady == "") and type(data) == "table" then
                for k, v in pairs(data) do
                    local keyName = tostring(k)
                    if keyName:match("^" .. BTN_BIND_PREFIX) and isTruthyChoice(v, keyName) then
                        newMalady = extractButtonSuffix(keyName, BTN_BIND_PREFIX)
                        break
                    end
                end
            end
        end

        if newMalady and newMalady ~= "" then
            local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[newMalady]) or 1
            local currentLevel = tonumber((getHospitalState(worldName) or {}).level) or 1
            if currentLevel < requiredLevel then
                safeBubble(cbPlayer, "`4Hospital level is too low for this treatment.")
                AutoSurgeon.showAutoSurgeonIllnessPickerPanel(cbWorld, cbPlayer, worldName, x, y)
                return true
            end
            AutoSurgeon.setStationMalady(worldName, x, y, newMalady)
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            safeBubble(cbPlayer, "`2Station bound to " .. (MaladySystem.MALADY_DISPLAY[newMalady] or newMalady) .. ".")
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

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
    local maladyName = maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not Selected"
    local maladyIcon = getMaladyIconID(maladyType)
    local maladyVisual = getVisualIconString(maladyType)
    if maladyType == "" then maladyIcon = AUTO_SURGEON_ID end
    local withdrawFlags = earnedWL > 0 and "noflags" or "off"
    local reqTools = {}
    local reqMap = TOOL_REQUIREMENT[maladyType]
    if type(reqMap) == "table" then
        for toolID in pairs(reqMap) do
            reqTools[#reqTools + 1] = tonumber(toolID) or 0
        end
        table.sort(reqTools)
    end
    if #reqTools == 0 then
        for i = 1, math.min(5, #ALL_SURGICAL_TOOLS) do
            reqTools[#reqTools + 1] = ALL_SURGICAL_TOOLS[i]
        end
    end

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oThis humanoid can cure:|\n"
    if maladyVisual then
        d = d .. "add_label_with_icon|small|`5" .. tostring(maladyName) .. "``|left||" .. maladyVisual .. "|\n"
    else
        d = d .. "add_label_with_icon|small|`5" .. tostring(maladyName) .. "``|left|" .. tostring(maladyIcon) .. "|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_CHOOSE_ILLNESS .. "|Choose another illness|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou need these Surgeon tools:|\n"
    d = d .. "add_smalltext|`5Click on the tool to deposit or withdraw|\n"
    d = d .. "add_spacer|small|\n"

    for rowStart = 1, #reqTools, 5 do
        local rowEnd = math.min(rowStart + 4, #reqTools)
        for i = rowStart, rowEnd do
            local toolID = reqTools[i]
            local countNow = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            d = d .. string.format(
                "add_button_with_icon|%s%d|%s|is_count_label,noflags|%d|1|left|\n",
                BTN_TOOL_PREFIX, toolID,
                AutoSurgeon.getToolStorageLabel(worldName, x, y, toolID),
                toolID
            )
        end
        d = d .. "add_custom_break|\n"
        d = d .. "add_spacer|small|\n"
    end
    d = d .. "add_custom_margin|x:0;y:6|\n"
    d = d .. "add_button|" .. BTN_OPEN_STORAGE .. "|Storage|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    local taxWL = getWorldTaxWL(priceWL)
    d = d .. "add_smalltext|`oPrice of one cure:|\n"
    d = d .. "add_text_input|station_price_wl||" .. tostring(priceWL) .. "|4|\n"
    d = d .. "add_smalltext|`oGrowtopia world tax will be: `9" .. tostring(taxWL) .. " World Locks|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oAuto Surgeon Station can cure " .. tostring(maladyName) .. ": `2" .. tostring(cureCount) .. " Time|\n"
    d = d .. "add_smalltext|`oYou have earned `2" .. tostring(earnedWL) .. "`` World Locks.|\n"
    d = d .. "add_button|" .. BTN_WITHDRAW_WL  .. "|Withdraw World Locks|" .. withdrawFlags .. "|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_checkbox|station_enabled|Enable Auto Surgeon Station|" .. (enabled and "1" or "0") .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_CLOSE_OWNER  .. "|textLabel:Close;middle_colour:80543231;border_colour:80543231;|\n"
    d = d .. "add_custom_button|" .. BTN_OWNER_CONFIRM .. "|textLabel:Confirm;middle_colour:431888895;border_colour:431888895;anchor:" .. BTN_CLOSE_OWNER .. ";left:1;margin:40,0;|\n"
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

        if btn == BTN_CLOSE_OWNER then
            return true
        end

        if btn == BTN_CHOOSE_ILLNESS then
            AutoSurgeon.showAutoSurgeonIllnessPickerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn == BTN_OWNER_CONFIRM then
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

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
                AutoSurgeon.showAutoSurgeonToolPanel(cbWorld, cbPlayer, worldName, x, y, toolID)
                return true
            end
            AutoSurgeon.showAutoSurgeonOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if (not btn or btn == "") and type(data) == "table" then
            for k, v in pairs(data) do
                local keyName = tostring(k)
                if keyName:match("^" .. BTN_TOOL_PREFIX) then
                    local raw = string.lower(tostring(v or ""))
                    if raw ~= "" and raw ~= "0" and raw ~= "false" and raw ~= "off" then
                        local toolID = tonumber(extractButtonSuffix(keyName, BTN_TOOL_PREFIX)) or 0
                        if toolID > 0 then
                            AutoSurgeon.showAutoSurgeonToolPanel(cbWorld, cbPlayer, worldName, x, y, toolID)
                            return true
                        end
                    end
                end
            end
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
    local maladyName = maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not configured"
    local ownedWL    = getPlayerItemAmount(player, WORLD_LOCK_ID)

    local function showWarningDialog(targetPlayer, title, message)
        local warnDlg = "autosurgeon_warn_v5m_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(os.time())
        local warn = "set_default_color|`o\n"
        warn = warn .. "set_bg_color|54,152,198,180|\n"
        warn = warn .. "add_label_with_icon|big|" .. tostring(title) .. "|left|2946|\n"
        warn = warn .. "add_spacer|small|\n"
        warn = warn .. "add_smalltext|" .. tostring(message) .. "|\n"
        warn = warn .. "add_spacer|small|\n"
        warn = warn .. "add_custom_button|btn_warn_close|textLabel:Close;middle_colour:80543231;border_colour:80543231;display:block;|\n"
        warn = warn .. "add_quick_exit|\n"
        warn = warn .. "end_dialog|" .. warnDlg .. "|||\n"
        targetPlayer:onDialogRequest(warn, 0)
    end

    local dialog = {
        "set_default_color|`o",
        "set_bg_color|54,152,198,180|",
        "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|",
        "add_smalltext|This friendly humanoid can cure:|",
        "add_label_with_icon|small|`5" .. tostring(maladyName) .. "``|left|" .. tostring(getMaladyIconID(maladyType)) .. "|",
        "add_label_with_icon|small|Cost: `2" .. tostring(priceWL) .. "``|left|" .. tostring(WORLD_LOCK_ID) .. "|",
        "add_label_with_icon|small|Owned World Locks: `2" .. tostring(ownedWL) .. "``|left|" .. tostring(WORLD_LOCK_ID) .. "|",
        "add_spacer|small|",
        "add_custom_button|btn_player_close|textLabel:Close;middle_colour:80543231;border_colour:80543231;|",
        "add_custom_button|" .. BTN_CURE_MALADY .. "|textLabel:Purchase Cure;middle_colour:431888895;border_colour:431888895;anchor:btn_player_close;left:1;margin:40,0;|",
        "add_quick_exit|",
        "end_dialog|" .. dlgName .. "|||"
    }

    player:onDialogRequest(table.concat(dialog, "\n"), 0, function(_, cbPlayer, data)
        if type(data) ~= "table" then return end
        if data["dialog_name"] ~= dlgName then return end
        local clicked = tostring(data["buttonClicked"] or "")
        if clicked == "btn_player_close" then return true end
        if clicked ~= BTN_CURE_MALADY then return true end

        MaladySystem.refreshPlayerState(cbPlayer)
        local activeMalady = MaladySystem.getActiveMalady(cbPlayer)

        if not activeMalady then
            showWarningDialog(cbPlayer, "Error", "You do not have any malady that requires treatment.")
            return true
        end
        if MaladySystem.isRecovering(cbPlayer) then
            showWarningDialog(cbPlayer, "Out Of Order", "You are recovering and cannot use Auto Surgeon right now.")
            return true
        end
        if maladyType == "" then
            showWarningDialog(cbPlayer, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if tostring(activeMalady) ~= maladyType then
            showWarningDialog(cbPlayer, "Error", "This Auto Surgeon Station can only cure `5" .. tostring(maladyName) .. "``! Come back soon.")
            return true
        end

        local hospitalState = getHospitalState(worldName)
        local hospitalLevel = tonumber(hospitalState.level) or 1
        local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[maladyType]) or 999
        if hospitalLevel < requiredLevel then
            showWarningDialog(cbPlayer, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if not enabled then
            showWarningDialog(cbPlayer, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if not AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
            AutoSurgeon.setStationEnabled(worldName, x, y, false)
            showWarningDialog(cbPlayer, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if getPlayerItemAmount(cbPlayer, WORLD_LOCK_ID) < priceWL then
            showWarningDialog(cbPlayer, "Error", "You do not have enough World Locks to purchase this cure.")
            return true
        end

        local ok, reason = MaladySystem.cureFromAutoSurgeon(cbPlayer)
        if not ok then
            showWarningDialog(cbPlayer, "Error", "Auto Surgeon cure failed: " .. tostring(reason))
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
