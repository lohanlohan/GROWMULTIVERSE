-- carnival.lua
-- Carnival Minigames — World: CARNIVAL_2
-- Includes: Prize Manager + Concentration Room 1 & 2
--
-- Commands (role 51):
--   /carnivalprize          — manage prizes for all minigames
--   /carnivalreset [1|2]    — emergency reset (all rooms or specific)
--
-- Prize Storage: "CARNIVAL_PRIZE_V1"

math.randomseed(os.time())

local WORLD       = "CARNIVAL_2"
local WORLD_UPPER = "CARNIVAL_2"

-- Shared constants
local TICKET_ID    = 1898
local CARD_BACK_ID = 1916
local GAME_DURATION = 60
local QUEUE_DELAY   = 3
local FLIP_DELAY    = 2
local WIN_PARTICLE  = 18
local SYMBOLS = {742, 744, 746, 748, 1918, 1920, 1922, 1924}

-- ══════════════════════════════════════════════════════════════
-- PRIZE SYSTEM
-- ══════════════════════════════════════════════════════════════

local PRIZE_KEY = "CARNIVAL_PRIZE_V1"

local MINIGAMES = {
    "Shooting Gallery",
    "Growganoth Gulch",
    "Mirror Maze",
    "Concentration",
    "Brutal Bounce",
    "Hall of Mirrors",
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
            t[tier.key][i] = {itemID = TICKET_ID, amount = tier.defAmt}
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
                            itemID = tonumber(s.itemID) or TICKET_ID,
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

local function getRandPrize(gameName)
    local prizes = PRIZE_DATA[gameName]
    if not prizes then return {itemID = TICKET_ID, amount = 1} end

    local r = math.random(100)
    local tierKey
    if     r <= 65 then tierKey = "common"
    elseif r <= 95 then tierKey = "rare"
    else                tierKey = "epic"
    end

    local tier = prizes[tierKey]
    if not tier or #tier == 0 then return {itemID = TICKET_ID, amount = 1} end
    local pick = tier[math.random(#tier)]
    return {itemID = pick.itemID or TICKET_ID, amount = pick.amount or 1}
end

-- ══════════════════════════════════════════════════════════════
-- ROOM CONFIG & STATE
-- ══════════════════════════════════════════════════════════════
-- Both rooms run the same Concentration logic.
-- Each room has its own config, card lookup, and runtime state.
-- Rooms share the same prize table ("Concentration").

local ROOMS = {
    -- Room 1
    {
        name         = "Concentration",
        doorEntrance = "CONCENTRATION01",  -- Carnival Tent entrance
        doorIngame   = "CONCENTRATION02",  -- Carnival Landing posIngame
        doorExit     = "CONCENTRATION03",  -- Carnival Landing posExit
        cardPos = {
            {x=39,y=29},{x=41,y=29},{x=43,y=29},{x=45,y=29},
            {x=39,y=31},{x=41,y=31},{x=43,y=31},{x=45,y=31},
            {x=39,y=33},{x=41,y=33},{x=43,y=33},{x=45,y=33},
            {x=39,y=35},{x=41,y=35},{x=43,y=35},{x=45,y=35},
        },
        posTent   = {x=48, y=33},
        posWait   = {x=48, y=30},
        posIngame = {x=42, y=36},
        posExit   = {x=49, y=33},
        gameArea  = {xMin=(37-1)*32, xMax=(46-1)*32, yMin=(27-1)*32, yMax=(37-1)*32},
    },
    -- Room 2
    {
        name         = "Concentration",
        doorEntrance = "CONCENTRATION04",
        doorIngame   = "CONCENTRATION05",
        doorExit     = "CONCENTRATION06",
        cardPos = {
            {x=64,y=29},{x=66,y=29},{x=68,y=29},{x=70,y=29},
            {x=64,y=31},{x=66,y=31},{x=68,y=31},{x=70,y=31},
            {x=64,y=33},{x=66,y=33},{x=68,y=33},{x=70,y=33},
            {x=64,y=35},{x=66,y=35},{x=68,y=35},{x=70,y=35},
        },
        posTent   = {x=61, y=36},
        posWait   = {x=61, y=33},
        posIngame = {x=67, y=36},
        posExit   = {x=60, y=36},
        gameArea  = {xMin=(63-1)*32, xMax=(71-1)*32, yMin=(28-1)*32, yMax=(36-1)*32},
    },
}

-- Build card lookup table + initialize runtime state for each room
for _, room in ipairs(ROOMS) do
    room.cardLookup    = {}
    for i, pos in ipairs(room.cardPos) do
        room.cardLookup[pos.x .. "_" .. pos.y] = i
    end
    room.queue          = {}
    room.activeUID      = nil
    room.gameBoard      = {}
    room.matched        = {}
    room.matchCount     = 0
    room.firstPick      = nil
    room.resolving      = nil
    room.exitUID        = nil
    room.gameSession    = 0
    room.flipTimer      = nil
    room.gameTimer      = nil
    room.nextTickAt     = nil
    room.exitTickAt     = nil
    room.reanchorUID    = nil
    room.reanchorTickAt = nil
    room.reanchorPos    = nil
    room.secTeleport    = nil
    room.secTickAt      = nil
end

-- ══════════════════════════════════════════════════════════════
-- SHOOTING GALLERY — ROOM CONFIG & STATE
-- ══════════════════════════════════════════════════════════════

local BULLSEYE_ID     = 1908
local TILE_FLAG_IS_ON = bit.lshift(1, 6)
local SG_DURATION     = 30
local SG_ROUND_TIME   = 3   -- seconds before targets reset
local SG_ACTIVE_COUNT = 3   -- targets lit at once
local SG_WIN_SCORE    = 30

local SG_ROOMS = {
    -- Room 1 (left of entrance)
    {
        name         = "Shooting Gallery",
        doorEntrance = "SHOOTING01",
        doorIngame   = "SHOOTING02",
        doorExit     = "SHOOTING03",
        targetPos    = {
            {x=38,y=53},{x=39,y=51},{x=40,y=53},{x=41,y=51},{x=42,y=53},
            {x=43,y=51},{x=44,y=53},{x=42,y=49},{x=40,y=49},{x=41,y=47},
        },
        posWait   = {x=36, y=54},
        posIngame = {x=41, y=54},
        posExit   = {x=35, y=52},
        gameArea  = {xMin=(38-1)*32, xMax=(44-1)*32, yMin=(46-1)*32, yMax=(54-1)*32},
    },
    -- Room 2 (right side)
    {
        name         = "Shooting Gallery",
        doorEntrance = "SHOOTING04",
        doorIngame   = "SHOOTING05",
        doorExit     = "SHOOTING06",
        targetPos    = {
            {x=70,y=53},{x=72,y=53},{x=74,y=53},{x=76,y=53},
            {x=71,y=51},{x=73,y=51},{x=75,y=51},
            {x=72,y=49},{x=74,y=49},
            {x=73,y=47},
        },
        posWait   = {x=78, y=54},
        posIngame = {x=73, y=54},
        posExit   = {x=79, y=52},
        gameArea  = {xMin=(70-1)*32, xMax=(76-1)*32, yMin=(46-1)*32, yMax=(54-1)*32},
    },
}

for _, room in ipairs(SG_ROOMS) do
    room.queue           = {}
    room.activeUID       = nil
    room.exitUID         = nil
    room.gameSession     = 0
    room.score           = 0
    room.litSet          = {}
    room.punchedCount    = 0
    room.gameTimer       = nil
    room.roundTimer      = nil
    room.nextTickAt      = nil
    room.exitTickAt      = nil
    room.secTeleport     = nil
    room.secTickAt       = nil
    room.reanchorUID     = nil
    room.reanchorTickAt  = nil
    room.reanchorPos     = nil
    room.gameStartTime   = 0
    room.targetLookup    = {}
    for i, pos in ipairs(room.targetPos) do
        room.targetLookup[pos.x .. "_" .. pos.y] = i
    end
end

local snapTick = 0  -- unified snap counter for all rooms

-- ══════════════════════════════════════════════════════════════
-- SHARED HELPERS
-- ══════════════════════════════════════════════════════════════

local function getCarnivalWorld()
    for _, w in ipairs(getActiveWorlds()) do
        if w:getName():upper() == WORLD_UPPER then return w end
    end
    return nil
end

local function getPlayerInWorld(world, uid)
    for _, p in ipairs(world:getPlayers()) do
        if p:getUserID() == uid then return p end
    end
    return nil
end

local function removeFromQueue(room, uid)
    for i, e in ipairs(room.queue) do
        if e.uid == uid then table.remove(room.queue, i); return end
    end
end

local function isInQueue(room, uid)
    for _, e in ipairs(room.queue) do
        if e.uid == uid then return true end
    end
    return false
end

local DR_ROOMS         = {}   -- forward declaration (populated after SG section)
local drClearTimers    = nil  -- forward declaration (defined in DR section)
local drClearObstacles = nil  -- forward declaration (defined in DR section)

local MM_ROOMS      = {}   -- forward declaration (populated in MM section)
local mmClearTimers = nil  -- forward declaration (defined in MM section)
local mmClearBlocks = nil  -- forward declaration (defined in MM section)

-- Returns gameType ("concentration"/"sg"/"dr") and room if player is active in any game
local function getPlayerActiveGame(uid)
    for _, room in ipairs(ROOMS) do
        if uid == room.activeUID then return "concentration", room end
        for _, e in ipairs(room.queue or {}) do
            if e.uid == uid then return "concentration", room end
        end
    end
    for _, room in ipairs(SG_ROOMS) do
        if uid == room.activeUID then return "sg", room end
        for _, e in ipairs(room.queue or {}) do
            if e.uid == uid then return "sg", room end
        end
    end
    for _, room in ipairs(DR_ROOMS) do
        if room.activePlayers and room.activePlayers[uid] then return "dr", room end
        for _, e in ipairs(room.queue or {}) do
            if e.uid == uid then return "dr", room end
        end
    end
    for _, room in ipairs(MM_ROOMS) do
        if uid == room.activeUID then return "mm", room end
        for _, e in ipairs(room.queue or {}) do
            if e.uid == uid then return "mm", room end
        end
    end
    return nil, nil
end

local function bubble(world, player, text)
    local netID = player:getNetID()
    for _, p in ipairs(world:getPlayers()) do
        p:onTalkBubble(netID, text, 1)
    end
end

local function makeBoard()
    local deck = {}
    for _, sym in ipairs(SYMBOLS) do
        deck[#deck+1] = sym
        deck[#deck+1] = sym
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- ══════════════════════════════════════════════════════════════
-- CARD OPERATIONS
-- ══════════════════════════════════════════════════════════════

local function setCard(world, room, idx, itemID)
    local pos = room.cardPos[idx]
    if not pos then return end
    local tile = world:getTile(pos.x - 1, pos.y - 1)
    if tile then
        world:setTileForeground(tile, itemID)
        world:updateTile(tile)
    end
end

local function resetAllCards(world, room)
    for i = 1, #room.cardPos do
        setCard(world, room, i, CARD_BACK_ID)
    end
end

-- ══════════════════════════════════════════════════════════════
-- GAME STATE HELPERS
-- ══════════════════════════════════════════════════════════════

local function resetBoard(room)
    room.matched    = {}
    room.matchCount = 0
    room.firstPick  = nil
    room.resolving  = nil
end

local function clearGameTimers(room)
    if room.flipTimer then timer.clear(room.flipTimer); room.flipTimer = nil end
    if room.gameTimer then timer.clear(room.gameTimer); room.gameTimer = nil end
    room.nextTickAt = nil
    room.exitTickAt = nil
end

local function scheduleNextPlayer(room)
    if room.nextTickAt then return end
    if room.exitTickAt then return end
    room.nextTickAt = os.time() + QUEUE_DELAY
end

-- ══════════════════════════════════════════════════════════════
-- GAME FLOW
-- ══════════════════════════════════════════════════════════════

local function handleEnd(world, player, won, room)
    clearGameTimers(room)
    local uid = room.activeUID
    room.activeUID = nil
    room.firstPick = nil
    room.resolving = nil

    if won and player then
        local p = getRandPrize(room.name)
        local item = getItem(p.itemID)
        local itemName = item and item:getName() or ("Item#" .. p.itemID)
        bubble(world, player, "`2Concentration Clear!")
        player:onConsoleMessage("`2Congratulations! You matched all 8 pairs!")
        player:onConsoleMessage("`2Prize: `w" .. p.amount .. "x " .. itemName)
        player:changeItem(p.itemID, p.amount, 0)
        local tx = math.floor(player:getPosX() / 32)
        local ty = math.floor(player:getPosY() / 32)
        player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())
    elseif player then
        bubble(world, player, "`4Time's Up!")
        player:onConsoleMessage("`4Time's up! Better luck next time.")
    end

    if player then
        player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
    end

    room.exitUID    = uid
    room.exitTickAt = os.time() + QUEUE_DELAY
end

local function startNextPlayer(world, room)
    if room.activeUID or #room.queue == 0 then return end

    local entry, player
    repeat
        if #room.queue == 0 then break end
        entry  = table.remove(room.queue, 1)
        player = getPlayerInWorld(world, entry.uid)
    until player or #room.queue == 0

    if not player then return end

    local uid = entry.uid
    room.activeUID   = uid
    room.gameBoard   = makeBoard()
    room.gameSession = room.gameSession + 1
    local session    = room.gameSession

    resetBoard(room)
    local in_px = (room.posIngame.x - 1) * 32
    local in_py = (room.posIngame.y - 1) * 32
    world:setPlayerPosition(player, in_px, in_py)
    room.secTeleport = {uid = uid, x = in_px, y = in_py}
    room.secTickAt   = os.time() + 1

    player:onConsoleMessage("`2Concentration! Match `w8 pairs`2 of cards within `w" .. GAME_DURATION .. " seconds`2!")
    player:sendVariant({"OnCountdownStart", GAME_DURATION, -1}, 0, player:getNetID())

    for _, warnSec in ipairs({60, 30, 10}) do
        if GAME_DURATION > warnSec then
            local delay = GAME_DURATION - warnSec
            timer.setTimeout(delay, function()
                if room.gameSession ~= session then return end
                if room.activeUID   ~= uid     then return end
                local w = getCarnivalWorld()
                local p = w and getPlayerInWorld(w, uid)
                if p then p:onConsoleMessage("`6" .. warnSec .. " seconds remaining!") end
            end)
        end
    end

    clearGameTimers(room)
    room.gameTimer = timer.setTimeout(GAME_DURATION, function()
        room.gameTimer = nil
        if room.activeUID ~= uid then return end
        local w = getCarnivalWorld()
        local p = w and getPlayerInWorld(w, uid)
        handleEnd(w, p, false, room)
    end)

    for i, e in ipairs(room.queue) do
        local qp = getPlayerInWorld(world, e.uid)
        if qp then
            qp:onConsoleMessage("`7" .. entry.name .. " is now playing. You are `w#" .. i .. "`7 in queue.")
        end
    end
end

-- Per-room tick logic (called each world tick for each room)
local function tickRoom(world, room, now)
    -- Start next player after queue delay
    if room.nextTickAt and now >= room.nextTickAt and not room.activeUID and #room.queue > 0 then
        room.nextTickAt = nil
        startNextPlayer(world, room)
    end

    -- Exit teleport: cards reset + player teleported out
    if room.exitTickAt and now >= room.exitTickAt then
        room.exitTickAt = nil
        local uid_ex = room.exitUID
        local exP    = uid_ex and getPlayerInWorld(world, uid_ex)
        local ex_px  = (room.posExit.x - 1) * 32
        local ex_py  = (room.posExit.y - 1) * 32
        resetAllCards(world, room)
        if exP then
            world:setPlayerPosition(exP, ex_px, ex_py)
            room.secTeleport = {uid = uid_ex, x = ex_px, y = ex_py}
            room.secTickAt   = now + 1
        end
        room.exitUID = nil
        scheduleNextPlayer(room)
    end

    -- Re-anchor (snap player to specific position)
    if room.reanchorTickAt and now >= room.reanchorTickAt then
        local ruid = room.reanchorUID
        local rpos = room.reanchorPos
        room.reanchorUID    = nil
        room.reanchorTickAt = nil
        room.reanchorPos    = nil
        local rp = ruid and getPlayerInWorld(world, ruid)
        if rp then
            local re_px = (rpos.x - 1) * 32
            local re_py = (rpos.y - 1) * 32
            world:setPlayerPosition(rp, re_px, re_py)
            room.secTeleport = {uid = ruid, x = re_px, y = re_py}
            room.secTickAt   = now + 1
        end
    end

    -- Secondary teleport: confirmation 1 second after primary
    if room.secTickAt and now >= room.secTickAt then
        room.secTickAt   = nil
        local st = room.secTeleport
        room.secTeleport = nil
        if st then
            local sp = getPlayerInWorld(world, st.uid)
            if sp then world:setPlayerPosition(sp, st.x, st.y) end
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- SHOOTING GALLERY — HELPERS & GAME FLOW
-- ══════════════════════════════════════════════════════════════

-- Toggle a bullseye tile on or off
local function sgSetTarget(world, room, idx, on)
    local pos  = room.targetPos[idx]
    local tile = world:getTile(pos.x - 1, pos.y - 1)
    if not tile then return end
    local flags = tile:getFlags()
    if on then
        flags = bit.bor(flags, TILE_FLAG_IS_ON)
    else
        flags = bit.band(flags, bit.bnot(TILE_FLAG_IS_ON))
    end
    tile:setFlags(flags)
    world:updateTile(tile)
end

-- Turn off all currently lit targets
local function sgResetTargets(world, room)
    if world then
        for idx in pairs(room.litSet) do
            sgSetTarget(world, room, idx, false)
        end
    end
    room.litSet       = {}
    room.punchedCount = 0
end

local function sgClearTimers(room)
    if room.gameTimer  then timer.clear(room.gameTimer);  room.gameTimer  = nil end
    if room.roundTimer then timer.clear(room.roundTimer); room.roundTimer = nil end
    room.nextTickAt = nil
    room.exitTickAt = nil
end

local function sgScheduleNext(room)
    if room.nextTickAt then return end
    if room.exitTickAt then return end
    room.nextTickAt = os.time() + QUEUE_DELAY
end

-- Pick SG_ACTIVE_COUNT random targets and light them; start 3s round timer
local function sgStartRound(world, room)
    for idx in pairs(room.litSet) do sgSetTarget(world, room, idx, false) end
    room.litSet       = {}
    room.punchedCount = 0
    if room.roundTimer then timer.clear(room.roundTimer); room.roundTimer = nil end

    -- Fisher-Yates shuffle → pick first SG_ACTIVE_COUNT
    local pool = {}
    for i = 1, #room.targetPos do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for i = 1, SG_ACTIVE_COUNT do
        local idx = pool[i]
        room.litSet[idx] = true
        sgSetTarget(world, room, idx, true)
    end

    local uid     = room.activeUID
    local session = room.gameSession
    room.roundTimer = timer.setTimeout(SG_ROUND_TIME, function()
        room.roundTimer = nil
        if room.activeUID ~= uid or room.gameSession ~= session then return end
        local w = getCarnivalWorld()
        if not w then return end
        sgStartRound(w, room)
    end)
end

local function sgHandleEnd(world, player, won, room)
    sgClearTimers(room)
    local uid      = room.activeUID
    room.activeUID = nil
    sgResetTargets(world, room)

    if won and player then
        local p        = getRandPrize(room.name)
        local item     = getItem(p.itemID)
        local itemName = item and item:getName() or ("Item#" .. p.itemID)
        bubble(world, player, "`6You scored " .. room.score .. " points! `0You win a `2" .. itemName .. "`0!")
        player:changeItem(p.itemID, p.amount, 0)
        local tx = math.floor(player:getPosX() / 32)
        local ty = math.floor(player:getPosY() / 32)
        player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())
    elseif player then
        bubble(world, player, "`4Time's Up! Final score: " .. room.score)
        player:onConsoleMessage("`4Time's up! Final score: `w" .. room.score)
    end

    if player then
        player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
    end

    room.score      = 0
    room.exitUID    = uid
    room.exitTickAt = os.time() + QUEUE_DELAY
end

local function sgStartNextPlayer(world, room)
    if room.activeUID or #room.queue == 0 then return end

    local entry, player
    repeat
        if #room.queue == 0 then break end
        entry  = table.remove(room.queue, 1)
        player = getPlayerInWorld(world, entry.uid)
    until player or #room.queue == 0

    if not player then return end

    local uid        = entry.uid
    room.activeUID   = uid
    room.score       = 0
    room.gameSession = room.gameSession + 1
    local session    = room.gameSession

    local in_px = (room.posIngame.x - 1) * 32
    local in_py = (room.posIngame.y - 1) * 32
    world:setPlayerPosition(player, in_px, in_py)
    room.secTeleport = {uid = uid, x = in_px, y = in_py}
    room.secTickAt     = os.time() + 1
    room.gameStartTime = os.time()

    player:sendVariant({"OnCountdownStart", SG_DURATION, -1}, 0, player:getNetID())
    player:onConsoleMessage("`wGO! `7Hit all `w3`7 lit targets within `w3s`7 each round.")

    room.gameTimer = timer.setTimeout(SG_DURATION, function()
        room.gameTimer = nil
        if room.activeUID ~= uid or room.gameSession ~= session then return end
        local w   = getCarnivalWorld()
        local p   = w and getPlayerInWorld(w, uid)
        local won = room.score >= SG_WIN_SCORE
        sgHandleEnd(w, p, won, room)
    end)

    -- Start first round after 1s (let teleport settle)
    timer.setTimeout(1, function()
        if room.activeUID ~= uid or room.gameSession ~= session then return end
        local w = getCarnivalWorld()
        if not w then return end
        sgStartRound(w, room)
    end)
end

local function sgTickRoom(world, room, now)
    -- Re-anchor (snap player to position after door callback)
    if room.reanchorTickAt and now >= room.reanchorTickAt then
        local ruid = room.reanchorUID
        local rpos = room.reanchorPos
        room.reanchorUID    = nil
        room.reanchorTickAt = nil
        room.reanchorPos    = nil
        local rp = ruid and getPlayerInWorld(world, ruid)
        if rp then
            local re_px = (rpos.x - 1) * 32
            local re_py = (rpos.y - 1) * 32
            world:setPlayerPosition(rp, re_px, re_py)
            room.secTeleport = {uid = ruid, x = re_px, y = re_py}
            room.secTickAt   = now + 1
        end
    end

    if room.secTickAt and now >= room.secTickAt then
        room.secTickAt   = nil
        local st         = room.secTeleport
        room.secTeleport = nil
        if st then
            local sp = getPlayerInWorld(world, st.uid)
            if sp then world:setPlayerPosition(sp, st.x, st.y) end
        end
    end

    if room.exitTickAt and now >= room.exitTickAt then
        room.exitTickAt = nil
        local uid_ex    = room.exitUID
        local exP       = uid_ex and getPlayerInWorld(world, uid_ex)
        local ex_px     = (room.posExit.x - 1) * 32
        local ex_py     = (room.posExit.y - 1) * 32
        sgResetTargets(world, room)
        if exP then
            world:setPlayerPosition(exP, ex_px, ex_py)
            room.secTeleport = {uid = uid_ex, x = ex_px, y = ex_py}
            room.secTickAt   = now + 1
        end
        room.exitUID = nil
        sgScheduleNext(room)
    end

    if room.nextTickAt and now >= room.nextTickAt then
        room.nextTickAt = nil
        sgStartNextPlayer(world, room)
    end
end

-- ══════════════════════════════════════════════════════════════
-- WORLD TICK
-- ══════════════════════════════════════════════════════════════

onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(ROOMS) do
        tickRoom(world, room, now)
    end

    -- Snap non-active players out of any game area (throttled 1x/second)
    snapTick = snapTick + 1
    if snapTick >= 10 then
        snapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px  = p:getPosX()
            local py  = p:getPosY()
            local uid = p:getUserID()
            for _, room in ipairs(ROOMS) do
                if uid ~= room.activeUID then
                    local ga = room.gameArea
                    if px >= ga.xMin and px <= ga.xMax and py >= ga.yMin and py <= ga.yMax then
                        world:setPlayerPosition(p, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                        p:onConsoleMessage("`4Game area is restricted to the active player only!")
                        break
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- DOOR ENTRY
-- ══════════════════════════════════════════════════════════════

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(ROOMS) do
        -- Ingame landing: prevent door from sending active player away
        if doorUp == room.doorIngame then
            if uid == room.activeUID then
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
            end
            return false
        end

        -- Exit landing: pass through
        if doorUp == room.doorExit then
            return false
        end

        -- Entrance: ticket check + add to queue
        if doorUp == room.doorEntrance then
            if uid == room.activeUID then
                player:onConsoleMessage("`4You are currently playing! Returning you to the game.")
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
                return false
            end

            -- Guard: block if already active in another minigame
            local gType, gRoom = getPlayerActiveGame(uid)
            if gType then
                player:onConsoleMessage("`4You're already playing another minigame!")
                gRoom.reanchorUID    = uid
                gRoom.reanchorTickAt = os.time() + 1
                gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                return false
            end

            if isInQueue(room, uid) then
                player:onConsoleMessage("`7You are already in queue.")
                return false
            end

            if player:getItemAmount(TICKET_ID) < 1 then
                bubble(world, player, "`4No Golden Ticket!")
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Concentration!")
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posTent.x, y = room.posTent.y}
                return false
            end

            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})

            if not room.activeUID and #room.queue == 1 then
                player:onConsoleMessage("`2Get ready! Entering in `w" .. QUEUE_DELAY .. " seconds`2...")
                scheduleNextPlayer(room)
            else
                player:onConsoleMessage("`oYou are `w#" .. #room.queue .. "`o in queue — hang tight!")
            end

            return false
        end
    end

    return false
end)

-- ══════════════════════════════════════════════════════════════
-- TILE PUNCH — card flip mechanic
-- ══════════════════════════════════════════════════════════════

onTilePunchCallback(function(world, avatar, tile)
    if world:getName() ~= WORLD then return false end

    -- Convert pixel coord → display tile coord for lookup
    local px  = math.floor(tile:getPosX() / 32) + 1
    local py  = math.floor(tile:getPosY() / 32) + 1
    local key = px .. "_" .. py

    for _, room in ipairs(ROOMS) do
        local cardIdx = room.cardLookup[key]
        if cardIdx then
            -- Card belongs to this room — always prevent breaking
            if avatar:getUserID() ~= room.activeUID then return true end
            if room.matched[cardIdx] then return true end

            if room.resolving then
                -- Close the two mismatched cards, open this one as firstPick
                local r = room.resolving
                room.resolving = nil
                setCard(world, room, r.idx1, CARD_BACK_ID)
                setCard(world, room, r.idx2, CARD_BACK_ID)
                if not room.matched[cardIdx] then
                    room.firstPick = {idx = cardIdx, sym = room.gameBoard[cardIdx]}
                    setCard(world, room, cardIdx, room.gameBoard[cardIdx])
                end
                return true
            end

            if not room.firstPick then
                -- First card flip
                room.firstPick = {idx = cardIdx, sym = room.gameBoard[cardIdx]}
                setCard(world, room, cardIdx, room.gameBoard[cardIdx])

            elseif room.firstPick.idx ~= cardIdx then
                -- Second card flip
                local sym2 = room.gameBoard[cardIdx]
                setCard(world, room, cardIdx, sym2)

                if room.firstPick.sym == sym2 then
                    -- MATCH
                    room.matched[room.firstPick.idx] = true
                    room.matched[cardIdx]            = true
                    room.matchCount = room.matchCount + 2
                    room.firstPick  = nil
                    if room.matchCount == 16 then
                        handleEnd(world, avatar, true, room)
                    end
                else
                    -- MISMATCH — stay open until next punch
                    room.resolving = {idx1 = room.firstPick.idx, idx2 = cardIdx}
                    room.firstPick = nil
                end
            end

            return true
        end
    end

    return false
end)

-- ══════════════════════════════════════════════════════════════
-- PLAYER LEAVE — cleanup on disconnect or world exit
-- ══════════════════════════════════════════════════════════════

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()

    for _, room in ipairs(ROOMS) do
        if uid == room.activeUID then
            -- Active player disconnected/left mid-game
            clearGameTimers(room)
            room.gameSession = room.gameSession + 1
            room.activeUID   = nil
            room.firstPick   = nil
            room.resolving   = nil
            resetBoard(room)
            resetAllCards(world, room)

            if #room.queue > 0 then
                for _, e in ipairs(room.queue) do
                    local qp = getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`7Previous player left. Next player entering in `w" .. QUEUE_DELAY .. " seconds`7...")
                    end
                end
                scheduleNextPlayer(room)
            end
        else
            -- Not active in this room — clean up queue / exit / reanchor state
            removeFromQueue(room, uid)

            if uid == room.exitUID then
                room.exitUID    = nil
                room.exitTickAt = nil
                resetAllCards(world, room)
                scheduleNextPlayer(room)
            end

            if uid == room.reanchorUID then
                room.reanchorUID    = nil
                room.reanchorTickAt = nil
                room.reanchorPos    = nil
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- PRIZE DIALOG BUILDERS
-- ══════════════════════════════════════════════════════════════

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
            local p    = prizes[tier.key][i] or {itemID = TICKET_ID, amount = tier.defAmt}
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

-- ══════════════════════════════════════════════════════════════
-- COMMANDS (role 51)
-- ══════════════════════════════════════════════════════════════

onPlayerCommandCallback(function(world, player, fullCmd)
    local args = {}
    for word in fullCmd:gmatch("%S+") do args[#args+1] = word end
    local cmd = args[1] and args[1]:lower()

    -- /carnivalprize — open prize manager
    if cmd == "carnivalprize" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access denied!")
            return true
        end
        openMainPrizeDialog(player)
        return true
    end

    -- /carnivalreset [1|2] — emergency state reset
    if cmd == "carnivalreset" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Access denied!")
            return true
        end
        if world:getName() ~= WORLD then
            player:onConsoleMessage("`4Must be used inside world `w" .. WORLD)
            return true
        end

        local roomNum = tonumber(args[2])
        if roomNum and not ROOMS[roomNum] then
            player:onConsoleMessage("`4Invalid room number. Use 1 or 2.")
            return true
        end

        local target = roomNum and {ROOMS[roomNum]} or ROOMS
        for _, room in ipairs(target) do
            clearGameTimers(room)
            room.queue          = {}
            room.activeUID      = nil
            room.firstPick      = nil
            room.resolving      = nil
            room.exitUID        = nil
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            room.reanchorPos    = nil
            room.gameSession    = room.gameSession + 1
            resetBoard(room)
            resetAllCards(world, room)
        end

        -- Also reset SG and DR rooms when no specific room given
        if not roomNum then
            for _, sgRoom in ipairs(SG_ROOMS) do
                sgClearTimers(sgRoom)
                sgRoom.queue           = {}
                sgRoom.activeUID       = nil
                sgRoom.exitUID         = nil
                sgRoom.gameSession     = sgRoom.gameSession + 1
                sgRoom.score           = 0
                sgRoom.reanchorUID     = nil
                sgRoom.reanchorTickAt  = nil
                sgRoom.reanchorPos     = nil
                sgResetTargets(world, sgRoom)
            end
            for _, drRoom in ipairs(DR_ROOMS) do
                drClearTimers(drRoom)
                drRoom.queue         = {}
                drRoom.activePlayers = {}
                drRoom.gameActive    = false
                drRoom.winner        = nil
                drRoom.gameSession   = drRoom.gameSession + 1
                drRoom.reanchorList  = {}
                drClearObstacles(world, drRoom)
            end
            for _, mmRoom in ipairs(MM_ROOMS) do
                mmClearTimers(mmRoom)
                mmClearBlocks(world, mmRoom)
                mmRoom.queue           = {}
                mmRoom.activeUID       = nil
                mmRoom.exitUID         = nil
                mmRoom.gameSession     = mmRoom.gameSession + 1
                mmRoom.exitTickAt      = nil
                mmRoom.nextQueueTickAt = nil
                mmRoom.reanchorUID     = nil
                mmRoom.reanchorTickAt  = nil
                mmRoom.reanchorPos     = nil
            end
        end
        local label = roomNum and ("Concentration Room " .. roomNum) or "all games"
        player:onConsoleMessage("`2Reset: `w" .. label)
        return true
    end

    return false
end)

