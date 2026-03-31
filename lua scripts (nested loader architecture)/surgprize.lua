-- MODULE
-- surgprize.lua — /surgprize: manage per-disease surgery prize pools

local M = {}
local DB     = _G.DB
local SD     = _G.SurgeryData
local ROLE   = 51
local DB_KEY = "surg_prize"

-- =======================================================
-- HELPERS
-- =======================================================

local function load() return DB.loadFeature(DB_KEY) or {} end
local function save(t) DB.saveFeature(DB_KEY, t) end

local function getDiagPrizes(data, key)
    if not data[key] then data[key] = { prizes = {} } end
    return data[key].prizes
end

local function diagExists(key)
    return SD.DIAG[key] ~= nil
end

local function usage(player)
    player:onConsoleMessage("`oUsage:")
    player:onConsoleMessage("`o  /surgprize list [diagKey]")
    player:onConsoleMessage("`o  /surgprize add <diagKey> <itemId> <amount> <chance%>")
    player:onConsoleMessage("`o  /surgprize remove <diagKey> <index>")
    player:onConsoleMessage("`o  /surgprize clear <diagKey>")
    player:onConsoleMessage("`oDiag keys: " .. table.concat(SD.DIAG_KEYS, ", "))
end

-- =======================================================
-- COMMAND
-- =======================================================

registerLuaCommand({
    command      = "surgprize",
    roleRequired = ROLE,
    description  = "Manage surgery prize pools per diagnosis.",
})

onPlayerCommandCallback(function(world, player, full)
    local cmd, rest = full:match("^(%S+)%s*(.*)")
    if not cmd or cmd:lower() ~= "surgprize" then return false end
    if not player:hasRole(ROLE) then return false end

    local args = {}
    for w in rest:gmatch("%S+") do args[#args+1] = w end
    local sub = (args[1] or ""):lower()

    -- /surgprize  or  /surgprize list
    if sub == "" or sub == "list" then
        local key = args[2] and args[2]:upper()
        local data = load()
        if key then
            if not diagExists(key) then
                player:onConsoleMessage("`4Unknown diagnosis: " .. key)
                return true
            end
            local prizes = getDiagPrizes(data, key)
            if #prizes == 0 then
                player:onConsoleMessage("`o[" .. key .. "] No prizes set.")
                return true
            end
            player:onConsoleMessage("`w[" .. key .. "] Prizes:")
            for i, p in ipairs(prizes) do
                local item = getItemById(tonumber(p.itemId))
                local name = item and item:getName() or ("ID:" .. tostring(p.itemId))
                player:onConsoleMessage("`o  " .. i .. ". " .. name .. " x" .. p.amount .. " (" .. p.chance .. "%)")
            end
        else
            player:onConsoleMessage("`wSurgery Prize Pools:")
            for _, k in ipairs(SD.DIAG_KEYS) do
                local prizes = (data[k] and data[k].prizes) or {}
                local diagName = (SD.DIAG[k] or {}).name or k
                player:onConsoleMessage("`o  " .. k .. " `w(" .. diagName .. ")`o: " .. #prizes .. " prize(s)")
            end
        end
        return true
    end

    -- /surgprize add <diagKey> <itemId> <amount> <chance>
    if sub == "add" then
        local key     = args[2] and args[2]:upper()
        local itemId  = tonumber(args[3])
        local amount  = tonumber(args[4])
        local chance  = tonumber(args[5])
        if not key or not itemId or not amount or not chance then
            usage(player)
            return true
        end
        if not diagExists(key) then
            player:onConsoleMessage("`4Unknown diagnosis: " .. key)
            return true
        end
        if chance < 1 or chance > 100 then
            player:onConsoleMessage("`4Chance must be 1-100.")
            return true
        end
        local data   = load()
        local prizes = getDiagPrizes(data, key)
        prizes[#prizes+1] = { itemId = itemId, amount = math.max(1, amount), chance = chance }
        save(data)
        local item = getItemById(itemId)
        local name = item and item:getName() or ("ID:" .. itemId)
        player:onConsoleMessage("`2Added to [" .. key .. "]: " .. name .. " x" .. amount .. " at " .. chance .. "% chance.")
        return true
    end

    -- /surgprize remove <diagKey> <index>
    if sub == "remove" then
        local key = args[2] and args[2]:upper()
        local idx = tonumber(args[3])
        if not key or not idx then usage(player); return true end
        if not diagExists(key) then
            player:onConsoleMessage("`4Unknown diagnosis: " .. key)
            return true
        end
        local data   = load()
        local prizes = getDiagPrizes(data, key)
        if idx < 1 or idx > #prizes then
            player:onConsoleMessage("`4Index out of range (1-" .. #prizes .. ").")
            return true
        end
        table.remove(prizes, idx)
        save(data)
        player:onConsoleMessage("`2Removed prize #" .. idx .. " from [" .. key .. "].")
        return true
    end

    -- /surgprize clear <diagKey>
    if sub == "clear" then
        local key = args[2] and args[2]:upper()
        if not key then usage(player); return true end
        if not diagExists(key) then
            player:onConsoleMessage("`4Unknown diagnosis: " .. key)
            return true
        end
        local data = load()
        data[key]  = { prizes = {} }
        save(data)
        player:onConsoleMessage("`2Cleared all prizes for [" .. key .. "].")
        return true
    end

    usage(player)
    return true
end)

return M
