-- MODULE
-- reception_desk.lua — Reception Desk panels: main, stats, level-up, manage doctors, doctor panel

local ReceptionDesk = {}
local MaladySystem = _G.MaladySystem

-- Constants from hospital.lua (guaranteed set since hospital loads before reception_desk)
local RECEPTION_DESK_ID = _G.RECEPTION_DESK_ID
local AUTO_SURGEON_ID = _G.AUTO_SURGEON_ID
local OPERATING_TABLE_ID = _G.OPERATING_TABLE_ID
local WORLD_LOCK_ID = _G.WORLD_LOCK_ID
local DIAMOND_LOCK_ID = _G.DIAMOND_LOCK_ID
local BGL_ID = _G.BGL_ID
local MAX_HOSPITAL_RATING = _G.MAX_HOSPITAL_RATING
local RATING_STEP_CURES = _G.RATING_STEP_CURES

local BTN_SHOW_STATS = _G.BTN_SHOW_STATS
local BTN_LEVEL_UP = _G.BTN_LEVEL_UP
local BTN_MANAGE_DOCTORS = _G.BTN_MANAGE_DOCTORS or "v5m_manage_doctors"
local BTN_REMOVE_DOCTORS_MAIN = _G.BTN_REMOVE_DOCTORS_MAIN or "v5m_remove_doctors_main"
local BTN_BACK_STATS = _G.BTN_BACK_STATS
local BTN_LEVEL_UP_BACK = _G.BTN_LEVEL_UP_BACK
local BTN_LEVEL_UP_NEW_CONFIRM = _G.BTN_LEVEL_UP_NEW_CONFIRM
local BTN_ADD_DOCTOR_PREFIX = _G.BTN_ADD_DOCTOR_PREFIX
local BTN_REMOVE_DOCTOR_PREFIX = _G.BTN_REMOVE_DOCTOR_PREFIX
local BTN_DOCTORS_BACK = _G.BTN_DOCTORS_BACK
local DLG_MANAGE_DOCTORS = _G.DLG_MANAGE_DOCTORS

local HOSPITAL_LEVELS = _G.HOSPITAL_LEVELS
local LEVEL_UP_RULES = _G.LEVEL_UP_RULES
local HOSPITAL_STATS_MALADY_ROWS = _G.HOSPITAL_STATS_MALADY_ROWS
local MALADY_ICON_VISUAL = _G.MALADY_ICON_VISUAL
local MALADY_ICON = _G.MALADY_ICON

local MALADY_PREVIEW_LABEL = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = "Torn Muscle",
    [MaladySystem.MALADY.GEMS_CUTS] = "Gem Cuts",
    [MaladySystem.MALADY.CHICKEN_FEET] = "Chicken Feet",
    [MaladySystem.MALADY.GRUMBLETEETH] = "Grumbleteeth"
}

local function getUnlockedAutoSurgeonMaladies(level)
    return _G.getUnlockedAutoSurgeonMaladies(level)
end

local function getMaladyVisualIcon(maladyType)
    -- Stable overrides for fullscreen rendering (avoid runtime map mismatch).
    if maladyType == MaladySystem.MALADY.TORN_PUNCHING_MUSCLE then
        return "image:game/tiles_page16.rttex;frame:8,22;frameSize:32;"
    end
    if maladyType == MaladySystem.MALADY.GEMS_CUTS then
        return "image:game/tiles_page16.rttex;frame:22,26;frameSize:32;"
    end

    local visualMap = MALADY_ICON_VISUAL or {}
    local visual = visualMap[maladyType]
    if type(visual) == "string" and visual ~= "" then return visual end
    return nil
end

local function getMaladyIconID(maladyType)
    local iconMap = MALADY_ICON or {}
    return tonumber(iconMap[maladyType]) or AUTO_SURGEON_ID
end

local function getTierColor(current, required)
    local c = math.max(0, math.floor(tonumber(current) or 0))
    local r = math.max(0, math.floor(tonumber(required) or 0))
    if r <= 0 then return "`2" end
    if c >= r then return "`2" end

    local ratio = c / r
    if ratio <= 0 then return "`4" end
    if ratio < 0.25 then return "`6" end
    if ratio < 0.7 then return "`9" end
    return "`^"
end

local function formatTierProgress(current, required)
    local c = math.max(0, math.floor(tonumber(current) or 0))
    local r = math.max(0, math.floor(tonumber(required) or 0))
    return getTierColor(c, r) .. tostring(c) .. "/" .. tostring(r) .. "``"
