# Konvensi Kode — Growtopia Multiverse
> Last updated: March 2026
> Platform: GTPS Cloud by Sebia (Lua scripting)

---

## Struktur Wajib Setiap Script

```lua
-- ================================================
-- NamaScript v1.0
-- Deskripsi singkat fungsi script ini
-- ================================================
print("(Loaded) NamaScript")

-- 1. CONFIG — semua konstanta di atas, tidak ada magic number
local CONFIG = {
    ADMIN_ROLE  = 52,
    SAVE_KEY    = "MULTIVERSE_NAMAFITUR_V1",
    MAX_AMOUNT  = 100,
    COOLDOWN    = 86400  -- 24 jam dalam detik
}

-- 2. DATA — load sekali saat script start
local db = loadDataFromServer(CONFIG.SAVE_KEY) or {}

-- 3. AUTO SAVE — satu-satunya tempat save data
onAutoSaveRequest(function()
    saveDataToServer(CONFIG.SAVE_KEY, db)
end)

-- 4. HELPER FUNCTIONS — fungsi kecil pendukung

-- 5. CORE FUNCTIONS — logika utama

-- 6. CALLBACKS — event handlers

print("(Ready) NamaScript")
```

---

## Penamaan

```lua
-- Fungsi: camelCase
local function giveReward(player, itemID) end
local function openMainDialog(player) end
local function getPlayerData(player) end

-- Variable lokal: camelCase
local playerData = {}
local currentStreak = 0

-- Konstanta: UPPER_SNAKE_CASE
local MAX_STREAK = 14
local COOLDOWN_SECONDS = 86400

-- Storage key: WAJIB format ini
-- "MULTIVERSE_[NAMAFITUR]_V[versi]"
-- Contoh:
-- "MULTIVERSE_DAILY_V1"
-- "MULTIVERSE_MISSIONS_V2"
-- "MULTIVERSE_QUEST_V1"

-- Nama dialog: lowercase dengan underscore
-- "daily_reward_dialog"
-- "mission_main_dialog"
```

---

## Data Storage Pattern

```lua
-- WAJIB: selalu ada fallback or {}
local db = loadDataFromServer(CONFIG.SAVE_KEY) or {}

-- WAJIB: helper function untuk init + akses data player
-- Pakai TOSTRING untuk userID sebagai key!
local function getPlayerData(player)
    local uid = tostring(player:getUserID())  -- WAJIB tostring()
    if not db[uid] then
        db[uid] = {
            -- Isi semua field dengan default value
            streak    = 0,
            lastClaim = 0,
            total     = 0,
            createdAt = os.time()
        }
    end
    return db[uid]
end

-- WAJIB: hanya save di autoSave, tidak di tempat lain
onAutoSaveRequest(function()
    saveDataToServer(CONFIG.SAVE_KEY, db)
end)

-- DILARANG: save di dalam callback yang sering dipanggil
-- onPlayerHarvestCallback → JANGAN saveDataToServer di sini
-- onTileBreakCallback     → JANGAN saveDataToServer di sini
-- onPlayerTick            → JANGAN saveDataToServer di sini
```

---

## Nil Check — Wajib Selalu

```lua
-- Cek world sebelum dipakai
local world = player:getWorld()
if world == nil then return end

-- Cek player data sebelum dipakai
local data = db[tostring(player:getUserID())]
if data == nil then return end

-- Cek item sebelum dipakai
local item = getItem(itemID)
if item == nil then return end

-- Cek NPC setelah create
local npc = world:createNPC("Guard", 10, 5)
if npc == nil then return end

-- Cek getPlayer — bisa nil kalau offline
local target = getPlayer(userID)
if target == nil then
    player:onConsoleMessage("`4Player tidak ditemukan atau offline.")
    return
end

-- Pattern aman untuk akses nested data
local data = db[tostring(player:getUserID())]
local gems = 0
if data ~= nil then
    gems = data.gems or 0  -- pakai 'or default' untuk field
end
```

---

## ⚡ Performance Rules — WAJIB DIIKUTI

### Caching — Jangan Query Ulang yang Sudah Ada

```lua
-- SALAH: loadDataFromServer di dalam callback
onPlayerLoginCallback(function(player)
    local data = loadDataFromServer("key")  -- query tiap login!
end)

-- BENAR: load sekali saat script start
local db = loadDataFromServer("key") or {}

onPlayerLoginCallback(function(player)
    local data = db[tostring(player:getUserID())]  -- dari memory
end)

-- Cache item yang sering dipakai
local ITEM_CACHE = {}
local function getCachedItem(itemID)
    if not ITEM_CACHE[itemID] then
        ITEM_CACHE[itemID] = getItem(itemID)
    end
    return ITEM_CACHE[itemID]
end
```

### Tick Callbacks — Paling Berbahaya

```lua
-- onTick       = SETIAP 100ms GLOBAL
-- onWorldTick  = SETIAP 100ms PER WORLD AKTIF
-- onPlayerTick = SETIAP 1000ms PER PLAYER

