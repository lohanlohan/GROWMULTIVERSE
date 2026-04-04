-- MODULE
-- growganoth_gulch.lua — Growganoth Gulch minigame (2 rooms, solo climb)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER     = Shared.WORLD_UPPER
local WORLD           = Shared.WORLD
local TICKET_ID       = Shared.TICKET_ID
local QUEUE_DELAY     = Shared.QUEUE_DELAY
local TILE_FLAG_IS_ON = Shared.TILE_FLAG_IS_ON

-- ── Constants ─────────────────────────────────────────────────────────────────

local GG_TIMER              = 40
local GG_PLATFORM_INTERVAL  = 5
local GG_EYE_INTERVAL       = 5
local GG_PLATFORM_FLIP_CHANCE = 0.55
local GG_EYE_FLIP_CHANCE      = 0.60
local GG_DISABLED_ID          = 1224
local GG_CREEPSTONE_ID        = 1222

-- ── Room config ───────────────────────────────────────────────────────────────

local GG_ROOMS = {
    {
        name         = "Growganoth Gulch",
        doorEntrance = "GLUCH01",
        doorIngame   = "GLUCH02",
        posTent      = {x=93, y=38},
        posWait      = {x=93, y=40},
        posIngame    = {x=97, y=54},
        posEndgame   = {x=97, y=24},
        posExit      = {x=91, y=40},
        gameArea     = {x1=95, y1=23, x2=99, y2=54},
        disabledPlatforms = {
            {95,33},{96,35},{96,40},{96,41},{96,46},{97,35},{97,39},{98,26},
            {98,35},{98,38},{98,45},{98,48},{98,53},{99,34},{99,41},{99,49},
        },
        evilEyes = {
            {95,30},{95,36},{95,44},{96,27},{96,36},{97,36},{97,51},{98,32},
            {98,36},{98,39},{99,28},{99,36},{99,42},{99,52},
        },
    },
    {
        name         = "Growganoth Gulch",
        doorEntrance = "GLUCH04",
        doorIngame   = "GLUCH05",
        posTent      = {x=8, y=38},
        posWait      = {x=8, y=40},
        posIngame    = {x=4, y=54},
        posEndgame   = {x=4, y=24},
        posExit      = {x=10, y=40},
        gameArea     = {x1=2, y1=23, x2=6, y2=54},
        disabledPlatforms = {
            {2,26},{2,39},{3,29},{3,42},{3,44},{3,52},{4,33},{4,49},
            {5,25},{5,29},{5,35},{5,39},{5,42},{6,30},{6,43},
        },
        evilEyes = {
            {2,25},{2,29},{2,36},{2,45},{2,50},{3,36},{3,39},{4,36},
            {4,42},{5,27},{5,32},{5,36},{5,53},{6,36},{6,44},{6,49},
        },
    },
}

for _, room in ipairs(GG_ROOMS) do
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
    room.obstacleNextAt  = nil
    room.eyeNextAt       = nil
    room.platformState   = {}
    room.eyeState        = {}
    for i = 1, #room.disabledPlatforms do
        room.platformState[i] = GG_DISABLED_ID
    end
    for i = 1, #room.evilEyes do
        room.eyeState[i] = false
    end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ggClearTimers(room)
    if room.gameTimer then timer.clear(room.gameTimer); room.gameTimer = nil end
end

local function ggResetObstacles(world, room)
    if not world then return end
    for i, coord in ipairs(room.disabledPlatforms) do
        local tile = world:getTile(coord[1]-1, coord[2]-1)
        if tile then world:setTileForeground(tile, GG_DISABLED_ID) end
        room.platformState[i] = GG_DISABLED_ID
    end
    for i, coord in ipairs(room.evilEyes) do
        local tile = world:getTile(coord[1]-1, coord[2]-1)
        if tile then
            local flags = bit.band(tile:getFlags(), bit.bnot(TILE_FLAG_IS_ON))
            tile:setFlags(flags)
            world:updateTile(tile)
        end
        room.eyeState[i] = false
    end
end

