-- MODULE
-- carnival_shared.lua — Shared constants, helpers, prize system, game registry
-- Loaded first by carnival_loader; all game modules require _G.CarnivalShared.

local M = {}
math.randomseed(os.time())

-- ── World ────────────────────────────────────────────────────────────────────
M.WORLD       = "CARNIVAL_2"
M.WORLD_UPPER = "CARNIVAL_2"

-- ── Shared item / tile constants ─────────────────────────────────────────────
M.TICKET_ID       = 1898
M.CARD_BACK_ID    = 1916
M.WIN_PARTICLE    = 18
M.QUEUE_DELAY     = 3
M.GAME_DURATION   = 60   -- Concentration default timer
M.TILE_FLAG_IS_ON = bit.lshift(1, 6)

-- Concentration card symbols (pairs)
M.SYMBOLS = {742, 744, 746, 748, 1918, 1920, 1922, 1924}

-- ══════════════════════════════════════════════════════════════════════════════
-- SHARED HELPERS
-- ══════════════════════════════════════════════════════════════════════════════

function M.getCarnivalWorld()
    for _, w in ipairs(getActiveWorlds()) do
        if w:getName():upper() == M.WORLD_UPPER then return w end
    end
    return nil
end

function M.getPlayerInWorld(world, uid)
    for _, p in ipairs(world:getPlayers()) do
        if p:getUserID() == uid then return p end
    end
    return nil
end

function M.removeFromQueue(room, uid)
    for i, e in ipairs(room.queue) do
        if e.uid == uid then table.remove(room.queue, i); return end
    end
end

function M.isInQueue(room, uid)
    for _, e in ipairs(room.queue) do
        if e.uid == uid then return true end
    end
    return false
end

function M.bubble(world, player, text)
    local netID = player:getNetID()
    for _, p in ipairs(world:getPlayers()) do
        p:onTalkBubble(netID, text, 1)
    end
end