-- DILARANG di dalam onTick / onWorldTick:
onTick(function()
    getAllPlayers()       -- DILARANG
    loadDataFromServer()  -- DILARANG
    saveDataToServer()    -- DILARANG
end)

-- BENAR: gunakan timer untuk operasi tidak real-time
timer.setInterval(60, function()    -- tiap 1 menit
    updateLeaderboard()
end)

timer.setInterval(300, function()   -- tiap 5 menit
    broadcastServerStats()
end)

-- Kalau HARUS pakai onWorldTick, pakai throttle
local lastUpdate = 0
onWorldTick(function(world)
    local now = os.time()
    if now - lastUpdate < 5 then return end  -- throttle 5 detik
    lastUpdate = now
    -- logic di sini
end)
```

### Loop & Iterasi

```lua
-- DILARANG: getAllPlayers() di dalam tick
onPlayerTick(function(player)
    local all = getAllPlayers()  -- DILARANG, sangat boros
end)

-- BENAR: cache player list, update berkala
local cachedPlayers = {}
timer.setInterval(30, function()
    cachedPlayers = getServerPlayers() or {}
end)

-- ipairs untuk array (lebih cepat), pairs untuk table
for i, item in ipairs(arrayTable) do end
for key, val in pairs(hashTable) do end

-- Break kalau sudah ketemu yang dicari
for _, p in ipairs(players) do
    if p:getUserID() == targetID then
        -- found
        break
    end
end
```

### Memory Management

```lua
-- Bedakan data persistent vs session
local db = {}           -- persistent: disimpan ke server
local sessionData = {}  -- sementara: hilang saat restart

-- Bersihkan session saat player disconnect
onPlayerDisconnectCallback(function(player)
    local uid = tostring(player:getUserID())
    sessionData[uid] = nil  -- hapus dari memory
end)
```

---

## Dialog Pattern

```lua
-- WAJIB: cek dialog_name PERTAMA
onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] ~= "my_dialog" then
        return false
    end

    local btn = data["buttonClicked"] or ""

    if btn == "btn_claim" then
        return true
    end

    if btn == "btn_close" then
        return true
    end

    return true
end)

-- WAJIB: resetDialogColor setelah custom color
player:setNextDialogRGBA(180, 140, 0, 200)
player:setNextDialogBorderRGBA(255, 200, 0, 255)
player:onDialogRequest(dialog)
player:resetDialogColor()  -- JANGAN LUPA

-- embed_data untuk simpan state antar halaman
dialog = dialog .. "embed_data|tab|" .. tabNumber .. "\n"
-- Ambil di callback:
local tab = tonumber(data["tab"]) or 0