end

local function resolveWorldName(world, player)
    return _G.getWorldName(world, player)
end

-- Wrappers calling hospital.lua shared functions via _G bridge
local function loadHospital(worldName)
    return _G.loadHospital(worldName)
end

local function saveHospital(worldName, state)
    _G.saveHospital(worldName, state)
end

local function isWorldOwner(world, player)
    return _G.isWorldOwner(world, player)
end

local function getUserID(player)
    return _G.getUserID(player)
end

local function getHospitalState(worldName)
    return _G.getHospitalState(worldName)
end

local function getHospitalRatingCounter(worldName)
    return _G.getHospitalRatingCounter(worldName)
end

local function getHospitalTreatmentStats(worldName)
    return _G.getHospitalTreatmentStats(worldName)
end

local function countAutoSurgeons(world)
    return _G.countAutoSurgeons(world)
end

local function countOperatingTables(world)
    return _G.countOperatingTables(world)
end

local function getOperatingTableCapacityByLevel(level)
    return _G.getOperatingTableCapacityByLevel(level)
end

local function getOperatingPatientDurationByLevel(level)
    return _G.getOperatingPatientDurationByLevel(level)
end

local function getRequirementIconID(current, required)
    return _G.getRequirementIconID(current, required)
end

local function safeBubble(player, text)
    _G.safeBubble(player, text)
end

local function getPlayerItemAmount(player, itemID)
    return _G.getPlayerItemAmount(player, itemID)
end

local function getTotalWLEquivalent(player)
    return _G.getTotalWLEquivalent(player)
end

local function getLevelUpSnapshot(world, worldName, state, playerWL)
    return _G.getLevelUpSnapshot(world, worldName, state, playerWL)
end

local function isLevelUpReadyForRule(levelRule, snapshot, upgradeCost)
    return _G.isLevelUpReadyForRule(levelRule, snapshot, upgradeCost)
end

-- =======================================================
-- DOCTOR MANAGEMENT
-- =======================================================

function ReceptionDesk.isDoctor(worldName, userID)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    return doctors["u" .. tostring(userID)] ~= nil
end

function ReceptionDesk.isEffectiveDoctor(world, worldName, userID, player)
    if player and isWorldOwner(world, player) then return true end
    return ReceptionDesk.isDoctor(worldName, userID)
end

function ReceptionDesk.addDoctor(worldName, userID, displayName)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = tostring(displayName or "Unknown")
    saveHospital(worldName, state)
end

function ReceptionDesk.removeDoctor(worldName, userID)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = nil
    saveHospital(worldName, state)
end

function ReceptionDesk.countDoctors(worldName)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    local n = 0
    for _ in pairs(doctors) do n = n + 1 end
    return n
end

function ReceptionDesk.addDoctorSurgery(worldName, userID)
    local state = loadHospital(worldName)
    local stats = state.doctor_stats or {}
    local key = "u" .. tostring(userID)
    stats[key] = (tonumber(stats[key]) or 0) + 1
    state.doctor_stats = stats
    saveHospital(worldName, state)
end

function ReceptionDesk.getDoctorLeaderboard(worldName)
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

-- =======================================================
-- PANEL: RECEPTION DESK MAIN
-- =======================================================

