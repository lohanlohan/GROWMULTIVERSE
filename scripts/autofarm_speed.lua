-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    -- Item IDs
    CONSUMABLE_BOOST_ID = 25004,  -- Consumable item (24h boost, stackable)
    CLOTHING_BOOST_IDS = {
        98,  -- Clothing 1 (200% boost)
        25402,  -- Clothing 2 (200% boost)
        25403,  -- Clothing 3 (200% boost)
    },
    
    -- Boost values
    CONSUMABLE_BOOST = 100,    -- 100% boost per stack
    CLOTHING_BOOST = 200,      -- 200% boost
    MAX_BOOST = 500,           -- 500% max total (allows item effects on top)
    
    -- Base delay settings
    DEFAULT_BASE_DELAY = 1000,  -- 1000ms default
    MIN_DELAY = 20,             -- Minimum delay after boost
    
    -- Duration
    CONSUMABLE_DURATION = 86400,  -- 24 hours in seconds
    
    -- Storage keys
    BOOST_SAVE_KEY = "autofarm_boost_12",
    DELAY_SAVE_KEY = "autofarm_custom_delay_1212",
    
    -- Admin role
    ADMIN_ROLE = 52,
}

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================
local player_boosts = {}       -- [userID] = { consumable_stacks, expire_time }
local player_base_delays = {}  -- [userID] = custom_base_delay (0 = default)

-- ============================================================================
-- BASE DELAY MANAGEMENT (Standalone)
-- ============================================================================

local function loadPlayerBaseDelay(userID)
    local str = loadStringFromServer(CONFIG.DELAY_SAVE_KEY .. tostring(userID))
    return tonumber(str) or 0
end

local function savePlayerBaseDelay(userID, delay)
    saveStringToServer(CONFIG.DELAY_SAVE_KEY .. tostring(userID), tostring(delay))
    player_base_delays[userID] = delay
end

local function getBaseDelayForPlayer(userID)
    if not player_base_delays[userID] then
        player_base_delays[userID] = loadPlayerBaseDelay(userID)
    end
    
    local custom = player_base_delays[userID]
    return (custom > 0) and custom or CONFIG.DEFAULT_BASE_DELAY
end

-- ============================================================================
-- BOOST DATA MANAGEMENT
-- ============================================================================

local function loadBoostData(userID)
    local str = loadStringFromServer(CONFIG.BOOST_SAVE_KEY .. tostring(userID))
    if not str or str == "" then
        return { consumable_stacks = 0, expire_time = 0 }
    end
    
    local parts = {}
    for token in str:gmatch("[^:]+") do
        table.insert(parts, token)
    end
    
    return {
        consumable_stacks = tonumber(parts[1]) or 0,
        expire_time = tonumber(parts[2]) or 0,
    }
end

local function saveBoostData(userID, data)
    local str = data.consumable_stacks .. ":" .. data.expire_time
    saveStringToServer(CONFIG.BOOST_SAVE_KEY .. tostring(userID), str)
end

local function getBoostData(userID)
    if not player_boosts[userID] then
        player_boosts[userID] = loadBoostData(userID)
    end
    return player_boosts[userID]
end

-- ============================================================================
-- BOOST CALCULATION
-- ============================================================================

local function getClothingBoost(player)
    local boost = 0

    -- Check if wearing any boost clothing
    for _, itemID in ipairs(CONFIG.CLOTHING_BOOST_IDS) do
        if player:getClothingItemID(itemID) > 0 then
            boost = CONFIG.CLOTHING_BOOST
            break
        end
    end

    -- Add item effect farm speed boost (from item_effect_system.lua)
    if _G.getItemEffectFarmSpeedBoost then
        local itemBoost = _G.getItemEffectFarmSpeedBoost(player:getUserID())
        if itemBoost > 0 then
            boost = boost + itemBoost
        end
    end

    return boost
end

