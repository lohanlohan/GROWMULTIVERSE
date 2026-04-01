-- MODULE
-- surgery_data.lua — Surgical tool definitions and all 28 diagnoses

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

-- Exact Growtopia skill fail messages
M.TOOL_FAIL_MSG = {
    [1258] = "You somehow managed to eat the sponge.",
    [1260] = "This will leave a nasty scar, but you managed to cut the right place.",
    [1262] = "You end up inhaling all the anesthetic yourself. You feel woozy.",
    [1270] = "You somehow tied yourself up in stitches!",
    [1266] = "This is the wrong medication! The bacteria like it.",
    [1264] = "You spilled antiseptic on your shoes. They are very clean now.",
    [1268] = "You ate a splint, good job!",
    [4318] = "You contaminated the sample.",
    [4312] = "You electrocuted yourself!",
    [4308] = "You jabbed the pin through the artery!",
    [4314] = "The clamp fell out of your hand, oh well.",
    [4310] = "You spilled all of it! Kind of gross.",
    [4316] = "You scanned the nurse with your ultrasound!",
    [1296] = "You screwed it up! Try again.",
}

-- =======================================================
-- VITAL SIGN SCALES
-- =======================================================

-- 7-level pulse (matches real GT)
M.PULSE_ORDER = { "STRONG", "GOOD", "STEADY", "WEAK", "VERY_WEAK", "EXTREMELY_WEAK", "NONE" }
M.PULSE_INDEX = {}
for i, p in ipairs(M.PULSE_ORDER) do M.PULSE_INDEX[p] = i end

M.BLEED_ORDER = { "NONE", "SLIGHT", "MODERATE", "RAPID", "INTENSE" }
M.BLEED_INDEX = {}
for i, b in ipairs(M.BLEED_ORDER) do M.BLEED_INDEX[b] = i end

M.CLEAN_ORDER = { "CLEAN", "SLIGHTLY_DIRTY", "DIRTY", "UNSANITARY" }
M.CLEAN_INDEX = {}
for i, c in ipairs(M.CLEAN_ORDER) do M.CLEAN_INDEX[c] = i end

M.VIS_ORDER = { "CLEAR", "SLIGHTLY_HARD", "HARD", "IMPOSSIBLE" }
M.VIS_INDEX = {}
for i, v in ipairs(M.VIS_ORDER) do M.VIS_INDEX[v] = i end

