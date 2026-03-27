# Arsitektur Module System — Growtopia Multiverse
> Last updated: March 2026
> Platform: GTPS Cloud by Sebia (Lua scripting)

---

## Overview

Semua Lua script menggunakan **nested loader architecture** dengan 3 level:

```
main.lua → sys_[system].lua → [module].lua
(entry)     (system loader)    (feature module)
```

Satu entry point (`main.lua`) yang memuat semua system loader, dan setiap system loader
memuat module-module nya sendiri. Utils di-load paling awal dan tersedia global.

---

## Load Flow

```
Server Start / reloadScripts()
        │
        ▼
    main.lua  (satu-satunya file TANPA -- MODULE)
        │
        ├── [1] utils        ← helper functions (global)
        ├── [2] config       ← konstanta & settings (global)
        ├── [3] db           ← database wrapper (global)
        │
        ├── [4] sys_security ← PERTAMA — anti-cheat harus aktif sebelum yang lain
        ├── [5] sys_economy
        ├── [6] sys_player   ← sebelum sys_world (backpack integration)
        ├── [7] sys_world    ← depend on player (BP_storeItem)
        ├── [8] sys_items
        ├── [9] sys_carnival
        ├── [10] sys_hospital
        ├── [11] sys_events
        ├── [12] sys_social
        └── [13] sys_admin   ← TERAKHIR — dev tools
```

**Urutan load penting!** System yang di-depend harus diload duluan.

---

## Platform Constraint — GTPS Cloud

| Constraint | Detail |
|---|---|
| **Flat `require()`** | `require("module_name")` — TANPA path separator. Semua file di `/lua/` flat |
| **`-- MODULE`** | Wajib baris pertama untuk file yang di-require. Tanpa ini = dieksekusi standalone |
| **`package.loaded`** | Harus di-nil sebelum require agar `reloadScripts()` / `/rs` berfungsi |
| **Upload** | Semua `.lua` upload ke `/lua/` di panel (flat, tanpa subfolder) |
| **Callback stacking** | Multiple registrasi callback yang sama = semua fire. `return true` pertama = prevent default |

---

## Naming Convention

### File Naming
| Tipe | Prefix | Contoh |
|---|---|---|
| Entry point | (none) | `main.lua` |
| Utils | (none) | `utils.lua`, `config.lua`, `db.lua` |
| System loader | `sys_` | `sys_carnival.lua`, `sys_hospital.lua` |
| Module | `[system]_` | `carnival_core.lua`, `economy_store.lua` |
| Example | (in examples/) | `tile-extra-example.lua` |

### Aturan Penamaan
- Semua lowercase, underscore separator: `carnival_core.lua`
- System prefix konsisten: `carnival_`, `economy_`, `player_`, dll
- JANGAN campur prefix: `hospital.lua` → `hospital_core.lua`

---

## File Structure — Complete Map

### Entry Point & Utils
```
main.lua                        ← ENTRY POINT (satu-satunya tanpa -- MODULE)
utils.lua                       ← shared helpers: formatNum, formatTime, parseArgs, safeTp
config.lua                      ← global constants: WORLDS, ITEM_IDS, ROLE_IDS, SETTINGS
db.lua                          ← database wrapper: sqlite, saveData/loadData, file I/O
```

### System Loaders (Level 2)
```
sys_security.lua                ← anti-spam, anti-cheat, rate limiter
sys_economy.lua                 ← store, daily reward, currency, trading
sys_player.lua                  ← backpack, profile, starter pack, progression
sys_world.lua                   ← rent entrance, grow-o-matic, tile systems
sys_items.lua                   ← item info, item effects, item browser, wands, consumables
sys_carnival.lua                ← semua carnival minigames
sys_hospital.lua                ← hospital, malady, vile vial
sys_events.lua                  ← fenrir, clash finale, seasonal events
sys_social.lua                  ← news, broadcast, missions, portal
sys_admin.lua                   ← reload, automation, give commands, scan tools
```

### Modules (Level 3) — Per System

**Carnival System** (`sys_carnival.lua`):
```
carnival_core.lua               ← shared state, prize system, getCarnivalWorld(), helpers
carnival_concentration.lua      ← Concentration R1 & R2
carnival_shooting.lua           ← Shooting Gallery R1 & R2
carnival_deathrace.lua          ← Death Race 5000
carnival_mirrormaze.lua         ← Mirror Maze
carnival_gulch.lua              ← Growganoth Gulch R1 & R2
carnival_spiky.lua              ← Spiky Survivor
carnival_bounce.lua             ← Brutal Bounce
carnival_ticket.lua             ← Ticket Booth (opsional, jika ada logic terpisah)
```