local function getConsumableBoost(userID)
    local data = getBoostData(userID)
    local now = os.time()

    -- Check if expired
    if data.expire_time > 0 and now >= data.expire_time then
        data.consumable_stacks = 0
        data.expire_time = 0
        saveBoostData(userID, data)
        return 0
    end

    -- Each stack = 100% boost (stackable within consumable)
    -- But total consumable boost capped at 100%
    return math.min(data.consumable_stacks * CONFIG.CONSUMABLE_BOOST, CONFIG.CONSUMABLE_BOOST)
end

local function getTotalBoost(player)
    local userID = player:getUserID()
    local consumableBoost = getConsumableBoost(userID)
    local clothingBoost = getClothingBoost(player)
    local totalBoost = math.min(consumableBoost + clothingBoost, CONFIG.MAX_BOOST)
    return totalBoost, consumableBoost, clothingBoost
end

local function applyBoost(baseDelay, boostPercent)
    -- Formula: newDelay = baseDelay / (1 + boostPercent/100)
    -- Examples:
    -- 1000ms with 0%   -> 1000ms / 1.0 = 1000ms
    -- 1000ms with 100% -> 1000ms / 2.0 = 500ms
    -- 1000ms with 200% -> 1000ms / 3.0 = 333ms
    -- 1000ms with 300% -> 1000ms / 4.0 = 250ms
    
    local multiplier = 1 + (boostPercent / 100)
    local newDelay = math.floor(baseDelay / multiplier)
    
    return math.max(newDelay, CONFIG.MIN_DELAY)
end

-- ============================================================================
-- DELAY MANAGEMENT
-- ============================================================================

local function updatePlayerDelay(player)
    local userID = player:getUserID()
    local baseDelay = getBaseDelayForPlayer(userID)
    local totalBoost = getTotalBoost(player)
    local finalDelay = applyBoost(baseDelay, totalBoost)
    player:setCustomAutofarmDelay(finalDelay)
end

-- ============================================================================
-- PLAYMOD REGISTRATION
-- ============================================================================

local BOOST_PLAYMOD = registerLuaPlaymod({
    modID          = -4001,
    modName        = "Autofarm Boost",
    onAddMessage   = "`2Your Autofarm Boost is now active!``",
    onRemoveMessage= "`4Your Autofarm Boost has expired.``",
    iconID         = 25004,
})

-- Helper: apply or remove playmod based on current boost state
local function syncBoostPlaymod(player)
    local userID = player:getUserID()
    local data   = getBoostData(userID)
    local now    = os.time()

    local consumableActive = data.consumable_stacks > 0 and data.expire_time > now
    local clothingActive   = false
    for _, id in ipairs(CONFIG.CLOTHING_BOOST_IDS) do
        if player:getClothingItemID(id) > 0 then clothingActive = true ; break end
    end

    local shouldHaveMod = consumableActive or clothingActive

    if shouldHaveMod and not player:getMod(BOOST_PLAYMOD) then
        local duration = 0  -- 0 = permanent (clothing or both active)
        if consumableActive and not clothingActive then
            duration = math.max(1, data.expire_time - now)  -- süreli
        end
        player:addMod(BOOST_PLAYMOD, duration)
    elseif not shouldHaveMod and player:getMod(BOOST_PLAYMOD) then
        player:removeMod(BOOST_PLAYMOD)
    end
end

