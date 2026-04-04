-- MODULE
-- surgery_engine.lua — Surgery session management and game logic

local M  = {}
local SD = _G.SurgeryData

-- =======================================================
-- IN-MEMORY SESSION STORE
-- _G.__SURGERY_SESSIONS[worldName][tileKey] = session
-- =======================================================

local function store()
    if not _G.__SURGERY_SESSIONS then _G.__SURGERY_SESSIONS = {} end
    return _G.__SURGERY_SESSIONS
end

local function tileKey(x, y)
    return tostring(math.floor(tonumber(x) or 0)) .. ":" .. tostring(math.floor(tonumber(y) or 0))
end

function M.getSession(worldName, x, y)
    local s = store()
    local ws = s[worldName]
    if not ws then return nil end
    return ws[tileKey(x, y)]
end

function M.setSession(worldName, x, y, session)
    local s = store()
    if not s[worldName] then s[worldName] = {} end
    s[worldName][tileKey(x, y)] = session
end

function M.clearSession(worldName, x, y)
    local s = store()
    if s[worldName] then s[worldName][tileKey(x, y)] = nil end
end

-- =======================================================
-- NEW SESSION  (called when surgery starts)
-- =======================================================

function M.newSession(diagKey, surgeon, tileX, tileY, cfg)
    local diag = SD.DIAG[diagKey]
    if not diag then return nil end

    -- Roll modifiers
    local mods     = SD.rollModifiers()
    local modMap   = {}
    for _, k in ipairs(mods) do modMap[k] = true end

    -- TOUGH_SKIN adds 1 required scalpel
    local reqScalpels = (diag.requiredScalpels or 0) + (modMap.TOUGH_SKIN and 1 or 0)

    return {
        -- Identity
        diagKey        = diagKey,
        surgeonName    = surgeon:getName(),
        surgeonUID     = surgeon:getUserID(),
        tileX          = tileX,
        tileY          = tileY,
        cfg            = cfg,   -- { prizePool, caduceusId, onEnd }

        -- Vital signs
        temperature    = diag.initialTemp,
        tempRising     = diag.tempRising,
        pulse          = diag.initialPulse,
        heartStopped   = false,
        heartStopTurns = 0,

        -- Consciousness (AWAKE / UNCONSCIOUS / COMING_TO)
        -- Derived from anesthTurns each turn; anesthTurns = 0 means AWAKE
        consciousness  = "AWAKE",
        anesthTurns    = 0,

        -- Surgical site
        incisions      = 0,
        scalpelCount   = 0,
        bleeding       = diag.initialBleeding,
        siteClean      = modMap.FILTHY and "SLIGHTLY_DIRTY" or (diag.initialSiteClean or "CLEAN"),
        visibility     = diag.initialVisibility or "CLEAR",

        -- Bones
        brokenBones    = diag.brokenBones,
        shatteredBones = diag.shatteredBones,

        -- Diagnosis tracking
        labKitUsed     = false,
        ultrasoundUsed = false,
        requiredScalpels = reqScalpels,
        fixItReady     = (reqScalpels == 0 and not diag.needsFixIt),
        fixItDone      = not diag.needsFixIt,  -- pre-done if not needed
        abxUnlocked    = false,  -- always locked until Lab Kit is used
        bonesRevealed  = not diag.needsUltrasound,
        diagRevealed   = (not diag.needsUltrasound and not diag.needsLabKit and diag.headline ~= nil),

        -- Story headline + persistent context message
        -- Diagnoses that need neither Lab Kit nor Ultrasound reveal the headline immediately
        storyHeadline  = (not diag.needsUltrasound and not diag.needsLabKit and diag.headline)
                         and diag.headline or "`4The patient has not been diagnosed.",
        contextMsg     = "",

        -- Modifiers (map for quick lookup + array for display)
        modifiers      = modMap,
        modifierList   = mods,

        -- Last action message (shown in UI)
        lastMsg        = "",
        failReason     = nil,
        moveCount      = 0,

        -- Antibiotics passive effect counter
        abxTurnsLeft    = 0,
        abxImmuneTurns  = 0,  -- prevents dirty site from re-triggering fever after antibiotics
    }
