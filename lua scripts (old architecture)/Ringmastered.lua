-- Storage Keys
local KEY_QUEST = "RINGMASTER_QUEST_DATA_V2"
local KEY_CONFIG = "RINGMASTER_CONFIG_DATA_V2"

-- Runtime Data
local RINGMASTER_QUEST = {}
local RINGMASTER_CONFIG = {}
local SELECTED_RING = {}

local ringmasterId = 1900
local DEVELOPER_ROLE = 51
local BYPASS_ROLE = 8

-- Default Configuration
local function getDefaultConfig()
    return {
        maxSteps = 10,
        ringExchangeAmount = 5,
        startRequirements = {
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
            break_blocks = { min = 100, max = 1000 },
            harvest_trees = { min = 1000, max = 10000 },
            plant_trees = { min = 1000, max = 10000 },
            break_rarity = { min = 500, max = 5000 },
            plant_rarity = { min = 500, max = 5000 },
            harvest_provider = { min = 50, max = 500 },
            deliver_items = { min = 1, max = 100 },
            deliver_gems = { min = 100, max = 10000 },
            deliver_worldlocks = { min = 1, max = 100 },
            earn_xp = { min = 1000, max = 10000 },
            earn_gems = { min = 100, max = 5000 },
            perform_surgery = { min = 1, max = 50 },
            defeat_villain = { min = 1, max = 20 },
            shatter_crystal = { min = 1, max = 15 },
            find_geiger = { min = 1, max = 20 },
            catch_fish = { min = 100, max = 2000 },
            train_fish = { min = 1, max = 10 },
            earn_growtoken = { min = 1, max = 5 },
            catch_ghost = { min = 1, max = 20 },
            splice_dna = { min = 1, max = 50 }
        }
    }
end

