-- MODULE
-- db.lua — Data persistence wrapper (global via _G.DB)
-- Saat ini: JSON only. SQLite belum aktif — tunggu konfirmasi.
--
-- ATURAN: 1 feature = 1 file JSON
-- Lokasi file di panel: currentState/luaData/[feature].json
--
-- Contoh per feature:
--   currentState/luaData/hospital.json
--   currentState/luaData/carnival.json
--   currentState/luaData/player.json
--   currentState/luaData/economy.json

local M = {}

local BASE_PATH = "currentState/luaData/"

-- ═══════════════════════════════════════════
-- FEATURE FILE STORAGE
-- 1 feature = 1 file JSON
-- Isi file = Lua table (biasanya keyed by UID untuk per-player)
--
-- Pola umum:
--   {
--     ["12345"] = { level = 5, points = 100 },
--     ["67890"] = { level = 2, points = 30  },
--   }
-- ═══════════════════════════════════════════

-- Load seluruh data sebuah feature dari JSON file
-- Return {} jika file belum ada atau kosong
function M.loadFeature(featureName)
    local path = BASE_PATH .. featureName .. ".json"
    if not file.exists(path) then return {} end
    local content = file.read(path)
    if not content or content == "" then return {} end
    local data = json.decode(content)
    return data or {}
end

-- Simpan seluruh data sebuah feature ke JSON file
function M.saveFeature(featureName, dataTable)
    local path = BASE_PATH .. featureName .. ".json"
    file.write(path, json.encode(dataTable))
end

-- ═══════════════════════════════════════════
-- PER-PLAYER DATA (dalam 1 file feature)
-- Key = string UID player
--
-- Pola pakai:
--   local record = DB.getPlayer("hospital", uid)
--   record.rating = record.rating + 1
--   DB.setPlayer("hospital", uid, record)
-- ═══════════════════════════════════════════

-- Ambil data 1 player dari file feature, return {} jika belum ada
function M.getPlayer(featureName, uid)
    local all = M.loadFeature(featureName)
    return all[tostring(uid)] or {}
end

-- Simpan data 1 player ke file feature (merge ke data existing)
function M.setPlayer(featureName, uid, record)
    local all = M.loadFeature(featureName)
    all[tostring(uid)] = record
    M.saveFeature(featureName, all)
end

-- Update sebagian field player (shallow merge, tidak overwrite semua)
function M.updatePlayer(featureName, uid, patch)
    local record = M.getPlayer(featureName, uid)
    for k, v in pairs(patch) do
        record[k] = v
    end
    M.setPlayer(featureName, uid, record)
end

-- Hapus data 1 player dari file feature
function M.deletePlayer(featureName, uid)
    local all = M.loadFeature(featureName)
    all[tostring(uid)] = nil
    M.saveFeature(featureName, all)
end

-- ═══════════════════════════════════════════
-- SERVER KEY-VALUE STORAGE (saveDataToServer)
-- Untuk data global server yang tidak perlu per-player file
-- Contoh: config aktif, state server, flag event
-- ═══════════════════════════════════════════

function M.save(key, dataTable)
    saveDataToServer(key, dataTable)
end

function M.load(key)
    return loadDataFromServer(key) or {}
end

function M.saveStr(key, value)
    saveStringToServer(key, tostring(value))
end

function M.loadStr(key)
    return loadStringFromServer(key) or ""
end

return M
