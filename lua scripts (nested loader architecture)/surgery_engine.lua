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

        -- Consciousness (AWAKE / UNCONSCIOUS / COMING_TO / NEAR_COMA)
        -- Derived from anesthTurns each turn; anesthTurns = 0 means AWAKE
        consciousness  = "AWAKE",
        anesthTurns    = 0,

        -- Surgical site
        incisions      = 0,
        scalpelCount   = 0,
        bleeding       = diag.initialBleeding,
        siteClean      = modMap.FILTHY and "SLIGHTLY_DIRTY" or "CLEAN",
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
        abxUnlocked    = not diag.needsLabKit,
        bonesRevealed  = not diag.needsUltrasound,
        diagRevealed   = false,  -- always hidden until ultrasound

        -- Story headline + persistent context message
        storyHeadline  = "`4The patient has not been diagnosed.",
        contextMsg     = "",

        -- Modifiers (map for quick lookup + array for display)
        modifiers      = modMap,
        modifierList   = mods,

        -- Last action message (shown in UI)
        lastMsg        = "",
        failReason     = nil,
        moveCount      = 0,

        -- Antibiotics passive effect counter
        abxTurnsLeft   = 0,
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

    -- Single-use: available until successfully used
    if toolId == T.ULTRASOUND  then return not st.ultrasoundUsed end
    if toolId == T.LAB_KIT     then return not st.labKitUsed end

    -- Only available after Lab Kit is physically used
    if toolId == T.ANTIBIOTICS then return st.labKitUsed end

    -- Fix It: available when objective reached, disappears after use
    if toolId == T.FIX_IT then return st.fixItReady and not st.fixItDone end

    -- Bone tools: require bones revealed (Ultrasound used or needsUltrasound=false)
    if toolId == T.SPLINT then return st.bonesRevealed and st.brokenBones > 0 end
    if toolId == T.PINS   then return st.bonesRevealed and st.incisions > 0 and st.shatteredBones > 0 end
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
        return "You clean the operation site. Visibility improves."

    elseif toolId == T.LAB_KIT then
        st.labKitUsed    = true
        st.abxUnlocked   = true
        return "Lab results in. Antibiotics are now unlocked."

    elseif toolId == T.ANTIBIOTICS then
        -- Immediate drop on use + 2-turn passive effect (1-3°F per turn)
        -- Also clears fever climbing flag
        local drop
        if st.modifiers and st.modifiers.ANTIBIOTIC_RESISTANT then
            drop = 0.3 + math.random(0, 3) * 0.1  -- 0.3–0.6°F
        else
            drop = 1 + math.random(0, 2)  -- 1–3°F
        end
        st.temperature  = math.max(98.6, st.temperature - drop)
        st.tempRising   = false
        st.abxTurnsLeft = 2
        return string.format("Antibiotics administered. Temperature: %.1f°F. Treatment active for 2 more turns.", st.temperature)

    elseif toolId == T.ANTISEPTIC then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, -2)
        return "Area disinfected."

    elseif toolId == T.ANESTHETIC then
        -- Near coma → re-dose = permanent death (overdose)
        if st.consciousness == "NEAR_COMA" then
            return "<<PERMA_DEATH>>"
        end
        -- Already unconscious → overdose: patient enters NEAR_COMA after passive tick
        if st.consciousness == "UNCONSCIOUS" then
            st.anesthTurns = 2  -- passive tick: 2→1 = NEAR_COMA
            return "Overdose! Patient critical — DO NOT use Anesthetic again!"
        end
        -- AWAKE or COMING_TO → normal dose / safe re-dose → UNCONSCIOUS
        local turns = (st.modifiers and st.modifiers.HYPERACTIVE) and 4 or 10
        st.consciousness = "UNCONSCIOUS"
        st.anesthTurns   = turns
        return string.format("Patient sedated. You have about %d moves.", turns)

    elseif toolId == T.SCALPEL then
        st.incisions    = st.incisions + 1
        st.scalpelCount = st.scalpelCount + 1
        st.bleeding     = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
        if diag.needsFixIt and st.scalpelCount >= st.requiredScalpels then
            st.fixItReady = true
            if diag.scalpelHeadline then
                st.storyHeadline = diag.scalpelHeadline
            end
            if diag.scalpelContextMsg then
                st.contextMsg = diag.scalpelContextMsg
            end
        end
        return "Incision made. Incisions: " .. st.incisions

    elseif toolId == T.FIX_IT then
        -- 30% chance it fails on first try (retryable)
        local failChance = 0.30 - (tonumber(session.surgeonSkillSnapshot) or 0) * 0.002
        failChance = math.max(0.05, failChance)
        if math.random() < failChance then
            return "<<RETRY>>You screwed it up! Try again."  -- special marker
        end
        st.fixItDone  = true
        st.fixItReady = false
        if diag.fixItHeadline then
            st.storyHeadline = diag.fixItHeadline
        end
        return "Fix It! The procedure is complete. Now close up the incisions."

    elseif toolId == T.STITCHES then
        if st.incisions > 0 then
            st.incisions = st.incisions - 1
        end
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, -2)
        return "Incisions reduced to " .. st.incisions .. ". Bleeding: " .. st.bleeding

    elseif toolId == T.SPLINT then
        if st.brokenBones > 0 then
            st.brokenBones = st.brokenBones - 1
        end
        return "Bone set. Broken bones remaining: " .. st.brokenBones

    elseif toolId == T.ULTRASOUND then
        st.ultrasoundUsed = true
        st.bonesRevealed  = true
        st.diagRevealed   = true
        st.storyHeadline  = diag.headline or ("Patient suffers from " .. (diag.name or "?") .. ".")
        return ""

    elseif toolId == T.PINS then
        if st.shatteredBones > 0 then
            st.shatteredBones = st.shatteredBones - 1
            st.brokenBones    = st.brokenBones + 1
        end
        return "Shattered bone stabilized → now broken. Shattered: " .. st.shatteredBones

    elseif toolId == T.CLAMP then
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, -1)
        return "Clamped. Bleeding: " .. st.bleeding

    elseif toolId == T.TRANSFUSION then
        st.pulse = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, -2)
        return ""

    elseif toolId == T.DEFIBRILLATOR then
        if st.heartStopped then
            st.heartStopped     = false
            st.heartStopTurns   = 0
            st.pulse            = "WEAK"
            return "CLEAR! Heart restarted. Pulse is Weak."
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
        end
        return SD.TOOL_FAIL_MSG[T.SCALPEL] .. " Extra bleeding."

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

    -- Antibiotics 2-turn passive effect (1-3°F drop per turn, floor 98.6)
    if st.abxTurnsLeft and st.abxTurnsLeft > 0 then
        local drop
        if st.modifiers and st.modifiers.ANTIBIOTIC_RESISTANT then
            drop = 0.3 + math.random(0, 3) * 0.1  -- 0.3–0.6°F
        else
            drop = 1 + math.random(0, 2)  -- 1–3°F
        end
        st.temperature  = math.max(98.6, st.temperature - drop)
        if st.temperature <= 98.6 then st.tempRising = false end
        st.abxTurnsLeft = st.abxTurnsLeft - 1
    end

    -- Anesthetic countdown + consciousness state
    if st.anesthTurns > 0 then
        st.anesthTurns = st.anesthTurns - 1
    end
    if st.anesthTurns == 0 then
        st.consciousness = "AWAKE"
    elseif st.anesthTurns == 1 then
        st.consciousness = "NEAR_COMA"
    elseif st.anesthTurns <= 3 then
        st.consciousness = "COMING_TO"
    else
        st.consciousness = "UNCONSCIOUS"
    end

    -- Bleeding effects (hemophiliac: bleeds 2x faster)
    local bleedDelta = (st.modifiers and st.modifiers.HEMOPHILIAC) and 2 or 1
    if SD.BLEED_INDEX[st.bleeding] and SD.BLEED_INDEX[st.bleeding] > 1 then
        st.pulse      = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, 1)
        st.visibility = SD.shiftRank(SD.VIS_ORDER,   SD.VIS_INDEX,   st.visibility, bleedDelta)
        st.siteClean  = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, bleedDelta)
    end

    -- Filthy modifier: site gets dirtier faster
    if st.modifiers and st.modifiers.FILTHY and st.incisions > 0 then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, 1)
    end

    -- Dirtiness: chance per turn to trigger fever climbing (if not already rising)
    if not st.tempRising then
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

    -- Fever climbing: temp rises 0.5–2°F per turn
    if st.tempRising then
        st.temperature = st.temperature + (0.5 + math.random(0, 3) * 0.5)
    end

    -- Patient screams/flails if AWAKE with open incisions
    if st.consciousness == "AWAKE" and st.incisions > 0 then
        st.bleeding   = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        st.visibility = SD.shiftRank(SD.VIS_ORDER,   SD.VIS_INDEX,   st.visibility, 1)
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
            local roll = math.random(1, 8)
            if roll == 1 then
                st.temperature = st.temperature + math.random(2, 5) * 0.5
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
                st.fixItDone  = true  -- keep done but reset ready so player must redo
                st.fixItReady = true
                st.fixItDone  = false
                st.lastMsg    = (st.lastMsg or "") .. " `4Worms escaped to the back of the brain! Fix It again!"
            end

        elseif ev == "guts_burst" then
            -- Every ~3-4 turns: guts burst → visibility = IMPOSSIBLE
            if st.moveCount > 0 and st.moveCount % 3 == 0 then
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
