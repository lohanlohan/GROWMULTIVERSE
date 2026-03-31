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
    local color = {
        STRONG         = "`2", GOOD           = "`2",
        STEADY         = "`3", WEAK           = "`6",
        VERY_WEAK      = "`6", EXTREMELY_WEAK = "`4", NONE = "`4",
    }
    local text = {
        STRONG         = "Strong",        GOOD           = "Good",
        STEADY         = "Steady",        WEAK           = "Weak",
        VERY_WEAK      = "Very Weak",     EXTREMELY_WEAK = "Extremely Weak",
        NONE           = "NONE",
    }
    return (color[pulse] or "`4") .. (text[pulse] or (pulse or "?"))
end

local function tempLabel(temp)
    local s = string.format("%.1f", temp)
    if temp < 100.0 then return "`2" .. s end
    if temp < 103.0 then return "`3" .. s end
    if temp < 106.0 then return "`6" .. s end
    return "`4" .. s
end

local function cleanLabel(clean)
    return ({
        CLEAN          = "`2Clean",
        SLIGHTLY_DIRTY = "`6Unclean",
        DIRTY          = "`3Not Sanitized",
        UNSANITARY     = "`4Unsanitary",
    })[clean] or ("`4" .. (clean or "?"))
end

local function visRow(vis)
    if vis == "SLIGHTLY_HARD" then
        return "`6It is becoming hard to see your work."
    elseif vis == "HARD" or vis == "IMPOSSIBLE" then
        return "`4You can't see what you are doing!"
    end
    return nil
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
    local c = st.consciousness
    if c == "UNCONSCIOUS" then
        return "`2Unconscious `o(" .. st.anesthTurns .. " moves)"
    elseif c == "COMING_TO" then
        return "`4Coming To! `o(" .. st.anesthTurns .. " moves)"
    elseif c == "NEAR_COMA" then
        return "`4Near Coma!"
    end
    if st.heartStopped then
        return "`4Heart `4stopped!"
    end
    return "`3Awake"
end

-- =======================================================
-- MESSAGES
-- =======================================================

-- Bleeding row: between incisions and spacer
local function bleedingRow(bleeding)
    if bleeding == "INTENSE"  then return "`4Patient is losing blood intensely!" end
    if bleeding == "RAPID"    then return "`4Patient is losing blood rapidly!" end
    if bleeding == "MODERATE" then return "Patient is `6losing `6blood!" end
    if bleeding == "SLIGHT"   then return "Patient is losing blood `3slow`3ly." end
    return nil
end

