-- MODULE
-- vile_vial.lua — Vile Vials (item 8538-8548): infeksi malady ke player
-- Cross-feature: _G.MaladySystem (dari hospital feature)

local M  = {}
local DB = _G.DB

local VICIOUS_CHANCE = 20

local VIAL_TO_MALADY = {
    [8538] = "CHAOS_INFECTION",
    [8544] = "LUPUS",
    [8542] = "BRAINWORMS",
    [8540] = "MOLDY_GUTS",
    [8546] = "ECTO_BONES",
    [8548] = "FATTY_LIVER",
}

local function recordUse(itemID, isVicious)
    local data = DB.loadFeature("vile_vial")
    if type(data.stats) ~= "table" then data.stats = {} end
    local key = tostring(itemID)
    if not data.stats[key] then data.stats[key] = { uses = 0, vicious = 0 } end
    data.stats[key].uses    = data.stats[key].uses    + 1
    data.stats[key].vicious = data.stats[key].vicious + (isVicious and 1 or 0)
    DB.saveFeature("vile_vial", data)
end

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    local maladyKey = VIAL_TO_MALADY[itemID]
    if not maladyKey then return false end

    local MS = _G.MaladySystem
    if not MS then
        player:onTalkBubble(player:getNetID(), "`4Malady system not available.", 0)
        return true
    end

    local maladyType = MS.MALADY and MS.MALADY[maladyKey]
    if not maladyType then return true end

    local maladyName = (MS.MALADY_DISPLAY and MS.MALADY_DISPLAY[maladyType]) or maladyKey
    local target     = clickedPlayer or player
    local isSelf     = (clickedPlayer == nil or clickedPlayer == player)

    if MS.hasActiveMalady(target) then
        local activeName = (MS.MALADY_DISPLAY and MS.MALADY_DISPLAY[MS.getActiveMalady(target)]) or "a malady"
        if isSelf then
            player:onTalkBubble(player:getNetID(), "`4You are already infected with " .. activeName .. "!", 0)
        else
            player:onTalkBubble(player:getNetID(), "`4" .. target:getName() .. " is already infected with " .. activeName .. "!", 0)
        end
        return true
    end

    player:changeItem(itemID, -1, 0)

    local isVicious = math.random(1, 100) <= VICIOUS_CHANCE
    local ok, reason = MS.forceInfect(target, maladyType, "VIAL", isVicious, true)

    if ok then
        recordUse(itemID, isVicious)
        local tag = isVicious and " `4[Vicious]`o" or ""
        if isSelf then
            player:onTalkBubble(player:getNetID(), "`4You infected yourself with " .. maladyName .. "!" .. tag, 0)
        else
            player:onTalkBubble(player:getNetID(), "`4You infected " .. target:getName() .. " with " .. maladyName .. "!" .. tag, 0)
            target:onTalkBubble(target:getNetID(), "`4" .. player:getName() .. " infected you with " .. maladyName .. "!" .. tag, 0)
        end
    else
        player:onTalkBubble(player:getNetID(), "`4Failed: " .. tostring(reason), 0)
    end

    return true
end)

return M
