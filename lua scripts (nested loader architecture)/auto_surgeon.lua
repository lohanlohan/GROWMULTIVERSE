-- MODULE
-- auto_surgeon.lua — Auto Surgeon station management, panels, cure logic

local AutoSurgeon = {}

local MaladySystem = _G.MaladySystem

-- Constants (hospital.lua guaranteed loaded first)
local MIN_CURE_PRICE_WL = tonumber(_G.MIN_CURE_PRICE_WL) or 2
local MAX_TOOL_STORAGE  = tonumber(_G.MAX_TOOL_STORAGE) or 1000
local CURE_TAX_RATE     = 0.30
local AUTO_SURGEON_ID   = _G.AUTO_SURGEON_ID
local WORLD_LOCK_ID     = _G.WORLD_LOCK_ID

local ALL_SURGICAL_TOOLS = _G.ALL_SURGICAL_TOOLS

local TOOL_REQUIREMENT = _G.TOOL_REQUIREMENT or {}
if next(TOOL_REQUIREMENT) == nil then
    for _, maladyType in pairs(MaladySystem.MALADY or {}) do
        TOOL_REQUIREMENT[maladyType] = {}
        for _, toolID in ipairs(ALL_SURGICAL_TOOLS) do
            TOOL_REQUIREMENT[maladyType][toolID] = 1
        end
    end
end

local MALADY_UI_VIAL       = _G.MALADY_UI_VIAL or {}
local MALADY_UI_RNG        = _G.MALADY_UI_RNG or {}
local MALADY_ICON          = _G.MALADY_ICON or {}
local MALADY_ICON_VISUAL   = _G.MALADY_ICON_VISUAL or {}
local MALADY_UNLOCK_LEVEL  = _G.MALADY_UNLOCK_LEVEL or {}

local BTN_BIND_PREFIX          = "v5m_bind_"
local BTN_TOOL_PREFIX          = "v5m_tool_"
local BTN_WITHDRAW_TOOL_PREFIX = "v5m_withdraw_tool_"
local BTN_OPEN_STORAGE         = "v5m_open_storage_panel"
local BTN_STORAGE_BACK         = "v5m_storage_back"
local BTN_WITHDRAW_WL          = "v5m_withdraw_station_wl"
local BTN_CLOSE_OWNER          = "v5m_close_station_owner"
local BTN_CURE_MALADY          = "v5m_cure_malady_station"
local BTN_OWNER_CONFIRM        = "v5m_owner_confirm"
local BTN_CHOOSE_ILLNESS       = "v5m_choose_illness"
local BTN_PICKER_BACK          = "v5m_picker_back"
local BTN_TOOL_PANEL_ADD       = "v5m_tool_panel_add"
local BTN_TOOL_PANEL_REMOVE    = "v5m_tool_panel_remove"
local BTN_TOOL_PANEL_BACK      = "v5m_tool_panel_back"
local BTN_TOOL_PANEL_FULL      = "v5m_tool_panel_full"      -- Developer only
local BTN_TOOL_PANEL_CLEAR     = "v5m_tool_panel_clear"     -- Developer only
local ROLE_DEVELOPER           = 51

-- Illness visual IDs for the Auto Surgeon tile (Growtopia client numeric IDs).
-- Note: On this runtime/client build, Torn and Gems visual IDs are reversed
-- compared to some public examples.
-- Illness visual IDs sourced from client XML (tile.extra.autoSurgeonIllness).
-- AutomationCurse has no client visual state — mapped to ChaosInfection (25) as closest.
local AUTO_SURGEON_ILLNESS_VISUAL_ID = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = 20,
    [MaladySystem.MALADY.GEMS_CUTS]            = 21,
    [MaladySystem.MALADY.CHICKEN_FEET]         = 22,
    [MaladySystem.MALADY.GRUMBLETEETH]         = 23,
    [MaladySystem.MALADY.BROKEN_HEARTS]        = 24,
    [MaladySystem.MALADY.CHAOS_INFECTION]      = 25,
    [MaladySystem.MALADY.MOLDY_GUTS]           = 26,
    [MaladySystem.MALADY.BRAINWORMS]           = 27,
    [MaladySystem.MALADY.LUPUS]                = 28,
    [MaladySystem.MALADY.ECTO_BONES]           = 29,
    [MaladySystem.MALADY.FATTY_LIVER]          = 30,
    [MaladySystem.MALADY.AUTOMATION_CURSE]     = 25
}