end

-- =======================================================
-- TOOL AVAILABILITY CHECK
-- Returns true if the given tool can be used in this state
-- =======================================================

function M.isToolAvailable(session, toolId)
    local T  = SD.TOOL
    local st = session

    -- Defibrillator: ONLY when heart has stopped
    if toolId == T.DEFIBRILLATOR then
        return st.heartStopped
    end

    -- Sponge: always available (even when IMPOSSIBLE)
    if toolId == T.SPONGE then return true end

    -- All other tools blocked when visibility is IMPOSSIBLE
    if st.visibility == "IMPOSSIBLE" then return false end

    -- Always available (except IMPOSSIBLE)
    if toolId == T.ANESTHETIC  then return true end
    if toolId == T.STITCHES    then return true end
    if toolId == T.SCALPEL     then return true end  -- using on awake patient = instant fail (callbacks)
    if toolId == T.ANTISEPTIC  then return true end
    if toolId == T.TRANSFUSION then return true end

    local diag = SD.DIAG[st.diagKey]

    -- Ultrasound: only shown for diagnoses that require it, single-use
    if toolId == T.ULTRASOUND then
        if not diag.needsUltrasound then return false end
        return not st.ultrasoundUsed
    end

    -- Lab Kit: always available (single-use) for all diagnoses
    if toolId == T.LAB_KIT then return not st.labKitUsed end

    -- Antibiotics: always locked until Lab Kit is used first
    if toolId == T.ANTIBIOTICS then return st.abxUnlocked end

    -- Fix It: objective must be reached; also requires ultrasound first if diagnosis needs it
    if toolId == T.FIX_IT then
        if diag.needsUltrasound and not st.ultrasoundUsed then return false end
        return st.fixItReady and not st.fixItDone
    end

    -- Bone tools: Splint available whenever bones exist (GT shows Splint before ultrasound for trauma)
    if toolId == T.SPLINT then return st.brokenBones > 0 end
    if toolId == T.PINS   then return st.incisions > 0 and st.shatteredBones > 0 end
    if toolId == T.CLAMP  then return st.incisions > 0 end

    return true
end

-- =======================================================
-- APPLY TOOL EFFECT (success)
-- Returns message string
-- =======================================================

