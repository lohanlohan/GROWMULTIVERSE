-- MODULE
-- mirror_maze.lua — Mirror Maze minigame (1 room, solo)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER     = Shared.WORLD_UPPER
local WORLD           = Shared.WORLD
local TICKET_ID       = Shared.TICKET_ID
local QUEUE_DELAY     = Shared.QUEUE_DELAY
local TILE_FLAG_IS_ON = Shared.TILE_FLAG_IS_ON

-- ── Constants ─────────────────────────────────────────────────────────────────

local MM_BLOCK_ID = 1926
local MM_TIMER    = 40

-- ── Room config ───────────────────────────────────────────────────────────────

local MM_ROOMS = {
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

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function mmClearTimers(room)
    if room.gameTimer then timer.clear(room.gameTimer); room.gameTimer = nil end
end

local function mmClearBlocks(world, room)
    if not world then return end
    local ga = room.gameArea
    local si = room.posIngame
    local ei = room.posEndgame
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

-- Recursive backtracker maze generator
-- Returns openSet: keys (x*100+y) of passable tiles in world tile coords.
local function mmGenerateOpen(x1, y1, x2, y2, sx, sy, ex, ey)
    local openSet = {}
    local visited = {}

    local function key(x, y) return x * 100 + y end

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

    local scx = (sx - x1) / 2
    local scy = (sy - y1) / 2

    local function dfs(cx, cy)
        visited[key(cx, cy)] = true
        openSet[key(x1 + cx * 2, y1 + cy * 2)] = true
        local dirs = {{0,1},{0,-1},{1,0},{-1,0}}
        shuffle(dirs)
        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if inBoundsCell(nx, ny) and not visited[key(nx, ny)] then
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
        local p = Shared.getPlayerInWorld(world, entry.uid)
        if p then
            room.activeUID   = entry.uid
            room.gameSession = room.gameSession + 1
            local session    = room.gameSession
            world:setPlayerPosition(p, (room.posIngame.x-1)*32, (room.posIngame.y-1)*32)
            mmPlaceMaze(world, room)
            p:sendVariant({"OnCountdownStart", MM_TIMER, -1}, 0, p:getNetID())
            room.gameTimer = timer.setTimeout(MM_TIMER, function()
                if session ~= room.gameSession then return end
                local w2 = Shared.getCarnivalWorld()
                if not w2 then return end
                local loser = Shared.getPlayerInWorld(w2, room.activeUID)
                if loser then
                    loser:sendVariant({"OnCountdownStart", 0, -1}, 0, loser:getNetID())
                    Shared.bubble(w2, loser, "`4Time's up! Better luck next time.")
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

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    for _, room in ipairs(MM_ROOMS) do
        mmClearTimers(room)
        if world then mmClearBlocks(world, room) end
        room.queue           = {}
        room.activeUID       = nil
        room.exitUID         = nil
        room.reanchorUID     = nil
        room.reanchorTickAt  = nil
        room.reanchorPos     = nil
        room.exitTickAt      = nil
        room.nextQueueTickAt = nil
        room.gameSession     = room.gameSession + 1
    end
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local mmSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(MM_ROOMS) do
        if room.reanchorUID and room.reanchorTickAt and now >= room.reanchorTickAt then
            local uid2 = room.reanchorUID
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            local rp = Shared.getPlayerInWorld(world, uid2)
            if rp and room.reanchorPos then
                world:setPlayerPosition(rp, (room.reanchorPos.x-1)*32, (room.reanchorPos.y-1)*32)
            end
            room.reanchorPos = nil
        end

        if room.exitTickAt and now >= room.exitTickAt then
            room.exitTickAt = nil
            if room.exitUID then
                local ep = Shared.getPlayerInWorld(world, room.exitUID)
                if ep then
                    world:setPlayerPosition(ep, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                end
                room.exitUID = nil
            end
            mmScheduleNext(room)
        end

        if room.nextQueueTickAt and now >= room.nextQueueTickAt then
            room.nextQueueTickAt = nil
            mmStartGame(world, room)
        end

        if room.activeUID then
            local ap = Shared.getPlayerInWorld(world, room.activeUID)
            if ap then
                local tx = math.floor(ap:getPosX()/32) + 1
                local ty = math.floor(ap:getPosY()/32) + 1
                if tx == room.posEndgame.x and ty == room.posEndgame.y then
                    mmClearTimers(room)
                    local prize = Shared.getRandPrize(room.name)
                    local item  = getItem(prize.itemID)
                    local iname = item and item:getName() or ("Item#" .. prize.itemID)
                    ap:sendVariant({"OnCountdownStart", 0, -1}, 0, ap:getNetID())
                    Shared.bubble(world, ap, "`2You found the exit! You win a `w" .. iname .. "`2!")
                    ap:changeItem(prize.itemID, prize.amount, 1)
                    room.exitUID    = room.activeUID
                    room.activeUID  = nil
                    room.exitTickAt = now + 3
                    mmPlaceMaze(world, room)
                end
            else
                mmClearTimers(room)
                room.activeUID = nil
                mmPlaceMaze(world, room)
                mmScheduleNext(room)
            end
        end
    end

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

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(MM_ROOMS) do
        if doorUp == room.doorIngame then
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
                local qp = Shared.getPlayerInWorld(world, e.uid)
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

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid = player:getUserID()
    for _, room in ipairs(MM_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("mm", function() return MM_ROOMS end, false, resetAll)

return M