local function resolveAutoSurgeonIllnessVisualID(maladyType)
    local key    = tostring(maladyType or "")
    if key == "" then return 0 end
    local mapped = tonumber(AUTO_SURGEON_ILLNESS_VISUAL_ID[key])
    if mapped then return mapped end
    local upper = string.upper(key)
    if upper:find("TORN",       1, true) or upper:find("ECTO",  1, true)  then return 20 end
    if upper:find("GEMS",       1, true) or upper:find("MOLD",  1, true)  then return 21 end
    if upper:find("CHICKEN",    1, true) or upper:find("FATTY", 1, true)  then return 22 end
    if upper:find("GRUMBLE",    1, true) or upper:find("BRAIN", 1, true)  then return 23 end
    if upper:find("BROKEN",     1, true) or upper:find("LUPUS", 1, true)  then return 24 end
    if upper:find("CHAOS",      1, true) or upper:find("AUTOMATION", 1, true) then return 25 end
    return 20
end

local MALADY_PICKER_LABEL = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = "Torn Muscle",
    [MaladySystem.MALADY.GEMS_CUTS]            = "Gem Cuts",
    [MaladySystem.MALADY.CHICKEN_FEET]         = "Chicken Feet",
    [MaladySystem.MALADY.GRUMBLETEETH]         = "Grumbleteeth",
    [MaladySystem.MALADY.BROKEN_HEARTS]        = "Broken Hearts",
    [MaladySystem.MALADY.CHAOS_INFECTION]      = "Chaos Infection",
    [MaladySystem.MALADY.BRAINWORMS]           = "Brainworms",
    [MaladySystem.MALADY.MOLDY_GUTS]           = "Moldy Guts",
    [MaladySystem.MALADY.ECTO_BONES]           = "Ecto-Bones",
    [MaladySystem.MALADY.FATTY_LIVER]          = "Fatty Liver",
    [MaladySystem.MALADY.LUPUS]                = "Lupus",
    [MaladySystem.MALADY.AUTOMATION_CURSE]     = "Automation Curse"
}

-- Bridge wrappers (hospital.lua guaranteed loaded first)
local function getWorldName(world)
    return _G.getWorldName(world)
end

local function getStation(worldName, x, y)
    return _G.getStation(worldName, x, y)
end

local function saveStation(worldName, x, y, data)
    _G.saveStation(worldName, x, y, data)
end

local function deleteStationData(worldName, x, y)
    _G.deleteStationData(worldName, x, y)
end

local function getHospitalState(worldName)
    return _G.getHospitalState(worldName)
end

local function getPlayerItemAmount(player, itemID)
    return tonumber(_G.getPlayerItemAmount(player, itemID)) or 0
end

local function safeBubble(player, text)
    _G.safeBubble(player, text)
end

local function getOwnerNetGain(priceWL)
    return tonumber(_G.getOwnerNetGain(priceWL)) or 0
end

local function getWorldTaxWL(priceWL)
    return tonumber(_G.getWorldTaxWL(priceWL)) or 0
end

local function extractButtonSuffix(buttonName, prefix)
    return tostring(_G.extractButtonSuffix(buttonName, prefix) or "")
end

local function getUnlockedAutoSurgeonMaladies(level)
    return _G.getUnlockedAutoSurgeonMaladies(level)
end

-- Per-malady icon override: can be visual string or numeric item/icon ID.
local LOCAL_MALADY_ICON_OVERRIDE = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = "image:game/tiles_page16.rttex;frame:8,22;frameSize:32;",
    [MaladySystem.MALADY.GEMS_CUTS]            = "image:game/tiles_page16.rttex;frame:22,26;frameSize:32;",
    [MaladySystem.MALADY.CHICKEN_FEET]         = 872,
    [MaladySystem.MALADY.GRUMBLETEETH]         = "image:game/tiles_page14.rttex;frame:30,27;frameSize:32;",
    [MaladySystem.MALADY.BROKEN_HEARTS]        = 5810,
    [MaladySystem.MALADY.CHAOS_INFECTION]      = 8538,
    [MaladySystem.MALADY.MOLDY_GUTS]           = 8540,
    [MaladySystem.MALADY.BRAINWORMS]           = 8542,
    [MaladySystem.MALADY.LUPUS]                = 8544,
    [MaladySystem.MALADY.ECTO_BONES]           = 8546,
    [MaladySystem.MALADY.FATTY_LIVER]          = 8548,
    [MaladySystem.MALADY.AUTOMATION_CURSE]     = "image:game/tiles_page14.rttex;frame:26,0;frameSize:32;"
}

