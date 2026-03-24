local giveSupporterCommand = "givesupp"
local giveInventorySlotCommand = "giveinv"

local Roles = {
    ROLE_DEVELOPER = 51,
}

registerLuaCommand({
    command = giveSupporterCommand,
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Grants the Supporter or Super Supporter role to a player."
})

registerLuaCommand({
    command = giveInventorySlotCommand,
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Give inventory space to a player."
})

local function findPlayerByNameInsensitive(inputName)
    local target = string.lower(inputName)
    for _, p in ipairs(getServerPlayers()) do
        if string.lower(p:getCleanName()) == target then
            return p
        end
    end
    return nil
end

onPlayerCommandCallback(function(world, player, fullCommand)

    local command, args = fullCommand:match("^(%S+)%s*(.*)$")

    if command ~= giveSupporterCommand and command ~= giveInventorySlotCommand then return false end

    if not player:hasRole(Roles.ROLE_DEVELOPER) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if args == "" then
        player:onConsoleMessage("Usage: /" .. command .. " <playerName> <sup/ssup>")
        player:playAudio("thwoop.wav")
        return true
    end

    local targetName, tier = args:match("^(%S+)%s*(%S*)$")
    local target = findPlayerByNameInsensitive(targetName)

    if not target then
        player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if command == giveInventorySlotCommand then

        local targetName, amountStr = args:match("^(%S+)%s*(%S*)$")
        local target = findPlayerByNameInsensitive(targetName)

        if not target then
            player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        local amount = tonumber(amountStr)
        local maxInventory = 396
        local currentInventory = target:getInventorySize()

        if not amount then
            player:onConsoleMessage("Usage: /giveinv <playerName> <amount>")
            player:playAudio("thwoop.wav")
            return true
        end

        if amount <= 0 then
            player:onConsoleMessage("Invalid amount. Must be greater than zero.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        local newInventory = currentInventory + amount
        if newInventory > maxInventory then
            amount = maxInventory - currentInventory
            newInventory = maxInventory
        end

        if amount <= 0 then
            player:onConsoleMessage(target:getName() .. " already has max inventory space (" .. currentInventory .. ").")
            player:playAudio("bleep_fail.wav")
            return true
        end

        player:onConsoleMessage("Increased " .. target:getName() .. "'s inventory by " .. amount .. " slots to " .. newInventory .. ".")
        player:playAudio("piano_nice.wav")
        target:upgradeInventorySpace(amount)
        target:onConsoleMessage("Your inventory space has been increased by " .. amount .. " slots!")
        target:playAudio("success.wav")

        return true
    end

    local supporterCost = 0
    local roleName = ""

    if tier == "ssup" then
        supporterCost = 100
        roleName = "Super Supporter"
    elseif tier == "sup" then
        supporterCost = 35
        roleName = "Supporter"
    else
        player:onConsoleMessage("Invalid tier. Use 'sup' or 'ssup'.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    target:addCoins(supporterCost)
    target:removeCoins(supporterCost, 1)

    player:onConsoleMessage("You have successfully granted " .. roleName .. " Role to " .. target:getName() .. ".")
    player:playAudio("piano_nice.wav")
    target:onConsoleMessage("You have been granted the `#" .. roleName .. " Role`o by a Developer!")
    target:sendVariant({"OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Role!", "audio/success.wav", 0})

    return true
end)