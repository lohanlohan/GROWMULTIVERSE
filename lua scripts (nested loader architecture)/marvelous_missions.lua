-- MODULE
-- marvelous_missions.lua — Marvelous Missions: collection quest system

local M  = {}
local DB = _G.DB

local STORAGE_KEY = "marvelous-missions"

-- ============================================================================
-- DATA STORAGE
-- ============================================================================
local marvelousData = DB.load(STORAGE_KEY) or {}

onAutoSaveRequest(function()
    DB.save(STORAGE_KEY, marvelousData)
end)

-- ============================================================================
-- CATEGORIES & TYPES
-- ============================================================================
local MissionsCat = {
    SEASON_1_MENU = 0,
    SEASON_2_MENU = 1,
}

local MissionsTypes = {
    S1_FINDING_THE_SWAMP_MONSTER        = 0,
    S1_HERE_COME_THE_SHADY_AGENTS       = 1,
    S1_THE_SEARCH_FOR_NESSIE            = 2,
    S1_MOTHMAN_RISING                   = 3,
    S1_THE_MENACE_OF_THE_MINI_MINOKAWA  = 4,
    S1_THE_EYE_OF_THE_HEAVENS           = 5,
    S2_A_TALE_OF_TENTACLES              = 6,
    S2_THE_RAY_OF_THE_MANTA             = 7,
    S2_THE_CRUST_OF_THE_CRAB            = 8,
    S2_THE_CURSE_OF_THE_GHOST_PIRATE    = 9,
    S2_THE_WINGS_OF_ATLANTIS            = 10,
    S2_THE_HEART_OF_THE_OCEAN           = 11,
}

local missionsNavigation = {
    { name="Season I",  target="tab_1", cat=MissionsCat.SEASON_1_MENU, texture="interface/large/btn_mmtabs.rttex", texture_y="1" },
    { name="Season II", target="tab_2", cat=MissionsCat.SEASON_2_MENU, texture="interface/large/btn_mmtabs.rttex", texture_y="2" },
}

local missionsNames = {
    { type=MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER,       name="Myths and Legends : Finding the Swamp monster!" },
    { type=MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS,      name="Myths and Legends : Here come the Shady Agents" },
    { type=MissionsTypes.S1_THE_SEARCH_FOR_NESSIE,           name="Myths and Legends : The Search for Nessie" },
    { type=MissionsTypes.S1_MOTHMAN_RISING,                   name="Myths and Legends : Mothman Rising" },
    { type=MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA, name="Myths and Legends : The Menace of the Mini Minokawa" },
    { type=MissionsTypes.S1_THE_EYE_OF_THE_HEAVENS,          name="Myths and Legends : The Eye of the Heavens" },
    { type=MissionsTypes.S2_A_TALE_OF_TENTACLES,             name="The Seven Seas : A Tale of Tentacles!" },
    { type=MissionsTypes.S2_THE_RAY_OF_THE_MANTA,            name="The Seven Seas : The Ray of the Manta!" },
    { type=MissionsTypes.S2_THE_CRUST_OF_THE_CRAB,           name="The Seven Seas : The Crust of the Crab!" },
    { type=MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE,   name="The Seven Seas : The Curse of the Ghost Pirate!" },
    { type=MissionsTypes.S2_THE_WINGS_OF_ATLANTIS,           name="The Seven Seas : The Wings of Atlantis!" },
    { type=MissionsTypes.S2_THE_HEART_OF_THE_OCEAN,          name="The Seven Seas : The Heart of the Ocean!" },
}

