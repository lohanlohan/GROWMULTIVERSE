-- MODULE: ReceptionDesk Subsystem for Hospital
-- Handles panels: Reception Desk, Manage Doctors, Doctor Panel
-- Requires: hospital.lua (parent) untuk shared functions & constants

local ReceptionDesk = {}

local function getTierColor(current, required)
    local c = math.max(0, math.floor(tonumber(current) or 0))
    local r = math.max(0, math.floor(tonumber(required) or 0))
    if r <= 0 then return "`2" end
    if c >= r then return "`2" end

    local ratio = c / r
    if ratio <= 0 then return "`4" end
    if ratio < 0.25 then return "`6" end
    if ratio < 0.5 then return "`9" end
    return "`^"
end

local function formatTierProgress(current, required)
    local c = math.max(0, math.floor(tonumber(current) or 0))
    local r = math.max(0, math.floor(tonumber(required) or 0))
    return getTierColor(c, r) .. tostring(c) .. "/" .. tostring(r) .. "``"
end

local function resolveWorldName(world, player)
    local globalResolver = rawget(_G, "getWorldName")
    if type(globalResolver) == "function" then
        return tostring(globalResolver(world, player) or "")
    end
    if type(player) == "userdata" and player.getWorldName then
        return tostring(player:getWorldName() or "")
    end
    if type(world) == "userdata" and world.getName then
        return tostring(world:getName() or "")
    end
    return ""
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
    local ratingData = getHospitalRatingCounter(worldName)
    local playerName = tostring(player.getName and player:getName() or "Player")
    local doctorCount = ReceptionDesk.countDoctors(worldName)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wReception Desk|left|" .. tostring(RECEPTION_DESK_ID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Hello there, " .. playerName .. "`o. Welcome to `2" .. worldName .. "`o Hospital.|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Level: " .. getTierColor(level, 3) .. tostring(level) .. "``|left|\n"
    d = d .. "add_textbox|Rating: " .. formatTierProgress(ratingData.rating, MAX_HOSPITAL_RATING) .. "|left|\n"
    if ratingData.rating >= MAX_HOSPITAL_RATING then
        d = d .. "add_textbox|Rating Counter: `2MAX``|left|\n"
    else
        d = d .. "add_textbox|Rating Counter: " .. formatTierProgress(ratingData.counter, RATING_STEP_CURES) .. " `o(" .. tostring(ratingData.need) .. " to next)``|left|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_SHOW_STATS .. "|textLabel:Hospital Stats;middle_colour:3389566975;border_colour:3389566975;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|" .. BTN_LEVEL_UP .. "|textLabel:Level Up Hospital;middle_colour:431888895;border_colour:431888895;display:block;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_player_picker|playerNetID|`wAdd Doctors " .. tostring(doctorCount) .. "/1``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Auto Surgeon Stations in this Hospital can cure:|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_margin|x:32;y:0|\n"
    d = d .. "add_custom_button|illChoose_20|image:game/tiles_page16.rttex;image_size:32,32;width:0.08;frame:8,22;state:disabled;|\n"
    d = d .. "add_custom_label|Torn Muscle|target:illChoose_20;top:1.2;left:0.5;size:tiny;|\n"
    d = d .. "add_custom_margin|x:64;y:0|\n"
    d = d .. "add_custom_button|illChoose_21|image:game/tiles_page16.rttex;image_size:32,32;width:0.08;frame:22,26;state:disabled;|\n"
    d = d .. "add_custom_label|Gem Cuts|target:illChoose_21;top:1.2;left:0.5;size:tiny;|\n"
    d = d .. "add_custom_margin|x:64;y:0|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_margin|x:0;y:125|\n"
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
    local doctorCount = ReceptionDesk.countDoctors(worldName)
    local ratingData = getHospitalRatingCounter(worldName)
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
    d = d .. "add_label_with_icon|small|Operating Tables: `2" .. tostring(operatingTableCount) .. "/1``|left|" .. tostring(OPERATING_TABLE_ID) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Rating: `2" .. tostring(ratingData.rating) .. "/" .. tostring(MAX_HOSPITAL_RATING) .. "``|left|" .. tostring(getRequirementIconID(ratingData.rating, MAX_HOSPITAL_RATING)) .. "|\n"
    d = d .. "add_custom_margin|x:0;y:8|\n"
    d = d .. "add_label_with_icon|small|Rating Counter: `2" .. tostring(ratingData.counter) .. "/" .. tostring(RATING_STEP_CURES) .. "``|left|" .. tostring(getRequirementIconID(ratingData.counter, RATING_STEP_CURES)) .. "|\n"
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
    if not hasCuredRows then
        -- d = d .. "add_smalltext|`7No cured malady record yet.|\n"
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
    local upgradeCost = levelData.upgrade_wl
    local playerWL = tonumber(getPlayerItemAmount(player, WORLD_LOCK_ID)) or 0
    local snapshot = getLevelUpSnapshot(world, worldName, state, playerWL)
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
    d = d .. "add_label_with_icon|small|Owned World Locks: " .. getTierColor(playerWL, upgradeCost) .. tostring(playerWL) .. "``|left|242|\n"
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

    player:onDialogRequest(d, 0)
end

return ReceptionDesk
