-- MODULE
-- operating_table.lua — Operating Table: visual states, surgery, prizes

local M = {}

local DB = _G.DB

local function getWorldName(world)  return world:getName() end
local function loadHospital(wn)     return _G.loadHospital and _G.loadHospital(wn) or nil end

local OPERATING_TABLE_ID  = 25030   -- empty bed state
local SURGBOT_ITEM_ID     = 25026   -- surgbot idle — wrench opens confirm panel
local INSURGERY_ITEM_ID   = 25028   -- in-surgery animation — active during minigame
local ROLE_DEV            = 51
local CACHE_REBUILD_SEC   = 300     -- full tile scan interval (5 min) — stale-insurgery cleanup only

-- =======================================================
-- DURATION & CAPACITY  (exported — used by hospital.lua)
-- =======================================================

function M.getOperatingTableCapacityByLevel(level)
    local required  = _G.REQUIRED_OPERATING_TABLES or {}
    local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
    local base      = tonumber(required[safeLevel]) or 0
    return math.max(1, base + 1)
end

function M.getOperatingPatientDurationByLevel(level)
    local minSec    = tonumber(_G.OPERATING_TABLE_DURATION_MIN_SEC) or ((24 * 60 + 5) * 60)
    local maxSec    = tonumber(_G.OPERATING_TABLE_DURATION_MAX_SEC) or ((28 * 60 + 10) * 60)
    local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
    local bonus     = math.floor(((safeLevel - 1) * 5) / 2) * 60
    return math.max(minSec, math.min(maxSec, minSec + bonus))
end

function M.getOperatingRowKey(x, y)
    return tostring(math.floor(tonumber(x) or 0)) .. ":" .. tostring(math.floor(tonumber(y) or 0))
end

-- =======================================================
-- STATE DB
-- ot_state.json  → { [worldName] = { [tileKey] = { readyAt, inSurgery, surgeryPlayer } } }
-- ot_prizes.json → { [worldName] = { {itemId, amount, chance}, ... } }
--
-- Pattern: always loadAllStates once, modify, saveAllStates once → single DB read per operation
-- =======================================================

local function loadAllStates()  return DB.loadFeature("ot_state") or {} end
local function saveAllStates(d) DB.saveFeature("ot_state", d) end

local function getTileRow(state, x, y)
    local key = M.getOperatingRowKey(x, y)
    if not state[key] then
        state[key] = { readyAt = 0, inSurgery = false, surgeryPlayer = "" }
    end
    local row = state[key]
    row.readyAt       = tonumber(row.readyAt) or 0
    row.inSurgery     = (row.inSurgery == true or row.inSurgery == 1)
    row.surgeryPlayer = tostring(row.surgeryPlayer or "")
    return row, key
end

-- =======================================================
-- HELPERS
-- =======================================================

local function talkBubble(player, text)
    if player and player.onTalkBubble and player.getNetID then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function formatTime(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return h .. "h " .. m .. "m" end
    if m > 0 then return m .. "m " .. s .. "s" end
    return s .. "s"
end

local function getHospitalLevel(worldName)
    local data = loadHospital(worldName)
    return tonumber(data and data.level) or 1
end

local function swapTile(world, tile, itemId)
    world:setTileForeground(tile, itemId)
    world:updateTile(tile)
end

-- Arm the event scheduler for worldName at time t (keeps the earliest scheduled time)
local function armEvent(worldName, t)
    if not _G._OT_nextEvent then _G._OT_nextEvent = {} end
    local cur = _G._OT_nextEvent[worldName]
    if not cur or t < cur then
        _G._OT_nextEvent[worldName] = t
    end
end

-- =======================================================
-- SURGERY CONFIRMATION PANEL
-- =======================================================

-- =======================================================
-- NATIVE SURGERY INTERCEPT
-- =======================================================

-- embed_data from native Sebia dialogs is NOT echoed back to Lua callbacks.
-- Capture tile position at wrench time and store here, keyed by player name.
if not _G.__SURGE_PENDING then _G.__SURGE_PENDING = {} end

-- 1. Surg-E: Sebia sends end_dialog|surge|Cancel|Okay!|
--    Tile position was stored in _G.__SURGE_PENDING at wrench time.
onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "surge" then return false end
    local btn = data["buttonClicked"] or ""
    if btn == "Cancel" then
        _G.__SURGE_PENDING[player:getName()] = nil
        return true
    end

    local pending = _G.__SURGE_PENDING[player:getName()]
    _G.__SURGE_PENDING[player:getName()] = nil

    if not pending then
        player:onConsoleMessage("`4[Surgery] Could not determine tile position.")
        return true
    end

    local x, y     = pending.x, pending.y
    local worldName = getWorldName(world)

    if not _G.SurgerySystem then
        player:onConsoleMessage("`4[Surgery] SurgerySystem not loaded.")
        return true
    end

    if _G.SurgeryEngine then _G.SurgeryEngine.clearSession(worldName, x, y) end
    _G.SurgerySystem.start(world, player, x, y, {
        allowedDiags = _G.SurgeryData.DIAG_KEYS_STANDARD,
    })
    return true
end)

