-- MODULE
-- spiky_survivor.lua — Spiky Survivor minigame (1 room, multiplayer survival)

local M = {}
local Shared = _G.CarnivalShared

local WORLD_UPPER     = Shared.WORLD_UPPER
local WORLD           = Shared.WORLD
local TICKET_ID       = Shared.TICKET_ID
local QUEUE_DELAY     = Shared.QUEUE_DELAY

-- ── Constants ─────────────────────────────────────────────────────────────────

local SS_TIMER             = 55
local SS_PLATFORM_INTERVAL = 5
local SS_FLIP_CHANCE       = 0.65
local SS_SOLID_ID          = 7180   -- Carnival Creep Platform (solid, has collision)
local SS_PASSABLE_ID       = 7182   -- Disabled Carnival Creep Platform (passable)
local SS_COUNTDOWN         = 5

-- ── Room config ───────────────────────────────────────────────────────────────

local SS_ROOM = {
    name         = "Spiky Survivor",
    doorEntrance = "SPIKE01",
    doorIngame   = "SPIKE02",
    doorExit     = "SPIKE03",
    posWait      = {x = 31, y = 47},
    posIngame    = {x = 22, y = 42},
    posExit      = {x = 35, y = 43},
    gameArea     = {x1 = 17, y1 = 40, x2 = 27, y2 = 48},

    queue          = {},
    activePlayers  = {},   -- [uid] = {name, noDeathUntil, pendingExit}
    reanchorList   = {},
    platformTiles  = {},   -- {tx, ty} 0-indexed world coords
    platformState  = {},   -- mirrors tile foreground to avoid repeated getTileForeground
    gameActive     = false,
    gameSession    = 0,
    countdownAt    = nil,
    platformTickAt = nil,
    gameEndAt      = nil,
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Scan game area for platform tiles; called once at game start
local function ssScanPlatforms(world, room)
    room.platformTiles = {}
    room.platformState = {}
    local ga = room.gameArea
    for tx = ga.x1 - 1, ga.x2 - 1 do
        for ty = ga.y1 - 1, ga.y2 - 1 do
            local tile = world:getTile(tx, ty)
            if tile then
                local fg = tile:getTileForeground()
                if fg == SS_SOLID_ID or fg == SS_PASSABLE_ID then
                    local idx = #room.platformTiles + 1
                    room.platformTiles[idx] = {tx, ty}
                    room.platformState[idx] = fg
                end
            end
        end
    end
end

-- Randomize platforms: 65% solid, 35% passable
local function ssRandomizeStart(world, room)
    if not world then return end
    for i, pos in ipairs(room.platformTiles) do
        local id = (math.random() < 0.65) and SS_SOLID_ID or SS_PASSABLE_ID
        local tile = world:getTile(pos[1], pos[2])
        if tile then world:setTileForeground(tile, id) end
        room.platformState[i] = id
    end
end

-- Reset all platforms to solid
local function ssResetPlatforms(world, room)
    if not world then return end
    for i, pos in ipairs(room.platformTiles) do
        local tile = world:getTile(pos[1], pos[2])
        if tile then world:setTileForeground(tile, SS_SOLID_ID) end
        room.platformState[i] = SS_SOLID_ID
    end
end

-- Randomly flip each platform with SS_FLIP_CHANCE
local function ssTogglePlatforms(world, room)
    if not world then return end
    for i, pos in ipairs(room.platformTiles) do
        if math.random() < SS_FLIP_CHANCE then
            local tile = world:getTile(pos[1], pos[2])
            if tile then
                local cur = room.platformState[i] or SS_SOLID_ID
                local nxt = (cur == SS_SOLID_ID) and SS_PASSABLE_ID or SS_SOLID_ID
                world:setTileForeground(tile, nxt)
                room.platformState[i] = nxt
            end
        end
    end
end

local function ssScheduleNext(room)
    if #room.queue > 0 and not room.gameActive and not room.countdownAt then
        room.countdownAt = os.time() + SS_COUNTDOWN
    end
end

local function ssStartGame(world, room)
    room.gameSession = room.gameSession + 1

    local startList = {}
    for _, e in ipairs(room.queue) do
        local p = Shared.getPlayerInWorld(world, e.uid)
        if p then table.insert(startList, {uid = e.uid, player = p}) end
    end
    room.queue = {}

    if #startList == 0 then
        room.gameActive = false
        ssScheduleNext(room)
        return
    end

    ssScanPlatforms(world, room)
    ssRandomizeStart(world, room)

    room.gameActive     = true
    room.activePlayers  = {}
    room.gameEndAt      = os.time() + SS_TIMER
    room.platformTickAt = os.time() + SS_PLATFORM_INTERVAL

    for _, entry in ipairs(startList) do
        room.activePlayers[entry.uid] = {
            name         = entry.player:getName(),
            noDeathUntil = os.time() + 1,
        }
        world:setPlayerPosition(entry.player,
            (room.posIngame.x - 1) * 32,
            (room.posIngame.y - 1) * 32)
        entry.player:sendVariant({"OnCountdownStart", SS_TIMER, -1}, 0, entry.player:getNetID())
    end
end

local function ssEndGame(world, room)
    local survivors = {}
    for uid, data in pairs(room.activePlayers) do
        local p = Shared.getPlayerInWorld(world, uid)
        if p then table.insert(survivors, {uid = uid, player = p, name = data.name}) end
    end

    room.activePlayers  = {}
    room.gameActive     = false
    room.gameEndAt      = nil
    room.platformTickAt = nil
    ssResetPlatforms(world, room)

    for _, s in ipairs(survivors) do
        local prize = Shared.getRandPrize(room.name)
        local item  = getItem(prize.itemID)
        local iname = item and item:getName() or ("Item#" .. prize.itemID)
        s.player:sendVariant({"OnCountdownStart", 0, -1}, 0, s.player:getNetID())
        Shared.bubble(world, s.player, "`2You survived! You win a `w" .. iname .. "`2!")
        s.player:changeItem(prize.itemID, prize.amount, 1)
        world:setPlayerPosition(s.player,
            (room.posExit.x - 1) * 32,
            (room.posExit.y - 1) * 32)
    end

    ssScheduleNext(room)
end

-- ── Reset ─────────────────────────────────────────────────────────────────────

local function resetAll(world)
    if world then ssResetPlatforms(world, SS_ROOM) end
    SS_ROOM.queue          = {}
    SS_ROOM.activePlayers  = {}
    SS_ROOM.reanchorList   = {}
    SS_ROOM.platformTiles  = {}
    SS_ROOM.platformState  = {}
    SS_ROOM.gameActive     = false
    SS_ROOM.countdownAt    = nil
    SS_ROOM.platformTickAt = nil
    SS_ROOM.gameEndAt      = nil
    SS_ROOM.gameSession    = SS_ROOM.gameSession + 1
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

local ssSnapTick = 0

onWorldTick(function(world)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local now  = os.time()
    local room = SS_ROOM

    -- Process reanchor list
    for i = #room.reanchorList, 1, -1 do
        local e = room.reanchorList[i]
        if now >= e.tickAt then
            local p = Shared.getPlayerInWorld(world, e.uid)
            if p then
                world:setPlayerPosition(p, (e.pos.x - 1) * 32, (e.pos.y - 1) * 32)
            end
            table.remove(room.reanchorList, i)
        end
    end

    -- Countdown → start game
    if not room.gameActive and room.countdownAt and now >= room.countdownAt then
        room.countdownAt = nil
        ssStartGame(world, room)
        return
    end

    if room.gameActive then
        -- Platform toggle
        if room.platformTickAt and now >= room.platformTickAt then
            ssTogglePlatforms(world, room)
            room.platformTickAt = now + SS_PLATFORM_INTERVAL
        end

        -- Game end timer
        if room.gameEndAt and now >= room.gameEndAt then
            room.gameEndAt = nil
            ssEndGame(world, room)
            return
        end

        -- Death detection
        local ga     = room.gameArea
        local deadIDs = {}
        for uid, pdata in pairs(room.activePlayers) do
            local p = Shared.getPlayerInWorld(world, uid)
            if not p then
                table.insert(deadIDs, uid)
            elseif pdata.pendingExit then
                -- HP death: wait for native respawn to move player outside game area
                local px, py = p:getPosX(), p:getPosY()
                local outside = px < (ga.x1 - 1) * 32 or px > ga.x2 * 32 or
                                 py < (ga.y1 - 1) * 32 or py > ga.y2 * 32
                if outside then
                    p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                    world:setPlayerPosition(p,
                        (room.posExit.x - 1) * 32,
                        (room.posExit.y - 1) * 32)
                    Shared.bubble(world, p, "`4You fell! Better luck next time!")
                    table.insert(deadIDs, uid)
                end
            else
                -- Normal fall out of game area
                local px, py = p:getPosX(), p:getPosY()
                if px < (ga.x1 - 1) * 32 or px > ga.x2 * 32 or
                   py < (ga.y1 - 1) * 32 or py > ga.y2 * 32 then
                    if now >= (pdata.noDeathUntil or 0) then
                        p:sendVariant({"OnCountdownStart", 0, -1}, 0, p:getNetID())
                        world:setPlayerPosition(p,
                            (room.posExit.x - 1) * 32,
                            (room.posExit.y - 1) * 32)
                        Shared.bubble(world, p, "`4You fell! Better luck next time!")
                        table.insert(deadIDs, uid)
                    end
                end
            end
        end
        for _, uid in ipairs(deadIDs) do
            room.activePlayers[uid] = nil
        end

        -- All players gone before timer?
        local count = 0
        for _ in pairs(room.activePlayers) do count = count + 1 end
        if count == 0 then
            room.gameEndAt      = nil
            room.gameActive     = false
            room.platformTickAt = nil
            ssResetPlatforms(world, room)
            ssScheduleNext(room)
            return
        end
    end

    -- Eject non-active players from game area (~1s / 10 ticks)
    ssSnapTick = ssSnapTick + 1
    if ssSnapTick >= 10 then
        ssSnapTick = 0
        local ga = room.gameArea
        for _, p in ipairs(world:getPlayers()) do
            local uid = p:getUserID()
            if not room.activePlayers[uid] then
                local px, py = p:getPosX(), p:getPosY()
                if px >= (ga.x1 - 1) * 32 and px <= ga.x2 * 32 and
                   py >= (ga.y1 - 1) * 32 and py <= ga.y2 * 32 then
                    world:setPlayerPosition(p,
                        (room.posExit.x - 1) * 32,
                        (room.posExit.y - 1) * 32)
                    p:onConsoleMessage("`4Game area is restricted to active players only!")
                end
            end
        end
    end
end)

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    if world:getName():upper() ~= WORLD_UPPER then return false end
    local doorUp = tostring(doorID):upper()
    local uid    = player:getUserID()
    local room   = SS_ROOM

    if doorUp == room.doorExit then
        return false
    end

    if doorUp == room.doorIngame then
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
        if gType and gType ~= "ss" then
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

        if player:getItemAmount(TICKET_ID) < 1 then
            Shared.bubble(world, player, "`4No Golden Ticket!")
            player:onConsoleMessage("`4You need a `wGolden Ticket`4 to play Spiky Survivor!")
            return false
        end

        player:changeItem(TICKET_ID, -1, 0)
        table.insert(room.queue, {uid = uid, name = player:getName()})
        table.insert(room.reanchorList, {uid = uid, tickAt = os.time() + 1, pos = room.posWait})

        if not room.gameActive then
            if not room.countdownAt then
                room.countdownAt = os.time() + SS_COUNTDOWN
                player:onConsoleMessage("`2Game starting in `w" .. SS_COUNTDOWN .. " seconds`2! Waiting for more players...")
            else
                room.countdownAt = os.time() + SS_COUNTDOWN  -- reset timer — give more time to gather players
                player:onConsoleMessage("`oYou are `w#" .. #room.queue .. "`o in queue — starting in `w" .. SS_COUNTDOWN .. "s`o!")
            end
        else
            player:onConsoleMessage("`oYou are `w#" .. #room.queue .. "`o in queue — game in progress, up next!")
        end

        return false
    end

    return false
end)

onPlayerLeaveWorldCallback(function(world, player)
    if world:getName() ~= WORLD then return end
    local uid  = player:getUserID()
    local room = SS_ROOM

    for i = #room.reanchorList, 1, -1 do
        if room.reanchorList[i].uid == uid then table.remove(room.reanchorList, i) end
    end

    for i = #room.queue, 1, -1 do
        if room.queue[i].uid == uid then table.remove(room.queue, i) end
    end
    if room.countdownAt and #room.queue == 0 and not room.gameActive then
        room.countdownAt = nil
    end

    if room.activePlayers[uid] then
        room.activePlayers[uid] = nil

        if room.gameActive then
            local count = 0
            for _ in pairs(room.activePlayers) do count = count + 1 end
            if count == 0 then
                room.gameEndAt      = nil
                room.gameActive     = false
                room.platformTickAt = nil
                ssResetPlatforms(world, room)
                ssScheduleNext(room)
            else
                for ouid in pairs(room.activePlayers) do
                    local op = Shared.getPlayerInWorld(world, ouid)
                    if op then
                        op:onConsoleMessage("`7A player left. " .. count .. " player(s) still surviving!")
                    end
                end
            end
        end
    end
end)

onPlayerDeathCallback(function(world, player, isRespawn)
    if world:getName():upper() ~= WORLD_UPPER then return end
    local uid  = player:getUserID()
    local room = SS_ROOM

    if room.activePlayers[uid] then
        room.activePlayers[uid].pendingExit = true
    end
    for i = #room.queue, 1, -1 do
        if room.queue[i].uid == uid then table.remove(room.queue, i) end
    end
end)

-- ── Register ──────────────────────────────────────────────────────────────────

Shared.registerGame("ss", function() return {SS_ROOM} end, true, resetAll)

return M
