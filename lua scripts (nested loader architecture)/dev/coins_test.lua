-- coins_test.lua — test coins API (role 51 only)
-- /coinstest get       → baca balance dengan getCoins vs GetCoins
-- /coinstest add N     → addCoins(N) lalu baca ulang
-- /coinstest set N     → setCoins(N) lalu baca ulang

onPlayerCommandCallback(function(world, player, full)
    local args = {}
    for w in full:gmatch("%S+") do args[#args + 1] = w end
    local cmd = (args[1] or ""):lower()
    if cmd ~= "coinstest" then return false end
    if not player:hasRole(51) then return true end

    local sub = args[2] or "get"
    local n   = tonumber(args[3]) or 100

    if sub == "get" then
        local lower = player:getCoins()
        local upper = player:GetCoins()
        player:onConsoleMessage("`wgetCoins() = `2" .. tostring(lower))
        player:onConsoleMessage("`wGetCoins() = `2" .. tostring(upper))

    elseif sub == "add" then
        player:onConsoleMessage("`oBefore addCoins: " .. tostring(player:getCoins()))
        player:addCoins(n)
        player:onConsoleMessage("`2After addCoins(" .. n .. "): " .. tostring(player:getCoins()))

    elseif sub == "set" then
        player:setCoins(n)
        player:onConsoleMessage("`2After setCoins(" .. n .. "): " .. tostring(player:getCoins()))
    end

    return true
end)