-- 2. Player-on-player surgery: capture target UID by intercepting the manoProfile dialog
--    BEFORE it reaches the client via onPlayerVariantCallback.
--    embed_data|netID is in the dialog content — parse it here and store for surgery button use.
if not _G.__SURGERY_TARGET then _G.__SURGERY_TARGET = {} end

onPlayerVariantCallback(function(player, variant, delay, netID)
    if variant[1] ~= "OnDialogRequest" then return false end
    local content = tostring(variant[2] or "")
    if not content:find("manoProfile", 1, true) then return false end
    local targetNetID = tonumber(content:match("embed_data|netID|(%d+)"))
    if targetNetID then
        if not _G.__SURGERY_TARGET then _G.__SURGERY_TARGET = {} end
        for _, p in ipairs(getAllPlayers()) do
            if p:getNetID() == targetNetID then
                _G.__SURGERY_TARGET[player:getName()] = p:getUserID()
                break
            end
        end
    end
    return false  -- let dialog through to client unchanged
end)

onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "manoProfile" then return false end
    if (data["buttonClicked"] or "") ~= "surgery" then return false end

    if not _G.SurgerySystem then
        player:onConsoleMessage("`4[Surgery] SurgerySystem not loaded.")
        return true
    end

    local worldName = getWorldName(world)
    local targetUID = _G.__SURGERY_TARGET and _G.__SURGERY_TARGET[player:getName()] or nil
    if _G.__SURGERY_TARGET then _G.__SURGERY_TARGET[player:getName()] = nil end

    local vx = -(player:getUserID())
    local vy = -2

    if _G.SurgerySystem.hasSession(worldName, vx, vy) then
        talkBubble(player, "`4You already have a surgery in progress.")
        return true
    end

    if _G.SurgeryEngine then _G.SurgeryEngine.clearSession(worldName, vx, vy) end
    _G.SurgerySystem.start(world, player, vx, vy, {
        allowedDiags = _G.SurgeryData.DIAG_KEYS_STANDARD,
        targetUID    = targetUID,
    })
    return true
end)

-- 3. Block native surgery panel (dialog_name = "surgery") from processing natively.
onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "surgery" then return false end
    return true
end)

-- =======================================================
-- CUSTOM SURGBOT CONFIRM PANEL
-- =======================================================

local function showSurgbotConfirmPanel(player, tileX, tileY)
    local uid   = player:getUserID()
    local skill = tonumber((DB.getPlayer("surgeon_skill", uid) or {}).skill) or 0
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|`9Surg-E Patient|left|" .. SURGBOT_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oSurgeon Skill: " .. skill .. "|\n"
    d = d .. "add_textbox|`oAre you sure you want to perform surgery on this robot? Whether you succeed or fail, the robot will be destroyed in the process.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_custom_button|btn_cancel|textLabel:Cancel;middle_colour:80543231;border_colour:80543231;|\n"
    d = d .. "add_custom_button|btn_okay|textLabel:Okay!;anchor:btn_cancel;left:1;margin:40,0;|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|ot_surgery_" .. tileX .. "_" .. tileY .. "|||\n"
    player:onDialogRequest(d, 0)
