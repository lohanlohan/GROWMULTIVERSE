-- MODULE
-- surgery_ui.lua — Build the surgery minigame dialog panel from session state

local M  = {}
local SD = _G.SurgeryData
local SE = _G.SurgeryEngine

local INSURGERY_ITEM_ID  = 25028  -- icon shown in dialog title
local EMPTY_TRAY_ITEM_ID = 4320   -- shown for unavailable/missing tool slots

-- =======================================================
-- STATUS LABEL HELPERS
-- =======================================================

local function pulseLabel(pulse)
    local color = { STRONG = "`2", STEADY = "`o", WEAK = "`4", EXTREMELY_WEAK = "`4", NONE = "`4" }
    local text  = { STRONG = "Strong", STEADY = "Steady", WEAK = "Weak", EXTREMELY_WEAK = "Extremely Weak", NONE = "NONE" }
    return (color[pulse] or "`4") .. (text[pulse] or (pulse or "?"))
end

local function tempLabel(temp)
    local s = string.format("%.1f", temp) .. "°F"
    if temp <= 98.6  then return "`2" .. s end
    if temp <= 100.4 then return "`o" .. s end
    return "`4" .. s
end

local function siteLabel(clean, vis)
    local cleanStr = ({
        CLEAN          = "`2Clean",
        SLIGHTLY_DIRTY = "`oUnclean",
        DIRTY          = "`4Dirty",
        UNSANITARY     = "`4Unsanitary",
    })[clean] or ("`4" .. (clean or "?"))
    local visStr = ({
        CLEAR         = "",
        SLIGHTLY_HARD = " (`oHard`w)",
        HARD          = " (`4Hard`w)",
        IMPOSSIBLE    = " (`4Impossible`w)",
    })[vis] or ""
    return cleanStr .. visStr
end

local function bleedLabel(bleeding)
    return ({
        NONE     = "`2None",
        SLIGHT   = "`oSlight",
        MODERATE = "`4Moderate",
        RAPID    = "`4Rapid",
        INTENSE  = "`4INTENSE",
    })[bleeding] or ("`4" .. (bleeding or "?"))
end

local function consLabel(st)
    if st.consciousness == "UNCONSCIOUS" then
        if st.anesthTurns > 0 then
            local c = st.anesthTurns <= 3 and "`4" or "`2"
            return "`2Unconscious " .. c .. "(" .. st.anesthTurns .. " moves)"
        end
        return "`2Unconscious"
    end
    return "`4Awake"
end

-- =======================================================
-- MESSAGES — two groups: urgent (before status) and info (after status)
-- =======================================================

