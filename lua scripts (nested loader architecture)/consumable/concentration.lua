-- MODULE
-- concentration.lua — Concentration memory card game (2 rooms)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER  = Shared.WORLD_UPPER
local WORLD        = Shared.WORLD
local TICKET_ID    = Shared.TICKET_ID
local CARD_BACK_ID = Shared.CARD_BACK_ID
local QUEUE_DELAY  = Shared.QUEUE_DELAY
local WIN_PARTICLE = Shared.WIN_PARTICLE
local GAME_DURATION = Shared.GAME_DURATION

-- ── Room config ───────────────────────────────────────────────────────────────

local ROOMS = {
    {
        name         = "Concentration",
        doorEntrance = "CONCENTRATION01",
        doorIngame   = "CONCENTRATION02",
        doorExit     = "CONCENTRATION03",
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

-- ── Card operations ───────────────────────────────────────────────────────────

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

-- ── Game state helpers ────────────────────────────────────────────────────────

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

-- ── Game flow ─────────────────────────────────────────────────────────────────

local function handleEnd(world, player, won, room)
    clearGameTimers(room)
    local uid = room.activeUID
    room.activeUID = nil
    room.firstPick = nil
    room.resolving = nil

    if won and player then
        local p = Shared.getRandPrize(room.name)
        local item = getItem(p.itemID)
        local itemName = item and item:getName() or ("Item#" .. p.itemID)
        Shared.bubble(world, player, "`2Concentration Clear!")
        player:onConsoleMessage("`2Congratulations! You matched all 8 pairs!")
        player:onConsoleMessage("`2Prize: `w" .. p.amount .. "x " .. itemName)
        player:changeItem(p.itemID, p.amount, 0)
        local tx = math.floor(player:getPosX() / 32)
        local ty = math.floor(player:getPosY() / 32)
        player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())
    elseif player then
        Shared.bubble(world, player, "`4Time's Up!")
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
        player = Shared.getPlayerInWorld(world, entry.uid)
    until player or #room.queue == 0

    if not player then return end

    local uid = entry.uid
    room.activeUID   = uid
    room.gameBoard   = Shared.makeBoard()
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
                local w = Shared.getCarnivalWorld()
                local p = w and Shared.getPlayerInWorld(w, uid)
                if p then p:onConsoleMessage("`6" .. warnSec .. " seconds remaining!") end
            end)
        end
    end

    clearGameTimers(room)
    room.gameTimer = timer.setTimeout(GAME_DURATION, function()
        room.gameTimer = nil
        if room.activeUID ~= uid then return end
        local w = Shared.getCarnivalWorld()
        local p = w and Shared.getPlayerInWorld(w, uid)
        handleEnd(w, p, false, room)
    end)

    for i, e in ipairs(room.queue) do
        local qp = Shared.getPlayerInWorld(world, e.uid)
        if qp then
            qp:onConsoleMessage("`7" .. entry.name .. " is now playing. You are `w#" .. i .. "`7 in queue.")
        end
    end
end

local function tickRoom(world, room, now)
    if room.nextTickAt and now >= room.nextTickAt and not room.activeUID and #room.queue > 0 then
        room.nextTickAt = nil
        startNextPlayer(world, room)
    end

    if room.exitTickAt and now >= room.exitTickAt then
        room.exitTickAt = nil
        local uid_ex = room.exitUID
        local exP    = uid_ex and Shared.getPlayerInWorld(world, uid_ex)
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

    if room.reanchorTickAt and now >= room.reanchorTickAt then
        local ruid = room.reanchorUID
        local rpos = room.reanchorPos
        room.reanchorUID    = nil
        room.reanchorTickAt = nil
        room.reanchorPos    = nil
        local rp = ruid and Shared.getPlayerInWorld(world, ruid)
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
        local st = room.secTeleport
        room.secTeleport = nil
        if st then
            local sp = Shared.getPlayerInWorld(world, st.uid)
            if sp then world:setPlayerPosition(sp, st.x, st.y) end
        end
    end