function M.applyToolEffect(session, toolId)
    local T  = SD.TOOL
    local st = session
    local diag = SD.DIAG[st.diagKey]

    if toolId == T.SPONGE then
        st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, -2)
        return "You mopped up the operating site."

    elseif toolId == T.LAB_KIT then
        st.labKitUsed  = true
        st.abxUnlocked = true
        if not diag.needsUltrasound and diag.headline then
            st.diagRevealed  = true
            st.storyHeadline = diag.headline
            return "You performed lab work on the patient, and discovered they are suffering from "
                   .. string.lower(diag.name or "unknown") .. "!"
        end
        return "You performed lab work on the patient, and have antibiotics at the ready."

    elseif toolId == T.ANTIBIOTICS then
        local drop
        if st.modifiers and st.modifiers.ANTIBIOTIC_RESISTANT then
            drop = 0.3 + math.random(0, 3) * 0.1
        else
            drop = 2 + math.random(0, 2)
        end
        st.temperature     = math.max(98.6, st.temperature - drop)
        st.tempRising      = false
        st.abxTurnsLeft    = 2
        st.abxImmuneTurns  = 6  -- 6-turn window: fever can't re-trigger from dirty site
        return "You used antibiotics to reduce the patient's infection."

    elseif toolId == T.ANTISEPTIC then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, -2)
        return "You applied antiseptic to the area."

    elseif toolId == T.ANESTHETIC then
        if st.consciousness == "UNCONSCIOUS" then
            return "<<PERMA_DEATH>>"
        end
        local turns = (st.modifiers and st.modifiers.HYPERACTIVE) and 8 or 15
        st.consciousness = "UNCONSCIOUS"
        st.anesthTurns   = turns
        return "The patient falls into a deep sleep."

    elseif toolId == T.SCALPEL then
        st.incisions    = st.incisions + 1
        st.scalpelCount = st.scalpelCount + 1
        -- Successful scalpel = neat incision, does NOT increase bleeding (confirmed GT debug)
        -- Only skill fail scalpel increases bleeding (+2 in applySkillFailEffect)
        if diag.needsFixIt and st.scalpelCount >= st.requiredScalpels then
            st.fixItReady = true
            if diag.scalpelHeadline then
                st.storyHeadline = diag.scalpelHeadline
            end
            if diag.scalpelContextMsg then
                st.contextMsg = diag.scalpelContextMsg
            end
        end
        return "You've made a neat incision."

    elseif toolId == T.FIX_IT then
        local failChance = 0.30 - (tonumber(session.surgeonSkillSnapshot) or 0) * 0.002
        failChance = math.max(0.05, failChance)
        if math.random() < failChance then
            local pct = math.floor(failChance * 100 + 0.5)
            return "<<RETRY>>`3[`4Fix It Fail (" .. pct .. "%)`3] `6You screwed it up! Try again."
        end
        st.fixItDone  = true
        st.fixItReady = false
        if diag.fixItHeadline then
            st.storyHeadline = diag.fixItHeadline
        end
        return diag.fixItHeadline or "Fix It! The procedure is complete."

    elseif toolId == T.STITCHES then
        local hadIncision = st.incisions > 0
        if hadIncision then
            st.incisions = st.incisions - 1
        end
        -- Closing a proper incision = -2, bandaging with no incision = -1 (confirmed GT debug)
        local bleedDelta = -1
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, bleedDelta)
        return hadIncision and "You stitched up an incision." or "You bandaged some injuries."

    elseif toolId == T.SPLINT then
        if st.brokenBones > 0 then
            st.brokenBones = st.brokenBones - 1
        end
        return "You splinted a broken bone."

    elseif toolId == T.ULTRASOUND then
        st.ultrasoundUsed = true
        st.bonesRevealed  = true
        st.diagRevealed   = true
        if diag.headline then
            st.storyHeadline = diag.headline
        end
        local boneInfo = ""
        if st.brokenBones > 0 or st.shatteredBones > 0 then
            local parts = {}
            if st.brokenBones > 0 then
                parts[#parts+1] = st.brokenBones .. " broken bone" .. (st.brokenBones > 1 and "s" or "")
            end
            if st.shatteredBones > 0 then
                parts[#parts+1] = st.shatteredBones .. " shattered bone" .. (st.shatteredBones > 1 and "s" or "")
            end
            boneInfo = " You found " .. table.concat(parts, " and ") .. "."
        end
        -- Return as lastMsg only — storyHeadline already shows diagnosis persistently.
        -- Do NOT set contextMsg: would appear alongside lastMsg on same turn, causing duplicates.
        return "You scanned the patient with ultrasound, discovering they are suffering from "
               .. string.lower(diag.name or "?") .. "!" .. boneInfo

    elseif toolId == T.PINS then
        if st.shatteredBones > 0 then
            st.shatteredBones = st.shatteredBones - 1
            st.brokenBones    = st.brokenBones + 1
        end
        return "You pinned a shattered bone together. Don't forget to splint it!"

    elseif toolId == T.CLAMP then
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, -1)
        return "You clamped the wound."

    elseif toolId == T.TRANSFUSION then
        st.pulse = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, -2)
        return "You transfused several pints of blood into your patient."

    elseif toolId == T.DEFIBRILLATOR then
        if st.heartStopped then
            st.heartStopped     = false
            st.heartStopTurns   = 0
            st.pulse            = "WEAK"
            return "You shocked the patient back to life!"
        end
        return "Defibrillator used but patient's heart is fine."
    end

    return "Used tool."
