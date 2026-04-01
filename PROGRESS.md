# PROGRESS.md — Growtopia Multiverse
> Baca di awal setiap sesi. Update sebelum compact/tutup.

---

## Status Server
**Platform:** GTPS Cloud by Sebia
**Server Admin (beta):** 4134 — **Server Main:** 4552
**Reload:** `/rs` in-game

## Struktur Folder
```
lua scripts (old architecture)/            ← REFERENSI saja, jangan edit
lua scripts (nested loader architecture)/  ← TARGET aktif
scripts/                                   ← deprecated mirror, abaikan
```

---

## Arsitektur: Nested Loader
```
main.lua → [feature]_loader.lua → [object].lua
```
**Load order di main.lua:**
```
logger → security → economy → player → machine → item_info →
consumable → backpack → carnival → hospital → events →
social → admin → standalones
```

### ⚠️ GTPS Cloud Lua Sandbox — Confirmed 2026-03-27
- ❌ `pcall` = TIDAK ADA — jangan pernah pakai
- ❌ `package` / `package.loaded` = TIDAK ADA — jangan pernah pakai
- ✅ `require()` tersedia (custom GTPS Cloud), nested require didukung
- ✅ Loop pattern `for _, name in ipairs(modules) do M[name] = require(name) end` = WAJIB di setiap loader
- ❌ Single direct `require("x")` di loader = CRASH — selalu pakai loop meski hanya 1 modul
- ❌ Module/loader yang return `nil` (tidak ada `return`) = CRASH "attempt to index a nil value"
- ❌ Path folder di require = `invalid module name` error — gunakan nama file saja: `require("carnival_shared")` bukan `require("lua scripts .../carnival_shared")`
- ✅ Stub loader WAJIB `return {}` — meskipun isinya hanya print skip
- `logger` di-require langsung dari `main.lua` (bukan via loader) karena sama-sama single require

---

> **✅ FULL LOAD CONFIRMED 2026-03-27** — "Loaded 1 Lua scripts", 14 loaders sukses.
> **✅ CARNIVAL SYSTEM SELESAI 2026-03-28** — 10 modul, carnival_loader aktif.
> Cross-reference audit: semua _G.* valid. Hanya `_G.MaladySystem` belum ada (pending hospital).

---

## ✅ SELESAI

### Fondasi
| File | Status |
|------|--------|
| `main.lua` | ✅ server guard (4134/4552) + anti-theft + load semua loaders |
| `utils.lua` | ✅ `_G.Utils` |
| `config.lua` | ✅ `_G.Config` |
| `db.lua` | ✅ `_G.DB` — JSON only, SQLite pending |

### Logger
| File | Status |
|------|--------|
| `logger_loader.lua` | ✅ dimuat pertama setelah fondasi |
| `logger.lua` | ✅ `_G.Logger` — in-memory buffer 50 entries, `/errorlog` (role 51), `/errorlog clear` |

> Semua loader sudah terintegrasi: gagal load → `_G.Logger.error(...)`.

### Security + Player
| Feature | Loader | Modul |
|---------|--------|-------|
| security | `security_loader.lua` ✅ | `anti_spam.lua` ✅ |
| player | `player_loader.lua` ✅ | `login_message.lua` ✅ `default_slots.lua` ✅ `starter_pack.lua` ✅ `profile.lua` ✅ `set_slots.lua` ✅ `custom_titles.lua` ✅ `custom_help.lua` ✅ |

### Economy + Machine
| Feature | Loader | Modul |
|---------|--------|-------|
| economy | `economy_loader.lua` ✅ | `store.lua` ✅ `daily_reward.lua` ✅ `cashback_coupon.lua` ✅ `transfer_pwl.lua` ✅ |
| machine | `machine_loader.lua` ✅ | `rent_entrance.lua` ✅ `grow_matic.lua` ✅ |

### Item Info
| Feature | Loader | Modul |
|---------|--------|-------|
| item_info | `item_info_loader.lua` ✅ | `item_categorizer.lua` ✅ `item_browser.lua` ✅ `item_info.lua` ✅ |