end

-- ── Reset (called by /carnivalreset) ──────────────────────────────────────────

local function resetAll(world)
    for _, room in ipairs(ROOMS) do
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
        if world then resetAllCards(world, room) end
    end
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local snapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()
    for _, room in ipairs(ROOMS) do tickRoom(world, room, now) end

    snapTick = snapTick + 1
    if snapTick >= 10 then
        snapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px, py, uid = p:getPosX(), p:getPosY(), p:getUserID()
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

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(ROOMS) do
        if doorUp == room.doorIngame then
            if uid == room.activeUID then
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
            end
            return false
        end

        if doorUp == room.doorExit then
            return false
        end

        if doorUp == room.doorEntrance then
            if uid == room.activeUID then
                player:onConsoleMessage("`4You are currently playing! Returning you to the game.")
                room.reanchorUID    = uid
                room.reanchorTickAt = os.time() + 1
                room.reanchorPos    = {x = room.posIngame.x, y = room.posIngame.y}
                return false
            end

            local gType, gRoom = Shared.getPlayerActiveGame(uid)
            if gType then
                player:onConsoleMessage("`4You're already playing another minigame!")
                if gRoom.reanchorList then
                    table.insert(gRoom.reanchorList, {uid=uid, tickAt=os.time()+1, pos=gRoom.posIngame})
                else
                    gRoom.reanchorUID    = uid
                    gRoom.reanchorTickAt = os.time() + 1
                    gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                end
                return false
            end

            if Shared.isInQueue(room, uid) then
                player:onConsoleMessage("`7You are already in queue.")
                return false
            end

            if player:getItemAmount(TICKET_ID) < 1 then
                Shared.bubble(world, player, "`4No Golden Ticket!")
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

onTilePunchCallback(function(world, avatar, tile)
    if world:getName() ~= WORLD then return false end

    local px  = math.floor(tile:getPosX() / 32) + 1
    local py  = math.floor(tile:getPosY() / 32) + 1
    local key = px .. "_" .. py

    for _, room in ipairs(ROOMS) do
        local cardIdx = room.cardLookup[key]
        if cardIdx then
            if avatar:getUserID() ~= room.activeUID then return true end
            if room.matched[cardIdx] then return true end

            if room.resolving then
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
                room.firstPick = {idx = cardIdx, sym = room.gameBoard[cardIdx]}
                setCard(world, room, cardIdx, room.gameBoard[cardIdx])
            elseif room.firstPick.idx ~= cardIdx then
                local sym2 = room.gameBoard[cardIdx]
                setCard(world, room, cardIdx, sym2)

                if room.firstPick.sym == sym2 then
                    room.matched[room.firstPick.idx] = true
                    room.matched[cardIdx]            = true
                    room.matchCount = room.matchCount + 2
                    room.firstPick  = nil
                    if room.matchCount == 16 then
                        handleEnd(world, avatar, true, room)
                    end
                else
                    room.resolving = {idx1 = room.firstPick.idx, idx2 = cardIdx}
                    room.firstPick = nil
                end
            end

            return true
        end
    end

    return false
end)

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()

    for _, room in ipairs(ROOMS) do
        if uid == room.activeUID then
            clearGameTimers(room)
            room.gameSession = room.gameSession + 1
            room.activeUID   = nil
            room.firstPick   = nil
            room.resolving   = nil
            resetBoard(room)
            resetAllCards(world, room)

            if #room.queue > 0 then
                for _, e in ipairs(room.queue) do
                    local qp = Shared.getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`7Previous player left. Next player entering in `w" .. QUEUE_DELAY .. " seconds`7...")
                    end
                end
                scheduleNextPlayer(room)
            end
        else
            Shared.removeFromQueue(room, uid)

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

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid = player:getUserID()
    for _, room in ipairs(ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("concentration", function() return ROOMS end, false, resetAll)

return M