end

-- =======================================================
-- APPLY SKILL FAIL EFFECT
-- Returns message string
-- =======================================================

function M.applySkillFailEffect(session, toolId)
    local T  = SD.TOOL
    local st = session

    if toolId == T.ANTIBIOTICS then
        return SD.TOOL_FAIL_MSG[T.ANTIBIOTICS]

    elseif toolId == T.TRANSFUSION then
        return SD.TOOL_FAIL_MSG[T.TRANSFUSION]

    elseif toolId == T.ANESTHETIC then
        st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, 1)
        return "You inhaled the anesthetic. Visibility worsens."

    elseif toolId == T.SPLINT then
        return SD.TOOL_FAIL_MSG[T.SPLINT]

    elseif toolId == T.PINS then
        -- Ecto-Bones special event: pin phases through → extra shattered bone
        local diag = SD.DIAG[st.diagKey]
        if diag and diag.specialEvent == "ecto_pins_fail" then
            st.shatteredBones = st.shatteredBones + 1
            return SD.TOOL_FAIL_MSG[T.PINS] .. " The pin phased through, shattering another bone!"
        end
        return SD.TOOL_FAIL_MSG[T.PINS]

    elseif toolId == T.SCALPEL then
        -- Scalpel skill fail = still cuts, but extra bleeding
        st.incisions    = st.incisions + 1
        st.scalpelCount = st.scalpelCount + 1
        st.bleeding     = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        local diag = SD.DIAG[st.diagKey]
        if diag.needsFixIt and st.scalpelCount >= st.requiredScalpels then
            st.fixItReady = true
            if diag.scalpelHeadline then
                st.storyHeadline = diag.scalpelHeadline
            end
            if diag.scalpelContextMsg then
                st.contextMsg = diag.scalpelContextMsg
            end
        end
        return SD.TOOL_FAIL_MSG[T.SCALPEL]

    elseif toolId == T.FIX_IT then
        return "<<RETRY>>You screwed it up! Try again."

    elseif toolId == T.DEFIBRILLATOR then
        return "You electrocuted yourself! Turn wasted."

    else
        -- Harmless fails (Sponge, Stitches, Antiseptic, Lab Kit, Ultrasound, Clamp)
        return SD.TOOL_FAIL_MSG[toolId] or "Skill fail! No major effect."
    end
end

-- =======================================================
-- PASSIVE EFFECTS PER TURN
-- =======================================================

