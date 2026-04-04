-- MODULE
-- cashback_coupon.lua — Cashback Coupon (item ID 10394): gunakan ke player untuk beri gems
-- Jumlah gems bisa diatur via /setcashback (staff only)

local M = {}
local Utils  = _G.Utils
local DB     = _G.DB
local Config = _G.Config

local ITEM_ID     = 10394
local DB_KEY      = "cashback_gems"
local DEFAULT_GEMS = 1000

local function getGemReward()
    local val = tonumber(DB.loadStr(DB_KEY))
    return (val and val > 0) and val or DEFAULT_GEMS
end

registerLuaCommand({
    command      = "setcashback",
    roleRequired = Config.ROLES.STAFF,
    description  = "Set gem reward for Cashback Coupon.",
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = Utils.parseArgs(fullCommand)
    if args[1]:lower() ~= "/setcashback" then return false end
    if not Utils.isPrivileged(player) then return false end

    local gems = tonumber(args[2])
    if not gems or gems < 1 then
        Utils.msg(player, "`4Usage: /setcashback <gems>")
        return true
    end

    DB.saveStr(DB_KEY, tostring(gems))
    Utils.msg(player, "`2Cashback Coupon set to " .. gems .. " gems.")
    return true
end)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= ITEM_ID then return false end

    if not clickedPlayer then
        Utils.bubble(world, player, "`4Use this on a player!``")
        return true
    end

    if not player:changeItem(ITEM_ID, -1, 0) then return true end

    local gems = getGemReward()
    clickedPlayer:addGems(gems, 1, 1)
    world:useItemEffect(player:getNetID(), ITEM_ID, clickedPlayer:getNetID(), 0)
    clickedPlayer:onTalkBubble(clickedPlayer:getNetID(), "`2+" .. gems .. " Gems!``", 1)
    Utils.msg(clickedPlayer, "`2You received " .. gems .. " gems from Cashback Coupon!``")
    return true
end)

return M
