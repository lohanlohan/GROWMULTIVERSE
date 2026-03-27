-- MODULE
-- set_slots.lua — /setslots command untuk set autofarm slots player

local M = {}
local Utils  = _G.Utils
local Config = _G.Config

local CMD = "setslots"
local USAGE = "`oUsage: /setslots <`$name``> <`$amount``> - Set autofarm slots player, works offline!``"

registerLuaCommand({
    command     = CMD,
    roleRequired = Config.ROLES.STAFF,
    description = "Set autofarm slots of a player."
})

local function findExactMatch(players, name)
    for _, p in ipairs(players) do
        if p:getCleanName():lower() == name:lower() then
            return { p }
        end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = Utils.parseArgs(fullCommand)
    if args[1]:lower() ~= "/" .. CMD then return false end

    if not Utils.isPrivileged(player) then return false end

    local targetName = args[2]
    local amount     = tonumber(args[3])

    if not targetName or not amount or amount <= 0 then
        Utils.msg(player, USAGE)
        return true
    end

    local found = getPlayerByName(targetName)

    if not found or #found == 0 then
        Utils.msg(player, "`4Nobody online with name starting with `w" .. targetName .. "``.")
        return true
    end

    if #found > 1 then
        local exact = findExactMatch(found, targetName)
        if exact then
            found = exact
        else
            local names = {}
            for i = 1, math.min(3, #found) do
                names[#names + 1] = "`w" .. found[i]:getName() .. "``"
            end
            local extra = (#found > 3) and (" and `w" .. (#found - 3) .. "`` more...") or "."
            Utils.msg(player, "`oMore than one match for `w" .. targetName .. "``. Be specific: " .. table.concat(names, ", ") .. extra)
            return true
        end
    end

    local target = found[1]
    target:getAutofarm():setSlots(amount)
    Utils.msg(player, "`6>> Set `$" .. Utils.formatNum(amount) .. " autofarm slots`` to `w" .. target:getCleanName() .. "``.")

    return true
end)

return M
