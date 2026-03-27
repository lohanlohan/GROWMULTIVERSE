-- =========================================================
-- CONFIG
-- =========================================================

local FENRIR_ITEM_ID = 4364
local VALHOWLA_WORLD = "VALHOWLA"
local TREASURE_BLOCK_ID = 4368
local DEV_ROLE_ID = 51

local COUNTDOWN_DURATION = 180 -- 3 minutes
local RETURN_DELAY = 5
local REQUIRED_TREASURES = 4
local MAX_REWARDS = 10

local FENRIR_REWARD_SAVE_KEY = "fenrir_rewards_v1"

-- Global reward pool for all Valhowla Treasure blocks
local FENRIR_REWARDS = {}

-- =========================================================
-- RUNTIME STORAGE
-- =========================================================

local fenrir_active = {}         -- [userID] = true
local fenrir_timers = {}         -- [userID] = timerId
local fenrir_end_times = {}      -- [userID] = os.time() + COUNTDOWN_DURATION
local fenrir_return_world = {}   -- [userID] = previous world name
local fenrir_pending_return = {} -- [userID] = true when auto-returning after success
local fenrir_claimed = {}        -- [userID] = { ["x:y"] = true }
local fenrir_current_world = {}  -- [userID] = current tracked world name

-- =========================================================
-- HELPERS
-- =========================================================

local function isValhowlaWorld(worldName)
    if not worldName then return false end
    return worldName:lower() == VALHOWLA_WORLD:lower()
end

local function getItemNameSafe(itemID)
    local item = getItem(itemID)
    if item then
        return item:getName()
    end
    return "Unknown Item (" .. tostring(itemID) .. ")"
end

local function getItemIDByName(itemName)
    if not itemName then return nil end

    for id = 1, 25000 do
        local item = getItem(id)
        if item then
            local name = item:getName()
            if name and name:lower() == itemName:lower() then
                return id
            end
        end
    end

    return nil
end

local function saveFenrirRewards()
    saveDataToServer(FENRIR_REWARD_SAVE_KEY, FENRIR_REWARDS)
end

local function loadFenrirRewards()
    local data = loadDataFromServer(FENRIR_REWARD_SAVE_KEY)
    if type(data) == "table" then
        FENRIR_REWARDS = data
        -- migrate old entries that don't have itemID stored
        local migrated = false
        for _, reward in ipairs(FENRIR_REWARDS) do
            if not reward.itemID then
                reward.itemID = getItemIDByName(reward.itemName)
                migrated = true
            end
        end
        if migrated then
            saveFenrirRewards()
        end
    end
end

local function getRemainingTime(userID)
    if not fenrir_end_times[userID] then
        return 0
    end
    return fenrir_end_times[userID] - os.time()
end

local function clearFenrirState(userID, clearReturnWorld)
    if fenrir_timers[userID] then
        timer.clear(fenrir_timers[userID])
        fenrir_timers[userID] = nil
    end

    fenrir_active[userID] = nil
    fenrir_end_times[userID] = nil
    fenrir_pending_return[userID] = nil
    fenrir_current_world[userID] = nil
    fenrir_claimed[userID] = nil

    if clearReturnWorld then
        fenrir_return_world[userID] = nil
    end
end

local function countClaimedTreasures(userID)
    local count = 0
    local claimed = fenrir_claimed[userID]
    if not claimed then
        return 0
    end

    for _, _ in pairs(claimed) do
        count = count + 1
    end
    return count
end

