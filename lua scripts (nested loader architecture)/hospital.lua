-- MODULE
-- hospital.lua — Hospital System: constants, DB, shared helpers, callbacks

local MaladySystem = _G.MaladySystem

local HospitalSystem = {}

-- =======================================================
-- CONFIG
-- =======================================================

local ROLE_DEVELOPER = 51

local RECEPTION_DESK_ID = 14668
local AUTO_SURGEON_ID   = 14666
local OPERATING_TABLE_ID  = 25030  -- empty bed state
local SURGBOT_ITEM_ID     = 25026  -- surgbot idle
local INSURGERY_ITEM_ID   = 25028  -- in-surgery animation
local WORLD_LOCK_ID     = 242
local DIAMOND_LOCK_ID   = 1796
local BGL_ID            = 7188
local WORLD_KEY_ID      = 1424

local MIN_CURE_PRICE_WL = 2
local CURE_TAX_RATE     = 0.30
local MAX_TOOL_STORAGE  = 1000
local MAX_HOSPITAL_RATING = 5
local RATING_STEP_CURES = 100

local MAX_HOSPITAL_LEVEL = 52
local OPERATING_TABLE_DURATION_MIN_SEC = (24 * 60 + 5) * 60
local OPERATING_TABLE_DURATION_MAX_SEC = (28 * 60 + 10) * 60
local OPERATING_STATUS_BUBBLE_INTERVAL_SEC = 5

local function getRequiredCuresForNextLevel(nextLevel)
    return math.max(0, (30 * nextLevel * nextLevel) - (30 * nextLevel) - 40)
end

local function getUpgradeCostWLByLevel(level)
    if level == 1 then return 10 end
    if level <= 3 then return 20 end
    if level <= 5 then return 30 end
    if level <= 7 then return 40 end
    if level <= 10 then return 50 end
    if level <= 12 then return 60 end
    if level <= 16 then return 70 end
    if level <= 20 then return 80 end
    if level <= 24 then return 90 end
    if level <= 29 then return 100 end
    if level <= 36 then return 110 end
    if level <= 45 then return 120 end
    return 130
end

local function getRequiredDoctorsByLevel(level)
    if level <= 2 then return 1 end
    if level <= 4 then return 2 end
    if level <= 7 then return 3 end
    if level <= 10 then return 4 end
    if level <= 13 then return 5 end
    if level <= 17 then return 6 end
    if level <= 21 then return 7 end
    if level <= 26 then return 8 end
    if level <= 32 then return 9 end
    if level <= 40 then return 10 end
    if level <= 48 then return 11 end
    return 12
end

local function getRequiredRatingByLevel(level)
    if level <= 5 then return 1 end
    if level <= 10 then return 2 end
    if level <= 15 then return 3 end
    return 4
end

local REQUIRED_AUTO_SURGEONS = {
    [1]=0,[2]=1,[3]=1,[4]=2,[5]=2,[6]=3,[7]=3,[8]=3,[9]=4,[10]=4,
    [11]=4,[12]=5,[13]=5,[14]=5,[15]=6,[16]=6,[17]=6,[18]=6,[19]=6,[20]=7,
    [21]=7,[22]=7,[23]=7,[24]=8,[25]=8,[26]=8,[27]=8,[28]=8,[29]=8,[30]=9,
    [31]=9,[32]=9,[33]=9,[34]=9,[35]=9,[36]=9,[37]=9,[38]=9,[39]=10,[40]=10,
    [41]=10,[42]=10,[43]=10,[44]=10,[45]=10,[46]=10,[47]=11,[48]=11,[49]=11,[50]=11,[51]=11
}

local REQUIRED_OPERATING_TABLES = {
    [1]=0,[2]=1,[3]=2,[4]=3,[5]=4,[6]=5,[7]=5,[8]=6,[9]=7,[10]=7,
    [11]=8,[12]=9,[13]=9,[14]=10,[15]=10,[16]=10,[17]=11,[18]=11,[19]=12,[20]=12,
    [21]=12,[22]=13,[23]=13,[24]=14,[25]=14,[26]=14,[27]=14,[28]=15,[29]=15,[30]=15,
    [31]=15,[32]=16,[33]=16,[34]=16,[35]=16,[36]=17,[37]=17,[38]=17,[39]=17,[40]=17,
    [41]=18,[42]=18,[43]=18,[44]=18,[45]=18,[46]=18,[47]=19,[48]=19,[49]=19,[50]=19,[51]=19
}

local function getRequiredMaladiesByLevel(level)
    if level == 1 then
        return {
            { key = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE, count = 5, label = "Torn Muscle cured" },
            { key = MaladySystem.MALADY.GEMS_CUTS, count = 5, label = "Gem Cuts cured" }
        }
    end
    if level == 3 then
        return {
            { key = MaladySystem.MALADY.GRUMBLETEETH, count = 5, label = "Grumbleteeth cured" },
            { key = MaladySystem.MALADY.CHICKEN_FEET, count = 5, label = "Chicken Feet cured" }
        }
    end
    if level == 5 then
        return {
            { key = MaladySystem.MALADY.BROKEN_HEARTS, count = 5, label = "Broken Hearts cured" },
            { key = MaladySystem.MALADY.BRAINWORMS, count = 5, label = "Brainworms cured" }
        }
    end
    if level == 7 then
        return {
            { key = MaladySystem.MALADY.FATTY_LIVER, count = 5, label = "Fatty Liver cured" },
            { key = MaladySystem.MALADY.ECTO_BONES, count = 5, label = "Ecto-Bones cured" }
        }
    end
    if level == 9 then
        return {
            { key = MaladySystem.MALADY.MOLDY_GUTS, count = 5, label = "Moldy Guts cured" },
            { key = MaladySystem.MALADY.CHAOS_INFECTION, count = 5, label = "Chaos Infection cured" },
            { key = MaladySystem.MALADY.LUPUS, count = 5, label = "Lupus cured" }
        }
    end
    return {}
end

local LEVEL_UP_PERKS_BY_LEVEL = {
    [1] = {
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Duration: Between `24 hours, 5 mins`` and `26 hours``"
    },
    [2] = { "None" },
    [3] = {
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Spawn Delay: Between `222 hours, 55 mins`` and `21 day, 1 hour``",
        "Surg-E Patient Duration: Between `24 hours, 10 mins`` and `26 hours, 10 mins``",
        "All Auto Surgeon maladies require `21 less Surgical Scalpel``"
    },
    [4] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Operating Table Capacity: `2+1``",
        "Doctor Capacity: `2+1``",
        "Auto Surgeon can now cure `2Chaos Infection`` & `2Broken Hearts``"
    },
    [5] = {
        "Surg-E Patient Duration: Between `24 hours, 15 mins`` and `26 hours, 10 mins``"
    },
    [6] = {
        "Operating Table Capacity: `2+1``",
        "Auto Surgeon can now cure `2Brainworms`` & `2Moldy Guts``"
    },
    [7] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Operating Table Capacity: `2+1``",
        "Doctor Capacity: `2+1``",
        "Surg-E Patient Spawn Delay: Between `222 hours, 50 mins`` and `21 day, 50 mins``",
        "Surg-E Patient Duration: Between `24 hours, 20 mins`` and `26 hours, 20 mins``",
        "All Auto Surgeon maladies require `21 less Surgical Stitches``"
    },
    [8] = {
        "Auto Surgeon can now cure `2Fatty Liver``, `2Ecto-Bones`` & `2Lupus``"
    },
    [9] = {
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Duration: Between `24 hours, 25 mins`` and `26 hours, 20 mins``"
    },
    [10] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Operating Table Capacity: `2+1``",
        "Doctor Capacity: `2+1``"
    },
    [11] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 45 mins`` and `21 day, 50 mins``",
        "Surg-E Patient Duration: Between `24 hours, 30 mins`` and `26 hours, 30 mins``",
        "Ecto-Bones Auto Surgeon treatment requires `21 less Surgical Splint``"
    },
    [12] = {
        "Operating Table Capacity: `2+1``"
    },
    [13] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Doctor Capacity: `2+1``",
        "Surg-E Patient Duration: Between `24 hours, 35 mins`` and `26 hours, 30 mins``"
    },
    [14] = { "None" },
    [15] = {
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Spawn Delay: Between `222 hours, 40 mins`` and `21 day, 40 mins``",
        "Surg-E Patient Duration: Between `24 hours, 40 mins`` and `26 hours, 40 mins``"
    },
    [16] = { "None" },
    [17] = {
        "Operating Table Capacity: `2+1``",
        "Doctor Capacity: `2+1``",
        "Surg-E Patient Duration: Between `24 hours, 45 mins`` and `26 hours, 40 mins``"
    },
    [18] = {
        "Auto Surgeon Station Capacity: `2+1``"
    },
    [19] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 35 mins`` and `21 day, 40 mins``",
        "Surg-E Patient Duration: Between `24 hours, 50 mins`` and `26 hours, 50 mins``"
    },
    [20] = { "Operating Table Capacity: `2+1``" },
    [21] = {
        "Doctor Capacity: `2+1``",
        "Surg-E Patient Duration: Between `24 hours, 55 mins`` and `26 hours, 50 mins``"
    },
    [22] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Operating Table Capacity: `2+1``"
    },
    [23] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 30 mins`` and `21 day, 30 mins``",
        "Surg-E Patient Duration: Between `25 hours`` and `27 hours``"
    },
    [24] = { "None" },
    [25] = {
        "Surg-E Patient Duration: Between `25 hours, 5 mins`` and `27 hours``"
    },
    [26] = {
        "Operating Table Capacity: `2+1``",
        "Doctor Capacity: `2+1``"
    },
    [27] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 25 mins`` and `21 day, 30 mins``",
        "Surg-E Patient Duration: Between `25 hours, 10 mins`` and `27 hours, 10 mins``"
    },
    [28] = {
        "Auto Surgeon Station Capacity: `2+1``"
    },
    [29] = {
        "Surg-E Patient Duration: Between `25 hours, 15 mins`` and `27 hours, 10 mins``"
    },
    [30] = {
        "Operating Table Capacity: `2+1``"
    },
    [31] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 20 mins`` and `21 day, 20 mins``",
        "Surg-E Patient Duration: Between `25 hours, 20 mins`` and `27 hours, 20 mins``"
    },
    [32] = {
        "Doctor Capacity: `2+1``"
    },
    [33] = {
        "Surg-E Patient Duration: Between `25 hours, 25 mins`` and `27 hours, 20 mins``"
    },
    [34] = {
        "Operating Table Capacity: `2+1``"
    },
    [35] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 15 mins`` and `21 day, 20 mins``",
        "Surg-E Patient Duration: Between `25 hours, 30 mins`` and `27 hours, 30 mins``"
    },
    [36] = {
        "Auto Surgeon Station Capacity: `2+1``"
    },
    [37] = {
        "Surg-E Patient Duration: Between `25 hours, 35 mins`` and `27 hours, 30 mins``"
    },
    [38] = { "None" },
    [39] = {
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Spawn Delay: Between `222 hours, 10 mins`` and `21 day, 10 mins``",
        "Surg-E Patient Duration: Between `25 hours, 40 mins`` and `27 hours, 40 mins``"
    },
    [40] = {
        "Doctor Capacity: `2+1``"
    },
    [41] = {
        "Doctor Capacity: `2+1``",
        "Surg-E Patient Duration: Between `25 hours, 45 mins`` and `27 hours, 40 mins``"
    },
    [42] = { "None" },
    [43] = {
        "Surg-E Patient Spawn Delay: Between `222 hours, 5 mins`` and `21 day, 10 mins``",
        "Surg-E Patient Duration: Between `25 hours, 50 mins`` and `27 hours, 50 mins``"
    },
    [44] = { "None" },
    [45] = {
        "Auto Surgeon Station Capacity: `2+1``",
        "Operating Table Capacity: `2+1``",
        "Surg-E Patient Duration: Between `25 hours, 55 mins`` and `27 hours, 50 mins``"
    },
    [46] = { "None" },
    [47] = {
        "Surg-E Patient Spawn Delay: Between `222 hours`` and `21 day``",
        "Surg-E Patient Duration: Between `26 hours`` and `28 hours``"
    },
    [48] = {
        "Doctor Capacity: `2+1``"
    },
    [49] = {
        "Surg-E Patient Duration: Between `26 hours, 5 mins`` and `28 hours``"
    },
    [50] = { "None" },
    [51] = {
        "Surg-E Patient Spawn Delay: Between `221 hours, 55 mins`` and `21 day``",
        "Surg-E Patient Duration: Between `26 hours, 10 mins`` and `28 hours, 10 mins``"
    }
}