function ReceptionDesk.showReceptionDeskPanel(world, player)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    MaladySystem.refreshPlayerState(player)
    local worldName = resolveWorldName(world, player)
    local state = getHospitalState(worldName)
    local level = tonumber(state.level) or 1
    local ratingData = getHospitalRatingCounter(worldName) or {}
    ratingData.rating = tonumber(ratingData.rating) or 0
    ratingData.counter = tonumber(ratingData.counter) or 0
    ratingData.need = tonumber(ratingData.need) or math.max(0, (tonumber(RATING_STEP_CURES) or 100) - ratingData.counter)
    local maxRating = tonumber(MAX_HOSPITAL_RATING) or 5
    local ratingStep = tonumber(RATING_STEP_CURES) or 100
    local playerName = tostring(player.getName and player:getName() or "Player")
    local doctorCount = ReceptionDesk.countDoctors(worldName)
    local doctorCap = 1

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wReception Desk|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|Hello there, " .. playerName .. "`o. Welcome to `2" .. worldName .. "`o Hospital.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|Level: " .. getTierColor(level, 3) .. tostring(level) .. "``|\n"
    d = d .. "add_smalltext|Rating: " .. formatTierProgress(ratingData.rating, maxRating) .. "|\n"
    if (tonumber(ratingData.rating) or 0) >= maxRating then
        d = d .. "add_smalltext|Rating Counter: `2MAX``|\n"
    else
        d = d .. "add_smalltext|Rating Counter: " .. formatTierProgress(ratingData.counter, ratingStep) .. " `o(" .. tostring(ratingData.need) .. " to next)``|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_SHOW_STATS .. "|textLabel:Hospital Stats;middle_colour:3389566975;border_colour:3389566975;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_LEVEL_UP .. "|textLabel:Level Up Hospital;middle_colour:431888895;border_colour:431888895;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    if doctorCount < doctorCap then
        d = d .. "add_player_picker|playerNetID|`wAdd Doctors " .. tostring(doctorCount) .. "/" .. tostring(doctorCap) .. "``|\n"
    else
        d = d .. "add_custom_button|btn_add_doctor_disabled|textLabel:Add Doctors " .. tostring(doctorCount) .. "/" .. tostring(doctorCap) .. ";middle_colour:2526451450;border_colour:2526451450;display:block;state:disabled;|\n"
    end
    if doctorCount > 0 then
        d = d .. "add_spacer|small|\n"
        d = d .. "add_custom_button|" .. BTN_REMOVE_DOCTORS_MAIN .. "|textLabel:Remove Doctors " .. tostring(doctorCount) .. "/" .. tostring(doctorCap) .. ";middle_colour:33854463;border_colour:33854463;display:block;|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|Auto Surgeon Stations in this Hospital can cure (Lv " .. tostring(level) .. ") :|\n"
    d = d .. "add_spacer|small|\n"
    local unlockedMaladies = getUnlockedAutoSurgeonMaladies(level)
    local perRow = 4
    local rowCount = math.max(1, math.floor((#unlockedMaladies + perRow - 1) / perRow))
    local gridBottomPad = 24 + (rowCount * 92)
    d = d .. "add_custom_margin|x:26;y:0|\n"
    for i = 1, #unlockedMaladies do
        local maladyType = unlockedMaladies[i]
        local visual = getMaladyVisualIcon(maladyType)
        local displayName = tostring(MALADY_PREVIEW_LABEL[maladyType] or MaladySystem.MALADY_DISPLAY[maladyType] or maladyType)
        local btnName = "illChoose_" .. tostring(i)

        if type(visual) == "string" and visual ~= "" then
            d = d .. "add_custom_button|" .. btnName .. "|" .. visual .. "image_size:32,32;width:0.05;state:disabled;|\n"
            d = d .. "add_custom_label|" .. displayName .. "|target:" .. btnName .. ";top:1.2;left:0.5;size:tiny;|\n"
        else
            local iconID = getMaladyIconID(maladyType)
            d = d .. "add_label_with_icon|small|" .. displayName .. "|left|" .. tostring(iconID) .. "|\n"
        end

        d = d .. "add_custom_margin|x:66;y:0|\n"
        if (i % 4) == 0 then
            d = d .. "reset_placement_x|\n"
            d = d .. "add_custom_margin|x:26;y:90|\n"
        end
    end
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_margin|x:0;y:" .. tostring(gridBottomPad) .. "|\n"
    d = d .. "add_textbox|`9INFO:``|left|\n"
    d = d .. "add_smalltext|`9- The World Owner's surgeries will automatically count towards the hospital stats without needing to be registered as a doctor.``|left|\n"
    d = d .. "add_smalltext|`9- Rating: every 100 successful cures gives +1 rating. A failed cure gives -1 rating and resets the rating counter.``|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "end_dialog|receptionDeskMainUi|Close||\n"
    d = d .. "add_quick_exit|\n"

    player:onDialogRequest(d, 0)
end

-- =======================================================
-- PANEL: HOSPITAL STATS
-- =======================================================

function ReceptionDesk.showHospitalStatsPanel(world, player)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local worldName = resolveWorldName(world, player)
    local state = getHospitalState(worldName)
    local level = tonumber(state.level) or 1
    local autoSurgeonCount = countAutoSurgeons(world)
    local operatingTableCount = countOperatingTables(world)
    local operatingTableCapacity = getOperatingTableCapacityByLevel(level)
    local operatingDurationSec = getOperatingPatientDurationByLevel(level)
    local operatingDurationMin = math.floor(math.max(0, operatingDurationSec) / 60)
    local doctorCount = ReceptionDesk.countDoctors(worldName)
    local ratingData = getHospitalRatingCounter(worldName) or {}
    ratingData.rating = tonumber(ratingData.rating) or 0
    ratingData.counter = tonumber(ratingData.counter) or 0
    local maxRating = tonumber(MAX_HOSPITAL_RATING) or 5
    local ratingStep = tonumber(RATING_STEP_CURES) or 100
    local treatmentStats = getHospitalTreatmentStats(worldName)
    local curedByMalady = treatmentStats.cured_by_malady

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wHospital Stats|left|4298|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Hospital Level: `9" .. tostring(level) .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|Doctors: `2" .. tostring(doctorCount) .. "/1``|left|14674|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Auto Surgeon Stations: `2" .. tostring(autoSurgeonCount) .. "/1``|left|" .. tostring(AUTO_SURGEON_ID) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Operating Tables: `2" .. tostring(operatingTableCount) .. "/" .. tostring(operatingTableCapacity) .. "``|left|" .. tostring(OPERATING_TABLE_ID) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Surg-Bot patient duration: `2" .. tostring(operatingDurationMin) .. " minutes``|left|14662|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Rating: `2" .. tostring(ratingData.rating) .. "/" .. tostring(maxRating) .. "``|left|" .. tostring(getRequirementIconID(ratingData.rating, maxRating)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Rating Counter: `2" .. tostring(ratingData.counter) .. "/" .. tostring(ratingStep) .. "``|left|" .. tostring(getRequirementIconID(ratingData.counter, ratingStep)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Patients Treated|left|\n"
    d = d .. "add_textbox|Total: `2" .. tostring(treatmentStats.total) .. "``|left|\n"
    d = d .. "add_textbox|Successful Surgeries: `2" .. tostring(treatmentStats.successful) .. "``|left|\n"
    d = d .. "add_textbox|Failed Surgeries: `6" .. tostring(treatmentStats.failed) .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    local hasCuredRows = false
    for i = 1, #HOSPITAL_STATS_MALADY_ROWS do
        local row = HOSPITAL_STATS_MALADY_ROWS[i]
        local count = tonumber(curedByMalady[row.key]) or 0
        if count > 0 then
            hasCuredRows = true
            d = d .. "add_label_with_icon|small|" .. row.label .. ": `2" .. tostring(count) .. "``|left||" .. row.icon .. "|\n"
            d = d .. "add_custom_margin|x:0;y:8|\n"
        end
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|" .. BTN_BACK_STATS .. "|Back|noflags|0|0|\n"
    d = d .. "end_dialog|hospitalStatsUi|||\n"
    d = d .. "add_quick_exit|\n"

    player:onDialogRequest(d, 0)
end

-- =======================================================
-- PANEL: LEVEL UP HOSPITAL
-- =======================================================

function ReceptionDesk.showLevelUpPanel(world, player)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local worldName = resolveWorldName(world, player)
    local state = getHospitalState(worldName)
    local level = tonumber(state.level) or 1
    local levelData = HOSPITAL_LEVELS[level]

    if not levelData or not levelData.next_level then
        safeBubble(player, "`4Hospital is already at max level.")
        return
    end

    local nextLevel = levelData.next_level
    local levelRule = LEVEL_UP_RULES[level] or {}
    local requiredSurgeries = tonumber(levelRule.required_cures) or tonumber(levelData.required_surgeries) or 0
    local upgradeCost = tonumber(levelData.upgrade_wl) or 0
    local playerWL = tonumber(getPlayerItemAmount(player, WORLD_LOCK_ID)) or 0
    local totalWLEquiv = getTotalWLEquivalent(player)
    local snapshot = getLevelUpSnapshot(world, worldName, state, totalWLEquiv)
    local isReady = isLevelUpReadyForRule(levelRule, snapshot, upgradeCost)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wLevel Up Hospital|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Level up hospital to level: `9" .. tostring(nextLevel) .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    local perks = levelRule.perks or {}
    if #perks > 0 then
        for i = 1, #perks do
            d = d .. "add_label_with_icon|small|" .. perks[i] .. "|left|" .. tostring(OPERATING_TABLE_ID) .. "|\n"
            d = d .. "add_custom_margin|x:0;y:8|\n"
        end
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Rewards:|left|\n"
    local rewards = levelRule.rewards or {}
    if #rewards == 0 then
        d = d .. "add_label_with_icon|small|None|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
        d = d .. "add_custom_margin|x:0;y:8|\n"
    else
        for i = 1, #rewards do
            local reward = rewards[i]
            d = d .. "add_label_with_icon|small|" .. tostring(reward.label) .. "|left|" .. tostring(reward.icon or RECEPTION_DESK_ID) .. "|\n"
            d = d .. "add_custom_margin|x:0;y:8|\n"
        end
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Requirements:|left|\n"
    d = d .. "add_label_with_icon|small|Cured Patients: " .. formatTierProgress(snapshot.cures, requiredSurgeries) .. "|left|" .. tostring(getRequirementIconID(snapshot.cures, requiredSurgeries)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Doctors: " .. formatTierProgress(snapshot.doctors, tonumber(levelRule.required_doctors) or 0) .. "|left|" .. tostring(getRequirementIconID(snapshot.doctors, tonumber(levelRule.required_doctors) or 0)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Rating: " .. formatTierProgress(snapshot.rating, tonumber(levelRule.required_rating) or 0) .. "|left|" .. tostring(getRequirementIconID(snapshot.rating, tonumber(levelRule.required_rating) or 0)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"

    if (tonumber(levelRule.required_auto_surgeons) or 0) > 0 then
        d = d .. "add_label_with_icon|small|Auto Surgeon Stations: " .. formatTierProgress(snapshot.autoSurgeons, levelRule.required_auto_surgeons) .. "|left|" .. tostring(getRequirementIconID(snapshot.autoSurgeons, levelRule.required_auto_surgeons)) .. "|\n"
        d = d .. "add_custom_margin|x:0;y:8|\n"
    end
    if (tonumber(levelRule.required_operating_tables) or 0) > 0 then
        d = d .. "add_label_with_icon|small|Operating Tables: " .. formatTierProgress(snapshot.operatingTables, levelRule.required_operating_tables) .. "|left|" .. tostring(getRequirementIconID(snapshot.operatingTables, levelRule.required_operating_tables)) .. "|\n"
        d = d .. "add_custom_margin|x:0;y:8|\n"
    end

    local requiredMaladies = levelRule.required_maladies or {}
    for i = 1, #requiredMaladies do
        local req = requiredMaladies[i]
        local curedCount = tonumber(snapshot.curedByMalady[req.key]) or 0
        d = d .. "add_label_with_icon|small|" .. tostring(req.label) .. ": " .. formatTierProgress(curedCount, req.count) .. "|left|" .. tostring(getRequirementIconID(curedCount, req.count)) .. "|\n"
        d = d .. "add_custom_margin|x:0;y:8|\n"
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|Cost: `9" .. tostring(upgradeCost) .. "``|left|242|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|Owned World Locks: " .. getTierColor(totalWLEquiv, upgradeCost) .. tostring(totalWLEquiv) .. "``|left|242|\n"
    d = d .. "add_spacer|small|\n"

    if not isReady then
        d = d .. "add_textbox|`6You don't meet the requirements.|left|\n"
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "add_custom_button|" .. BTN_LEVEL_UP_BACK .. "|textLabel:Back;middle_colour:3434645503;border_colour:3434645503;|\n"
    d = d .. "add_custom_button|" .. BTN_LEVEL_UP_NEW_CONFIRM .. "|textLabel:Level Up Hospital;middle_colour:" .. (isReady and "1744830463" or "2526451450") .. ";border_colour:" .. (isReady and "1744830463" or "2526451450") .. ";anchor:" .. BTN_LEVEL_UP_BACK .. ";left:1;margin:40,0;state:" .. (isReady and "normal" or "disabled") .. ";|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "end_dialog|hospitalLevelUpUi|||\n"
    d = d .. "add_quick_exit|\n"

    player:onDialogRequest(d, 0)
end

-- =======================================================
-- PANEL: MANAGE DOCTORS
-- =======================================================

function ReceptionDesk.showManageDoctorsPanel(world, player, worldName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local state   = getHospitalState(worldName)
    local doctors = state.doctors or {}

    local d = "set_default_color|`o\n"
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
    d = d .. "add_button|" .. BTN_DOCTORS_BACK .. "|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. DLG_MANAGE_DOCTORS .. "|||\n"

    player:onDialogRequest(d, 0)
end

-- =======================================================
-- PANEL: DOCTOR RECEPTION (Leaderboard)
-- =======================================================

function ReceptionDesk.showDoctorReceptionPanel(world, player, worldName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlgName = "hosp_doctor_panel_v5m"
    local uid = getUserID(player)
    local leaderboard = ReceptionDesk.getDoctorLeaderboard(worldName)

    local d = "set_default_color|`o\n"
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

    player:onDialogRequest(d, 0)
end

_G.ReceptionDesk = ReceptionDesk
return ReceptionDesk