**Hospital System** (`sys_hospital.lua`):
```
hospital_core.lua               ← hospital main logic + callbacks
malady_rng.lua                  ← malady/curse RNG system
vile_vial.lua                   ← vile vial item logic
```

**Economy System** (`sys_economy.lua`):
```
economy_store.lua               ← store/shop system
economy_daily_reward.lua        ← daily reward
economy_buy.lua                 ← buy system
economy_cashback.lua            ← cashback coupon
economy_transfer.lua            ← transfer PWL
```

**Player System** (`sys_player.lua`):
```
player_backpack.lua             ← /bp, /backpack, /givebp, /editbp
player_item_categorizer.lua     ← module kategori item (dipakai backpack)
player_profile.lua              ← player profile display
player_starter_pack.lua         ← starter pack new player
player_login_message.lua        ← pesan login
player_default_slots.lua        ← default inventory slots
player_set_slots.lua            ← set slots command
player_titles.lua               ← custom titles system
player_skin.lua                 ← custom skin
```

**World System** (`sys_world.lua`):
```
world_rent_entrance.lua         ← rent entrance per-tile access system
world_grow_matic.lua            ← Grow-o-Matic farming machine
world_tile_extra.lua            ← tile extra data (surgeon station, vending, dll)
```

**Items System** (`sys_items.lua`):
```
items_info.lua                  ← item info editor + display (/editinfo)
items_effects.lua               ← item effects system (/effectadmin)
items_browser.lua               ← item browser (/items)
items_wands.lua                 ← fire wand, freeze wand, curse wand (combined)
items_consumables.lua           ← consumable items (coin, coconut tart, antidote, dll)
items_wolf_whistle.lua          ← wolf whistle item
```

**Events System** (`sys_events.lua`):
```
events_fenrir.lua               ← challenge of fenrir
events_clash_finale.lua         ← clash finale parkour
events_lb.lua                   ← leaderboard event
events_seasonal.lua             ← [FUTURE] halloween, christmas, dll
```

**Security System** (`sys_security.lua`):
```
security_anti_spam.lua          ← anti-spam system
security_anti_consumable.lua    ← anti-consumable
security_rate_limiter.lua       ← [FUTURE] rate limiting per-action
security_packet_check.lua       ← [FUTURE] packet validation
```

**Social System** (`sys_social.lua`):
```
social_news.lua                 ← news system
social_broadcast.lua            ← broadcast
social_missions.lua             ← marvelous missions
social_portal.lua               ← social portal
```

**Admin System** (`sys_admin.lua`):
```
admin_reload.lua                ← /reload command
admin_automation.lua            ← /auto menu
admin_autofarm.lua              ← autofarm speed booster
admin_give.lua                  ← /give commands (gems, level, skin, token, supporter)
admin_ban_wand.lua              ← ban wand tool
admin_scan.lua                  ← /bbscan, /ssscan dev utilities
admin_fakewarn.lua              ← fake warn tool
```

### Examples (TIDAK diupload)
```
examples/
├── blocks-drops-example.lua
├── tile-extra-example.lua
├── tile-wrench-example.lua
├── pot-o-gold-example.lua
├── roles-example.lua
├── say-example.lua
├── give-gems-command.lua
├── green-beer-consumable.lua
└── experimental-blocks.lua
```

---

## Pola Kode

### main.lua (Entry Point)