function M.applyPassiveEffects(session)
    local st   = session
    local diag = SD.DIAG[st.diagKey]

    -- Antibiotics 2-turn passive effect (2-4°F drop per turn, floor 98.6)
    if st.abxTurnsLeft and st.abxTurnsLeft > 0 then
        local drop
        if st.modifiers and st.modifiers.ANTIBIOTIC_RESISTANT then
            drop = 0.3 + math.random(0, 3) * 0.1  -- 0.3–0.6°F
        else
            drop = 2 + math.random(0, 2)  -- 2–4°F
        end
        st.temperature  = math.max(98.6, st.temperature - drop)
        if st.temperature <= 98.6 then st.tempRising = false end
        st.abxTurnsLeft = st.abxTurnsLeft - 1
    end

    -- Anesthetic countdown + consciousness state
    if st.anesthTurns > 0 then
        st.anesthTurns = st.anesthTurns - 1
    end
    -- Normal wakeup sequence: UNCONSCIOUS → COMING_TO → AWAKE
    if st.anesthTurns == 0 then
        st.consciousness = "AWAKE"
    else
        if st.anesthTurns <= 3 then
            st.consciousness = "COMING_TO"
        else
            st.consciousness = "UNCONSCIOUS"
        end
    end

    -- Bleeding effects (hemophiliac: bleeds 2x faster)
    -- Site always worsens with any bleeding (>NONE).
    -- Visibility: probability-based per tier (not guaranteed every turn).
    --   MODERATE=40%, RAPID=65%, INTENSE=100%
    local bleedIdx   = SD.BLEED_INDEX[st.bleeding] or 1
    local bleedDelta = (st.modifiers and st.modifiers.HEMOPHILIAC) and 2 or 1
    if bleedIdx > 1 then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, bleedDelta)
        local visChance = 0
        if     bleedIdx >= (SD.BLEED_INDEX["INTENSE"]   or 5) then visChance = 1.00
        elseif bleedIdx >= (SD.BLEED_INDEX["RAPID"]     or 4) then visChance = 0.65
        elseif bleedIdx >= (SD.BLEED_INDEX["MODERATE"]  or 3) then visChance = 0.40
        end
        if visChance > 0 and math.random() < visChance then
            st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, 1)
        end
    end

    -- Bleeding self-escalation: untreated wounds worsen over time
    if bleedIdx == (SD.BLEED_INDEX["SLIGHT"] or 2) then
        if math.random() < 0.15 then
            st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
        end
    elseif bleedIdx == (SD.BLEED_INDEX["MODERATE"] or 3) then
        if math.random() < 0.25 then
            st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
        end
    end

    -- Pulse degrades from sustained heavy bleeding
    if bleedIdx >= (SD.BLEED_INDEX["INTENSE"] or 5) then
        if math.random() < 0.60 then
            st.pulse = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, 1)
        end
    elseif bleedIdx >= (SD.BLEED_INDEX["RAPID"] or 4) then
        if math.random() < 0.30 then
            st.pulse = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, 1)
        end
    end

    -- Filthy modifier: site gets dirtier faster
    if st.modifiers and st.modifiers.FILTHY and st.incisions > 0 then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, 1)
    end

    -- Antibiotics immunity countdown (prevents dirty site re-triggering fever)
    if st.abxImmuneTurns and st.abxImmuneTurns > 0 then
        st.abxImmuneTurns = st.abxImmuneTurns - 1
    end

    -- Dirtiness: chance per turn to trigger fever climbing (if not already rising)
    -- Skipped during antibiotics immunity window
    if not st.tempRising and (not st.abxImmuneTurns or st.abxImmuneTurns <= 0) then
        local cleanIdx      = SD.CLEAN_INDEX[st.siteClean] or 1
        local triggerChance = 0
        if     cleanIdx >= 4 then triggerChance = 0.30   -- UNSANITARY
        elseif cleanIdx >= 3 then triggerChance = 0.15   -- DIRTY
        elseif cleanIdx >= 2 then triggerChance = 0.05   -- SLIGHTLY_DIRTY
        end
        if triggerChance > 0 and math.random() < triggerChance then
            st.tempRising = true
        end
    end

    -- Fever climbing: reduced rates to avoid insta-death on all diagnoses
    --   tempRiseFast (FLU, MONKEY_FLU): 0.3–0.7°F per turn
    --   regular tempRising:             0.1–0.3°F per turn
    if st.tempRising then
        if diag.tempRiseFast then
            st.temperature = st.temperature + (0.3 + math.random(0, 2) * 0.2)
        else
            st.temperature = st.temperature + (0.1 + math.random(0, 2) * 0.1)
        end
    end

    -- Patient screams/flails if AWAKE with open incisions
    -- Bleeding penalty kept (+2) — that's the dangerous consequence.
    -- Visibility only worsens 40% of the time (flailing is chaotic, not always blood in eyes).
    if st.consciousness == "AWAKE" and st.incisions > 0 then
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        if math.random() < 0.40 then
            st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, 1)
        end
    end

    -- Per-diagnosis heart stop chance (while incisions open)
    if diag.heartStopChance and diag.heartStopChance > 0 and st.incisions > 0 then
        if not st.heartStopped and math.random() < diag.heartStopChance then
            st.heartStopped   = true
            st.heartStopTurns = 0
        end
    end

    -- Special events (vile vial maladies only)
    local ev = diag.specialEvent
    if ev then
        if ev == "chaos" then
            -- Random: temp spike, sudden heart stop, or random bleed
            local roll = math.random(1, 20)
            if roll == 1 then
                st.temperature = st.temperature + math.random(1, 2) * 0.5
            elseif roll == 2 and not st.heartStopped then
                st.heartStopped   = true
                st.heartStopTurns = 0
            elseif roll == 3 then
                st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
            end

        elseif ev == "howl" then
            -- ~20% chance patient howls → +1 incision + bleed rises
            if math.random() < 0.20 then
                st.incisions = st.incisions + 1
                st.bleeding  = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
                st.lastMsg   = (st.lastMsg or "") .. " `4The patient howls! An incision opened!"
            end

        elseif ev == "worms_escape" then
            -- After fixItDone, ~25% chance worms escape → reset Fix It
            if st.fixItDone and math.random() < 0.25 then
                st.fixItDone  = false
                st.fixItReady = true
                st.lastMsg    = (st.lastMsg or "") .. " `4Worms escaped to the back of the brain! Fix It again!"
            end

        elseif ev == "guts_burst" then
            -- Every ~3-4 turns: guts burst → visibility = IMPOSSIBLE
            if st.moveCount > 0 and st.moveCount % 5 == 0 then
                st.visibility = "IMPOSSIBLE"
                st.lastMsg    = (st.lastMsg or "") .. " `4The patient's guts burst! You can't see anything!"
            end

        elseif ev == "fat_heartstop" then
            -- Frequent heart stops only while patient is unconscious
            if st.consciousness ~= "AWAKE" and not st.heartStopped and math.random() < 0.25 then
                st.heartStopped   = true
                st.heartStopTurns = 0
                st.lastMsg        = (st.lastMsg or "") .. " `4Fat build up caused the patient's heart to stop!"
            end
        end
        -- "ecto_pins_fail" is handled directly in applySkillFailEffect
    end

    -- Heart stop counter
    if st.heartStopped then
        st.heartStopTurns = st.heartStopTurns + 1
    end

    st.moveCount = st.moveCount + 1
