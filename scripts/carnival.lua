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
local GAME_DURATION = 180
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
    -- Room 2: add coords when available
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

-- Returns gameType ("concentration"/"sg") and room if player is activeUID in any game
local function getPlayerActiveGame(uid)
    for _, room in ipairs(ROOMS) do
        if uid == room.activeUID then return "concentration", room end
    end
    for _, room in ipairs(SG_ROOMS) do
        if uid == room.activeUID then return "sg", room end
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
            if room.resolving                        then return true end
            if room.matched[cardIdx]                 then return true end

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
                    -- MISMATCH — flip both cards back after delay
                    local i1 = room.firstPick.idx
                    local i2 = cardIdx
                    room.firstPick = nil
                    room.resolving = {idx1=i1, idx2=i2}
                    if room.flipTimer then timer.clear(room.flipTimer) end
                    room.flipTimer = timer.setTimeout(FLIP_DELAY, function()
                        room.flipTimer = nil
                        if not room.resolving then return end
                        local w = getCarnivalWorld()
                        if not w then return end
                        setCard(w, room, i1, CARD_BACK_ID)
                        setCard(w, room, i2, CARD_BACK_ID)
                        room.resolving = nil
                        room.firstPick = nil
                    end)
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

        -- Also reset SG rooms when no specific room given
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