-- ============================================================================
-- MISSION DATA
-- ============================================================================
local missionsData = {
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER,
        requiredItems = { {itemID=3166,itemCount=1},{itemID=7428,itemCount=1},{itemID=10028,itemCount=2},{itemID=10030,itemCount=2},{itemID=8390,itemCount=200},{itemID=6984,itemCount=100} },
        requiredMissions = {},
        rewardStr = "Reward: Swamp Monster Set + unlocks Here come the Shady Agents and The Search for Nessie",
        rewardItems = { {itemID=10692,itemCount=1},{itemID=10690,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS,
        requiredItems = { {itemID=9734,itemCount=1},{itemID=1150,itemCount=1},{itemID=7948,itemCount=1},{itemID=8394,itemCount=200},{itemID=1954,itemCount=100},{itemID=2035,itemCount=10} },
        requiredMissions = { MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER },
        rewardStr = "Reward: Shady Agent Shades + unlocks Mothman Rising Mission",
        rewardItems = { {itemID=10686,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_THE_SEARCH_FOR_NESSIE,
        requiredItems = { {itemID=10248,itemCount=1},{itemID=9442,itemCount=1},{itemID=4828,itemCount=1},{itemID=7996,itemCount=1},{itemID=822,itemCount=200},{itemID=2974,itemCount=10} },
        requiredMissions = { MissionsTypes.S1_FINDING_THE_SWAMP_MONSTER },
        rewardStr = "Reward: Cardboard Nessie + unlocks The menace of the Mini Minokawa Mission",
        rewardItems = { {itemID=10688,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_MOTHMAN_RISING,
        requiredItems = { {itemID=10680,itemCount=1},{itemID=6818,itemCount=1},{itemID=7350,itemCount=1},{itemID=9610,itemCount=1},{itemID=1206,itemCount=1},{itemID=10726,itemCount=1} },
        requiredMissions = { MissionsTypes.S1_HERE_COME_THE_SHADY_AGENTS },
        rewardStr = "Reward: Mothman Wings",
        rewardItems = { {itemID=10684,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA,
        requiredItems = { {itemID=9430,itemCount=1},{itemID=10578,itemCount=1},{itemID=6842,itemCount=1},{itemID=2856,itemCount=100},{itemID=1834,itemCount=100},{itemID=2722,itemCount=1} },
        requiredMissions = { MissionsTypes.S1_THE_SEARCH_FOR_NESSIE },
        rewardStr = "Reward: Mini Minokawa + unlocks The Eye of the Heavens",
        rewardItems = { {itemID=10694,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_1_MENU, type = MissionsTypes.S1_THE_EYE_OF_THE_HEAVENS,
        requiredItems = { {itemID=2714,itemCount=200},{itemID=7044,itemCount=2},{itemID=11098,itemCount=2},{itemID=9690,itemCount=200},{itemID=10676,itemCount=5},{itemID=10144,itemCount=10} },
        requiredMissions = { MissionsTypes.S1_THE_MENACE_OF_THE_MINI_MINOKAWA },
        rewardStr = "Reward: Primordial Jade Lance",
        rewardItems = { {itemID=11120,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_A_TALE_OF_TENTACLES,
        requiredItems = { {itemID=5612,itemCount=100},{itemID=3812,itemCount=200},{itemID=8814,itemCount=10},{itemID=10226,itemCount=10},{itemID=9732,itemCount=1},{itemID=11264,itemCount=10} },
        requiredMissions = {},
        rewardStr = "Reward: Robe of Tentacles + unlocks The Ray of the Manta and The Crust of the Crab",
        rewardItems = { {itemID=12236,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_THE_RAY_OF_THE_MANTA,
        requiredItems = { {itemID=5584,itemCount=10},{itemID=11110,itemCount=2},{itemID=5230,itemCount=10},{itemID=9656,itemCount=10},{itemID=10722,itemCount=1},{itemID=11576,itemCount=20} },
        requiredMissions = { MissionsTypes.S2_A_TALE_OF_TENTACLES },
        rewardStr = "Reward: Manta Ray Wings",
        rewardItems = { {itemID=12238,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_THE_CRUST_OF_THE_CRAB,
        requiredItems = { {itemID=5612,itemCount=50},{itemID=11244,itemCount=1},{itemID=9374,itemCount=1},{itemID=10760,itemCount=5},{itemID=11198,itemCount=1},{itemID=11454,itemCount=10} },
        requiredMissions = { MissionsTypes.S2_A_TALE_OF_TENTACLES },
        rewardStr = "Reward: Giant Crab Shell",
        rewardItems = { {itemID=12240,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE,
        requiredItems = { {itemID=11530,itemCount=1},{itemID=10416,itemCount=1},{itemID=9438,itemCount=1},{itemID=8986,itemCount=20},{itemID=10234,itemCount=1},{itemID=9382,itemCount=5} },
        requiredMissions = { MissionsTypes.S2_THE_RAY_OF_THE_MANTA },
        rewardStr = "Reward: Ghost Pirate Hat",
        rewardItems = { {itemID=12242,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_THE_WINGS_OF_ATLANTIS,
        requiredItems = { {itemID=11416,itemCount=1},{itemID=9896,itemCount=1},{itemID=10046,itemCount=1},{itemID=9698,itemCount=1},{itemID=11336,itemCount=1},{itemID=10922,itemCount=1} },
        requiredMissions = { MissionsTypes.S2_THE_CRUST_OF_THE_CRAB },
        rewardStr = "Reward: Atlantis Wings",
        rewardItems = { {itemID=12244,itemCount=1} },
    },
    {
        season = MissionsCat.SEASON_2_MENU, type = MissionsTypes.S2_THE_HEART_OF_THE_OCEAN,
        requiredItems = { {itemID=9732,itemCount=5},{itemID=11264,itemCount=50},{itemID=10226,itemCount=50},{itemID=9656,itemCount=50},{itemID=11576,itemCount=100},{itemID=11454,itemCount=50} },
        requiredMissions = { MissionsTypes.S2_THE_WINGS_OF_ATLANTIS, MissionsTypes.S2_THE_CURSE_OF_THE_GHOST_PIRATE },
        rewardStr = "Reward: Heart of the Ocean",
        rewardItems = { {itemID=12246,itemCount=1} },
    },
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function getMissionName(mtype)
    for _, m in ipairs(missionsNames) do
        if m.type == mtype then return m.name end
    end
    return nil
end

local function startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

local function isMissionComplete(player, mtype)
    local uid  = player:getUserID()
    local data = marvelousData[uid]
    if not data or not data.missionsComplete then return false end
    for _, completed in ipairs(data.missionsComplete) do
        if completed == mtype then return true end
    end
    return false
end

local function isMissionAvailable(player, mission)
    for _, req in ipairs(mission.requiredMissions or {}) do
        if not isMissionComplete(player, req) then return false end
    end
    return true
end

local function canClaim(player, mission)
    if isMissionComplete(player, mission.type) then return false end
    if not isMissionAvailable(player, mission)  then return false end
    for _, item in ipairs(mission.requiredItems) do
        if (player:getItemAmount(item.itemID) or 0) < item.itemCount then return false end
    end
    return true
end

-- ============================================================================
-- DIALOG
-- ============================================================================
local function showMissions(world, player, cat)
    if cat < 0 or cat > 1 then return end

    local tabs = {}
    for _, category in ipairs(missionsNavigation) do
        local selected = (category.cat == cat) and "1" or "0"
        tabs[#tabs+1] = string.format(
            "add_custom_button|%s|image:%s;image_size:228,92;frame:%s,%s;width:0.15;min_width:60;|",
            category.target, category.texture, selected, category.texture_y)
    end

    local rows = {}
    for _, mission in ipairs(missionsData) do
        if mission.season == cat then
            local complete   = isMissionComplete(player, mission.type)
            local available  = isMissionAvailable(player, mission)
            local hasAll     = true
            local alpha      = available and "255" or "80"
            rows[#rows+1] = "add_spacer|small|"
            rows[#rows+1] = "add_spacer|small|"
            rows[#rows+1] = string.format("add_custom_textbox|%s|size:medium;color:255,255,255,%s|", getMissionName(mission.type), alpha)
            for _, item in ipairs(mission.requiredItems) do
                local has    = player:getItemAmount(item.itemID) or 0
                local enough = has >= item.itemCount
                if not enough then hasAll = false end
                local color  = enough and "`2" or "`4"
                local dis    = available and "" or ",disabled"
                rows[#rows+1] = string.format("add_button_with_icon|info_%s|%s%s/%s`|staticGreyFrame,no_padding_x,is_count_label%s|%s||",
                    item.itemID, color, has, item.itemCount, dis, item.itemID)
            end
            rows[#rows+1] = "add_button_with_icon||END_LIST|noflags|0||"
            rows[#rows+1] = string.format("add_custom_textbox|`$%s`|size:small;color:255,255,255,%s", mission.rewardStr, alpha)
            for _, item in ipairs(mission.rewardItems) do
                local dis = available and "" or ",disabled"
                rows[#rows+1] = string.format("add_button_with_icon|info_%s||staticYellowFrame,no_padding_x%s|%s|%s|", item.itemID, dis, item.itemID, item.itemCount)
            end
            rows[#rows+1] = "add_button_with_icon||END_LIST|noflags|0||"
            rows[#rows+1] = "add_spacer|small|"
            local claimFlags = (complete and "off") or (hasAll and available and "noflags") or "off"
            rows[#rows+1] = string.format("add_button|claim_myth_%s|%s|%s|0|0|", mission.type, complete and "Claimed" or "Claim", claimFlags)
        end
    end

    if cat == MissionsCat.SEASON_2_MENU then
        player:setNextDialogRGBA(59, 130, 135, 168)
        player:setNextDialogBorderRGBA(0, 255, 255, 255)
    else
        player:setNextDialogRGBA(46, 26, 105, 168)
        player:setNextDialogBorderRGBA(65, 2, 250, 255)
    end

    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "start_custom_tabs|\n" ..
        table.concat(tabs, "\n") .. "\n" ..
        "end_custom_tabs|\n" ..
        "add_label_with_icon|big|`wMarvelous Missions``|left|982|\n" ..
        "embed_data|tab|" .. cat .. "\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|Start your mission towards some awesome rewards. Unless the mission states otherwise, rewards can only be claimed once.|left|\n" ..
        table.concat(rows, "\n") .. "\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|More missions coming soon!|left|\n" ..
        "add_spacer|small|\n" ..
        "add_button|back|Back|noflags|0|0|\n" ..
        "end_dialog|collectionQuests|||\n" ..
        "add_quick_exit|", 500
    )
    player:resetDialogColor()
end

-- ============================================================================
-- DIALOG CALLBACK
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"] or ""
    local btn = data["buttonClicked"] or ""

    if dn == "collectionQuests" then
        if btn == "back" then
            player:onProfileUI(world, 1)
            return true
        end

        if startsWith(btn, "tab_") then
            local tabNum = tonumber(btn:sub(5))
            showMissions(world, player, (tabNum or 1) - 1)
            return true
        end

        if startsWith(btn, "claim_myth_") then
            local mtype = tonumber(btn:sub(12))
            for _, mission in ipairs(missionsData) do
                if mission.type == mtype then
                    if not canClaim(player, mission) then return true end
                    if data["confirmClaim"] ~= nil then
                        -- Consume items
                        for _, item in ipairs(mission.requiredItems) do
                            player:changeItem(item.itemID, -item.itemCount, 0)
                        end
                        -- Give rewards
                        for _, item in ipairs(mission.rewardItems) do
                            if not player:changeItem(item.itemID, item.itemCount, 0) then
                                player:changeItem(item.itemID, item.itemCount, 1)
                            end
                        end
                        player:onAddNotification("", "`$Mission Complete!``", "", 0, 1500)
                        local mx = player:getMiddlePosX()
                        local my = player:getMiddlePosY()
                        local players = world:getPlayers()
                        for i = 1, #players do players[i]:onParticleEffect(46, mx, my, 0, 0) end
                        -- Save completion
                        local uid = player:getUserID()
                        if not marvelousData[uid] then
                            marvelousData[uid] = { missionsComplete = { mtype } }
                        else
                            marvelousData[uid].missionsComplete = marvelousData[uid].missionsComplete or {}
                            marvelousData[uid].missionsComplete[#marvelousData[uid].missionsComplete+1] = mtype
                        end
                        DB.save(STORAGE_KEY, marvelousData)
                        return true
                    end
                    -- Confirm dialog
                    local tab = tostring(data["tab"] or "0"):sub(1, -2)
                    player:onDialogRequest(
                        "set_default_color|`o\n" ..
                        "add_label|big|Marvelous Mission|left|\n" ..
                        "embed_data|tab|" .. tab .. "\n" ..
                        "embed_data|confirmClaim|1\n" ..
                        "add_spacer|small|\n" ..
                        "add_textbox|By selecting claim, the items will be removed from your inventory and your reward will be added.|left|\n" ..
                        "add_spacer|small|\n" ..
                        "add_button|" .. btn .. "|Claim|noflags|0|0|\n" ..
                        "end_dialog|collectionQuests||Back|", 500
                    )
                    return true
                end
            end
            return true
        end

        if startsWith(btn, "info_") then
            local itemID = tonumber(btn:sub(6))
            local item   = itemID and getItem(itemID)
            if not item then return true end
            local infoArr = {}
            local itemInfo = item:getInfo()
            for _, info in ipairs(itemInfo) do
                infoArr[#infoArr+1] = "add_textbox|" .. info .. "|left|"
            end
            local tab = tostring(data["tab"] or "0"):sub(1, -2)
            player:onDialogRequest(
                "set_default_color|`o\n" ..
                "add_label_with_icon|big|`wAbout " .. item:getName() .. "``|left|" .. item:getID() .. "|\n" ..
                "embed_data|tab|" .. tab .. "\n" ..
                "add_spacer|small|\n" ..
                "add_textbox|" .. item:getDescription() .. "|left|\n" ..
                "add_spacer|small|\n" ..
                table.concat(infoArr, "\n") .. "\n" ..
                "end_dialog|collectionQuests|Close|Back|", 500
            )
            return true
        end

        if data["tab"] ~= nil then
            showMissions(world, player, tonumber(tostring(data["tab"]):sub(1, -2)) or 0)
            return true
        end

        return true
    end

    if dn == "playerProfile" then
        if btn == "marvelous_missions" then
            showMissions(world, player, MissionsCat.SEASON_1_MENU)
            return true
        end
        return false
    end

    return false
end)

-- Global export so player-profile can trigger it
_G.openMarvelousMissions = function(world, player)
    showMissions(world, player, MissionsCat.SEASON_1_MENU)
end

return M