local function getVisualIconString(maladyType)
    local visual = LOCAL_MALADY_ICON_OVERRIDE[maladyType]
    if type(visual) == "string" and visual ~= "" then return visual end

    local visualMap = MALADY_ICON_VISUAL or {}
    local mapped = visualMap[maladyType]
    if type(mapped) == "string" and mapped ~= "" then return mapped end
    return nil
end

local function getMaladyIconID(maladyType)
    local localIcon = LOCAL_MALADY_ICON_OVERRIDE[maladyType]
    if type(localIcon) == "number" then
        return math.max(0, math.floor(localIcon))
    end

    local iconMap = MALADY_ICON or {}
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

local function refreshAutoSurgeonTileVisual(world, x, y)
    if type(world) ~= "userdata" then return end
    local tile = world:getTile(math.floor(x / 32), math.floor(y / 32))
    if not tile then return end
    world:updateTile(tile)
end

-- =======================================================
-- MODULE-LEVEL HELPERS
-- =======================================================

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

local function showAutoSurgeonWarning(player, x, y, title, message)
    local warnDlg = "autosurgeon_warn_v5m_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(os.time())
    local warn = "set_default_color|`o\n"
    warn = warn .. "set_bg_color|54,152,198,180|\n"
    warn = warn .. "add_label_with_icon|big|" .. tostring(title) .. "|left||image:game/tiles_page4.rttex;frame:12,9;frameSize:32;|\n"
    warn = warn .. "add_spacer|small|\n"
    warn = warn .. "add_smalltext|" .. tostring(message) .. "|\n"
    warn = warn .. "add_spacer|small|\n"
    warn = warn .. "add_custom_button|btn_warn_close|textLabel:Close;middle_colour:80543231;border_colour:80543231;display:block;|\n"
    warn = warn .. "add_quick_exit|\n"
    warn = warn .. "end_dialog|" .. warnDlg .. "|||\n"
    player:onDialogRequest(warn, 0)
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
-- PANEL: AUTO SURGEON TOOL MANAGEMENT
-- =======================================================

function AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    toolID = tonumber(toolID) or 0
    if toolID <= 0 then
        AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
        return
    end

    local dlgName  = "autosurgeon_tool_panel_v5m_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(toolID)
    local toolName = getItemNameByID(toolID)
    local inBag    = getPlayerItemAmount(player, toolID)
    local inStation = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
    local isDeveloper = player:hasRole(ROLE_DEVELOPER) == true

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|" .. tostring(toolName) .. "|left|" .. tostring(toolID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou have `$" .. tostring(inBag) .. "`2 " .. tostring(toolName) .. "`o in your backpack.|\n"
    d = d .. "add_text_input|tool_add_amount|Amount to add:|" .. tostring(math.max(0, inBag)) .. "|3|\n"
    d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_ADD .. "|textLabel:Add;middle_colour:431888895;border_colour:431888895;display:block;|\n"
    
    -- Developer: Stock Fully button beside Add
    if isDeveloper then
        d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_FULL .. "|textLabel:Stock Fully;middle_colour:7372287;border_colour:7372287;anchor:" .. BTN_TOOL_PANEL_ADD .. ";left:1;margin:10,0;|\n"
    end
    
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou have `$" .. tostring(inStation) .. "/1k`2 " .. tostring(toolName) .. "`o stored in the machine.|\n"
    d = d .. "add_text_input|tool_remove_amount|Amount to remove:|" .. tostring(math.max(0, inStation)) .. "|3|\n"
    d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_REMOVE .. "|textLabel:Remove;middle_colour:80543231;border_colour:80543231;display:block;|\n"
    
    -- Developer: Clear Stock button beside Remove
    if isDeveloper then
        d = d .. "add_custom_button|" .. BTN_TOOL_PANEL_CLEAR .. "|textLabel:Clear Stock;middle_colour:13369519;border_colour:13369519;anchor:" .. BTN_TOOL_PANEL_REMOVE .. ";left:1;margin:10,0;|\n"
    end
    
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_TOOL_PANEL_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0)
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

    player:onDialogRequest(d, 0)
end

-- =======================================================
-- PANEL: AUTO SURGEON ILLNESS PICKER
-- =======================================================

function AutoSurgeon.showAutoSurgeonIllnessPickerPanel(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName  = "autosurgeon_picker_v5m_" .. tostring(x) .. "_" .. tostring(y)
    local station  = getStation(worldName, x, y) or AutoSurgeon.ensureStation(worldName, x, y)
    local selected = tostring(station.malady_type or "")
    local hospitalState = getHospitalState(worldName)
    local hospitalLevel = tonumber(hospitalState.level) or 1

    local d = "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_smalltext|`oPick which illness this Auto Surgeon Station can cure:|\n"
    d = d .. "add_spacer|small|\n"

    local unlockedMaladies = getUnlockedAutoSurgeonMaladies(hospitalLevel)

    for rowStart = 1, #unlockedMaladies, 2 do
        local rowEnd = math.min(rowStart + 1, #unlockedMaladies)
        for i = rowStart, rowEnd do
            local m           = unlockedMaladies[i]
            local btnName     = BTN_BIND_PREFIX .. tostring(m)
            local displayName = tostring(MALADY_PICKER_LABEL[m] or MaladySystem.MALADY_DISPLAY[m] or m)
            local labelColor  = selected == m and "`2" or "`o"
            local iconID      = tonumber(getMaladyIconID(m)) or AUTO_SURGEON_ID

            d = d .. "add_button_with_icon|" .. btnName .. "|" .. labelColor .. displayName .. "|noflags|" .. tostring(iconID) .. "|0|left|\n"
        end
        d = d .. "add_custom_break|\n"
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_PICKER_BACK .. "|textLabel:Back;middle_colour:80543231;border_colour:80543231;display:block;|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0)
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

    local maladyType   = tostring(station.malady_type or "")
    local enabled      = tonumber(station.enabled) == 1
    local priceWL      = tonumber(station.price_wl) or MIN_CURE_PRICE_WL
    local earnedWL     = tonumber(station.earned_wl) or 0
    local cureCount    = maladyType ~= "" and AutoSurgeon.getStationPossibleCures(worldName, x, y, maladyType) or 0
    local maladyName   = maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not Selected"
    local maladyIcon   = getMaladyIconID(maladyType)
    local maladyVisual = getVisualIconString(maladyType)
    if maladyType == "" then maladyIcon = AUTO_SURGEON_ID end
    local withdrawFlags = earnedWL > 0 and "noflags" or "off"
    local reqTools = {}
    local reqMap   = TOOL_REQUIREMENT[maladyType]
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
    d = d .. "add_button|" .. BTN_WITHDRAW_WL .. "|Withdraw World Locks|" .. withdrawFlags .. "|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_checkbox|station_enabled|Enable Auto Surgeon Station|" .. (enabled and "1" or "0") .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_CLOSE_OWNER .. "|textLabel:Close;middle_colour:80543231;border_colour:80543231;|\n"
    d = d .. "add_custom_button|" .. BTN_OWNER_CONFIRM .. "|textLabel:Confirm;middle_colour:431888895;border_colour:431888895;anchor:" .. BTN_CLOSE_OWNER .. ";left:1;margin:40,0;|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    player:onDialogRequest(d, 0)
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
    local maladyVisual = getVisualIconString(maladyType)
    local ownedWL    = getPlayerItemAmount(player, WORLD_LOCK_ID)

    local activeMalady = MaladySystem.getActiveMalady(player)
    if not activeMalady then
        showAutoSurgeonWarning(player, x, y, "Error", "You do not have any malady that requires treatment.")
        return
    end
    if MaladySystem.isRecovering(player) then
        showAutoSurgeonWarning(player, x, y, "Out Of Order", "You are recovering and cannot use Auto Surgeon right now.")
        return
    end
    if maladyType == "" then
        showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
        return
    end
    if tostring(activeMalady) ~= maladyType then
        showAutoSurgeonWarning(player, x, y, "Error", "This Auto Surgeon Station can only cure `5" .. tostring(maladyName) .. "``! Come back soon.")
        return
    end

    local hospitalState = getHospitalState(worldName)
    local hospitalLevel = tonumber(hospitalState.level) or 1
    local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[maladyType]) or 999
    if hospitalLevel < requiredLevel then
        showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
        return
    end
    if not enabled then
        showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
        return
    end
    if not AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
        AutoSurgeon.setStationEnabled(worldName, x, y, false)
        showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
        return
    end

    local dialog = {
        "set_default_color|`o",
        "set_bg_color|54,152,198,180|",
        "add_label_with_icon|big|Auto Surgeon Station|left|" .. tostring(AUTO_SURGEON_ID) .. "|",
        "add_smalltext|This friendly humanoid can cure:|",
        "add_label_with_icon|small|Cost: `2" .. tostring(priceWL) .. "``|left|" .. tostring(WORLD_LOCK_ID) .. "|",
        "add_label_with_icon|small|Owned World Locks: `2" .. tostring(ownedWL) .. "``|left|" .. tostring(WORLD_LOCK_ID) .. "|",
        "add_spacer|small|",
        "add_custom_button|btn_player_close|textLabel:Close;middle_colour:80543231;border_colour:80543231;|",
        "add_custom_button|" .. BTN_CURE_MALADY .. "|textLabel:Purchase Cure;middle_colour:431888895;border_colour:431888895;anchor:btn_player_close;left:1;margin:40,0;|",
        "add_quick_exit|",
        "end_dialog|" .. dlgName .. "|||"
    }

    if maladyVisual then
        table.insert(dialog, 5, "add_label_with_icon|small|`5" .. tostring(maladyName) .. "``|left||" .. maladyVisual .. "|")
    else
        table.insert(dialog, 5, "add_label_with_icon|small|`5" .. tostring(maladyName) .. "``|left|" .. tostring(getMaladyIconID(maladyType)) .. "|")
    end

    player:onDialogRequest(table.concat(dialog, "\n"), 0)