-- Quest Definitions
local questDefinitions = {
    {
    id = "breaking_blocks",
    description = "add_textbox|`oListen up! I need you to absolutely demolish {break_blocks_goal} blocks for me - and I mean CRUSH them! I don't care if they're dirt, stone, or diamond - just get out there and smash everything in sight! Show those blocks who's boss!``|left|\n",
    completeText = "I bashed them good!",
    notCompleteText = "Keep on smashing!",
    objectives = { { type = "break_blocks" } }
},
{
    id = "harvesting_trees",
    description = "add_textbox|`oHere's what I need from you: harvest a total of {harvest_trees_goal} rarity worth of fruit from those pesky trees! I'm not interested in eating the fruit myself - I'm just absolutely furious that it's hanging up there, mocking us! Pluck every last one of them and show nature who's in charge!``|left|\n",
    smallDescription = "add_smalltext|`o(Here's how it works: If you harvest a rarity-50 tree that has 3 fruits on it, you'll earn 150 points total! The rarity multiplies with the fruit count, so aim for those high-rarity trees!)``|left|\n",
    completeText = "The fruit is no more!",
    notCompleteText = "I will go pick fruit!",
    objectives = { { type = "harvest_trees" } }
},
{
    id = "planting_trees",
    description = "add_textbox|`oI've got a special mission for you, gardener! Your task is to plant trees with a combined rarity value of {plant_trees_goal} points. Get creative with it - mix and match different seeds, experiment with rare varieties, and watch your garden flourish! Every seed counts toward your goal!``|left|\n",
    smallDescription = "add_smalltext|`o(The rarity system is simple: Plant a rarity-50 tree and earn 50 points instantly! Even a humble Dirt Tree gives you 1 point since it's rarity 1. Strategy tip: Balance between planting many cheap seeds or fewer expensive ones!)``|left|\n",
    completeText = "I planted them all!",
    notCompleteText = "I will go plant more!",
    objectives = { { type = "plant_trees" } }
},
{
    id = "breaking_blocks_rarity",
    description = "add_textbox|`oTime for some serious destruction! I need you to pulverize blocks worth a total rarity value of {break_rarity_goal} points. This isn't just about quantity - it's about the QUALITY of your destruction! Target those rare, valuable blocks and watch your score skyrocket! Unleash your inner demolition expert!``|left|\n",
    smallDescription = "add_smalltext|`o(Pro tip: Breaking a single rarity-50 block awards 50 points, while a basic Dirt block only gives 1 point. Focus on breaking rare materials like Chandeliers, Neon Blocks, or other high-rarity items for maximum efficiency!)``|left|\n",
    completeText = "No block can beat me!",
    notCompleteText = "I will go smash more!",
    objectives = { { type = "break_rarity" } }
},
{
    id = "planting_trees_rarity",
    description = "add_textbox|`oHere's a challenge for true farmers! I want you to plant premium, high-quality trees with a combined rarity value of {plant_rarity_goal} points. This isn't about planting dirt seeds - we're talking about the good stuff! Rare seeds, exotic varieties, the trees that make other farmers jealous! Show me what you're made of!``|left|\n",
    completeText = "Premium planting complete!",
    notCompleteText = "I will plant rare seeds!",
    objectives = { { type = "plant_rarity" } }
},
{
    id = "harvesting_providers",
    description = "add_textbox|`oTime to put those Provider blocks to work! I need you to collect a total of {harvest_provider_goal} items from any Provider-type blocks you can find. That includes Science Stations, Cows, Chickens, Weather Machines - you name it! Get out there, punch those providers, and bring home the goods! Every item counts!``|left|\n",
    smallDescription = "add_smalltext|`o(Provider blocks include: Science Stations, Cows, Chickens, Weather Machines, Silkworms, and many more! Each successful harvest counts as one item toward your goal, regardless of what the provider gives you.)``|left|\n",
    completeText = "I'm a cow-puncher!",
    notCompleteText = "I'm on my way!",
    objectives = { { type = "harvest_provider" } }
},
{
    id = "delivering_items",
    description = "add_textbox|`oAlright, listen carefully! I've got a very specific need right now, and that need is for {deliver_items_goal} of those wonderful {itemName} items! I don't care how you get them - farm them, trade for them, dig them up from your storage - just bring me exactly what I'm asking for! Time's ticking!``|left|\n",
    completeText = "Deliver Items",
    notCompleteText = "You have none!",
    objectives = { { type = "deliver_items" } }
},
{
    id = "delivering_gems",
    description = "add_textbox|`oLet's talk business! I need you to grease my palm with a generous donation of {deliver_gems_goal} Gems. That's right - cold, hard, sparkly currency! I know you've been breaking blocks and stashing away those gems, so now's the time to share the wealth! Don't be stingy now!``|left|\n",
    completeText = "Deliver Gems",
    notCompleteText = "You have none!",
    objectives = { { type = "deliver_gems" } }
},
{
    id = "delivering_worldlocks",
    description = "add_textbox|`oHere's what I need from you, and it's not negotiable: {deliver_worldlocks_goal} World Locks! Yes, the real deal - those blue beauties that everyone loves! I know they're valuable, but this is important! Raid your storage, check your inventory, and bring me those locks! Your contribution won't be forgotten!``|left|\n",
    completeText = "Deliver World Locks",
    notCompleteText = "You have none!",
    objectives = { { type = "deliver_worldlocks" } }
},
{
    id = "earning_xp",
    description = "add_textbox|`oTime to level up your game! I want you to earn a whopping {earn_xp_goal} XP, and I don't care how you do it! Break blocks, harvest trees, complete achievements, help other players - whatever gets you that sweet experience! Show me that you're dedicated to self-improvement and growth! Every action counts!``|left|\n",
    completeText = "I have learned!",
    notCompleteText = "I'm on my way!",
    objectives = { { type = "earn_xp" } }
},
{
    id = "earning_gems",
    description = "add_textbox|`oGet ready to get rich! Your mission is to earn {earn_gems_goal} Gems through good old-fashioned block breaking! Not trading, not buying - EARNING them the hard way! Find yourself a nice farming world, grab your pickaxe, and start smashing! Those gems won't collect themselves! Time to make it rain!``|left|\n",
    completeText = "I'm rich!",
    notCompleteText = "I'm farming gems!",
    objectives = { { type = "earn_gems" } }
},
{
    id = "performing_surgeries",
    description = "add_textbox|`oDoc, we need you! There are {perform_surgery_goal} Growtopians out there who desperately need your medical expertise! Grab your surgical tools, scrub in, and start saving lives! Every successful surgery makes the world a better place. You've got the skills - now use them! The operating room awaits!``|left|\n",
    completeText = "Saving lives!",
    notCompleteText = "Keep helping!",
    objectives = { { type = "perform_surgery" } }
},
{
    id = "defeating_villains",
    description = "add_textbox|`oThe world needs a hero, and that hero is YOU! I need you to defeat a total of {defeat_villain_goal} villains who are terrorizing our peaceful lands! Track them down, challenge them to battle, and show them that justice always prevails! Every villain defeated makes Growtopia safer for everyone! Are you ready to be a champion?``|left|\n",
    completeText = "My hero!",
    notCompleteText = "Keep fighting!",
    objectives = { { type = "defeat_villain" } }
},
{
    id = "shattering_crystals",
    description = "add_textbox|`oI need someone with a strong arm and a steady aim! Your quest is to shatter {shatter_crystal_goal} crystals into a million pieces! Find those crystalline structures, wind up your punch, and let 'em have it! The sound of shattering crystals is music to my ears! Don't stop until every last crystal is pulverized!``|left|\n",
    completeText = "All shattered!",
    notCompleteText = "Keep shattering!",
    objectives = { { type = "shatter_crystal" } }
},
{
    id = "using_geiger_counter",
    description = "add_textbox|`oAttention all treasure hunters! I need you to break out your Geiger Counter and track down {find_geiger_goal} radioactive items scattered across the worlds! Listen for those telltale clicks and beeps, follow the radiation trail, and collect those glowing treasures! It's like a treasure hunt, but with more radiation! Stay safe out there!``|left|\n",
    completeText = "These feel warm!",
    notCompleteText = "Keep searching!",
    objectives = { { type = "find_geiger" } }
},
{
    id = "fishing",
    description = "add_textbox|`oGrab your fishing rod and head to the nearest body of water! Your goal is to catch a whopping {catch_fish_goal} pounds of fish! That's right - pounds! Cast your line, wait for that bite, and reel in the big ones! Whether it's Grumpy Fish, Angelfish, or legendary catches, every pound counts toward your goal! Time to show off those fishing skills!``|left|\n",
    completeText = "I caught them!",
    notCompleteText = "Keep fishing!",
    objectives = { { type = "catch_fish" } }
},
{
    id = "training_fish",
    description = "add_textbox|`oHere's something special for you fish enthusiasts! I need you to train a total of {train_fish_goal} fish to become the best they can be! Take those aquatic friends, put them through their paces, and help them reach their full potential! Every trained fish is a testament to your dedication and patience! Ready to become a fish trainer extraordinaire?``|left|\n",
    completeText = "I trained them!",
    notCompleteText = "Train more fish!",
    objectives = { { type = "train_fish" } }
},
{
    id = "earning_growtokens",
    description = "add_textbox|`oTime to prove your worth! Your mission is to earn {earn_growtoken_goal} Growtokens through dedication, skill, and hard work! Complete quests, achieve milestones, help the community - whatever it takes to rack up those precious tokens! This is your chance to show everyone that you're not just any player - you're exceptional! Let's see that token count rise!``|left|\n",
    completeText = "I am talented!",
    notCompleteText = "Keep questing!",
    objectives = { { type = "earn_growtoken" } }
},
{
    id = "catching_ghosts",
    description = "add_textbox|`oWho you gonna call? YOU, apparently! I need a professional ghost hunter to catch {catch_ghost_goal} ghosts that are haunting our worlds! Equip your ghost-catching gear, track down those spooky spirits, and trap them before they cause any more mischief! Don't be afraid - they're more scared of you than you are of them! Probably. Maybe. Good luck!``|left|\n",
    completeText = "Who you gonna call?",
    notCompleteText = "Ghost hunting!",
    objectives = { { type = "catch_ghost" } }
},
{
    id = "splicing_dna",
    description = "add_textbox|`oAttention all scientists and mad experimenters! I have a genetic challenge for you: splice together {splice_dna_goal} DNA strands! Head to your laboratory, fire up that DNA Processor, and start creating genetic masterpieces! Mix and match those chromosomes, experiment with different combinations, and push the boundaries of science! Remember: with great power comes great responsibility... but mostly just great DNA!``|left|\n",
    completeText = "I'm a scientist!",
    notCompleteText = "Keep splicing!",
    objectives = { { type = "splice_dna" } }
}
}

