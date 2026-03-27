-- MODULE
-- give_gems.lua — /givegems: give gems to online player

local M = {}

local ROLE_DEV = 51

local function formatNum(n)
    local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return s
end

local function findExact(list, name)
    local needle = name:lower()
    for _, p in ipairs(list) do
        if p:getCleanName():lower() == needle then return { p } end
    end
    return nil
end

registerLuaCommand({
    command     = "givegems",
    roleRequired = ROLE_DEV,
    description = "Give gems to a player."
})

onPlayerCommandCallback(function(world, player, full)
    local cmd, msg = full:match("^(%S+)%s*(.*)")
    if not cmd or cmd:lower() ~= "givegems" then return false end

    if not player:hasRole(ROLE_DEV) then return false end

    local targetName, amountStr = msg:match("^(%S+)%s+(%d+)$")
    if not targetName or not amountStr then
        player:onConsoleMessage("`oUsage: /givegems <name> <amount>")
        return true
    end

    local amount = tonumber(amountStr)
    if not amount or amount <= 0 then
        player:onConsoleMessage("`oUsage: /givegems <name> <amount>")
        return true
    end

    local found = getPlayerByName(targetName)
    if not found or #found == 0 then
        player:onConsoleMessage("`4Oops: `oNobody online with a name starting with `w" .. targetName .. "``.")
        return true
    end

    if #found > 1 then
        local exact = findExact(found, targetName)
        if exact then
            found = exact
        else
            local names = {}
            for i = 1, math.min(#found, 3) do
                names[#names+1] = "`w" .. found[i]:getName() .. "``"
            end
            local extra = #found > 3 and (" and `w" .. formatNum(#found - 3) .. "`` more...") or "."
            player:onConsoleMessage("`oMore than one match for `w" .. targetName .. "``. Be more specific. Matches: " .. table.concat(names, ", ") .. extra)
            return true
        end
    end

    found[1]:addGems(amount, 0, 1)
    player:onConsoleMessage("`6>> Given `$" .. formatNum(amount) .. " Gems`` to " .. found[1]:getCleanName() .. ".``")
    return true
end)

return M