### Consumable (semua selesai)
| Feature | Loader | Modul |
|---------|--------|-------|
| consumable | `consumable_loader.lua` ✅ | `green_beer.lua` ✅ `coconut_tart.lua` ✅ `consumable_coin.lua` ✅ `antidote.lua` ✅ `vile_vial.lua` ✅ `firewand.lua` ✅ `freezewand.lua` ✅ `cursewand.lua` ✅ `banwand.lua` ✅ `duct_tape.lua` ✅ `fireworks.lua` ✅ `autofarm_speed.lua` ✅ `challenge_fenrir.lua` ✅ `clash_finale.lua` ✅ `wolf_whistle.lua` ✅ |

> `freezewand.lua`: `StateFlags.STATE_FROZEN` diomit (tidak ada di API docs), `modState = {}`.

### Backpack
| Feature | Loader | Modul |
|---------|--------|-------|
| backpack | `backpack_loader.lua` ✅ | `backpack.lua` ✅ |

### Events
| Feature | Loader | Modul |
|---------|--------|-------|
| events | `events_loader.lua` ✅ | `lb_event.lua` ✅ |

### Social
| Feature | Loader | Modul |
|---------|--------|-------|
| social | `social_loader.lua` ✅ | `social_portal.lua` ✅ `news.lua` ✅ `broadcast.lua` ✅ |

### Admin
| Feature | Loader | Modul |
|---------|--------|-------|
| admin | `admin_loader.lua` ✅ | `give_token.lua` ✅ `give_supporter.lua` ✅ `give_level.lua` ✅ `give_skin.lua` ✅ `give_gems.lua` ✅ `fake_warn.lua` ✅ `online.lua` ✅ `reload.lua` ✅ `bb_scan.lua` ✅ `gsm.lua` ✅ `xqsb.lua` ✅ `tile_debug.lua` ✅ `item_effect.lua` ✅ |

### Standalones
| Feature | Loader | Modul |
|---------|--------|-------|
| marvelous missions | `marvelous_missions_loader.lua` ✅ | `marvelous_missions.lua` ✅ |
| automation menu | `automation_menu_loader.lua` ✅ | `anti_consumable.lua` ✅ `automation_menu.lua` ✅ |

---

## 🔲 BELUM SELESAI

### Carnival ✅ SELESAI
| File | Dari | Status |
|------|------|--------|
| `carnival_loader.lua` | — | ✅ load 10 modul |
| `carnival_shared.lua` | `carnival.lua` | ✅ shared constants, helpers, prize system, registry |
| `concentration.lua` | `carnival.lua` | ✅ 2 rooms, card flip, solo queue |
| `shooting_gallery.lua` | `carnival.lua` | ✅ 2 rooms, bullseye toggle, solo queue |
| `death_race.lua` | `carnival.lua` | ✅ 1 room, multiplayer, checkpoint system |
| `mirror_maze.lua` | `carnival.lua` | ✅ 1 room, recursive backtracker maze, solo queue |
| `growganoth_gulch.lua` | `carnival.lua` | ✅ 2 rooms, platform+eye toggle, solo queue |
| `spiky_survivor.lua` | `carnival.lua` | ✅ 1 room, multiplayer survival, platform toggle |
| `brutal_bounce.lua` | `carnival.lua` | ✅ 1 room, multiplayer last-man-standing, spikeball punch |
| `ticket_booth.lua` | `TicketBooth_Carnival.lua` | ✅ rarity exchange → Golden Tickets, 3-step dialog |
| `ringmaster.lua` | `Ringmastered.lua` | ✅ 20 quest types, 10 steps, admin dialogs |