-- Helper Functions
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

-- Data Management
local function loadRingmasterQuestsData()
    local data = loadDataFromServer(KEY_QUEST)
    if data and type(data) == "table" then
        RINGMASTER_QUEST = data
    else
        RINGMASTER_QUEST = {}
    end
end

local function saveRingmasterQuestsData()
    saveDataToServer(KEY_QUEST, RINGMASTER_QUEST)
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

local function saveRingmasterConfig()
    saveDataToServer(KEY_CONFIG, RINGMASTER_CONFIG)
end

-- Quest Progress
local function addRingmasterQuestProgress(player, type, amount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]

    if not quest or not quest.objectives or not quest.objectives[type] then return end

    local objective = quest.objectives[type]
    local oldProgress = objective.progress
    objective.progress = math.min(objective.progress + amount, objective.goal)

    if oldProgress < objective.goal and objective.progress >= objective.goal then
        if type ~= "deliver_items" and type ~= "deliver_gems" and type ~= "deliver_worldlocks" then
            player:onConsoleMessage("`9Ring Quest task complete! Go tell the Ringmaster!")
            player:onTalkBubble(player:getNetID(), "`9Task complete!", 0)
        end
        quest.notified = true
    end
    saveRingmasterQuestsData()
end

-- Admin Dialog Builders
local function buildAdminMainDialog()
    local cfg = RINGMASTER_CONFIG
    -- Ensure config is loaded
    if not cfg or not cfg.startRequirements then
        cfg = getDefaultConfig()
        RINGMASTER_CONFIG = cfg
        saveRingmasterConfig()
    end
    
    return
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Ringmaster Admin``|left|" .. ringmasterId .. "|\n" ..
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
        "add_label_with_icon|big|`4Basic Settings``|left|" .. ringmasterId .. "|\n" ..
        "add_spacer|small|\n" ..
        "add_text_input|maxSteps|Max Steps:|" .. cfg.maxSteps .. "|5|\n" ..
        "add_text_input|ringExchange|Ring Exchange:|" .. cfg.ringExchangeAmount .. "|3|\n" ..
        "add_spacer|small|\n" ..
        "end_dialog|adminBasicDialog|Back|Save|"
end

