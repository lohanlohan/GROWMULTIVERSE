-- MODULE

local VileVialSystem = {}

print("(vile_vial) module loading...")

-- =======================================================
-- CONFIG
-- =======================================================

local VICIOUS_CHANCE = 20 -- 20% chance vicious saat vial digunakan

-- =======================================================
-- STORAGE  (JSON - vile_vial_data.json)
-- =======================================================

local VIAL_JSON = "vile_vial_data.json"

local function readVialDB()
    if not file.exists(VIAL_JSON) then return { stats = {} } end
    local data = json.decode(file.read(VIAL_JSON)) or {}
    if type(data.stats) ~= "table" then data.stats = {} end
    return data
end

local function recordVialUse(itemID, isVicious)
    local data = readVialDB()
    local key = tostring(itemID)
    if not data.stats[key] then data.stats[key] = { uses = 0, vicious = 0 } end
    data.stats[key].uses    = (data.stats[key].uses    or 0) + 1
    data.stats[key].vicious = (data.stats[key].vicious or 0) + (isVicious and 1 or 0)
    file.write(VIAL_JSON, json.encode(data))
end

local VIAL_TO_MALADY = {
    [8538] = MaladySystem.MALADY.CHAOS_INFECTION,
    [8544] = MaladySystem.MALADY.LUPUS,
    [8542] = MaladySystem.MALADY.BRAINWORMS,
    [8540] = MaladySystem.MALADY.MOLDY_GUTS,
    [8546] = MaladySystem.MALADY.ECTO_BONES,
    [8548] = MaladySystem.MALADY.FATTY_LIVER,
}

-- =======================================================
-- HELPERS
-- =======================================================

local function safeBubble(player, text)
    if player and type(player.onTalkBubble) == "function" and type(player.getNetID) == "function" then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local function safeConsole(player, text)
    if player and type(player.onConsoleMessage) == "function" then
        player:onConsoleMessage(text)
    end
end

local function getName(player)
    if player and type(player.getName) == "function" then
        return player:getName()
    end
    return "Unknown"
end

-- =======================================================
-- CALLBACKS
-- =======================================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if not VIAL_TO_MALADY[itemID] then return false end

    local maladyType = VIAL_TO_MALADY[itemID]
    local maladyName = MaladySystem.MALADY_DISPLAY[maladyType] or maladyType
    local target = clickedPlayer or player
    local isSelf = (target == player or clickedPlayer == nil)

    -- Cek apakah target sudah terinfeksi (jangan consume jika sudah infected)
    if MaladySystem.hasActiveMalady(target) then
        local activeName = MaladySystem.MALADY_DISPLAY[MaladySystem.getActiveMalady(target)] or "a malady"
        if isSelf then
            safeBubble(player, "`4You are already infected with " .. activeName .. "!")
        else
            safeBubble(player, "`4" .. getName(target) .. " is already infected with " .. activeName .. "!")
        end
        return true
    end

    -- Consume vial hanya jika target belum terinfeksi
    player:changeItem(itemID, -1, 0)

    -- RNG vicious
    local isVicious = math.random(1, 100) <= VICIOUS_CHANCE

    local ok, reason = MaladySystem.forceInfect(target, maladyType, "VIAL", isVicious, true)

    if ok then
        recordVialUse(itemID, isVicious)
        local viciousTag = isVicious and " `4[Vicious]`o" or ""
        if isSelf then
            safeBubble(player, "`4You infected yourself with " .. maladyName .. "!" .. viciousTag)
        else
            safeBubble(player, "`4You infected " .. getName(target) .. " with " .. maladyName .. "!" .. viciousTag)
            safeBubble(target, "`4" .. getName(player) .. " infected you with " .. maladyName .. "!" .. viciousTag)
        end
    else
        -- Seharusnya tidak sampai sini (sudah dicek hasActiveMalady), tapi jaga-jaga
        if isSelf then
            safeBubble(player, "`4Failed to infect: " .. tostring(reason))
        else
            safeBubble(player, "`4Failed to infect " .. getName(target) .. ": " .. tostring(reason))
        end
    end

    return true
end)

print("(vile_vial) module loaded successfully.")
return VileVialSystem