### Hospital ✅ SELESAI + Surgery Minigame ✅ SELESAI 2026-03-31
| File | Dari | Status |
|------|------|--------|
| `hospital_loader.lua` | — | ✅ load 5 modul |
| `malady_rng.lua` | `malady_rng.lua` | ✅ `_G.MaladySystem`, 12 maladies |
| `hospital.lua` | `hospital.lua` | ✅ `_G.HospitalSystem`, constants + DB + helpers |
| `reception_desk.lua` | `hospital_reception_desk.lua` | ✅ owner panel, manage doctors |
| `operating_table.lua` | `hospital_operating_table.lua` | ✅ 3 visual states + event-driven tick + prize panel + surgery minigame |
| `surgery_loader.lua` | — | ✅ load 5 surgery modul (+ surgprize) |
| `surgery_data.lua` | — | ✅ 28 diagnoses + 7-level pulse + modifiers + exact GT fail messages + headline texts |
| `surgery_engine.lua` | — | ✅ session management + unified win check + special events + Lab Kit reveal |
| `surgery_ui.lua` | — | ✅ sequential tool grid + story headline + fever/bleeding rows + heart stopped warning |
| `surgery_callbacks.lua` | — | ✅ dialog callbacks + DB prize pool + 3 reward flavor messages + allowedDiags |
| `surgprize.lua` | — | ✅ /surgprize panel UI per-diagnosis, 5 slots, item picker |
| `auto_surgeon.lua` | `hospital_auto_surgeon.lua` | ✅ auto-cure + tile extra data visual |

**Surgery Minigame — Status 2026-04-01, updated via real GT debug + full audit:**
- 28 diagnoses: 17 standard + 5 malady + 6 vile vial ✅ (MONKEY_FLU ditambah)
- Story headline system: storyHeadline per milestone (diagRevealed via Lab Kit/Ultrasound, scalpelHeadline, fixItHeadline) ✅
- Lab Kit reveal: set storyHeadline jika needsUltrasound=false ✅
- ANTIBIOTICS: availability check pakai `abxUnlocked` (bukan `labKitUsed`) ✅
- Diagnoses dengan confirmed headlines (dari GT debug): FLU, MONKEY_FLU, BROKEN_LEG, APPENDICITIS, KIDNEY_FAILURE, BRAIN_TUMOR, SWALLOWED_WL, HERNIATED_DISC, SERIOUS_TRAUMA, NOSE_JOB, MASSIVE_TRAUMA, SERIOUS_HEAD, HEART_ATTACK ✅
- Diagnoses **tanpa headline** (belum ada GT debug data): LIVER_INFECTION, BROKEN_EVERYTHING, semua malady, semua vile_vial
- Splint available dari awal (tidak perlu bonesRevealed) ✅
- Bones row: hidden sepenuhnya sebelum ultrasound ✅
- allowedDiags cfg: operating_table hanya pakai DIAG_KEYS_STANDARD (17 penyakit) ✅
- Prize pool: DB-based per diagnosis via /surgprize, Caduceus wajib + random prize ✅
- 3 reward flavor messages (random) ✅
- Success + Fail: result panel muncul di keduanya ✅
- Heart stopped: consLabel "Heart `4stopped!" + extra spacer + warning row ✅
- FLU: tempRiseFast=true → "climbing fast!" dari awal ✅
- Exact GT tool success & fail messages: semua 14 tool confirmed ✅
- cleanLabel color: SLIGHTLY_DIRTY=`3, DIRTY=`6, UNSANITARY=`4 ✅ (swap fixed)
- COMING_TO consLabel: `6 warna, tanpa move count ✅
- INTENSE bleeding row: "Extremely Fast" bukan "intensely" ✅
- feverRow: return nil jika tempRising=false ✅
- CHAOS_INFECTION: requiredScalpels=0 (bukan 3, orphaned) ✅
- HERNIATED_DISC: fixItHeadline ditambah ✅
- getSurgeonSkill: 1 read per move (tidak double) ✅
- getItem() (bukan getItemById) ✅
- role_inject.lua: item 25036 = role 51, 25038 = role 0 ✅