local function buildAdminRangesDialog()
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Quest Ranges``|left|" .. ringmasterId .. "|\n" ..
        "add_smalltext|`oSet min/max for each quest``|left|\n" ..
        "add_spacer|small|\n"
    
    local ranges = {
        { key = "break_blocks", name = "Break Blocks" },
        { key = "harvest_trees", name = "Harvest Trees" },
        { key = "plant_trees", name = "Plant Trees" },
        { key = "break_rarity", name = "Break Rarity" },
        { key = "plant_rarity", name = "Plant Rarity" },
        { key = "harvest_provider", name = "Harvest Provider" },
        { key = "deliver_items", name = "Deliver Items" },
        { key = "deliver_gems", name = "Deliver Gems" },
        { key = "deliver_worldlocks", name = "Deliver WLs" },
        { key = "earn_xp", name = "Earn XP" },
        { key = "earn_gems", name = "Earn Gems" },
        { key = "perform_surgery", name = "Surgery" },
        { key = "defeat_villain", name = "Defeat Villain" },
        { key = "shatter_crystal", name = "Shatter Crystal" },
        { key = "find_geiger", name = "Geiger" },
        { key = "catch_fish", name = "Catch Fish" },
        { key = "train_fish", name = "Train Fish" },
        { key = "earn_growtoken", name = "Earn GT" },
        { key = "catch_ghost", name = "Catch Ghost" },
        { key = "splice_dna", name = "Splice DNA" }
    }

    for _, range in ipairs(ranges) do
        local r = cfg.questRanges[range.key]
        dialog = dialog ..
            "add_smalltext|`w" .. range.name .. "``|left|\n" ..
            "add_text_input|min_" .. range.key .. "|Min:|" .. r.min .. "|10|\n" ..
            "add_text_input|max_" .. range.key .. "|Max:|" .. r.max .. "|10|\n" ..
            "add_spacer|small|\n"
    end

    dialog = dialog .. "end_dialog|adminRangesDialog|Back|Save|"
    return dialog
end

local function buildAdminRewardsDialog()
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Reward Rings``|left|" .. ringmasterId .. "|\n" ..
        "add_spacer|small|\n"
    
    for i, ring in ipairs(cfg.rewardRings) do
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. i .. ". " .. getItem(ring.id):getName() .. "``|left|" .. ring.id .. "|\n" ..
            "add_button|adminRemoveReward_" .. i .. "|`4Remove``|noflags|0|0|\n"
    end

    dialog = dialog ..
        "add_spacer|small|\n" ..
        "add_item_picker|addReward|`2Add Reward``|Choose ring|\n" ..
        "end_dialog|adminRewardsDialog|Back|Add|"
    return dialog
end

local function buildAdminRequirementsDialog()
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Requirements``|left|" .. ringmasterId .. "|\n" ..
        "add_spacer|small|\n"
    
    for i, req in ipairs(cfg.startRequirements) do
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. req.amount .. "x " .. getItem(req.id):getName() .. "``|left|" .. req.id .. "|\n" ..
            "add_text_input|reqAmount_" .. i .. "|Amount:|" .. req.amount .. "|5|\n" ..
            "add_button|adminRemoveReq_" .. i .. "|`4Remove``|noflags|0|0|\n" ..
            "add_spacer|small|\n"
    end

    dialog = dialog ..
        "add_item_picker|addReq|`2Add Requirement``|Choose item|\n" ..
        "add_text_input|newReqAmount|Amount:|1|5|\n" ..
        "end_dialog|adminRequirementsDialog|Back|Add|"
    return dialog
end

local function buildAdminDeliverablesDialog()
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`4Deliverable Items``|left|" .. ringmasterId .. "|\n" ..
        "add_spacer|small|\n"
    
    for i, item in ipairs(cfg.deliverableItems) do
        dialog = dialog ..
            "add_label_with_icon|small|`o" .. i .. ". " .. getItem(item.id):getName() .. "``|left|" .. item.id .. "|\n" ..
            "add_button|adminRemoveDel_" .. i .. "|`4Remove``|noflags|0|0|\n"
    end

    dialog = dialog ..
        "add_spacer|small|\n" ..
        "add_item_picker|addDel|`2Add Deliverable``|Choose item|\n" ..
        "end_dialog|adminDeliverablesDialog|Back|Add|"
    return dialog
end

