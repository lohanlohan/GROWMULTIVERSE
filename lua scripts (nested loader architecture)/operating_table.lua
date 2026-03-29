-- MODULE
-- operating_table.lua — Operating Table: visual states, surgery, prizes

local M = {}

local DB = _G.DB

-- Bridges from hospital.lua
local function getWorldName(world)  return world:getName() end
local function loadHospital(wn)     return _G.loadHospital and _G.loadHospital(wn) or nil end

local OPERATING_TABLE_ID  = 25030   -- empty bed state (plain tile, no extra data dependency)
local SURGBOT_ITEM_ID     = 25026   -- surgbot idle — wrench opens confirm panel
local INSURGERY_ITEM_ID   = 25028   -- in-surgery animation — active during minigame
local ROLE_DEV            = 51
local SURGERY_ANIM_SEC    = 300  -- max surgery duration before auto-fail (seconds, ~5 min)
local TICK_INTERVAL       = 5    -- onWorldTick check interval (seconds)

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
-- =======================================================
-- ot_state.json  → { [worldName] = { [tileKey] = { readyAt, inSurgery, surgeryEndAt, surgeryPlayer } } }
-- ot_prizes.json → { [worldName] = { {itemId, amount, chance}, ... } }

local function loadAllStates()  return DB.loadFeature("ot_state")  or {} end
local function loadAllPrizes()  return DB.loadFeature("ot_prizes") or {} end
local function saveAllStates(d) DB.saveFeature("ot_state",  d) end
local function saveAllPrizes(d) DB.saveFeature("ot_prizes", d) end

local function loadWorldState(worldName)
    return loadAllStates()[worldName] or {}
end
local function saveWorldState(worldName, state)
    local all = loadAllStates()
    all[worldName] = state
    saveAllStates(all)
end
local function loadWorldPrizes(worldName)
    return loadAllPrizes()[worldName] or {}
end
local function saveWorldPrizes(worldName, prizes)
    local all = loadAllPrizes()
    all[worldName] = prizes
    saveAllPrizes(all)
end

local function getTileRow(state, x, y)
    local key = M.getOperatingRowKey(x, y)
    if not state[key] then
        state[key] = { readyAt = 0, inSurgery = false, surgeryEndAt = 0, surgeryPlayer = "" }
    end
    local row = state[key]
    row.readyAt       = tonumber(row.readyAt) or 0
    row.inSurgery     = (row.inSurgery == true or row.inSurgery == 1)
    row.surgeryEndAt  = tonumber(row.surgeryEndAt) or 0
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

-- =======================================================
-- PRIZE ROLL
-- =======================================================

local function rollPrizes(prizes)
    local rewards = {}
    for _, p in ipairs(prizes) do
        if math.random(1, 100) <= (tonumber(p.chance) or 0) then
            rewards[#rewards + 1] = {
                itemId = tonumber(p.itemId),
                amount = math.max(1, tonumber(p.amount) or 1)
            }
        end
    end
    return rewards
end

-- =======================================================
-- PRIZE ADMIN PANEL
-- =======================================================

local MAX_PRIZES = 5

local function showPrizePanel(world, player, worldName)
    local prizes = loadWorldPrizes(worldName)
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|`wOperating Table Prizes|left|14662|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oMax " .. MAX_PRIZES .. " prizes. Chance = 1-100 (%).|\n"
    d = d .. "add_spacer|small|\n"

    for i = 1, MAX_PRIZES do
        local p      = prizes[i] or {}
        local itemId = tostring(p.itemId or "")
        local amount = tostring(p.amount or "1")
        local chance = tostring(p.chance or "0")
        d = d .. "add_textbox|`wPrize " .. i .. "|\n"
        d = d .. "add_text_input|p_item_" .. i .. "|Item ID:|" .. itemId .. "|6|\n"
        d = d .. "add_text_input|p_amt_"  .. i .. "|Amount:|"  .. amount .. "|4|\n"
        d = d .. "add_text_input|p_ch_"   .. i .. "|Chance %:|" .. chance .. "|3|\n"
        d = d .. "add_spacer|small|\n"
    end

    d = d .. "add_button|btn_save|`wSave|noflags|0|0|\n"
    d = d .. "add_button|btn_close|`wClose|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|ot_prize_panel|||\n"
    player:onDialogRequest(d, 0)