```lua
-- main.lua — Growtopia Multiverse Server
-- Entry point — dipanggil sekali saat server start / reloadScripts()

print("[main] ═══════════════════════════════")
print("[main] Loading Growtopia Multiverse...")
print("[main] ═══════════════════════════════")

-- ══════════════════════════════════════════
-- PHASE 1: Utils (wajib pertama, global)
-- ══════════════════════════════════════════
package.loaded["utils"]  = nil
package.loaded["config"] = nil
package.loaded["db"]     = nil

_G.Utils  = require("utils")
_G.Config = require("config")
_G.DB     = require("db")

print("[main] ✓ Utils loaded")

-- ══════════════════════════════════════════
-- PHASE 2: System Loaders (urutan penting!)
-- ══════════════════════════════════════════
local systems = {
    "sys_security",     -- [1] anti-cheat aktif duluan
    "sys_economy",      -- [2] store, currency
    "sys_player",       -- [3] backpack, profile (sebelum world)
    "sys_world",        -- [4] rent entrance, grow-o-matic (depend player)
    "sys_items",        -- [5] item info, effects, browser
    "sys_carnival",     -- [6] carnival minigames
    "sys_hospital",     -- [7] hospital system
    "sys_events",       -- [8] events & seasonal
    "sys_social",       -- [9] news, broadcast, missions
    "sys_admin",        -- [10] dev tools (terakhir)
}

local loaded, failed = 0, 0
for _, name in ipairs(systems) do
    package.loaded[name] = nil
    local ok, err = pcall(require, name)
    if ok then
        loaded = loaded + 1
        print("[main] ✓ " .. name)
    else
        failed = failed + 1
        print("[main] ✗ " .. name .. " — " .. tostring(err))
    end
end

print("[main] ═══════════════════════════════")
print("[main] Done: " .. loaded .. " loaded, " .. failed .. " failed")
print("[main] ═══════════════════════════════")
```

### System Loader (contoh sys_carnival.lua)

```lua
-- MODULE
-- sys_carnival.lua — Carnival system loader

local modules = {
    "carnival_core",
    "carnival_concentration",
    "carnival_shooting",
    "carnival_deathrace",
    "carnival_mirrormaze",
    "carnival_gulch",
    "carnival_spiky",
    "carnival_bounce",
}

-- Clear cache untuk reload support
for _, name in ipairs(modules) do
    package.loaded[name] = nil
end

-- Load modules dengan error isolation
local M = {}
for _, name in ipairs(modules) do
    local ok, result = pcall(require, name)
    if ok then
        M[name] = result
        print("  [carnival] ✓ " .. name)
    else
        print("  [carnival] ✗ " .. name .. " — " .. tostring(result))
    end
end

-- Export untuk cross-system access
_G.CarnivalSystem = M

return M
```

### Module (contoh carnival_bounce.lua)

```lua
-- MODULE
-- carnival_bounce.lua — Brutal Bounce minigame

local M = {}

-- Dependencies (sudah di-load global oleh main.lua)
local Utils  = _G.Utils
local Config = _G.Config

-- Module-specific state
local BB_ROOM = { ... }

-- Module functions
function M.startGame(world) ... end
function M.endGame(world, winnerUID) ... end

-- Register callbacks (module bertanggung jawab atas callback sendiri)
onPlayerEnterDoorCallback(function(world, player, targetWorld, doorID)
    -- handle BOUNCE01-04
end)

return M
```

### Utils Module (utils.lua)

```lua
-- MODULE
-- utils.lua — Shared utility functions

local M = {}

-- ═══ Format ═══
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

function M.formatTime(seconds)
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

-- ═══ Command Parsing ═══
function M.parseArgs(fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do
        table.insert(args, word)
    end
    return args
end

function M.getCmd(fullCommand)
    return (fullCommand:match("^%S+") or ""):lower()
end

-- ═══ Player Helpers ═══
function M.isPrivileged(player)
    return player:hasRole(51)
end

function M.isDev(player)
    return player:hasRole(52)
end

function M.uid(player)
    return tostring(player:getUserID())
end

-- ═══ World Helpers ═══
function M.isWorld(world, name)
    return world:getName():upper() == name:upper()
end

function M.tileToPixel(tileCoord)
    return (tileCoord - 1) * 32
end

function M.pixelToTile(pixel)
    return math.floor(pixel / 32) + 1
end

-- ═══ Safe Operations ═══
function M.safeBubble(world, player, text)
    world:onCreateChatBubble(
        player:getPosX(), player:getPosY() - 16,
        text, player:getNetID()
    )
end

-- ═══ Logger (dev console) ═══
function M.log(tag, msg)
    print("[" .. tag .. "] " .. tostring(msg))
end

function M.logError(tag, func, msg)
    print("[ERROR] " .. tag .. " > " .. func .. ": " .. tostring(msg))
end

return M
```

### Config Module (config.lua)

