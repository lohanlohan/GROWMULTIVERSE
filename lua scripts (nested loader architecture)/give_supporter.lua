-- MODULE
-- give_supporter.lua — /givesupp /giveinv: grant supporter role or inventory slots

local M = {}

local ROLE_DEV        = 51
local MAX_INVENTORY   = 396

registerLuaCommand({ command = "givesupp", roleRequired = ROLE_DEV, description = "Grants Supporter or Super Supporter role to a player." })
registerLuaCommand({ command = "giveinv",  roleRequired = ROLE_DEV, description = "Give inventory space to a player." })

local function findPlayer(name)
    local needle = name:lower()
    for _, p in ipairs(getServerPlayers()) do
        local nm = (p.getCleanName and p:getCleanName()) or p:getName()
        if nm and nm:lower() == needle then return p end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "givesupp" and cmd ~= "giveinv" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if args == "" then
        player:onConsoleMessage("Usage: /" .. cmd .. " <playerName> <sup/ssup|amount>")
        return true
    end

    local targetName, param = args:match("^(%S+)%s*(%S*)$")
    local target = findPlayer(targetName or "")
    if not target then
        player:onConsoleMessage("Player '" .. (targetName or "") .. "' not found or not online.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if cmd == "giveinv" then
        local amount = tonumber(param)
        if not amount then
            player:onConsoleMessage("Usage: /giveinv <playerName> <amount>")
            return true
        end
        if amount <= 0 then
            player:onConsoleMessage("Invalid amount. Must be greater than zero.")
            player:playAudio("bleep_fail.wav")
            return true
        end
        local current = target:getInventorySize()
        local give    = math.min(amount, MAX_INVENTORY - current)
        if give <= 0 then
            player:onConsoleMessage(target:getName() .. " already has max inventory space (" .. current .. ").")
            player:playAudio("bleep_fail.wav")
            return true
        end
        target:upgradeInventorySpace(give)
        player:onConsoleMessage("Increased " .. target:getName() .. "'s inventory by " .. give .. " slots to " .. (current + give) .. ".")
        player:playAudio("piano_nice.wav")
        target:onConsoleMessage("Your inventory space has been increased by " .. give .. " slots!")
        target:playAudio("success.wav")
        return true
    end

    -- /givesupp
    local tier = param:lower()
    local cost, roleName
    if tier == "ssup" then
        cost = 100; roleName = "Super Supporter"
    elseif tier == "sup" then
        cost = 35;  roleName = "Supporter"
    else
        player:onConsoleMessage("Invalid tier. Use 'sup' or 'ssup'.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    target:addCoins(cost)
    target:removeCoins(cost, 1)
    player:onConsoleMessage("You have successfully granted " .. roleName .. " Role to " .. target:getName() .. ".")
    player:playAudio("piano_nice.wav")
    target:onConsoleMessage("You have been granted the `#" .. roleName .. " Role`o by a Developer!")
    target:sendVariant({ "OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Role!", "audio/success.wav", 0 })
    return true
end)

return M