function M.makeBoard()
    local deck = {}
    for _, sym in ipairs(M.SYMBOLS) do
        deck[#deck+1] = sym
        deck[#deck+1] = sym
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GAME REGISTRY
-- Each game calls M.registerGame after defining its rooms.
-- ══════════════════════════════════════════════════════════════════════════════

M.registry = {}

-- getRoomsFn: function() → array of rooms
-- isMulti: false = room.activeUID, true = room.activePlayers[uid]
-- resetFn: function(world)
function M.registerGame(gameType, getRoomsFn, isMulti, resetFn)
    table.insert(M.registry, {
        type      = gameType,
        getRooms  = getRoomsFn,
        isMulti   = isMulti,
        resetFn   = resetFn,
    })
end

-- Returns (gameType, room) if player is active/in-queue in any registered game.
function M.getPlayerActiveGame(uid)
    for _, entry in ipairs(M.registry) do
        local rooms = entry.getRooms()
        for _, room in ipairs(rooms) do
            if entry.isMulti then
                if room.activePlayers and room.activePlayers[uid] then
                    return entry.type, room
                end
            else
                if uid == room.activeUID then return entry.type, room end
            end
            for _, e in ipairs(room.queue or {}) do
                if e.uid == uid then return entry.type, room end
            end
        end
    end
    return nil, nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PRIZE SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

local PRIZE_KEY = "CARNIVAL_PRIZE_V1"

local MINIGAMES = {
    "Shooting Gallery",
    "Growganoth Gulch",
    "Mirror Maze",
    "Concentration",
    "Brutal Bounce",
    "Death Race 5000",
    "Spiky Survivor",
}

-- Probability: Common 65%, Rare 30%, Epic 5%
local TIERS = {
    {key="common", label="Common", color="`2", pct="65%", count=7, defAmt=1},
    {key="rare",   label="Rare",   color="`6", pct="30%", count=5, defAmt=2},
    {key="epic",   label="Epic",   color="`5", pct="5%",  count=3, defAmt=3},
}

local function makeDefaultPrizes()
    local t = {}
    for _, tier in ipairs(TIERS) do
        t[tier.key] = {}
        for i = 1, tier.count do
            t[tier.key][i] = {itemID = M.TICKET_ID, amount = tier.defAmt}
        end
    end
    return t
end

local _rawPrize = loadDataFromServer(PRIZE_KEY) or {}
local PRIZE_DATA = {}
for _, gName in ipairs(MINIGAMES) do
    PRIZE_DATA[gName] = makeDefaultPrizes()
    local saved = _rawPrize[gName]
    if saved then
        for _, tier in ipairs(TIERS) do
            if saved[tier.key] then
                for i = 1, tier.count do
                    local s = saved[tier.key][i]
                    if s then
                        PRIZE_DATA[gName][tier.key][i] = {
                            itemID = tonumber(s.itemID) or M.TICKET_ID,
                            amount = tonumber(s.amount) or tier.defAmt,
                        }
                    end
                end
            end
        end
    end
end

onAutoSaveRequest(function()
    saveDataToServer(PRIZE_KEY, PRIZE_DATA)
end)

function M.getRandPrize(gameName)
    local prizes = PRIZE_DATA[gameName]
    if not prizes then return {itemID = M.TICKET_ID, amount = 1} end
    local r = math.random(100)
    local tierKey
    if     r <= 65 then tierKey = "common"
    elseif r <= 95 then tierKey = "rare"
    else                tierKey = "epic"
    end
    local tier = prizes[tierKey]
    if not tier or #tier == 0 then return {itemID = M.TICKET_ID, amount = 1} end
    local pick = tier[math.random(#tier)]
    return {itemID = pick.itemID or M.TICKET_ID, amount = pick.amount or 1}
end

-- ── Prize dialogs ─────────────────────────────────────────────────────────────

local function openMainPrizeDialog(player)
    local d =
        "set_default_color|`o\n" ..
        "add_label|big|`wCarnival Prize|left|\n" ..
        "add_textbox|Select a minigame to configure prizes:|\n" ..
        "add_spacer|small|\n"
    for _, gName in ipairs(MINIGAMES) do
        local btnID = "game_" .. gName:gsub("[^%w]", "_")
        d = d .. "add_button|" .. btnID .. "|`o" .. gName .. "|noflags|0|0|\n"
    end
    d = d ..
        "add_spacer|small|\n" ..
        "add_button|btn_close|`7Close|noflags|0|0|\n" ..
        "end_dialog|carnival_prize_main|||"
    player:onDialogRequest(d)
end

local function openEditPrizeDialog(player, gameName, delay)
    local prizes = PRIZE_DATA[gameName] or makeDefaultPrizes()
    local d =
        "set_default_color|`o\n" ..
        "add_label|big|`w" .. gameName .. "|left|\n" ..
        "add_textbox|`7Leave item picker unchanged to keep the current item.|\n" ..
        "embed_data|game|" .. gameName .. "|\n"
    for _, tier in ipairs(TIERS) do
        d = d .. "add_spacer|small|\n"
        d = d .. "add_label|small|" .. tier.color .. tier.label ..
                 " `7(" .. tier.pct .. ") — " .. tier.count .. " prizes|left|\n"
        for i = 1, tier.count do
            local p    = prizes[tier.key][i] or {itemID = M.TICKET_ID, amount = tier.defAmt}
            local item = getItem(p.itemID)
            local name = item and item:getName() or ("ID:" .. p.itemID)
            d = d ..
                "add_item_picker|" .. tier.key .. "_item_" .. i ..
                "|`w" .. name .. "`7:|Select Carnival Prize|\n" ..
                "add_text_input|" .. tier.key .. "_amt_" .. i ..
                "|Amount:|" .. p.amount .. "|6|\n" ..
                "add_spacer|small|\n"
        end
    end
    d = d ..
        "add_spacer|small|\n" ..
        "add_button|btn_save|`2Set Prize|noflags|0|0|\n" ..
        "add_button|btn_back|`oBack|noflags|0|0|\n" ..
        "end_dialog|carnival_prize_edit|||"
    player:onDialogRequest(d, delay or 0)
end

-- ── Prize commands ────────────────────────────────────────────────────────────

onPlayerCommandCallback(function(world, player, fullCmd)
    local args = {}
    for word in fullCmd:gmatch("%S+") do args[#args+1] = word end
    local cmd = args[1] and args[1]:lower()

    if cmd == "carnivalprize" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access denied!")
            return true
        end
        openMainPrizeDialog(player)
        return true
    end

    if cmd == "carnivalreset" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access denied!")
            return true
        end
        if world:getName() ~= M.WORLD then
            player:onConsoleMessage("`4Must be used inside world `w" .. M.WORLD)
            return true
        end
        -- Call all registered game reset functions
        for _, entry in ipairs(M.registry) do
            entry.resetFn(world)
        end
        player:onConsoleMessage("`2All carnival games reset.")
        return true
    end

    return false
end)

-- ── Prize dialog callbacks ────────────────────────────────────────────────────

onPlayerDialogCallback(function(world, player, data)
    local dname = data["dialog_name"]

    if dname == "carnival_prize_main" then
        local btn = data["buttonClicked"] or ""
        if btn == "btn_close" then return true end
        for _, gName in ipairs(MINIGAMES) do
            if btn == "game_" .. gName:gsub("[^%w]", "_") then
                openEditPrizeDialog(player, gName)
                return true
            end
        end
        return true
    end

    if dname == "carnival_prize_edit" then
        local btn   = data["buttonClicked"] or ""
        local gName = data["game"] or ""

        if btn == "btn_back" then
            openMainPrizeDialog(player)
            return true
        end

        if gName == "" then return true end
        if not PRIZE_DATA[gName] then PRIZE_DATA[gName] = makeDefaultPrizes() end
        for _, tier in ipairs(TIERS) do
            for i = 1, tier.count do
                local itemID = tonumber(data[tier.key .. "_item_" .. i])
                local amount = tonumber(data[tier.key .. "_amt_"  .. i])
                if itemID and itemID > 0 then
                    PRIZE_DATA[gName][tier.key][i].itemID = itemID
                end
                if amount and amount > 0 then
                    PRIZE_DATA[gName][tier.key][i].amount = amount
                end
            end
        end
        if btn == "btn_save" then
            saveDataToServer(PRIZE_KEY, PRIZE_DATA)
            player:onConsoleMessage("`2Prizes for `w" .. gName .. "`2 saved!")
        end
        openEditPrizeDialog(player, gName, 300)
        return true
    end

    return false
end)

-- ── Export ────────────────────────────────────────────────────────────────────
_G.CarnivalShared = M
return M
