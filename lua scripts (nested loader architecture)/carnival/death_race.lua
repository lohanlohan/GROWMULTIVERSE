-- MODULE
-- death_race.lua — Death Race 5000 minigame (1 room, multiplayer)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER  = Shared.WORLD_UPPER
local WORLD        = Shared.WORLD
local TICKET_ID    = Shared.TICKET_ID
local WIN_PARTICLE = Shared.WIN_PARTICLE

-- ── Constants ─────────────────────────────────────────────────────────────────

local DR_SPIKE_ID    = 162
local DR_LAVA_ID     = 4
local DR_DURATION    = 90
local DR_COUNTDOWN   = 5
local DR_MIN_PLAYERS = 2
local DR_EXIT_DELAY  = 5

-- ── Room config ───────────────────────────────────────────────────────────────

local DR_ROOMS = {}

DR_ROOMS[1] = {
    name         = "Death Race 5000",
    doorEntrance = "DEATH01",
    doorExit     = "DEATH04",
    posTent      = {x=34, y=14},
    posWait      = {x=34, y=16},
    posIngame    = {x=34, y=16},
    posCP1       = {x=32, y=16},
    posCP2       = {x=4,  y=12},
    posFinish    = {x=32, y=12},
    posExit      = {x=36, y=17},
    gameArea     = {
        xMin = (2-1)*32,
        xMax = (33-1)*32,
        yMin = (9-1)*32,
        yMax = (17-1)*32,
    },
    queue           = {},
    activePlayers   = {},
    gameActive      = false,
    gameSession     = 0,
    countdownTickAt = nil,
    gameTimer       = nil,
    exitTickAt      = nil,
    obstacles       = {},
    winner          = nil,
    reanchorList    = {},
}

-- ── Obstacle helpers ──────────────────────────────────────────────────────────

local function drClearObstacles(world, room)
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

local function drPlaceObstacles(world, room)
    local function genFloor(yFloor)
        local prevFilled = false
        for sx = 6, 30, 2 do
            if prevFilled and math.random(10) <= 6 then
                prevFilled = false
            else
                prevFilled = false
                local r = math.random(12)
                if r <= 3 then
                    -- 25% empty
                elseif r <= 5 then
                    table.insert(room.obstacles, {x=sx, y=yFloor, id=DR_SPIKE_ID})
                    prevFilled = true
                elseif r <= 8 then
                    table.insert(room.obstacles, {x=sx, y=yFloor, id=DR_LAVA_ID})
                    prevFilled = true
                else
                    table.insert(room.obstacles, {x=sx, y=yFloor,   id=DR_LAVA_ID})
                    table.insert(room.obstacles, {x=sx, y=yFloor-1, id=DR_LAVA_ID})
                    prevFilled = true
                end
            end
        end
    end

    genFloor(16)
    genFloor(12)

    for _, obs in ipairs(room.obstacles) do
        local tile = world:getTile(obs.x - 1, obs.y - 1)
        if tile then
            world:setTileForeground(tile, obs.id)
            world:updateTile(tile)
        end
    end
end

local function drClearTimers(room)
    if room.gameTimer then timer.clear(room.gameTimer); room.gameTimer = nil end
    room.countdownTickAt = nil
    room.exitTickAt      = nil
end

local function drTeleportToCP(world, player, room, uid)
    local pstate = room.activePlayers[uid]
    if not pstate then return end
    local cpPos = pstate.checkpoint == 2 and room.posCP2 or room.posCP1
    local cpx   = (cpPos.x - 1) * 32
    local cpy   = (cpPos.y - 1) * 32
    world:setPlayerPosition(player, cpx, cpy)
    pstate.noDeathUntil = os.time() + 2
end

local function drEndGame(world, room)
    drClearTimers(room)
    room.gameActive = false
    room.exitTickAt = os.time() + DR_EXIT_DELAY
end

local function drHandleWin(world, player, uid, room)
    if room.winner then return end
    room.winner = uid

    local p        = Shared.getRandPrize(room.name)
    local item     = getItem(p.itemID)
    local itemName = item and item:getName() or ("Item#" .. p.itemID)

    Shared.bubble(world, player, "`6FINISH! " .. player:getName() .. " wins!")
    player:onConsoleMessage("`61st place! `wPrize: " .. p.amount .. "x " .. itemName)
    player:changeItem(p.itemID, p.amount, 0)
    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())
    local tx = math.floor(player:getPosX() / 32)
    local ty = math.floor(player:getPosY() / 32)
    player:sendVariant({"OnParticleEffect", WIN_PARTICLE, tx, ty}, 0, player:getNetID())

    for ouid in pairs(room.activePlayers) do
        if ouid ~= uid then
            local op = Shared.getPlayerInWorld(world, ouid)
            if op then
                Shared.bubble(world, op, "`4" .. player:getName() .. " wins the race!")
                op:onConsoleMessage("`4" .. player:getName() .. " reached the finish first. Better luck next time!")
                op:sendVariant({"OnCountdownStart", 0, -1}, 0, op:getNetID())
            end
        end
    end

    drEndGame(world, room)