end

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local tx, ty = dlg:match("^ot_surgery_(-?%d+)_(-?%d+)")
    if not tx then return false end

    if (data["buttonClicked"] or "") ~= "btn_okay" then return true end

    local worldName = getWorldName(world)
    local x, y     = tonumber(tx), tonumber(ty)

    -- Single DB read for the whole operation
    local all   = loadAllStates()
    local state = all[worldName] or {}
    local row, key = getTileRow(state, x, y)

    if row.inSurgery then
        talkBubble(player, "`4Surgery already in progress.")
        return true
    end

    local tile = world:getTile(math.floor(x / 32), math.floor(y / 32))
    if not tile or tonumber(tile:getTileForeground()) ~= SURGBOT_ITEM_ID then
        talkBubble(player, "`4Surg-Bot is no longer here.")
        return true
    end

    if not _G.SurgerySystem then
        player:onConsoleMessage("`4[OT] SurgerySystem not loaded! Upload surgery files.")
        return true
    end

    row.inSurgery     = true
    row.surgeryPlayer = player:getName()
    state[key]        = row
    all[worldName]    = state
    saveAllStates(all)  -- single write

    swapTile(world, tile, INSURGERY_ITEM_ID)

    local function onSurgeryEnd(endWorld, endPlayer, success)
        local readyAt    = os.time() + M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
        local all2       = loadAllStates()
        local state2     = all2[worldName] or {}
        local row2, k2   = getTileRow(state2, x, y)
        row2.inSurgery   = false
        row2.surgeryPlayer = ""
        row2.readyAt     = readyAt
        state2[k2]       = row2
        all2[worldName]  = state2
        saveAllStates(all2)  -- single write
        armEvent(worldName, readyAt)
        local t = endWorld:getTile(math.floor(x / 32), math.floor(y / 32))
        if t then swapTile(endWorld, t, OPERATING_TABLE_ID) end
    end

    -- Clear any stale in-memory session from a previous crash
    if _G.SurgeryEngine then _G.SurgeryEngine.clearSession(worldName, x, y) end

    _G.SurgerySystem.start(world, player, x, y, {
        onEnd        = onSurgeryEnd,
        allowedDiags = _G.SurgeryData.DIAG_KEYS_STANDARD,
    })
    return true
end)

-- =======================================================
-- WRENCH HANDLER
-- =======================================================

onTileWrenchCallback(function(world, player, tile)
    if type(tile) ~= "userdata" then return false end
    local fg = tonumber(tile:getTileForeground()) or 0

    -- Always store tile position for native surge dialog intercept.
    -- Native Surg-E (4296) sends embed_data that we cannot read back from Lua,
    -- so we capture the position here for every wrench and use it if surge dialog arrives.
    if not _G.__SURGE_PENDING then _G.__SURGE_PENDING = {} end
    _G.__SURGE_PENDING[player:getName()] = { x = tile:getPosX(), y = tile:getPosY() }

    if fg == SURGBOT_ITEM_ID then
        local worldName = getWorldName(world)
        local all       = loadAllStates()
        local state     = all[worldName] or {}
        local row       = getTileRow(state, tile:getPosX(), tile:getPosY())
        if row.inSurgery then
            talkBubble(player, "`4Surgery in progress.")
            return true
        end
        showSurgbotConfirmPanel(player, tile:getPosX(), tile:getPosY())
        return true
    end

    if fg == INSURGERY_ITEM_ID then
        local worldName = getWorldName(world)
        local sx, sy    = tile:getPosX(), tile:getPosY()
        local all       = loadAllStates()
        local state     = all[worldName] or {}
        local row       = getTileRow(state, sx, sy)
        if row.inSurgery and row.surgeryPlayer == player:getName() then
            _G.SurgerySystem.reopen(world, player, sx, sy)
        else
            talkBubble(player, "`4Surgery in progress.")
        end
        return true
    end

    return false
end)

