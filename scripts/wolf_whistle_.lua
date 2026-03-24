local WOLF_WHISTLE_ID = 2992
local WOLF_WORLDS = {
    "WOLFWORLD_1",
    "WOLFWORLD_2",
    "WOLFWORLD_3",
    "WOLFWORLD_4",
    "WOLFWORLD_5",
    "WOLFWORLD_6",
    "WOLFWORLD_7"
}

local COUNTDOWN_DURATION = 900 -- 15 minutes
local COWARDLY_WEAKNESS_MOD = -15982
local MOD_DURATION = 600 -- 10 minutes penalty
local WOLF_REWARD_ITEM_ID = 4354
local WOLF_TOTEM_ID = 2994

local wolf_hunt_active = {}   -- [userID] = true
local wolf_hunt_timers = {}   -- [userID] = timerId
local wolf_claimed = {}       -- [userID] = true
local wolf_end_times = {}     -- [userID] = os.time() + duration
local wolf_pending_entry = {} -- [userID] = true only after consumable use

-- =========================================================
-- RANDOM REWARDS (USE ITEM IDs DIRECTLY)
-- Format:
-- { itemID = ID, amount = COUNT }
-- =========================================================
local RANDOM_REWARDS = {
    { itemID = 4355, amount = 1 }, -- example
    { itemID = 4356, amount = 1 },
    { itemID = 4357, amount = 1 },
    { itemID = 2994, amount = 3 }, -- Wolf Totem example
    { itemID = 1234, amount = 5 }, -- replace with your real item IDs
    { itemID = 5678, amount = 5 },
    { itemID = 9012, amount = 1 },
    { itemID = 242,  amount = 1 }  -- World Lock example
}

-- =========================================================
-- HELPERS
-- =========================================================
local function isWolfWorld(worldName)
    if not worldName then return false end
    return string.match(worldName, "^WOLFWORLD_[1-7]$") ~= nil
end

local function getItemNameSafe(itemID)
    local item = getItem(itemID)
    if item and item.getName then
        local name = item:getName()
        if name and name ~= "" then
            return name
        end
    end
    return "Item #" .. tostring(itemID)
end

-- =========================================================
-- MOD REGISTRATION
-- =========================================================
local cowardlyWeaknessModData = {
    modID = COWARDLY_WEAKNESS_MOD,
    modName = "Howlin' Mad",
    onAddMessage = "`oYou feel the Howlin' Mad take hold...",
    onRemoveMessage = "`oYour Wolf Whistle crumbles to dust.",
    iconID = WOLF_WHISTLE_ID
}

if registerLuaPlaymod then
    registerLuaPlaymod(cowardlyWeaknessModData)
end