-- ============================================================================
-- CONSUMABLE HANDLER
-- ============================================================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= CONFIG.CONSUMABLE_BOOST_ID then return false end

    local userID = player:getUserID()
    local data = getBoostData(userID)
    local now = os.time()

    -- Add stack
    data.consumable_stacks = data.consumable_stacks + 1

    -- Extend duration (24h per use, stackable)
    if data.expire_time < now then
        data.expire_time = now + CONFIG.CONSUMABLE_DURATION
    else
        data.expire_time = data.expire_time + CONFIG.CONSUMABLE_DURATION
    end

    -- Consume item
    player:changeItem(CONFIG.CONSUMABLE_BOOST_ID, -1, 0)

    -- Save
    saveBoostData(userID, data)

    -- Update delay
    updatePlayerDelay(player)
    syncBoostPlaymod(player)

    -- Get info
    local totalBoost, consumableBoost, clothingBoost = getTotalBoost(player)
    local baseDelay = getBaseDelayForPlayer(userID)
    local finalDelay = applyBoost(baseDelay, totalBoost)

    local timeRemaining = data.expire_time - now
    local hours = math.floor(timeRemaining / 3600)

    player:onTalkBubble(player:getNetID(), "`2Autofarm boost activated!", 0)
    player:onConsoleMessage("`2Consumable Boost Added!``")
    player:onConsoleMessage("`wStacks: `5" .. data.consumable_stacks .. "``")
    player:onConsoleMessage("`wTotal Boost: `5" .. totalBoost .. "%`` `o(Consumable: " .. consumableBoost .. "%, Clothing: " .. clothingBoost .. "%)``")
    player:onConsoleMessage("`wDelay: `5" .. finalDelay .. "ms`` `o(Base: " .. baseDelay .. "ms)``")
    player:onConsoleMessage("`wTime Remaining: `5" .. hours .. " hours``")
    player:playAudio("audio/piano_nice.wav", 0)

    return true
end)

-- ============================================================================
-- CLOTHING CHANGE HANDLERS
-- ============================================================================

onPlayerEquipClothingCallback(function(world, player, itemID)
    -- Check if it's a boost clothing
    local isBoostClothing = false
    for _, id in ipairs(CONFIG.CLOTHING_BOOST_IDS) do
        if itemID == id then
            isBoostClothing = true
            break
        end
    end
    
    if not isBoostClothing then return end
    
    -- Update delay when clothing equipped
    timer.setTimeout(100, function()
        if player and player:isOnline() then
            updatePlayerDelay(player)
            syncBoostPlaymod(player)
            
            local totalBoost, consumableBoost, clothingBoost = getTotalBoost(player)
            local baseDelay = getBaseDelayForPlayer(player:getUserID())
            local finalDelay = applyBoost(baseDelay, totalBoost)
            
            player:onConsoleMessage("`2Clothing Boost Equipped!``")
            player:onConsoleMessage("`wTotal Boost: `5" .. totalBoost .. "%`` `o(Consumable: " .. consumableBoost .. "%, Clothing: " .. clothingBoost .. "%)``")
            player:onConsoleMessage("`wDelay: `5" .. finalDelay .. "ms`` `o(Base: " .. baseDelay .. "ms)``")
        end
    end)
end)

onPlayerUnequipClothingCallback(function(world, player, itemID)
    -- Check if it's a boost clothing
    local isBoostClothing = false
    for _, id in ipairs(CONFIG.CLOTHING_BOOST_IDS) do
        if itemID == id then
            isBoostClothing = true
            break
        end
    end
    
    if not isBoostClothing then return end
    
    -- Update delay when clothing unequipped
    timer.setTimeout(100, function()
        if player and player:isOnline() then
            updatePlayerDelay(player)
            syncBoostPlaymod(player)
            
            local totalBoost, consumableBoost, clothingBoost = getTotalBoost(player)
            local baseDelay = getBaseDelayForPlayer(player:getUserID())
            local finalDelay = applyBoost(baseDelay, totalBoost)
            
            player:onConsoleMessage("`4Clothing Boost Removed!``")
            player:onConsoleMessage("`wTotal Boost: `5" .. totalBoost .. "%`` `o(Consumable: " .. consumableBoost .. "%, Clothing: " .. clothingBoost .. "%)``")
            player:onConsoleMessage("`wDelay: `5" .. finalDelay .. "ms`` `o(Base: " .. baseDelay .. "ms)``")
        end
    end)
end)