-- ══════════════════════════════════════════════════════════════
-- PRIZE DIALOG CALLBACK
-- ══════════════════════════════════════════════════════════════

onPlayerDialogCallback(function(world, player, data)
    local dname = data["dialog_name"]

    -- Main prize panel
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

    -- Edit prize panel
    if dname == "carnival_prize_edit" then
        local btn   = data["buttonClicked"] or ""
        local gName = data["game"] or ""

        if btn == "btn_back" then
            openMainPrizeDialog(player)
            return true
        end

        if gName == "" then return true end
        -- Anything that is not btn_back: save in-memory + reopen
        -- Covers: btn_save, "" (empty), or picker field name (e.g. "common_item_1")
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

-- ══════════════════════════════════════════════════════════════
-- SHOOTING GALLERY — CALLBACKS
-- ══════════════════════════════════════════════════════════════

local sgSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()
    for _, room in ipairs(SG_ROOMS) do sgTickRoom(world, room, now) end
    sgSnapTick = sgSnapTick + 1
    if sgSnapTick >= 10 then
        sgSnapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px, py, uid = p:getPosX(), p:getPosY(), p:getUserID()
            for _, room in ipairs(SG_ROOMS) do
                if uid ~= room.activeUID then
                    local ga = room.gameArea
                    if px >= ga.xMin and px <= ga.xMax and py >= ga.yMin and py <= ga.yMax then
                        world:setPlayerPosition(p, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                        p:onConsoleMessage("`4Game area is restricted to the active player only!")
                        break
                    end
                end
            end
        end
    end
end)

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(SG_ROOMS) do
        if doorUp == room.doorIngame then
            -- Block direct entry; reanchor active player back to ingame pos
            if uid == room.activeUID then
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
            end
            return false
        end

        if doorUp == room.doorExit then
            return false  -- pass through
        end

        if doorUp == room.doorEntrance then
            if uid == room.activeUID then
                player:onConsoleMessage("`4You are currently playing!")
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
                return false
            end
            -- Guard: block if already active in another minigame
            local gType, gRoom = getPlayerActiveGame(uid)
            if gType then
                player:onConsoleMessage("`4You're already playing another minigame!")
                gRoom.reanchorUID    = uid
                gRoom.reanchorTickAt = os.time() + 1
                gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                return false
            end

            for _, e in ipairs(room.queue) do
                if e.uid == uid then
                    player:onConsoleMessage("`7You are already in queue.")
                    room.reanchorUID    = uid
                    room.reanchorTickAt = os.time() + 1
                    room.reanchorPos    = {x = room.posWait.x, y = room.posWait.y}
                    return false
                end
            end
            if player:getItemAmount(TICKET_ID) < 1 then
                bubble(world, player, "`4No Golden Ticket!")
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Shooting Gallery!")
                return false
            end
            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})
            room.reanchorUID    = uid
            room.reanchorTickAt = os.time() + 1
            room.reanchorPos    = {x = room.posWait.x, y = room.posWait.y}
            if not room.activeUID and #room.queue == 1 then
                player:onConsoleMessage("`2Get ready! Entering in `w" .. QUEUE_DELAY .. " seconds`2...")
                sgScheduleNext(room)
            else
                player:onConsoleMessage("`oYou are `w#" .. #room.queue .. "`o in queue — hang tight!")
            end
            return false
        end
    end
    return false
end)