**Surgery UI confirmed via GT debug (2026-04-01):**
- Tool order (re-confirmed GT debug SERIOUS_HEAD 2026-04-01): Sponge, Scalpel, Stitches, Antibiotics, Antiseptic, Fix It!, Ultrasound, Lab Kit, Anesthetic, Defibrillator, Splint, Pins, Clamp, Transfusion ✅
- Sequential layout (END_LIST), client auto-wrap, text_scaling_string|Defibrillator ✅
- add_smalltext pakai |left| alignment pada semua baris di surgery panel ✅
- cleanLabel confirmed: SLIGHTLY_DIRTY=`3"Not sanitized", DIRTY=`6"Unclean", UNSANITARY=`4"Unsanitary" ✅
- Scalpel SUCCESS tidak naikan bleeding (hanya skill fail +2) ✅
- HEART_ATTACK: needsUltrasound=true, initialTemp=98.6, tempRising=false, initialPulse=STRONG ✅
- Bleeding row SEBELUM spacer, fever row SEBELUM spacer ✅
- "prepped for surgery" hanya muncul jika lastMsg DAN contextMsg kosong ✅
- Operation site: lowercase 's' ✅
- Incision color: `2 kalau 0, `3 kalau >0 ✅

**Operating Table Tick — Status 2026-03-31 ✅ OPTIMIZED:**
- Event-driven: tick fire tepat saat `readyAt` tiba via `_G._OT_nextEvent` ✅
- Full tile scan (`world:getTiles()`) hanya 1x per 5 menit (stale insurgery cleanup) ✅
- `swapTile()` langsung di `onSurgeryEnd` — tidak ada delay ✅
- `loadAllStates()` 1x read + 1x write per operasi (tidak ada double read) ✅
- Dead code dihapus: `rollPrizes`, `getSurgeonSkill`, `addSurgeonSkill`, `isOwnerOrDev`, stubs ✅
- `hospital.lua`: hapus `processOperatingTablesInWorld`, `getOperatingStateRow`, empty tick block ✅

**Tile Extra Data (auto_surgeon.lua) — Updated 2026-03-28:**
- Pakai GTPS Cloud internal keys: `"outOfOrder"`, `"selectedIllness"`, `"wlCount"` (BUKAN XML variable names)
- `TILE_FLAG_HAS_EXTRA_DATA` JANGAN pernah di-set manual → crash client Growtopia untuk item 14662
- `world:getTile(x, y)` butuh **tile coords** (pixel ÷ 32), BUKAN pixel coords dari `tile:getPosX()`
- Urutan kritis: panggil `showDialog` dulu, baru `refreshAutoSurgeonTileVisual` → jika terbalik, client drop tile update karena dialog packet datang bersamaan
- `BinaryWriter` adalah table (bukan function) → cek `== nil` bukan `type() ~= "function"`

**Tile Extra Data (operating_table.lua) — Confirmed 2026-03-29:**
- `onGetTileExtraDataCallback` untuk item 14662 hanya fire saat **world load** (re-enter), BUKAN dari `world:updateTile`
- `world:updateTile` dengan `flags=0` → callback TIDAK fire (konfirmasi via xdata_debug `/xtest`)
- Set `TILE_FLAG_HAS_EXTRA_DATA` manual + `world:updateTile` → **crash client Growtopia**
- `return nil` dari callback → GTPS native handle → surgbot visual (default item 14662)
- `return false` dari callback → override native, kirim no data → empty bed visual
- `return data(isABed=0x01)` → empty bed visual
- `BinaryWriter` nil di dalam `onGetTileExtraDataCallback` — HARUS pre-build di `onWorldTick` atau `onPlayerCommandCallback`
- Pre-build pattern: `_tryBuildData()` dipanggil dari `onWorldTick` (fire ~100ms setelah start, sebelum player join)

**Operating Table Item IDs — Confirmed 2026-03-30:**
- `25030` = empty bed (item baru, plain tile tanpa extra data dependency) — BUKAN 14662
- `25026` = surgbot idle
- `25028` = in-surgery animation
- `swapTile()` dipanggil langsung di `onSurgeryEnd` — 25030 plain item, works dari context manapun ✅
- `_G._OT_nextEvent[worldName] = readyAt` di `onSurgeryEnd` → tick fire tepat waktu cooldown habis ✅
- `onTilePlaceCallback` block placement 25026 & 25028 secara manual
- `countOperatingTables` di hospital.lua hitung ketiga state (25030 + 25026 + 25028) anti-bypass

**Dialog Callback (auto_surgeon.lua) — Confirmed 2026-03-28:**
- ❌ Inline callback `player:onDialogRequest(d, 0, function...end)` = TIDAK PERNAH dipanggil di GTPS Cloud
- ✅ Semua dialog handling WAJIB pakai `onPlayerDialogCallback` global
- Dialog name encode x,y: `"autosurgeon_owner_v5m_" .. x .. "_" .. y` → parse dengan pattern `_(%d+)_(%d+)$`
- Tool panel punya 3 angka: `_(%d+)_(%d+)_(%d+)$` → handle duluan sebelum pattern 2-angka

**Bug Fixes (hospital.lua) — 2026-03-28:**
- Reception desk: player biasa dapat owner panel → fix: hapus `else showReceptionDeskPanel` (visitor dapat bubble saja)
- "Unhandled dialog" warnings: semua dialog yang kita "own" harus `return true` di akhir (bukan `return false`)
- Warning dialog auto_surgeon: `onDialogRequest(warn, 0, function() end)` untuk suppress warning

**Native GT Items dengan Tile Extra Data (confirmed via xdata_debug):**
- Vending Machine: 2978 | Digivend Machine: 9268 | Magplant 5000: 5638
- Unstable Tesseract: 6948 | Tesseract Manipulator: 6952 | Gaia's Beacon: 6946
- `onGetTileExtraDataCallback` fire untuk semua item ini saat player enter + saat `world:updateTile` dipanggil

### UI Experiment — Overlay Icon Pattern (✅ Confirmed 2026-03-28)

`ui_test.lua` — test script untuk eksperimen dialog UI, command `/panel`, di-load dari `main.lua`.

**Pattern overlay icon di pojok kiri atas `staticGreyFrame` button (C1 = winner):**
```
add_button_with_icon|btn|LABEL|staticGreyFrame,is_count_label|MAIN_ID|SIZE|
add_custom_button||display:block;height:1px;width:1.0;state:disabled;|
reset_placement_x|
add_custom_button||icon:OVERLAY_ID;width:0.10;margin-top:-80px;state:disabled;|
add_custom_break|
```
- Kedua icon = **item ID** (integer)
- `margin-left` TIDAK bekerja di `add_custom_button`
- Icon overlay dirender SETELAH button → z-order ON TOP

---

## Broadcast Console Style (✅ Confirmed 2026-04-01)

- Referensi utama: `docs/broadcast-console-style.md`
- Echo command client (contoh `/lsb a`) adalah bawaan client, bukan output script server.
- Echo command client tidak bisa di-overwrite/hapus pakai `gsub` dari Lua server.
- Gunakan `sendVariant({"OnConsoleMessage", "CT:[SB] ..."})` untuk output broadcast agar style custom muncul.
- Hindari kirim echo command tambahan dari script karena akan terlihat dobel di console.
- Untuk pesan sistem internal (contoh potong gems/sukses command), gunakan `onConsoleMessage` default jika ingin tampil sebagai system message.

---

## Registry — Jangan Duplikasi

### Storage Keys
| Key | File | Tipe |
|-----|------|------|
| `"GROWMATIC"` | `grow_matic.lua` | `DB.save/load` |
| `"ITEM_INFOS_V3"` | `item_info.lua` | `DB.saveStr/loadStr` |
| `"cashback_gems"` | `cashback_coupon.lua` | `DB.saveStr/loadStr` |
| `"ITEM_EFFECTS_V2_4552"` | `item_effect.lua` | `DB.saveStr/loadStr` |
| `"fenrir_rewards_v1"` | `challenge_fenrir.lua` | `DB.save/load` |
| `"finale_claims_rewards_v1"` | `clash_finale.lua` | `DB.saveStr/loadStr` |
| `"autofarm_boost_12" + uid` | `autofarm_speed.lua` | `DB.saveStr/loadStr` per-player |
| `"autofarm_custom_delay_1212" + uid` | `autofarm_speed.lua` | `DB.saveStr/loadStr` per-player |
| `"marvelous-missions"` | `marvelous_missions.lua` | `DB.save/load` |
| `"CARNIVAL_PRIZE_V1"` | `carnival_shared.lua` | `saveDataToServer/loadDataFromServer` |
| `"RINGMASTER_QUEST_DATA_V2"` | `ringmaster.lua` | `saveDataToServer/loadDataFromServer` |
| `"RINGMASTER_CONFIG_DATA_V2"` | `ringmaster.lua` | `saveDataToServer/loadDataFromServer` |
| `rent_entrance.json` | `rent_entrance.lua` | `DB.loadFeature/saveFeature` |
| `vile_vial.json` | `vile_vial.lua` | `DB.loadFeature/saveFeature` |
| `backpack.json` | `backpack.lua` | `DB.loadFeature/saveFeature` |
| `surg_prize` | `surgprize.lua` | `DB.loadFeature/saveFeature` |
| `surgeon_skill` | `surgery_callbacks.lua` | `DB.getPlayer/setPlayer` per-player |

### Commands
| Command | File | Role |
|---------|------|------|
| `/transfer` | `transfer_pwl.lua` | 0 |
| `/setcashback` | `cashback_coupon.lua` | 51 |
| `/getdaily` | `daily_reward.lua` | 51 |
| `/editinfo` | `item_info.lua` | 51 |
| `/items` `/itemscompact` | `item_browser.lua` | 0 |
| `/setslots` | `set_slots.lua` | 51 |
| `/titles` | `custom_titles.lua` | 0 |
| `/help` `/?` | `custom_help.lua` | 0 |
| `/backpack` `/bp` `/givebp` `/editbp` | `backpack.lua` | 0/51 |
| `/auto` | `automation_menu.lua` | 0 |
| `/effectadmin` | `item_effect.lua` | 51 |
| `/boostinfo` | `autofarm_speed.lua` | 0 |
| `/clearboost` `/setbasedelay` | `autofarm_speed.lua` | 52 |
| `/fenrirconfig` | `challenge_fenrir.lua` | 51 |
| `/finaleconfig` `/finale` | `clash_finale.lua` | 51 |
| `/wolf` | `wolf_whistle.lua` | 51 |
| `/lbevent` | `lb_event.lua` | 51 |
| `/givetoken` `/removetoken` | `give_token.lua` | 51 |
| `/givesupp` `/giveinv` | `give_supporter.lua` | 51 |
| `/givelevel` | `give_level.lua` | 51 |
| `/giveskin` | `give_skin.lua` | 51 |
| `/givegems` | `give_gems.lua` | 51 |
| `/fakewarn` | `fake_warn.lua` | 51 |
| `/online` | `online.lua` | 51 |
| `/rs` `/reloadscripts` | `reload.lua` | 51 |
| `/bbscan` | `bb_scan.lua` | 51 |
| `/gsm` | `gsm.lua` | 51 |
| `/qsb` | `xqsb.lua` | 51/7/6 |
| `/tile` | `tile_debug.lua` | 51 |
| `/news` | `news.lua` | 0 |
| `/lsb` `/osb` `/ssb` `/scsb` | `broadcast.lua` | varies |
| `/errorlog` | `logger.lua` | 51 |
| `/carnivalprize` `/carnivalreset` | `carnival_shared.lua` | 51 |
| `/surgprize` | `surgprize.lua` | 51 |
| `/sbtest` | `sbtest.lua` (standalone) | 51 |

### Cross-Feature References
| Reference | Dibuat oleh | Dipakai oleh |
|-----------|-------------|--------------|
| `_G.Logger` | `logger.lua` | semua loader |
| `_G.Utils` | `utils.lua` | semua |
| `_G.Config` | `config.lua` | semua |
| `_G.DB` | `db.lua` | semua |
| `_G.ItemCategorizer` | `item_categorizer.lua` | `backpack.lua` |
| `_G.CarnivalShared` | `carnival_shared.lua` | semua game modul carnival |
| `_G.MaladySystem` | `malady_rng.lua` (belum port) | `vile_vial.lua` `automation_menu.lua` |
| `_G.BP_storeItem` | `backpack.lua` | `grow_matic.lua` |
| `_G.BP_openBackpack` | `backpack.lua` | `profile.lua` |
| `_G.GM_openCheatMenu` | `automation_menu.lua` | `profile.lua` |
| `_G.openMarvelousMissions` | `marvelous_missions.lua` | `profile.lua` |
| `_G.itemEffects` | `item_effect.lua` | `item_info.lua` |
| `_G.getItemEffectFarmSpeedBoost` | `item_effect.lua` | `autofarm_speed.lua` |
| `_G.TileDebug` | `tile_debug.lua` | — |
| `_G.isAutofarmBoostSystemActive` | `autofarm_speed.lua` | — |
| `_G.getPlayerBoostMultiplier` | `autofarm_speed.lua` | — |
| `_G.getPlayerBoostedDelay` | `autofarm_speed.lua` | — |
