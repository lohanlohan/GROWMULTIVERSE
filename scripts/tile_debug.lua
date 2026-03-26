-- MODULE

local TileDebug = {}

local TILE_DATA_PROPERTY_NAMES = {
    [0] = "SEED_FRUITS_COUNT",
    [1] = "SEED_PLANTED_TIME",
    [2] = "MAGPLANT_ITEM_COUNT",
    [3] = "VENDING_ITEM_COUNT",
    [4] = "SIGN_TEXT",
    [5] = "DOOR_TEXT",
    [6] = "DOOR_IS_OPEN",
    [7] = "DOOR_DESTINATION",
    [8] = "DOOR_ID",
    [9] = "VENDING_ITEM_ID",
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
    [21] = "MAGPLANT_COLLECT_SEEDS"
}

local AUTO_SCAN_MIN_PROPERTY = 0
local AUTO_SCAN_MAX_PROPERTY = 64

local function isMeaningfulValue(value)
    local t = type(value)
    if value == nil then return false end
    if t == "number" then return value ~= 0 end
    if t == "string" then return value ~= "" end
    if t == "boolean" then return value == true end
    if t == "table" then return next(value) ~= nil end
    return true
end

local function getPropertyLabel(property)
    return TILE_DATA_PROPERTY_NAMES[property] or ("PROPERTY_" .. tostring(property))
end

local function toStringValue(value)
    local valueType = type(value)
    if valueType ~= "table" then
        return tostring(value), valueType
    end

    local items = {}
    local count = 0
    for k, v in pairs(value) do
        count = count + 1
        items[#items + 1] = tostring(k) .. "=" .. tostring(v)
        if count >= 6 then break end
    end
    if #items == 0 then
        return "{}", "table"
    end
    if count >= 6 then
        items[#items + 1] = "..."
    end
    return "{" .. table.concat(items, ", ") .. "}", "table"
end

function TileDebug.handleTileCommand(world, player, parts, safeConsole, safeBubble)
    local cmd = string.lower(tostring(parts and parts[1] or ""))
    if cmd ~= "tile" and cmd ~= "/tile" then return false end

    if type(world) ~= "userdata" or type(player) ~= "userdata" then return true end

    local px = math.floor((player:getPosX() or 0) / 32)
    local py = math.floor((player:getPosY() or 0) / 32)
    local tile = world:getTile(px, py)
    if not tile then
        safeBubble(player, "`4Tile not found at your position.")
        return true
    end

    local tx = tile:getPosX()
    local ty = tile:getPosY()
    local fg = tonumber(tile:getTileID()) or 0
    safeConsole(player, "`wTile: `o(" .. tostring(tx) .. "," .. tostring(ty) .. ")")
    safeConsole(player, "`wFG/BG: `o" .. tostring(fg) .. "`w/`o" .. tostring(tile:getTileBackground()))
    safeConsole(player, "`wFlags: `o" .. tostring(tile:getFlags()))

    if fg == 14666 then
        safeConsole(player, "`wDetected: `oAUTO_SURGEON_ID (14666)")
        safeConsole(player, "`wTileData can be empty for this custom tile. Reading hospital station state...")
        local fn = rawget(_G, "getAutoSurgeonTileDebugInfo")
        if type(fn) == "function" then
            local info = fn(world, tile)
            if type(info) == "table" then
                safeConsole(player, "`wStation exists: `o" .. tostring(info.station_exists))
                safeConsole(player, "`wStation malady_type: `o" .. tostring(info.malady_type))
                safeConsole(player, "`wStation enabled: `o" .. tostring(info.enabled))
                safeConsole(player, "`wStation price_wl: `o" .. tostring(info.price_wl))
                safeConsole(player, "`wStation earned_wl: `o" .. tostring(info.earned_wl))
                safeConsole(player, "`wStation storage_total: `o" .. tostring(info.storage_total))
                safeConsole(player, "`wTileExtra outOfOrder: `o" .. tostring(info.out_of_order))
                safeConsole(player, "`wTileExtra selectedIllness: `o" .. tostring(info.selected_illness_id))
                safeConsole(player, "`wTileExtra wlCountVisual: `o" .. tostring(info.wl_count_visual))
                safeConsole(player, "`wForced illness ID: `o" .. tostring(info.forced_illness_id or "nil"))
                safeConsole(player, "`wForced wl visual: `o" .. tostring(info.forced_wl_visual or "nil"))
            else
                safeConsole(player, "`4Failed to read Auto Surgeon station debug info.")
            end
        else
            safeConsole(player, "`4Auto Surgeon debug bridge is not registered yet.")
        end
    elseif fg == 14662 then
        local getWorldName = rawget(_G, "getWorldName")
        local worldName = ""
        if type(getWorldName) == "function" then
            worldName = tostring(getWorldName(world, player) or "")
        elseif world and world.getName then
            worldName = tostring(world:getName() or "")
        end
        local statusFn = rawget(_G, "getOperatingStatusForTable")
        if type(statusFn) == "function" and worldName ~= "" then
            local statusText = statusFn(worldName, tx, ty, os.time())
            safeConsole(player, "`wOperating status: `o" .. tostring(statusText))
        end
    end

    local found = {}
    for property = AUTO_SCAN_MIN_PROPERTY, AUTO_SCAN_MAX_PROPERTY do
        local value = tile:getTileData(property)
        if isMeaningfulValue(value) then
            found[#found + 1] = { property = property, value = value }
        end
    end

    if #found > 0 then
        safeConsole(player, "`wTileData auto-scan results (`o" .. tostring(#found) .. "`w entries):")
        for i = 1, #found do
            local row = found[i]
            local textValue, valueType = toStringValue(row.value)
            local label = getPropertyLabel(row.property)
            safeConsole(player, "`w[" .. tostring(row.property) .. "] `o" .. label .. " `w(" .. valueType .. "): `o" .. textValue)
        end
        return true
    end

    safeConsole(player, "`wNo non-empty TileData found in range " .. tostring(AUTO_SCAN_MIN_PROPERTY) .. "-" .. tostring(AUTO_SCAN_MAX_PROPERTY) .. ".")
    safeConsole(player, "`wShowing known properties 0-21 for reference:")
    for property = 0, 21 do
        local value = tile:getTileData(property)
        local textValue, valueType = toStringValue(value)
        local label = getPropertyLabel(property)
        safeConsole(player, "`w[" .. tostring(property) .. "] `o" .. label .. " `w(" .. valueType .. "): `o" .. textValue)
    end

    return true
end

return TileDebug