-- =========================================================
-- CONSUMABLE CALLBACK
-- =========================================================
onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= WOLF_WHISTLE_ID then
        return false
    end

    local userID = player:getUserID()

    if player:getMod(COWARDLY_WEAKNESS_MOD) then
        player:onTalkBubble(player:getNetID(), "`wYou still have Howlin' Mad! Can't use Wolf Whistle!", 1)
        return true
    end

    if isWolfWorld(world:getName()) then
        player:onTalkBubble(player:getNetID(), "`wYou can't use this while in a wolf world!``", 1)
        return true
    end

    if wolf_hunt_active[userID] then
        player:onTalkBubble(player:getNetID(), "`wYou already have an active wolf hunt!", 1)
        return true
    end

    player:changeItem(WOLF_WHISTLE_ID, -1, 0)
    player:onTalkBubble(player:getNetID(), "`6I SHALL FACE THE WOLF!!!", 1)

    local randomWorld = WOLF_WORLDS[math.random(1, #WOLF_WORLDS)]

    wolf_pending_entry[userID] = true
    wolf_claimed[userID] = nil

    timer.setTimeout(2, function()
        if player:isOnline() then
            player:enterWorld(randomWorld, "", 1)
        else
            wolf_pending_entry[userID] = nil
        end
    end)

    return true
end)

-- =========================================================
-- WORLD ENTER CALLBACK
-- Only activate hunt if:
-- 1. player used consumable and has pending entry
-- 2. OR player reconnects during an already active hunt
-- =========================================================
onPlayerEnterWorldCallback(function(world, player)
    local worldName = world:getName()
    if not isWolfWorld(worldName) then
        return
    end

    local userID = player:getUserID()

    -- direct warp protection:
    -- if player enters wolf world manually without whistle, do not activate hunt
    if not wolf_pending_entry[userID] and not wolf_hunt_active[userID] then
        return
    end

    local remaining = COUNTDOWN_DURATION

    if wolf_end_times[userID] then
        remaining = wolf_end_times[userID] - os.time()
        if remaining <= 0 then
            wolf_hunt_active[userID] = nil
            wolf_hunt_timers[userID] = nil
            wolf_end_times[userID] = nil
            wolf_pending_entry[userID] = nil
            wolf_claimed[userID] = nil

            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour wolf hunt time has ended!", 1)
            return
        end
    else
        wolf_end_times[userID] = os.time() + COUNTDOWN_DURATION
    end

    wolf_hunt_active[userID] = true
    wolf_pending_entry[userID] = nil

    if wolf_hunt_timers[userID] then
        timer.clear(wolf_hunt_timers[userID])
        wolf_hunt_timers[userID] = nil
    end

    player:sendVariant({"OnCountdownStart", remaining, -1}, 0, player:getNetID())

    wolf_hunt_timers[userID] = timer.setTimeout(remaining, function()
        if player:isOnline() then
            wolf_hunt_active[userID] = nil
            wolf_hunt_timers[userID] = nil
            wolf_end_times[userID] = nil
            wolf_pending_entry[userID] = nil
            wolf_claimed[userID] = nil

            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour wolf hunt time has ended!", 1)
        end
    end)
end)

-- =========================================================
-- WORLD LEAVE CALLBACK
-- Early leave while active hunt = penalty
-- =========================================================
onPlayerLeaveWorldCallback(function(world, player)
    local worldName = world:getName()
    local userID = player:getUserID()

    if isWolfWorld(worldName) and wolf_hunt_active[userID] then
        -- if still online, it's a real leave, not disconnect
        if player:isOnline() then
            player:addMod(COWARDLY_WEAKNESS_MOD, MOD_DURATION)

            if wolf_hunt_timers[userID] then
                timer.clear(wolf_hunt_timers[userID])
                wolf_hunt_timers[userID] = nil
            end

            wolf_hunt_active[userID] = nil
            wolf_end_times[userID] = nil
            wolf_pending_entry[userID] = nil
            wolf_claimed[userID] = nil
        end
    end
end)

-- =========================================================
-- DISCONNECT CALLBACK
-- realtime continues, timer callback is cleared locally
-- =========================================================
onPlayerDisconnectCallback(function(player)
    local userID = player:getUserID()

    if wolf_hunt_active[userID] then
        if wolf_hunt_timers[userID] then
            timer.clear(wolf_hunt_timers[userID])
            wolf_hunt_timers[userID] = nil
        end

        -- keep wolf_hunt_active and wolf_end_times for reconnect resume
    else
        wolf_pending_entry[userID] = nil
    end

    wolf_claimed[userID] = nil
end)

-- =========================================================
-- WOLF TOTEM TILE ACTIVATION
-- =========================================================
onPlayerActivateTileCallback(function(world, player, tile)
    if tile:getTileID() ~= WOLF_TOTEM_ID then
        return false
    end

    local userID = player:getUserID()

    if wolf_claimed[userID] then
        return true
    end

    if not wolf_hunt_active[userID] then
        player:onTalkBubble(player:getNetID(), "`wYou need to use a Wolf Whistle first!", 1)
        return true
    end

    if player:getMod(COWARDLY_WEAKNESS_MOD) then
        return true
    end

    wolf_claimed[userID] = true

    local tX = tile:getPosX() * 32
    local tY = tile:getPosY() * 32

    -- Main reward
    if not player:changeItem(WOLF_REWARD_ITEM_ID, 1, 0) then
        world:spawnItem(tX, tY, WOLF_REWARD_ITEM_ID, 1)
    end

    -- Random reward using item IDs directly
    local randomRewardName = ""
    if #RANDOM_REWARDS > 0 then
        local reward = RANDOM_REWARDS[math.random(1, #RANDOM_REWARDS)]
        local rewardID = tonumber(reward.itemID) or 0
        local rewardAmount = math.max(1, tonumber(reward.amount) or 1)

        if rewardID > 0 then
            randomRewardName = getItemNameSafe(rewardID)

            if not player:changeItem(rewardID, rewardAmount, 0) then
                world:spawnItem(tX, tY, rewardID, rewardAmount)
            end
        end
    end

    local msg = "`9You have been granted " .. (randomRewardName ~= "" and randomRewardName or "a reward") .. " by the Wolf Spirit!"
    player:onConsoleMessage(msg)
    player:onTalkBubble(player:getNetID(), msg, 1)

    player:playAudio("level_up.wav")

    local cx = player:getPosX() + 15
    local cy = player:getPosY() + 15
    if player.onParticleEffect then
        player:onParticleEffect(46, cx, cy, 0, 0, 0)
    end

    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())

    if wolf_hunt_timers[userID] then
        timer.clear(wolf_hunt_timers[userID])
        wolf_hunt_timers[userID] = nil
    end

    wolf_hunt_active[userID] = nil
    wolf_end_times[userID] = nil
    wolf_pending_entry[userID] = nil

    timer.setTimeout(5, function()
        wolf_claimed[userID] = nil
        if player:isOnline() then
            player:enterWorld("", "", 1)
        end
    end)

    return true
end)

-- =========================================================
-- ADMIN COMMAND - /wolf
-- =========================================================
onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then
        return false
    end

    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    cmd = cmd:lower()

    if cmd == "wolf" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end

        if player:getMod(COWARDLY_WEAKNESS_MOD) then
            player:removeMod(COWARDLY_WEAKNESS_MOD)
            player:playAudio("audio/success.wav")
        end

        return true
    end

    if cmd == "ghost" or cmd == "superbreak" or cmd == "longpunch" or cmd == "tpclick" or cmd == "invis" then
        if isWolfWorld(world:getName()) then
            if not player:hasRole(51) then
                player:onConsoleMessage("`oCommand blocked in Mine World!``")
                return true
            end
        end
    end

    return false
end)

