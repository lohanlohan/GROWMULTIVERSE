-- MODULE

local MaladySystem = {}

-- =======================================================
-- CONFIG
-- =======================================================

local MALADY_DURATION = 12 * 60 * 60 -- 12 hours
local CORE_RECOVERING_MOD_ID = nil -- disabled: hasMod with negative IDs can crash
local AUTOMATION_PLAYMOD_ID = -111

MaladySystem.MALADY = {
    CHICKEN_FEET         = "CHICKEN_FEET",
    TORN_PUNCHING_MUSCLE = "TORN_PUNCHING_MUSCLE",
    GRUMBLETEETH         = "GRUMBLETEETH",
    GEMS_CUTS            = "GEMS_CUTS",
    AUTOMATION_CURSE     = "AUTOMATION_CURSE",
    BROKEN_HEARTS        = "BROKEN_HEARTS",
    -- Vile Vial maladies
    CHAOS_INFECTION      = "CHAOS_INFECTION",
    LUPUS                = "LUPUS",
    BRAINWORMS           = "BRAINWORMS",
    MOLDY_GUTS           = "MOLDY_GUTS",
    ECTO_BONES           = "ECTO_BONES",
    FATTY_LIVER          = "FATTY_LIVER"
}

MaladySystem.MALADY_DISPLAY = {
    CHICKEN_FEET         = "Chicken Feet",
    TORN_PUNCHING_MUSCLE = "Torn Punching Muscle",
    GRUMBLETEETH         = "Grumbleteeth",
    GEMS_CUTS            = "Gems Cuts",
    AUTOMATION_CURSE     = "Automation Curse",
    BROKEN_HEARTS        = "Broken Hearts",
    CHAOS_INFECTION      = "Chaos Infection",
    LUPUS                = "Lupus",
    BRAINWORMS           = "Brainworms",
    MOLDY_GUTS           = "Moldy Guts",
    ECTO_BONES           = "Ecto-Bones",
    FATTY_LIVER          = "Fatty Liver"
}

-- Register lua playmod untuk CHICKEN_FEET (gravity tinggi = jump lebih pendek)
-- Adjust CHICKEN_FEET_GRAVITY_STRENGTH jika efek kurang/terlalu kuat setelah test ingame
-- Guard global agar registerLuaPlaymod tidak dipanggil ulang saat reloadScripts()
local CHICKEN_FEET_GRAVITY_STRENGTH = 800

if not _MALADY_CHICKEN_FEET_MOD_ID then
    _MALADY_CHICKEN_FEET_MOD_ID = registerLuaPlaymod({
        modID                    = -1101,
        modName                  = "Chicken Feet",
        onAddMessage             = "Your feet have turned into chicken feet!",
        onRemoveMessage          = "Your feet feel normal again.",
        iconID                   = 0,
        changeMovementSpeed      = 0,
        changeAcceleration       = 0,
        changeGravity            = CHICKEN_FEET_GRAVITY_STRENGTH,
        changePunchStrength      = 0,
        changeBuildRange         = 0,
        changePunchRange         = 0,
        changeWaterMovementSpeed = 0
    })
end
local _chickenFeetModID = _MALADY_CHICKEN_FEET_MOD_ID

MaladySystem.PLAYMOD_BY_MALADY = {
    CHICKEN_FEET         = _chickenFeetModID,
    TORN_PUNCHING_MUSCLE = -59,
    GRUMBLETEETH         = -57,
    GEMS_CUTS            = -58,
    BROKEN_HEARTS        = -55,
    CHAOS_INFECTION      = -50,
    LUPUS                = -49,
    BRAINWORMS           = -54,
    MOLDY_GUTS           = -52,
    ECTO_BONES           = -53,
    FATTY_LIVER          = -51
}

MaladySystem.TRIGGER_SOURCE = {
    JUMP = "JUMP",
    BREAK = "BREAK",
    WRENCH = "WRENCH",
    CHAT = "CHAT",
    GEMS = "GEMS",
    AUTOMATION = "AUTOMATION",
    SURGERY = "SURGERY",
    VIAL = "VIAL",
    EVENT = "EVENT",
    ADMIN = "ADMIN"
}

