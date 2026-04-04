-- MODULE
-- xdata_debug.lua — Debug tile extra data callback untuk native GT items
-- Upload standalone, hapus setelah selesai debug

local LOG_ENABLED = true
local ROLE_DEV    = 51

local TILE_FLAG_HAS_EXTRA_DATA = bit.lshift(1, 0)  -- flag bit 0 = 1

-- /xdatalog on|off — toggle logging
-- /xtest <tileX> <tileY> — test real-time updateTile pada tile tertentu
onPlayerCommandCallback(function(world, player, cmd)
    local args = {}
    for w in cmd:gmatch("%S+") do table.insert(args, w) end
    local command = (args[1] or ""):lower()

    if command == "xdatalog" then
        if not player:hasRole(ROLE_DEV) then return true end
        local sub = (args[2] or ""):lower()
        if sub == "on" then
            LOG_ENABLED = true
            player:onConsoleMessage("`2[xdata] logging ON")
        elseif sub == "off" then
            LOG_ENABLED = false
            player:onConsoleMessage("`6[xdata] logging OFF")
        else
            local state = LOG_ENABLED and "`2ON" or "`6OFF"
            player:onConsoleMessage("[xdata] logging is " .. state .. " — /xdatalog on|off")
        end
        return true
    end

    if command == "xtest" then
        if not player:hasRole(ROLE_DEV) then return true end
        local tx = tonumber(args[2])
        local ty = tonumber(args[3])
        if not tx or not ty then
            player:onConsoleMessage("`6Usage: /xtest <tileX> <tileY>  (0-indexed tile coords)")
            player:onConsoleMessage("`6Tip: pixel coords dari log dibagi 32, contoh: x=896 y=1696 → /xtest 28 53")
            return true
        end

        local tile = world:getTile(tx, ty)
        if not tile then
            player:onConsoleMessage("`4[xtest] tile not found at " .. tx .. "," .. ty)
            return true
        end

        local fg = tonumber(tile:getTileForeground()) or 0
        local currentFlags = tile:getFlags()
        local hasFlag = bit.band(currentFlags, TILE_FLAG_HAS_EXTRA_DATA) ~= 0

        player:onConsoleMessage("[xtest] tile fg=" .. fg .. " flags=" .. currentFlags .. " HAS_EXTRA_DATA=" .. tostring(hasFlag))
        player:onConsoleMessage("[xtest] calling world:updateTile — watch console for callback log...")

        -- Test 1: updateTile saja (tanpa set flag)
        world:updateTile(tile)
        player:onConsoleMessage("[xtest] updateTile called (no flag change). Callback fired? Check log above.")

        return true
    end

    if command == "xtest2" then
        if not player:hasRole(ROLE_DEV) then return true end
        local tx = tonumber(args[2])
        local ty = tonumber(args[3])
        if not tx or not ty then
            player:onConsoleMessage("`6Usage: /xtest2 <tileX> <tileY>")
            return true
        end

        local tile = world:getTile(tx, ty)
        if not tile then
            player:onConsoleMessage("`4[xtest2] tile not found at " .. tx .. "," .. ty)
            return true
        end

        local fg = tonumber(tile:getTileForeground()) or 0
        local currentFlags = tile:getFlags()

        -- Test 2: set flag dulu, lalu updateTile
        tile:setFlags(bit.bor(currentFlags, TILE_FLAG_HAS_EXTRA_DATA))
        world:updateTile(tile)
        player:onConsoleMessage("[xtest2] tile fg=" .. fg .. " — SET flag + updateTile called. Callback fired? Check log.")

        return true
    end

    return false
end)

-- Log setiap tile yang trigger onGetTileExtraDataCallback
onGetTileExtraDataCallback(function(world, tile, game_version)
    if not LOG_ENABLED then return false end
    if type(tile) ~= "userdata" then return false end

    local fg = tonumber(tile:getTileForeground()) or 0
    if fg == 0 then return false end

    local x = tile:getPosX()
    local y = tile:getPosY()
    print("[xdata] CALLBACK FIRED — tile fg=" .. tostring(fg) .. " x=" .. tostring(x) .. " y=" .. tostring(y))

    return false
end)

return {}