-- ============================================================================
-- LOGIN & WORLD ENTER
-- ============================================================================

onPlayerLoginCallback(function(player)
    local userID = player:getUserID()
    player_boosts[userID] = loadBoostData(userID)
    player_base_delays[userID] = loadPlayerBaseDelay(userID)
    updatePlayerDelay(player)
    syncBoostPlaymod(player)
end)

onPlayerEnterWorldCallback(function(world, player)
    updatePlayerDelay(player)
end)

onPlayerDisconnectCallback(function(player)
    local userID = player:getUserID()
    if player:getMod(BOOST_PLAYMOD) then
        player:removeMod(BOOST_PLAYMOD)
    end
    player_boosts[userID] = nil
    player_base_delays[userID] = nil
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

registerLuaCommand({
    command = "boostinfo",
    roleRequired = 0,
    description = "Check your autofarm boost status"
})

registerLuaCommand({
    command = "clearboost",
    roleRequired = 52,
    description = "Clear a player's boost: /clearboost <name>"
})

registerLuaCommand({
    command = "setbasedelay",
    roleRequired = 52,
    description = "Set base delay: /setbasedelay <name> <ms>"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, args = fullCommand:match("^(%S+)%s*(.*)")
    if not cmd then return false end
    
    -- Boost Info
    if cmd == "boostinfo" then
        local userID = player:getUserID()
        local data = getBoostData(userID)
        local totalBoost, consumableBoost, clothingBoost = getTotalBoost(player)
        local baseDelay = getBaseDelayForPlayer(userID)
        local finalDelay = applyBoost(baseDelay, totalBoost)
        
        player:onConsoleMessage("`#=== Autofarm Boost Info ===``")
        player:onConsoleMessage("`wBase Delay: `5" .. baseDelay .. "ms``")
        player:onConsoleMessage("`wTotal Boost: `5" .. totalBoost .. "%``")
        player:onConsoleMessage("`w  - Consumable: `5" .. consumableBoost .. "%`` `o(Stacks: " .. data.consumable_stacks .. ")``")
        player:onConsoleMessage("`w  - Clothing: `5" .. clothingBoost .. "%``")
        player:onConsoleMessage("`wFinal Delay: `5" .. finalDelay .. "ms``")
        
        if data.expire_time > 0 then
            local now = os.time()
            local remaining = data.expire_time - now
            if remaining > 0 then
                local hours = math.floor(remaining / 3600)
                local mins = math.floor((remaining % 3600) / 60)
                player:onConsoleMessage("`wTime Remaining: `5" .. hours .. "h " .. mins .. "m``")
            else
                player:onConsoleMessage("`4Consumable boost expired!``")
            end
        end
        
        return true
    end
    
    -- Clear Boost (Admin)
    if cmd == "clearboost" then
        if not player:hasRole(CONFIG.ADMIN_ROLE) then return false end
        
        local targetName = args:match("^(%S+)$")
        if not targetName then
            player:onConsoleMessage("`oUsage: /clearboost <playername>``")
            return true
        end
        
        local targetPlayer = nil
        local searchName = targetName:lower()
        for _, p in ipairs(getServerPlayers()) do
            if p:getCleanName():lower() == searchName or p:getName():lower() == searchName then
                targetPlayer = p
                break
            end
        end
        
        if not targetPlayer then
            player:onConsoleMessage("`4Player not found online.``")
            return true
        end
        
        local uid = targetPlayer:getUserID()
        local data = getBoostData(uid)
        data.consumable_stacks = 0
        data.expire_time = 0
        saveBoostData(uid, data)
        
        updatePlayerDelay(targetPlayer)
        
        player:onConsoleMessage("`2Boost cleared for " .. targetPlayer:getName() .. "``")
        targetPlayer:onConsoleMessage("`4Your autofarm boost has been cleared by an admin.``")
        
        return true
    end
    
    -- Set Base Delay (Admin)
    if cmd == "setbasedelay" then
        if not player:hasRole(CONFIG.ADMIN_ROLE) then return false end
        
        local targetName, msStr = args:match("^(%S+)%s+(%S+)$")
        if not targetName or not msStr then
            player:onConsoleMessage("`oUsage: /setbasedelay <playername> <ms>``")
            player:onConsoleMessage("`oExample: /setbasedelay Player1 500``")
            player:onConsoleMessage("`oSet to 0 to reset to default (1000ms)``")
            return true
        end
        
        local ms = tonumber(msStr)
        if not ms or ms < 0 then
            player:onConsoleMessage("`4Invalid ms value.``")
            return true
        end
        
        local targetPlayer = nil
        local searchName = targetName:lower()
        for _, p in ipairs(getServerPlayers()) do
            if p:getCleanName():lower() == searchName or p:getName():lower() == searchName then
                targetPlayer = p
                break
            end
        end
        
        if not targetPlayer then
            player:onConsoleMessage("`4Player not found online.``")
            return true
        end
        
        local uid = targetPlayer:getUserID()
        savePlayerBaseDelay(uid, ms)
        
        updatePlayerDelay(targetPlayer)
        
        local actualDelay = (ms > 0) and ms or CONFIG.DEFAULT_BASE_DELAY
        player:onConsoleMessage("`2Set base delay for " .. targetPlayer:getName() .. " to " .. actualDelay .. "ms``")
        targetPlayer:onConsoleMessage("`oYour base autofarm delay has been set to `5" .. actualDelay .. "ms``")
        
        return true
    end
    
    return false
end)

-- ============================================================================
-- TIMER: Check expiration every minute
-- ============================================================================

timer.setInterval(60000, function()
    local now = os.time()
    for _, player in ipairs(getServerPlayers()) do
        if player and player:isOnline() then
            local userID = player:getUserID()
            local data = getBoostData(userID)
            
            -- Check if just expired
            if data.expire_time > 0 and now >= data.expire_time and data.consumable_stacks > 0 then
                data.consumable_stacks = 0
                data.expire_time = 0
                saveBoostData(userID, data)
                
                updatePlayerDelay(player)
                syncBoostPlaymod(player)
                
                player:onConsoleMessage("`4Your autofarm consumable boost has expired!``")
                player:playAudio("audio/bleep_fail.wav", 0)
            end
        end
    end
end)

-- ============================================================================
-- AUTO SAVE
-- ============================================================================

onAutoSaveRequest(function()
    for userID, data in pairs(player_boosts) do
        saveBoostData(userID, data)
    end
    for userID, delay in pairs(player_base_delays) do
        savePlayerBaseDelay(userID, delay)
    end
end)

-- ============================================================================
-- GLOBAL EXPORTS (for setdelay.lua integration)
-- ============================================================================

-- Export function so setdelay.lua can detect boost system
function isAutofarmBoostSystemActive()
    return true
end

-- Export function to get current boost multiplier
function getPlayerBoostMultiplier(userID)
    -- Get player
    local player = nil
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == userID then
            player = p
            break
        end
    end
    
    if not player then return 1.0 end
    
    local totalBoost = getTotalBoost(player)
    -- Convert boost% to multiplier: 100% boost = 2.0x, 200% = 3.0x, 300% = 4.0x
    return 1 + (totalBoost / 100)
end

-- Export function to get boosted delay
function getPlayerBoostedDelay(userID)
    local player = nil
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == userID then
            player = p
            break
        end
    end
    
    if not player then return CONFIG.DEFAULT_BASE_DELAY end
    
    local baseDelay = getBaseDelayForPlayer(userID)
    local totalBoost = getTotalBoost(player)
    return applyBoost(baseDelay, totalBoost)
end

-- ============================================================================
-- INIT
-- ============================================================================

