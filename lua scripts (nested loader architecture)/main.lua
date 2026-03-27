-- main.lua — Growtopia Multiverse Server
-- Entry point — dipanggil sekali saat server start / reloadScripts()
-- SATU-SATUNYA file tanpa "-- MODULE"

-- ═══════════════════════════════════════════
-- SERVER ID GUARD
-- Allowed: 4134 (admin/beta), 4552 (main server)
-- ═══════════════════════════════════════════
local ALLOWED_IDS = { ["4134"] = true, ["4552"] = true }
local currentID   = tostring(getServerID())

if not ALLOWED_IDS[currentID] then
    print("================================================================")
    print("  [GROWMULTIVERSE] UNAUTHORIZED SERVER DETECTED — ID: " .. currentID)
    print("  You are running STOLEN scripts. This is private property of")
    print("  Growtopia Multiverse. You are a pathetic thief and you know it.")
    print("  These scripts will NOT load. Enjoy your broken server, loser.")
    print("================================================================")
    return
end

print("[main] ════════════════════════════════")
print("[main] Loading Growtopia Multiverse...")
print("[main] Server ID: " .. currentID)
print("[main] ════════════════════════════════")

-- ═══════════════════════════════════════════
-- FONDASI — utils, config, db (wajib pertama)
-- ═══════════════════════════════════════════
package.loaded["utils"]  = nil
package.loaded["config"] = nil
package.loaded["db"]     = nil

local ok, err

ok, err = pcall(function() _G.Utils  = require("utils")  end)
if not ok then print("[main] ✗ utils — " .. tostring(err))  return end

ok, err = pcall(function() _G.Config = require("config") end)
if not ok then print("[main] ✗ config — " .. tostring(err)) return end

ok, err = pcall(function() _G.DB     = require("db")     end)
if not ok then print("[main] ✗ db — " .. tostring(err))     return end

print("[main] ✓ fondasi loaded (utils / config / db)")

-- ═══════════════════════════════════════════
-- FEATURE LOADERS (urutan penting!)
-- ═══════════════════════════════════════════
local loaders = {
    "security_loader",   -- [1] anti-cheat aktif duluan
    "economy_loader",    -- [2] store, currency, daily reward
    "player_loader",     -- [3] backpack, profile, titles (sebelum world)
    "world_loader",      -- [4] rent entrance, grow-o-matic (depend player)
    "item_info_loader",  -- [5] item info, item effects
    "consumable_loader", -- [6] wands, consumable items
    "backpack_loader",   -- [7] backpack system (depend item_info)
    "carnival_loader",   -- [8] carnival minigames
    "hospital_loader",   -- [9] hospital system
    "events_loader",     -- [10] fenrir, clash finale, lb event
    "social_loader",     -- [11] news, broadcast, social portal
    "admin_loader",      -- [12] give, reload, fakewarn, online (terakhir)
}

local loaded, failed = 0, 0
for _, name in ipairs(loaders) do
    package.loaded[name] = nil
    local success, result = pcall(require, name)
    if success then
        loaded = loaded + 1
        print("[main] ✓ " .. name)
    else
        failed = failed + 1
        print("[main] ✗ " .. name .. " — " .. tostring(result))
    end
end

-- ═══════════════════════════════════════════
-- STANDALONE FEATURES
-- ═══════════════════════════════════════════
local standalones = {
    "marvelous_missions_loader",
    "automation_menu_loader",
}

for _, name in ipairs(standalones) do
    package.loaded[name] = nil
    local success, result = pcall(require, name)
    if success then
        loaded = loaded + 1
        print("[main] ✓ " .. name)
    else
        failed = failed + 1
        print("[main] ✗ " .. name .. " — " .. tostring(result))
    end
end

print("[main] ════════════════════════════════")
print("[main] Done: " .. loaded .. " loaded, " .. failed .. " failed")
print("[main] ════════════════════════════════")