local LEVEL_UP_REWARDS_BY_LEVEL = {
    [1] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [2] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [3] = { "OPERATING_TABLE" },
    [4] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [5] = { "OPERATING_TABLE" },
    [6] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [7] = { "NONE" },
    [8] = { "OPERATING_TABLE" },
    [9] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [10] = { "NONE" },
    [11] = { "OPERATING_TABLE" },
    [12] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [13] = { "NONE" },
    [14] = { "OPERATING_TABLE" },
    [15] = { "AUTO_SURGEON" },
    [16] = { "NONE" },
    [17] = { "OPERATING_TABLE" },
    [18] = { "NONE" },
    [19] = { "OPERATING_TABLE" },
    [20] = { "AUTO_SURGEON" },
    [21] = { "NONE" },
    [22] = { "OPERATING_TABLE" },
    [23] = { "NONE" },
    [24] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [25] = { "NONE" },
    [26] = { "NONE" },
    [27] = { "NONE" },
    [28] = { "OPERATING_TABLE" },
    [29] = { "NONE" },
    [30] = { "AUTO_SURGEON" },
    [31] = { "NONE" },
    [32] = { "OPERATING_TABLE" },
    [33] = { "NONE" },
    [34] = { "NONE" },
    [35] = { "NONE" },
    [36] = { "OPERATING_TABLE" },
    [37] = { "NONE" },
    [38] = { "AUTO_SURGEON" },
    [39] = { "NONE" },
    [40] = { "NONE" },
    [41] = { "OPERATING_TABLE" },
    [42] = { "NONE" },
    [43] = { "NONE" },
    [44] = { "NONE" },
    [45] = { "NONE" },
    [46] = { "NONE" },
    [47] = { "OPERATING_TABLE", "AUTO_SURGEON" },
    [48] = { "NONE" },
    [49] = { "NONE" },
    [50] = { "NONE" },
    [51] = { "OPERATING_TABLE" }
}

local function cloneTextArray(arr)
    local out = {}
    if type(arr) ~= "table" then return out end
    for i = 1, #arr do out[i] = tostring(arr[i]) end
    return out
end

