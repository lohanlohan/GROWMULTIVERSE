-- MODULE
-- shooting_gallery.lua — Shooting Gallery minigame (2 rooms)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER  = Shared.WORLD_UPPER
local WORLD        = Shared.WORLD
local TICKET_ID    = Shared.TICKET_ID
local QUEUE_DELAY  = Shared.QUEUE_DELAY
local WIN_PARTICLE = Shared.WIN_PARTICLE
local TILE_FLAG_IS_ON = Shared.TILE_FLAG_IS_ON

-- ── Constants ─────────────────────────────────────────────────────────────────

local BULLSEYE_ID     = 1908
local SG_DURATION     = 30
local SG_ROUND_TIME   = 3
local SG_ACTIVE_COUNT = 3
local SG_WIN_SCORE    = 30

-- ── Room config ───────────────────────────────────────────────────────────────

local SG_ROOMS = {
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
    room.queue          = {}
    room.activeUID      = nil
    room.exitUID        = nil
    room.gameSession    = 0
    room.score          = 0
    room.litSet         = {}
    room.punchedCount   = 0
    room.gameTimer      = nil
    room.roundTimer     = nil
    room.nextTickAt     = nil
    room.exitTickAt     = nil
    room.secTeleport    = nil
    room.secTickAt      = nil
    room.reanchorUID    = nil
    room.reanchorTickAt = nil
    room.reanchorPos    = nil
    room.gameStartTime  = 0
    room.targetLookup   = {}
    for i, pos in ipairs(room.targetPos) do
        room.targetLookup[pos.x .. "_" .. pos.y] = i
    end
end

-- ── Target operations ─────────────────────────────────────────────────────────

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

local function sgStartRound(world, room)
    for idx in pairs(room.litSet) do sgSetTarget(world, room, idx, false) end
    room.litSet       = {}
    room.punchedCount = 0
    if room.roundTimer then timer.clear(room.roundTimer); room.roundTimer = nil end

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
        local w = Shared.getCarnivalWorld()
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
        local p        = Shared.getRandPrize(room.name)
        local item     = getItem(p.itemID)
        local itemName = item and item:getName() or ("Item#" .. p.itemID)
        Shared.bubble(world, player, "`6You scored " .. room.score .. " points! `0You win a `2" .. itemName .. "`0!")
        player:changeItem(p.itemID, p.amount, 0)
        local tx = math.floor(player:getPosX() / 32)
        local ty = math.floor(player:getPosY() / 32)
        player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())
    elseif player then
        Shared.bubble(world, player, "`4Time's Up! Final score: " .. room.score)
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
        player = Shared.getPlayerInWorld(world, entry.uid)
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
    room.secTeleport   = {uid = uid, x = in_px, y = in_py}
    room.secTickAt     = os.time() + 1
    room.gameStartTime = os.time()

    player:sendVariant({"OnCountdownStart", SG_DURATION, -1}, 0, player:getNetID())
    player:onConsoleMessage("`wGO! `7Hit all `w3`7 lit targets within `w3s`7 each round.")

    room.gameTimer = timer.setTimeout(SG_DURATION, function()
        room.gameTimer = nil
        if room.activeUID ~= uid or room.gameSession ~= session then return end
        local w   = Shared.getCarnivalWorld()
        local p   = w and Shared.getPlayerInWorld(w, uid)
        local won = room.score >= SG_WIN_SCORE
        sgHandleEnd(w, p, won, room)
    end)

    timer.setTimeout(1, function()
        if room.activeUID ~= uid or room.gameSession ~= session then return end
        local w = Shared.getCarnivalWorld()
        if not w then return end
        sgStartRound(w, room)
    end)
end

local function sgTickRoom(world, room, now)
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
        local st         = room.secTeleport
        room.secTeleport = nil
        if st then
            local sp = Shared.getPlayerInWorld(world, st.uid)
            if sp then world:setPlayerPosition(sp, st.x, st.y) end
        end
    end

    if room.exitTickAt and now >= room.exitTickAt then
        room.exitTickAt = nil
        local uid_ex    = room.exitUID
        local exP       = uid_ex and Shared.getPlayerInWorld(world, uid_ex)
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

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    for _, room in ipairs(SG_ROOMS) do
        sgClearTimers(room)
        room.queue          = {}
        room.activeUID      = nil
        room.exitUID        = nil
        room.score          = 0
        room.reanchorUID    = nil
        room.reanchorTickAt = nil
        room.reanchorPos    = nil
        room.gameSession    = room.gameSession + 1
        if world then sgResetTargets(world, room) end
    end
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local snapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()
    for _, room in ipairs(SG_ROOMS) do sgTickRoom(world, room, now) end

    snapTick = snapTick + 1
    if snapTick >= 10 then
        snapTick = 0
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
                player:onConsoleMessage("`4You are currently playing!")
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
                Shared.bubble(world, player, "`4No Golden Ticket!")
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
            if uid ~= room.activeUID then return true end

            local idx = room.targetLookup[key]
            if not room.litSet[idx] then return true end

            room.litSet[idx]  = nil
            room.punchedCount = room.punchedCount + 1
            room.score        = room.score + 1
            sgSetTarget(world, room, idx, false)

            Shared.bubble(world, avatar, "`6Score: " .. room.score)

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
                local qp = Shared.getPlayerInWorld(world, e.uid)
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

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid = player:getUserID()
    for _, room in ipairs(SG_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("sg", function() return SG_ROOMS end, false, resetAll)

return M