-- Fever row: shown BEFORE spacer (same position as bleeding)
local function feverRow(st)
    if st.temperature < 100.0 then return nil end
    local diag = SD.DIAG[st.diagKey] or {}
    if st.tempRising and diag.tempRiseFast then
        return "Patient's fever is `4climbing `4fast!"
    elseif st.temperature >= 106.0 and st.tempRising then
        return "Patient's fever is `4climbing `4fast!"
    elseif st.temperature >= 101.0 and st.tempRising then
        return "Patient's fever is `6clim`6bing!"
    else
        return "Patient's fever is `3slowly `3rising."
    end
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
    d = d .. "add_label_with_icon|big|`wSurg-E|left|" .. INSURGERY_ITEM_ID .. "|\n"

    -- Modifiers (right after header, `9 color)
    if st.modifierList and #st.modifierList > 0 then
        local parts = {}
        for _, key in ipairs(st.modifierList) do
            local mod = SD.MODIFIER[key]
            if mod then parts[#parts+1] = "`9" .. mod.label end
        end
        if #parts > 0 then
            d = d .. "add_smalltext|" .. table.concat(parts, " `w| ") .. "|\n"
        end
    end

    -- Story headline (changes per milestone)
    d = d .. "add_smalltext|" .. (st.storyHeadline or "`4The patient has not been diagnosed.") .. "|\n"

    -- ── Status block ────────────────────────────────────────────────────────
    d = d .. "add_smalltext|`$Pulse: "        .. pulseLabel(st.pulse)
          .. "    `$Status: "                   .. consLabel(st) .. "|\n"
    d = d .. "add_smalltext|`$Temp: "          .. tempLabel(st.temperature)
          .. "    `$Operation site: "           .. cleanLabel(st.siteClean) .. "|\n"

    local vr = visRow(st.visibility)
    if vr then
        d = d .. "add_smalltext|" .. vr .. "|\n"
    end

    local incColor = st.incisions == 0 and "`2" or "`3"
    local incRow = "add_smalltext|`$Incisions: " .. incColor .. st.incisions .. "``"

    local hasBones = st.brokenBones > 0 or st.shatteredBones > 0
    if hasBones and st.bonesRevealed then
        local boneStr
        if st.brokenBones > 0 and st.shatteredBones > 0 then
            boneStr = "`6" .. st.brokenBones .. " broken``, `6" .. st.shatteredBones .. " shattered"
        elseif st.brokenBones > 0 then
            boneStr = "`6" .. st.brokenBones .. " broken"
        elseif st.shatteredBones > 0 then
            boneStr = "`6" .. st.shatteredBones .. " shattered"
        else
            boneStr = "`2OK"
        end
        d = d .. incRow .. "    `$Bones: " .. boneStr .. "|\n"
    else
        d = d .. incRow .. "|\n"
    end

    -- Bleeding + fever rows (between incisions and spacer)
    local br = bleedingRow(st.bleeding)
    if br then d = d .. "add_smalltext|" .. br .. "|\n" end
    local fr = feverRow(st)
    if fr then d = d .. "add_smalltext|" .. fr .. "|\n" end

    -- After spacer: lastMsg, contextMsg, or default "prepped" if nothing
    d = d .. "add_spacer|small|\n"
    local hasMsg = false
    if st.lastMsg and st.lastMsg ~= "" then
        d = d .. "add_smalltext|`3" .. st.lastMsg .. "|\n"
        hasMsg = true
    end
    if st.contextMsg and st.contextMsg ~= "" then
        d = d .. "add_smalltext|`3" .. st.contextMsg .. "|\n"
        hasMsg = true
    end
    if not hasMsg then
        d = d .. "add_smalltext|Patient is prepped for surgery.|\n"
    end
    -- Heart stopped: extra spacer + warning (shown after lastMsg/contextMsg)
    if st.heartStopped then
        d = d .. "add_spacer|small|\n"
        d = d .. "add_smalltext|`4The patient's `4heart `4has stopped!|\n"
    end

    -- ── Tool grid (sequential, client auto-wrap) ─────────────────────────────
    local toolOrder = {
        T.DEFIBRILLATOR, T.SPONGE, T.ANESTHETIC, T.STITCHES, T.SCALPEL, T.ULTRASOUND,
        T.ANTISEPTIC, T.FIX_IT, T.LAB_KIT, T.ANTIBIOTICS, T.TRANSFUSION, T.SPLINT,
        T.PINS, T.CLAMP,
    }

    local invMap = buildInvMap(player)

    d = d .. "text_scaling_string|Defibrillator|\n"
    for _, toolId in ipairs(toolOrder) do
        local count = invMap[toolId] or 0
        if SE.isToolAvailable(session, toolId) then
            local label = SD.TOOL_LABEL[toolId] or ("Item " .. toolId)
            d = d .. "add_button_with_icon|btn_t_" .. toolId
                  .. "|`$" .. label .. "|noflags|" .. toolId .. "|" .. count .. "|\n"
        else
            d = d .. "add_button_with_icon|btn_na_" .. toolId
                  .. "||noflags|" .. EMPTY_TRAY_ITEM_ID .. "|\n"
        end
    end
    -- Slot 15: permanent empty (row 3 slot 3)
    d = d .. "add_button_with_icon|btn_na_extra||noflags|" .. EMPTY_TRAY_ITEM_ID .. "|\n"
    d = d .. "add_button_with_icon||END_LIST|noflags|0||\n"

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_giveup|`4Give Up!|noflags|0|0|\n"
    d = d .. "end_dialog|" .. dlgName .. "|||\n"

    return d
end

-- =======================================================
-- BUILD GIVE UP CONFIRMATION PANEL
-- =======================================================

function M.buildGiveUpConfirm(tileX, tileY)
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,200|\n"
    d = d .. "add_label_with_icon|big|`4Give Up Surgery?|left|" .. INSURGERY_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`wAre you sure you want to give up? The patient will not be saved.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_confirm_giveup|`4Yes, Give Up|noflags|0|0|\n"
    d = d .. "add_button|btn_cancel_giveup|`2No, Continue Surgery|noflags|0|0|\n"
    d = d .. "end_dialog|surg_giveup_" .. tileX .. "_" .. tileY .. "|||\n"
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
        d = d .. "add_smalltext|`oSurgeon Skill: " .. (surgeonSkill or 0) .. " `w→ `2" .. (newSkill or 0) .. "|\n"
        d = d .. "add_smalltext|`oYou received: `21x Caduceus `o+ a random prize.|\n"
    else
        d = d .. "add_label_with_icon|big|`4Surgery Failed!|left|" .. INSURGERY_ITEM_ID .. "|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`4" .. (failReason or "The surgery failed.") .. "|\n"
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