-- Player Dialog Builders
local function buildRingmasterFirstDialog(player)
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "add_default_color|`o\n" ..
        "add_label_with_icon|big|`9The Scammaster``|left|" .. ringmasterId .. "|\n" ..
        "add_smalltext|`oCome one, come all, to the most extraordinary show in Growtopia! I am the Ringmaster. That means I know a lot about Rings! For 10 Golden Tickets, I might even tell you how you can get a Ring of your own...``|left|\n" ..
        "add_spacer|small|\n"

    local hasRequirements = true
    local inventoryItems = player:getInventoryItems()
    
    for _, req in ipairs(cfg.startRequirements) do
        local hasItem = false
        for _, item in ipairs(inventoryItems) do
            if item:getItemID() == req.id and item:getItemCount() >= req.amount then
                hasItem = true
                break
            end
        end
        if not hasItem then
            hasRequirements = false
            break
        end
    end

    if hasRequirements then
        local reqText = ""
        for i, req in ipairs(cfg.startRequirements) do
            reqText = reqText .. req.amount .. "x " .. getItem(req.id):getName()
            if i < #cfg.startRequirements then reqText = reqText .. ", " end
        end
        dialog = dialog ..
            "add_button|ringmasterContinueDialog|`9Give " .. reqText .. "``|noflags|0|0|\n"
    else
        dialog = dialog .. "add_smalltext|`oYou need the `910 Golden Tickets`o to start a quest.``|left|\n"
    end

    -- Developer bypass button (only for role 51, only when no quest)
    if player:hasRole(DEVELOPER_ROLE) then
        dialog = dialog ..
            "add_spacer|small|\n" ..
            "add_button|devBypassQuest|`4[DEV] Bypass Quest``|noflags|0|0|\n"
    end

    dialog = dialog .. "add_spacer|small|\nend_dialog|ringmasterFirstDialog|Goodbye!||"
    player:onDialogRequest(dialog)
end

local function buildRingmasterSecondDialog()
    local cfg = RINGMASTER_CONFIG
    local reqText = ""
    for i, req in ipairs(cfg.startRequirements) do
        reqText = reqText .. req.amount .. " " .. getItem(req.id):getName()
        if i < #cfg.startRequirements then reqText = reqText .. ", " end
    end

    return
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`9Quest For The Ring``|left|" .. ringmasterId .. "|\n" ..
        "add_smalltext|`oComplete " .. cfg.maxSteps .. " tasks for a random ring!``|left|\n" ..
        "add_smalltext|`oIf you quit, all progress is lost!``|left|\n" ..
        "add_smalltext|`oThere is no benefit to quitting the Ring Quest, except that you can start over and hope for easier tasks (not likely!). You'll also have to pay 10 more Golden Tickets when you start again.``|left|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|`oReady to give " .. reqText .. "?``|left|\n" ..
        "end_dialog|ringmasterSecondDialog|No!|Yes!|"
end

local function buildRingmasterActiveQuestDialog(questData, player)
    local cfg = RINGMASTER_CONFIG
    local dialog =
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`9Quest For Ring``|left|" .. ringmasterId .. "|\n" ..
        string.format("add_smalltext|`o(Step %d/%d)``|left|\n", questData.step or 1, cfg.maxSteps) ..
        "add_spacer|small|\n" ..
        questData.description

    if questData.smallDescription then
        dialog = dialog .. questData.smallDescription
    end

    dialog = dialog .. "add_spacer|small|\n"

    local complete = true
    for _, objective in pairs(questData.objectives or {}) do
        if objective.progress < objective.goal then
            complete = false
            break
        end
    end

    local baseQuest
    for _, quest in ipairs(questDefinitions) do
        if quest.id == questData.id then
            baseQuest = quest
            break
        end
    end

    for _, objective in pairs(questData.objectives) do
        dialog = dialog ..
            string.format("add_smalltext|`o(Progress: %s/%s)``|left|\n", 
                formatNumber(objective.progress or 0),
                formatNumber(objective.goal or 0))
    end

    if baseQuest then
        if baseQuest.id == "delivering_items" or baseQuest.id == "delivering_gems" or baseQuest.id == "delivering_worldlocks" then
            local typeKey = baseQuest.objectives[1].type
            local objective = questData.objectives[typeKey]
            local owned, name = 0, ""

            if typeKey == "deliver_items" then
                local itemId = questData.itemID
                name = getItem(itemId):getName()
                for _, item in ipairs(player:getInventoryItems()) do
                    if item:getItemID() == itemId then
                        owned = item:getItemCount()
                        break
                    end
                end
            elseif typeKey == "deliver_gems" then
                owned = player:getGems()
                name = "Gems"
            elseif typeKey == "deliver_worldlocks" then
                for _, item in ipairs(player:getInventoryItems()) do
                    if item:getItemID() == 242 then
                        owned = item:getItemCount()
                        break
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
    
    -- Bypass button for role 8 (skip current step only)
    if player:hasRole(BYPASS_ROLE) then
        dialog = dialog .. "add_button|bypassCurrentStep|`eBypass Current Step``|noflags|0|0|\n"
    end

    -- Developer complete button for role 51 (complete entire quest)
    if player:hasRole(DEVELOPER_ROLE) then
        dialog = dialog .. "add_button|devCompleteQuest|`4[DEV] Complete Quest``|noflags|0|0|\n"
    end
    
    dialog = dialog .. "add_spacer|small|\nend_dialog|ringmasterActiveQuestDialog|Close||"
    return dialog
end

