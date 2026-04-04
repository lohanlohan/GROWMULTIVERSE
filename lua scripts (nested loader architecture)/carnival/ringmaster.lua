-- MODULE
-- ringmaster.lua — Ringmaster NPC (Quest For Ring — 20 quest types, 10 steps)

local M = {}

-- ── Constants ─────────────────────────────────────────────────────────────────

local KEY_QUEST      = "RINGMASTER_QUEST_DATA_V2"
local KEY_CONFIG     = "RINGMASTER_CONFIG_DATA_V2"
local RINGMASTER_ID  = 1900
local DEVELOPER_ROLE = 51
local BYPASS_ROLE    = 8

-- ── State ─────────────────────────────────────────────────────────────────────

local RINGMASTER_QUEST  = {}
local RINGMASTER_CONFIG = {}

-- ── Default Config ────────────────────────────────────────────────────────────

local function getDefaultConfig()
    return {
        maxSteps           = 10,
        ringExchangeAmount = 5,
        startRequirements  = {
            { id = 1898, amount = 10 }
        },
        rewardRings = {
            { id = 1874 }, { id = 1876 }, { id = 1904 }, { id = 1932 },
            { id = 1986 }, { id = 1996 }, { id = 2970 }, { id = 3174 },
            { id = 6028 }, { id = 8962 }
        },
        deliverableItems = {
            { id = 552 },
            { id = 340 }
        },
        questRanges = {
            break_blocks      = { min = 100,  max = 1000  },
            harvest_trees     = { min = 1000, max = 10000 },
            plant_trees       = { min = 1000, max = 10000 },
            break_rarity      = { min = 500,  max = 5000  },
            plant_rarity      = { min = 500,  max = 5000  },
            harvest_provider  = { min = 50,   max = 500   },
            deliver_items     = { min = 1,    max = 100   },
            deliver_gems      = { min = 100,  max = 10000 },
            deliver_worldlocks= { min = 1,    max = 100   },
            earn_xp           = { min = 1000, max = 10000 },
            earn_gems         = { min = 100,  max = 5000  },
            perform_surgery   = { min = 1,    max = 50    },
            defeat_villain    = { min = 1,    max = 20    },
            shatter_crystal   = { min = 1,    max = 15    },
            find_geiger       = { min = 1,    max = 20    },
            catch_fish        = { min = 100,  max = 2000  },
            train_fish        = { min = 1,    max = 10    },
            earn_growtoken    = { min = 1,    max = 5     },
            catch_ghost       = { min = 1,    max = 20    },
            splice_dna        = { min = 1,    max = 50    }
        }
    }
end

-- ── Quest Definitions ─────────────────────────────────────────────────────────