MaladySystem.DEFAULT_RNG_PERCENT = 1

MaladySystem.RNG_PERCENT_BY_MALADY = {
    CHICKEN_FEET         = 1,
    TORN_PUNCHING_MUSCLE = 1,
    GRUMBLETEETH         = 1,
    GEMS_CUTS            = 1,
    AUTOMATION_CURSE     = 15,
    BROKEN_HEARTS        = 1,
    -- Vile Vial maladies: tidak di-trigger oleh RNG activity
    CHAOS_INFECTION      = 0,
    LUPUS                = 0,
    BRAINWORMS           = 0,
    MOLDY_GUTS           = 0,
    ECTO_BONES           = 0,
    FATTY_LIVER          = 0
}

MaladySystem.TRIGGER_TO_MALADY = {
    JUMP = MaladySystem.MALADY.CHICKEN_FEET,
    BREAK = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    WRENCH = MaladySystem.MALADY.TORN_PUNCHING_MUSCLE,
    CHAT = MaladySystem.MALADY.GRUMBLETEETH,
    GEMS = MaladySystem.MALADY.GEMS_CUTS,
    AUTOMATION = MaladySystem.MALADY.AUTOMATION_CURSE,
    SURGERY = MaladySystem.MALADY.BROKEN_HEARTS
}

-- =======================================================
-- STORAGE LAYER  (JSON - malady_data.json)
-- =======================================================

local MALADY_JSON = "malady_data.json"

local function readMaladyDB()
    if not file.exists(MALADY_JSON) then return {} end
    return json.decode(file.read(MALADY_JSON)) or {}
end

local function writeMaladyDB(data)
    file.write(MALADY_JSON, json.encode(data))
end

local function dbLoadMalady(userID)
    local db = readMaladyDB()
    return db[tostring(userID)]
end

local function dbSaveMalady(userID, data)
    local db = readMaladyDB()
    db[tostring(userID)] = data
    writeMaladyDB(db)
end

local function dbDeleteMalady(userID)
    local db = readMaladyDB()
    db[tostring(userID)] = nil
    writeMaladyDB(db)
end

-- =======================================================
-- HELPERS
-- =======================================================

local function now()
    return os.time()
end

local function getUserID(player)
    if type(player) ~= "userdata" then return 0 end
    return tonumber(player:getUserID()) or 0
end

local function hasMethod(obj, methodName)
    return obj and type(obj[methodName]) == "function"
end

local function safeConsole(player, text)
    if hasMethod(player, "onConsoleMessage") then
        player:onConsoleMessage(text)
    end
end

local function safeBubble(player, text)
    if hasMethod(player, "onTalkBubble") and hasMethod(player, "getNetID") then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function hasCoreRecovering(player)
    if not CORE_RECOVERING_MOD_ID then
        return false
    end
    if hasMethod(player, "hasMod") then
        return player:hasMod(CORE_RECOVERING_MOD_ID)
    end
    return false
end

local function isValidMaladyType(maladyType)
    for _, v in pairs(MaladySystem.MALADY) do
        if v == maladyType then
            return true
        end
    end
    return false
end

local function getPlaymodID(maladyType)
    return MaladySystem.PLAYMOD_BY_MALADY[maladyType]
end

local function clearAllKnownMaladyPlaymods(player)
    if not hasMethod(player, "removeMod") then
        return
    end
    for _, modID in pairs(MaladySystem.PLAYMOD_BY_MALADY) do
        player:removeMod(modID)
    end
end

-- =======================================================
-- STATE READ API
-- =======================================================

function MaladySystem.getActiveMaladyRow(player)
    local userID = getUserID(player)
    return dbLoadMalady(userID)
end

function MaladySystem.hasActiveMalady(player)
    return MaladySystem.getActiveMaladyRow(player) ~= nil
end