```lua
-- MODULE
-- config.lua — Global constants & settings

local C = {}

-- ═══ Worlds ═══
C.WORLDS = {
    CARNIVAL  = "CARNIVAL_2",
    HOSPITAL  = "HOSPITAL",
    -- tambah world lain di sini
}

-- ═══ Roles ═══
C.ROLES = {
    PLAYER    = 0,
    DEV       = 51,
    ADMIN     = 52,
}

-- ═══ Item IDs ═══
C.ITEMS = {
    GOLDEN_TICKET     = 1898,
    CARNIVAL_SPIKEBALL = 2568,
    -- tambah item lain di sini
}

-- ═══ Settings ═══
C.SETTINGS = {
    SAVE_INTERVAL     = 300,    -- 5 menit
    MAX_BACKPACK_DROP = 200,
    WITHDRAW_TAX      = 0.10,   -- 10%
}

return C
```

### DB Module (db.lua)

```lua
-- MODULE
-- db.lua — Database wrapper

local M = {}

-- ═══ Key-Value Storage ═══
function M.save(key, data)
    saveDataToServer(key, data)
end

function M.load(key)
    return loadDataFromServer(key) or {}
end

function M.saveString(key, value)
    saveStringToServer(key, value)
end

function M.loadString(key)
    return loadStringFromServer(key) or ""
end

-- ═══ File Storage ═══
function M.readFile(path)
    if not file.exists(path) then return nil end
    local content = file.read(path)
    if not content or content == "" then return nil end
    local ok, data = pcall(json.decode, content)
    return ok and data or nil
end

function M.writeFile(path, data)
    file.write(path, json.encode(data))
end

-- ═══ SQLite Wrapper ═══
function M.openDB(name)
    return sqlite.open(name)
end

return M
```

---

## Cross-System Communication

### Via Global (_G)

System loader meng-export ke `_G` untuk akses cross-system:

```lua
-- Di sys_player.lua:
_G.PlayerSystem = M           -- export
_G.BP_storeItem = function(player, itemID, count)  -- legacy compat
    M.player_backpack.storeItem(player, itemID, count)
end

-- Di sys_world.lua (depend on player):
local bpStore = _G.BP_storeItem   -- consume
```

### Aturan Cross-System
1. **Hanya expose yang perlu** — jangan export seluruh module
2. **Cek nil** — system yang gagal load = nil di _G
3. **Naming**: `_G.[SystemName]` untuk system table, `_G.[FUNC]` untuk legacy compat
4. **Utils, Config, DB** selalu tersedia via `_G.Utils`, `_G.Config`, `_G.DB`

---

## Architecture Rules

### 1. Satu File = Satu Tanggung Jawab
Setiap module hanya handle SATU fitur spesifik.
Jangan campur logic berbeda dalam satu file.

### 2. >500 Lines → Pecah
Kalau satu module lebih dari 500 baris, pertimbangkan untuk dipecah jadi sub-module.
Contoh: carnival.lua (3767 baris) → 8 module terpisah.

### 3. Max 3 Level Nesting
```
main.lua → sys_[system].lua → [module].lua
Level 1     Level 2            Level 3
```
JANGAN bikin level 4. Kalau butuh, flat-kan di level 3.

### 4. Utils = Jangan Dimodifikasi Per System
Utils bersifat UNIVERSAL. Kalau butuh helper khusus satu system,
buat sebagai function di module core system itu, bukan di utils.

### 5. Error Isolation via pcall
System loader WAJIB pakai `pcall(require, name)`.
Kalau satu module gagal, system lain tetap jalan.

### 6. Reload Support
Setiap loader WAJIB `package.loaded[name] = nil` sebelum `require()`.
Tanpa ini, `/rs` (reloadScripts) tidak memuat ulang module.

### 7. Load Order Matters
System yang di-depend HARUS diload duluan.
Urutan di main.lua BUKAN random — ada alasan untuk setiap posisi.

### 8. Callback Ownership
Setiap module register callback-nya sendiri.
JANGAN register callback module A dari dalam module B.

### 9. State Isolation
Module state = `local` di dalam module.
Share state antar module HANYA via explicit export ke `_G` atau return table.

### 10. Naming Strict
- File: `[system]_[feature].lua` — lowercase, underscore
- Global: `_G.[SystemName]` — PascalCase
- Local: `camelCase` untuk variables, `UPPER_SNAKE` untuk constants

---

## Migration Map — Current → New