end

-- =======================================================
-- FAIL CONDITION CHECK
-- Returns fail_key string or nil
-- =======================================================

function M.checkFail(session)
    local st = session

    -- Scalpel on awake patient (checked before tool effect, handled in callbacks)
    -- Temperature too high
    if st.temperature > 110.0 then
        return "INFECTION", "The patient has succumbed to infection. YOUR MEDICAL LICENSE IS REVOKED!"
    end

    -- Bled out
    if st.pulse == "NONE" then
        return "BLED_OUT", "The patient has bled out! YOUR MEDICAL LICENSE IS REVOKED!"
    end

    -- Heart not resuscitated in time
    if st.heartStopped and st.heartStopTurns >= 2 then
        return "HEART_STOPPED", "The patient was not resuscitated in time. YOUR MEDICAL LICENSE IS REVOKED!"
    end

    return nil, nil
end

-- =======================================================
-- WIN CONDITION CHECK
-- =======================================================

-- Unified win check — same conditions for ALL diagnoses.
-- Note: pulse strength and tempRising do NOT affect win (matches real GT).
function M.checkWin(session)
    local st   = session
    local diag = SD.DIAG[st.diagKey]
    if diag.needsFixIt and not st.fixItDone  then return false end
    if st.incisions ~= 0                     then return false end
    if st.bleeding ~= "NONE"                 then return false end
    if st.brokenBones ~= 0                   then return false end
    if st.shatteredBones ~= 0                then return false end
    if st.temperature > 100.4                then return false end
    if st.heartStopped                       then return false end
    return true
end

return M
