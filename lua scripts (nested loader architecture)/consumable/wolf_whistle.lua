-- MODULE
-- wolf_whistle.lua — Wolf Whistle consumable (item 2992), 15min WOLFWORLD hunt, mod -15982

local M = {}

local WOLF_WHISTLE_ID        = 2992
local COWARDLY_WEAKNESS_MOD  = -15982
local MOD_DURATION           = 600
local WOLF_REWARD_ITEM_ID    = 4354
local WOLF_TOTEM_ID          = 2994
local COUNTDOWN_DURATION     = 900

local WOLF_WORLDS = {
    "WOLFWORLD_1", "WOLFWORLD_2", "WOLFWORLD_3", "WOLFWORLD_4",
    "WOLFWORLD_5", "WOLFWORLD_6", "WOLFWORLD_7",
}

local RANDOM_REWARDS = {
    { itemID = 4355, amount = 1 },
    { itemID = 4356, amount = 1 },
    { itemID = 4357, amount = 1 },
    { itemID = 2994, amount = 3 },
    { itemID = 1234, amount = 5 },
    { itemID = 5678, amount = 5 },
    { itemID = 9012, amount = 1 },
    { itemID = 242,  amount = 1 },
}

local wolf_hunt_active   = {}
local wolf_hunt_timers   = {}
local wolf_claimed       = {}
local wolf_end_times     = {}
local wolf_pending_entry = {}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function isWolfWorld(worldName)
    return worldName and string.match(worldName, "^WOLFWORLD_[1-7]$") ~= nil
end

local function getItemNameSafe(itemID)
    local item = getItem(itemID)
    if item then
        local name = item:getName()
        if name and name ~= "" then return name end
    end
    return "Item #" .. tostring(itemID)
end

-- ============================================================================
-- MOD REGISTRATION
-- ============================================================================

registerLuaPlaymod({
    modID          = COWARDLY_WEAKNESS_MOD,
    modName        = "Howlin' Mad",
    onAddMessage   = "`oYou feel the Howlin' Mad take hold...",
    onRemoveMessage= "`oYour Wolf Whistle crumbles to dust.",
    iconID         = WOLF_WHISTLE_ID,
})

-- ============================================================================
-- CONSUMABLE
-- ============================================================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= WOLF_WHISTLE_ID then return false end

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

    local randomWorld           = WOLF_WORLDS[math.random(1, #WOLF_WORLDS)]
    wolf_pending_entry[userID]  = true
    wolf_claimed[userID]        = nil

    timer.setTimeout(2, function()
        if player:isOnline() then
            player:enterWorld(randomWorld, "", 1)
        else
            wolf_pending_entry[userID] = nil
        end
    end)

    return true
end)

-- ============================================================================
-- WORLD ENTER
-- ============================================================================

onPlayerEnterWorldCallback(function(world, player)
    if not isWolfWorld(world:getName()) then return end

    local userID = player:getUserID()
    if not wolf_pending_entry[userID] and not wolf_hunt_active[userID] then return end

    local remaining = COUNTDOWN_DURATION
    if wolf_end_times[userID] then
        remaining = wolf_end_times[userID] - os.time()
        if remaining <= 0 then
            wolf_hunt_active[userID]   = nil
            wolf_hunt_timers[userID]   = nil
            wolf_end_times[userID]     = nil
            wolf_pending_entry[userID] = nil
            wolf_claimed[userID]       = nil
            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour wolf hunt time has ended!", 1)
            return
        end
    else
        wolf_end_times[userID] = os.time() + COUNTDOWN_DURATION
    end

    wolf_hunt_active[userID]   = true
    wolf_pending_entry[userID] = nil

    if wolf_hunt_timers[userID] then
        timer.clear(wolf_hunt_timers[userID])
        wolf_hunt_timers[userID] = nil
    end

    player:sendVariant({"OnCountdownStart", remaining, -1}, 0, player:getNetID())

    wolf_hunt_timers[userID] = timer.setTimeout(remaining, function()
        if player:isOnline() then
            wolf_hunt_active[userID]   = nil
            wolf_hunt_timers[userID]   = nil
            wolf_end_times[userID]     = nil
            wolf_pending_entry[userID] = nil
            wolf_claimed[userID]       = nil
            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour wolf hunt time has ended!", 1)
        end
    end)
end)

-- ============================================================================
-- WORLD LEAVE
-- ============================================================================

onPlayerLeaveWorldCallback(function(world, player)
    local userID = player:getUserID()
    if not isWolfWorld(world:getName()) then return end
    if not wolf_hunt_active[userID] then return end

    if player:isOnline() then
        player:addMod(COWARDLY_WEAKNESS_MOD, MOD_DURATION)
        if wolf_hunt_timers[userID] then
            timer.clear(wolf_hunt_timers[userID])
            wolf_hunt_timers[userID] = nil
        end
        wolf_hunt_active[userID]   = nil
        wolf_end_times[userID]     = nil
        wolf_pending_entry[userID] = nil
        wolf_claimed[userID]       = nil
    end
end)

-- ============================================================================
-- DISCONNECT
-- ============================================================================

onPlayerDisconnectCallback(function(player)
    local userID = player:getUserID()
    if wolf_hunt_active[userID] then
        if wolf_hunt_timers[userID] then
            timer.clear(wolf_hunt_timers[userID])
            wolf_hunt_timers[userID] = nil
        end
    else
        wolf_pending_entry[userID] = nil
    end
    wolf_claimed[userID] = nil
end)

-- ============================================================================
-- WOLF TOTEM ACTIVATION
-- ============================================================================

onPlayerActivateTileCallback(function(world, player, tile)
    if tile:getTileID() ~= WOLF_TOTEM_ID then return false end

    local userID = player:getUserID()

    if wolf_claimed[userID] then return true end

    if not wolf_hunt_active[userID] then
        player:onTalkBubble(player:getNetID(), "`wYou need to use a Wolf Whistle first!", 1)
        return true
    end

    if player:getMod(COWARDLY_WEAKNESS_MOD) then return true end

    wolf_claimed[userID] = true

    local tX = tile:getPosX() * 32
    local tY = tile:getPosY() * 32

    if not player:changeItem(WOLF_REWARD_ITEM_ID, 1, 0) then
        world:spawnItem(tX, tY, WOLF_REWARD_ITEM_ID, 1)
    end

    local randomRewardName = ""
    if #RANDOM_REWARDS > 0 then
        local reward       = RANDOM_REWARDS[math.random(1, #RANDOM_REWARDS)]
        local rewardID     = tonumber(reward.itemID) or 0
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

    if player.onParticleEffect then
        player:onParticleEffect(46, player:getPosX() + 15, player:getPosY() + 15, 0, 0, 0)
    end

    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())

    if wolf_hunt_timers[userID] then
        timer.clear(wolf_hunt_timers[userID])
        wolf_hunt_timers[userID] = nil
    end

    wolf_hunt_active[userID]   = nil
    wolf_end_times[userID]     = nil
    wolf_pending_entry[userID] = nil

    timer.setTimeout(5, function()
        wolf_claimed[userID] = nil
        if player:isOnline() then
            player:enterWorld("", "", 1)
        end
    end)

    return true
end)

-- ============================================================================
-- ADMIN COMMAND: /wolf
-- ============================================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then return false end
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
                player:onConsoleMessage("`oCommand blocked in Wolf World!``")
                return true
            end
        end
    end

    return false
end)

return M