local function ggRandomizeStart(world, room)
    if not world then return end

    for i, coord in ipairs(room.disabledPlatforms) do
        local id = (math.random() < 0.35) and GG_CREEPSTONE_ID or GG_DISABLED_ID
        local tile = world:getTile(coord[1]-1, coord[2]-1)
        if tile then world:setTileForeground(tile, id) end
        room.platformState[i] = id
    end

    local sorted = {}
    for i, coord in ipairs(room.disabledPlatforms) do
        table.insert(sorted, {idx=i, y=coord[2]})
    end
    table.sort(sorted, function(a, b) return a.y > b.y end)

    local BAND = 6
    local i = 1
    while i <= #sorted do
        local bandTop = sorted[i].y - BAND
        local hasSolid = false
        local first = nil
        local j = i
        while j <= #sorted and sorted[j].y >= bandTop do
            if room.platformState[sorted[j].idx] == GG_CREEPSTONE_ID then
                hasSolid = true
            end
            if not first then first = sorted[j] end
            j = j + 1
        end
        if not hasSolid and first then
            local coord = room.disabledPlatforms[first.idx]
            local tile = world:getTile(coord[1]-1, coord[2]-1)
            if tile then world:setTileForeground(tile, GG_CREEPSTONE_ID) end
            room.platformState[first.idx] = GG_CREEPSTONE_ID
        end
        i = j
    end

    for i, coord in ipairs(room.evilEyes) do
        local isOpen = math.random() < 0.65
        local tile = world:getTile(coord[1]-1, coord[2]-1)
        if tile then
            local flags = tile:getFlags()
            if isOpen then
                flags = bit.bor(flags, TILE_FLAG_IS_ON)
            else
                flags = bit.band(flags, bit.bnot(TILE_FLAG_IS_ON))
            end
            tile:setFlags(flags)
            world:updateTile(tile)
        end
        room.eyeState[i] = isOpen
    end
end

local function ggTogglePlatforms(world, room)
    if not world then return end
    for i, coord in ipairs(room.disabledPlatforms) do
        if math.random() < GG_PLATFORM_FLIP_CHANCE then
            local tile = world:getTile(coord[1]-1, coord[2]-1)
            if tile then
                local cur = room.platformState[i] or GG_DISABLED_ID
                local nxt = (cur == GG_DISABLED_ID) and GG_CREEPSTONE_ID or GG_DISABLED_ID
                world:setTileForeground(tile, nxt)
                room.platformState[i] = nxt
            end
        end
    end
end

local function ggToggleEyes(world, room)
    if not world then return end
    for i, coord in ipairs(room.evilEyes) do
        if math.random() < GG_EYE_FLIP_CHANCE then
            local tile = world:getTile(coord[1]-1, coord[2]-1)
            if tile then
                local isOpen = room.eyeState[i]
                local flags  = tile:getFlags()
                if isOpen then
                    flags = bit.band(flags, bit.bnot(TILE_FLAG_IS_ON))
                else
                    flags = bit.bor(flags, TILE_FLAG_IS_ON)
                end
                tile:setFlags(flags)
                world:updateTile(tile)
                room.eyeState[i] = not isOpen
            end
        end
    end
end

local function ggScheduleNext(room)
    if #room.queue > 0 then
        room.nextQueueTickAt = os.time() + QUEUE_DELAY
    end
end