-- Quest Completion
local function completeQuestStep(world, player)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    local cfg = RINGMASTER_CONFIG
    
    if not quest then return end

    if (quest.step or 1) >= cfg.maxSteps then
        local reward = cfg.rewardRings[math.random(1, #cfg.rewardRings)]
        local ringItemId = reward.id
        local ringName = getItem(ringItemId):getName()

        player:onTextOverlay("`9Quest Complete!``")
        player:changeItem(ringItemId, 1, 0)
        world:setClothing(player, ringItemId)
        world:updateClothing(player)
        world:sendPlayerMessage(player, "/cheer")

        for _, players in pairs(world:getPlayers()) do
            players:onConsoleMessage("`9>> `w" .. cleanName(player:getName()) .. 
                " `9completed Quest For Ring and earned " .. ringName .. "!``")
            players:onParticleEffect(90, player:getPosX(), player:getPosY(), 0, 0, 0)
        end

        RINGMASTER_QUEST[userId] = nil
        saveRingmasterQuestsData()
        return
    end

    local base = questDefinitions[math.random(1, #questDefinitions)]
    local description = base.description
    local smallDescription = base.smallDescription
    local objectiveData = {}

    for _, objective in ipairs(base.objectives) do
        local range = cfg.questRanges[objective.type]
        local goal = math.random(range.min, range.max)
        objectiveData[objective.type] = { goal = goal, progress = 0 }
        description = description:gsub("{" .. objective.type .. "_goal}", formatNumber(goal))
    end

    if base.id == "delivering_items" then
        base.itemID = cfg.deliverableItems[math.random(1, #cfg.deliverableItems)].id
        description = description:gsub("{itemName}", getItem(base.itemID):getName())
    end

    local nextStep = (quest.step or 1) + 1

    RINGMASTER_QUEST[userId] = {
        id = base.id,
        description = description,
        smallDescription = smallDescription or nil,
        objectives = objectiveData,
        notified = false,
        itemID = base.itemID,
        step = nextStep
    }

    player:onTextOverlay("`9Quest step complete!``")
    saveRingmasterQuestsData()
    player:onDialogRequest(buildRingmasterActiveQuestDialog(RINGMASTER_QUEST[userId], player))
end

-- Tile Callbacks
onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() ~= ringmasterId then return false end

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
    if tile:getTileID() ~= ringmasterId then return false end

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

    if player:hasRole(DEVELOPER_ROLE) then
        return false
    else
        player:onTalkBubble(player:getNetID(), "`wI cannot break that!``", 0)
        return true
    end
end)

-- Dialog Callbacks
onPlayerDialogCallback(function(world, player, data)
    local action = data["action"]
    local dialog = data["dialog_name"]
    local button = data["buttonClicked"]

    -- Admin Dialogs
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
            player:onConsoleMessage("`2Configuration reset!``")
            player:onDialogRequest(buildAdminMainDialog())
        end
        return true
    end

    if dialog == "adminBasicDialog" and action == "dialog_return" then
        local maxSteps = tonumber(data["maxSteps"])
        local ringExchange = tonumber(data["ringExchange"])
        
        if maxSteps and maxSteps > 0 then
            RINGMASTER_CONFIG.maxSteps = maxSteps
        end
        if ringExchange and ringExchange > 0 then
            RINGMASTER_CONFIG.ringExchangeAmount = ringExchange
        end
        
        saveRingmasterConfig()
        player:onConsoleMessage("`2Settings saved!``")
        player:onDialogRequest(buildAdminMainDialog())
        return true
    end

    if dialog == "adminRangesDialog" and action == "dialog_return" then
        for key, _ in pairs(RINGMASTER_CONFIG.questRanges) do
            local minVal = tonumber(data["min_" .. key])
            local maxVal = tonumber(data["max_" .. key])
            
            if minVal and maxVal and minVal > 0 and maxVal >= minVal then
                RINGMASTER_CONFIG.questRanges[key].min = minVal
                RINGMASTER_CONFIG.questRanges[key].max = maxVal
            end
        end
        
        saveRingmasterConfig()
        player:onConsoleMessage("`2Quest ranges saved!``")
        player:onDialogRequest(buildAdminMainDialog())
        return true
    end

    if dialog == "adminRewardsDialog" then
        if action == "dialog_return" and data["addReward"] then
            local itemId = tonumber(data["addReward"])
            if itemId then
                table.insert(RINGMASTER_CONFIG.rewardRings, { id = itemId })
                saveRingmasterConfig()
                player:onConsoleMessage("`2Reward added!``")
            end
            player:onDialogRequest(buildAdminRewardsDialog())
            return true
        end
        
        if button and button:match("^adminRemoveReward_") then
            local idx = tonumber(button:match("adminRemoveReward_(%d+)"))
            if idx and RINGMASTER_CONFIG.rewardRings[idx] then
                table.remove(RINGMASTER_CONFIG.rewardRings, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Reward removed!``")
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
                player:onConsoleMessage("`2Requirement added!``")
            end
            player:onDialogRequest(buildAdminRequirementsDialog())
            return true
        end
        
        if button and button:match("^adminRemoveReq_") then
            local idx = tonumber(button:match("adminRemoveReq_(%d+)"))
            if idx and RINGMASTER_CONFIG.startRequirements[idx] then
                table.remove(RINGMASTER_CONFIG.startRequirements, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Requirement removed!``")
                player:onDialogRequest(buildAdminRequirementsDialog())
            end
            return true
        end
        
        for i, req in ipairs(RINGMASTER_CONFIG.startRequirements) do
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
                player:onConsoleMessage("`2Deliverable added!``")
            end
            player:onDialogRequest(buildAdminDeliverablesDialog())
            return true
        end
        
        if button and button:match("^adminRemoveDel_") then
            local idx = tonumber(button:match("adminRemoveDel_(%d+)"))
            if idx and RINGMASTER_CONFIG.deliverableItems[idx] then
                table.remove(RINGMASTER_CONFIG.deliverableItems, idx)
                saveRingmasterConfig()
                player:onConsoleMessage("`4Deliverable removed!``")
                player:onDialogRequest(buildAdminDeliverablesDialog())
            end
            return true
        end
        return true
    end

    -- Player Dialogs
    if dialog == "ringmasterFirstDialog" then
        if button == "ringmasterContinueDialog" then
            player:onDialogRequest(buildRingmasterSecondDialog())
        elseif button == "devBypassQuest" then
            -- Developer bypass - instant completion
            if player:hasRole(DEVELOPER_ROLE) then
                local cfg = RINGMASTER_CONFIG
                local reward = cfg.rewardRings[math.random(1, #cfg.rewardRings)]
                player:changeItem(reward.id, 1, 0)
                world:setClothing(player, reward.id)
                world:updateClothing(player)
                player:onConsoleMessage("`4[DEV] Quest bypassed! Received " .. getItem(reward.id):getName() .. "!``")
                player:onTextOverlay("`4[DEV] Quest Bypassed!``")
            end
        end
        return true
    end

    if dialog == "ringmasterSecondDialog" and action == "dialog_return" then
        local userId = player:getUserID()
        local cfg = RINGMASTER_CONFIG
        
        local inventoryItems = player:getInventoryItems()
        for _, req in ipairs(cfg.startRequirements) do
            local hasItem = false
            for _, item in ipairs(inventoryItems) do
                if item:getItemID() == req.id and item:getItemCount() >= req.amount then
                    hasItem = true
                    break
                end
            end
            if not hasItem then
                player:onTalkBubble(player:getNetID(), "`wYou don't have the items!``", 0)
                return true
            end
        end

        for _, req in ipairs(cfg.startRequirements) do
            player:changeItem(req.id, -req.amount, 0)
        end

        local base = questDefinitions[math.random(1, #questDefinitions)]
        local description = base.description
        local smallDescription = base.smallDescription
        local objectiveData = {}

        for _, objective in ipairs(base.objectives) do
            local range = cfg.questRanges[objective.type]
            local goal = math.random(range.min, range.max)
            objectiveData[objective.type] = { goal = goal, progress = 0 }
            description = description:gsub("{" .. objective.type .. "_goal}", formatNumber(goal))
        end

        if base.id == "delivering_items" then
            base.itemID = cfg.deliverableItems[math.random(1, #cfg.deliverableItems)].id
            description = description:gsub("{itemName}", getItem(base.itemID):getName())
        end

        RINGMASTER_QUEST[userId] = {
            id = base.id,
            description = description,
            smallDescription = smallDescription or nil,
            objectives = objectiveData,
            notified = false,
            step = 1,
            itemID = base.itemID
        }

        player:onTalkBubble(player:getNetID(), "`wThe Ringmaster collects your items!``", 0)
        saveRingmasterQuestsData()
        player:onDialogRequest(buildRingmasterActiveQuestDialog(RINGMASTER_QUEST[userId], player))
        return true
    end

    if dialog == "ringmasterActiveQuestDialog" then
        if button == "giveupQuest" then
            local userId = player:getUserID()
            RINGMASTER_QUEST[userId] = nil
            saveRingmasterQuestsData()
            player:onTextOverlay("`9Quest abandoned!``")
        elseif button == "notCompleteStep" then
            player:onTextOverlay("`9Good luck!``")
        elseif button == "completeStep" then
            completeQuestStep(world, player)
        elseif button == "bypassCurrentStep" then
            -- Role 8 bypass - skip current step only
            if player:hasRole(BYPASS_ROLE) then
                player:onTextOverlay("`eStep Bypassed!``")
                completeQuestStep(world, player)
            end
        elseif button == "devCompleteQuest" then
            -- Developer instant complete entire quest
            if player:hasRole(DEVELOPER_ROLE) then
                local userId = player:getUserID()
                local cfg = RINGMASTER_CONFIG
                local reward = cfg.rewardRings[math.random(1, #cfg.rewardRings)]
                
                player:onTextOverlay("`4[DEV] Quest Force Completed!``")
                player:changeItem(reward.id, 1, 0)
                world:setClothing(player, reward.id)
                world:updateClothing(player)
                
                player:onConsoleMessage("`4[DEV] Quest bypassed! Received " .. getItem(reward.id):getName() .. "!``")
                
                RINGMASTER_QUEST[userId] = nil
                saveRingmasterQuestsData()
            end
        elseif button == "deliverItem" then
            local userId = player:getUserID()
            local quest = RINGMASTER_QUEST[userId]
            if not quest then return true end

            local deliverType = quest.id
            local typeKey = nil
            if deliverType == "delivering_items" then typeKey = "deliver_items"
            elseif deliverType == "delivering_gems" then typeKey = "deliver_gems"
            elseif deliverType == "delivering_worldlocks" then typeKey = "deliver_worldlocks"
            end

            if not typeKey then return true end
            local objective = quest.objectives[typeKey]

            local deliverAmount = 0
            if deliverType == "delivering_items" then
                local itemId = quest.itemID
                for _, item in ipairs(player:getInventoryItems()) do
                    if item:getItemID() == itemId then
                        deliverAmount = math.min(item:getItemCount(), objective.goal - objective.progress)
                        if deliverAmount > 0 then
                            player:changeItem(itemId, -deliverAmount, 0)
                        end
                        break
                    end
                end
            elseif deliverType == "delivering_gems" then
                local gems = player:getGems()
                deliverAmount = math.min(gems, objective.goal - objective.progress)
                if deliverAmount > 0 then
                    player:removeGems(deliverAmount, 1, 0)
                end
            elseif deliverType == "delivering_worldlocks" then
                for _, item in ipairs(player:getInventoryItems()) do
                    if item:getItemID() == 242 then
                        deliverAmount = math.min(item:getItemCount(), objective.goal - objective.progress)
                        if deliverAmount > 0 then
                            player:changeItem(242, -deliverAmount, 0)
                        end
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

-- Quest Progress Callbacks (All 20 Quest Types)
onTileBreakCallback(function(world, player, tile)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    local brokenId = tile:getTileID()
    
    if quest.objectives["break_blocks"] then
        addRingmasterQuestProgress(player, "break_blocks", 1)
    end
    
    if quest.objectives["break_rarity"] then
        local rarity = getItem(brokenId):getRarity() or 0
        if rarity > 0 then
            addRingmasterQuestProgress(player, "break_rarity", rarity)
        end
    end
end)

onPlayerHarvestCallback(function(world, player, tile)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    local harvestedId = tile:getTileID()
    
    if quest.objectives["harvest_trees"] then
        local rarity = getItem(harvestedId):getRarity() or 0
        if rarity > 0 then
            addRingmasterQuestProgress(player, "harvest_trees", rarity)
        end
    end
end)

onPlayerPlantCallback(function(world, player, tile)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    local plantedId = tile:getTileID()
    
    if quest.objectives["plant_trees"] then
        local rarity = getItem(plantedId):getRarity() or 0
        if rarity > 0 then
            addRingmasterQuestProgress(player, "plant_trees", rarity)
        end
    end
    
    if quest.objectives["plant_rarity"] then
        local rarity = getItem(plantedId):getRarity() or 0
        if rarity > 0 then
            addRingmasterQuestProgress(player, "plant_rarity", rarity)
        end
    end
end)

onPlayerXPCallback(function(world, player, amount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["earn_xp"] then
        addRingmasterQuestProgress(player, "earn_xp", amount)
    end
end)

onPlayerGemsObtainedCallback(function(world, player, amount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["earn_gems"] then
        addRingmasterQuestProgress(player, "earn_gems", amount)
    end
end)

onPlayerSurgeryCallback(function(world, player, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["perform_surgery"] then
        addRingmasterQuestProgress(player, "perform_surgery", 1)
    end
end)

onPlayerProviderCallback(function(world, player, tile, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["harvest_provider"] then
        addRingmasterQuestProgress(player, "harvest_provider", itemCount)
    end
end)

onPlayerEarnGrowtokenCallback(function(world, player, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["earn_growtoken"] then
        addRingmasterQuestProgress(player, "earn_growtoken", itemCount)
    end
end)

onPlayerCrimeCallback(function(world, player, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["defeat_villain"] then
        addRingmasterQuestProgress(player, "defeat_villain", 1)
    end
end)

onPlayerHarmonicCallback(function(world, player, tile, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["shatter_crystal"] then
        addRingmasterQuestProgress(player, "shatter_crystal", 1)
    end
end)

onPlayerGeigerCallback(function(world, player, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["find_geiger"] then
        addRingmasterQuestProgress(player, "find_geiger", 1)
    end
end)

onPlayerCatchFishCallback(function(world, player, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["catch_fish"] then
        addRingmasterQuestProgress(player, "catch_fish", itemCount)
    end
end)

onPlayerTrainFishCallback(function(world, player)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["train_fish"] then
        addRingmasterQuestProgress(player, "train_fish", 1)
    end
end)

onPlayerCatchGhostCallback(function(world, player, itemID, itemCount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["catch_ghost"] then
        addRingmasterQuestProgress(player, "catch_ghost", 1)
    end
end)

onPlayerDNACallback(function(world, player, resultID, resultAmount)
    local userId = player:getUserID()
    local quest = RINGMASTER_QUEST[userId]
    if not quest then return end

    if quest.objectives["splice_dna"] then
        addRingmasterQuestProgress(player, "splice_dna", 1)
    end
end)

-- Initialize
loadRingmasterQuestsData()
loadRingmasterConfig()

