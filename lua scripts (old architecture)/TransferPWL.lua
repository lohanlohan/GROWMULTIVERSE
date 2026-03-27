local TOKEN_ID = 20234
local TOKEN_NAME = getItem(TOKEN_ID):getName()

-- command config
local transferCommand = {
    command = "transfer",
    roleRequired = 0, -- semua player bisa pakai
    description = "Transfer your PWL (" .. TOKEN_NAME .. ") to another player."
}

registerLuaCommand(transferCommand)

-- helper
local function findPlayerByNameInsensitive(name)
    name = name:lower()
    for _, p in ipairs(getServerPlayers()) do
        if p:getCleanName():lower() == name then
            return p
        end
    end
    return nil
end

local function fail(p, msg)
    p:onConsoleMessage(msg)
    p:onTextOverlay("`4Failed")
    p:playAudio("bleep_fail.wav")
end

local function success(p, msg)
    p:onConsoleMessage(msg)
    p:onTextOverlay("`2Success")
    p:playAudio("coin_flip.wav")
end

-- === MAIN CALLBACK ===
onPlayerCommandCallback(function(world, player, fullCommand)
    local command, args = fullCommand:match("^(%S+)%s*(.*)$")
    if not command or command ~= transferCommand.command then return false end

    local targetName, amountStr = args:match("^(%S+)%s+(%S+)$")
    if not targetName or not amountStr then
        fail(player, "Usage: /transfer <playerName> <amount>")
        return true
    end

    local amount = tonumber(amountStr)
    if not amount or amount <= 0 then
        fail(player, "Invalid amount.")
        return true
    end

    local target = findPlayerByNameInsensitive(targetName)
    if not target then
        fail(player, "Player '" .. targetName .. "' not found or offline.")
        return true
    end

    if target:getCleanName():lower() == player:getCleanName():lower() then
        fail(player, "You cannot transfer to yourself.")
        return true
    end

    local senderCoins = player:getCoins()
    if senderCoins < amount then
        fail(player, "Not enough " .. TOKEN_NAME .. ".")
        return true
    end

    -- transfer coins
    player:setCoins(senderCoins - amount)
    target:setCoins(target:getCoins() + amount)

    success(player, "You sent " .. amount .. " " .. TOKEN_NAME .. " to " .. target:getName() .. ".")
    target:onConsoleMessage("You received " .. amount .. " " .. TOKEN_NAME .. " from " .. player:getName() .. ".")
    target:playAudio("cash_register.wav")

    return true
end)