onTilePunchCallback(function(world, avatar, tile)
    if world:getName() ~= WORLD then return false end
    if tile:getTileID() ~= BULLSEYE_ID then return false end

    local px  = math.floor(tile:getPosX() / 32) + 1
    local py  = math.floor(tile:getPosY() / 32) + 1
    local key = px .. "_" .. py

    for _, room in ipairs(SG_ROOMS) do
        if room.targetLookup[key] then
            local uid = avatar:getUserID()
            if uid ~= room.activeUID then return true end  -- prevent break, not active player

            local idx = room.targetLookup[key]
            if not room.litSet[idx] then return true end   -- not lit, no hit

            -- Hit!
            room.litSet[idx]  = nil
            room.punchedCount = room.punchedCount + 1
            room.score        = room.score + 1
            sgSetTarget(world, room, idx, false)

            bubble(world, avatar, "`6Score: " .. room.score)

            if room.punchedCount >= SG_ACTIVE_COUNT then
                if room.roundTimer then timer.clear(room.roundTimer); room.roundTimer = nil end
                sgStartRound(world, room)
            end
            return true
        end
    end
    return false
end)

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()
    for _, room in ipairs(SG_ROOMS) do
        if uid == room.reanchorUID then
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            room.reanchorPos    = nil
        end
        if uid == room.activeUID then
            sgClearTimers(room)
            room.activeUID = nil
            sgResetTargets(world, room)
            for _, e in ipairs(room.queue) do
                local qp = getPlayerInWorld(world, e.uid)
                if qp then
                    qp:onConsoleMessage("`7Previous player left. Next up in `w" .. QUEUE_DELAY .. "s`7...")
                end
            end
            sgScheduleNext(room)
        else
            for i = #room.queue, 1, -1 do
                if room.queue[i].uid == uid then table.remove(room.queue, i) end
            end
            if uid == room.exitUID then
                room.exitUID    = nil
                room.exitTickAt = nil
                sgResetTargets(world, room)
                sgScheduleNext(room)
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- DEATH RACE 5000 — CONSTANTS & CONFIG
-- ══════════════════════════════════════════════════════════════