local questDefinitions = {
    { id = "breaking_blocks",
      description = "add_textbox|`oListen up! I need you to absolutely demolish {break_blocks_goal} blocks for me — CRUSH them! I don't care if they're dirt, stone, or diamond — just get out there and smash everything in sight!``|left|\n",
      completeText = "I bashed them good!", notCompleteText = "Keep on smashing!",
      objectives = { { type = "break_blocks" } } },
    { id = "harvesting_trees",
      description = "add_textbox|`oHere's what I need: harvest a total of {harvest_trees_goal} rarity worth of fruit from those pesky trees! Pluck every last one and show nature who's in charge!``|left|\n",
      smallDescription = "add_smalltext|`o(Harvest a rarity-50 tree with 3 fruits = 150 points. Rarity × fruit count!)``|left|\n",
      completeText = "The fruit is no more!", notCompleteText = "I will go pick fruit!",
      objectives = { { type = "harvest_trees" } } },
    { id = "planting_trees",
      description = "add_textbox|`oYour task: plant trees with a combined rarity value of {plant_trees_goal} points. Mix and match different seeds and watch your garden flourish!``|left|\n",
      smallDescription = "add_smalltext|`o(Plant a rarity-50 tree = 50 points. Even Dirt Tree gives 1 point!)``|left|\n",
      completeText = "I planted them all!", notCompleteText = "I will go plant more!",
      objectives = { { type = "plant_trees" } } },
    { id = "breaking_blocks_rarity",
      description = "add_textbox|`oTime for serious destruction! Pulverize blocks worth a total rarity of {break_rarity_goal} points. Target rare, valuable blocks!``|left|\n",
      smallDescription = "add_smalltext|`o(Breaking a rarity-50 block = 50 points. Focus on rare materials!)``|left|\n",
      completeText = "No block can beat me!", notCompleteText = "I will go smash more!",
      objectives = { { type = "break_rarity" } } },
    { id = "planting_trees_rarity",
      description = "add_textbox|`oPlant premium trees with a combined rarity of {plant_rarity_goal} points. Rare seeds, exotic varieties — the trees that make other farmers jealous!``|left|\n",
      completeText = "Premium planting complete!", notCompleteText = "I will plant rare seeds!",
      objectives = { { type = "plant_rarity" } } },
    { id = "harvesting_providers",
      description = "add_textbox|`oTime to put those Provider blocks to work! Collect {harvest_provider_goal} items from any Provider-type blocks: Science Stations, Cows, Chickens, Weather Machines...``|left|\n",
      smallDescription = "add_smalltext|`o(Each successful provider harvest counts as 1 item.)``|left|\n",
      completeText = "I'm a cow-puncher!", notCompleteText = "I'm on my way!",
      objectives = { { type = "harvest_provider" } } },
    { id = "delivering_items",
      description = "add_textbox|`oI need {deliver_items_goal} of those wonderful {itemName} items! Bring me exactly what I'm asking for!``|left|\n",
      completeText = "Deliver Items", notCompleteText = "You have none!",
      objectives = { { type = "deliver_items" } } },
    { id = "delivering_gems",
      description = "add_textbox|`oI need {deliver_gems_goal} Gems. Cold, hard, sparkly currency! Share the wealth!``|left|\n",
      completeText = "Deliver Gems", notCompleteText = "You have none!",
      objectives = { { type = "deliver_gems" } } },
    { id = "delivering_worldlocks",
      description = "add_textbox|`oI need {deliver_worldlocks_goal} World Locks! Yes, the real deal — those blue beauties!``|left|\n",
      completeText = "Deliver World Locks", notCompleteText = "You have none!",
      objectives = { { type = "deliver_worldlocks" } } },
    { id = "earning_xp",
      description = "add_textbox|`oEarn a whopping {earn_xp_goal} XP. Break blocks, harvest trees, complete achievements — whatever gets you that sweet experience!``|left|\n",
      completeText = "I have learned!", notCompleteText = "I'm on my way!",
      objectives = { { type = "earn_xp" } } },
    { id = "earning_gems",
      description = "add_textbox|`oEarn {earn_gems_goal} Gems through good old-fashioned block breaking! Not trading — EARNING the hard way!``|left|\n",
      completeText = "I'm rich!", notCompleteText = "I'm farming gems!",
      objectives = { { type = "earn_gems" } } },
    { id = "performing_surgeries",
      description = "add_textbox|`oDoc, we need you! Perform {perform_surgery_goal} successful surgeries. The operating room awaits!``|left|\n",
      completeText = "Saving lives!", notCompleteText = "Keep helping!",
      objectives = { { type = "perform_surgery" } } },
    { id = "defeating_villains",
      description = "add_textbox|`oDefeat {defeat_villain_goal} villains who are terrorizing our lands! Show them that justice always prevails!``|left|\n",
      completeText = "My hero!", notCompleteText = "Keep fighting!",
      objectives = { { type = "defeat_villain" } } },
    { id = "shattering_crystals",
      description = "add_textbox|`oShatter {shatter_crystal_goal} crystals into a million pieces! The sound of shattering is music to my ears!``|left|\n",
      completeText = "All shattered!", notCompleteText = "Keep shattering!",
      objectives = { { type = "shatter_crystal" } } },
    { id = "using_geiger_counter",
      description = "add_textbox|`oBring out your Geiger Counter and track down {find_geiger_goal} radioactive items! Follow the radiation trail!``|left|\n",
      completeText = "These feel warm!", notCompleteText = "Keep searching!",
      objectives = { { type = "find_geiger" } } },
    { id = "fishing",
      description = "add_textbox|`oGrab your fishing rod and catch {catch_fish_goal} pounds of fish! Cast your line and reel in the big ones!``|left|\n",
      completeText = "I caught them!", notCompleteText = "Keep fishing!",
      objectives = { { type = "catch_fish" } } },
    { id = "training_fish",
      description = "add_textbox|`oTrain {train_fish_goal} fish to become the best they can be! Every trained fish is a testament to your patience!``|left|\n",
      completeText = "I trained them!", notCompleteText = "Train more fish!",
      objectives = { { type = "train_fish" } } },
    { id = "earning_growtokens",
      description = "add_textbox|`oEarn {earn_growtoken_goal} Growtokens through dedication and hard work! Show everyone you're exceptional!``|left|\n",
      completeText = "I am talented!", notCompleteText = "Keep questing!",
      objectives = { { type = "earn_growtoken" } } },
    { id = "catching_ghosts",
      description = "add_textbox|`oCatch {catch_ghost_goal} ghosts that are haunting our worlds! Track down those spooky spirits!``|left|\n",
      completeText = "Who you gonna call?", notCompleteText = "Ghost hunting!",
      objectives = { { type = "catch_ghost" } } },
    { id = "splicing_dna",
      description = "add_textbox|`oSplice together {splice_dna_goal} DNA strands! Head to your laboratory and create genetic masterpieces!``|left|\n",
      completeText = "I'm a scientist!", notCompleteText = "Keep splicing!",
      objectives = { { type = "splice_dna" } } },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function formatNumber(number)
    local formatted = tostring(number)
    local n
    while true do
        formatted, n = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if n == 0 then break end
    end
    return formatted
end

local function cleanName(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("`.", "")
    name = name:gsub("^@", "")
    name = name:gsub("%b[]", "")
    name = name:gsub("^Dr%.", "")
    name = name:gsub(" of Legend", "")
    name = name:gsub("_%d+$", "")
    name = name:gsub("%s+", "")
    return name
end

-- ── Data Management ───────────────────────────────────────────────────────────

local function saveRingmasterConfig()
    saveDataToServer(KEY_CONFIG, RINGMASTER_CONFIG)
end

local function loadRingmasterConfig()
    local data = loadDataFromServer(KEY_CONFIG)
    if data and type(data) == "table" then
        RINGMASTER_CONFIG = data
    else
        RINGMASTER_CONFIG = getDefaultConfig()
        saveRingmasterConfig()
    end
end

local function saveRingmasterQuestsData()
    saveDataToServer(KEY_QUEST, RINGMASTER_QUEST)
end

local function loadRingmasterQuestsData()
    local data = loadDataFromServer(KEY_QUEST)
    if data and type(data) == "table" then
        RINGMASTER_QUEST = data
    else
        RINGMASTER_QUEST = {}
    end
end

-- ── Quest Progress ────────────────────────────────────────────────────────────

local function addRingmasterQuestProgress(player, questType, amount)
    local userId = player:getUserID()
    local quest  = RINGMASTER_QUEST[userId]
    if not quest or not quest.objectives or not quest.objectives[questType] then return end

    local objective   = quest.objectives[questType]
    local oldProgress = objective.progress
    objective.progress = math.min(objective.progress + amount, objective.goal)

    if oldProgress < objective.goal and objective.progress >= objective.goal then
        if questType ~= "deliver_items" and questType ~= "deliver_gems" and questType ~= "deliver_worldlocks" then
            player:onConsoleMessage("`9Ring Quest task complete! Go tell the Ringmaster!")
            player:onTalkBubble(player:getNetID(), "`9Task complete!", 0)
        end
        quest.notified = true
    end
    saveRingmasterQuestsData()
end

-- ── Admin Dialog Builders ─────────────────────────────────────────────────────

local function buildAdminMainDialog()
    local cfg = RINGMASTER_CONFIG
    if not cfg or not cfg.startRequirements then
        cfg = getDefaultConfig()
        RINGMASTER_CONFIG = cfg
        saveRingmasterConfig()
    end
    return
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Ringmaster Admin``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_spacer|small|\n" ..
        "add_smalltext|`oMax Steps: `w" .. (cfg.maxSteps or 10) .. "``|left|\n" ..
        "add_smalltext|`oRing Exchange: `w" .. (cfg.ringExchangeAmount or 5) .. "``|left|\n" ..
        "add_smalltext|`oRequirements: `w" .. #(cfg.startRequirements or {}) .. "``|left|\n" ..
        "add_smalltext|`oReward Rings: `w" .. #(cfg.rewardRings or {}) .. "``|left|\n" ..
        "add_smalltext|`oDeliverables: `w" .. #(cfg.deliverableItems or {}) .. "``|left|\n" ..
        "add_spacer|small|\n" ..
        "add_button|adminEditBasic|`wBasic Settings``|noflags|0|0|\n" ..
        "add_button|adminEditRanges|`wQuest Ranges``|noflags|0|0|\n" ..
        "add_button|adminEditRewards|`wReward Rings``|noflags|0|0|\n" ..
        "add_button|adminEditRequirements|`wRequirements``|noflags|0|0|\n" ..
        "add_button|adminEditDeliverables|`wDeliverables``|noflags|0|0|\n" ..
        "add_spacer|small|\n" ..
        "add_button|adminResetConfig|`4Reset Config``|noflags|0|0|\n" ..
        "end_dialog|adminMainDialog|Close||"
end

local function buildAdminBasicDialog()
    local cfg = RINGMASTER_CONFIG
    return
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Basic Settings``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_spacer|small|\n" ..
        "add_text_input|maxSteps|Max Steps:|" .. cfg.maxSteps .. "|5|\n" ..
        "add_text_input|ringExchange|Ring Exchange:|" .. cfg.ringExchangeAmount .. "|3|\n" ..
        "add_spacer|small|\n" ..
        "end_dialog|adminBasicDialog|Back|Save|"
end

local function buildAdminRangesDialog()
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Quest Ranges``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_smalltext|`oSet min/max for each quest``|left|\n" ..
        "add_spacer|small|\n"

    local ranges = {
        { key = "break_blocks",       name = "Break Blocks"      },
        { key = "harvest_trees",      name = "Harvest Trees"     },
        { key = "plant_trees",        name = "Plant Trees"       },
        { key = "break_rarity",       name = "Break Rarity"      },
        { key = "plant_rarity",       name = "Plant Rarity"      },
        { key = "harvest_provider",   name = "Harvest Provider"  },
        { key = "deliver_items",      name = "Deliver Items"     },
        { key = "deliver_gems",       name = "Deliver Gems"      },
        { key = "deliver_worldlocks", name = "Deliver WLs"       },
        { key = "earn_xp",            name = "Earn XP"           },
        { key = "earn_gems",          name = "Earn Gems"         },
        { key = "perform_surgery",    name = "Surgery"           },
        { key = "defeat_villain",     name = "Defeat Villain"    },
        { key = "shatter_crystal",    name = "Shatter Crystal"   },
        { key = "find_geiger",        name = "Geiger"            },
        { key = "catch_fish",         name = "Catch Fish"        },
        { key = "train_fish",         name = "Train Fish"        },
        { key = "earn_growtoken",     name = "Earn GT"           },
        { key = "catch_ghost",        name = "Catch Ghost"       },
        { key = "splice_dna",         name = "Splice DNA"        },
    }

    for _, range in ipairs(ranges) do
        local r = cfg.questRanges[range.key]
        dialog = dialog ..
            "add_smalltext|`w" .. range.name .. "``|left|\n" ..
            "add_text_input|min_" .. range.key .. "|Min:|" .. r.min .. "|10|\n" ..
            "add_text_input|max_" .. range.key .. "|Max:|" .. r.max .. "|10|\n" ..
            "add_spacer|small|\n"
    end

    return dialog .. "end_dialog|adminRangesDialog|Back|Save|"
end

local function buildAdminRewardsDialog()
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Reward Rings``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_spacer|small|\n"

    for i, ring in ipairs(cfg.rewardRings) do
        local item = getItem(ring.id)
        local name = item and item:getName() or ("Item#" .. ring.id)
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. i .. ". " .. name .. "``|left|" .. ring.id .. "|\n" ..
            "add_button|adminRemoveReward_" .. i .. "|`4Remove``|noflags|0|0|\n"
    end

    return dialog ..
        "add_spacer|small|\n" ..
        "add_item_picker|addReward|`2Add Reward``|Choose ring|\n" ..
        "end_dialog|adminRewardsDialog|Back|Add|"
end

local function buildAdminRequirementsDialog()
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Requirements``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_spacer|small|\n"

    for i, req in ipairs(cfg.startRequirements) do
        local item = getItem(req.id)
        local name = item and item:getName() or ("Item#" .. req.id)
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. req.amount .. "x " .. name .. "``|left|" .. req.id .. "|\n" ..
            "add_text_input|reqAmount_" .. i .. "|Amount:|" .. req.amount .. "|5|\n" ..
            "add_button|adminRemoveReq_" .. i .. "|`4Remove``|noflags|0|0|\n" ..
            "add_spacer|small|\n"
    end

    return dialog ..
        "add_item_picker|addReq|`2Add Requirement``|Choose item|\n" ..
        "add_text_input|newReqAmount|Amount:|1|5|\n" ..
        "end_dialog|adminRequirementsDialog|Back|Add|"
end

local function buildAdminDeliverablesDialog()
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Deliverable Items``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_spacer|small|\n"

    for i, delItem in ipairs(cfg.deliverableItems) do
        local item = getItem(delItem.id)
        local name = item and item:getName() or ("Item#" .. delItem.id)
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. i .. ". " .. name .. "``|left|" .. delItem.id .. "|\n" ..
            "add_button|adminRemoveDel_" .. i .. "|`4Remove``|noflags|0|0|\n"
    end

    return dialog ..
        "add_spacer|small|\n" ..
        "add_item_picker|addDel|`2Add Deliverable``|Choose item|\n" ..
        "end_dialog|adminDeliverablesDialog|Back|Add|"
end

-- ── Player Dialog Builders ────────────────────────────────────────────────────

local function buildRingmasterFirstDialog(player)
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "add_default_color|`o\n" ..
        "add_label_with_icon|big|`9The Ringmaster``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_smalltext|`oCome one, come all! I am the Ringmaster. For 10 Golden Tickets, I might even tell you how to get a Ring of your own...``|left|\n" ..
        "add_spacer|small|\n"

    local hasRequirements = true
    local inventoryItems  = player:getInventoryItems()
    for _, req in ipairs(cfg.startRequirements) do
        local found = false
        for _, item in ipairs(inventoryItems) do
            if item:getItemID() == req.id and item:getItemCount() >= req.amount then
                found = true; break
            end
        end
        if not found then hasRequirements = false; break end
    end

    if hasRequirements then
        local reqText = ""
        for i, req in ipairs(cfg.startRequirements) do
            local item = getItem(req.id)
            local name = item and item:getName() or ("Item#" .. req.id)
            reqText = reqText .. req.amount .. "x " .. name
            if i < #cfg.startRequirements then reqText = reqText .. ", " end
        end
        dialog = dialog .. "add_button|ringmasterContinueDialog|`9Give " .. reqText .. "``|noflags|0|0|\n"
    else
        dialog = dialog .. "add_smalltext|`oYou need the `910 Golden Tickets`o to start a quest.``|left|\n"
    end

    if player:hasRole(DEVELOPER_ROLE) then
        dialog = dialog ..
            "add_spacer|small|\n" ..
            "add_button|devBypassQuest|`4[DEV] Bypass Quest``|noflags|0|0|\n"
    end

    dialog = dialog .. "add_spacer|small|\nend_dialog|ringmasterFirstDialog|Goodbye!||"
    player:onDialogRequest(dialog)
end

local function buildRingmasterSecondDialog()
    local cfg     = RINGMASTER_CONFIG
    local reqText = ""
    for i, req in ipairs(cfg.startRequirements) do
        local item = getItem(req.id)
        local name = item and item:getName() or ("Item#" .. req.id)
        reqText = reqText .. req.amount .. " " .. name
        if i < #cfg.startRequirements then reqText = reqText .. ", " end
    end
    return
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`9Quest For The Ring``|left|" .. RINGMASTER_ID .. "|\n" ..
        "add_smalltext|`oComplete " .. cfg.maxSteps .. " tasks for a random ring!``|left|\n" ..
        "add_smalltext|`oIf you quit, all progress is lost!``|left|\n" ..
        "add_smalltext|`oThere is no benefit to quitting, except that you can start over — not likely to be easier! You'll also have to pay again.``|left|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|`oReady to give " .. reqText .. "?``|left|\n" ..
        "end_dialog|ringmasterSecondDialog|No!|Yes!|"
end

local function buildRingmasterActiveQuestDialog(questData, player)
    local cfg    = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`9Quest For Ring``|left|" .. RINGMASTER_ID .. "|\n" ..
        string.format("add_smalltext|`o(Step %d/%d)``|left|\n", questData.step or 1, cfg.maxSteps) ..
        "add_spacer|small|\n" ..
        questData.description

    if questData.smallDescription then
        dialog = dialog .. questData.smallDescription
    end

    dialog = dialog .. "add_spacer|small|\n"

    local complete = true
    for _, objective in pairs(questData.objectives or {}) do
        if objective.progress < objective.goal then complete = false; break end
    end

    local baseQuest
    for _, quest in ipairs(questDefinitions) do
        if quest.id == questData.id then baseQuest = quest; break end
    end

    for _, objective in pairs(questData.objectives) do
        dialog = dialog ..
            string.format("add_smalltext|`o(Progress: %s/%s)``|left|\n",
                formatNumber(objective.progress or 0),
                formatNumber(objective.goal or 0))
    end

    if baseQuest then
        local deliverTypes = {
            delivering_items      = "deliver_items",
            delivering_gems       = "deliver_gems",
            delivering_worldlocks = "deliver_worldlocks",
        }
        local typeKey = deliverTypes[baseQuest.id]

        if typeKey then
            local objective = questData.objectives[typeKey]
            local owned, name = 0, ""

            if typeKey == "deliver_items" then
                local itemId = questData.itemID
                local item   = getItem(itemId)
                name = item and item:getName() or ("Item#" .. itemId)
                for _, invItem in ipairs(player:getInventoryItems()) do
                    if invItem:getItemID() == itemId then
                        owned = invItem:getItemCount(); break
                    end
                end
            elseif typeKey == "deliver_gems" then
                owned = player:getGems()
                name  = "Gems"
            elseif typeKey == "deliver_worldlocks" then
                for _, invItem in ipairs(player:getInventoryItems()) do
                    if invItem:getItemID() == 242 then
                        owned = invItem:getItemCount(); break
                    end
                end
                name = "World Lock"
            end

            if owned > 0 then
                local deliverable = math.min(owned, objective.goal - objective.progress)
                dialog = dialog ..
                    string.format("add_button|deliverItem|`oDeliver %s %s``|noflags|0|0|\n",
                        formatNumber(deliverable), name)
            else
                dialog = dialog .. "add_button|notCompleteStep|`oYou have none!``|noflags|0||\n"
            end
        else
            if complete then
                dialog = dialog .. string.format("add_button|completeStep|`o%s``|noflags|0|0|\n", baseQuest.completeText)
            else
                dialog = dialog .. string.format("add_button|notCompleteStep|`o%s``|noflags|0|0|\n", baseQuest.notCompleteText)
            end
        end
    end

    dialog = dialog .. "add_button|giveupQuest|`4Give up``|noflags|0|0|\n"

    if player:hasRole(BYPASS_ROLE) then
        dialog = dialog .. "add_button|bypassCurrentStep|`eBypass Current Step``|noflags|0|0|\n"
    end
    if player:hasRole(DEVELOPER_ROLE) then
        dialog = dialog .. "add_button|devCompleteQuest|`4[DEV] Complete Quest``|noflags|0|0|\n"
    end

    return dialog .. "add_spacer|small|\nend_dialog|ringmasterActiveQuestDialog|Close||"
end

-- ── Quest Completion ──────────────────────────────────────────────────────────

local function completeQuestStep(world, player)
    local userId = player:getUserID()
    local quest  = RINGMASTER_QUEST[userId]
    local cfg    = RINGMASTER_CONFIG
    if not quest then return end

    if (quest.step or 1) >= cfg.maxSteps then
        local reward    = cfg.rewardRings[math.random(1, #cfg.rewardRings)]
        local item      = getItem(reward.id)
        local ringName  = item and item:getName() or ("Item#" .. reward.id)

        player:onTextOverlay("`9Quest Complete!``")
        player:changeItem(reward.id, 1, 0)
        world:setClothing(player, reward.id)
        world:updateClothing(player)
        world:sendPlayerMessage(player, "/cheer")

        for _, p in pairs(world:getPlayers()) do
            p:onConsoleMessage("`9>> `w" .. cleanName(player:getName()) ..
                " `9completed Quest For Ring and earned " .. ringName .. "!``")
            p:onParticleEffect(90, player:getPosX(), player:getPosY(), 0, 0, 0)
        end

        RINGMASTER_QUEST[userId] = nil
        saveRingmasterQuestsData()
        return
    end

    local base        = questDefinitions[math.random(1, #questDefinitions)]
    local description = base.description
    local objectiveData = {}

    for _, objective in ipairs(base.objectives) do
        local range = cfg.questRanges[objective.type]
        local goal  = math.random(range.min, range.max)
        objectiveData[objective.type] = { goal = goal, progress = 0 }
        description = description:gsub("{" .. objective.type .. "_goal}", formatNumber(goal))
    end

    local itemID = nil
    if base.id == "delivering_items" then
        itemID = cfg.deliverableItems[math.random(1, #cfg.deliverableItems)].id
        local item = getItem(itemID)
        description = description:gsub("{itemName}", item and item:getName() or ("Item#" .. itemID))
    end

    RINGMASTER_QUEST[userId] = {
        id               = base.id,
        description      = description,
        smallDescription = base.smallDescription or nil,
        objectives       = objectiveData,
        notified         = false,
        itemID           = itemID,
        step             = (quest.step or 1) + 1
    }

    player:onTextOverlay("`9Quest step complete!``")
    saveRingmasterQuestsData()
    player:onDialogRequest(buildRingmasterActiveQuestDialog(RINGMASTER_QUEST[userId], player))
end

-- ── Tile Callbacks ────────────────────────────────────────────────────────────

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() ~= RINGMASTER_ID then return false end

    if player:hasRole(DEVELOPER_ROLE) then
        player:onDialogRequest(buildAdminMainDialog())
        return true
    end

    if player:getLevel() < 10 then
        player:onTalkBubble(player:getNetID(), "`wCome back at level 10!``", 0)
        return true
    end

    local activeQuest = RINGMASTER_QUEST[player:getUserID()]
    if activeQuest then
        player:onDialogRequest(buildRingmasterActiveQuestDialog(activeQuest, player))
    else
        buildRingmasterFirstDialog(player)
    end
    return true
end)

onTilePunchCallback(function(world, player, tile)
    if tile:getTileID() ~= RINGMASTER_ID then return false end

    if player:getLevel() < 10 then
        player:onTalkBubble(player:getNetID(), "`wCome back at level 10!``", 0)
        return true
    end

    local activeQuest = RINGMASTER_QUEST[player:getUserID()]
    if activeQuest then
        player:onDialogRequest(buildRingmasterActiveQuestDialog(activeQuest, player))
    else
        buildRingmasterFirstDialog(player)
    end

    if player:hasRole(DEVELOPER_ROLE) then return false end
    player:onTalkBubble(player:getNetID(), "`wI cannot break that!``", 0)
    return true
end)

-- ── Dialog Callback ───────────────────────────────────────────────────────────

onPlayerDialogCallback(function(world, player, data)
    local action = data["action"]
    local dialog = data["dialog_name"]
    local button = data["buttonClicked"]

    -- Admin dialogs
    if dialog == "adminMainDialog" then
        if button == "adminEditBasic" then
            player:onDialogRequest(buildAdminBasicDialog())
        elseif button == "adminEditRanges" then
            player:onDialogRequest(buildAdminRangesDialog())
        elseif button == "adminEditRewards" then
            player:onDialogRequest(buildAdminRewardsDialog())
        elseif button == "adminEditRequirements" then
            player:onDialogRequest(buildAdminRequirementsDialog())
        elseif button == "adminEditDeliverables" then
            player:onDialogRequest(buildAdminDeliverablesDialog())
        elseif button == "adminResetConfig" then
            RINGMASTER_CONFIG = getDefaultConfig()
            saveRingmasterConfig()
            player:onConsoleMessage("`2Configuration reset!")
            player:onDialogRequest(buildAdminMainDialog())
        end
        return true
    end

    if dialog == "adminBasicDialog" and action == "dialog_return" then
        local maxSteps    = tonumber(data["maxSteps"])
        local ringExchange = tonumber(data["ringExchange"])
        if maxSteps    and maxSteps    > 0 then RINGMASTER_CONFIG.maxSteps           = maxSteps    end
        if ringExchange and ringExchange > 0 then RINGMASTER_CONFIG.ringExchangeAmount = ringExchange end
        saveRingmasterConfig()
        player:onConsoleMessage("`2Settings saved!")
        player:onDialogRequest(buildAdminMainDialog())
        return true
    end

    if dialog == "adminRangesDialog" and action == "dialog_return" then
        for key in pairs(RINGMASTER_CONFIG.questRanges) do
            local minVal = tonumber(data["min_" .. key])
            local maxVal = tonumber(data["max_" .. key])
            if minVal and maxVal and minVal > 0 and maxVal >= minVal then
                RINGMASTER_CONFIG.questRanges[key].min = minVal
                RINGMASTER_CONFIG.questRanges[key].max = maxVal
            end
        end
        saveRingmasterConfig()
        player:onConsoleMessage("`2Quest ranges saved!")
        player:onDialogRequest(buildAdminMainDialog())
        return true
    end

    if dialog == "adminRewardsDialog" then
        if action == "dialog_return" and data["addReward"] then
            local itemId = tonumber(data["addReward"])
            if itemId then
                table.insert(RINGMASTER_CONFIG.rewardRings, { id = itemId })
                saveRingmasterConfig()
                player:onConsoleMessage("`2Reward added!")
            end
            player:onDialogRequest(buildAdminRewardsDialog())
            return true
        end
        if button and button:match("^adminRemoveReward_") then
            local idx = tonumber(button:match("adminRemoveReward_(%d+)"))
            if idx and RINGMASTER_CONFIG.rewardRings[idx] then
                table.remove(RINGMASTER_CONFIG.rewardRings, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Reward removed!")
                player:onDialogRequest(buildAdminRewardsDialog())
            end
            return true
        end
        return true
    end

    if dialog == "adminRequirementsDialog" then
        if action == "dialog_return" and data["addReq"] then
            local itemId = tonumber(data["addReq"])
            local amount = tonumber(data["newReqAmount"]) or 1
            if itemId and amount > 0 then
                table.insert(RINGMASTER_CONFIG.startRequirements, { id = itemId, amount = amount })
                saveRingmasterConfig()
                player:onConsoleMessage("`2Requirement added!")
            end
            player:onDialogRequest(buildAdminRequirementsDialog())
            return true
        end
        if button and button:match("^adminRemoveReq_") then
            local idx = tonumber(button:match("adminRemoveReq_(%d+)"))
            if idx and RINGMASTER_CONFIG.startRequirements[idx] then
                table.remove(RINGMASTER_CONFIG.startRequirements, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Requirement removed!")
                player:onDialogRequest(buildAdminRequirementsDialog())
            end
            return true
        end
        for i in ipairs(RINGMASTER_CONFIG.startRequirements) do
            local amount = tonumber(data["reqAmount_" .. i])
            if amount and amount > 0 then
                RINGMASTER_CONFIG.startRequirements[i].amount = amount
            end
        end
        saveRingmasterConfig()
        return true
    end

    if dialog == "adminDeliverablesDialog" then
        if action == "dialog_return" and data["addDel"] then
            local itemId = tonumber(data["addDel"])
            if itemId then
                table.insert(RINGMASTER_CONFIG.deliverableItems, { id = itemId })
                saveRingmasterConfig()
                player:onConsoleMessage("`2Deliverable added!")
            end
            player:onDialogRequest(buildAdminDeliverablesDialog())
            return true
        end
        if button and button:match("^adminRemoveDel_") then
            local idx = tonumber(button:match("adminRemoveDel_(%d+)"))
            if idx and RINGMASTER_CONFIG.deliverableItems[idx] then
                table.remove(RINGMASTER_CONFIG.deliverableItems, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Deliverable removed!")
                player:onDialogRequest(buildAdminDeliverablesDialog())
            end
            return true
        end
        return true
    end

    -- Player dialogs
    if dialog == "ringmasterFirstDialog" then
        if button == "ringmasterContinueDialog" then
            player:onDialogRequest(buildRingmasterSecondDialog())
        elseif button == "devBypassQuest" and player:hasRole(DEVELOPER_ROLE) then
            local reward = RINGMASTER_CONFIG.rewardRings[math.random(1, #RINGMASTER_CONFIG.rewardRings)]
            local item   = getItem(reward.id)
            player:changeItem(reward.id, 1, 0)
            world:setClothing(player, reward.id)
            world:updateClothing(player)
            player:onConsoleMessage("`4[DEV] Quest bypassed! Received " .. (item and item:getName() or ("Item#" .. reward.id)) .. "!")
            player:onTextOverlay("`4[DEV] Quest Bypassed!``")
        end
        return true
    end

    if dialog == "ringmasterSecondDialog" and action == "dialog_return" then
        local userId  = player:getUserID()
        local cfg     = RINGMASTER_CONFIG
        local invItems = player:getInventoryItems()

        for _, req in ipairs(cfg.startRequirements) do
            local found = false
            for _, item in ipairs(invItems) do
                if item:getItemID() == req.id and item:getItemCount() >= req.amount then
                    found = true; break
                end
            end
            if not found then
                player:onTalkBubble(player:getNetID(), "`wYou don't have the items!``", 0)
                return true
            end
        end

        for _, req in ipairs(cfg.startRequirements) do
            player:changeItem(req.id, -req.amount, 0)
        end

        local base        = questDefinitions[math.random(1, #questDefinitions)]
        local description = base.description
        local objectiveData = {}

        for _, objective in ipairs(base.objectives) do
            local range = cfg.questRanges[objective.type]
            local goal  = math.random(range.min, range.max)
            objectiveData[objective.type] = { goal = goal, progress = 0 }
            description = description:gsub("{" .. objective.type .. "_goal}", formatNumber(goal))
        end

        local itemID = nil
        if base.id == "delivering_items" then
            itemID = cfg.deliverableItems[math.random(1, #cfg.deliverableItems)].id
            local item = getItem(itemID)
            description = description:gsub("{itemName}", item and item:getName() or ("Item#" .. itemID))
        end

        RINGMASTER_QUEST[userId] = {
            id               = base.id,
            description      = description,
            smallDescription = base.smallDescription or nil,
            objectives       = objectiveData,
            notified         = false,
            step             = 1,
            itemID           = itemID,
        }

        player:onTalkBubble(player:getNetID(), "`wThe Ringmaster collects your items!``", 0)
        saveRingmasterQuestsData()
        player:onDialogRequest(buildRingmasterActiveQuestDialog(RINGMASTER_QUEST[userId], player))
        return true
    end

    if dialog == "ringmasterActiveQuestDialog" then
        if button == "giveupQuest" then
            RINGMASTER_QUEST[player:getUserID()] = nil
            saveRingmasterQuestsData()
            player:onTextOverlay("`9Quest abandoned!``")
        elseif button == "notCompleteStep" then
            player:onTextOverlay("`9Good luck!``")
        elseif button == "completeStep" then
            completeQuestStep(world, player)
        elseif button == "bypassCurrentStep" and player:hasRole(BYPASS_ROLE) then
            player:onTextOverlay("`eStep Bypassed!``")
            completeQuestStep(world, player)
        elseif button == "devCompleteQuest" and player:hasRole(DEVELOPER_ROLE) then
            local userId = player:getUserID()
            local reward = RINGMASTER_CONFIG.rewardRings[math.random(1, #RINGMASTER_CONFIG.rewardRings)]
            local item   = getItem(reward.id)
            player:onTextOverlay("`4[DEV] Quest Force Completed!``")
            player:changeItem(reward.id, 1, 0)
            world:setClothing(player, reward.id)
            world:updateClothing(player)
            player:onConsoleMessage("`4[DEV] Received " .. (item and item:getName() or ("Item#" .. reward.id)) .. "!")
            RINGMASTER_QUEST[userId] = nil
            saveRingmasterQuestsData()
        elseif button == "deliverItem" then
            local userId = player:getUserID()
            local quest  = RINGMASTER_QUEST[userId]
            if not quest then return true end

            local typeMap = {
                delivering_items      = "deliver_items",
                delivering_gems       = "deliver_gems",
                delivering_worldlocks = "deliver_worldlocks",
            }
            local typeKey = typeMap[quest.id]
            if not typeKey then return true end

            local objective    = quest.objectives[typeKey]
            local deliverAmount = 0

            if typeKey == "deliver_items" then
                local itemId = quest.itemID
                for _, invItem in ipairs(player:getInventoryItems()) do
                    if invItem:getItemID() == itemId then
                        deliverAmount = math.min(invItem:getItemCount(), objective.goal - objective.progress)
                        if deliverAmount > 0 then player:changeItem(itemId, -deliverAmount, 0) end
                        break
                    end
                end
            elseif typeKey == "deliver_gems" then
                local gems = player:getGems()
                deliverAmount = math.min(gems, objective.goal - objective.progress)
                if deliverAmount > 0 then player:removeGems(deliverAmount, 1, 0) end
            elseif typeKey == "deliver_worldlocks" then
                for _, invItem in ipairs(player:getInventoryItems()) do
                    if invItem:getItemID() == 242 then
                        deliverAmount = math.min(invItem:getItemCount(), objective.goal - objective.progress)
                        if deliverAmount > 0 then player:changeItem(242, -deliverAmount, 0) end
                        break
                    end
                end
            end

            addRingmasterQuestProgress(player, typeKey, deliverAmount)

            if objective.progress >= objective.goal then
                completeQuestStep(world, player)
            else
                player:onTextOverlay("`9Thanks, keep it coming!``")
            end
        end
        return true
    end

    return false
end)

-- ── Progress Callbacks ────────────────────────────────────────────────────────

onTileBreakCallback(function(world, player, tile)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["break_blocks"] then
        addRingmasterQuestProgress(player, "break_blocks", 1)
    end
    if quest.objectives["break_rarity"] then
        local item   = getItem(tile:getTileID())
        local rarity = item and item:getRarity() or 0
        if rarity > 0 then addRingmasterQuestProgress(player, "break_rarity", rarity) end
    end
end)

onPlayerHarvestCallback(function(world, player, tile)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["harvest_trees"] then
        local item   = getItem(tile:getTileID())
        local rarity = item and item:getRarity() or 0
        if rarity > 0 then addRingmasterQuestProgress(player, "harvest_trees", rarity) end
    end
end)

onPlayerPlantCallback(function(world, player, tile)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    local item   = getItem(tile:getTileID())
    local rarity = item and item:getRarity() or 0
    if rarity > 0 then
        if quest.objectives["plant_trees"]  then addRingmasterQuestProgress(player, "plant_trees",  rarity) end
        if quest.objectives["plant_rarity"] then addRingmasterQuestProgress(player, "plant_rarity", rarity) end
    end
end)

onPlayerXPCallback(function(world, player, amount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["earn_xp"] then addRingmasterQuestProgress(player, "earn_xp", amount) end
end)

onPlayerGemsObtainedCallback(function(world, player, amount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["earn_gems"] then addRingmasterQuestProgress(player, "earn_gems", amount) end
end)

onPlayerSurgeryCallback(function(world, player, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["perform_surgery"] then addRingmasterQuestProgress(player, "perform_surgery", 1) end
end)

onPlayerProviderCallback(function(world, player, tile, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["harvest_provider"] then addRingmasterQuestProgress(player, "harvest_provider", itemCount) end
end)

onPlayerEarnGrowtokenCallback(function(world, player, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["earn_growtoken"] then addRingmasterQuestProgress(player, "earn_growtoken", itemCount) end
end)

onPlayerCrimeCallback(function(world, player, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["defeat_villain"] then addRingmasterQuestProgress(player, "defeat_villain", 1) end
end)

onPlayerHarmonicCallback(function(world, player, tile, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["shatter_crystal"] then addRingmasterQuestProgress(player, "shatter_crystal", 1) end
end)

onPlayerGeigerCallback(function(world, player, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["find_geiger"] then addRingmasterQuestProgress(player, "find_geiger", 1) end
end)

onPlayerCatchFishCallback(function(world, player, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["catch_fish"] then addRingmasterQuestProgress(player, "catch_fish", itemCount) end
end)

onPlayerTrainFishCallback(function(world, player)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["train_fish"] then addRingmasterQuestProgress(player, "train_fish", 1) end
end)

onPlayerCatchGhostCallback(function(world, player, itemID, itemCount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["catch_ghost"] then addRingmasterQuestProgress(player, "catch_ghost", 1) end
end)

onPlayerDNACallback(function(world, player, resultID, resultAmount)
    local quest = RINGMASTER_QUEST[player:getUserID()]
    if not quest then return end
    if quest.objectives["splice_dna"] then addRingmasterQuestProgress(player, "splice_dna", 1) end
end)

-- ── Init ──────────────────────────────────────────────────────────────────────

loadRingmasterQuestsData()
loadRingmasterConfig()

return M
