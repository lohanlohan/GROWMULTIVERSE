-- MODULE
-- surgery_data.lua — Surgical tool definitions and diagnosis data (5 diagnoses)

local M = {}

-- =======================================================
-- TOOL ITEM IDs
-- =======================================================

M.TOOL = {
    SPONGE        = 1258,
    SCALPEL       = 1260,
    ANESTHETIC    = 1262,
    STITCHES      = 1270,
    ANTIBIOTICS   = 1266,
    ANTISEPTIC    = 1264,
    SPLINT        = 1268,
    LAB_KIT       = 4318,
    DEFIBRILLATOR = 4312,
    PINS          = 4308,
    CLAMP         = 4314,
    TRANSFUSION   = 4310,
    ULTRASOUND    = 4316,
    FIX_IT        = 1296,
    CADUCEUS      = 4298,
}

-- Display label per tool
M.TOOL_LABEL = {
    [1258] = "Sponge",
    [1260] = "Scalpel",
    [1262] = "Anesthetic",
    [1270] = "Stitches",
    [1266] = "Antibiotics",
    [1264] = "Antiseptic",
    [1268] = "Splint",
    [4318] = "Lab Kit",
    [4312] = "Defibrillator",
    [4308] = "Pins",
    [4314] = "Clamp",
    [4310] = "Transfusion",
    [4316] = "Ultrasound",
    [1296] = "Fix It!",
}

-- =======================================================
-- PULSE ORDER  (index = severity, 1 = best, 5 = fatal)
-- =======================================================

M.PULSE_ORDER  = { "STRONG", "STEADY", "WEAK", "EXTREMELY_WEAK", "NONE" }
M.PULSE_INDEX  = {}
for i, p in ipairs(M.PULSE_ORDER) do M.PULSE_INDEX[p] = i end

M.BLEED_ORDER  = { "NONE", "SLIGHT", "MODERATE", "RAPID", "INTENSE" }
M.BLEED_INDEX  = {}
for i, b in ipairs(M.BLEED_ORDER) do M.BLEED_INDEX[b] = i end

M.CLEAN_ORDER  = { "CLEAN", "SLIGHTLY_DIRTY", "DIRTY", "UNSANITARY" }
M.CLEAN_INDEX  = {}
for i, c in ipairs(M.CLEAN_ORDER) do M.CLEAN_INDEX[c] = i end

M.VIS_ORDER    = { "CLEAR", "SLIGHTLY_HARD", "HARD", "IMPOSSIBLE" }
M.VIS_INDEX    = {}
for i, v in ipairs(M.VIS_ORDER) do M.VIS_INDEX[v] = i end

-- Shift a value along an order list by delta (clamped)
function M.shiftRank(orderList, indexMap, current, delta)
    local idx = (indexMap[current] or 1) + delta
    idx = math.max(1, math.min(#orderList, idx))
    return orderList[idx]
end

-- =======================================================
-- SKILL FAIL CHANCE
-- =======================================================

-- Returns probability 0..1 that the next tool use is a skill-fail
function M.skillFailChance(surgeonSkill)
    local base   = 0.25
    local reduce = (tonumber(surgeonSkill) or 0) * 0.002
    return math.max(0.01, base - reduce)
end

-- =======================================================
-- DIAGNOSES  (5 total)
-- =======================================================
-- Fields:
--   name            string
--   initialTemp     float (°F)
--   tempRising      bool
--   initialPulse    PULSE_ORDER string
--   initialBleeding BLEED_ORDER string
--   brokenBones     int
--   shatteredBones  int
--   requiredScalpels int (how many before Fix It available)
--   needsLabKit     bool  (antibiotics locked until Lab Kit)
--   needsUltrasound bool  (bones hidden / splint/pins locked until US)
--   needsFixIt      bool  (surgery requires Fix It to complete)
--   heartStopChance float (per-turn random chance 0..1, 0=never)
--   description     string shown in UI before surgery starts

M.DIAG = {
    FLU = {
        name             = "Flu",
        initialTemp      = 102.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        requiredScalpels = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = false,
        heartStopChance  = 0,
        description      = "Patient has a bad fever. Bring the temperature down to normal.",
    },
    BROKEN_ARM = {
        name             = "Broken Arm",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "SLIGHT",
        brokenBones      = 2,
        shatteredBones   = 0,
        requiredScalpels = 0,
        needsLabKit      = false,
        needsUltrasound  = true,
        needsFixIt       = false,
        heartStopChance  = 0,
        description      = "Patient has broken bones and needs them set.",
    },
    NOSE_JOB = {
        name             = "Nose Job",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        requiredScalpels = 1,
        needsLabKit      = false,
        needsUltrasound  = false,
        needsFixIt       = true,
        heartStopChance  = 0,
        description      = "Routine cosmetic procedure. Keep the patient under and make precise incisions.",
    },
    APPENDICITIS = {
        name             = "Appendicitis",
        initialTemp      = 103.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        requiredScalpels = 3,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        heartStopChance  = 0,
        description      = "Severe inflammation. Reduce fever, sanitize the site, then operate carefully.",
    },
    BROKEN_HEART = {
        name             = "Broken Heart",
        initialTemp      = 100.0,
        tempRising       = true,
        initialPulse     = "WEAK",
        initialBleeding  = "NONE",
        brokenBones      = 2,    -- revealed as shattered+broken via Pins/Splint sequence
        shatteredBones   = 2,
        requiredScalpels = 2,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        heartStopChance  = 0.12, -- 12% per turn while incisions > 0
        description      = "Critical cardiac condition. Reduce fever, stabilize pulse, and prepare for complications.",
    },
}

-- Ordered list for random selection
M.DIAG_KEYS = { "FLU", "BROKEN_ARM", "NOSE_JOB", "APPENDICITIS", "BROKEN_HEART" }

function M.randomDiag()
    local key = M.DIAG_KEYS[math.random(1, #M.DIAG_KEYS)]
    return key, M.DIAG[key]
end

return M
