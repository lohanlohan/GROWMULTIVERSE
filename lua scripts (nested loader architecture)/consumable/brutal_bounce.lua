-- MODULE
-- brutal_bounce.lua — Brutal Bounce minigame (1 room, multiplayer last-man-standing)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER = Shared.WORLD_UPPER
local WORLD       = Shared.WORLD
local TICKET_ID   = Shared.TICKET_ID

-- ── Constants ─────────────────────────────────────────────────────────────────

local BB_TIMER          = 60
local BB_SPIKEBALL_ID   = 2568
local BB_COUNTDOWN      = 5
local BB_MIN_PLAYERS    = 2
local BB_MAX_PLAYERS    = 4
local BB_SPIKE_DURATION = 2

-- ── Room config ───────────────────────────────────────────────────────────────

local BB_ROOM = {
    name         = "Brutal Bounce",
    doorEntrance = "BOUNCE01",
    doorIngame1  = "BOUNCE02",
    doorIngame2  = "BOUNCE03",
    doorExit     = "BOUNCE04",
    posWait      = {x = 76, y = 33},
    posIngame    = {x = 78, y = 27},
    posIngame2   = {x = 87, y = 27},
    posExit      = {x = 76, y = 36},
    gameArea     = {x1 = 77, y1 = 20, x2 = 88, y2 = 36},

    queue         = {},
    activePlayers = {},   -- [uid] = {name, noDeathUntil, pendingExit, spikeTileX, spikeTileY, spikePlacedAt}
    reanchorList  = {},
    spawnZones    = {},
    spawnZoneSet  = {},
    gameActive    = false,
    gameSession   = 0,
    countdownAt   = nil,
    gameEndAt     = nil,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Scan game area for background-only tiles (fg==0 or nil, bg!=0)
local function bbScanSpawnZones(world, room)
    room.spawnZones   = {}
    room.spawnZoneSet = {}
    local ga = room.gameArea
    for tx = ga.x1 - 1, ga.x2 - 1 do
        for ty = ga.y1 - 1, ga.y2 - 1 do
            local tile = world:getTile(tx, ty)
            if tile then
                local fg = tile:getTileForeground()
                local bg = tile:getTileBackground()
                if (fg == 0 or fg == nil) and bg ~= nil and bg ~= 0 then
                    table.insert(room.spawnZones, {tx, ty})
                    room.spawnZoneSet[tx .. "," .. ty] = true
                end
            end
        end
    end
end

local function bbScheduleNext(room)
    if #room.queue > 0 and not room.gameActive and not room.countdownAt then
        room.countdownAt = os.time() + BB_COUNTDOWN
    end
end

local function bbRemoveSpikeball(world, pdata)
    if pdata.spikeTileX then
        local tile = world:getTile(pdata.spikeTileX, pdata.spikeTileY)
        if tile and tile:getTileForeground() == BB_SPIKEBALL_ID then
            world:setTileForeground(tile, 0)
        end
        pdata.spikeTileX    = nil
        pdata.spikeTileY    = nil
        pdata.spikePlacedAt = 0
    end
end

local function bbCleanupSpikeballs(world, room)
    for _, pdata in pairs(room.activePlayers) do
        bbRemoveSpikeball(world, pdata)
    end
end

local function bbStartGame(world, room)
    room.gameSession = room.gameSession + 1

    local startList = {}
    for _, e in ipairs(room.queue) do
        local p = Shared.getPlayerInWorld(world, e.uid)
        if p then table.insert(startList, {uid = e.uid, player = p}) end
    end

    if #startList < BB_MIN_PLAYERS then
        room.queue = {}
        for _, e in ipairs(startList) do
            table.insert(room.queue, {uid = e.uid, name = e.player:getName()})
            e.player:onConsoleMessage("`4Not enough players online. Still in queue — waiting for more...")
        end
        return
    end

    room.queue = {}
    bbScanSpawnZones(world, room)

    room.gameActive    = true
    room.activePlayers = {}
    room.gameEndAt     = os.time() + BB_TIMER

    for _, entry in ipairs(startList) do
        local pos = (math.random(1, 2) == 1) and room.posIngame or room.posIngame2
        room.activePlayers[entry.uid] = {
            name          = entry.player:getName(),
            noDeathUntil  = os.time() + 1,
            pendingExit   = false,
            spikeTileX    = nil,
            spikeTileY    = nil,
            spikePlacedAt = 0,
        }
        world:setPlayerPosition(entry.player, (pos.x - 1) * 32, (pos.y - 1) * 32)
        entry.player:sendVariant({"OnCountdownStart", BB_TIMER, -1}, 0, entry.player:getNetID())
        entry.player:onConsoleMessage("`2GO! Punch empty tiles to place spikeballs. Last one standing wins!")
    end
end

local function bbEndGame(world, room, winnerUID)
    bbCleanupSpikeballs(world, room)

    local notified = {}
    if winnerUID then
        local wp = Shared.getPlayerInWorld(world, winnerUID)
        if wp then
            local prize = Shared.getRandPrize(room.name)
            local item  = getItem(prize.itemID)
            local iname = item and item:getName() or ("Item#" .. prize.itemID)
            wp:sendVariant({"OnCountdownStart", 0, -1}, 0, wp:getNetID())
            Shared.bubble(world, wp, "`2Last one standing! You win a `w" .. iname .. "`2!")
            wp:changeItem(prize.itemID, prize.amount, 1)
            world:setPlayerPosition(wp, (room.posExit.x - 1) * 32, (room.posExit.y - 1) * 32)
            notified[winnerUID] = true
        end
    end

    for uid in pairs(room.activePlayers) do
        if not notified[uid] then
            local p = Shared.getPlayerInWorld(world, uid)
            if p then
                p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                if not winnerUID then
                    p:onConsoleMessage("`7Time's up! No winner this round.")
                end
                world:setPlayerPosition(p, (room.posExit.x - 1) * 32, (room.posExit.y - 1) * 32)
            end
        end
    end

    room.activePlayers = {}
    room.gameActive    = false
    room.gameEndAt     = nil
    room.spawnZones    = {}
    room.spawnZoneSet  = {}
    bbScheduleNext(room)
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    if world then bbCleanupSpikeballs(world, BB_ROOM) end
    BB_ROOM.queue         = {}
    BB_ROOM.activePlayers = {}
    BB_ROOM.reanchorList  = {}
    BB_ROOM.spawnZones    = {}
    BB_ROOM.spawnZoneSet  = {}
    BB_ROOM.gameActive    = false
    BB_ROOM.countdownAt   = nil
    BB_ROOM.gameEndAt     = nil
    BB_ROOM.gameSession   = BB_ROOM.gameSession + 1
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local bbSnapTick = 0

onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now  = os.time()
    local room = BB_ROOM

    -- Process reanchor list
    for i = #room.reanchorList, 1, -1 do
        local e = room.reanchorList[i]
        if now >= e.tickAt then
            local p = Shared.getPlayerInWorld(world, e.uid)
            if p then world:setPlayerPosition(p, (e.pos.x - 1) * 32, (e.pos.y - 1) * 32) end
            table.remove(room.reanchorList, i)
        end
    end

    -- Countdown → start game
    if not room.gameActive and room.countdownAt and now >= room.countdownAt then
        room.countdownAt = nil
        bbStartGame(world, room)
        return
    end

    if room.gameActive then
        -- Expire spikeballs
        for _, pdata in pairs(room.activePlayers) do
            if pdata.spikeTileX and pdata.spikePlacedAt > 0 and
               now >= pdata.spikePlacedAt + BB_SPIKE_DURATION then
                bbRemoveSpikeball(world, pdata)
            end
        end

        -- Game timer end
        if room.gameEndAt and now >= room.gameEndAt then
            room.gameEndAt = nil
            local count, lastUID = 0, nil
            for uid in pairs(room.activePlayers) do count = count + 1; lastUID = uid end
            bbEndGame(world, room, count == 1 and lastUID or nil)
            return
        end

        -- Death detection
        local ga      = room.gameArea
        local deadIDs = {}
        for uid, pdata in pairs(room.activePlayers) do
            local p = Shared.getPlayerInWorld(world, uid)
            if not p then
                bbRemoveSpikeball(world, pdata)
                table.insert(deadIDs, uid)
            elseif pdata.pendingExit then
                local px, py = p:getPosX(), p:getPosY()
                local outside = px < (ga.x1 - 1) * 32 or px > ga.x2 * 32 or
                                 py < (ga.y1 - 1) * 32 or py > ga.y2 * 32
                if outside then
                    p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                    world:setPlayerPosition(p, (room.posExit.x - 1) * 32, (room.posExit.y - 1) * 32)
                    Shared.bubble(world, p, "`4You got spiked! Better luck next time!")
                    bbRemoveSpikeball(world, pdata)
                    table.insert(deadIDs, uid)
                end
            else
                local px, py = p:getPosX(), p:getPosY()
                if px < (ga.x1 - 1) * 32 or px > ga.x2 * 32 or
                   py < (ga.y1 - 1) * 32 or py > ga.y2 * 32 then
                    if now >= (pdata.noDeathUntil or 0) then
                        p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                        world:setPlayerPosition(p, (room.posExit.x - 1) * 32, (room.posExit.y - 1) * 32)
                        Shared.bubble(world, p, "`4You left the arena!")
                        bbRemoveSpikeball(world, pdata)
                        table.insert(deadIDs, uid)
                    end
                end
            end
        end

        for _, uid in ipairs(deadIDs) do
            room.activePlayers[uid] = nil
        end

        -- Auto-win or all-dead check
        local count, lastUID = 0, nil
        for uid in pairs(room.activePlayers) do count = count + 1; lastUID = uid end
        if count == 1 then
            room.gameEndAt = nil
            bbEndGame(world, room, lastUID)
            return
        elseif count == 0 then
            room.gameEndAt    = nil
            room.gameActive   = false
            room.spawnZones   = {}
            room.spawnZoneSet = {}
            bbScheduleNext(room)
            return
        end
    end

    -- Eject non-active players from game area (~1s / 10 ticks)
    -- Note: uses ga.x1*32 (not ga.x1-1) to exclude leftmost column (tent entrance)
    bbSnapTick = bbSnapTick + 1
    if bbSnapTick >= 10 then
        bbSnapTick = 0
        local ga = room.gameArea
        for _, p in ipairs(world:getPlayers()) do
            local uid = p:getUserID()
            if not room.activePlayers[uid] then
                local px, py = p:getPosX(), p:getPosY()
                if px >= ga.x1 * 32 and px <= ga.x2 * 32 and
                   py >= (ga.y1 - 1) * 32 and py <= ga.y2 * 32 then
                    world:setPlayerPosition(p, (room.posExit.x - 1) * 32, (room.posExit.y - 1) * 32)
                    p:onConsoleMessage("`4Game area is restricted to active players only!")
                end
            end
        end
    end
end)