local DR_SPIKE_ID    = 162   -- Death Spike (instant kill)
local DR_LAVA_ID     = 4     -- Lava (deadly)
local DR_DURATION    = 90    -- Race timer (seconds)
local DR_COUNTDOWN   = 5     -- Pre-race countdown (seconds)
local DR_MIN_PLAYERS = 2     -- Minimum players to start
local DR_EXIT_DELAY  = 5     -- Seconds before exit teleport after race ends

-- Populate DR_ROOMS (forward-declared above getPlayerActiveGame)
DR_ROOMS[1] = {
    name         = "Death Race 5000",
    doorEntrance = "DEATH01",
    doorExit     = "DEATH04",

    posTent   = {x=34, y=14},
    posWait   = {x=34, y=16},
    posIngame = {x=34, y=16},  -- alias used by cross-game guard reanchor
    posCP1    = {x=32, y=16},  -- checkpoint 1 / start
    posCP2    = {x=4,  y=12},  -- checkpoint 2 (left side, floor 2)
    posFinish = {x=32, y=12},  -- finish line (Race End Flag)
    posExit   = {x=36, y=17},

    -- Game area with 1-2 tile buffer so checkpoints are safely inside,
    -- while posWait(34,16) and posExit(36,17) remain outside.
    gameArea = {
        xMin = (2-1)*32,   -- tile 2  (buffer left of CP2 at x=4)
        xMax = (33-1)*32,  -- tile 33 (1 tile right of CP1 at x=32; posWait x=34 still outside)
        yMin = (9-1)*32,   -- tile 9  (buffer above game ceiling)
        yMax = (17-1)*32,  -- tile 17 (1 tile below CP1 floor at y=16)
    },

    -- Runtime state (initialised below)
    queue           = {},
    activePlayers   = {},  -- [uid] = {name, checkpoint, dead, noDeathUntil, finished, respawnAt}
    gameActive      = false,
    gameSession     = 0,
    countdownTickAt = nil,
    gameTimer       = nil,
    exitTickAt      = nil,
    obstacles       = {},  -- [{x,y,id}, ...]  currently placed obstacle tiles
    winner          = nil,
    reanchorList    = {},  -- [{uid, tickAt, pos}]  pending teleports (supports multiple at once)
}