### Phase 1: Utils + Main Loader (buat baru)
| New File | Source | Note |
|---|---|---|
| `main.lua` | — | Baru, entry point |
| `utils.lua` | Extract dari conventions.md patterns | Baru, shared helpers |
| `config.lua` | Extract constants dari semua script | Baru, global config |
| `db.lua` | Extract patterns dari semua script | Baru, db wrapper |

### Phase 2: Carnival Refactor (pecah carnival.lua)
| New File | Source | Note |
|---|---|---|
| `sys_carnival.lua` | — | Baru, loader |
| `carnival_core.lua` | carnival.lua (shared state, prize, helpers) | Extract |
| `carnival_concentration.lua` | carnival.lua (ROOMS section) | Extract |
| `carnival_shooting.lua` | carnival.lua (SG_ROOMS section) | Extract |
| `carnival_deathrace.lua` | carnival.lua (DR_ROOMS section) | Extract |
| `carnival_mirrormaze.lua` | carnival.lua (MM_ROOMS section) | Extract |
| `carnival_gulch.lua` | carnival.lua (GG_ROOMS section) | Extract |
| `carnival_spiky.lua` | carnival.lua (SS section) | Extract |
| `carnival_bounce.lua` | carnival.lua (BB section) | Extract |

### Phase 3: Hospital (sudah mendekati pola benar)
| New File | Source | Note |
|---|---|---|
| `sys_hospital.lua` | hospital_main.lua | Rename + adapt |
| `hospital_core.lua` | hospital.lua | Rename |
| `malady_rng.lua` | malady_rng.lua | Sudah module ✓ |
| `vile_vial.lua` | vile_vial.lua | Sudah module ✓ |

### Phase 4: Economy System
| New File | Source | Note |
|---|---|---|
| `sys_economy.lua` | — | Baru, loader |
| `economy_store.lua` | store.lua | Rename + add MODULE |
| `economy_daily_reward.lua` | daily-reward.lua | Rename + add MODULE |
| `economy_buy.lua` | buy.lua | Rename + add MODULE |
| `economy_cashback.lua` | cashbackCoupon.lua | Rename + add MODULE |
| `economy_transfer.lua` | TransferPWL.lua | Rename + add MODULE |

### Phase 5: Player System
| New File | Source | Note |
|---|---|---|
| `sys_player.lua` | — | Baru, loader |
| `player_backpack.lua` | Backpack.lua | Rename |
| `player_item_categorizer.lua` | item_categorizer.lua | Rename (sudah module ✓) |
| `player_profile.lua` | player-profile.lua | Rename + add MODULE |
| `player_starter_pack.lua` | starter-pack.lua | Rename + add MODULE |
| `player_login_message.lua` | login-message.lua | Rename + add MODULE |
| `player_default_slots.lua` | default-slots.lua | Rename + add MODULE |
| `player_set_slots.lua` | set-slots-command.lua | Rename + add MODULE |
| `player_titles.lua` | custom-titles.lua | Rename + add MODULE |
| `player_skin.lua` | cskin.lua | Rename + add MODULE |

### Phase 6: World System
| New File | Source | Note |
|---|---|---|
| `sys_world.lua` | — | Baru, loader |
| `world_rent_entrance.lua` | Rent_Entrance.lua | Rename + add MODULE |
| `world_grow_matic.lua` | GrowMatic.lua | Rename + add MODULE |
| `world_tile_extra.lua` | tile-extra-example.lua | Promote dari example |

### Phase 7: Items System
| New File | Source | Note |
|---|---|---|
| `sys_items.lua` | — | Baru, loader |
| `items_info.lua` | iteminfo.lua / ItemInfo.lua | Rename + add MODULE |
| `items_effects.lua` | itemeffectlua.lua | Rename + add MODULE |
| `items_browser.lua` | item_browser.lua | Rename + add MODULE |
| `items_wands.lua` | firewand + freezewand + cursewand | Combine + add MODULE |
| `items_consumables.lua` | consumablecoin + coconutTart + antidote | Combine + add MODULE |
| `items_wolf_whistle.lua` | wolf_whistle_.lua | Rename + add MODULE |

### Phase 8: Events System
| New File | Source | Note |
|---|---|---|
| `sys_events.lua` | — | Baru, loader |
| `events_fenrir.lua` | challenge_of_fenrir.lua | Rename + add MODULE |
| `events_clash_finale.lua` | clash_finale_parkour.lua | Rename + add MODULE |
| `events_lb.lua` | lbeventscript.lua | Rename + add MODULE |