local function ggStartGame(world, room)
    if room.activeUID then return end
    while #room.queue > 0 do
        local entry = table.remove(room.queue, 1)
        local p = Shared.getPlayerInWorld(world, entry.uid)
        if p then
            room.activeUID      = entry.uid
            room.gameSession    = room.gameSession + 1
            local session       = room.gameSession
            room.obstacleNextAt = os.time() + GG_PLATFORM_INTERVAL
            room.eyeNextAt      = os.time() + GG_EYE_INTERVAL
            world:setPlayerPosition(p, (room.posIngame.x-1)*32, (room.posIngame.y-1)*32)
            ggRandomizeStart(world, room)
            p:sendVariant({"OnCountdownStart", GG_TIMER, -1}, 0, p:getNetID())
            p:onConsoleMessage("`6GO! Climb to the top in `w" .. GG_TIMER .. " seconds`6!")
            room.gameTimer = timer.setTimeout(GG_TIMER, function()
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
                ggResetObstacles(w2, room)
            end)
            return
        end
    end
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    for _, room in ipairs(GG_ROOMS) do
        ggClearTimers(room)
        room.queue           = {}
        room.activeUID       = nil
        room.exitUID         = nil
        room.reanchorUID     = nil
        room.reanchorTickAt  = nil
        room.reanchorPos     = nil
        room.exitTickAt      = nil
        room.nextQueueTickAt = nil
        room.obstacleNextAt  = nil
        room.eyeNextAt       = nil
        room.gameSession     = room.gameSession + 1
        if world then ggResetObstacles(world, room) end
    end
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local ggSnapTick = 0
onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now = os.time()

    for _, room in ipairs(GG_ROOMS) do
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
            ggScheduleNext(room)
        end

        if room.nextQueueTickAt and now >= room.nextQueueTickAt then
            room.nextQueueTickAt = nil
            ggStartGame(world, room)
        end

        if room.activeUID then
            local ap = Shared.getPlayerInWorld(world, room.activeUID)

            if room.obstacleNextAt and now >= room.obstacleNextAt then
                room.obstacleNextAt = now + GG_PLATFORM_INTERVAL
                ggTogglePlatforms(world, room)
            end

            if room.eyeNextAt and now >= room.eyeNextAt then
                room.eyeNextAt = now + GG_EYE_INTERVAL
                ggToggleEyes(world, room)
            end

            if ap then
                local px, py = ap:getPosX(), ap:getPosY()
                local ga = room.gameArea

                if px < (ga.x1-1)*32 or px > ga.x2*32 or
                   py < (ga.y1-1)*32 or py > ga.y2*32 then
                    world:setPlayerPosition(ap, (room.posIngame.x-1)*32, (room.posIngame.y-1)*32)
                else
                    local ex = (room.posEndgame.x - 1) * 32
                    local ey = (room.posEndgame.y - 1) * 32
                    if math.abs(px - ex) <= 28 and math.abs(py - ey) <= 28 then
                        ggClearTimers(room)
                        local prize = Shared.getRandPrize(room.name)
                        local item  = getItem(prize.itemID)
                        local iname = item and item:getName() or ("Item#" .. prize.itemID)
                        ap:sendVariant({"OnCountdownStart", 0, -1}, 0, ap:getNetID())
                        Shared.bubble(world, ap, "`2You reached the top! You win a `w" .. iname .. "`2!")
                        ap:changeItem(prize.itemID, prize.amount, 1)
                        world:setPlayerPosition(ap, (room.posExit.x-1)*32, (room.posExit.y-1)*32)
                        room.activeUID = nil
                        ggResetObstacles(world, room)
                        ggScheduleNext(room)
                    end
                end
            else
                ggClearTimers(room)
                room.activeUID = nil
                ggResetObstacles(world, room)
                ggScheduleNext(room)
            end
        end
    end

    ggSnapTick = ggSnapTick + 1
    if ggSnapTick >= 10 then
        ggSnapTick = 0
        for _, p in ipairs(world:getPlayers()) do
            local px, py, uid = p:getPosX(), p:getPosY(), p:getUserID()
            for _, room in ipairs(GG_ROOMS) do
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

    for _, room in ipairs(GG_ROOMS) do
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
                player:onConsoleMessage("`4You are currently in the game!")
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
                player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Growganoth Gulch!")
                return false
            end

            player:changeItem(TICKET_ID, -1, 0)
            table.insert(room.queue, {uid = uid, name = player:getName()})
            room.reanchorUID    = uid
            room.reanchorTickAt = os.time() + 1
            room.reanchorPos    = {x = room.posWait.x, y = room.posWait.y}

            if not room.activeUID and #room.queue == 1 then
                player:onConsoleMessage("`2Get ready! Entering in `w" .. QUEUE_DELAY .. " seconds`2...")
                ggScheduleNext(room)
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
    for _, room in ipairs(GG_ROOMS) do
        if uid == room.reanchorUID then
            room.reanchorUID    = nil
            room.reanchorTickAt = nil
            room.reanchorPos    = nil
        end
        if uid == room.activeUID then
            ggClearTimers(room)
            room.activeUID = nil
            ggResetObstacles(world, room)
            for _, e in ipairs(room.queue) do
                local qp = Shared.getPlayerInWorld(world, e.uid)
                if qp then qp:onConsoleMessage("`7Previous player left. Next up in `w" .. QUEUE_DELAY .. "s`7...") end
            end
            ggScheduleNext(room)
        elseif uid == room.exitUID then
            room.exitUID    = nil
            room.exitTickAt = nil
            ggScheduleNext(room)
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
    for _, room in ipairs(GG_ROOMS) do
        for i = #room.queue, 1, -1 do
            if room.queue[i].uid == uid then table.remove(room.queue, i) end
        end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("gg", function() return GG_ROOMS end, false, resetAll)

return M