end

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    if dlg ~= "ot_prize_panel" then return false end
    if (data["buttonClicked"] or "") == "btn_save" then
        local worldName = getWorldName(world)
        local prizes    = {}
        for i = 1, MAX_PRIZES do
            local itemId = tonumber(data["p_item_" .. i])
            local amount = math.max(1, tonumber(data["p_amt_" .. i]) or 1)
            local chance = math.max(0, math.min(100, tonumber(data["p_ch_" .. i]) or 0))
            if itemId and itemId > 0 and chance > 0 then
                prizes[#prizes + 1] = { itemId = itemId, amount = amount, chance = chance }
            end
        end
        saveWorldPrizes(worldName, prizes)
        player:onConsoleMessage("`2[OT] Saved `w" .. #prizes .. " `2prize(s).")
    end
    return true
end)

-- =======================================================
-- SURGEON SKILL (tracked per player in DB)
-- =======================================================

local function getSurgeonSkill(player)
    local uid  = player:getUserID()
    local data = DB.getPlayer("surgeon_skill", uid) or {}
    return tonumber(data.skill) or 0
end

local function addSurgeonSkill(player, amount)
    local uid   = player:getUserID()
    local data  = DB.getPlayer("surgeon_skill", uid) or {}
    data.skill  = (tonumber(data.skill) or 0) + (amount or 1)
    DB.setPlayer("surgeon_skill", uid, data)
    return data.skill
end

-- =======================================================
-- SURGERY CONFIRMATION PANEL  (replicate native Surg-E panel)
-- =======================================================

local function showSurgbotConfirmPanel(player, tileX, tileY)
    local skill = getSurgeonSkill(player)
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|`wSurg-E Patient|left|" .. SURGBOT_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`wSurgeon Skill: `o" .. skill .. "|\n"
    d = d .. "add_textbox|`oAre you sure you want to perform surgery on this robot? Whether you succeed or fail, the robot will be destroyed in the process.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_cancel|`wCancel|noflags|0|0|\n"
    d = d .. "add_button|btn_okay|`wOkay!|noflags|0|0|\n"
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
    local now       = os.time()
    local state     = loadWorldState(worldName)
    local row, key  = getTileRow(state, x, y)

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

    -- Mark surgery started, swap visual to insurgery
    row.inSurgery     = true
    row.surgeryEndAt  = now + SURGERY_ANIM_SEC
    row.surgeryPlayer = player:getName()
    state[key]        = row
    saveWorldState(worldName, state)

    swapTile(world, tile, INSURGERY_ITEM_ID)

    -- onEnd: called by SurgerySystem before result panel is shown
    local function onSurgeryEnd(endWorld, endPlayer, success)
        local state2       = loadWorldState(worldName)
        local row2, k2     = getTileRow(state2, x, y)
        row2.inSurgery     = false
        row2.surgeryEndAt  = 0
        row2.surgeryPlayer = ""
        row2.readyAt       = os.time() + M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
        state2[k2]         = row2
        saveWorldState(worldName, state2)
        -- Signal tick to run immediately on next onWorldTick call (bypasses 5s gate)
        _pendingSwap[worldName] = true
    end

    -- Start minigame via SurgerySystem
    local prizes = loadWorldPrizes(worldName)
    _G.SurgerySystem.start(world, player, x, y, {
        prizePool  = prizes,
        caduceusId = 4298,
        onEnd      = onSurgeryEnd,
    })
    return true
end)

-- =======================================================
-- WRENCH HANDLER
-- 25026 (surgbot)    → surgery confirm panel (all players)
-- 25028 (insurgery)  → re-open minigame for the surgeon
-- 14662 (empty bed)  → no wrench action (use /operatingtableprize)
-- =======================================================

local function isOwnerOrDev(world, player)
    if player:hasRole(ROLE_DEV) then return true end
    if _G.isWorldOwner and _G.isWorldOwner(world, player) then return true end
    return false
end

onTileWrenchCallback(function(world, player, tile)
    if type(tile) ~= "userdata" then return false end
    local fg = tonumber(tile:getTileForeground()) or 0

    if fg == SURGBOT_ITEM_ID then
        local worldName = getWorldName(world)
        local state     = loadWorldState(worldName)
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
        local state     = loadWorldState(worldName)
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
    return true  -- block default toggle behavior
end)

-- =======================================================
-- PLACE HANDLER — block manual placement of 25026 and 25028
-- =======================================================

onTilePlaceCallback(function(world, player, tile, placingID)
    local id = tonumber(placingID) or 0
    if id ~= SURGBOT_ITEM_ID and id ~= INSURGERY_ITEM_ID then return false end
    talkBubble(player, "`4You can't place that here.")
    return true  -- prevent placement
end)

-- =======================================================
-- WORLD TICK — state transitions + tile swaps
-- =======================================================

local _tickGate    = {}
local _pendingSwap = {}  -- [worldName] = true — bypass tick gate on next tick

