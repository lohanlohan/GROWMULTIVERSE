-- MODULE
-- utils.lua — Shared utility functions (global via _G.Utils)

local M = {}

-- ═══════════════════════════════════════════
-- FORMAT
-- ═══════════════════════════════════════════

-- Tambah pemisah ribuan: 1000000 → "1,000,000"
function M.formatNum(num)
    local formatted = tostring(math.floor(num))
    local result, count = "", 0
    for i = #formatted, 1, -1 do
        if count > 0 and count % 3 == 0 then result = "," .. result end
        result = formatted:sub(i, i) .. result
        count = count + 1
    end
    return result
end

-- Format detik ke string readable: 3661 → "1h 1m 1s"
function M.formatTime(seconds)
    seconds = math.floor(seconds)
    if seconds <= 0 then return "0s" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    if m > 0 then return string.format("%dm %ds", m, s) end
    return string.format("%ds", s)
end

-- ═══════════════════════════════════════════
-- COMMAND PARSING
-- ═══════════════════════════════════════════

-- Split command jadi array: "/give 100 gems" → {"/give", "100", "gems"}
function M.parseArgs(fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do
        table.insert(args, word)
    end
    return args
end

-- Ambil command utama lowercase: "/Give 100" → "/give"
function M.getCmd(fullCommand)
    return (fullCommand:match("^%S+") or ""):lower()
end

-- ═══════════════════════════════════════════
-- PLAYER HELPERS
-- ═══════════════════════════════════════════

-- Cek apakah player punya akses mod/staff (role 51+)
function M.isPrivileged(player)
    return player:hasRole(51)
end

-- Cek apakah player adalah developer (role 52+)
function M.isDev(player)
    return player:hasRole(52)
end

-- Ambil userID sebagai string
function M.uid(player)
    return tostring(player:getUserID())
end

-- ═══════════════════════════════════════════
-- WORLD / TILE HELPERS
-- ═══════════════════════════════════════════

-- Bandingkan nama world (case insensitive)
function M.isWorld(world, name)
    return world:getName():upper() == name:upper()
end

-- Konversi tile coordinate ke pixel position
function M.tileToPixel(tileCoord)
    return (tileCoord - 1) * 32
end

-- Konversi pixel position ke tile coordinate
function M.pixelToTile(pixel)
    return math.floor(pixel / 32) + 1
end

-- Cek apakah pixel position ada dalam area tile (inklusif)
function M.inArea(px, py, tileX1, tileY1, tileX2, tileY2)
    local pxMin = (tileX1 - 1) * 32
    local pxMax = (tileX2 - 1) * 32 + 31
    local pyMin = (tileY1 - 1) * 32
    local pyMax = (tileY2 - 1) * 32 + 31
    return px >= pxMin and px <= pxMax and py >= pyMin and py <= pyMax
end

-- ═══════════════════════════════════════════
-- SAFE OPERATIONS
-- ═══════════════════════════════════════════

-- Tampilkan chat bubble di atas player
function M.bubble(world, player, text)
    world:onCreateChatBubble(
        player:getPosX(), player:getPosY() - 16,
        text, player:getNetID()
    )
end

-- Kirim pesan console ke player
function M.msg(player, text)
    player:onConsoleMessage(text)
end

-- Teleport player ke tile coordinate
function M.tp(player, tileX, tileY)
    player:setPos((tileX - 1) * 32, (tileY - 1) * 32)
end

-- ═══════════════════════════════════════════
-- LOGGER
-- ═══════════════════════════════════════════

function M.log(tag, msg)
    print("[" .. tag .. "] " .. tostring(msg))
end

function M.logError(tag, func, msg)
    print("[ERROR][" .. tag .. "] " .. func .. ": " .. tostring(msg))
end

return M