end

-- =======================================================
-- TILE EXTRA DATA — Auto Surgeon visual (illness + wl earned + out of order)
-- =======================================================

local function buildAutoSurgeonTileExtraData(world, tile, game_version)
    if type(tile) ~= "userdata" then return false end
    local fg = tonumber(tile:getTileForeground()) or 0
    if fg ~= AUTO_SURGEON_ID then return false end
    if game_version and game_version < 4.65 then return false end
    if BinaryWriter == nil then return false end

    local worldName  = getWorldName(world)
    local x          = tile:getPosX()
    local y          = tile:getPosY()
    local station    = getStation(worldName, x, y)

    local maladyType = tostring(station and station.malady_type or "")
    local hasMalady  = maladyType ~= ""
    local illnessID  = 0
    if hasMalady then
        illnessID = resolveAutoSurgeonIllnessVisualID(maladyType)
    end
    local forcedIllnessID = tonumber(_G.__HOSPITAL_FORCE_ILLNESS_ID)
    if hasMalady and forcedIllnessID then
        illnessID = math.max(0, math.min(255, math.floor(forcedIllnessID)))
    end

    local wlCountVisual = (tonumber(station and station.earned_wl) or 0) > 0 and 1 or 0
    local forcedWLVisual = tonumber(_G.__HOSPITAL_FORCE_WL_VISUAL)
    if forcedWLVisual then wlCountVisual = forcedWLVisual > 0 and 1 or 0 end

    -- outOfOrder=1 when:
    -- 1. Station does not exist
    -- 2. Malady is not configured (empty string)
    -- 3. Station does not have enough tools to perform cure
    -- 4. Station is not enabled
    local outOfOrder = 0
    if not station or maladyType == "" then
        outOfOrder = 1
    else
        -- Inline check for tools requirement to avoid upvalue dependency
        local req = TOOL_REQUIREMENT[maladyType]
        if not req then
            outOfOrder = 1
        else
            local storage = station.storage or {}
            for toolID, need in pairs(req) do
                if (tonumber(storage["t" .. tostring(toolID)]) or 0) < need then
                    outOfOrder = 1
                    break
                end
            end
        end
        
        -- Station must be enabled to be operational
        if outOfOrder == 0 then
            local enabled = tonumber(station.enabled) == 1
            if not enabled then
                outOfOrder = 1
            end
        end
    end

    local wr = BinaryWriter("")
    -- GTPS Cloud internal keys (server maps these to XML variable names internally)
    -- Total: 1(163) + (1+10+1) + (1+15+1) + (1+7+1) = 39
    wr:WriteUInt32(39)
    wr:WriteUInt8(163)

    wr:WriteUInt8(106)          -- 96 + #"outOfOrder" = 106
    wr:WriteString("outOfOrder")
    wr:WriteUInt8(outOfOrder)

    wr:WriteUInt8(111)          -- 96 + #"selectedIllness" = 111
    wr:WriteString("selectedIllness")
    wr:WriteUInt8(illnessID)

    wr:WriteUInt8(103)          -- 96 + #"wlCount" = 103
    wr:WriteString("wlCount")
    wr:WriteUInt8(wlCountVisual)

    return wr:GetCurrentString()
end