-- =======================================================
-- PUNCH HANDLER — block manual toggle on 25026 and 25028
-- =======================================================

onTilePunchCallback(function(world, player, tile)
    if type(tile) ~= "userdata" then return false end
    local fg = tonumber(tile:getTileForeground()) or 0
    if fg ~= SURGBOT_ITEM_ID and fg ~= INSURGERY_ITEM_ID then return false end
    return true
end)

-- =======================================================
-- PLACE HANDLER — block manual placement of 25026 and 25028
-- =======================================================

onTilePlaceCallback(function(world, player, tile, placingID)
    local id = tonumber(placingID) or 0
    if id == SURGBOT_ITEM_ID or id == INSURGERY_ITEM_ID then
        talkBubble(player, "`4You can't place that here.")
        return true
    end
    -- New OT placed → invalidate cache + arm event (readyAt=0 → immediate surgbot spawn)
    if id == OPERATING_TABLE_ID then
        local wn = world:getName()
        if not _G._OT_cacheTime then _G._OT_cacheTime = {} end
        _G._OT_cacheTime[wn] = 0
        armEvent(wn, os.time())
    end
    return false
end)

-- =======================================================
-- WORLD TICK — event-driven state transitions
-- =======================================================

onWorldTick(function(world)
    local worldName = getWorldName(world)
    local now       = os.time()

    if not _G._OT_nextEvent then _G._OT_nextEvent = {} end
    if not _G._OT_posCache  then _G._OT_posCache  = {} end
    if not _G._OT_cacheTime then _G._OT_cacheTime = {} end

    -- Periodic full scan: rebuild position cache + fix stale insurgery (crash recovery only)
    if (_G._OT_cacheTime[worldName] or 0) <= now then
        local positions = {}
        local all       = loadAllStates()
        local state     = all[worldName] or {}
        local changed   = false
        for _, tile in ipairs(world:getTiles()) do
            local fg = tonumber(tile:getTileForeground()) or 0
            if fg == OPERATING_TABLE_ID or fg == SURGBOT_ITEM_ID or fg == INSURGERY_ITEM_ID then
                positions[#positions + 1] = { x = tile:getPosX(), y = tile:getPosY() }
                if fg == INSURGERY_ITEM_ID then
                    local row = getTileRow(state, tile:getPosX(), tile:getPosY())
                    if not row.inSurgery then
                        swapTile(world, tile, OPERATING_TABLE_ID)
                        changed = true
                    end
                end
            end
        end
        _G._OT_posCache[worldName]  = positions
        _G._OT_cacheTime[worldName] = now + CACHE_REBUILD_SEC
        if changed then
            all[worldName] = state
            saveAllStates(all)
        end
    end

    -- Event-driven: skip until a scheduled readyAt arrives
    local nextEv = _G._OT_nextEvent[worldName]
    if not nextEv or now < nextEv then return end
    _G._OT_nextEvent[worldName] = nil

    local positions = _G._OT_posCache[worldName]
    if not positions or #positions == 0 then return end

    local all     = loadAllStates()
    local state   = all[worldName] or {}
    local nextMin = nil

    for _, pos in ipairs(positions) do
        local tile = world:getTile(math.floor(pos.x / 32), math.floor(pos.y / 32))
        if tile then
            local fg = tonumber(tile:getTileForeground()) or 0
            if fg == OPERATING_TABLE_ID then
                local row = getTileRow(state, pos.x, pos.y)
                if not row.inSurgery then
                    if row.readyAt <= now then
                        swapTile(world, tile, SURGBOT_ITEM_ID)
                    elseif not nextMin or row.readyAt < nextMin then
                        nextMin = row.readyAt
                    end
                end
            end
        end
    end

    if nextMin then
        _G._OT_nextEvent[worldName] = nextMin
    end
end)

-- =======================================================
-- COMMANDS
-- =======================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for w in fullCommand:gmatch("%S+") do args[#args + 1] = w end
    if not args[1] then return false end
    local cmd = args[1]:lower()

    if cmd == "operatingtable" then
        if not player:hasRole(ROLE_DEV) then
            player:onConsoleMessage("`4No permission.")
            return true
        end
        local sub = (args[2] or ""):lower()
        if sub ~= "alive" and sub ~= "dead" then
            player:onConsoleMessage("`4Usage: /operatingtable alive|dead")
            return true
        end

        local worldName   = getWorldName(world)
        local now         = os.time()
        local all         = loadAllStates()
        local state       = all[worldName] or {}
        local count       = 0
        local cooldownSec = M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))

        for _, tile in ipairs(world:getTiles()) do
            local fg = tonumber(tile:getTileForeground()) or 0
            if fg == OPERATING_TABLE_ID or fg == SURGBOT_ITEM_ID then
                local x, y     = tile:getPosX(), tile:getPosY()
                local row, key = getTileRow(state, x, y)
                if sub == "alive" then
                    row.readyAt       = 0
                    row.inSurgery     = false
                    row.surgeryPlayer = ""
                    state[key]        = row
                    if fg ~= SURGBOT_ITEM_ID then
                        swapTile(world, tile, SURGBOT_ITEM_ID)
                    end
                else
                    local t           = now + cooldownSec
                    row.readyAt       = t
                    row.inSurgery     = false
                    row.surgeryPlayer = ""
                    state[key]        = row
                    armEvent(worldName, t)  -- schedule surgbot spawn
                    if fg ~= OPERATING_TABLE_ID then
                        swapTile(world, tile, OPERATING_TABLE_ID)
                    end
                end
                count = count + 1
            end
        end

        all[worldName] = state
        saveAllStates(all)  -- single write
        player:onConsoleMessage("`2[OT] " .. sub .. " — `w" .. count .. " `2table(s).")
        return true
    end

    return false