local function chooseFenrirReward()
    if #FENRIR_REWARDS <= 0 then
        return nil
    end

    local totalChance = 0
    for _, reward in ipairs(FENRIR_REWARDS) do
        totalChance = totalChance + (tonumber(reward.chance) or 0)
    end

    if totalChance <= 0 then
        return FENRIR_REWARDS[#FENRIR_REWARDS]
    end

    local roll = math.random(1, totalChance)
    local cumulative = 0

    for _, reward in ipairs(FENRIR_REWARDS) do
        cumulative = cumulative + (tonumber(reward.chance) or 0)
        if roll <= cumulative then
            return reward
        end
    end

    return FENRIR_REWARDS[#FENRIR_REWARDS]
end

local function giveItemToPlayerOrDrop(world, player, itemID, amount)
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end

    local given = player:changeItem(itemID, amount, 0)
    if not given then
        local pX = math.floor(player:getPosX() / 32) * 32
        local pY = math.floor(player:getPosY() / 32) * 32
        world:spawnItem(pX, pY, itemID, amount)
    end
end

local function scheduleFenrirTimeout(player)
    local userID = player:getUserID()
    local remaining = getRemainingTime(userID)

    if remaining <= 0 then
        local returnWorld = fenrir_return_world[userID]
        clearFenrirState(userID, true)

        player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
        player:onTalkBubble(player:getNetID(), "`4Your Challenge Of Fenrir time has ended!", 1)

        if returnWorld and returnWorld ~= "" then
            player:enterWorld(returnWorld, "", 1)
        else
            player:enterWorld("", "", 1)
        end
        return
    end

    if fenrir_timers[userID] then
        timer.clear(fenrir_timers[userID])
        fenrir_timers[userID] = nil
    end

    player:sendVariant({"OnCountdownStart", remaining, -1}, 0, player:getNetID())

    fenrir_timers[userID] = timer.setTimeout(remaining, function()
        if not player:isOnline() then
            return
        end

        local returnWorld = fenrir_return_world[userID]
        clearFenrirState(userID, true)

        player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
        player:onTalkBubble(player:getNetID(), "`4Your Challenge Of Fenrir time has ended!", 1)

        if returnWorld and returnWorld ~= "" then
            player:enterWorld(returnWorld, "", 1)
        else
            player:enterWorld("", "", 1)
        end
    end)
end

local function finishFenrirRun(player)
    local userID = player:getUserID()
    local returnWorld = fenrir_return_world[userID]

    fenrir_pending_return[userID] = true

    if fenrir_timers[userID] then
        timer.clear(fenrir_timers[userID])
        fenrir_timers[userID] = nil
    end

    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
    player:onConsoleMessage("`2You have claimed all 4 Valhowla Treasures!")
    player:onTalkBubble(player:getNetID(), "`2Fenrir acknowledges your worth...", 1)

    timer.setTimeout(RETURN_DELAY, function()
        if not player:isOnline() then
            clearFenrirState(userID, true)
            return
        end

        clearFenrirState(userID, true)

        if returnWorld and returnWorld ~= "" then
            player:enterWorld(returnWorld, "", 1)
        else
            player:enterWorld("", "", 1)
        end
    end)
end

-- =========================================================
-- LOAD / SAVE
-- =========================================================

loadFenrirRewards()

onAutoSaveRequest(function()
    saveFenrirRewards()
end)

-- =========================================================
-- CONSUMABLE CALLBACK
-- Everyone can use Challenge Of Fenrir
-- =========================================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= FENRIR_ITEM_ID then
        return false
    end

    local userID = player:getUserID()
    local worldName = world:getName()

    if fenrir_active[userID] then
        player:onTalkBubble(player:getNetID(), "`4You already have an active Challenge Of Fenrir!", 1)
        return true
    end

    if isValhowlaWorld(worldName) then
        player:onTalkBubble(player:getNetID(), "`4You can't use Challenge Of Fenrir inside VALHOWLA!", 1)
        return true
    end

    player:changeItem(FENRIR_ITEM_ID, -1, 0)

    fenrir_active[userID] = true
    fenrir_end_times[userID] = os.time() + COUNTDOWN_DURATION
    fenrir_return_world[userID] = worldName
    fenrir_pending_return[userID] = nil
    fenrir_claimed[userID] = {}
    fenrir_current_world[userID] = VALHOWLA_WORLD

    player:onTalkBubble(player:getNetID(), "`9I ACCEPT THE CHALLENGE OF FENRIR", 1)

    timer.setTimeout(2, function()
        if player:isOnline() then
            player:enterWorld(VALHOWLA_WORLD, "", 1)
        end
    end)

    return true
end)

-- =========================================================
-- WORLD ENTER CALLBACK
-- =========================================================

onPlayerEnterWorldCallback(function(world, player)
    local worldName = world:getName()
    if not isValhowlaWorld(worldName) then
        return
    end

    local userID = player:getUserID()
    if not fenrir_active[userID] then
        return
    end

    local remaining = getRemainingTime(userID)
    if remaining <= 0 then
        local returnWorld = fenrir_return_world[userID]
        clearFenrirState(userID, true)

        player:onTalkBubble(player:getNetID(), "`4Your Challenge Of Fenrir time has ended!", 1)

        if returnWorld and returnWorld ~= "" then
            player:enterWorld(returnWorld, "", 1)
        else
            player:enterWorld("", "", 1)
        end
        return
    end

    fenrir_current_world[userID] = worldName

    player:onConsoleMessage("`9Challenge Of Fenrir has begun!")
    player:onConsoleMessage("`wClaim 4 different Valhowla Treasures within 3 minutes.")
    player:onConsoleMessage("`4Leaving VALHOWLA will fail the challenge.")
    player:onConsoleMessage("`7Disconnecting is allowed, but time continues in real time.")

    scheduleFenrirTimeout(player)
end)

-- =========================================================
-- WORLD LEAVE CALLBACK
-- Manual leave from VALHOWLA while run active = RIP
-- =========================================================

onPlayerLeaveWorldCallback(function(world, player)
    local userID = player:getUserID()
    local worldName = world:getName()

    if not isValhowlaWorld(worldName) then
        return
    end

    if not fenrir_active[userID] then
        return
    end

    if fenrir_pending_return[userID] then
        return
    end

    if player:isOnline() then
        if fenrir_timers[userID] then
            timer.clear(fenrir_timers[userID])
            fenrir_timers[userID] = nil
        end

        clearFenrirState(userID, true)
        player:onTalkBubble(player:getNetID(), "`4You abandoned the Challenge Of Fenrir!", 1)
    end
end)

-- =========================================================
-- DISCONNECT CALLBACK
-- Real-time timer continues, only local timeout gets cleared
-- =========================================================

onPlayerDisconnectCallback(function(player)
    local userID = player:getUserID()

    if fenrir_active[userID] then
        if fenrir_timers[userID] then
            timer.clear(fenrir_timers[userID])
            fenrir_timers[userID] = nil
        end
    end
end)

-- =========================================================
-- TREASURE BLOCK ACTIVATION
-- Same block ID can be claimed 4x because claim key uses tile position
-- =========================================================

onPlayerActivateTileCallback(function(world, player, tile)
    if tile:getTileID() ~= TREASURE_BLOCK_ID then
        return false
    end

    local userID = player:getUserID()
    local tileX = tile:getPosX()
    local tileY = tile:getPosY()
    local claimKey = tostring(tileX) .. ":" .. tostring(tileY)

    if not fenrir_active[userID] or not isValhowlaWorld(world:getName()) then
        player:onTalkBubble(player:getNetID(), "`4You Are Not Worthy to Claim The Reward", 1)
        return true
    end

    local remaining = getRemainingTime(userID)
    if remaining <= 0 then
        local returnWorld = fenrir_return_world[userID]
        clearFenrirState(userID, true)

        player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
        player:onTalkBubble(player:getNetID(), "`4Your Challenge Of Fenrir time has ended!", 1)

        if returnWorld and returnWorld ~= "" then
            player:enterWorld(returnWorld, "", 1)
        else
            player:enterWorld("", "", 1)
        end
        return true
    end

    if not fenrir_claimed[userID] then
        fenrir_claimed[userID] = {}
    end

    if fenrir_claimed[userID][claimKey] then
        player:onTalkBubble(player:getNetID(), "`4You have already claimed this Valhowla Treasure.", 1)
        return true
    end

    if #FENRIR_REWARDS <= 0 then
        player:onTalkBubble(player:getNetID(), "`4Valhowla Treasure reward pool is empty.", 1)
        return true
    end

    fenrir_claimed[userID][claimKey] = true

    local chosen = chooseFenrirReward()
    local rewardText = "a reward"

    if chosen then
        local rewardID = chosen.itemID
        local rewardAmount = tonumber(chosen.amount) or 1

        if rewardID and rewardID > 0 then
            giveItemToPlayerOrDrop(world, player, rewardID, rewardAmount)
            rewardText = tostring(rewardAmount) .. " " .. getItemNameSafe(rewardID)
        else
            rewardText = tostring(rewardAmount) .. " " .. tostring(chosen.itemName)
        end
    end

    local msg = "`6Fenrir Graces you with " .. rewardText
    player:onConsoleMessage(msg)
    player:onTalkBubble(player:getNetID(), msg, 1)
    player:playAudio("level_up.wav")

    local cx = player:getPosX() + 15
    local cy = player:getPosY() + 15
    if player.onParticleEffect then
        player:onParticleEffect(46, cx, cy, 0, 0, 0)
    end

    local totalClaimed = countClaimedTreasures(userID)
    player:onConsoleMessage("`9Valhowla Treasures Claimed: `w" .. tostring(totalClaimed) .. "/" .. tostring(REQUIRED_TREASURES))

    if totalClaimed >= REQUIRED_TREASURES then
        finishFenrirRun(player)
    end

    return true
end)

-- =========================================================
-- CONFIG DIALOG HELPERS
-- One global reward pool for all treasure blocks
-- =========================================================

local function showFenrirConfigDialog(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wFenrir Reward Config``|left|" .. FENRIR_ITEM_ID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`oThis reward pool is used by all Valhowla Treasure blocks.``|\n"
    dialog = dialog .. "add_smalltext|`oTreasure Block ID: " .. tostring(TREASURE_BLOCK_ID) .. " | Required Claims: " .. tostring(REQUIRED_TREASURES) .. "``|\n"
    dialog = dialog .. "add_spacer|small|\n"

    local totalChance = 0
    for _, reward in ipairs(FENRIR_REWARDS) do
        totalChance = totalChance + (tonumber(reward.chance) or 0)
    end

    dialog = dialog .. "add_textbox|`wTotal chance weight: `2" .. tostring(totalChance) .. "|left|\n"
    dialog = dialog .. "add_spacer|small|\n"

    for i, reward in ipairs(FENRIR_REWARDS) do
        local iconID = reward.itemID or 2
        dialog = dialog .. "add_button_with_icon|remove_reward_" .. i .. "|`w" .. reward.itemName .. "  `2x" .. tostring(reward.amount) .. "  `6Chance:" .. tostring(reward.chance) .. "|staticBlueFrame|" .. iconID .. "|\n"
    end

    dialog = dialog .. "add_button_with_icon||END_LIST|noflags|0||\n"
    dialog = dialog .. "add_spacer|small|\n"

    if #FENRIR_REWARDS < MAX_REWARDS then
        dialog = dialog .. "add_button|add_new|`2+ Add Item``|noflags|0|0|\n"
    end

    dialog = dialog .. "add_button|clear_all|`4Clear All Rewards``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|fenrir_config_main|||\n"

    player:onDialogRequest(dialog)
end

local function showFenrirItemPickerDialog(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wSelect Item|left|2|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oPick an item from your inventory:|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_item_picker|item_selected|Select Item|Pick from inventory|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|btn_back|`7Back|noflags|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|fenrir_item_picker|Close||\n"

    player:onDialogRequest(dialog)
end

local function showFenrirAmountDialog(player, itemID)
    local item = getItem(itemID)
    if not item then return end

    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wAdd Reward|left|" .. itemID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oSelected: `5" .. item:getName() .. "|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_text_input|item_amount|Amount:|1|5|\n"
    dialog = dialog .. "add_text_input|item_chance|Chance Weight:|10|5|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|confirm_amount|`2Add Reward|noflags|\n"
    dialog = dialog .. "add_button|btn_back|`7Back|noflags|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|fenrir_amount_" .. itemID .. "|Close||\n"

    player:onDialogRequest(dialog)
end

-- =========================================================
-- DIALOG CALLBACK
-- Only developer role can manage config
-- =========================================================

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    local buttonClicked = data["buttonClicked"] or ""

    if dialogName == "fenrir_config_main" then
        if not player:hasRole(DEV_ROLE_ID) then
            player:onConsoleMessage("`4You don't have permission.")
            return true
        end

        if buttonClicked == "add_new" then
            showFenrirItemPickerDialog(player)
            return true
        end

        local removeIndex = tonumber(buttonClicked:match("^remove_reward_(%d+)$"))
        if removeIndex then
            if FENRIR_REWARDS[removeIndex] then
                table.remove(FENRIR_REWARDS, removeIndex)
                saveFenrirRewards()
                player:onConsoleMessage("`4Removed reward slot " .. tostring(removeIndex) .. "!")
                showFenrirConfigDialog(player)
            end
            return true
        end

        if buttonClicked == "clear_all" then
            FENRIR_REWARDS = {}
            saveFenrirRewards()
            player:onConsoleMessage("`4Cleared all Fenrir rewards!``")
            player:playAudio("audio/bleep_fail.wav")
            showFenrirConfigDialog(player)
            return true
        end

        return true
    end

    if dialogName == "fenrir_item_picker" then
        if not player:hasRole(DEV_ROLE_ID) then
            player:onConsoleMessage("`4You don't have permission.")
            return true
        end

        if buttonClicked == "btn_back" then
            showFenrirConfigDialog(player)
            return true
        end

        local selectedItem = tonumber(data["item_selected"])
        if selectedItem and selectedItem > 0 then
            showFenrirAmountDialog(player, selectedItem)
            return true
        end

        return true
    end

    local amountItemID = tonumber(dialogName:match("^fenrir_amount_(%d+)$"))
    if amountItemID then
        if not player:hasRole(DEV_ROLE_ID) then
            player:onConsoleMessage("`4You don't have permission.")
            return true
        end

        if buttonClicked == "btn_back" then
            showFenrirConfigDialog(player)
            return true
        end

        if buttonClicked == "confirm_amount" then
            if #FENRIR_REWARDS >= MAX_REWARDS then
                player:onConsoleMessage("`4Maximum reward slots reached.")
                showFenrirConfigDialog(player)
                return true
            end

            local amount = math.max(1, tonumber(data["item_amount"]) or 1)
            local chance = math.max(1, tonumber(data["item_chance"]) or 1)

            local item = getItem(amountItemID)
            if not item then
                player:onConsoleMessage("`4Item not found!")
                showFenrirConfigDialog(player)
                return true
            end

            table.insert(FENRIR_REWARDS, {
                itemName = item:getName(),
                itemID   = amountItemID,
                amount   = amount,
                chance   = chance
            })

            saveFenrirRewards()
            player:onConsoleMessage("`2Added " .. item:getName() .. " x" .. tostring(amount) .. " (Chance " .. tostring(chance) .. ")!")
            player:playAudio("audio/success.wav")
            showFenrirConfigDialog(player)
            return true
        end

        return true
    end

    return false
end)

-- =========================================================
-- COMMAND
-- Only /fenrirconfig is developer-only
-- =========================================================

onPlayerCommandCallback(function(world, player, command)
    if not command then
        return false
    end

    local cmd = command:match("^(%S+)")
    if not cmd then
        return false
    end

    cmd = cmd:lower()

    if cmd == "fenrirconfig" then
        if not player:hasRole(DEV_ROLE_ID) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end

        showFenrirConfigDialog(player)
        return true
    end

    return false
end)

