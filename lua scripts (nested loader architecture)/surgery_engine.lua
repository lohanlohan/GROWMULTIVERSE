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
    return {
        -- Identity
        diagKey       = diagKey,
        surgeonName   = surgeon:getName(),
        surgeonUID    = surgeon:getUserID(),
        tileX         = tileX,
        tileY         = tileY,
        cfg           = cfg,   -- { prizePool, caduceusId, onEnd }

        -- Vital signs
        temperature   = diag.initialTemp,
        tempRising    = diag.tempRising,
        pulse         = diag.initialPulse,
        heartStopped  = false,
        heartStopTurns= 0,

        -- Consciousness
        consciousness = "AWAKE",
        anesthTurns   = 0,

        -- Surgical site
        incisions     = 0,
        scalpelCount  = 0,
        bleeding      = diag.initialBleeding,
        siteClean     = "CLEAN",
        visibility    = "CLEAR",

        -- Bones
        brokenBones   = diag.brokenBones,
        shatteredBones= diag.shatteredBones,

        -- Diagnosis tracking
        labKitUsed    = false,
        ultrasoundUsed= false,
        fixItReady    = (diag.requiredScalpels == 0 and not diag.needsFixIt) and true or false,
        fixItDone     = false,
        abxUnlocked   = not diag.needsLabKit,   -- true if no lab kit needed
        bonesRevealed = not diag.needsUltrasound,

        -- Last action message (shown in UI)
        lastMsg       = "",
        failReason    = nil,  -- set on fail before session cleared
        moveCount     = 0,
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

    -- Unlocked by Lab Kit
    if toolId == T.ANTIBIOTICS then return st.abxUnlocked end

    -- Fix It: available when objective reached, disappears after use
    if toolId == T.FIX_IT then return st.fixItReady and not st.fixItDone end

    -- Require open incisions + relevant bone state
    if toolId == T.SPLINT then return st.incisions > 0 and st.brokenBones > 0 end
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
        return "You clean the operation site. Visibility improves."

    elseif toolId == T.LAB_KIT then
        st.labKitUsed   = true
        st.abxUnlocked  = true
        return "Lab results in. Antibiotics are now unlocked."

    elseif toolId == T.ANTIBIOTICS then
        -- Lower temp by ~1-2°F per use
        local drop = 1.0 + math.random(0, 10) * 0.1
        st.temperature  = math.max(97.0, st.temperature - drop)
        if st.temperature <= 98.6 then st.tempRising = false end
        return string.format("Antibiotics administered. Temperature: %.1f°F", st.temperature)

    elseif toolId == T.ANTISEPTIC then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, -2)
        return "Area disinfected."

    elseif toolId == T.ANESTHETIC then
        st.consciousness = "UNCONSCIOUS"
        st.anesthTurns   = 10
        return "Patient is now unconscious. You have about 10 moves."

    elseif toolId == T.SCALPEL then
        st.incisions     = st.incisions + 1
        st.scalpelCount  = st.scalpelCount + 1
        st.bleeding      = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
        -- Check if Fix It is now ready
        if diag.needsFixIt and st.scalpelCount >= diag.requiredScalpels then
            st.fixItReady = true
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
        return string.format("Ultrasound reveals: %d broken, %d shattered bone(s).",
            st.brokenBones, st.shatteredBones)

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
        st.pulse = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, -1)
        return "Transfusion complete. Pulse: " .. st.pulse

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
        st.temperature = st.temperature + 1.5
        return "Wrong medication! Bacteria liked it. Temperature rises."

    elseif toolId == T.TRANSFUSION then
        st.siteClean = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, 1)
        return "You spilled blood everywhere! Site is dirtier."

    elseif toolId == T.ANESTHETIC then
        st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, 1)
        return "You inhaled the anesthetic. Visibility worsens."

    elseif toolId == T.SPLINT then
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 1)
        return "You cut the patient! Bleeding increases."

    elseif toolId == T.PINS then
        st.bleeding = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        return "Pin through the artery! Bleeding increases rapidly."

    elseif toolId == T.SCALPEL then
        -- Scalpel skill fail = still cuts, but extra bleeding
        st.incisions    = st.incisions + 1
        st.scalpelCount = st.scalpelCount + 1
        st.bleeding     = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        local diag = SD.DIAG[st.diagKey]
        if diag.needsFixIt and st.scalpelCount >= diag.requiredScalpels then
            st.fixItReady = true
        end
        return "Nasty scar, but you cut the right place. Extra bleeding."

    elseif toolId == T.FIX_IT then
        return "<<RETRY>>You screwed it up! Try again."

    elseif toolId == T.DEFIBRILLATOR then
        return "You electrocuted yourself! Turn wasted."

    else
        -- Harmless fails (Sponge, Stitches, Antiseptic, Lab Kit, Ultrasound, Clamp)
        local harmless = {
            [T.SPONGE]     = "You somehow managed to eat the sponge.",
            [T.STITCHES]   = "You tied yourself in stitches. Embarrassing.",
            [T.ANTISEPTIC] = "You spilled antiseptic on your shoes. Very clean shoes.",
            [T.LAB_KIT]    = "You contaminated the sample.",
            [T.ULTRASOUND] = "You scanned the nurse by accident.",
            [T.CLAMP]      = "The clamp fell out of your hand, oh well.",
        }
        return harmless[toolId] or "Skill fail! No major effect."
    end