end)

-- =======================================================
-- HOSPITAL.LUA BRIDGE
-- =======================================================

function M.resolveOperatingTableSurgery(world, surgeon, targetPlayer)
    local worldName   = getWorldName(world)
    local now         = os.time()
    local all         = loadAllStates()
    local state       = all[worldName] or {}
    local surgeonName = surgeon:getName()
    local found       = false

    for key, row in pairs(state) do
        if type(row) == "table"
        and (row.inSurgery == true or row.inSurgery == 1)
        and tostring(row.surgeryPlayer or "") == surgeonName then
            local cooldownSec   = M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
            local readyAt       = now + cooldownSec
            row.inSurgery       = false
            row.surgeryPlayer   = ""
            row.readyAt         = readyAt
            state[key]          = row
            armEvent(worldName, readyAt)  -- schedule surgbot spawn
            found = true
            local px, py = key:match("^(-?%d+):(-?%d+)$")
            if px then
                local tile = world:getTile(math.floor(tonumber(px) / 32), math.floor(tonumber(py) / 32))
                if tile then
                    local tfg = tonumber(tile:getTileForeground()) or 0
                    if tfg == SURGBOT_ITEM_ID or tfg == INSURGERY_ITEM_ID then
                        swapTile(world, tile, OPERATING_TABLE_ID)
                    end
                end
            end
        end
    end

    if found then
        all[worldName] = state
        saveAllStates(all)  -- single write
    end
    return found
end

function M.clearOperatingTable(world, worldName, x, y)
    local all   = loadAllStates()
    local state = all[worldName] or {}
    local key   = M.getOperatingRowKey(x, y)
    state[key]  = nil
    all[worldName] = state
    saveAllStates(all)
end

-- =======================================================
-- HOSPITAL.LUA LEGACY STUBS  (hospital.lua calls these — kept for compatibility)
-- =======================================================

function M.processOperatingTablesInWorld(world, now) end
function M.getOperatingStateRow(state, x, y, now) return {} end

-- =======================================================
-- EXPORTS
-- =======================================================

_G.OperatingTable = M
return M