end

local function drHandleTimeout(world, room)
    for uid in pairs(room.activePlayers) do
        local p = Shared.getPlayerInWorld(world, uid)
        if p then
            Shared.bubble(world, p, "`4Time's Up! No winner.")
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

    local startList = {}
    for _, e in ipairs(room.queue) do
        local p = Shared.getPlayerInWorld(world, e.uid)
        if p then
            table.insert(startList, {uid = e.uid, player = p, name = e.name})
        end
    end

    if #startList < DR_MIN_PLAYERS then
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

    room.queue = {}
    for _, entry in ipairs(startList) do
        room.activePlayers[entry.uid] = {
            name         = entry.name,
            checkpoint   = 1,
            noDeathUntil = os.time() + 3,
            finished     = false,
        }
    end

    drClearObstacles(world, room)
    drPlaceObstacles(world, room)

    local cp1x = (room.posCP1.x - 1) * 32
    local cp1y = (room.posCP1.y - 1) * 32
    for _, entry in ipairs(startList) do
        world:setPlayerPosition(entry.player, cp1x, cp1y)
        entry.player:sendVariant({"OnCountdownStart", DR_DURATION, -1}, 0, entry.player:getNetID())
        entry.player:onConsoleMessage("`wGO! `7Race to the finish — `w" .. DR_DURATION .. "s`7 on the clock!")
    end

    room.gameTimer = timer.setTimeout(DR_DURATION, function()
        room.gameTimer = nil
        if room.gameSession ~= session then return end
        local w = Shared.getCarnivalWorld()
        if w then drHandleTimeout(w, room) end
    end)

    if DR_DURATION > 30 then
        timer.setTimeout(DR_DURATION - 30, function()
            if room.gameSession ~= session or not room.gameActive then return end
            local w = Shared.getCarnivalWorld()
            if not w then return end
            for uid in pairs(room.activePlayers) do
                local p = Shared.getPlayerInWorld(w, uid)
                if p then p:onConsoleMessage("`630 seconds remaining!") end
            end
        end)
    end
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    for _, room in ipairs(DR_ROOMS) do
        drClearTimers(room)
        room.queue         = {}
        room.activePlayers = {}
        room.gameActive    = false
        room.winner        = nil
        room.reanchorList  = {}
        room.gameSession   = room.gameSession + 1
        if world then drClearObstacles(world, room) end
    end
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local drSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(DR_ROOMS) do
        if room.countdownTickAt and now >= room.countdownTickAt and not room.gameActive then
            room.countdownTickAt = nil
            if #room.queue >= DR_MIN_PLAYERS then
                drStartGame(world, room)
            end
        end

        if not room.gameActive and not room.exitTickAt and not room.countdownTickAt then
            if #room.queue >= DR_MIN_PLAYERS then
                room.countdownTickAt = now + DR_COUNTDOWN
                for _, e in ipairs(room.queue) do
                    local qp = Shared.getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`2Race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                    end
                end
            end
        end

        for i = #room.reanchorList, 1, -1 do
            local ra = room.reanchorList[i]
            if now >= ra.tickAt then
                table.remove(room.reanchorList, i)
                local rp = Shared.getPlayerInWorld(world, ra.uid)
                if rp then
                    world:setPlayerPosition(rp, (ra.pos.x-1)*32, (ra.pos.y-1)*32)
                end
            end
        end

        if room.exitTickAt and now >= room.exitTickAt then
            room.exitTickAt = nil
            local ex_px = (room.posExit.x - 1) * 32
            local ex_py = (room.posExit.y - 1) * 32
            for uid in pairs(room.activePlayers) do
                local p = Shared.getPlayerInWorld(world, uid)
                if p then
                    p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                    world:setPlayerPosition(p, ex_px, ex_py)
                end
            end
            room.activePlayers = {}
            room.winner        = nil
            if #room.queue >= DR_MIN_PLAYERS and not room.countdownTickAt then
                room.countdownTickAt = now + DR_COUNTDOWN
                for _, e in ipairs(room.queue) do
                    local qp = Shared.getPlayerInWorld(world, e.uid)
                    if qp then
                        qp:onConsoleMessage("`2Next race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                    end
                end
            end
        end

        if room.gameActive then
            local toRemove = {}
            for uid, pstate in pairs(room.activePlayers) do
                local p = Shared.getPlayerInWorld(world, uid)
                if not p then
                    toRemove[uid] = true
                else
                    local px = p:getPosX()
                    local py = p:getPosY()
                    local tx = math.floor(px / 32) + 1
                    local ty = math.floor(py / 32) + 1

                    if not pstate.finished then
                        if tx == room.posFinish.x and ty >= room.posFinish.y - 1 and ty <= room.posFinish.y + 1 then
                            pstate.finished = true
                            drHandleWin(world, p, uid, room)
                        end
                    end

                    if not pstate.finished and pstate.checkpoint < 2 then
                        if tx <= room.posCP2.x + 1 and ty >= room.posCP2.y - 1 and ty <= room.posCP2.y + 1 then
                            pstate.checkpoint = 2
                            p:onConsoleMessage("`2Checkpoint 2 reached! You will respawn here from now on.")
                        end
                    end

                    if room.gameActive and not pstate.finished and now >= (pstate.noDeathUntil or 0) then
                        local ga = room.gameArea
                        if px < ga.xMin or px > ga.xMax or py < ga.yMin or py > ga.yMax then
                            drTeleportToCP(world, p, room, uid)
                        end
                    end
                end
            end

            for uid in pairs(toRemove) do
                room.activePlayers[uid] = nil
            end

            if room.gameActive and not room.exitTickAt then
                local remaining = 0
                for _, ps in pairs(room.activePlayers) do
                    if not ps.finished then remaining = remaining + 1 end
                end
                if remaining == 0 then drEndGame(world, room) end
            end
        end
    end

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

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()

    for _, room in ipairs(DR_ROOMS) do
        if doorUp == room.doorExit then
            return false
        end

        if doorUp == room.doorEntrance then
            if room.activePlayers[uid] then
                player:onConsoleMessage("`4You are currently in the race!")
                local pstate = room.activePlayers[uid]
                local cpPos  = pstate.checkpoint == 2 and room.posCP2 or room.posCP1
                table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=cpPos})
                return false
            end

            local gType, gRoom = Shared.getPlayerActiveGame(uid)
            if gType and gType ~= "dr" then
                player:onConsoleMessage("`4You're already playing another minigame!")
                if gRoom and gRoom.posIngame then
                    if gRoom.reanchorList then
                        table.insert(gRoom.reanchorList, {uid=uid, tickAt=os.time()+1, pos=gRoom.posIngame})
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
                    table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=room.posWait})
                    return false
                end
            end

            if player:getItemAmount(TICKET_ID) < 1 then
                Shared.bubble(world, player, "`4No Golden Ticket!")
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to join Death Race 5000!")
                return false
            end

            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})
            table.insert(room.reanchorList, {uid=uid, tickAt=os.time()+1, pos=room.posWait})

            if not room.gameActive and not room.exitTickAt then
                if #room.queue >= DR_MIN_PLAYERS and not room.countdownTickAt then
                    room.countdownTickAt = os.time() + DR_COUNTDOWN
                    for _, e in ipairs(room.queue) do
                        local qp = Shared.getPlayerInWorld(world, e.uid)
                        if qp then
                            qp:onConsoleMessage("`2Race starting in `w" .. DR_COUNTDOWN .. "s`2! Get ready!")
                        end
                    end
                else
                    local needed = DR_MIN_PLAYERS - #room.queue
                    if needed > 0 then
                        player:onConsoleMessage("`oWaiting for `w" .. needed .. " more player" .. (needed > 1 and "s" or "") .. "`o to start the race...")
                    elseif room.countdownTickAt then
                        room.countdownTickAt = os.time() + DR_COUNTDOWN
                        for _, e in ipairs(room.queue) do
                            local qp = Shared.getPlayerInWorld(world, e.uid)
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

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid = player:getUserID()

    for _, room in ipairs(DR_ROOMS) do
        for i = #room.reanchorList, 1, -1 do
            if room.reanchorList[i].uid == uid then
                table.remove(room.reanchorList, i)
            end
        end

        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end

        if room.countdownTickAt and #room.queue < DR_MIN_PLAYERS then
            room.countdownTickAt = nil
            for _, e in ipairs(room.queue) do
                local qp = Shared.getPlayerInWorld(world, e.uid)
                if qp then
                    qp:onConsoleMessage("`4Not enough players — countdown cancelled. Waiting for more racers.")
                end
            end
        end

        if room.activePlayers[uid] then
            room.activePlayers[uid] = nil

            if room.gameActive and not room.exitTickAt then
                local remaining = 0
                for _, ps in pairs(room.activePlayers) do
                    if not ps.finished then remaining = remaining + 1 end
                end

                if remaining == 0 then
                    drClearTimers(room)
                    room.gameActive = false
                    if #room.queue >= DR_MIN_PLAYERS then
                        room.countdownTickAt = os.time() + DR_COUNTDOWN
                        for _, e in ipairs(room.queue) do
                            local qp = Shared.getPlayerInWorld(world, e.uid)
                            if qp then
                                qp:onConsoleMessage("`7All racers left. New race starting in `w" .. DR_COUNTDOWN .. "s`7...")
                            end
                        end
                    end
                else
                    for ouid in pairs(room.activePlayers) do
                        local op = Shared.getPlayerInWorld(world, ouid)
                        if op then
                            op:onConsoleMessage("`7A racer disconnected. Race continues!")
                        end
                    end
                end
            end
        end
    end
end)

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid = player:getUserID()
    for _, room in ipairs(DR_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
        if room.countdownTickAt and #room.queue < DR_MIN_PLAYERS then
            room.countdownTickAt = nil
            for _, e in ipairs(room.queue) do
                local qp = Shared.getPlayerInWorld(world, e.uid)
                if qp then qp:onConsoleMessage("`4Not enough players — countdown cancelled.") end
            end
        end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("dr", function() return DR_ROOMS end, true, resetAll)

return M