end

-- =======================================================
-- PASSIVE EFFECTS PER TURN
-- =======================================================

function M.applyPassiveEffects(session)
    local st   = session
    local diag = SD.DIAG[st.diagKey]

    -- Anesthetic countdown
    if st.anesthTurns > 0 then
        st.anesthTurns = st.anesthTurns - 1
        if st.anesthTurns == 0 then
            st.consciousness = "AWAKE"
        end
    end

    -- Bleeding effects
    if SD.BLEED_INDEX[st.bleeding] and SD.BLEED_INDEX[st.bleeding] > 1 then
        -- Pulse degrades
        st.pulse     = SD.shiftRank(SD.PULSE_ORDER, SD.PULSE_INDEX, st.pulse, 1)
        -- Visibility worsens
        st.visibility = SD.shiftRank(SD.VIS_ORDER, SD.VIS_INDEX, st.visibility, 1)
        -- Site gets dirtier
        st.siteClean  = SD.shiftRank(SD.CLEAN_ORDER, SD.CLEAN_INDEX, st.siteClean, 1)
    end

    -- Infection: dirty + bleeding → temp rises
    if SD.CLEAN_INDEX[st.siteClean] and SD.CLEAN_INDEX[st.siteClean] >= 3
    and SD.BLEED_INDEX[st.bleeding] and SD.BLEED_INDEX[st.bleeding] > 1 then
        st.temperature = st.temperature + 0.5
    elseif st.tempRising then
        st.temperature = st.temperature + 0.3
    end

    -- Patient screams/flails if awake with open incisions
    if st.consciousness == "AWAKE" and st.incisions > 0 then
        st.bleeding   = SD.shiftRank(SD.BLEED_ORDER, SD.BLEED_INDEX, st.bleeding, 2)
        st.visibility = SD.shiftRank(SD.VIS_ORDER,   SD.VIS_INDEX,   st.visibility, 1)
    end

    -- Heart stop (Broken Heart diagnosis)
    if diag.heartStopChance and diag.heartStopChance > 0 and st.incisions > 0 then
        if not st.heartStopped and math.random() < diag.heartStopChance then
            st.heartStopped    = true
            st.heartStopTurns  = 0
        end
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
        return "INFECTION", "The patient has succumbed to infection."
    end

    -- Bled out
    if st.pulse == "NONE" then
        return "BLED_OUT", "The patient has bled out!"
    end

    -- Heart not resuscitated in time
    if st.heartStopped and st.heartStopTurns >= 2 then
        return "HEART_STOPPED", "The patient was not resuscitated in time."
    end

    return nil, nil
end

-- =======================================================
-- WIN CONDITION CHECK
-- =======================================================

function M.checkWin(session)
    local st   = session
    local diag = SD.DIAG[st.diagKey]

    -- Flu: no scalpel needed, just temp
    if st.diagKey == "FLU" then
        return st.temperature <= 98.6 and not st.tempRising
    end

    -- Broken Arm: no scalpel, just bones and bleeding
    if st.diagKey == "BROKEN_ARM" then
        return st.brokenBones == 0
           and st.shatteredBones == 0
           and st.bleeding == "NONE"
    end

    -- Diagnoses that need Fix It
    if diag.needsFixIt then
        if not st.fixItDone         then return false end
        if st.incisions ~= 0        then return false end
        if st.bleeding ~= "NONE"    then return false end
        if st.brokenBones ~= 0      then return false end
        if st.shatteredBones ~= 0   then return false end
        if st.temperature > 100.4   then return false end
        if st.heartStopped          then return false end
        return true
    end

    return false
end

return M