local function buildRewardsFromCodes(codes)
    local rewards = {}
    if type(codes) ~= "table" or #codes == 0 then
        rewards[1] = { label = "None", icon = RECEPTION_DESK_ID }
        return rewards
    end

    for i = 1, #codes do
        local code = tostring(codes[i])
        if code == "OPERATING_TABLE" then
            rewards[#rewards + 1] = { label = "Operating Table (x1)", icon = SURGBOT_ITEM_ID }
        elseif code == "AUTO_SURGEON" then
            rewards[#rewards + 1] = { label = "Auto Surgeon Station (x1)", icon = AUTO_SURGEON_ID }
        end
    end

    if #rewards == 0 then
        rewards[1] = { label = "None", icon = RECEPTION_DESK_ID }
    end
    return rewards
end

local HOSPITAL_LEVELS = {}
local LEVEL_UP_RULES = {}
for level = 1, MAX_HOSPITAL_LEVEL do
    local nextLevel = level < MAX_HOSPITAL_LEVEL and (level + 1) or nil
    HOSPITAL_LEVELS[level] = {
        next_level = nextLevel,
        required_surgeries = nextLevel and getRequiredCuresForNextLevel(nextLevel) or 0,
        upgrade_gems = 0,
        upgrade_wl = nextLevel and getUpgradeCostWLByLevel(level) or 0
    }

    LEVEL_UP_RULES[level] = {
        required_cures = nextLevel and getRequiredCuresForNextLevel(nextLevel) or 0,
        required_doctors = nextLevel and getRequiredDoctorsByLevel(level) or 0,
        required_rating = nextLevel and getRequiredRatingByLevel(level) or 0,
        required_auto_surgeons = nextLevel and (REQUIRED_AUTO_SURGEONS[level] or 0) or 0,
        required_operating_tables = nextLevel and (REQUIRED_OPERATING_TABLES[level] or 0) or 0,
        required_maladies = getRequiredMaladiesByLevel(level),
        perks = cloneTextArray(LEVEL_UP_PERKS_BY_LEVEL[level] or { "None" }),
        rewards = buildRewardsFromCodes(LEVEL_UP_REWARDS_BY_LEVEL[level])
    }
end

local MALADY_UNLOCK_LEVEL = {
    TORN_PUNCHING_MUSCLE = 1,
    GEMS_CUTS            = 1,
    CHICKEN_FEET         = 3,
    GRUMBLETEETH         = 3,
    CHAOS_INFECTION      = 4,
    BROKEN_HEARTS        = 4,
    BRAINWORMS           = 6,
    MOLDY_GUTS           = 6,
    FATTY_LIVER          = 8,
    ECTO_BONES           = 8,
    LUPUS                = 8,
    AUTOMATION_CURSE     = 999
}

-- Icon per malady di owner panel
-- Vile Vial maladies pakai icon vial mereka sendiri
-- RNG maladies pakai placeholder (ganti iconID sesuai kebutuhan)
local MALADY_ICON = {
    CHICKEN_FEET         = 2,
    GRUMBLETEETH         = 2,
    TORN_PUNCHING_MUSCLE = 2,
    GEMS_CUTS            = 2,
    AUTOMATION_CURSE     = 20704,
    BROKEN_HEARTS        = 2,
    CHAOS_INFECTION      = 8538,
    LUPUS                = 8544,
    BRAINWORMS           = 8542,
    MOLDY_GUTS           = 8540,
    ECTO_BONES           = 8546,
    FATTY_LIVER          = 8548,
}

local MALADY_ICON_VISUAL = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = "image:game/tiles_page16.rttex;frame:8,22;frameSize:32;",
    [MaladySystem.MALADY.GEMS_CUTS] = "image:game/tiles_page16.rttex;frame:22,26;frameSize:32;",
    [MaladySystem.MALADY.CHICKEN_FEET] = "image:game/tiles_page2.rttex;frame:20,0;frameSize:32;",
    [MaladySystem.MALADY.GRUMBLETEETH] = "image:game/tiles_page14.rttex;frame:30,27;frameSize:32;",
    [MaladySystem.MALADY.BRAINWORMS] = "image:game/tiles_page14.rttex;frame:29,0;frameSize:32;",
    [MaladySystem.MALADY.CHAOS_INFECTION] = "image:game/tiles_page14.rttex;frame:31,1;frameSize:32;",
    [MaladySystem.MALADY.LUPUS] = "image:game/tiles_page14.rttex;frame:31,2;frameSize:32;",
    [MaladySystem.MALADY.MOLDY_GUTS] = "image:game/tiles_page14.rttex;frame:31,3;frameSize:32;",
    [MaladySystem.MALADY.ECTO_BONES] = "image:game/tiles_page14.rttex;frame:31,4;frameSize:32;",
    [MaladySystem.MALADY.FATTY_LIVER] = "image:game/tiles_page14.rttex;frame:31,5;frameSize:32;",
    [MaladySystem.MALADY.BROKEN_HEARTS] = "image:game/player_cosmetics1_icon.rttex;frame:31,31;frameSize:32;"
}

-- Urutan tampil di UI: vile vial dulu, RNG di bawahnya
local MALADY_UI_VIAL = {
    MaladySystem.MALADY.CHAOS_INFECTION,
    MaladySystem.MALADY.LUPUS,
    MaladySystem.MALADY.BRAINWORMS,
    MaladySystem.MALADY.MOLDY_GUTS,
    MaladySystem.MALADY.ECTO_BONES,
    MaladySystem.MALADY.FATTY_LIVER,
}

local MALADY_UI_RNG = {
    MaladySystem.MALADY.CHICKEN_FEET,
    MaladySystem.MALADY.GRUMBLETEETH,
    MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    MaladySystem.MALADY.GEMS_CUTS,
    MaladySystem.MALADY.BROKEN_HEARTS,
    MaladySystem.MALADY.AUTOMATION_CURSE,
}

-- Auto Surgeon tile-extra selectedIllness mapping (Growtopia client visual IDs).
-- Note: On this runtime/client build, Torn and Gems visual IDs are reversed
-- compared to some public examples.
local AUTO_SURGEON_ILLNESS_VISUAL_ID = {
    [MaladySystem.MALADY.TORN_PUNCHING_MUSCLE] = 21,
    [MaladySystem.MALADY.GEMS_CUTS] = 20,
    [MaladySystem.MALADY.GRUMBLETEETH] = 22,
    [MaladySystem.MALADY.CHICKEN_FEET] = 23,
    [MaladySystem.MALADY.BROKEN_HEARTS] = 24,
    [MaladySystem.MALADY.AUTOMATION_CURSE] = 25,
    -- Map Vile Vial maladies into the closest supported visual buckets
    -- so selected illness no longer falls back to Gem Cuts visual.
    [MaladySystem.MALADY.CHAOS_INFECTION] = 26,
    [MaladySystem.MALADY.LUPUS] = 27,
    [MaladySystem.MALADY.BRAINWORMS] = 28,
    [MaladySystem.MALADY.MOLDY_GUTS] = 29,
    [MaladySystem.MALADY.ECTO_BONES] = 30,
    [MaladySystem.MALADY.FATTY_LIVER] = 31
}

local function resolveAutoSurgeonIllnessVisualID(maladyType)
    local key = tostring(maladyType or "")
    local mapped = tonumber(AUTO_SURGEON_ILLNESS_VISUAL_ID[key])
    if mapped then return mapped end

    -- Defensive fallback for any custom malady string variants.
    local upper = string.upper(key)
    if upper:find("AUTOMATION", 1, true) or upper:find("CHAOS", 1, true) then return 25 end
    if upper:find("BROKEN", 1, true) or upper:find("LUPUS", 1, true) then return 24 end
    if upper:find("CHICKEN", 1, true) or upper:find("FATTY", 1, true) then return 23 end
    if upper:find("GRUMBLE", 1, true) or upper:find("BRAIN", 1, true) then return 22 end
    if upper:find("GEMS", 1, true) or upper:find("MOLD", 1, true) then return 20 end
    if upper:find("TORN", 1, true) or upper:find("ECTO", 1, true) then return 21 end

    return 20
end

local ALL_SURGICAL_TOOLS = {
    1258, 1260, 1262, 1264, 1266, 1268, 1270,
    4308, 4310, 4312, 4314, 4316, 4318
}

local TOOL_REQUIREMENT = {}
for _, maladyType in pairs(MaladySystem.MALADY) do
    TOOL_REQUIREMENT[maladyType] = {}
    for _, toolID in ipairs(ALL_SURGICAL_TOOLS) do
        TOOL_REQUIREMENT[maladyType][toolID] = 1
    end
end

local AUTO_SURGEON_MALADY_ORDER = {
    MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    MaladySystem.MALADY.GEMS_CUTS,
    MaladySystem.MALADY.CHICKEN_FEET,
    MaladySystem.MALADY.GRUMBLETEETH,
    MaladySystem.MALADY.BROKEN_HEARTS,
    MaladySystem.MALADY.CHAOS_INFECTION,
    MaladySystem.MALADY.BRAINWORMS,
    MaladySystem.MALADY.MOLDY_GUTS,
    MaladySystem.MALADY.ECTO_BONES,
    MaladySystem.MALADY.FATTY_LIVER,
    MaladySystem.MALADY.LUPUS,
    MaladySystem.MALADY.AUTOMATION_CURSE
}

local function getUnlockedAutoSurgeonMaladies(level)
    local hospitalLevel = math.max(1, math.floor(tonumber(level) or 1))
    local result = {}
    for i = 1, #AUTO_SURGEON_MALADY_ORDER do
        local maladyType = AUTO_SURGEON_MALADY_ORDER[i]
        local reqLevel = tonumber(MALADY_UNLOCK_LEVEL[maladyType]) or 999
        if hospitalLevel >= reqLevel then
            result[#result + 1] = maladyType
        end
    end
    return result
end

local DLG_RECEPTION      = "reception_desk_panel_v5m"
local DLG_MANAGE_DOCTORS = "hosp_manage_doctors_v5m"
local DLG_OWNER          = "autosurgeon_owner_panel_v5m"
local DLG_STORAGE        = "autosurgeon_storage_panel_v5m"
local DLG_PLAYER         = "autosurgeon_player_panel_v5m"

local BTN_BIND_PREFIX          = "v5m_bind_"
local BTN_TOOL_PREFIX          = "v5m_tool_"
local BTN_WITHDRAW_TOOL_PREFIX = "v5m_withdraw_tool_"
local BTN_ADD_DOCTOR_PREFIX    = "v5m_add_dr_"
local BTN_REMOVE_DOCTOR_PREFIX = "v5m_rm_dr_"

local BTN_MANAGE_DOCTORS     = "v5m_manage_doctors"
local BTN_UPGRADE_HOSPITAL   = "v5m_upgrade_hospital"
local BTN_LEADERBOARD        = "v5m_leaderboard"
local BTN_CLOSE_RECEPTION    = "v5m_close_reception"
local BTN_DEV_RESET_HOSPITAL = "v5m_dev_reset_hospital"
local BTN_DOCTORS_BACK       = "v5m_doctors_back"

local BTN_OPEN_STORAGE  = "v5m_open_storage_panel"
local BTN_STORAGE_BACK  = "v5m_storage_back"
local BTN_WITHDRAW_WL   = "v5m_withdraw_station_wl"
local BTN_CLOSE_OWNER   = "v5m_close_station_owner"
local BTN_CURE_MALADY   = "v5m_cure_malady_station"

local BTN_SHOW_STATS    = "receptionBtn_showHospitalStats"
local BTN_LEVEL_UP      = "receptionBtn_levelUp"
local BTN_BACK_STATS    = "statsBtn_back"
local BTN_LEVEL_UP_NEW_CONFIRM = "levelUpBtn_confirm"
local BTN_LEVEL_UP_BACK = "levelUpBtn_back"

local HOSPITAL_STATS_MALADY_ROWS = {
    { label = "Brainworms cured", key = MaladySystem.MALADY.BRAINWORMS, icon = "image:game/tiles_page14.rttex;frame:29,0;frameSize:32;" },
    { label = "Grumbleteeth cured", key = MaladySystem.MALADY.GRUMBLETEETH, icon = "image:game/tiles_page14.rttex;frame:30,27;frameSize:32;" },
    { label = "Chicken Feet cured", key = MaladySystem.MALADY.CHICKEN_FEET, icon = "image:game/tiles_page2.rttex;frame:20,0;frameSize:32;" },
    { label = "Gem Cuts cured", key = MaladySystem.MALADY.GEMS_CUTS, icon = "image:game/tiles_page16.rttex;frame:22,26;frameSize:32;" },
    { label = "Torn Muscle cured", key = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE, icon = "image:game/tiles_page16.rttex;frame:8,22;frameSize:32;" },
    { label = "Chaos Infection cured", key = MaladySystem.MALADY.CHAOS_INFECTION, icon = "image:game/tiles_page14.rttex;frame:31,1;frameSize:32;" },
    { label = "Lupus cured", key = MaladySystem.MALADY.LUPUS, icon = "image:game/tiles_page14.rttex;frame:31,2;frameSize:32;" },
    { label = "Moldy Guts cured", key = MaladySystem.MALADY.MOLDY_GUTS, icon = "image:game/tiles_page14.rttex;frame:31,3;frameSize:32;" },
    { label = "Ecto-Bones cured", key = MaladySystem.MALADY.ECTO_BONES, icon = "image:game/tiles_page14.rttex;frame:31,4;frameSize:32;" },
    { label = "Fatty Liver cured", key = MaladySystem.MALADY.FATTY_LIVER, icon = "image:game/tiles_page14.rttex;frame:31,5;frameSize:32;" },
    { label = "Broken Hearts cured", key = MaladySystem.MALADY.BROKEN_HEARTS, icon = "image:game/player_cosmetics1_icon.rttex;frame:31,31;frameSize:32;" },
    { label = "Automation Curse cured", key = MaladySystem.MALADY.AUTOMATION_CURSE, icon = "image:game/tiles_page1.rttex;frame:20,0;frameSize:32;" },
}

-- Optional mapping for non-MaladySystem surgery cases.
-- Fill with real rewardID values if you want those maladies to be auto-counted.
local SURGERY_REWARD_MALADY_KEY = {
    -- [1234] = MaladySystem.MALADY.SOME_MALADY,
}

-- =======================================================
-- STORAGE LAYER  (JSON - hospital_data.json)
-- =======================================================

local HOSPITAL_JSON = "hospital_data.json"

local function readHospitalDB()
    if not file.exists(HOSPITAL_JSON) then return { worlds = {}, stations = {} } end
    local data = json.decode(file.read(HOSPITAL_JSON)) or {}
    if type(data.worlds)   ~= "table" then data.worlds   = {} end
    if type(data.stations) ~= "table" then data.stations = {} end
    return data
end

local function writeHospitalDB(data)
    file.write(HOSPITAL_JSON, json.encode(data))
end

local function stationKey(worldName, x, y)
    return tostring(worldName) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function normalizeHospitalState(state)
    if type(state.doctors) ~= "table" then state.doctors = {} end
    if type(state.doctor_stats) ~= "table" then state.doctor_stats = {} end
    if type(state.treatment_stats) ~= "table" then state.treatment_stats = {} end
    if type(state.cured_by_malady) ~= "table" then state.cured_by_malady = {} end
    if type(state.operating_tables) ~= "table" then state.operating_tables = {} end
    state.rating = tonumber(state.rating) or 0
    state.rating_counter = tonumber(state.rating_counter) or 0

    state.treatment_stats.total = tonumber(state.treatment_stats.total) or 0
    state.treatment_stats.successful = tonumber(state.treatment_stats.successful) or 0
    state.treatment_stats.failed = tonumber(state.treatment_stats.failed) or 0
    state.rating = math.max(0, math.min(MAX_HOSPITAL_RATING, math.floor(state.rating)))
    state.rating_counter = math.max(0, math.min(RATING_STEP_CURES, math.floor(state.rating_counter)))

    if state.rating >= MAX_HOSPITAL_RATING then
        state.rating_counter = RATING_STEP_CURES
    end

    for _, maladyType in pairs(MaladySystem.MALADY) do
        state.cured_by_malady[maladyType] = tonumber(state.cured_by_malady[maladyType]) or 0
    end

    for k, row in pairs(state.operating_tables) do
        if type(k) ~= "string" or type(row) ~= "table" then
            state.operating_tables[k] = nil
        else
            row.status = tostring(row.status or "idle")
            row.spawned_at = tonumber(row.spawned_at) or 0
            row.expire_at = tonumber(row.expire_at) or 0
            row.next_spawn_at = tonumber(row.next_spawn_at) or 0
            row.npc_name = tostring(row.npc_name or "")
        end
    end

    return state
end

-- Hospital world state
local function loadHospital(worldName)
    local db = readHospitalDB()
    local w = db.worlds[tostring(worldName)]
    if type(w) == "table" and w.level then
        return normalizeHospitalState(w)
    end
    return normalizeHospitalState({
        level = 1,
        progress = 0,
        rating = 0,
        rating_counter = 0,
        doctors = {},
        doctor_stats = {},
        treatment_stats = { total = 0, successful = 0, failed = 0 },
        cured_by_malady = {},
        operating_tables = {}
    })
end

local function saveHospital(worldName, data)
    local db = readHospitalDB()
    local normalized = normalizeHospitalState(data)
    db.worlds[tostring(worldName)] = {
        level          = tonumber(normalized.level) or 1,
        progress       = tonumber(normalized.progress) or 0,
        rating         = tonumber(normalized.rating) or 0,
        rating_counter = tonumber(normalized.rating_counter) or 0,
        doctors        = normalized.doctors,
        doctor_stats   = normalized.doctor_stats,
        treatment_stats = normalized.treatment_stats,
        cured_by_malady = normalized.cured_by_malady,
        operating_tables = normalized.operating_tables,
    }
    writeHospitalDB(db)
end

-- Station record
local function getStation(worldName, x, y)
    local db = readHospitalDB()
    local s = db.stations[stationKey(worldName, x, y)]
    if type(s) == "table" and s.price_wl ~= nil then
        if type(s.storage) ~= "table" then s.storage = {} end
        return s
    end
    return nil
end

local function saveStation(worldName, x, y, data)
    local db = readHospitalDB()
    db.stations[stationKey(worldName, x, y)] = {
        malady_type = tostring(data.malady_type or ""),
        enabled     = tonumber(data.enabled) or 0,
        price_wl    = tonumber(data.price_wl) or MIN_CURE_PRICE_WL,
        earned_wl   = tonumber(data.earned_wl) or 0,
        storage     = type(data.storage) == "table" and data.storage or {},
    }
    writeHospitalDB(db)
end

local function deleteStationData(worldName, x, y)
    local db = readHospitalDB()
    db.stations[stationKey(worldName, x, y)] = nil
    writeHospitalDB(db)
end

-- =======================================================
-- HELPERS
-- =======================================================

local function getUserID(player)
    if type(player) ~= "userdata" then return 0 end
    return tonumber(player:getUserID()) or 0
end

local function getWorldName(world, player)
    if type(player) == "userdata" and player.getWorldName then
        return tostring(player:getWorldName() or "")
    end
    if type(world) ~= "userdata" then return "" end
    return tostring(world:getName() or "")
end

local function isWorldOwner(world, player)
    if type(world) ~= "userdata" then return false end
    if type(player) ~= "userdata" then return false end
    return world:hasAccess(player) == true
end

local function safeHasRole(player, role)
    if type(player) ~= "userdata" then return false end
    return player:hasRole(role) == true
end

local function safeBubble(player, text)
    if player and player.onTalkBubble and player.getNetID then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function safeConsole(player, text)
    if player and player.onConsoleMessage then
        player:onConsoleMessage(text)
    end
end

local function getPlayerItemAmount(player, itemID)
    if player.getItemAmount then
        return tonumber(player:getItemAmount(itemID)) or 0
    end
    if player.getInventoryItems then
        local items = player:getInventoryItems()
        if type(items) == "table" then
            for _, inv in pairs(items) do
                if inv and inv.getItemID and inv:getItemID() == itemID then
                    return tonumber(inv:getItemCount()) or 0
                end
            end
        end
    end
    if player.getItemCount then
        return tonumber(player:getItemCount(itemID)) or 0
    end
    return 0
end

local function getTotalWLEquivalent(player)
    local wl = getPlayerItemAmount(player, WORLD_LOCK_ID)
    local dl = getPlayerItemAmount(player, DIAMOND_LOCK_ID)
    local bgl = getPlayerItemAmount(player, BGL_ID)
    return math.max(0, wl + (dl * 100) + (bgl * 10000))
end

local function rebalanceLocksByWLEquivalent(player, targetTotalWL)
    local total = math.max(0, math.floor(tonumber(targetTotalWL) or 0))
    local targetBGL = 0
    local targetDL = 0
    local targetWL = total

    if BGL_ID > 0 then
        targetBGL = math.floor(targetWL / 10000)
        targetWL = targetWL - (targetBGL * 10000)
    end
    targetDL = math.floor(targetWL / 100)
    targetWL = targetWL - (targetDL * 100)

    local currentBGL = BGL_ID > 0 and getPlayerItemAmount(player, BGL_ID) or 0
    local currentDL = getPlayerItemAmount(player, DIAMOND_LOCK_ID)
    local currentWL = getPlayerItemAmount(player, WORLD_LOCK_ID)

    local deltaBGL = targetBGL - currentBGL
    local deltaDL = targetDL - currentDL
    local deltaWL = targetWL - currentWL

    if BGL_ID > 0 and deltaBGL ~= 0 then player:changeItem(BGL_ID, deltaBGL, 0) end
    if deltaDL ~= 0 then player:changeItem(DIAMOND_LOCK_ID, deltaDL, 0) end
    if deltaWL ~= 0 then player:changeItem(WORLD_LOCK_ID, deltaWL, 0) end
end

local function deductWLEquivalent(player, amountWL)
    local need = math.max(0, math.floor(tonumber(amountWL) or 0))
    if need <= 0 then return true end
    local currentTotal = getTotalWLEquivalent(player)
    if currentTotal < need then return false end

    local remainingTotal = currentTotal - need
    rebalanceLocksByWLEquivalent(player, remainingTotal)
    return getTotalWLEquivalent(player) == remainingTotal
end

local function safeItemID(value)
    if type(value) == "number" then return math.floor(value) end
    if type(value) == "string" then
        local digits = value:match("%-?%d+")
        if digits then return tonumber(digits) or 0 end
    end
    return 0
end

local function extractButtonSuffix(buttonName, prefix)
    if type(buttonName) ~= "string" then return "" end
    local result = buttonName:gsub("^" .. prefix, "")
    return result  -- discard gsub count to prevent tonumber(str, base) error
end

local function getOwnerNetGain(priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local tax = math.max(1, math.ceil(safePrice * CURE_TAX_RATE))
    local gain = safePrice - tax
    return gain < 0 and 0 or gain
end

local function getWorldTaxWL(priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    return math.max(1, math.ceil(safePrice * CURE_TAX_RATE))
end

-- =======================================================
-- WORLD TILE HELPERS
-- =======================================================

local function getAllWorldTiles(world)
    if world.getTiles then
        local tiles = world:getTiles()
        if type(tiles) == "table" then return tiles end
    end
    local sizeX, sizeY
    if world.getSizeX then sizeX = tonumber(world:getSizeX())
    elseif world.getWorldSizeX then sizeX = tonumber(world:getWorldSizeX()) end
    if world.getSizeY then sizeY = tonumber(world:getSizeY())
    elseif world.getWorldSizeY then sizeY = tonumber(world:getWorldSizeY()) end
    local result = {}
    if sizeX and sizeY then
        for x = 0, sizeX - 1 do
            for y = 0, sizeY - 1 do
                local tile = world:getTile(x, y)
                if tile then result[#result + 1] = tile end
            end
        end
    end
    return result
end

local function countReceptionDesks(world)
    local count = 0
    for _, tile in pairs(getAllWorldTiles(world)) do
        if tile and tile:getTileID() == RECEPTION_DESK_ID then count = count + 1 end
    end
    return count
end

local function countAutoSurgeons(world)
    local count = 0
    for _, tile in pairs(getAllWorldTiles(world)) do
        if tile and tile:getTileID() == AUTO_SURGEON_ID then count = count + 1 end
    end
    return count
end

local function countOperatingTables(world)
    local count = 0
    for _, tile in pairs(getAllWorldTiles(world)) do
        local fg = tile and (tonumber(tile:getTileID()) or 0) or 0
        if fg == OPERATING_TABLE_ID or fg == SURGBOT_ITEM_ID or fg == INSURGERY_ITEM_ID then
            count = count + 1
        end
    end
    return count
end

-- OperatingTable wrappers — resolved lazily via _G.OperatingTable (loaded after hospital)
local function getOperatingTableCapacityByLevel(level)
    return _G.OperatingTable.getOperatingTableCapacityByLevel(level)
end

local function getOperatingPatientDurationByLevel(level)
    return _G.OperatingTable.getOperatingPatientDurationByLevel(level)
end

local function getOperatingRowKey(x, y)
    return _G.OperatingTable.getOperatingRowKey(x, y)
end

local function getSurgBotNameForTable(x, y)
    return "Surg-Bot " .. tostring(math.floor(tonumber(x) or 0)) .. ":" .. tostring(math.floor(tonumber(y) or 0))
end


local function findOperatingTileByPlayer(world, target)
    if type(world) ~= "userdata" or type(target) ~= "userdata" then return nil end
    local tx = math.floor((tonumber(target:getPosX()) or 0) / 32)
    local ty = math.floor((tonumber(target:getPosY()) or 0) / 32)
    local tile = world:getTile(tx, ty)
    if not tile or tile:getTileID() ~= OPERATING_TABLE_ID then return nil end
    return tile
end


local function resolveOperatingTableSurgery(world, surgeon, targetPlayer)
    return _G.OperatingTable.resolveOperatingTableSurgery(world, surgeon, targetPlayer)
end

local function hasHospitalInWorld(world)
    return countReceptionDesks(world) > 0 or countAutoSurgeons(world) > 0
end

-- =======================================================
-- HOSPITAL WORLD STATE
-- =======================================================

local function getHospitalState(worldName)
    return loadHospital(worldName)
end

local function setHospitalState(worldName, level, progress)
    local state = loadHospital(worldName)
    state.level    = tonumber(level) or 1
    state.progress = tonumber(progress) or 0
    saveHospital(worldName, state)
end

local function resetHospitalState(worldName)
    local db = readHospitalDB()
    db.worlds[tostring(worldName)] = nil
    local prefix = tostring(worldName) .. ":"
    for k in pairs(db.stations) do
        if k:sub(1, #prefix) == prefix then db.stations[k] = nil end
    end
    writeHospitalDB(db)
end

-- isDoctor checks registered doctors only (not owner - owner is handled separately)
local function isDoctor(worldName, userID)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    return doctors["u" .. tostring(userID)] ~= nil
end

-- isEffectiveDoctor = owner OR registered doctor
local function isEffectiveDoctor(world, worldName, userID, player)
    if player and isWorldOwner(world, player) then return true end
    return _G.ReceptionDesk.isDoctor(worldName, userID)
end

-- doctors stored as ["u{uid}"] = displayName
local function addDoctor(worldName, userID, displayName)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = tostring(displayName or "Unknown")
    saveHospital(worldName, state)
end

local function removeDoctor(worldName, userID)
    local state = loadHospital(worldName)
    state.doctors = state.doctors or {}
    state.doctors["u" .. tostring(userID)] = nil
    saveHospital(worldName, state)
end

local function countDoctors(worldName)
    local state = loadHospital(worldName)
    local doctors = state.doctors or {}
    local n = 0
    for _ in pairs(doctors) do n = n + 1 end
    return n
end

local function addDoctorSurgery(worldName, userID)
    local state = loadHospital(worldName)
    local stats = state.doctor_stats or {}
    local key = "u" .. tostring(userID)
    stats[key] = (tonumber(stats[key]) or 0) + 1
    state.doctor_stats = stats
    saveHospital(worldName, state)
end

local function recordHospitalTreatment(worldName, maladyType, isSuccess)
    local state = loadHospital(worldName)
    local stats = state.treatment_stats or { total = 0, successful = 0, failed = 0 }
    local rating = tonumber(state.rating) or 0
    local ratingCounter = tonumber(state.rating_counter) or 0

    stats.total = (tonumber(stats.total) or 0) + 1
    if isSuccess then
        stats.successful = (tonumber(stats.successful) or 0) + 1
        if maladyType then
            state.cured_by_malady[maladyType] = (tonumber(state.cured_by_malady[maladyType]) or 0) + 1
        end

        if rating < MAX_HOSPITAL_RATING then
            ratingCounter = ratingCounter + 1
            if ratingCounter >= RATING_STEP_CURES then
                rating = math.min(MAX_HOSPITAL_RATING, rating + 1)
                ratingCounter = rating >= MAX_HOSPITAL_RATING and RATING_STEP_CURES or 0
            end
        else
            ratingCounter = RATING_STEP_CURES
        end
    else
        stats.failed = (tonumber(stats.failed) or 0) + 1
        rating = math.max(0, rating - 1)
        ratingCounter = 0
    end

    state.rating = rating
    state.rating_counter = ratingCounter
    state.treatment_stats = stats
    saveHospital(worldName, state)
end

local function getHospitalTreatmentStats(worldName)
    local state = loadHospital(worldName)
    local stats = state.treatment_stats or {}
    return {
        total = tonumber(stats.total) or 0,
        successful = tonumber(stats.successful) or 0,
        failed = tonumber(stats.failed) or 0,
        cured_by_malady = state.cured_by_malady or {}
    }
end

local function getDoctorLeaderboard(worldName)
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

local function getHospitalProgressText(level, progress)
    local levelData = HOSPITAL_LEVELS[level]
    if not levelData or not levelData.next_level then return "MAX LEVEL" end
    return tostring(progress) .. "/" .. tostring(levelData.required_surgeries)
end

local function getHospitalRating(worldName)
    local state = getHospitalState(worldName)
    return math.max(0, math.min(MAX_HOSPITAL_RATING, tonumber(state.rating) or 0))
end

local function getHospitalRatingCounter(worldName)
    local state = getHospitalState(worldName)
    local rating = math.max(0, math.min(MAX_HOSPITAL_RATING, tonumber(state.rating) or 0))
    local counter = math.max(0, tonumber(state.rating_counter) or 0)
    if rating >= MAX_HOSPITAL_RATING then
        counter = RATING_STEP_CURES
    else
        counter = math.min(RATING_STEP_CURES, counter)
    end
    return {
        rating = rating,
        counter = counter,
        need = rating >= MAX_HOSPITAL_RATING and 0 or (RATING_STEP_CURES - counter)
    }
end

local function getRequirementColor(current, required)
    local safeCurrent = math.max(0, math.floor(tonumber(current) or 0))
    local safeRequired = math.max(0, math.floor(tonumber(required) or 0))
    if safeRequired <= 0 then return "`2" end
    if safeCurrent >= safeRequired then return "`2" end
    if (safeCurrent * 2) >= safeRequired then return "`9" end
    return "`4"
end

local function formatRequirementProgress(current, required)
    local safeCurrent = math.max(0, math.floor(tonumber(current) or 0))
    local safeRequired = math.max(0, math.floor(tonumber(required) or 0))
    return getRequirementColor(safeCurrent, safeRequired) .. tostring(safeCurrent) .. "/" .. tostring(safeRequired) .. "``"
end

local function getRequirementIconID(current, required)
    local safeCurrent = math.max(0, math.floor(tonumber(current) or 0))
    local safeRequired = math.max(0, math.floor(tonumber(required) or 0))
    if safeRequired <= 0 or safeCurrent >= safeRequired then
        return 6292 -- completed/max requirement
    end
    return 2946 -- requirement in progress
end

local function isDialogBackAction(buttonClicked, explicitButtonID)
    local btn = string.lower(tostring(buttonClicked or ""))
    local explicit = string.lower(tostring(explicitButtonID or ""))

    if explicit ~= "" and btn == explicit then return true end
    if btn == "back" or btn == "close" or btn == "cancel" or btn == "backbtn" then return true end
    if btn:find("back", 1, true) ~= nil then return true end
    return false
end

local function isDialogButtonPressed(data, buttonID)
    if type(data) ~= "table" then return false end
    local target = tostring(buttonID or "")
    if target == "" then return false end

    local clicked = tostring(data["buttonClicked"] or "")
    if clicked == target then return true end

    local raw = data[target]
    if raw == nil then return false end
    local str = string.lower(tostring(raw))
    if str == "" or str == "0" or str == "false" then return false end
    return true
end

local function resolveDialogContext(cbWorld, cbPlayer, fallbackWorld, fallbackPlayer)
    local w = cbWorld
    local p = cbPlayer
    if type(w) ~= "userdata" then w = fallbackWorld end
    if type(p) ~= "userdata" then p = fallbackPlayer end
    return w, p
end

local function getLevelUpSnapshot(world, worldName, state, playerWL)
    local treatmentStats = getHospitalTreatmentStats(worldName)
    return {
        cures = tonumber(state.progress) or 0,
        doctors = _G.ReceptionDesk.countDoctors(worldName),
        rating = getHospitalRating(worldName),
        autoSurgeons = countAutoSurgeons(world),
        operatingTables = countOperatingTables(world),
        playerWL = math.max(0, math.floor(tonumber(playerWL) or 0)),
        curedByMalady = treatmentStats.cured_by_malady or {}
    }
end

local function isLevelUpReadyForRule(levelRule, snapshot, upgradeCost)
    if not levelRule or not snapshot then return false end
    if snapshot.playerWL < (tonumber(upgradeCost) or 0) then return false end
    if snapshot.cures < (tonumber(levelRule.required_cures) or 0) then return false end
    if snapshot.doctors < (tonumber(levelRule.required_doctors) or 0) then return false end
    if snapshot.rating < (tonumber(levelRule.required_rating) or 0) then return false end
    if snapshot.autoSurgeons < (tonumber(levelRule.required_auto_surgeons) or 0) then return false end
    if snapshot.operatingTables < (tonumber(levelRule.required_operating_tables) or 0) then return false end

    local reqMaladies = levelRule.required_maladies or {}
    for i = 1, #reqMaladies do
        local row = reqMaladies[i]
        local current = tonumber(snapshot.curedByMalady[row.key]) or 0
        if current < (tonumber(row.count) or 0) then
            return false
        end
    end

    return true
end

local function addHospitalProgressIfPossible(worldName, amount)
    local state = loadHospital(worldName)
    local level     = tonumber(state.level) or 1
    local progress  = tonumber(state.progress) or 0
    local levelData = HOSPITAL_LEVELS[level]
    if not levelData or not levelData.next_level then return false end
    if progress >= tonumber(levelData.required_surgeries) then return false end
    local nextProgress = math.min(
        tonumber(levelData.required_surgeries),
        progress + math.max(0, math.floor(tonumber(amount) or 0))
    )
    state.progress = nextProgress
    saveHospital(worldName, state)
    return true
end

-- =======================================================
-- STATION STATE
-- =======================================================

local function ensureStation(worldName, x, y)
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

local function setStationMalady(worldName, x, y, maladyType)
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    station.malady_type = tostring(maladyType)
    saveStation(worldName, x, y, station)
end

local function setStationEnabled(worldName, x, y, enabled)
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    station.enabled = enabled and 1 or 0
    saveStation(worldName, x, y, station)
end

local function setStationPrice(worldName, x, y, priceWL)
    local safePrice = math.max(MIN_CURE_PRICE_WL, math.floor(tonumber(priceWL) or MIN_CURE_PRICE_WL))
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    station.price_wl = safePrice
    saveStation(worldName, x, y, station)
end

local function getStationToolAmount(worldName, x, y, toolID)
    local station = getStation(worldName, x, y)
    if not station then return 0 end
    local storage = station.storage or {}
    return tonumber(storage["t" .. tostring(toolID)]) or 0
end

local function addStationTool(worldName, x, y, toolID, amount)
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.min(MAX_TOOL_STORAGE, current + math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function removeStationTool(worldName, x, y, toolID, amount)
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    local current = tonumber(storage["t" .. tostring(toolID)]) or 0
    storage["t" .. tostring(toolID)] = math.max(0, current - math.max(0, math.floor(tonumber(amount) or 0)))
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function stationHasEnoughTools(worldName, x, y, maladyType)
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

local function getStationPossibleCures(worldName, x, y, maladyType)
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

local function consumeStationTools(worldName, x, y, maladyType)
    local req = TOOL_REQUIREMENT[maladyType]
    if not req then return end
    local station = _G.AutoSurgeon.ensureStation(worldName, x, y)
    local storage = station.storage or {}
    for toolID, need in pairs(req) do
        local current = tonumber(storage["t" .. tostring(toolID)]) or 0
        storage["t" .. tostring(toolID)] = math.max(0, current - need)
    end
    station.storage = storage
    saveStation(worldName, x, y, station)
end

local function addStationEarnedWL(worldName, x, y, amount)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = (tonumber(station.earned_wl) or 0) + math.max(0, math.floor(tonumber(amount) or 0))
    saveStation(worldName, x, y, station)
end

local function clearStationEarnedWL(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    station.earned_wl = 0
    saveStation(worldName, x, y, station)
end

local function deleteStation(worldName, x, y)
    deleteStationData(worldName, x, y)
end

local function countStationRowsInWorld(worldName)
    local db = readHospitalDB()
    local prefix = tostring(worldName) .. ":"
    local n = 0
    for k in pairs(db.stations) do
        if k:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end

local function refreshStationOperationalState(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return end
    local maladyType = tostring(station.malady_type or "")
    if maladyType == "" then return end
    if not _G.AutoSurgeon.stationHasEnoughTools(worldName, x, y, maladyType) then
        _G.AutoSurgeon.setStationEnabled(worldName, x, y, false)
    end
end

local function getToolStorageLabel(worldName, x, y, toolID)
    return tostring(_G.AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)) .. "/1k"
end

local function hasAnyStationStock(worldName, x, y)
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

local function canBreakAutoSurgeon(worldName, x, y)
    local station = getStation(worldName, x, y)
    if not station then return true end
    if (tonumber(station.earned_wl) or 0) > 0 then return false end
    if _G.AutoSurgeon.hasAnyStationStock(worldName, x, y) then return false end
    return true
end

local function tryDepositToolToStation(player, worldName, x, y, toolID)
    local current = _G.AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
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
    _G.AutoSurgeon.addStationTool(worldName, x, y, toolID, depositAmount)
    safeBubble(player, "`2Deposited " .. tostring(depositAmount) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

local function tryWithdrawToolFromStation(player, worldName, x, y, toolID)
    local current = _G.AutoSurgeon.getStationToolAmount(worldName, x, y, toolID)
    if current <= 0 then
        safeBubble(player, "`4There is no stock for this tool.")
        return false
    end
    player:changeItem(toolID, current, 0)
    _G.AutoSurgeon.removeStationTool(worldName, x, y, toolID, current)
    safeBubble(player, "`2Withdrew " .. tostring(current) .. "x tool ID " .. tostring(toolID) .. ".")
    return true
end

-- =======================================================
-- PANELS
-- =======================================================

local function tryUpgradeHospital(player, world)
    local worldName = getWorldName(world, player)
    local state     = getHospitalState(worldName)
    local level     = tonumber(state.level) or 1
    local progress  = tonumber(state.progress) or 0
    local levelData = HOSPITAL_LEVELS[level]

    if not levelData or not levelData.next_level then
        safeBubble(player, "`4Hospital is already at max level.")
        return
    end
    if progress < tonumber(levelData.required_surgeries) then
        safeBubble(player, "`4Not enough surgery progress to upgrade yet.")
        return
    end
    if (tonumber(player:getGems()) or 0) < tonumber(levelData.upgrade_gems) then
        safeBubble(player, "`4Not enough Gems to upgrade the hospital.")
        return
    end

    safeBubble(player, "`oWL upgrade check is not connected yet in this build.")

    player:removeGems(tonumber(levelData.upgrade_gems), 1, 1)
    setHospitalState(worldName, tonumber(levelData.next_level), 0)
    safeBubble(player, "`2Hospital upgraded to level " .. tostring(levelData.next_level) .. "!")
end

-- Bridge shared locals so sub-modules can access hospital helpers via _G.HospitalSystem
_G.getStation = getStation
_G.saveStation = saveStation
_G.deleteStationData = deleteStationData
_G.loadHospital = loadHospital
_G.saveHospital = saveHospital
_G.getHospitalState = getHospitalState
_G.getHospitalRatingCounter = getHospitalRatingCounter
_G.getHospitalTreatmentStats = getHospitalTreatmentStats
_G.formatRequirementProgress = formatRequirementProgress
_G.getRequirementIconID = getRequirementIconID
_G.getOwnerNetGain = getOwnerNetGain
_G.getWorldTaxWL = getWorldTaxWL
_G.getPlayerItemAmount = getPlayerItemAmount
_G.getTotalWLEquivalent = getTotalWLEquivalent
_G.deductWLEquivalent = deductWLEquivalent
_G.getUserID = getUserID
_G.getWorldName = getWorldName
_G.isWorldOwner = isWorldOwner
_G.isEffectiveDoctor = isEffectiveDoctor
_G.safeHasRole = safeHasRole
_G.safeBubble = safeBubble
_G.getAllWorldTiles = getAllWorldTiles
_G.recordHospitalTreatment = recordHospitalTreatment
_G.RECEPTION_DESK_ID = RECEPTION_DESK_ID
_G.AUTO_SURGEON_ID = AUTO_SURGEON_ID
_G.OPERATING_TABLE_ID = OPERATING_TABLE_ID
_G.MIN_CURE_PRICE_WL = MIN_CURE_PRICE_WL
_G.MAX_TOOL_STORAGE = MAX_TOOL_STORAGE
_G.MAX_HOSPITAL_RATING = MAX_HOSPITAL_RATING
_G.RATING_STEP_CURES = RATING_STEP_CURES
_G.ALL_SURGICAL_TOOLS = ALL_SURGICAL_TOOLS
_G.TOOL_REQUIREMENT = TOOL_REQUIREMENT
_G.MALADY_UI_VIAL = MALADY_UI_VIAL
_G.MALADY_UI_RNG = MALADY_UI_RNG
_G.MALADY_ICON = MALADY_ICON
_G.MALADY_ICON_VISUAL = MALADY_ICON_VISUAL
_G.MALADY_UNLOCK_LEVEL = MALADY_UNLOCK_LEVEL
_G.getUnlockedAutoSurgeonMaladies = getUnlockedAutoSurgeonMaladies
_G.HOSPITAL_STATS_MALADY_ROWS = HOSPITAL_STATS_MALADY_ROWS
_G.HOSPITAL_LEVELS = HOSPITAL_LEVELS
_G.LEVEL_UP_RULES = LEVEL_UP_RULES
_G.REQUIRED_OPERATING_TABLES = REQUIRED_OPERATING_TABLES
_G.OPERATING_TABLE_DURATION_MIN_SEC = OPERATING_TABLE_DURATION_MIN_SEC
_G.OPERATING_TABLE_DURATION_MAX_SEC = OPERATING_TABLE_DURATION_MAX_SEC
_G.OPERATING_STATUS_BUBBLE_INTERVAL_SEC = OPERATING_STATUS_BUBBLE_INTERVAL_SEC
_G.ROLE_DEVELOPER = ROLE_DEVELOPER
_G.WORLD_LOCK_ID = WORLD_LOCK_ID
_G.DIAMOND_LOCK_ID = DIAMOND_LOCK_ID
_G.BGL_ID = BGL_ID
_G.BTN_BIND_PREFIX = BTN_BIND_PREFIX
_G.BTN_TOOL_PREFIX = BTN_TOOL_PREFIX
_G.BTN_WITHDRAW_TOOL_PREFIX = BTN_WITHDRAW_TOOL_PREFIX
_G.BTN_ADD_DOCTOR_PREFIX = BTN_ADD_DOCTOR_PREFIX
_G.BTN_REMOVE_DOCTOR_PREFIX = BTN_REMOVE_DOCTOR_PREFIX
_G.BTN_DOCTORS_BACK = BTN_DOCTORS_BACK
_G.BTN_OPEN_STORAGE = BTN_OPEN_STORAGE
_G.BTN_STORAGE_BACK = BTN_STORAGE_BACK
_G.BTN_WITHDRAW_WL = BTN_WITHDRAW_WL
_G.BTN_CLOSE_OWNER = BTN_CLOSE_OWNER
_G.BTN_CURE_MALADY = BTN_CURE_MALADY
_G.BTN_SHOW_STATS = BTN_SHOW_STATS
_G.BTN_LEVEL_UP = BTN_LEVEL_UP
_G.BTN_BACK_STATS = BTN_BACK_STATS
_G.BTN_LEVEL_UP_BACK = BTN_LEVEL_UP_BACK
_G.BTN_LEVEL_UP_NEW_CONFIRM = BTN_LEVEL_UP_NEW_CONFIRM
_G.DLG_MANAGE_DOCTORS = DLG_MANAGE_DOCTORS
_G.extractButtonSuffix = extractButtonSuffix
_G.countAutoSurgeons = countAutoSurgeons
_G.countOperatingTables = countOperatingTables
_G.getLevelUpSnapshot = getLevelUpSnapshot
_G.isLevelUpReadyForRule = isLevelUpReadyForRule
_G.setHospitalState = setHospitalState
_G.getOperatingTableCapacityByLevel = getOperatingTableCapacityByLevel
_G.getOperatingPatientDurationByLevel = getOperatingPatientDurationByLevel

-- =======================================================
-- CALLBACKS
-- =======================================================
-- NOTE: Auto Surgeon tile extra data callback is registered in auto_surgeon.lua
-- (loads after hospital.lua). resolveAutoSurgeonIllnessVisualID is exposed via
-- _G so the /hospitaltest tileextra command can use it.

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() == RECEPTION_DESK_ID then
        local worldName = getWorldName(world, player)
        local uid = getUserID(player)
        if isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER) then
            _G.ReceptionDesk.showReceptionDeskPanel(world, player)
        elseif _G.ReceptionDesk.isDoctor(worldName, uid) then
            _G.ReceptionDesk.showDoctorReceptionPanel(world, player, worldName)
        else
            safeBubble(player, "`4You are not registered as a doctor at this hospital!")
        end
        return true
    end
    if tile:getTileID() == AUTO_SURGEON_ID then
        local worldName = getWorldName(world, player)
        local x = tile:getPosX()
        local y = tile:getPosY()
        -- Cek jarak: player harus dekat station
        -- getPosX() mungkin pixel (/32) atau tile coords langsung - dual-check keduanya
        -- Offset kanan lebih besar (+4) karena getPosX() = ujung kiri player, bukan center
        local pxRaw = math.floor(player:getPosX() or 0)
        local pyRaw = math.floor(player:getPosY() or 0)
        local pxTile = math.floor(pxRaw / 32)
        local pyTile = math.floor(pyRaw / 32)
        local closeAsPixels = (pxTile - x) >= -8 and (pxTile - x) <= 17 and math.abs(pyTile - y) <= 6
        local closeAsTiles  = (pxRaw - x) >= -8 and (pxRaw - x) <= 17 and math.abs(pyRaw - y) <= 6
        if not closeAsPixels and not closeAsTiles then
            safeBubble(player, "Get closer!")
            return true
        end
        _G.AutoSurgeon.ensureStation(worldName, x, y)
        if isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER) then
            _G.AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, x, y)
        else
            _G.AutoSurgeon.showAutoSurgeonPlayerPanel(world, player, worldName, x, y)
        end
        return true
    end
    return false
end)

onTilePlaceCallback(function(world, player, tile, placingID)
    local itemID = safeItemID(placingID)

    if itemID == RECEPTION_DESK_ID then
        if countReceptionDesks(world) >= 1 then
            safeBubble(player, "`4Only one Reception Desk can exist in a world.")
            return true
        end
    end

    if itemID == AUTO_SURGEON_ID then
        if countReceptionDesks(world) < 1 then
            safeBubble(player, "`4A Reception Desk must be placed first before adding Auto Surgeon Stations.")
            return true
        end
        if countAutoSurgeons(world) >= 12 then
            safeBubble(player, "`4Maximum 12 Auto Surgeon Stations allowed per world.")
            return true
        end
    end

    if itemID == OPERATING_TABLE_ID then
        if countReceptionDesks(world) < 1 then
            safeBubble(player, "`4A Reception Desk must be placed first before adding Operating Tables.")
            return true
        end
        local worldName = getWorldName(world, player)
        local hospitalLevel = tonumber((getHospitalState(worldName) or {}).level) or 1
        local capacity = getOperatingTableCapacityByLevel(hospitalLevel)
        if countOperatingTables(world) >= capacity then
            safeBubble(player, "`4Operating Table capacity reached: `o" .. tostring(capacity) .. "`4. Upgrade hospital level to unlock more.")
            return true
        end
    end

    return false
end)

-- onTilePunchCallback: prevent punching to completion when tiles are protected
-- (return true = prevent break/damage accumulation, tile stays intact)
onTilePunchCallback(function(world, player, tile)
    local worldName = getWorldName(world, player)
    local x = tile:getPosX()
    local y = tile:getPosY()

    if tile:getTileID() == RECEPTION_DESK_ID then
        if countAutoSurgeons(world) > 0 then
            safeBubble(player, "`4Remove all Auto Surgeon Stations before breaking the Reception Desk.")
            return true
        end
    end

    if tile:getTileID() == AUTO_SURGEON_ID then
        if not _G.AutoSurgeon.canBreakAutoSurgeon(worldName, x, y) then
            safeBubble(player, "`4Empty the Auto Surgeon storage and withdraw earnings before breaking.")
            return true
        end
    end

    if tile:getTileID() == WORLD_LOCK_ID then
        if hasHospitalInWorld(world) then
            safeBubble(player, "`4Cannot break the World Lock while a hospital is active in this world.")
            return true
        end
    end

    return false
end)

-- onTileBreakCallback: cleanup after allowed break (no prevention here)
onTileBreakCallback(function(world, player, tile)
    local worldName = getWorldName(world, player)

    if tile:getTileID() == RECEPTION_DESK_ID then
        resetHospitalState(worldName)
    end

    if tile:getTileID() == AUTO_SURGEON_ID then
        deleteStation(worldName, tile:getPosX(), tile:getPosY())
    end

    if tile:getTileID() == OPERATING_TABLE_ID then
        _G.OperatingTable.clearOperatingTable(world, worldName, tile:getPosX(), tile:getPosY())
    end
end)


-- (Nperma only) Block trading World Lock out of a hospital world
onPlayerTradeCallback(function(world, player1, player2, items1, items2)
    if not hasHospitalInWorld(world) then return end
    local function hasWL(items)
        if type(items) ~= "table" then return false end
        for _, item in pairs(items) do
            if item and item.getItemID and item:getItemID() == WORLD_KEY_ID then
                return true
            end
        end
        return false
    end
    if hasWL(items1) or hasWL(items2) then
        safeBubble(player1, "`4Cannot trade the World Key while a hospital is active in this world.")
        safeBubble(player2, "`4Cannot trade the World Key while a hospital is active in this world.")
        return true
    end
end)

onPlayerSurgeryCallback(function(world, surgeon, rewardID, rewardCount, targetPlayer)
    if MaladySystem.getActiveMalady(surgeon) == MaladySystem.MALADY.BROKEN_HEARTS then
        return true -- block: patient tidak sembuh, hospital progress tidak naik
    end

    local worldName = getWorldName(world, surgeon)
    local treatmentRecorded = false

    if resolveOperatingTableSurgery(world, surgeon, targetPlayer) then
        treatmentRecorded = true
    end

    if targetPlayer and MaladySystem.hasActiveMalady(targetPlayer) then
        local targetMalady = MaladySystem.getActiveMalady(targetPlayer)
        local mappedMalady = SURGERY_REWARD_MALADY_KEY[tonumber(rewardID) or -1]
        local surgeryMaladyKey = targetMalady or mappedMalady
        local ok, reason = MaladySystem.cureFromManualSurgery(targetPlayer)
        if ok then
            safeConsole(targetPlayer, "`2Your malady has been cured by surgery.")
            recordHospitalTreatment(worldName, surgeryMaladyKey, true)
            treatmentRecorded = true
        else
            safeConsole(targetPlayer, "`4Malady cure failed: " .. tostring(reason))
            recordHospitalTreatment(worldName, surgeryMaladyKey, false)
            treatmentRecorded = true
        end
    end

    local effectiveDoctor = isEffectiveDoctor(world, worldName, getUserID(surgeon), surgeon)
    if effectiveDoctor then
        if not treatmentRecorded then
            -- Fallback for Surg-E/manual surgery that does not go through MaladySystem target flow.
            -- onPlayerSurgeryCallback is treated as successful surgery event here.
            local mappedMalady = SURGERY_REWARD_MALADY_KEY[tonumber(rewardID) or -1]
            recordHospitalTreatment(worldName, mappedMalady, true)
            treatmentRecorded = true
        end

        local added = addHospitalProgressIfPossible(worldName, 1)
        if added then safeConsole(surgeon, "`2Hospital progress increased by 1.") end
        addDoctorSurgery(worldName, getUserID(surgeon))
    end

    MaladySystem.tryInfectFromTrigger(surgeon, MaladySystem.TRIGGER_SOURCE.SURGERY)
end)

-- =======================================================
-- DEV COMMANDS
-- =======================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    local parts = {}
    for token in (fullCommand or ""):gmatch("%S+") do
        parts[#parts + 1] = token
    end
    local cmd = string.lower(parts[1] or "")

    if cmd == "sleep" or cmd == "/sleep" then
        local px = math.floor((player:getPosX() or 0) / 32)
        local py = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if tile and tile:getTileID() == OPERATING_TABLE_ID then
            if world.setPlayerPosition then
                world:setPlayerPosition(player, tile:getPosX(), tile:getPosY())
            end
            safeBubble(player, "`2You lay on the Operating Table and wait for a doctor.")
            return false
        end
    end

    if cmd ~= "hospitaltest" and cmd ~= "/hospitaltest" then
        return false
    end
    if not safeHasRole(player, ROLE_DEVELOPER) then
        safeBubble(player, "`4Developer only test command.")
        return true
    end

    local sub = string.lower(parts[2] or "help")

    if sub == "help" then
        safeConsole(player, "`w/hospitaltest panel `o= open reception panel")
        safeConsole(player, "`w/hospitaltest owner `o= open owner panel while standing on station")
        safeConsole(player, "`w/hospitaltest infect chicken/torn/grumble/gems/auto/broken")
        safeConsole(player, "`w/hospitaltest clear")
        safeConsole(player, "`w/hospitaltest state")
        safeConsole(player, "`w/hospitaltest addprogress")
        safeConsole(player, "`w/hospitaltest stationstate")
        safeConsole(player, "`w/hospitaltest operating `o= debug operating table status in this world")
        safeConsole(player, "`w/hospitaltest tileextra `o= debug Auto Surgeon tile extra values")
        safeConsole(player, "`w/hospitaltest tileextra id <0-255> `o= force selectedIllness visual ID")
        safeConsole(player, "`w/hospitaltest tileextra auto `o= clear forced selectedIllness ID")
        safeConsole(player, "`w/hospitaltest tileextra wl 0|1 `o= force wlCount visual flag")
        return true
    end

    if sub == "operating" then
        local worldName = getWorldName(world, player)
        local state = getHospitalState(worldName)
        local level = tonumber(state.level) or 1
        safeConsole(player, "`wOperating Table Capacity: `o" .. tostring(getOperatingTableCapacityByLevel(level)))
        safeConsole(player, "`wOperating Table Duration(s): `o" .. tostring(getOperatingPatientDurationByLevel(level)))

        local loaded = loadHospital(worldName)
        local opRows = loaded.operating_tables or {}
        local total = 0
        local active = 0
        for _, row in pairs(opRows) do
            total = total + 1
            if tostring(row.status or "") == "active" then active = active + 1 end
        end
        safeConsole(player, "`wOperating Table rows tracked: `o" .. tostring(total) .. " `w(active: `o" .. tostring(active) .. "`w)")
        return true
    end

    if sub == "panel" then
        _G.ReceptionDesk.showReceptionDeskPanel(world, player)
        return true
    end

    if sub == "owner" then
        local px   = math.floor((player:getPosX() or 0) / 32)
        local py   = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if not tile or tile:getTileID() ~= AUTO_SURGEON_ID then
            safeBubble(player, "`4Stand on an Auto Surgeon Station first.")
            return true
        end
        local worldName = getWorldName(world)
        _G.AutoSurgeon.showAutoSurgeonOwnerPanel(world, player, worldName, tile:getPosX(), tile:getPosY())
        return true
    end

    if sub == "infect" then
        local which = string.lower(parts[3] or "")
        local maladyMap = {
            chicken = MaladySystem.MALADY.CHICKEN_FEET,
            torn    = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
            grumble = MaladySystem.MALADY.GRUMBLETEETH,
            gems    = MaladySystem.MALADY.GEMS_CUTS,
            auto    = MaladySystem.MALADY.AUTOMATION_CURSE,
            broken  = MaladySystem.MALADY.BROKEN_HEARTS
        }
        local maladyType = maladyMap[which]
        if not maladyType then
            safeBubble(player, "`4Unknown malady test key.")
            return true
        end
        local ok, reason = MaladySystem.forceInfect(player, maladyType, "ADMIN", false)
        safeConsole(player, "forceInfect => " .. tostring(ok) .. " / " .. tostring(reason))
        return true
    end

    if sub == "clear" then
        local ok = MaladySystem.clearMalady(player, "ADMIN")
        safeConsole(player, "clearMalady => " .. tostring(ok))
        return true
    end

    if sub == "state" then
        MaladySystem.debugState(player)
        local worldName = getWorldName(world, player)
        local state = getHospitalState(worldName)
        safeConsole(player, "`wHospital Level: `o" .. tostring(state.level))
        safeConsole(player, "`wHospital Progress: `o" .. tostring(state.progress))
        safeConsole(player, "`wDoctors: `o" .. tostring(_G.ReceptionDesk.countDoctors(worldName)))
        return true
    end

    if sub == "addprogress" then
        local added = addHospitalProgressIfPossible(getWorldName(world, player), 1)
        if added then
            safeBubble(player, "`2Added hospital progress by 1.")
        else
            safeBubble(player, "`4Could not add progress. Maybe hospital is full or max level.")
        end
        return true
    end

    if sub == "stationstate" then
        local px   = math.floor((player:getPosX() or 0) / 32)
        local py   = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if not tile or tile:getTileID() ~= AUTO_SURGEON_ID then
            safeBubble(player, "`4Stand on an Auto Surgeon Station first.")
            return true
        end
        local station = getStation(getWorldName(world), tile:getPosX(), tile:getPosY())
        if not station then
            safeBubble(player, "`4Station data not found.")
            return true
        end
        safeConsole(player, "`wStation Malady: `o" .. tostring(station.malady_type))
        safeConsole(player, "`wEnabled: `o" .. tostring(station.enabled))
        safeConsole(player, "`wPrice WL: `o" .. tostring(station.price_wl))
        safeConsole(player, "`wEarned WL: `o" .. tostring(station.earned_wl))
        return true
    end

    if sub == "tileextra" then
        local px   = math.floor((player:getPosX() or 0) / 32)
        local py   = math.floor((player:getPosY() or 0) / 32)
        local tile = world:getTile(px, py)
        if not tile or tile:getTileID() ~= AUTO_SURGEON_ID then
            safeBubble(player, "`4Stand on an Auto Surgeon Station first.")
            return true
        end

        local mode = string.lower(parts[3] or "")
        if mode == "id" then
            local raw = tonumber(parts[4])
            if not raw then
                safeBubble(player, "`4Usage: /hospitaltest tileextra id <0-255>")
                return true
            end
            _G.__HOSPITAL_FORCE_ILLNESS_ID = math.max(0, math.min(255, math.floor(raw)))
            world:updateTile(tile)
            safeConsole(player, "`wForced selectedIllness ID => `o" .. tostring(_G.__HOSPITAL_FORCE_ILLNESS_ID))
            return true
        elseif mode == "auto" then
            _G.__HOSPITAL_FORCE_ILLNESS_ID = nil
            world:updateTile(tile)
            safeConsole(player, "`wForced selectedIllness ID cleared (back to malady mapping).")
            return true
        elseif mode == "wl" then
            local raw = tonumber(parts[4])
            if raw == nil then
                safeBubble(player, "`4Usage: /hospitaltest tileextra wl 0|1")
                return true
            end
            _G.__HOSPITAL_FORCE_WL_VISUAL = raw > 0 and 1 or 0
            world:updateTile(tile)
            safeConsole(player, "`wForced wlCountVisual => `o" .. tostring(_G.__HOSPITAL_FORCE_WL_VISUAL))
            return true
        end

        local station = getStation(getWorldName(world), tile:getPosX(), tile:getPosY())
        if not station then
            safeBubble(player, "`4Station data not found.")
            return true
        end

        local maladyType = tostring(station.malady_type or "")
        local illnessID = resolveAutoSurgeonIllnessVisualID(maladyType)
        local forcedIllnessID = tonumber(rawget(_G, "__HOSPITAL_FORCE_ILLNESS_ID"))
        if forcedIllnessID then illnessID = forcedIllnessID end
        local wlCount = tonumber(station.earned_wl) or 0
        local wlCountVisual = wlCount > 0 and 1 or 0
        local forcedWLVisual = tonumber(rawget(_G, "__HOSPITAL_FORCE_WL_VISUAL"))
        if forcedWLVisual then wlCountVisual = forcedWLVisual > 0 and 1 or 0 end
        local outOfOrder = (maladyType == "" or tonumber(station.enabled) ~= 1) and 1 or 0

        safeConsole(player, "`wTileExtra Malady: `o" .. maladyType)
        safeConsole(player, "`wTileExtra selectedIllness ID: `o" .. tostring(illnessID))
        safeConsole(player, "`wTileExtra outOfOrder: `o" .. tostring(outOfOrder))
        safeConsole(player, "`wTileExtra wlCount: `o" .. tostring(wlCount))
        safeConsole(player, "`wTileExtra wlCountVisual(0/1): `o" .. tostring(wlCountVisual))
        safeConsole(player, "`wTileExtra forced selectedIllness ID: `o" .. tostring(rawget(_G, "__HOSPITAL_FORCE_ILLNESS_ID") or "nil"))
        safeConsole(player, "`wTileExtra forced wlVisual: `o" .. tostring(rawget(_G, "__HOSPITAL_FORCE_WL_VISUAL") or "nil"))
        return true
    end

    return true
end)

-- =======================================================
-- GLOBAL DIALOG CALLBACK - Handles all hospital dialogs
-- This ensures proper dialog navigation even with nested dialogs
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    if type(data) ~= "table" or type(world) ~= "userdata" or type(player) ~= "userdata" then
        return false
    end

    local dialogName = tostring(data["dialog_name"] or "")
    local buttonClicked = tostring(data["buttonClicked"] or "")
    local worldName = getWorldName(world, player)

    -- List of all hospital dialog names we handle
    local hospitalDialogs = {
        ["hospitalStatsUi"] = true,
        ["hospitalLevelUpUi"] = true,
        ["receptionDeskMainUi"] = true,
        [DLG_MANAGE_DOCTORS] = true,
    }

    -- Check if this is one of our hospital dialogs
    if not hospitalDialogs[dialogName] then
        return false
    end

    -- ===== HOSPITAL STATS UI =====
    if dialogName == "hospitalStatsUi" then
        if isDialogButtonPressed(data, BTN_BACK_STATS) or isDialogBackAction(buttonClicked, BTN_BACK_STATS) then
            _G.ReceptionDesk.showReceptionDeskPanel(world, player)
        end
        return true
    end

    -- ===== LEVEL UP UI =====
    if dialogName == "hospitalLevelUpUi" then
        if isDialogButtonPressed(data, BTN_LEVEL_UP_BACK) or isDialogBackAction(buttonClicked, BTN_LEVEL_UP_BACK) then
            _G.ReceptionDesk.showReceptionDeskPanel(world, player)
            return true
        end

        if isDialogButtonPressed(data, BTN_LEVEL_UP_NEW_CONFIRM) then
            local state = getHospitalState(worldName)
            local level = tonumber(state.level) or 1
            local levelData = HOSPITAL_LEVELS[level]
            local ownerAccess = isWorldOwner(world, player) or safeHasRole(player, ROLE_DEVELOPER)

            if ownerAccess and levelData and levelData.next_level then
                local upgradeCost = tonumber(levelData.upgrade_wl) or 0
                local totalWLEquiv = getTotalWLEquivalent(player)
                local snapshot = getLevelUpSnapshot(world, worldName, state, totalWLEquiv)
                local levelRule = LEVEL_UP_RULES[level] or {}

                if totalWLEquiv >= upgradeCost and isLevelUpReadyForRule(levelRule, snapshot, upgradeCost) and deductWLEquivalent(player, upgradeCost) then
                    setHospitalState(worldName, levelData.next_level, 0)
                    safeConsole(player, "`2Hospital has been upgraded to level " .. tostring(levelData.next_level) .. "!")
                    _G.ReceptionDesk.showReceptionDeskPanel(world, player)
                end
            end
        end

        return true
    end

    -- ===== RECEPTION DESK MAIN UI =====
    if dialogName == "receptionDeskMainUi" then
        if buttonClicked == BTN_SHOW_STATS then
            _G.ReceptionDesk.showHospitalStatsPanel(world, player)
        elseif buttonClicked == BTN_LEVEL_UP then
            _G.ReceptionDesk.showLevelUpPanel(world, player)
        end
        return true
    end

    -- ===== MANAGE DOCTORS DIALOG =====
    if dialogName == DLG_MANAGE_DOCTORS then
        if isDialogButtonPressed(data, BTN_DOCTORS_BACK) or isDialogBackAction(buttonClicked, BTN_DOCTORS_BACK) then
            _G.ReceptionDesk.showReceptionDeskPanel(world, player)
            return true
        end

        if buttonClicked and buttonClicked:match("^" .. BTN_ADD_DOCTOR_PREFIX) then
            local uid = tonumber(buttonClicked:gsub("^" .. BTN_ADD_DOCTOR_PREFIX, ""))
            if uid and uid > 0 then
                _G.ReceptionDesk.addDoctor(worldName, uid)
                _G.ReceptionDesk.showManageDoctorsPanel(world, player, worldName)
            end
        elseif buttonClicked and buttonClicked:match("^" .. BTN_REMOVE_DOCTOR_PREFIX) then
            local uid = tonumber(buttonClicked:gsub("^" .. BTN_REMOVE_DOCTOR_PREFIX, ""))
            if uid and uid > 0 then
                _G.ReceptionDesk.removeDoctor(worldName, uid)
                _G.ReceptionDesk.showManageDoctorsPanel(world, player, worldName)
            end
        end

        return true
    end

    return false
end)

_G.HospitalSystem = HospitalSystem
return HospitalSystem