-- ══════════════════════════════════════════════════════════════
-- DEATH RACE — HELPERS
-- ══════════════════════════════════════════════════════════════

drClearObstacles = function(world, room)
    if world then
        for _, obs in ipairs(room.obstacles) do
            local tile = world:getTile(obs.x - 1, obs.y - 1)
            if tile then
                world:setTileForeground(tile, 0)
                world:updateTile(tile)
            end
        end
    end
    room.obstacles = {}
end

-- Generate and place obstacles for both floors.
-- Rules:
--   Slots: x = 6,8,10,...,30 at yFloor (13 slots per floor)
--   After a filled slot: 60% force empty gap, 40% can roll again (allows occasional doubles)
--   Distribution: 25% empty | 17% spike | 25% lava single | 33% lava double
local function drPlaceObstacles(world, room)
    local function genFloor(yFloor)
        local prevFilled = false
        for sx = 6, 30, 2 do
            if prevFilled and math.random(10) <= 6 then
                -- 60% chance: force empty gap after obstacle
                prevFilled = false
            else
                prevFilled = false
                local r = math.random(12)
                if r <= 3 then
                    -- 25% empty slot
                elseif r <= 5 then
                    -- 17% death spike (single tile, floor level)
                    table.insert(room.obstacles, {x=sx, y=yFloor, id=DR_SPIKE_ID})
                    prevFilled = true
                elseif r <= 8 then
                    -- 25% lava single (floor level only)
                    table.insert(room.obstacles, {x=sx, y=yFloor, id=DR_LAVA_ID})
                    prevFilled = true
                else
                    -- 33% lava double (floor + one tile above)
                    table.insert(room.obstacles, {x=sx, y=yFloor,   id=DR_LAVA_ID})
                    table.insert(room.obstacles, {x=sx, y=yFloor-1, id=DR_LAVA_ID})
                    prevFilled = true
                end
            end
        end
    end

    genFloor(16)  -- floor 1 (bottom)
    genFloor(12)  -- floor 2 (top)

    for _, obs in ipairs(room.obstacles) do
        local tile = world:getTile(obs.x - 1, obs.y - 1)
        if tile then
            world:setTileForeground(tile, obs.id)
            world:updateTile(tile)
        end
    end
end

drClearTimers = function(room)
    if room.gameTimer then timer.clear(room.gameTimer); room.gameTimer = nil end
    room.countdownTickAt = nil
    room.exitTickAt      = nil
end

-- Teleport player to their current checkpoint and set death cooldown
local function drTeleportToCP(world, player, room, uid)
    local pstate = room.activePlayers[uid]
    if not pstate then return end
    local cpPos = pstate.checkpoint == 2 and room.posCP2 or room.posCP1
    local cpx   = (cpPos.x - 1) * 32
    local cpy   = (cpPos.y - 1) * 32
    world:setPlayerPosition(player, cpx, cpy)
    pstate.noDeathUntil = os.time() + 2  -- 2s grace period after respawn
end

local function drEndGame(world, room)
    drClearTimers(room)
    room.gameActive = false
    room.exitTickAt = os.time() + DR_EXIT_DELAY
end