-- Register callback every load (GTPS Cloud clears callbacks on restart but keeps _G).
if type(onGetTileExtraDataCallback) == "function" then
    onGetTileExtraDataCallback(function(world, tile, game_version)
        return buildAutoSurgeonTileExtraData(world, tile, game_version)
    end)
end

-- =======================================================
-- GLOBAL DIALOG CALLBACK — handles all autosurgeon dialogs
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    if type(data) ~= "table" then return false end
    local dlgName = tostring(data["dialog_name"] or "")
    if not dlgName:match("^autosurgeon_") then return false end

    -- Suppress warning dialogs silently
    if dlgName:match("^autosurgeon_warn_") then return true end

    local worldName = getWorldName(world)
    local btn = tostring(data["buttonClicked"] or "")

    -- -------------------------------------------------------
    -- Tool panel: autosurgeon_tool_panel_v5m_{x}_{y}_{toolID}
    -- -------------------------------------------------------
    local tx, ty, ttoolID = dlgName:match("^autosurgeon_tool_panel_v5m_(%d+)_(%d+)_(%d+)$")
    if tx then
        local x      = tonumber(tx)
        local y      = tonumber(ty)
        local toolID = tonumber(ttoolID) or 0
        local toolName = getItemNameByID(toolID)

        if btn == BTN_TOOL_PANEL_BACK then
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            return true
        end

        if btn == BTN_TOOL_PANEL_ADD then
            local requested     = math.max(1, math.floor(tonumber(data["tool_add_amount"]) or 0))
            local haveTool      = getPlayerItemAmount(player, toolID)
            local current       = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            local freeSpace     = MAX_TOOL_STORAGE - current
            local depositAmount = math.min(requested, haveTool, freeSpace)

            if depositAmount <= 0 then
                if current >= MAX_TOOL_STORAGE then
                    safeBubble(player, "`4This tool storage is already full.")
                else
                    safeBubble(player, "`4You do not have enough tools in inventory.")
                end
            else
                player:changeItem(toolID, -depositAmount, 0)
                AutoSurgeon.addStationTool(worldName, x, y, toolID, depositAmount)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                safeBubble(player, "`2Added " .. tostring(depositAmount) .. "x " .. tostring(toolName) .. ".")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
            return true
        end

        if btn == BTN_TOOL_PANEL_REMOVE then
            local requested      = math.max(1, math.floor(tonumber(data["tool_remove_amount"]) or 0))
            local current        = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            local withdrawAmount = math.min(requested, current)

            if withdrawAmount <= 0 then
                safeBubble(player, "`4There is no stock for this tool.")
            else
                player:changeItem(toolID, withdrawAmount, 0)
                AutoSurgeon.removeStationTool(worldName, x, y, toolID, withdrawAmount)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                safeBubble(player, "`2Removed " .. tostring(withdrawAmount) .. "x " .. tostring(toolName) .. ".")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
            return true
        end

        if btn == BTN_TOOL_PANEL_FULL then
            -- Developer only: fill storage to max for this tool
            if player:hasRole(ROLE_DEVELOPER) ~= true then
                safeBubble(player, "`4Developer only command.")
                AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
                return true
            end

            local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            if current >= MAX_TOOL_STORAGE then
                safeBubble(player, "`8This tool storage is already full.")
            else
                AutoSurgeon.addStationTool(worldName, x, y, toolID, MAX_TOOL_STORAGE - current)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                refreshAutoSurgeonTileVisual(world, x, y)
                safeBubble(player, "`2Storage filled to capacity (1000/1k).")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
            return true
        end

        if btn == BTN_TOOL_PANEL_CLEAR then
            -- Developer only: clear all stock for this tool
            if player:hasRole(ROLE_DEVELOPER) ~= true then
                safeBubble(player, "`4Developer only command.")
                AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
                return true
            end

            local current = AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
            if current <= 0 then
                safeBubble(player, "`8There is no stock to clear.")
            else
                AutoSurgeon.removeStationTool(worldName, x, y, toolID, current)
                AutoSurgeon.refreshStationOperationalState(worldName, x, y)
                refreshAutoSurgeonTileVisual(world, x, y)
                safeBubble(player, "`2Cleared " .. tostring(current) .. "x " .. tostring(toolName) .. " from storage.")
            end

            AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
            return true
        end

        -- Any other button on tool panel: re-show it
        AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
        return true
    end

    -- For all remaining panels, extract x,y from last two numbers in dialog name
    local sx, sy = dlgName:match("_(%d+)_(%d+)$")
    if not sx then return true end
    local x = tonumber(sx)
    local y = tonumber(sy)

    -- -------------------------------------------------------
    -- Owner panel: autosurgeon_owner_v5m_{x}_{y}
    -- -------------------------------------------------------
    if dlgName:match("^autosurgeon_owner_") then
        local newEnabled = data["station_enabled"] == "1"
        local newPrice   = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(data["station_price_wl"]) or MIN_CURE_PRICE_WL))

        AutoSurgeon.setStationEnabled(worldName, x, y, newEnabled)
        AutoSurgeon.setStationPrice(worldName, x, y, newPrice)

        if btn == BTN_CLOSE_OWNER then
            -- No dialog follows → refresh here works reliably
            refreshAutoSurgeonTileVisual(world, x, y)
            return true
        end

        if btn == BTN_OWNER_CONFIRM then
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            refreshAutoSurgeonTileVisual(world, x, y)
            return true
        end

        if btn == BTN_CHOOSE_ILLNESS then
            AutoSurgeon.showAutoSurgeonIllnessPickerPanel(world, player, worldName, x, y)
            return true
        end

        if btn:match("^" .. BTN_BIND_PREFIX) then
            local newMalady = extractButtonSuffix(btn, BTN_BIND_PREFIX)
            AutoSurgeon.setStationMalady(worldName, x, y, newMalady)
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            safeBubble(player, "`2Station bound to " .. (MaladySystem.MALADY_DISPLAY[newMalady] or newMalady) .. ".")
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            refreshAutoSurgeonTileVisual(world, x, y)
            return true
        end

        if btn:match("^" .. BTN_TOOL_PREFIX) then
            local toolID = tonumber(extractButtonSuffix(btn, BTN_TOOL_PREFIX)) or 0
            if toolID > 0 then
                AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
                return true
            end
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
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
                            AutoSurgeon.showAutoSurgeonToolPanel(world, player, worldName, x, y, toolID)
                            return true
                        end
                    end
                end
            end
        end

        if btn == BTN_OPEN_STORAGE then
            AutoSurgeon.showAutoSurgeonStoragePanel(world, player, worldName, x, y)
            return true
        end

        if btn == BTN_WITHDRAW_WL then
            local stationNow   = getStation(worldName, x, y)
            local wlToWithdraw = tonumber(stationNow and stationNow.earned_wl) or 0
            if wlToWithdraw <= 0 then
                safeBubble(player, "`4No World Locks to withdraw.")
            else
                player:changeItem(WORLD_LOCK_ID, wlToWithdraw, 0)
                AutoSurgeon.clearStationEarnedWL(worldName, x, y)
                safeBubble(player, "`2Withdrew " .. tostring(wlToWithdraw) .. " WL from station earnings.")
            end
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            refreshAutoSurgeonTileVisual(world, x, y)
            return true
        end

        return true
    end

    -- -------------------------------------------------------
    -- Storage panel: autosurgeon_storage_v5m_{x}_{y}
    -- -------------------------------------------------------
    if dlgName:match("^autosurgeon_storage_") then
        if btn == BTN_STORAGE_BACK then
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            return true
        end

        if btn:match("^" .. BTN_WITHDRAW_TOOL_PREFIX) then
            local toolID = tonumber(extractButtonSuffix(btn, BTN_WITHDRAW_TOOL_PREFIX)) or 0
            if toolID > 0 then
                AutoSurgeon.tryWithdrawToolFromStation(player, worldName, x, y, toolID)
            end
            AutoSurgeon.showAutoSurgeonStoragePanel(world, player, worldName, x, y)
            return true
        end

        return true
    end

    -- -------------------------------------------------------
    -- Illness picker: autosurgeon_picker_v5m_{x}_{y}
    -- -------------------------------------------------------
    if dlgName:match("^autosurgeon_picker_") then
        if btn == BTN_PICKER_BACK then
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            return true
        end

        local newMalady = nil
        if btn:match("^" .. BTN_BIND_PREFIX) then
            newMalady = extractButtonSuffix(btn, BTN_BIND_PREFIX)
        else
            local hospitalState = getHospitalState(worldName)
            local hospitalLevel = tonumber(hospitalState.level) or 1
            local unlockedMaladies = getUnlockedAutoSurgeonMaladies(hospitalLevel)

            for i = 1, #unlockedMaladies do
                local candidate = tostring(unlockedMaladies[i])
                local key       = BTN_BIND_PREFIX .. candidate
                local raw       = data[key]
                if isTruthyChoice(raw, key) then
                    newMalady = candidate
                    break
                end
            end

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
            local stationNow = getStation(worldName, x, y) or AutoSurgeon.ensureStation(worldName, x, y)
            local currentMalady = tostring(stationNow.malady_type or "")

            -- Toggle behavior: clicking selected malady again will unbind and disable station.
            if currentMalady == newMalady then
                AutoSurgeon.setStationMalady(worldName, x, y, "")
                AutoSurgeon.setStationEnabled(worldName, x, y, false)
                safeBubble(player, "`8Station unbound and disabled.")
                AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
                refreshAutoSurgeonTileVisual(world, x, y)
                return true
            end

            local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[newMalady]) or 1
            local currentLevel  = tonumber((getHospitalState(worldName) or {}).level) or 1
            if currentLevel < requiredLevel then
                safeBubble(player, "`4Hospital level is too low for this treatment.")
                AutoSurgeon.showAutoSurgeonIllnessPickerPanel(world, player, worldName, x, y)
                return true
            end
            AutoSurgeon.setStationMalady(worldName, x, y, newMalady)
            AutoSurgeon.refreshStationOperationalState(worldName, x, y)
            safeBubble(player, "`2Station bound to " .. (MaladySystem.MALADY_DISPLAY[newMalady] or newMalady) .. ".")
            AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
            refreshAutoSurgeonTileVisual(world, x, y)
            return true
        end

        return true
    end

    -- -------------------------------------------------------
    -- Player panel: autosurgeon_player_v5m_{x}_{y}
    -- -------------------------------------------------------
    if dlgName:match("^autosurgeon_player_") then
        if btn == "btn_player_close" then return true end
        if btn ~= BTN_CURE_MALADY then return true end

        -- Re-read station data fresh (no closure state)
        local station    = getStation(worldName, x, y)
        if not station then
            showAutoSurgeonWarning(player, x, y, "Error", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        local maladyType = tostring(station.malady_type or "")
        local enabled    = tonumber(station.enabled) == 1
        local priceWL    = tonumber(station.price_wl) or MIN_CURE_PRICE_WL
        local maladyName = maladyType ~= "" and (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) or "Not configured"

        MaladySystem.refreshPlayerState(player)
        local activeMalady = MaladySystem.getActiveMalady(player)

        if not activeMalady then
            showAutoSurgeonWarning(player, x, y, "Error", "You do not have any malady that requires treatment.")
            return true
        end
        if MaladySystem.isRecovering(player) then
            showAutoSurgeonWarning(player, x, y, "Out Of Order", "You are recovering and cannot use Auto Surgeon right now.")
            return true
        end
        if maladyType == "" then
            showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if tostring(activeMalady) ~= maladyType then
            showAutoSurgeonWarning(player, x, y, "Error", "This Auto Surgeon Station can only cure `5" .. tostring(maladyName) .. "``! Come back soon.")
            return true
        end

        local hospitalState = getHospitalState(worldName)
        local hospitalLevel = tonumber(hospitalState.level) or 1
        local requiredLevel = tonumber(MALADY_UNLOCK_LEVEL[maladyType]) or 999
        if hospitalLevel < requiredLevel then
            showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if not enabled then
            showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if not AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
            AutoSurgeon.setStationEnabled(worldName, x, y, false)
            showAutoSurgeonWarning(player, x, y, "Out Of Order", "This Auto Surgeon Station is currently out of order! Come back soon.")
            return true
        end
        if getPlayerItemAmount(player, WORLD_LOCK_ID) < priceWL then
            showAutoSurgeonWarning(player, x, y, "Error", "You do not have enough World Locks to purchase this cure.")
            return true
        end

        local ok, reason = MaladySystem.cureFromAutoSurgeon(player)
        if not ok then
            showAutoSurgeonWarning(player, x, y, "Error", "Auto Surgeon cure failed: " .. tostring(reason))
            return true
        end

        player:changeItem(WORLD_LOCK_ID, -priceWL, 0)
        AutoSurgeon.consumeStationTools(worldName, x, y, maladyType)
        AutoSurgeon.addStationEarnedWL(worldName, x, y, getOwnerNetGain(priceWL))
        AutoSurgeon.refreshStationOperationalState(worldName, x, y)
        refreshAutoSurgeonTileVisual(world, x, y)
        safeBubble(player, "`2Your malady has been cured.")
        return true
    end

    -- Unknown autosurgeon dialog — suppress
    return true
end)

_G.AutoSurgeon = AutoSurgeon
return AutoSurgeon