### Phase 9: Security System
| New File | Source | Note |
|---|---|---|
| `sys_security.lua` | — | Baru, loader |
| `security_anti_spam.lua` | anti-spam.lua | Rename + add MODULE |
| `security_anti_consumable.lua` | anti_consumable.lua | Rename + add MODULE |

### Phase 10: Social System
| New File | Source | Note |
|---|---|---|
| `sys_social.lua` | — | Baru, loader |
| `social_news.lua` | news.lua | Rename + add MODULE |
| `social_broadcast.lua` | broadcast.lua | Rename + add MODULE |
| `social_missions.lua` | marvelous-missions.lua | Rename + add MODULE |
| `social_portal.lua` | socialportal.lua | Rename + add MODULE |

### Phase 11: Admin System
| New File | Source | Note |
|---|---|---|
| `sys_admin.lua` | — | Baru, loader |
| `admin_reload.lua` | reload-command.lua | Rename + add MODULE |
| `admin_automation.lua` | automation_menu.lua | Rename + add MODULE |
| `admin_autofarm.lua` | autofarm_speed.lua | Rename + add MODULE |
| `admin_give.lua` | Givelevel + GiveServerToken + GiveSupporter + giveskin | Combine |
| `admin_ban_wand.lua` | banwand.lua | Rename + add MODULE |
| `admin_scan.lua` | bb_scan.lua | Rename + add MODULE |
| `admin_fakewarn.lua` | fakewarn.lua | Rename + add MODULE |

### Scripts Belum Dikategorikan
```
ball.lua                ← perlu investigasi
BALOON.lua              ← perlu investigasi
gsm.lua                 ← perlu investigasi
onlinealbin.lua         ← perlu investigasi
Xqsb.lua               ← perlu investigasi
Ringmastered.lua        ← perlu investigasi
fireworks.lua           ← items atau events?
ducttape.lua            ← items?
```

---

## Future Systems (Placeholder)

Sistem yang belum ada tapi sudah disiapkan slot-nya:

| System | Loader | Modules (planned) | Use Case |
|---|---|---|---|
| Quest | `sys_quest.lua` | `quest_core`, `quest_daily`, `quest_weekly` | Quest/achievement system |
| Guild | `sys_guild.lua` | `guild_core`, `guild_war`, `guild_bank` | Guild management |
| Trading | `sys_trading.lua` | `trading_core`, `trading_auction` | Player-to-player trading |
| Anticheat (advanced) | Expand `sys_security` | `security_speed_check`, `security_noclip` | Packet-level validation |
| Seasonal | Expand `sys_events` | `events_halloween`, `events_christmas` | Rotating seasonal content |
| PvP | `sys_pvp.lua` | `pvp_arena`, `pvp_ranking` | PvP arena system |
| Gacha | Expand `sys_economy` | `economy_gacha`, `economy_spinner` | Randomized reward system |
| Crafting | `sys_crafting.lua` | `crafting_core`, `crafting_recipes` | Item crafting system |

---

## Dependency Graph

```
           ┌──────────┐
           │ main.lua │
           └────┬─────┘
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
 utils.lua  config.lua   db.lua         ← GLOBAL (semua system akses)
    │           │           │
    └───────────┼───────────┘
                │
    ┌───────────┼───────────────────────────────┐
    ▼           ▼           ▼           ▼       ▼
sys_security sys_economy sys_player sys_world  ...
                            │           │
                            └─────┬─────┘
                                  │
                         _G.BP_storeItem
                      (cross-system dependency)
```

---

## Checklist Sebelum Bikin Module Baru

- [ ] File dimulai dengan `-- MODULE` di baris pertama
- [ ] Nama file ikut naming convention: `[system]_[feature].lua`
- [ ] Module return table (`return M`)
- [ ] Sudah didaftarkan di system loader (`sys_[system].lua`)
- [ ] `package.loaded` di-nil di system loader
- [ ] Pakai `_G.Utils`, `_G.Config`, `_G.DB` untuk shared functions
- [ ] State module = `local` (tidak bocor ke global kecuali explicit export)
- [ ] Callback register di dalam module sendiri
- [ ] Storage key pakai prefix `MULTIVERSE_[SYSTEM]_[FEATURE]_V[N]`
- [ ] Sudah update migration map di docs/structure.md