local function drHandleWin(world, player, uid, room)
    if room.winner then return end
    room.winner = uid

    local p        = getRandPrize(room.name)
    local item     = getItem(p.itemID)
    local itemName = item and item:getName() or ("Item#" .. p.itemID)

    bubble(world, player, "`6FINISH! " .. player:getName() .. " wins!")
    player:onConsoleMessage("`61st place! `wPrize: " .. p.amount .. "x " .. itemName)
    player:changeItem(p.itemID, p.amount, 0)
    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
    local tx = math.floor(player:getPosX() / 32)
    local ty = math.floor(player:getPosY() / 32)
    player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())

    for ouid in pairs(room.activePlayers) do
        if ouid ~= uid then
            local op = getPlayerInWorld(world, ouid)
            if op then
                bubble(world, op, "`4" .. player:getName() .. " wins the race!")
                op:onConsoleMessage("`4" .. player:getName() .. " reached the finish first. Better luck next time!")
                op:sendVariant({"OnCountdownStart", 0, -1}, 0, op:getNetID())
            end
        end
    end

    drEndGame(world, room)
end

local function drHandleTimeout(world, room)
    for uid in pairs(room.activePlayers) do
        local p = getPlayerInWorld(world, uid)
        if p then
            bubble(world, p, "`4Time's Up! No winner.")
            p:onConsoleMessage("`4Time's up! No one finished the race.")
            p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
        end
    end
    drEndGame(world, room)
end