onWorldTick(function(world)
    local worldName = getWorldName(world)
    local now       = os.time()
    local hasPending = _pendingSwap[worldName]
    if not hasPending and (_tickGate[worldName] or 0) > now then return end
    _tickGate[worldName]    = now + TICK_INTERVAL
    _pendingSwap[worldName] = nil

    local state   = loadWorldState(worldName)
    local changed = false
    local tiles   = world:getTiles()

    for _, tile in ipairs(tiles) do
        local fg  = tonumber(tile:getTileForeground()) or 0
        local x   = tile:getPosX()
        local y   = tile:getPosY()

        if fg == OPERATING_TABLE_ID then
            -- Dead/cooldown state: check if cooldown expired → spawn surgbot
            local row, key = getTileRow(state, x, y)
            if row.readyAt <= now and not row.inSurgery then
                swapTile(world, tile, SURGBOT_ITEM_ID)
            end

        elseif fg == SURGBOT_ITEM_ID or fg == INSURGERY_ITEM_ID then
            local row, key = getTileRow(state, x, y)
            if row.inSurgery then
                -- Check surgery timeout (auto-fail)
                if (tonumber(row.surgeryEndAt) or 0) > 0 and now >= row.surgeryEndAt then
                    local cooldownSec    = M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
                    row.inSurgery        = false
                    row.surgeryEndAt     = 0
                    row.surgeryPlayer    = ""
                    row.readyAt          = now + cooldownSec
                    state[key]           = row
                    changed              = true
                    if _G.SurgeryEngine then
                        _G.SurgeryEngine.clearSession(worldName, x, y)
                    end
                    swapTile(world, tile, OPERATING_TABLE_ID)
                end
            elseif fg == INSURGERY_ITEM_ID then
                swapTile(world, tile, OPERATING_TABLE_ID)
                changed = true
            end
        end
    end

    if changed then saveWorldState(worldName, state) end
end)

-- =======================================================
-- COMMANDS
-- =======================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for w in fullCommand:gmatch("%S+") do args[#args + 1] = w end
    if not args[1] then return false end
    local cmd = args[1]:lower()

    -- /operatingtable alive|dead
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

        local worldName = getWorldName(world)
        local now       = os.time()
        local state     = loadWorldState(worldName)
        local count     = 0
        local tiles     = world:getTiles()

        for _, tile in ipairs(tiles) do
            local fg = tonumber(tile:getTileForeground()) or 0
            if fg == OPERATING_TABLE_ID or fg == SURGBOT_ITEM_ID then
                local x, y     = tile:getPosX(), tile:getPosY()
                local row, key = getTileRow(state, x, y)

                if sub == "alive" then
                    row.readyAt      = 0
                    row.inSurgery    = false
                    row.surgeryEndAt = 0
                    row.surgeryPlayer = ""
                    state[key]       = row
                    if fg ~= SURGBOT_ITEM_ID then
                        swapTile(world, tile, SURGBOT_ITEM_ID)
                    end
                else  -- dead
                    local cooldownSec = M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
                    row.readyAt      = now + cooldownSec
                    row.inSurgery    = false
                    row.surgeryEndAt = 0
                    row.surgeryPlayer = ""
                    state[key]       = row
                    if fg ~= OPERATING_TABLE_ID then
                        swapTile(world, tile, OPERATING_TABLE_ID)
                    end
                end
                count = count + 1
            end
        end

        saveWorldState(worldName, state)
        player:onConsoleMessage("`2[OT] " .. sub .. " — `w" .. count .. " `2table(s).")
        return true
    end

    -- /operatingtableprize
    if cmd == "operatingtableprize" then
        if not player:hasRole(ROLE_DEV) then
            player:onConsoleMessage("`4No permission.")
            return true
        end
        showPrizePanel(world, player, getWorldName(world))
        return true
    end

    return false
end)

-- =======================================================
-- HOSPITAL.LUA BRIDGE FUNCTIONS
-- =======================================================

function M.processOperatingTablesInWorld(world, now) end
function M.getOperatingStateRow(state, x, y, now) return {} end

function M.resolveOperatingTableSurgery(world, surgeon, targetPlayer)
    local worldName   = getWorldName(world)
    local now         = os.time()
    local state       = loadWorldState(worldName)
    local surgeonName = surgeon:getName()
    local found       = false

    for key, row in pairs(state) do
        if type(row) == "table" then
            if (row.inSurgery == true or row.inSurgery == 1)
               and tostring(row.surgeryPlayer or "") == surgeonName then
                local cooldownSec = M.getOperatingPatientDurationByLevel(getHospitalLevel(worldName))
                row.inSurgery     = false
                row.surgeryEndAt  = 0
                row.surgeryPlayer = ""
                row.readyAt       = now + cooldownSec
                state[key]        = row
                found             = true
                -- Swap tile to dead (empty bed)
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
    end

    if found then saveWorldState(worldName, state) end
    return found
end

function M.clearOperatingTable(world, worldName, x, y)
    local state = loadWorldState(worldName)
    local key   = M.getOperatingRowKey(x, y)
    state[key]  = nil
    saveWorldState(worldName, state)
end

-- =======================================================
-- EXPORTS
-- =======================================================

_G.OperatingTable = M
return M