-- Urgent: warnings that need immediate attention, shown BEFORE status block
local function buildUrgentMessages(st)
    local diag = SD.DIAG[st.diagKey] or {}
    local msgs = {}

    if st.siteClean == "UNSANITARY" then
        msgs[#msgs+1] = "`4The patient is absolutely filthy."
    elseif st.siteClean == "DIRTY" then
        msgs[#msgs+1] = "`4The patient is filthy."
    elseif st.siteClean == "SLIGHTLY_DIRTY" then
        msgs[#msgs+1] = "`oThe operation site is unclean."
    end

    if diag.needsLabKit and not st.labKitUsed then
        msgs[#msgs+1] = "`4The patient has not been diagnosed."
    end

    if st.heartStopped then
        msgs[#msgs+1] = "`4HEART STOPPED! Use Defibrillator immediately!"
    end

    if st.consciousness == "AWAKE" and st.incisions > 0 then
        msgs[#msgs+1] = "`4Patient is awake with open incisions!"
    end

    if st.consciousness == "UNCONSCIOUS" and st.anesthTurns > 0 and st.anesthTurns <= 3 then
        msgs[#msgs+1] = "`4Patient waking up in " .. st.anesthTurns .. " move(s)!"
    end

    return msgs
end

-- Info: shown AFTER the status block (below incisions, like real GT)
local function buildInfoMessages(st)
    local msgs = {}

    if st.temperature >= 105.0 then
        msgs[#msgs+1] = "`4Patient's fever is dangerously high!"
    elseif st.tempRising and st.temperature > 98.6 then
        msgs[#msgs+1] = "`oPatient's fever is climbing rapidly!"
    end

    if st.bleeding == "INTENSE" then
        msgs[#msgs+1] = "`4CRITICAL: Patient is bleeding intensely!"
    elseif st.bleeding == "RAPID" then
        msgs[#msgs+1] = "`4Patient is bleeding rapidly!"
    elseif st.bleeding == "MODERATE" then
        msgs[#msgs+1] = "`oThe patient is bleeding."
    end

    if #msgs == 0 then
        msgs[#msgs+1] = "`wThe patient is prepped for surgery."
    end

    return msgs
end

-- =======================================================
-- INVENTORY MAP
-- =======================================================

local function buildInvMap(player)
    local map = {}
    for _, item in pairs(player:getInventoryItems()) do
        map[item:getItemID()] = item:getItemCount() or 0
    end
    return map
end

-- =======================================================
-- BUILD PANEL
-- =======================================================

function M.buildPanel(player, session, surgeonSkill)
    local st   = session
    local diag = SD.DIAG[st.diagKey] or {}
    local T    = SD.TOOL

    local dlgName = "surg_play_" .. st.tileX .. "_" .. st.tileY

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,200|\n"
    d = d .. "add_label_with_icon|big|`wSurg-E: " .. (diag.name or "?") .. "|left|" .. INSURGERY_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"

    -- Last action message
    if st.lastMsg and st.lastMsg ~= "" then
        local msg = st.lastMsg
        local c = "`o"
        if msg:find("CRITICAL") or msg:find("stopped") or msg:find("artery") or msg:find("REVOKED") then c = "`4"
        elseif msg:find("complete") or msg:find("normal") or msg:find("restarted") or msg:find("cured") then c = "`2"
        end
        d = d .. "add_textbox|" .. c .. msg .. "|\n"
        d = d .. "add_spacer|small|\n"
    end

    -- Urgent messages (before status block)
    for _, msg in ipairs(buildUrgentMessages(st)) do
        d = d .. "add_smalltext|" .. msg .. "|\n"
    end

    -- ── Status block ────────────────────────────────────────────────────────
    d = d .. "add_smalltext|`wPulse: "       .. pulseLabel(st.pulse)
          .. "    `wStatus: "                  .. consLabel(st) .. "|\n"
    d = d .. "add_smalltext|`wTemp: "         .. tempLabel(st.temperature)
          .. "    `wOperation site: "          .. siteLabel(st.siteClean, st.visibility) .. "|\n"

    local incColor = st.incisions > 0 and "`4" or "`2"
    d = d .. "add_smalltext|`wIncisions: "    .. incColor .. st.incisions
          .. "    `wBleeding: "                .. bleedLabel(st.bleeding) .. "|\n"

    if diag.needsUltrasound or (diag.brokenBones and diag.brokenBones > 0)
    or st.brokenBones > 0 or st.shatteredBones > 0 then
        local boneStr
        if not st.bonesRevealed then
            boneStr = "`o?? (use Ultrasound)"
        elseif st.brokenBones > 0 or st.shatteredBones > 0 then
            boneStr = "`4Broken: " .. st.brokenBones .. "  Shattered: " .. st.shatteredBones
        else
            boneStr = "`2OK"
        end
        d = d .. "add_smalltext|`wBones: " .. boneStr .. "|\n"
    end

    -- Info messages (after incisions, like real GT)
    d = d .. "add_spacer|small|\n"
    for _, msg in ipairs(buildInfoMessages(st)) do
        d = d .. "add_smalltext|" .. msg .. "|\n"
    end
    d = d .. "add_spacer|small|\n"

    -- ── Tool grid ────────────────────────────────────────────────────────────
    -- Row 1 (6): Defibrillator, Sponge, Anesthetic, Stitches, Scalpel, Ultrasound
    -- Row 2 (6): Antiseptic, Fix It, Lab Kit, Antibiotics, Transfusion, Splint
    -- Row 3 (3): Pins, Clamp, [permanent empty tray]
    local toolOrder = {
        T.DEFIBRILLATOR, T.SPONGE, T.ANESTHETIC, T.STITCHES, T.SCALPEL, T.ULTRASOUND,
        T.ANTISEPTIC, T.FIX_IT, T.LAB_KIT, T.ANTIBIOTICS, T.TRANSFUSION, T.SPLINT,
        T.PINS, T.CLAMP,
    }

    local invMap = buildInvMap(player)

    for i, toolId in ipairs(toolOrder) do
        if i == 7  then d = d .. "add_custom_break|\n" d = d .. "add_spacer|small|\n" end
        if i == 13 then d = d .. "add_custom_break|\n" d = d .. "add_spacer|small|\n" end
        local count = invMap[toolId] or 0
        if SE.isToolAvailable(session, toolId) then
            local label = SD.TOOL_LABEL[toolId] or ("Item " .. toolId)
            d = d .. "add_button_with_icon|btn_t_" .. toolId
                  .. "|`w" .. label .. "|is_count_label,noflags|" .. toolId .. "|" .. count .. "|left|\n"
        else
            -- Locked: empty tray, icon only (no count badge)
            d = d .. "add_button_with_icon|btn_na_" .. toolId
                  .. "||noflags|" .. EMPTY_TRAY_ITEM_ID .. "|\n"
        end
    end
    -- Slot 15: permanent empty tray (row 3 slot 3)
    d = d .. "add_button_with_icon|btn_na_extra||noflags|" .. EMPTY_TRAY_ITEM_ID .. "|\n"

    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_giveup|`4Give Up!|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    return d
end

-- =======================================================
-- BUILD RESULT PANEL (success or fail)
-- =======================================================

function M.buildResultPanel(success, failReason, diagName, surgeonSkill, newSkill, tileX, tileY)
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,200|\n"

    if success then
        d = d .. "add_label_with_icon|big|`2Surgery Successful!|left|" .. INSURGERY_ITEM_ID .. "|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`wOperation complete! The " .. (diagName or "patient") .. " is cured.|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_smalltext|`wSurgeon Skill: `o" .. (surgeonSkill or 0) .. " `w→ `2" .. (newSkill or 0) .. "|\n"
        d = d .. "add_smalltext|`oYou received: `21x Caduceus `o+ a random prize.|\n"
    else
        d = d .. "add_label_with_icon|big|`4Surgery Failed!|left|" .. INSURGERY_ITEM_ID .. "|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`4" .. (failReason or "The surgery failed.") .. "|\n"
        d = d .. "add_textbox|`oYOUR MEDICAL LICENSE IS REVOKED!|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`wNo rewards. Better luck next time.|\n"
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_close|`wClose|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|surg_result_" .. tileX .. "_" .. tileY .. "|||\n"
    return d
end

return M
