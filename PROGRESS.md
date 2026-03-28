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
- ✅ Stub loader WAJIB `return {}` — meskipun isinya hanya print skip
- `logger` di-require langsung dari `main.lua` (bukan via loader) karena sama-sama single require

---

> **✅ FULL LOAD CONFIRMED 2026-03-27** — "Loaded 1 Lua scripts", 14 loaders sukses.
> profile.lua: backpack → `_G.BP_openBackpack` ✅, cheats → `_G.GM_openCheatMenu` ✅, marvelous_missions → `_G.openMarvelousMissions` ✅
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

### Hospital
| File | Dari | Keterangan |
|------|------|------------|
| `hospital_loader.lua` | — | ✅ stub ada (`return {}`), belum implementasi |
| `reception_desk.lua` | `hospital_reception_desk.lua` | |
| `operating_table.lua` | `hospital_operating_table.lua` | |
| `auto_surgeon.lua` | `hospital_auto_surgeon.lua` | |
| `malady_rng.lua` | `malady_rng.lua` | `_G.MaladySystem` undefined — vile_vial & automation_menu ada guard, aman |
| `hospital_main.lua` | `hospital_main.lua` | |

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