local function drStartGame(world, room)
    room.gameActive  = true
    room.winner      = nil
    room.gameSession = room.gameSession + 1
    local session    = room.gameSession

    -- Build startList first WITHOUT clearing queue yet
    local startList = {}
    for _, e in ipairs(room.queue) do
        local p = getPlayerInWorld(world, e.uid)
        if p then
            table.insert(startList, {uid = e.uid, player = p, name = e.name})
        end
    end

    if #startList < DR_MIN_PLAYERS then
        -- Not enough online players — abort, keep online players in queue
        room.gameActive = false
        for i = #room.queue, 1, -1 do
            local online = false
            for _, s in ipairs(startList) do
                if s.uid == room.queue[i].uid then online = true; break end
            end
            if not online then table.remove(room.queue, i) end
        end
        return
    end

    -- Enough real players — clear queue and populate activePlayers
    room.queue = {}
    for _, entry in ipairs(startList) do
        room.activePlayers[entry.uid] = {
            name         = entry.name,
            checkpoint   = 1,
            dead         = false,
            noDeathUntil = os.time() + 3,
            finished     = false,
            respawnAt    = nil,
        }
    end

    -- Generate new obstacle layout
    drClearObstacles(world, room)
    drPlaceObstacles(world, room)

    -- Teleport everyone to CP1 and start countdown display
    local cp1x = (room.posCP1.x - 1) * 32
    local cp1y = (room.posCP1.y - 1) * 32
    for _, entry in ipairs(startList) do
        world:setPlayerPosition(entry.player, cp1x, cp1y)
        entry.player:sendVariant({"OnCountdownStart", DR_DURATION, -1}, 0, entry.player:getNetID())
        -- entry.player:onConsoleMessage("`wGO! `7Race to the finish — `w" .. DR_DURATION .. "s`7 on the clock!")
    end

    -- Race timeout timer
    room.gameTimer = timer.setTimeout(DR_DURATION, function()
        room.gameTimer = nil
        if room.gameSession ~= session then return end
        local w = getCarnivalWorld()
        if w then drHandleTimeout(w, room) end
    end)

    -- 30-second warning
    if DR_DURATION > 30 then
        timer.setTimeout(DR_DURATION - 30, function()
            if room.gameSession ~= session or not room.gameActive then return end
            local w = getCarnivalWorld()
            if not w then return end
            for uid in pairs(room.activePlayers) do
                local p = getPlayerInWorld(w, uid)
                if p then p:onConsoleMessage("`630 seconds remaining!") end
            end
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
-- DEATH RACE — WORLD TICK
-- ══════════════════════════════════════════════════════════════

local drSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(DR_ROOMS) do

        -- Countdown: start game when time arrives
        if room.countdownTickAt and now >= room.countdownTickAt and not room.gameActive then
            room.countdownTickAt = nil
            if #room.queue >= DR_MIN_PLAYERS then
                drStartGame(world, room)
            end
        end

        -- Fallback: auto-trigger countdown if conditions met but no countdown running
        -- Catches edge cases where door callback missed the trigger (e.g. brief disconnect/reconnect)
        if not room.gameActive and not room.exitTickAt and not room.countdownTickAt then
            if #room.queue >= DR_MIN_PLAYERS then
                room.countdownTickAt = now + DR_COUNTDOWN
                for _, e in ipairs(room.queue) do
                    local qp = getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`2Race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                    end
                end
            end
        end

        -- Re-anchor pending teleports (supports multiple players simultaneously)
        for i = #room.reanchorList, 1, -1 do
            local ra = room.reanchorList[i]
            if now >= ra.tickAt then
                table.remove(room.reanchorList, i)
                local rp = getPlayerInWorld(world, ra.uid)
                if rp then
                    world:setPlayerPosition(rp, (ra.pos.x-1)*32, (ra.pos.y-1)*32)
                end
            end
        end

        -- Exit teleport: move all finished players out and clean up
        if room.exitTickAt and now >= room.exitTickAt then
            room.exitTickAt = nil
            local ex_px = (room.posExit.x - 1) * 32
            local ex_py = (room.posExit.y - 1) * 32
            for uid in pairs(room.activePlayers) do
                local p = getPlayerInWorld(world, uid)
                if p then
                    p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                    world:setPlayerPosition(p, ex_px, ex_py)
                end
            end
            room.activePlayers = {}
            room.winner        = nil
            drClearObstacles(world, room)
            -- Auto-start next batch if queue already has enough players
            if #room.queue >= DR_MIN_PLAYERS and not room.countdownTickAt then
                room.countdownTickAt = now + DR_COUNTDOWN
                for _, e in ipairs(room.queue) do
                    local qp = getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`2Next race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                    end
                end
            end
        end

        if room.gameActive then
            -- Per-player update
            local toRemove = {}
            for uid, pstate in pairs(room.activePlayers) do
                local p = getPlayerInWorld(world, uid)
                if not p then
                    toRemove[uid] = true
                else
                    local px = p:getPosX()
                    local py = p:getPosY()
                    local tx = math.floor(px / 32) + 1
                    local ty = math.floor(py / 32) + 1

                    -- Finish detection: player reaches tile (32,12)
                    if not pstate.finished then
                        if tx == room.posFinish.x and ty >= room.posFinish.y - 1 and ty <= room.posFinish.y + 1 then
                            pstate.finished = true
                            drHandleWin(world, p, uid, room)
                            -- drHandleWin ends the game; continue loop safely (gameActive=false guards below)
                        end
                    end

                    -- Checkpoint 2 upgrade: player reaches left side of floor 2
                    if not pstate.finished and pstate.checkpoint < 2 then
                        if tx <= room.posCP2.x + 1 and ty >= room.posCP2.y - 1 and ty <= room.posCP2.y + 1 then
                            pstate.checkpoint = 2
                            -- p:onConsoleMessage("`2Checkpoint 2 reached! You will respawn here from now on.")
                        end
                    end

                    -- Death detection: active player outside game area = died and respawned at world door
                    if room.gameActive and not pstate.dead and not pstate.finished and now >= (pstate.noDeathUntil or 0) then
                        local ga = room.gameArea
                        if px < ga.xMin or px > ga.xMax or py < ga.yMin or py > ga.yMax then
                            pstate.dead      = true
                            pstate.respawnAt = now + 1
                            -- p:onConsoleMessage("`4You died! Respawning at checkpoint " .. pstate.checkpoint .. "...")
                        end
                    end

                    -- Respawn after 1-second death delay
                    if pstate.dead and pstate.respawnAt and now >= pstate.respawnAt then
                        pstate.dead      = false
                        pstate.respawnAt = nil
                        drTeleportToCP(world, p, room, uid)
                    end
                end
            end

            for uid in pairs(toRemove) do
                room.activePlayers[uid] = nil
            end

            -- End game if all players finished or left
            if room.gameActive and not room.exitTickAt then
                local remaining = 0
                for _, ps in pairs(room.activePlayers) do
                    if not ps.finished then remaining = remaining + 1 end
                end
                if remaining == 0 then drEndGame(world, room) end
            end
        end
    end

    -- Snap non-active players out of DR game areas (throttled 1×/second)
    drSnapTick = drSnapTick + 1
    if drSnapTick >= 10 then
        drSnapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px, py, uid = p:getPosX(), p:getPosY(), p:getUserID()
            for _, room in ipairs(DR_ROOMS) do
                if not room.activePlayers[uid] then
                    local ga = room.gameArea
                    if px >= ga.xMin and px <= ga.xMax and py >= ga.yMin and py <= ga.yMax then
                        world:setPlayerPosition(p, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                        p:onConsoleMessage("`4Game area is restricted to active race players only!")
                        break
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- DEATH RACE — DOOR ENTRY
-- ══════════════════════════════════════════════════════════════

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(DR_ROOMS) do
        if doorUp == room.doorExit then
            return false  -- pass through
        end

        if doorUp == room.doorEntrance then
            -- Player already active in this race → send back to their checkpoint
            if room.activePlayers[uid] then
                player:onConsoleMessage("`4You are currently in the race!")
                local pstate = room.activePlayers[uid]
                local cpPos  = pstate.checkpoint == 2 and room.posCP2 or room.posCP1
                table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=cpPos})
                return false
            end

            -- Cross-game guard: block if active in Concentration or Shooting Gallery
            local gType, gRoom = getPlayerActiveGame(uid)
            if gType and gType ~= "dr" then
                player:onConsoleMessage("`4You're already playing another minigame!")
                if gRoom.posIngame then
                    gRoom.reanchorUID    = uid
                    gRoom.reanchorTickAt = os.time() + 1
                    gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                end
                return false
            end

            -- Already in DR queue
            for _, e in ipairs(room.queue) do
                if e.uid == uid then
                    player:onConsoleMessage("`7You are already in queue.")
                    table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=room.posWait})
                    return false
                end
            end

            -- Ticket check
            if player:getItemAmount(TICKET_ID) < 1 then
                bubble(world, player, "`4No Golden Ticket!")
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to join Death Race 5000!")
                return false
            end

            -- Add to queue
            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})
            table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=room.posWait})

            if not room.gameActive and not room.exitTickAt then
                if #room.queue >= DR_MIN_PLAYERS and not room.countdownTickAt then
                    -- Enough players — kick off countdown
                    room.countdownTickAt = os.time() + DR_COUNTDOWN
                    for _, e in ipairs(room.queue) do
                        local qp = getPlayerInWorld(world, e.uid)
                        if qp then
                            qp:onConsoleMessage("`2Race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                        end
                    end
                else
                    local needed = DR_MIN_PLAYERS - #room.queue
                    if needed > 0 then
                        player:onConsoleMessage("`oWaiting for `w" .. needed .. " more player" .. (needed > 1 and "s" or "") .. "`o to start the race...")
                    elseif room.countdownTickAt then
                        -- New player joined — reset countdown to give everyone time to prepare
                        room.countdownTickAt = os.time() + DR_COUNTDOWN
                        for _, e in ipairs(room.queue) do
                            local qp = getPlayerInWorld(world, e.uid)
                            if qp then
                                qp:onConsoleMessage("`2New racer joined! Countdown reset — `w" .. DR_COUNTDOWN .. "s`2!")
                            end
                        end
                    end
                end
            else
                player:onConsoleMessage("`oRace in progress. You are `w#" .. #room.queue .. "`o in queue — next race starts after this one.")
            end

            return false
        end
    end

    return false
end)

-- ══════════════════════════════════════════════════════════════
-- DEATH RACE — PLAYER LEAVE
-- ══════════════════════════════════════════════════════════════

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()

    for _, room in ipairs(DR_ROOMS) do
        -- Clean up any pending reanchors for this player
        for i = #room.reanchorList, 1, -1 do
            if room.reanchorList[i].uid == uid then
                table.remove(room.reanchorList, i)
            end
        end

        -- Remove from queue
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end

        -- Cancel countdown if queue drops below minimum
        if room.countdownTickAt and #room.queue < DR_MIN_PLAYERS then
            room.countdownTickAt = nil
            for _, e in ipairs(room.queue) do
                local qp = getPlayerInWorld(world, e.uid)
                if qp then
                    qp:onConsoleMessage("`4Not enough players — countdown cancelled. Waiting for more racers.")
                end
            end
        end

        -- Handle active racer leaving mid-game
        if room.activePlayers[uid] then
            room.activePlayers[uid] = nil

            if room.gameActive and not room.exitTickAt then
                -- Check if anyone is still racing
                local remaining = 0
                for _, ps in pairs(room.activePlayers) do
                    if not ps.finished then remaining = remaining + 1 end
                end

                if remaining == 0 then
                    -- No racers left — end game immediately
                    drClearTimers(room)
                    room.gameActive = false
                    drClearObstacles(world, room)
                    if #room.queue >= DR_MIN_PLAYERS then
                        room.countdownTickAt = os.time() + DR_COUNTDOWN
                        for _, e in ipairs(room.queue) do
                            local qp = getPlayerInWorld(world, e.uid)
                            if qp then
                                qp:onConsoleMessage("`7All racers left. New race starting in `w" .. DR_COUNTDOWN .. "s`7...")
                            end
                        end
                    end
                else
                    -- Notify remaining racers
                    for ouid in pairs(room.activePlayers) do
                        local op = getPlayerInWorld(world, ouid)
                        if op then
                            op:onConsoleMessage("`7A racer disconnected. Race continues!")
                        end
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- MIRROR MAZE — CONSTANTS & CONFIG
-- ══════════════════════════════════════════════════════════════

local MM_BLOCK_ID = 1926  -- Mirror Maze Block (OFF=collision/wall, ON=no collision/passable)
local MM_TIMER    = 40    -- Seconds to solve the maze

-- Maze is generated randomly each game (see mmGenerateOpen).
-- posIngame and posEndgame tiles are always skipped (existing world tiles kept).

MM_ROOMS = {
    {
        name         = "Mirror Maze",
        doorEntrance = "MIRROR01",
        doorIngame   = "MIRROR02",
        posWait      = {x=27, y=29},
        posIngame    = {x=15, y=33},
        posEndgame   = {x=25, y=25},
        posExit      = {x=28, y=26},
        gameArea     = {x1=15, y1=25, x2=25, y2=33},
    },
}

for _, room in ipairs(MM_ROOMS) do
    room.queue           = {}
    room.activeUID       = nil
    room.exitUID         = nil
    room.reanchorUID     = nil
    room.reanchorTickAt  = nil
    room.reanchorPos     = nil
    room.gameTimer       = nil
    room.gameSession     = 0
    room.exitTickAt      = nil
    room.nextQueueTickAt = nil
end

-- ══════════════════════════════════════════════════════════════
-- MIRROR MAZE — HELPERS
-- ══════════════════════════════════════════════════════════════

mmClearTimers = function(room)
    if room.gameTimer then
        timer.clear(room.gameTimer)
        room.gameTimer = nil
    end
end

mmClearBlocks = function(world, room)
    if not world then return end
    local ga   = room.gameArea
    local si   = room.posIngame
    local ei   = room.posEndgame
    for tx = ga.x1, ga.x2 do
        for ty = ga.y1, ga.y2 do
            if not (tx == si.x and ty == si.y) and not (tx == ei.x and ty == ei.y) then
                local tile = world:getTile(tx-1, ty-1)
                if tile then
                    world:setTileForeground(tile, 0)
                    world:updateTile(tile)
                end
            end
        end
    end
end

-- Generates a perfect maze using recursive backtracker on a 2-step cell grid.
-- Cells are at even offsets from (x1,y1); walls sit between adjacent cells.
-- Each corridor is exactly 1 tile wide: wall | path | wall guaranteed.
-- openSet: keys (x*100+y) of passable tiles in world tile coords.
local function mmGenerateOpen(x1, y1, x2, y2, sx, sy, ex, ey)
    local openSet = {}
    local visited = {}

    local function key(x, y) return x * 100 + y end

    -- Cell grid dimensions (cells spaced 2 tiles apart)
    local cw = math.floor((x2 - x1) / 2)
    local ch = math.floor((y2 - y1) / 2)

    local function inBoundsCell(cx, cy)
        return cx >= 0 and cx <= cw and cy >= 0 and cy <= ch
    end

    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(i)
            t[i], t[j] = t[j], t[i]
        end
    end

    -- Start cell from posIngame (must be at even offset)
    local scx = (sx - x1) / 2
    local scy = (sy - y1) / 2

    -- Randomized DFS: carve cell + wall between cells
    local function dfs(cx, cy)
        visited[key(cx, cy)] = true
        -- Open this cell tile
        openSet[key(x1 + cx * 2, y1 + cy * 2)] = true

        local dirs = {{0,1},{0,-1},{1,0},{-1,0}}
        shuffle(dirs)
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if inBoundsCell(nx, ny) and not visited[key(nx, ny)] then
                -- Open the 1-tile wall between current cell and next cell
                openSet[key(x1 + cx*2 + d[1], y1 + cy*2 + d[2])] = true
                dfs(nx, ny)
            end
        end
    end

    dfs(scx, scy)
    return openSet
end

local function mmPlaceMaze(world, room)
    math.randomseed(os.time() + room.gameSession * 1337)
    local ga = room.gameArea
    local si = room.posIngame
    local ei = room.posEndgame
    local openSet = mmGenerateOpen(ga.x1, ga.y1, ga.x2, ga.y2, si.x, si.y, ei.x, ei.y)
    for tx = ga.x1, ga.x2 do
        for ty = ga.y1, ga.y2 do
            if not (tx == si.x and ty == si.y) and not (tx == ei.x and ty == ei.y) then
                local tile = world:getTile(tx-1, ty-1)
                if tile then
                    world:setTileForeground(tile, MM_BLOCK_ID)
                    local flags = tile:getFlags()
                    if openSet[tx * 100 + ty] then
                        flags = bit.bor(flags, TILE_FLAG_IS_ON)
                    else
                        flags = bit.band(flags, bit.bnot(TILE_FLAG_IS_ON))
                    end
                    tile:setFlags(flags)
                    world:updateTile(tile)
                end
            end
        end
    end
end

local function mmScheduleNext(room)
    if #room.queue > 0 then
        room.nextQueueTickAt = os.time() + QUEUE_DELAY
    end
end

local function mmStartGame(world, room)
    if room.activeUID then return end
    while #room.queue > 0 do
        local entry = table.remove(room.queue, 1)
        local p = getPlayerInWorld(world, entry.uid)
        if p then
            room.activeUID   = entry.uid
            room.gameSession = room.gameSession + 1
            local session    = room.gameSession
            world:setPlayerPosition(p, (room.posIngame.x-1)*32, (room.posIngame.y-1)*32)
            mmPlaceMaze(world, room)
            p:sendVariant({"OnCountdownStart", MM_TIMER, -1}, 0, p:getNetID())
            room.gameTimer = timer.setTimeout(MM_TIMER, function()
                if session ~= room.gameSession then return end
                local w2 = getCarnivalWorld()
                if not w2 then return end
                local loser = getPlayerInWorld(w2, room.activeUID)
                if loser then
                    loser:sendVariant({"OnCountdownStart", 0, -1}, 0, loser:getNetID())
                    bubble(w2, loser, "`4Time's up! Better luck next time.")
                end
                room.gameTimer  = nil
                room.exitUID    = room.activeUID
                room.activeUID  = nil
                room.exitTickAt = os.time() + 3
                mmPlaceMaze(w2, room)
            end)
            return
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- MIRROR MAZE — WORLD TICK
-- ══════════════════════════════════════════════════════════════

local mmSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(MM_ROOMS) do
        -- Reanchor tick
        if room.reanchorUID and room.reanchorTickAt and now >= room.reanchorTickAt then
            local uid2 = room.reanchorUID
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            local rp = getPlayerInWorld(world, uid2)
            if rp and room.reanchorPos then
                world:setPlayerPosition(rp, (room.reanchorPos.x-1)*32, (room.reanchorPos.y-1)*32)
            end
            room.reanchorPos = nil
        end

        -- Exit tick: teleport player out, start next queue entry
        if room.exitTickAt and now >= room.exitTickAt then
            room.exitTickAt = nil
            if room.exitUID then
                local ep = getPlayerInWorld(world, room.exitUID)
                if ep then
                    world:setPlayerPosition(ep, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                end
                room.exitUID = nil
            end
            mmScheduleNext(room)
        end

        -- Queue start tick
        if room.nextQueueTickAt and now >= room.nextQueueTickAt then
            room.nextQueueTickAt = nil
            mmStartGame(world, room)
        end

        -- Win detection: active player reached posEndgame
        if room.activeUID then
            local ap = getPlayerInWorld(world, room.activeUID)
            if ap then
                local tx = math.floor(ap:getPosX()/32) + 1
                local ty = math.floor(ap:getPosY()/32) + 1
                if tx == room.posEndgame.x and ty == room.posEndgame.y then
                    mmClearTimers(room)
                    local prize = getRandPrize(room.name)
                    local item  = getItem(prize.itemID)
                    local iname = item and item:getName() or ("Item#" .. prize.itemID)
                    ap:sendVariant({"OnCountdownStart", 0, -1}, 0, ap:getNetID())
                    bubble(world, ap, "`2You found the exit! You win a `w" .. iname .. "`2!")
                    ap:changeItem(prize.itemID, prize.amount, 1)
                    room.exitUID    = room.activeUID
                    room.activeUID  = nil
                    room.exitTickAt = now + 3
                    mmPlaceMaze(world, room)
                end
            else
                -- Active player disconnected mid-game
                mmClearTimers(room)
                room.activeUID = nil
                mmPlaceMaze(world, room)
                mmScheduleNext(room)
            end
        end
    end

    -- Snap: eject non-active players from game area every ~1s
    mmSnapTick = mmSnapTick + 1
    if mmSnapTick >= 10 then
        mmSnapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px, py, uid = p:getPosX(), p:getPosY(), p:getUserID()
            for _, room in ipairs(MM_ROOMS) do
                if uid ~= room.activeUID then
                    local ga = room.gameArea
                    if px >= (ga.x1-1)*32 and px <= ga.x2*32 and
                       py >= (ga.y1-1)*32 and py <= ga.y2*32 then
                        world:setPlayerPosition(p, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                        p:onConsoleMessage("`4Game area is restricted to the active player only!")
                        break
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- MIRROR MAZE — DOOR ENTRY
-- ══════════════════════════════════════════════════════════════

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(MM_ROOMS) do
        if doorUp == room.doorIngame then
            -- Block direct entry; reanchor active player back inside
            if uid == room.activeUID then
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
            end
            return false
        end

        if doorUp == room.doorEntrance then
            if uid == room.activeUID then
                player:onConsoleMessage("`4You are currently in the maze!")
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
                return false
            end
            -- Guard: block if already active in another minigame
            local gType, gRoom = getPlayerActiveGame(uid)
            if gType then
                player:onConsoleMessage("`4You're already playing another minigame!")
                gRoom.reanchorUID    = uid
                gRoom.reanchorTickAt = os.time() + 1
                gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                return false
            end
            -- Already in queue?
            for _, e in ipairs(room.queue) do
                if e.uid == uid then
                    player:onConsoleMessage("`7You are already in queue.")
                    room.reanchorUID    = uid
                    room.reanchorTickAt = os.time() + 1
                    room.reanchorPos    = {x = room.posWait.x, y = room.posWait.y}
                    return false
                end
            end
            -- Ticket check
            if player:getItemAmount(TICKET_ID) < 1 then
                bubble(world, player, "`4No Golden Ticket!")
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Mirror Maze!")
                return false
            end
            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})
            room.reanchorUID    = uid
            room.reanchorTickAt = os.time() + 1
            room.reanchorPos    = {x = room.posWait.x, y = room.posWait.y}
            if not room.activeUID and #room.queue == 1 then
                player:onConsoleMessage("`2Get ready! Entering in `w" .. QUEUE_DELAY .. " seconds`2...")
                mmScheduleNext(room)
            else
                player:onConsoleMessage("`oYou are `w#" .. #room.queue .. "`o in queue — hang tight!")
            end
            return false
        end
    end
    return false
end)

-- ══════════════════════════════════════════════════════════════
-- MIRROR MAZE — PLAYER LEAVE
-- ══════════════════════════════════════════════════════════════

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()
    for _, room in ipairs(MM_ROOMS) do
        if uid == room.reanchorUID then
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            room.reanchorPos    = nil
        end
        if uid == room.activeUID then
            mmClearTimers(room)
            room.activeUID = nil
            mmPlaceMaze(world, room)
            for _, e in ipairs(room.queue) do
                local qp = getPlayerInWorld(world, e.uid)
                if qp then qp:onConsoleMessage("`7Previous player left. Next up in `w" .. QUEUE_DELAY .. "s`7...") end
            end
            mmScheduleNext(room)
        elseif uid == room.exitUID then
            room.exitUID    = nil
            room.exitTickAt = nil
            mmScheduleNext(room)
        else
            for i = #room.queue, 1, -1 do
                if room.queue[i].uid == uid then table.remove(room.queue, i) end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- GLOBAL — PLAYER DEATH / RESPAWN
-- Remove player from all queues and forfeit active game.
-- DR active players are excluded (DR has its own death handling).
-- ══════════════════════════════════════════════════════════════

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid = player:getUserID()

    -- Concentration (queue only)
    for _, room in ipairs(ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end

    -- Shooting Gallery (queue only)
    for _, room in ipairs(SG_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end

    -- Death Race — queue only (active racers handled by DR itself)
    for _, room in ipairs(DR_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
        if room.countdownTickAt and #room.queue < DR_MIN_PLAYERS then
            room.countdownTickAt = nil
            for _, e in ipairs(room.queue) do
                local qp = getPlayerInWorld(world, e.uid)
                if qp then qp:onConsoleMessage("`4Not enough players — countdown cancelled.") end
            end
        end
    end

    -- Mirror Maze (queue only)
    for _, room in ipairs(MM_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end
end)