-- Pakai delay 500ms untuk dialog dengan tabs
player:onDialogRequest(dialog, 500)
```

---

## Command Pattern

```lua
-- WAJIB: daftarkan command
registerLuaCommand({
    command      = "mycommand",
    roleRequired = CONFIG.ADMIN_ROLE,
    description  = "Deskripsi singkat"
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:lower():gsub("^/", ""):match("^%S+")
    if cmd ~= "mycommand" then return false end

    if not player:hasRole(CONFIG.ADMIN_ROLE) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end

    -- Parse args
    local args = {}
    for word in fullCommand:gmatch("%S+") do
        table.insert(args, word)
    end
    -- args[1]=command, args[2]=arg1, dst.

    local targetName = args[2]
    if targetName == nil then
        player:onConsoleMessage("`oUsage: /mycommand <playerName>")
        return true
    end

    return true
end)
```

---

## Callback Return Values

```lua
-- onPlayerCommandCallback:
-- return true  = sudah dihandle, stop propagasi
-- return false = bukan saya, teruskan ke script lain

-- onPlayerDialogCallback:
-- return true  = sudah dihandle
-- return false = bukan saya, teruskan

-- onTilePlaceCallback, onTileBreakCallback, dll:
-- return true  = PREVENT aksi default
-- return false = allow aksi default

-- DILARANG: tidak return apapun
onPlayerCommandCallback(function(world, player, cmd)
    if cmd == "test" then
        player:onConsoleMessage("test")
        -- LUPA return! Bug!
    end
    -- LUPA return false! Bug!
end)
```

---

## Error Handling Pattern

```lua
-- Wrap operasi yang bisa gagal
local function safeGiveItem(player, itemID, amount)
    if player == nil then return false end
    if itemID == nil or itemID <= 0 then return false end
    if amount == nil or amount <= 0 then return false end

    local item = getItem(itemID)
    if item == nil then
        print("[ERROR] safeGiveItem: itemID " .. itemID .. " tidak ditemukan")
        return false
    end

    local success = player:changeItem(itemID, amount, 0)
    if not success then
        success = player:changeItem(itemID, amount, 1)  -- coba backpack
    end
    return success
end

-- Format log error yang konsisten
local function logError(scriptName, funcName, message)
    print("[ERROR] " .. scriptName .. " > " .. funcName .. ": " .. message)
end
```

---

## Coroutine untuk HTTP

```lua
-- HTTP WAJIB dalam coroutine

-- SALAH
onPlayerLoginCallback(function(player)
    local body, status = http.get("https://api.example.com")  -- CRASH!
end)

-- BENAR
onPlayerLoginCallback(function(player)
    coroutine.wrap(function()
        local body, status = http.get("https://api.example.com")
        if status == 200 then
            local data = json.decode(body)
            if data ~= nil then
                -- proses data
            end
        end
    end)()
end)
```

---

## NPC Safety Pattern

```lua
local npc = world:createNPC("Guard", 10, 5)
if npc == nil then return end

-- Setelah removeNPC, set nil
world:removeNPC(npc)
npc = nil  -- PENTING

-- Cek type untuk bedakan NPC vs player
onPlayerWrenchCallback(function(world, player, wrenchedPlayer)
    if wrenchedPlayer:getType() == 25 then
        -- NPC
    else
        -- player biasa
    end
end)
```

---

## Timer Pattern

```lua
-- Gunakan timer, bukan onTick untuk operasi berkala
timer.setInterval(300, function()   -- tiap 5 menit
    updateLeaderboard()
end)

timer.setInterval(3600, function()  -- tiap 1 jam
    local players = getServerPlayers()
    for _, p in ipairs(players or {}) do
        p:onConsoleMessage("`2[Info] Server berjalan normal!")
    end
end)

-- Simpan ID kalau perlu dihentikan
local intervalID = timer.setInterval(60, function()
    doSomething()
end)

-- Hentikan kalau perlu
timer.clear(intervalID)
```

---

## String & Format Helper

```lua
-- Format angka dengan koma pemisah
local function formatNum(num)
    local formatted = tostring(math.floor(num))
    local result = ""
    local count = 0
    for i = #formatted, 1, -1 do
        if count > 0 and count % 3 == 0 then
            result = "," .. result
        end
        result = formatted:sub(i, i) .. result
        count = count + 1
    end
    return result
end
-- formatNum(1000000) → "1,000,000"

-- Format waktu tersisa
local function formatTime(seconds)
    if seconds <= 0 then return "Sekarang" end
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if hours > 0 then return hours .. "j " .. mins .. "m" end
    return mins .. " menit"
end
```

---

## Growtopia Color Codes

```lua
-- `0=putih terang  `1=biru tua   `2=hijau
-- `3=biru muda     `4=merah      `5=ungu
-- `6=orange        `7=abu        `8=abu gelap
-- `9=cyan          `w=putih      `o=oranye(default)
-- `$=emas          `#=pink       `!=berkedip
-- ``=reset warna

-- Contoh
player:onConsoleMessage("`2Berhasil!`` Dapat `$1 DL``!")
player:onConsoleMessage("`4Error!`` Inventory penuh.")
player:onConsoleMessage("`oHalo `w" .. player:getName() .. "``!")
```

---

## Multi-Script Safety

```lua
-- DILARANG: variable global generik
data = {}     -- SALAH
db = {}       -- SALAH
players = {}  -- SALAH

-- BENAR: selalu local
local daily_db = {}
local missions_db = {}

-- Storage key WAJIB prefix unik
-- SALAH: "data", "daily", "quest"
-- BENAR: "MULTIVERSE_DAILY_V1", "MULTIVERSE_QUEST_V1"
```

---

## Yang Dilarang — Ringkasan Cepat

```
❌ db[player:getUserID()]        → pakai tostring()
❌ saveDataToServer di callback  → hanya di onAutoSaveRequest
❌ loadDataFromServer di callback → load sekali saat start
❌ getAllPlayers() di onTick      → pakai cache + timer
❌ http.get() di luar coroutine  → wajib dalam coroutine
❌ tidak return di callback      → selalu return true/false
❌ lupa resetDialogColor()       → selalu setelah custom color
❌ tidak cek dialog_name dulu    → cek di awal callback
❌ variable global tanpa prefix  → selalu local atau prefix unik
❌ npc tidak dicek nil           → selalu cek setelah create
❌ npc tidak di-nil setelah remove → set nil setelah removeNPC
```

---

## Template Penjelasan Tugas

Format WAJIB setiap minta fitur baru:

```
Tujuan:
[nama fitur] — [deskripsi 1-2 kalimat]

Struktur data (key: "MULTIVERSE_NAMAFITUR_V1"):
{
    field1 = defaultValue,
    field2 = defaultValue
}
(Tulis "tidak ada persistent data" kalau tidak perlu simpan)

Flow:
1. [trigger]
2. [langkah 2]
3. [dst]

Detail UI/Dialog:
- Nama dialog: [nama_dialog]
- Warna: [r,g,b,a] atau default
- Buttons: [nama → fungsi]
- Input: [nama → untuk apa]

Logic:
[kondisi A → hasil A]
[kondisi B → hasil B]

Edge cases:
- Data nil / player baru
- [kondisi khusus]
- [kondisi yang bisa di-abuse]

Scope — TIDAK perlu dibuat:
- [batasan]
```

---

## Cara Lapor Error

```
Script: [nama-file.lua]
Error: [paste LENGKAP dari konsol server]
Terjadi saat: [player melakukan apa]
Line: [nomor line]
Kondisi: [hal khusus sebelum error]
```
