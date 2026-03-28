-- MODULE
-- tile_debug.lua — /tile: debug tile data at player's position

local M = {}

local ROLE_DEV = 51

local TILE_DATA_PROPERTY_NAMES = {
    [0]  = "SEED_FRUITS_COUNT",
    [1]  = "SEED_PLANTED_TIME",
    [2]  = "MAGPLANT_ITEM_COUNT",
    [3]  = "VENDING_ITEM_COUNT",
    [4]  = "SIGN_TEXT",
    [5]  = "DOOR_TEXT",
    [6]  = "DOOR_IS_OPEN",
    [7]  = "DOOR_DESTINATION",
    [8]  = "DOOR_ID",
    [9]  = "VENDING_ITEM_ID",
    [10] = "VENDING_PRICE",
    [11] = "VENDING_EARNED",
    [12] = "DISPLAY_BLOCK_ITEM_ID",
    [13] = "MAGPLANT_ITEM_ID",
    [14] = "MAGPLANT_IS_ACTIVE",
    [15] = "MAGPLANT_IS_MAGNET",
    [16] = "MAGPLANT_SPACE",
    [17] = "MAGPLANT_GEMS",
    [18] = "MAGPLANT_SECOND_ITEM_ID",
    [19] = "MAGPLANT_IS_ENABLED",
    [20] = "MAGPLANT_HARVEST_TREES",
    [21] = "MAGPLANT_COLLECT_SEEDS",
}

local function isMeaningful(value)
    if value == nil    then return false end
    if type(value) == "number"  then return value ~= 0 end
    if type(value) == "string"  then return value ~= "" end
    if type(value) == "boolean" then return value == true end
    if type(value) == "table"   then return next(value) ~= nil end
    return true
end

local function toStrValue(value)
    if type(value) ~= "table" then return tostring(value), type(value) end
    local items, count = {}, 0
    for k, v in pairs(value) do
        count = count + 1
        items[#items+1] = tostring(k) .. "=" .. tostring(v)
        if count >= 6 then break end
    end
    if #items == 0 then return "{}", "table" end
    if count >= 6  then items[#items+1] = "..." end
    return "{" .. table.concat(items, ", ") .. "}", "table"
end

local function handleTile(world, player)
    local px = math.floor((player:getPosX() or 0) / 32)
    local py = math.floor((player:getPosY() or 0) / 32)
    local tile = world:getTile(px, py)
    if not tile then
        player:onConsoleMessage("`4Tile not found at your position.")
        return
    end

    local tx = tile:getPosX()
    local ty = tile:getPosY()
    local fg = tonumber(tile:getTileID()) or 0

    player:onConsoleMessage("`wTile: `o(" .. tx .. "," .. ty .. ")")
    player:onConsoleMessage("`wFG/BG: `o" .. tostring(fg) .. "`w/`o" .. tostring(tile:getTileBackground()))
    player:onConsoleMessage("`wFlags: `o" .. tostring(tile:getFlags()))

    -- Special tile handlers
    if fg == 14666 then
        player:onConsoleMessage("`wDetected: `oAUTO_SURGEON_ID (14666)")
        local fn = rawget(_G, "getAutoSurgeonTileDebugInfo")
        if type(fn) == "function" then
            local info = fn(world, tile)
            if type(info) == "table" then
                player:onConsoleMessage("`wStation exists: `o" .. tostring(info.station_exists))
                player:onConsoleMessage("`wMalady type: `o" .. tostring(info.malady_type))
                player:onConsoleMessage("`wEnabled: `o" .. tostring(info.enabled))
                player:onConsoleMessage("`wPrice WL: `o" .. tostring(info.price_wl))
                player:onConsoleMessage("`wEarned WL: `o" .. tostring(info.earned_wl))
                player:onConsoleMessage("`wStorage total: `o" .. tostring(info.storage_total))
                player:onConsoleMessage("`wOut of order: `o" .. tostring(info.out_of_order))
                player:onConsoleMessage("`wSelected illness ID: `o" .. tostring(info.selected_illness_id))
            else
                player:onConsoleMessage("`4Failed to read Auto Surgeon debug info.")
            end
        else
            player:onConsoleMessage("`4Auto Surgeon debug bridge not registered.")
        end
    elseif fg == 14662 then
        local statusFn = rawget(_G, "getOperatingStatusForTable")
        if type(statusFn) == "function" then
            local statusText = statusFn(world:getName(), tx, ty, os.time())
            player:onConsoleMessage("`wOperating status: `o" .. tostring(statusText))
        end
    end

    -- Auto-scan TileData
    local found = {}
    for prop = 0, 64 do
        local val = tile:getTileData(prop)
        if isMeaningful(val) then found[#found+1] = { property = prop, value = val } end
    end

    if #found > 0 then
        player:onConsoleMessage("`wTileData auto-scan (`o" .. #found .. "`w entries):")
        for _, row in ipairs(found) do
            local label    = TILE_DATA_PROPERTY_NAMES[row.property] or ("PROPERTY_" .. row.property)
            local text, vt = toStrValue(row.value)
            player:onConsoleMessage("`w[" .. row.property .. "] `o" .. label .. " `w(" .. vt .. "): `o" .. text)
        end
    else
        player:onConsoleMessage("`wNo non-empty TileData found (0-64).")
        player:onConsoleMessage("`wShowing known properties 0-21:")
        for prop = 0, 21 do
            local label    = TILE_DATA_PROPERTY_NAMES[prop] or ("PROPERTY_" .. prop)
            local val      = tile:getTileData(prop)
            local text, vt = toStrValue(val)
            player:onConsoleMessage("`w[" .. prop .. "] `o" .. label .. " `w(" .. vt .. "): `o" .. text)
        end
    end
end

local TILE_FLAG_HAS_EXTRA_DATA = bit.lshift(1, 0)  -- bit 0 = 1
local AUTO_SURGEON_ID          = 14666

local function handleClearXData(world, player)
    local tiles   = world:getTiles()
    local cleared = 0
    for _, tile in ipairs(tiles) do
        local flags = tile:getFlags()
        if bit.band(flags, TILE_FLAG_HAS_EXTRA_DATA) ~= 0 then
            local fg = tonumber(tile:getTileForeground()) or 0
            if fg ~= AUTO_SURGEON_ID then
                tile:setFlags(bit.band(flags, bit.bnot(TILE_FLAG_HAS_EXTRA_DATA)))
                world:updateTile(tile)
                cleared = cleared + 1
            end
        end
    end
    player:onConsoleMessage("`2[clearxdata] Done — `w" .. cleared .. " `2tiles cleared.")
end

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd then return false end
    cmd = cmd:lower()

    if cmd == "clearxdata" then
        if not player:hasRole(ROLE_DEV) then
            player:onConsoleMessage("`4No permission.")
            return true
        end
        handleClearXData(world, player)
        return true
    end

    if cmd ~= "tile" then return false end
    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4No permission.")
        return true
    end
    handleTile(world, player)
    return true
end)

-- Global export for cross-feature debug bridge compatibility
_G.TileDebug = M

return M