function M.shiftRank(orderList, indexMap, current, delta)
    local idx = (indexMap[current] or 1) + delta
    idx = math.max(1, math.min(#orderList, idx))
    return orderList[idx]
end

-- =======================================================
-- SKILL FAIL CHANCE
-- =======================================================

function M.skillFailChance(surgeonSkill)
    local base   = 0.25
    local reduce = (tonumber(surgeonSkill) or 0) * 0.002
    return math.max(0.01, base - reduce)
end

-- =======================================================
-- DIAGNOSES  (28 total)
-- =======================================================
-- Fields:
--   name              string
--   category          "standard" | "malady" | "vile_vial"
--   description       string (shown in UI before first move)
--   initialTemp       float °F
--   tempRising        bool  (start with fever flag)
--   initialPulse      PULSE_ORDER key
--   initialBleeding   BLEED_ORDER key
--   initialVisibility VIS_ORDER key (optional, default "CLEAR")
--   brokenBones       int
--   shatteredBones    int
--   needsLabKit       bool  (Antibiotics locked until Lab Kit used)
--   needsUltrasound   bool  (bones hidden, Splint/Pins locked until Ultrasound)
--   needsFixIt        bool  (win requires fixItDone == true)
--   requiredScalpels  int   (Fix It unlocks after this many scalpels; 0 = never needed)
--   heartStopChance   float (random per-turn chance 0..1 while incisions > 0)
--   specialEvent      string|nil  (ONLY vile_vial: "chaos","howl","worms_escape",
--                                  "guts_burst","ecto_pins_fail","fat_heartstop")

M.DIAG = {

    -- =========================================================
    --  STANDARD DIAGNOSES  (16)
    -- =========================================================

    FLU = {
        name             = "Bird Flu",
        category         = "standard",
        description      = "Patient has a bad fever. Use Lab Kit first, then Antibiotics until temperature is normal.",
        initialTemp      = 101.6,
        tempRising       = true,
        tempRiseFast     = true,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = false,
        requiredScalpels = 0,
        heartStopChance  = 0,
        headline         = "Patient is showing signs of the bird flu.",
    },

    MONKEY_FLU = {
        name             = "Monkey Flu",
        category         = "standard",
        description      = "Patient has a severe monkey flu infection. Use Lab Kit first, then Antibiotics until temperature returns to normal.",
        initialTemp      = 107.6,
        tempRising       = true,
        tempRiseFast     = true,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = false,
        requiredScalpels = 0,
        heartStopChance  = 0,
        headline         = "Patient is showing signs of the monkey flu.",
    },

    BROKEN_ARM = {
        name             = "Broken Arm",
        category         = "standard",
        description      = "Broken arm. Use Ultrasound to reveal the fractures, then Splint to set them.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STRONG",
        initialBleeding  = "SLIGHT",
        brokenBones      = 1,
        shatteredBones   = 0,
        needsLabKit      = false,
        needsUltrasound  = true,
        needsFixIt       = false,
        requiredScalpels = 0,
        heartStopChance  = 0,
        headline         = "Patient broke his arm.",
    },

    BROKEN_LEG = {
        name             = "Broken Leg",
        category         = "standard",
        description      = "Broken leg with shattered fragments. Ultrasound first, then Anesthetic, Scalpel, Pins, Splint.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "SLIGHT",
        brokenBones      = 0,
        shatteredBones   = 2,
        needsLabKit      = false,
        needsUltrasound  = true,
        needsFixIt       = false,
        requiredScalpels = 1,
        heartStopChance  = 0,
        headline         = "Patient broke his leg.",
    },

    NOSE_JOB = {
        name             = "Nose Job",
        category         = "standard",
        description      = "Routine cosmetic procedure. Sedate, one incision, Fix It, then stitch up.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = false,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
        headline         = "Patient wants a nose job.",
        scalpelHeadline  = "You have cut into nasal area.",
        scalpelContextMsg = "You have cut into nasal area.",
        fixItHeadline    = "You rearranged their face!",
    },

    LUNG_TUMOR = {
        name             = "Lung Tumor",
        category         = "standard",
        description      = "Tumor must be removed. Ultrasound to locate it, sedate, incision, Fix It, Stitches.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
        headline         = "Patient has a tumor in their lung.",
        scalpelHeadline  = "The lungs are now exposed.",
        scalpelContextMsg = "The lungs are now exposed.",
        fixItHeadline    = "You excised the tumor!",
    },

    HEART_ATTACK = {
        name             = "Heart Attack",
        category         = "standard",
        description      = "Cardiac emergency. Ultrasound to confirm, sedate, two incisions, Fix It, stitch up. Heart may stop — keep Defibrillator ready.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0.03,
        headline         = "Patient had a heart attack.",
        scalpelHeadline  = "The heart is now exposed for operating.",
        scalpelContextMsg = "The heart is now exposed for operating.",
        fixItHeadline    = "You grafted in some nice new arteries!",
    },

    BRAIN_TUMOR = {
        name             = "Brain Tumor",
        category         = "standard",
        description      = "Delicate brain surgery. Five incisions needed — manage visibility carefully.",
        initialTemp      = 98.6,
        tempRising       = true,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 5,
        heartStopChance  = 0,
        headline         = "Patient has a brain tumor, deep inside.",
        scalpelHeadline  = "You've finally found the tumor!",
        scalpelContextMsg = "You've finally found the tumor!",
        fixItHeadline    = "You excised the tumor!",
    },

    LIVER_INFECTION = {
        name             = "Liver Infection",
        category         = "standard",
        description      = "Infected liver. Reduce fever with Antibiotics, then operate with two incisions.",
        initialTemp      = 102.5,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
    },

    KIDNEY_FAILURE = {
        name             = "Kidney Failure",
        category         = "standard",
        description      = "Kidney failure. Reduce fever first, then perform the operation.",
        initialTemp      = 101.8,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
        headline         = "Patient suffers from kidney failure.",
        scalpelHeadline  = "You now have access to the bad kidney.",
        scalpelContextMsg = "You now have access to the bad kidney.",
        fixItHeadline    = "You popped in a fresh new kidney!",
    },

    APPENDICITIS = {
        name             = "Appendicitis",
        category         = "standard",
        description      = "Severe inflammation. Reduce fever, disinfect the site with Antiseptic, then operate.",
        initialTemp      = 103.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0,
        headline         = "Patient suffers from appendicitis.",
        scalpelHeadline  = "You now have access to the appendix.",
        scalpelContextMsg= "You now have access to the appendix.",
        fixItHeadline    = "You yanked out the appendix!",
    },

    SWALLOWED_WL = {
        name             = "Swallowed a World Lock",
        category         = "standard",
        description      = "Patient swallowed a World Lock somehow. Reduce fever, then retrieve it surgically.",
        initialTemp      = 101.6,
        tempRising       = true,
        initialPulse     = "STRONG",
        initialBleeding  = "SLIGHT",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
        headline         = "Patient has swallowed a world lock.",
        scalpelHeadline  = "You've opened the stomach.",
        scalpelContextMsg = "You've opened the stomach.",
        fixItHeadline    = "You got the lock out!",
    },

    HERNIATED_DISC = {
        name             = "Herniated Disc",
        category         = "standard",
        description      = "Damaged spine. Reduce fever, then perform three-incision spinal surgery.",
        initialTemp      = 100.4,
        tempRising       = true,
        initialPulse     = "STRONG",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0,
        headline         = "Patient's spine is damaged.",
        scalpelHeadline  = "You've opened up the vertebrae.",
        scalpelContextMsg = "You've opened up the vertebrae.",
        fixItHeadline    = "You repaired the herniated disc!",
    },

    BROKEN_EVERYTHING = {
        name             = "Broken Everything",
        category         = "standard",
        description      = "Run over by a truck. Multiple fractures everywhere. Complex multi-stage surgery — re-sedation likely needed.",
        initialTemp      = 102.0,
        tempRising       = true,
        initialPulse     = "WEAK",
        initialBleeding  = "SLIGHT",
        brokenBones      = 2,
        shatteredBones   = 3,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0.04,
    },

    SERIOUS_HEAD = {
        name             = "Serious Head Injury",
        category         = "standard",
        description      = "Head trauma with active bleeding. Sponge to clear visibility, Transfuse to stabilize pulse, Lab Kit, Ultrasound, Anesthetic, then operate.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "WEAK",
        initialBleeding  = "MODERATE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
        headline         = "Patient has a serious head injury.",
        scalpelHeadline  = "You've opened the skull.",
        scalpelContextMsg = "You've opened the skull.",
        fixItHeadline    = "You reduced the swelling!",
    },

    SERIOUS_TRAUMA = {
        name             = "Serious Trauma",
        category         = "standard",
        description      = "Trauma with punctured lung. Splint bones, use Lab Kit, sedate, operate.",
        initialTemp      = 98.6,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "MODERATE",
        brokenBones      = 2,
        shatteredBones   = 1,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
        headline         = "Patient suffered serious trauma with a punctured lung.",
        scalpelHeadline  = "You found the lung puncture.",
        scalpelContextMsg = "You found the lung puncture.",
        fixItHeadline    = "You repaired it.",
    },

    MASSIVE_TRAUMA = {
        name             = "Massive Trauma",
        category         = "standard",
        description      = "Critical condition. Sponge first to see anything, stop bleeding, Transfuse, Lab Kit, Ultrasound, then operate. Heart may stop after sedation.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "INTENSE",
        initialVisibility = "IMPOSSIBLE",
        brokenBones      = 2,
        shatteredBones   = 2,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0.05,
        headline         = "Patient suffered massive trauma with internal bleeding.",
        scalpelHeadline  = "You found the internal bleed.",
        scalpelContextMsg = "You found the internal bleed.",
        fixItHeadline    = "You cauterized it.",
    },

    -- =========================================================
    --  MALADY DIAGNOSES  (5)
    -- =========================================================

    TORN_PUNCHING_MUSCLE = {
        name             = "Torn Punching Muscle",
        category         = "malady",
        description      = "Punched too many blocks. The muscle is torn. Sedate, one incision, Fix It, Stitches.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = false,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
    },

    GEM_CUTS = {
        name             = "Gem Cuts",
        category         = "malady",
        description      = "Wounds from picking up gems. Two precise incisions until the wounds are fully examined, then Fix It.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "SLIGHT",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = false,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
    },

    -- Bones visible without Ultrasound (heart condition, bones known from malady)
    BROKEN_HEART_MALADY = {
        name             = "Broken Heart",
        category         = "malady",
        description      = "Too many surgeries broke your own heart. VERY HIGH heart stop chance! Keep Defibrillator ready.",
        initialTemp      = 100.5,
        tempRising       = true,
        initialPulse     = "WEAK",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 2,
        needsLabKit      = true,
        needsUltrasound  = false,  -- bones known (heart malady)
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0.12,
    },

    GRUMBLETEETH = {
        name             = "Grumbleteeth",
        category         = "malady",
        description      = "Chatting too much wore the teeth to bone. Antibiotics, Ultrasound, sedate, operate, Pins, Splint, Fix It.",
        initialTemp      = 101.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 1,
        needsLabKit      = true,
        needsUltrasound  = true,
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
    },

    -- Bones visible without Ultrasound (feet are external, obvious)
    CHICKEN_FEET = {
        name             = "Chicken Feet",
        category         = "malady",
        description      = "Walked too much and grew chicken feet. Reduce fever, operate, Pins twice, then fix everything.",
        initialTemp      = 101.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 2,
        needsLabKit      = true,
        needsUltrasound  = false,  -- feet are external, bones visible
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
    },

    -- =========================================================
    --  VILE VIAL MALADIES  (6)  — specialEvent active
    -- =========================================================

    CHAOS_INFECTION = {
        name             = "Chaos Infection",
        category         = "vile_vial",
        description      = "Pure chaos infects the body. Expect random temperature spikes, sudden heart stops, and status changes.",
        initialTemp      = 102.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "SLIGHT",
        brokenBones      = 1,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = false,
        requiredScalpels = 0,
        heartStopChance  = 0,
        specialEvent     = "chaos",
    },

    LUPUS = {
        name             = "Lupus",
        category         = "vile_vial",
        description      = "Patient howls randomly, adding incisions and bleeding. Stabilize everything before you operate.",
        initialTemp      = 102.5,
        tempRising       = true,
        initialPulse     = "WEAK",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0,
        specialEvent     = "howl",
    },

    BRAINWORMS = {
        name             = "Brainworms",
        category         = "vile_vial",
        description      = "Worms in the brain. They may escape, resetting Fix It. Manage bleeding carefully.",
        initialTemp      = 102.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "SLIGHT",
        brokenBones      = 0,
        shatteredBones   = 1,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0,
        specialEvent     = "worms_escape",
    },

    MOLDY_GUTS = {
        name             = "Moldy Guts",
        category         = "vile_vial",
        description      = "Guts randomly burst, instantly blocking visibility. Keep Sponge ready at all times.",
        initialTemp      = 101.5,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 1,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 2,
        heartStopChance  = 0,
        specialEvent     = "guts_burst",
    },

    ECTO_BONES = {
        name             = "Ecto-Bones",
        category         = "vile_vial",
        description      = "Ghost bones everywhere! Sponge first, Splint all broken bones, then operate. Pins skill fail may shatter more.",
        initialTemp      = 98.6,
        tempRising       = false,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        initialVisibility = "HARD",
        brokenBones      = 6,
        shatteredBones   = 2,
        needsLabKit      = false,
        needsUltrasound  = false,  -- ghost bones are visible
        needsFixIt       = true,
        requiredScalpels = 1,
        heartStopChance  = 0,
        specialEvent     = "ecto_pins_fail",
    },

    FATTY_LIVER = {
        name             = "Fatty Liver",
        category         = "vile_vial",
        description      = "Fat buildup causes frequent heart stops after sedation. Keep Defibrillator ready once patient is unconscious.",
        initialTemp      = 102.0,
        tempRising       = true,
        initialPulse     = "STEADY",
        initialBleeding  = "NONE",
        brokenBones      = 0,
        shatteredBones   = 0,
        needsLabKit      = true,
        needsUltrasound  = false,
        needsFixIt       = true,
        requiredScalpels = 3,
        heartStopChance  = 0,
        specialEvent     = "fat_heartstop",
    },
}

-- =======================================================
-- MODIFIERS  (random roll, can apply to any diagnosis)
-- =======================================================

M.MODIFIER = {
    HYPERACTIVE = {
        key     = "HYPERACTIVE",
        label   = "Hyperactive",
        message = "The patient is hyperactive.",
        chance  = 0.15,
    },
    HEMOPHILIAC = {
        key     = "HEMOPHILIAC",
        label   = "Hemophiliac",
        message = "The patient is a hemophiliac.",
        chance  = 0.15,
    },
    ANTIBIOTIC_RESISTANT = {
        key     = "ANTIBIOTIC_RESISTANT",
        label   = "Antibiotic Resistant",
        message = "The patient has an antibiotic-resistant infection.",
        chance  = 0.10,
    },
    FILTHY = {
        key     = "FILTHY",
        label   = "Absolutely Filthy",
        message = "The patient is absolutely filthy.",
        chance  = 0.10,
    },
    TOUGH_SKIN = {
        key     = "TOUGH_SKIN",
        label   = "Tough Skin",
        message = "The patient exhibits very tough skin. Possibly a superhero.",
        chance  = 0.10,
    },
}

-- Roll which modifiers apply (returns array of modifier keys)
function M.rollModifiers()
    local result = {}
    for key, mod in pairs(M.MODIFIER) do
        if math.random() < mod.chance then
            result[#result + 1] = key
        end
    end
    return result
end

-- =======================================================
-- DIAGNOSIS KEY LISTS
-- =======================================================

M.DIAG_KEYS_STANDARD = {
    "FLU", "MONKEY_FLU", "BROKEN_ARM", "BROKEN_LEG", "NOSE_JOB", "LUNG_TUMOR",
    "HEART_ATTACK", "BRAIN_TUMOR", "LIVER_INFECTION", "KIDNEY_FAILURE",
    "APPENDICITIS", "SWALLOWED_WL", "HERNIATED_DISC", "BROKEN_EVERYTHING",
    "SERIOUS_HEAD", "SERIOUS_TRAUMA", "MASSIVE_TRAUMA",
}

M.DIAG_KEYS_MALADY = {
    "TORN_PUNCHING_MUSCLE", "GEM_CUTS", "BROKEN_HEART_MALADY",
    "GRUMBLETEETH", "CHICKEN_FEET",
}

M.DIAG_KEYS_VILE_VIAL = {
    "CHAOS_INFECTION", "LUPUS", "BRAINWORMS",
    "MOLDY_GUTS", "ECTO_BONES", "FATTY_LIVER",
}

-- All keys combined (used for random selection)
M.DIAG_KEYS = {}
for _, k in ipairs(M.DIAG_KEYS_STANDARD)  do M.DIAG_KEYS[#M.DIAG_KEYS + 1] = k end
for _, k in ipairs(M.DIAG_KEYS_MALADY)    do M.DIAG_KEYS[#M.DIAG_KEYS + 1] = k end
for _, k in ipairs(M.DIAG_KEYS_VILE_VIAL) do M.DIAG_KEYS[#M.DIAG_KEYS + 1] = k end

function M.randomDiag()
    local key = M.DIAG_KEYS[math.random(1, #M.DIAG_KEYS)]
    return key, M.DIAG[key]
end

return M
