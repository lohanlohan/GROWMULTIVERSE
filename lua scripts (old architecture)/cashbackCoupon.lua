-- =========================================
-- CASHBACK COUPON SCRIPT (GTPS CLOUD SAFE)
-- Item ID : 10394
-- =========================================

local CASHBACK_ITEM_ID = 10394
local PRESIDENT_ROLE  = 51
local DB_KEY = "cashback_coupon_gems"

-- ================= DEFAULT SETTING =================
local DEFAULT_GEMS = 1000
-- ==================================================

-- ================= DATABASE =================
local function getGemReward()
    local raw = loadStringFromServer(DB_KEY)
    local val = tonumber(raw)
    if val and val > 0 then
        return val
    end
    return DEFAULT_GEMS
end

local function setGemReward(amount)
    saveStringToServer(DB_KEY, tostring(amount))
end
-- ============================================

-- ================= ADMIN COMMAND =================
registerLuaCommand({
    command = "setcashback",
    roleRequired = PRESIDENT_ROLE,
    description = "Set gems reward for Cashback Coupon"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, arg = fullCommand:match("^(%S+)%s*(.*)$")
    if cmd ~= "setcashback" then return false end

    if not arg:match("^%d+$") then
        player:onConsoleMessage("`4Usage: /setcashback <gems>")
        return true
    end

    local gems = tonumber(arg)
    if gems < 1 then gems = 1 end

    setGemReward(gems)
    player:onConsoleMessage("`2Cashback Coupon set to " .. gems .. " gems")
    player:onTalkBubble(player:getNetID(),
        "`2Cashback Coupon reward updated!``", 1)
    return true
end)
-- ================================================

-- ================= ITEM USE =================
onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= CASHBACK_ITEM_ID then return false end

    if not clickedPlayer then
        player:onTalkBubble(player:getNetID(),
            "`4Use this item on a player!``", 1)
        return true
    end

    -- Remove item
    if not player:changeItem(CASHBACK_ITEM_ID, -1, 0) then
        return true
    end

    local gems = getGemReward()

    -- GIVE GEMS (INI YANG BENER)
    clickedPlayer:addGems(gems, 1, 1)

    -- EFFECT & FEEDBACK
    world:useItemEffect(
        player:getNetID(),
        CASHBACK_ITEM_ID,
        clickedPlayer:getNetID(),
        0
    )

    clickedPlayer:onTalkBubble(
        clickedPlayer:getNetID(),
        "`2+" .. gems .. " Gems!``",
        1
    )

    clickedPlayer:onConsoleMessage(
        "`2You received " .. gems .. " gems from Cashback Coupon!``"
    )

    return true
end)
-- ============================================