function MaladySystem.getActiveMalady(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if not row then return nil end
    return tostring(row.malady_type)
end

function MaladySystem.isVicious(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if not row then return false end
    return tonumber(row.is_vicious) == 1
end

function MaladySystem.getRemainingSeconds(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if not row then return 0 end
    local left = (tonumber(row.expires_at) or 0) - now()
    return left < 0 and 0 or left
end

function MaladySystem.isRecovering(player)
    return hasCoreRecovering(player)
end

function MaladySystem.getStatusText(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if row then
        local left = MaladySystem.getRemainingSeconds(player)
        local hours = math.floor(left / 3600)
        local minutes = math.floor((left % 3600) / 60)
        local name = MaladySystem.MALADY_DISPLAY[tostring(row.malady_type)] or tostring(row.malady_type)
        local viciousText = tonumber(row.is_vicious) == 1 and " `4[Vicious]`o" or ""
        return "`4Infected: `o" .. name .. viciousText .. " `w(" .. tostring(hours) .. "h " .. tostring(minutes) .. "m left)"
    end
    if MaladySystem.isRecovering(player) then
        return "`9Recovering"
    end
    return "`2Healthy"
end

-- =======================================================
-- EFFECT SYNC
-- =======================================================

function MaladySystem.syncEffects(player)
    clearAllKnownMaladyPlaymods(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if not row then
        -- Restore automation playmod saat tidak ada malady
        if hasMethod(player, "addMod") then
            player:addMod(AUTOMATION_PLAYMOD_ID, 99999999)
        end
        if hasMethod(player, "getWorld") then
            local w = player:getWorld()
            if w and hasMethod(w, "updateClothing") then
                w:updateClothing(player)
            end
        end
        return
    end
    local maladyType = tostring(row.malady_type)
    local playmodID = getPlaymodID(maladyType)
    if playmodID and hasMethod(player, "addMod") then
        local left = MaladySystem.getRemainingSeconds(player)
        if left > 0 then
            player:addMod(playmodID, left)
        end
    end
    -- AUTOMATION_CURSE: pastikan playmod automation ter-remove
    if maladyType == MaladySystem.MALADY.AUTOMATION_CURSE and hasMethod(player, "removeMod") then
        player:removeMod(AUTOMATION_PLAYMOD_ID)
    end
    if hasMethod(player, "getWorld") then
        local w = player:getWorld()
        if w and hasMethod(w, "updateClothing") then
            w:updateClothing(player)
        end
    end
end

function MaladySystem.refreshPlayerState(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if not row then return end
    if tonumber(row.expires_at) <= now() then
        dbDeleteMalady(getUserID(player))
        safeConsole(player, "`2Your malady has expired. You are now healthy.")
        MaladySystem.syncEffects(player) -- sync hanya saat expire
    end
end

-- =======================================================
-- STATE WRITE API
-- =======================================================

function MaladySystem.clearMalady(player, source)
    local userID = getUserID(player)
    local hadMalady = MaladySystem.hasActiveMalady(player)
    dbDeleteMalady(userID)
    MaladySystem.syncEffects(player)
    return hadMalady
end

function MaladySystem.forceInfect(player, maladyType, source, isVicious, suppressBubble)
    if not isValidMaladyType(maladyType) then
        return false, "INVALID_MALADY"
    end
    if MaladySystem.hasActiveMalady(player) then
        return false, "ALREADY_INFECTED"
    end
    if MaladySystem.isRecovering(player) then
        return false, "RECOVERING"
    end

    local userID = getUserID(player)
    local ts = now()

    dbSaveMalady(userID, {
        malady_type = maladyType,
        source      = tostring(source or "UNKNOWN"),
        is_vicious  = isVicious and 1 or 0,
        infected_at = ts,
        expires_at  = ts + MALADY_DURATION
    })

    MaladySystem.syncEffects(player)
    if not suppressBubble then
        safeBubble(player, "`4You were infected with " .. (MaladySystem.MALADY_DISPLAY[maladyType] or maladyType) .. "!")
    end

    return true, "INFECTED"
end

function MaladySystem.tryInfect(player, maladyType, source, percent, isVicious)
    if not isValidMaladyType(maladyType) then
        return false, "INVALID_MALADY"
    end
    if MaladySystem.hasActiveMalady(player) then
        return false, "ALREADY_INFECTED"
    end
    if MaladySystem.isRecovering(player) then
        return false, "RECOVERING"
    end
    local chance = tonumber(percent)
    if not chance then
        chance = MaladySystem.RNG_PERCENT_BY_MALADY[maladyType] or MaladySystem.DEFAULT_RNG_PERCENT
    end
    local roll = math.random(1, 100)
    if roll > chance then
        return false, "RNG_FAILED"
    end
    return MaladySystem.forceInfect(player, maladyType, source, isVicious)
end

function MaladySystem.tryInfectFromTrigger(player, triggerSource)
    local maladyType = MaladySystem.TRIGGER_TO_MALADY[triggerSource]
    if not maladyType then
        return false, "NO_TRIGGER_MAPPING"
    end
    return MaladySystem.tryInfect(player, maladyType, triggerSource, nil, false)
end

function MaladySystem.cureFromManualSurgery(player)
    if not MaladySystem.hasActiveMalady(player) then
        return false, "NO_ACTIVE_MALADY"
    end
    MaladySystem.clearMalady(player, "SURGERY")
    safeConsole(player, "`2Your malady has been cured by surgery.")
    return true, "CURED_BY_SURGERY"
end

function MaladySystem.cureFromAutoSurgeon(player)
    if not MaladySystem.hasActiveMalady(player) then
        return false, "NO_ACTIVE_MALADY"
    end
    MaladySystem.clearMalady(player, "AUTOSURGEON")
    safeConsole(player, "`2Your malady has been cured by Auto Surgeon.")
    return true, "CURED_BY_AUTOSURGEON"
end

function MaladySystem.cure(player, source)
    local src = tostring(source or "UNKNOWN")
    if src == "AUTOSURGEON" then
        return MaladySystem.cureFromAutoSurgeon(player)
    end
    if src == "SURGERY" then
        return MaladySystem.cureFromManualSurgery(player)
    end
    if not MaladySystem.hasActiveMalady(player) then
        return false, "NO_ACTIVE_MALADY"
    end
    MaladySystem.clearMalady(player, src)
    return true, "CURED"
end

-- =======================================================
-- DEBUFF / GAMEPLAY BRIDGE API
-- =======================================================

function MaladySystem.transformChat(player, text)
    if MaladySystem.getActiveMalady(player) ~= MaladySystem.MALADY.GRUMBLETEETH then
        return text
    end
    local original = tostring(text or "")
    if original == "" then return original end
    local count = #original
    local result = {}
    local syllables = {"mmf", "mfm", "ffm", "fmf"}
    for i = 1, math.max(1, math.floor(count / 2)) do
        result[#result + 1] = syllables[math.random(1, #syllables)]
    end
    return table.concat(result)
end

function MaladySystem.modifyGemGain(player, amount)
    local n = math.floor(tonumber(amount) or 0)
    if n <= 0 then return 0 end
    if MaladySystem.getActiveMalady(player) ~= MaladySystem.MALADY.GEMS_CUTS then
        return n
    end
    local reduced = math.floor(n * 0.4)
    return math.max(1, reduced)
end

function MaladySystem.getBlockHardnessMultiplier(player)
    if MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.TORN_PUNCHING_MUSCLE then
        return 3
    end
    return 1
end

function MaladySystem.isAutomationBlocked(player)
    return MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.AUTOMATION_CURSE
end

function MaladySystem.hasShortJump(player)
    return MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.CHICKEN_FEET
end

function MaladySystem.getSurgeryFailModifier(player)
    if MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.BROKEN_HEARTS then
        return 1
    end
    return 0
end

-- =======================================================
-- DEBUG / DEV
-- =======================================================

function MaladySystem.debugState(player)
    MaladySystem.refreshPlayerState(player)
    local row = MaladySystem.getActiveMaladyRow(player)
    if row then
        safeConsole(player, "`4Malady: `o" .. tostring(row.malady_type))
        safeConsole(player, "`4Source: `o" .. tostring(row.source))
        safeConsole(player, "`4Vicious: `o" .. tostring(row.is_vicious))
        safeConsole(player, "`4Expires At: `o" .. tostring(row.expires_at))
    else
        safeConsole(player, "`2No active malady.")
    end
    if MaladySystem.isRecovering(player) then
        safeConsole(player, "`9Recovering detected from core mod.")
    end
end

-- =======================================================
-- CALLBACKS
-- =======================================================

onPlayerLoginCallback(function(player)
    MaladySystem.refreshPlayerState(player)
    MaladySystem.syncEffects(player) -- selalu sync saat login untuk restore playmod
end)

onPlayerDisconnectCallback(function(player)
    local uid = getUserID(player)
    if uid ~= 0 then
        _maladyLastPos[uid] = nil
        _maladyPunchCount[uid] = nil
        _maladyPunchBubbleAt[uid] = nil
        _maladySurgeryBubbleAt[uid] = nil
        _maladyPendingRemoveCaduceus[uid] = nil
    end
end)

-- MOVEMENT (JUMP trigger): deteksi pergerakan player via posisi tiap tick
_maladyLastPos = _maladyLastPos or {}
_maladyPunchCount = _maladyPunchCount or {}
_maladyPunchBubbleAt = _maladyPunchBubbleAt or {} -- [uid] = os.time() last bubble shown

onPlayerTick(function(player)
    local uid = getUserID(player)
    if uid == 0 then return end
    local x = player:getPosX()
    local y = player:getPosY()
    local last = _maladyLastPos[uid]
    if last and (last.x ~= x or last.y ~= y) then
        MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.JUMP)
    end
    _maladyLastPos[uid] = {x = x, y = y}

    -- AUTOMATION_CURSE: re-remove playmod tiap tick agar tidak kembali dari equip/unequip
    if MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.AUTOMATION_CURSE then
        if hasMethod(player, "removeMod") then
            player:removeMod(AUTOMATION_PLAYMOD_ID)
        end
    end
end)

-- TORN_PUNCHING_MUSCLE: setiap 20 punch baru bisa kasih damage ke tile
-- 19 punch pertama di-block (return true), punch ke-20 diizinkan (return false)
-- Setiap punch yang di-block: tampilkan bubble reminder (cooldown 3 detik, delay 2 detik)
onTilePunchCallback(function(world, player, tile)
    if MaladySystem.getActiveMalady(player) ~= MaladySystem.MALADY.TORN_PUNCHING_MUSCLE then
        return false
    end
    local uid = getUserID(player)
    if uid == 0 then return false end
    local tileKey = tostring(tile:getPosX()) .. ":" .. tostring(tile:getPosY())
    if not _maladyPunchCount[uid] then
        _maladyPunchCount[uid] = {}
    end
    local count = (_maladyPunchCount[uid][tileKey] or 0) + 1
    if count < 20 then
        _maladyPunchCount[uid][tileKey] = count
        -- Bubble reminder: tampilkan tiap punch, tapi cooldown 3 detik agar tidak flood
        local lastAt = _maladyPunchBubbleAt[uid] or 0
        if (now() - lastAt) >= 6 then
            _maladyPunchBubbleAt[uid] = now()
            safeBubble(player, "`4Ouch! Your muscle is torn, punching feels much harder! Cure your malady at a Hospital!")
        end
        return true -- block damage
    end
    _maladyPunchCount[uid][tileKey] = nil -- reset, izinkan damage ke-20
    return false
end)

-- BREAK: tile dipecahkan player
-- (Nperma only — tidak akan crash jika engine tidak support, callback hanya tidak terpanggil)
onTileBreakCallback(function(world, player, tile)
    MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.BREAK)
end)

-- WRENCH: player mewrench tile apapun
-- Skip hospital tiles (Reception Desk=14668, Auto Surgeon=14666) agar tidak trigger RNG
onTileWrenchCallback(function(world, player, tile)
    local tileID = tile:getTileID()
    if tileID == 14668 or tileID == 14666 then return false end
    MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.WRENCH)
    return false
end)

-- GEMS: player mendapat gems
-- Sekaligus apply debuff GEMS_CUTS: kurangi gems ke 20% jika aktif
onPlayerGemsObtainedCallback(function(world, player, amount)
    local amt = tonumber(amount) or 0
    if amt <= 0 then return end
    local reduced = MaladySystem.modifyGemGain(player, amt)
    if reduced < amt then
        player:removeGems(amt - reduced, 1, 0)
        safeBubble(player, "`4Gems Cuts! You only received " .. tostring(reduced) .. " of " .. tostring(amt) .. " gems.")
    end
    MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.GEMS)
end)

-- CHAT: player mengirim chat biasa (bukan command /)
-- onPlayerActionCallback (Nperma) menangkap regular chat dengan action "input"
-- Sekaligus apply debuff GRUMBLETEETH: garble chat ke semua player jika aktif
onPlayerActionCallback(function(world, player, data)
    if type(data) ~= "table" then return end
    if data["action"] ~= "input" then return end
    local text = tostring(data["|text"] or "")
    if text == "" or text:sub(1, 1) == "/" then return end

    if MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.GRUMBLETEETH then
        local garbled = MaladySystem.transformChat(player, text)
        local netID   = player:getNetID()
        local name    = player.getName and player:getName() or "?"
        local players = world:getPlayers()
        if type(players) == "table" then
            for _, p in pairs(players) do
                if p and p.onTalkBubble then
                    p:onTalkBubble(netID, garbled, 0)
                end
                if p and p.onConsoleMessage then
                    p:onConsoleMessage("`6<`o" .. name .. "`6>" .. garbled)
                end
            end
        end
        return true
    end

    MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.CHAT)
end)

-- AUTOMATION_CURSE: block item 20704 (automation role consumable) saat malady aktif
local AUTOMATION_ROLE_ITEM_ID = 20704

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID ~= AUTOMATION_ROLE_ITEM_ID then return false end
    if MaladySystem.getActiveMalady(player) ~= MaladySystem.MALADY.AUTOMATION_CURSE then return false end
    safeBubble(player, "`4Automation Curse! You cannot use this while cursed. Get cured first!")
    return true
end)

-- BROKEN_HEARTS: block surgical tool usage jika player punya malady ini
-- Surgical tool IDs dari hospital.lua (1258-1270 = basic tools, 4308-4318 = advanced tools)
local _SURGICAL_TOOL_SET = {
    [1258]=true,[1260]=true,[1262]=true,[1264]=true,[1266]=true,[1268]=true,[1270]=true,
    [4308]=true,[4310]=true,[4312]=true,[4314]=true,[4316]=true,[4318]=true
}

local CADUCEUS_ID = 4298
_maladySurgeryBubbleAt = _maladySurgeryBubbleAt or {}
_maladyPendingRemoveCaduceus = _maladyPendingRemoveCaduceus or {}

onPlayerSurgeryCallback(function(world, surgeon, rewardID, rewardCount, targetPlayer)
    if MaladySystem.getActiveMalady(surgeon) ~= MaladySystem.MALADY.BROKEN_HEARTS then return false end
    local uid = getUserID(surgeon)
    local lastAt = _maladySurgeryBubbleAt[uid] or 0
    if (now() - lastAt) >= 2 then
        _maladySurgeryBubbleAt[uid] = now()
        _maladyPendingRemoveCaduceus[uid] = { rid = tonumber(rewardID) or 0, rcount = tonumber(rewardCount) or 0 }
        safeBubble(surgeon, "`4Broken Hearts! Your hands tremble too much to perform surgery. Get cured first!")
    end
    return true
end)

onPlayerTick(function(player)
    local uid = getUserID(player)
    if _maladyPendingRemoveCaduceus[uid] then
        local pending = _maladyPendingRemoveCaduceus[uid]
        _maladyPendingRemoveCaduceus[uid] = nil
        player:changeItem(CADUCEUS_ID, -1, 0)
        if pending.rid > 0 and pending.rcount > 0 then
            player:changeItem(pending.rid, -pending.rcount, 0)
        end
    end
end)

-- AUTOMATION: trigger saat player ketik /auto
-- JUMP & AUTOMATION: tidak ada callback langsung di API.
-- Panggil MaladySystem.tryInfectFromTrigger(player, TRIGGER_SOURCE.JUMP/AUTOMATION)
-- secara eksternal dari sistem lain jika tersedia.

return MaladySystem