onTilePunchCallback(function(world, avatar, tile)
    if world:getName() ~= WORLD then return false end
    local room = BB_ROOM
    if not room.gameActive then return false end

    local ga = room.gameArea
    local tx = math.floor(tile:getPosX() / 32)
    local ty = math.floor(tile:getPosY() / 32)

    if tx < ga.x1 - 1 or tx > ga.x2 - 1 or
       ty < ga.y1 - 1 or ty > ga.y2 - 1 then
        return false
    end

    local fg = tile:getTileForeground() or 0

    -- Block breaking any foreground in game area
    if fg ~= 0 then return true end

    local uid   = avatar:getUserID()
    local pdata = room.activePlayers[uid]
    if not pdata then return true end

    if not room.spawnZoneSet[tx .. "," .. ty] then return true end

    local now = os.time()
    if pdata.spikePlacedAt > 0 and now < pdata.spikePlacedAt + BB_SPIKE_DURATION then
        return true
    end

    -- Remove old spikeball if still placed
    if pdata.spikeTileX then
        local oldTile = world:getTile(pdata.spikeTileX, pdata.spikeTileY)
        if oldTile and oldTile:getTileForeground() == BB_SPIKEBALL_ID then
            world:setTileForeground(oldTile, 0)
        end
    end

    world:setTileForeground(tile, BB_SPIKEBALL_ID)
    pdata.spikeTileX    = tx
    pdata.spikeTileY    = ty
    pdata.spikePlacedAt = now

    return true
end)

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()
    local room   = BB_ROOM

    if doorUp == room.doorExit then
        return false
    end

    if doorUp == room.doorIngame1 or doorUp == room.doorIngame2 then
        if room.activePlayers[uid] then
            table.insert(room.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = room.posIngame})
        end
        return false
    end

    if doorUp == room.doorEntrance then
        if room.activePlayers[uid] then
            player:onConsoleMessage("`4You are currently in the game!")
            table.insert(room.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = room.posIngame})
            return false
        end

        local gType, gRoom = Shared.getPlayerActiveGame(uid)
        if gType and gType ~= "bb" then
            player:onConsoleMessage("`4You're already playing another minigame!")
            if gRoom and gRoom.posIngame then
                if gRoom.reanchorList then
                    table.insert(gRoom.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = gRoom.posIngame})
                else
                    gRoom.reanchorUID    = uid
                    gRoom.reanchorTickAt = os.time() + 1
                    gRoom.reanchorPos    = {x = gRoom.posIngame.x, y = gRoom.posIngame.y}
                end
            end
            return false
        end

        for _, e in ipairs(room.queue) do
            if e.uid == uid then
                player:onConsoleMessage("`7You are already in queue.")
                table.insert(room.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = room.posWait})
                return false
            end
        end

        local activeCount = 0
        for _ in pairs(room.activePlayers) do activeCount = activeCount + 1 end
        if #room.queue >= BB_MAX_PLAYERS or activeCount >= BB_MAX_PLAYERS then
            player:onConsoleMessage("`4This game is full! (max " .. BB_MAX_PLAYERS .. " players)")
            return false
        end

        if player:getItemAmount(TICKET_ID) < 1 then
            Shared.bubble(world, player, "`4No Golden Ticket!")
            player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Brutal Bounce!")
            return false
        end

        player:changeItem(TICKET_ID, -1, 0)
        table.insert(room.queue, {uid = uid, name = player:getName()})
        table.insert(room.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = room.posWait})

        if not room.gameActive then
            if #room.queue >= BB_MIN_PLAYERS then
                room.countdownAt = os.time() + BB_COUNTDOWN
                for _, e in ipairs(room.queue) do
                    local qp = Shared.getPlayerInWorld(world, e.uid)
                    if qp then
                        if #room.queue == BB_MIN_PLAYERS then
                            qp:onConsoleMessage("`22 players ready! Brutal Bounce starting in `w" .. BB_COUNTDOWN .. "s`2!")
                        else
                            qp:onConsoleMessage("`oNew player! " .. #room.queue .. " in queue — countdown reset to `w" .. BB_COUNTDOWN .. "s`o!")
                        end
                    end
                end
            else
                player:onConsoleMessage("`oWaiting for more players... (" .. #room.queue .. "/" .. BB_MIN_PLAYERS .. " needed to start)")
            end
        else
            player:onConsoleMessage("`oGame in progress. You are `w#" .. #room.queue .. "`o in queue — up next!")
        end

        return false
    end

    return false
end)

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid  = player:getUserID()
    local room = BB_ROOM

    for i = #room.reanchorList, 1, -1 do
        if room.reanchorList[i].uid == uid then table.remove(room.reanchorList, i) end
    end

    for i = #room.queue, 1, -1 do
        if room.queue[i].uid == uid then table.remove(room.queue, i) end
    end
    if room.countdownAt and #room.queue < BB_MIN_PLAYERS and not room.gameActive then
        room.countdownAt = nil
        for _, e in ipairs(room.queue) do
            local qp = Shared.getPlayerInWorld(world, e.uid)
            if qp then qp:onConsoleMessage("`4Not enough players — countdown cancelled.") end
        end
    end

    if room.activePlayers[uid] then
        local pdata = room.activePlayers[uid]
        bbRemoveSpikeball(world, pdata)
        room.activePlayers[uid] = nil

        if room.gameActive then
            local count, lastUID = 0, nil
            for uid2 in pairs(room.activePlayers) do count = count + 1; lastUID = uid2 end
            if count == 0 then
                room.gameEndAt    = nil
                room.gameActive   = false
                room.spawnZones   = {}
                room.spawnZoneSet = {}
                bbScheduleNext(room)
            elseif count == 1 then
                room.gameEndAt = nil
                bbEndGame(world, room, lastUID)
            else
                for ouid in pairs(room.activePlayers) do
                    local op = Shared.getPlayerInWorld(world, ouid)
                    if op then
                        op:onConsoleMessage("`7A player left. " .. count .. " player(s) remaining!")
                    end
                end
            end
        end
    end
end)

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid  = player:getUserID()
    local room = BB_ROOM

    if room.activePlayers[uid] then
        room.activePlayers[uid].pendingExit = true
    end
    for i = #room.queue, 1, -1 do
        if room.queue[i].uid == uid then table.remove(room.queue, i) end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("bb", function() return {BB_ROOM} end, true, resetAll)

return M
