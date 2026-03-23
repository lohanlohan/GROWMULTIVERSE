# PROGRESS.md — Growtopia Multiverse
> File ini WAJIB dibaca di awal setiap sesi coding baru
> WAJIB diupdate sebelum close/compact session
> Setiap fitur punya section TERPISAH — jangan campur

---

## Cara Pakai

**Awal sesi:**
```
Baca CLAUDE.md, PROGRESS.md, dan docs/conventions.md
dulu sebelum kita mulai. Konfirmasi sudah baca.
```

**Akhir sesi (sebelum compact/tutup):**
```
Update PROGRESS.md — update HANYA section fitur
yang kita kerjakan tadi. Jangan ubah section lain.
```

---

## Status Server

**Status:** Development — fokus core features
**Platform:** GTPS Cloud by Sebia
**Reload script:** `/rs` in-game

---

## Registry — Jangan Duplikasi!

### Storage Keys yang Sudah Dipakai
```
"marvelous-missions"         → marvelous-missions.lua
"QUEST_DEPOSIT_DATA"         → examplequest.lua
"ENCHANTED_DROPS_[ID]V"      → itemeffectlua.lua
"ITEM_EFFECTS_V2_4552"       → itemeffectlua.lua
"ITEM_INFOS_V3"              → iteminfo.lua
"CARNIVAL_PRIZE_V1"          → carnival.lua  (semua minigame prizes)
"fenrir_rewards_v1"          → challenge_of_fenrir.lua
"finale_claims_rewards_v1"   → clash_finale_parkour.lua  (string format)
"rent_entrance_data.json"    → Rent_Entrance.lua  (file JSON)
```

### Commands yang Sudah Terdaftar
```
/deleteaccount  → delaccount.lua        (role 52)
/quest          → examplequest.lua      (role 0)
/effectadmin    → itemeffectlua.lua     (role 51)
/editinfo       → iteminfo.lua          (role 51)
/backpack, /bp  → Backpack.lua          (role 0)
/givebp         → Backpack.lua          (role 51)
/editbp         → Backpack.lua          (role 51)
/auto           → automation_menu.lua   (role 0)
/carnivalprize      → carnival.lua  (role 51) — prize manager semua minigame
/carnivalreset [N]  → carnival.lua  (role 51) — reset room N atau semua
```

### Scripts yang Sudah Ada

**Core / Active:**
```
carnival.lua             ✅ Done  — Carnival (Prize Manager + Concentration R1&2 + Shooting Gallery R1)
Backpack.lua             ✅ Done  — /bp /backpack /givebp /editbp
GrowMatic.lua            ✅ Done  — core server script
Rent_Entrance.lua        ✅ Done  — rent entrance system
anti-spam.lua            ✅ Done  — anti spam
anti_consum.lua          ✅ Done  — anti consumable standalone
autofarm_speed.lua       ✅ Done  — autofarm speed booster
automation_menu.lua      ✅ Done  — /auto cheat menu
buy.lua                  ✅ Done  — buy system
challenge_of_fenrir.lua  ✅ Done  — event challenge
clash_finale_parkour.lua ✅ Done  — parkour event
daily-reward.lua         ✅ Done  — daily reward
default-slots.lua        ✅ Done  — default inventory slots
hospital.lua             ✅ Done  — hospital system
hospital_main.lua        ✅ Done  — hospital main UI
item_browser.lua         ✅ Done  — /items browser
item_categorizer.lua     ✅ Done  — module kategori item (dipakai Backpack)
itemeffectlua.lua        ✅ Done  — /effectadmin item effects
iteminfo.lua             ✅ Done  — /editinfo + effects display
login-message.lua        ✅ Done  — pesan saat login
malady_rng.lua           ✅ Done  — malady/curse system
marvelous-missions.lua   ✅ Done  — mission system
news.lua                 ✅ Done  — news system
player-profile.lua       ✅ Done  — profile player
reload-command.lua       ✅ Done  — /reload command
set-slots-command.lua    ✅ Done  — set inventory slots
starter-pack.lua         ✅ Done  — starter pack new player
store.lua                ✅ Done  — store system
vile_vial.lua            ✅ Done  — vile vial item
wolf_whistle_.lua        ✅ Done  — wolf whistle item
```

**Example / Template (tidak diload ke server):**
```
blocks-drops-example.lua
experimental-blocks.lua
give-gems-command.lua
green-beer-consumable.lua
pot-o-gold-example.lua
roles-example.lua
say-example.lua
tile-wrench-example.lua
```

---

## ════════════════════════════════════
## FITUR: Carnival Minigames — carnival.lua
## ════════════════════════════════════

**File:** `scripts/carnival.lua`
**Storage Key:** `"CARNIVAL_PRIZE_V1"`
**World:** `CARNIVAL_2`
**Status:** ✅ Done (Concentration R1&2 + Shooting Gallery R1)

### Minigames Implemented
```
Concentration      — Room 1 (CONCENTRATION01-03) + Room 2 (CONCENTRATION04-06) ✅
Shooting Gallery   — Room 1 (SHOOTING01-03) ✅ | Room 2 coords belum diterima
Shooting Gallery   — Room 2: tambah entry ke SG_ROOMS saat dapat coords
```

### Prize System
```
/carnivalprize  — open prize manager (role 51)
/carnivalreset [N] — reset Concentration room N atau semua game (role 51)
Storage: CARNIVAL_PRIZE_V1 — 8 minigame × 3 tier (Common/Rare/Epic)
Prize: weighted random 65%/30%/5%, configurable per minigame via dialog
```

### Carnival Rules (shared semua minigame)
```
- Golden Ticket (ID 1898) deduct 1 saat masuk queue
- Tidak punya tiket → blocked + bubble error
- Queue per room, FIFO, delay 3 detik antar player
- Active player only di game area (snap kick setiap 1 detik)
- Disconnect mid-game → state cleanup + queue lanjut (tiket hangus)
- Timer countdown via OnCountdownStart variant
- Win → getRandPrize(room.name) → changeItem + particle effect
- Lose (timer habis) → bubble + no prize
- Teleport ke posExit setelah game selesai (3 detik delay)
- Double teleport (+1 detik secondary) untuk stability
```

---

### Concentration (Room 1 & 2)
```
Mekanik: 16 kartu tertutup, cocokkan 8 pasang dalam 3 menit
Item kartu tertutup: 1916 | Simbol: 742,744,746,748,1918,1920,1922,1924

Room 1: CONCENTRATION01-03 | cards (39-45,29-35) | posIngame=(42,36) | posExit=(49,33)
Room 2: CONCENTRATION04-06 | cards (64-70,29-35) | posIngame=(67,36) | posExit=(60,36)

Tile change real (visible semua player), flip-back 2 detik jika mismatch
Win: 8 pasang cocok | Lose: timer 3 menit habis
```

### Shooting Gallery (Room 1)
```
Mekanik: Punch 3 bullseye yang menyala dalam 3 detik per round, score ≥ 30 untuk menang
Bullseye item ID: 1908 | TILE_FLAG_IS_ON = bit.lshift(1,6) + world:updateTile()
Durasi game: 30 detik | Round timeout: 3 detik | Targets active: 3 dari 10
Win condition: timer habis, cek score ≥ 30 (score bisa > 30)

Room 1: SHOOTING01-03
  Targets: (38,53)(39,51)(40,53)(41,51)(42,53)(43,51)(44,53)(42,49)(40,49)(41,47)
  posWait=(36,54) | posIngame=(41,54) | posExit=(35,52)
  gameArea: xMin=(38-1)*32, xMax=(44-1)*32, yMin=(46-1)*32, yMax=(54-1)*32

Room 2: belum ada coords — tambah entry ke SG_ROOMS[] saat dapat

Alur:
  1. Masuk SHOOTING01 → ticket deduct → reanchor ke posWait → antri
  2. Giliran → reanchor ke posIngame → countdown 30s → "GO!" console
  3. 3 random bullseye nyala → punch ketiganya dalam 3s → bubble score → round baru
  4. Jika 3s habis → reset ke 3 random baru (score tidak nambah)
  5. Timer 30s habis → score ≥ 30 = WIN (bubble score + prize) | < 30 = LOSE
  6. Win bubble: "`6You scored X points! `0You win a `2ItemName`0!"
  7. Exit delay 3s → teleport ke posExit (double teleport +1s)
```

### Catatan Teknis Penting
```
1. Koordinat GTPS Cloud Lua:
   → tile:getPosX/Y() = PIXEL 0-based: (display-1)*32
   → world:getTile(x, y) = 0-indexed: pakai (display_x-1, display_y-1)
   → world:setPlayerPosition = pixel: (display-1)*32
   → Konversi tile:getPosX() → display: math.floor(getPosX()/32) + 1

2. setPlayerPosition TIDAK bekerja dari dalam timer.setTimeout
   → semua teleport via onWorldTick tick-based timing (nextTickAt, exitTickAt)

3. return false di onPlayerEnterDoorCallback untuk SEMUA door (Concentration & SG)
   → JANGAN pakai return true — menyebabkan client stuck "entering world..."
   → pakai return false + reanchorUID/reanchorTickAt/reanchorPos via onWorldTick

4. onPlayerCommandCallback menerima command TANPA slash prefix

5. Toggle tile on/off: TILE_FLAG_IS_ON = bit.lshift(1,6)
   → bit.bor(flags, TILE_FLAG_IS_ON) untuk ON
   → bit.band(flags, bit.bnot(TILE_FLAG_IS_ON)) untuk OFF
   → WAJIB world:updateTile(tile) setelah setFlags()
   → TILE_FLAG_IS_ON wajib didefinisikan sebagai local constant

6. item_picker onPlayerDialogCallback:
   → buttonClicked = "" (empty) saat item dipilih dari picker
   → PRIZE_DATA[gameName] bisa nil jika belum pernah di-set → auto-init makeDefaultPrizes()
   → Treat semua btn yang bukan "btn_back" sebagai save+reopen (termasuk empty)

7. gameSession counter mencegah stale timer fire setelah reset/leave

8. OnCountdownStart label limitation:
   → Float value → label update ✓ tapi timer display salah (float bits misinterpreted)
   → Integer value → timer benar ✓ tapi label direset ke cache awal
   → OnSetLabel tidak support di GTPS Cloud
   → Solusi: timer tanpa label, score update via bubble(world, avatar, "`6Score: X")

9. Cross-minigame guard: getPlayerActiveGame(uid) cek semua ROOMS + SG_ROOMS
   → Player sedang active di game lain → block + reanchor ke posIngame game mereka
```

### Progress Coding
```
Status: ✅ Done (fully tested in-game)

Concentration: fully tested, 2 rooms working
Shooting Gallery Room 1: fully tested ✅
  → TILE_FLAG_IS_ON constant wajib didefinisikan
  → Door pattern: return false + reanchor (bukan return true)
  → Win condition: timer-based (score ≥ 30 saat timer habis, bukan immediate)
  → Score display: bubble di atas kepala player (OnCountdownStart label tidak support update)

Next: Shooting Gallery Room 2 (tunggu coords dari user)
Next: Minigame lain (Growganoth Gulch, Mirror Maze, Brutal Bounce, dll)
```

---

## ════════════════════════════════════
## FITUR: Rent Entrance System
## ════════════════════════════════════

**File:** `scripts/Rent_Entrance.lua`
**Storage:** File JSON `rent_entrance_data.json`
**Item ID:** 25020 (passable) + 25026 (visual solid untuk non-renter)
**Status:** ✅ Done

---

### Fitur
- Owner/Dev wrench → owner config panel (set harga per durasi, max renters, withdraw WL)
- Player wrench → buy panel (pilih durasi, konfirmasi, bayar WL)
- Player yang sudah sewa → status panel (sisa waktu + extend)
- Renter aktif bisa lewat tile (Collision VIP), non-renter visual solid
- Owner dapat withdraw earned WL (dipotong tax 10%)
- Owner bisa add renter manual (gratis, tanpa potong WL)
- Owner bisa remove renter dari renter list panel
- expired otomatis via onWorldTick → revoke visual access

### Setup Item di Dashboard
```
Action Type    : Tile - Toggleable Multi-Framed Animated Foreground
Collision Type : Collision - VIP
```

### Durasi Sewa
```
3h / 6h / 12h / 24h / permanent (0 = tidak pernah expired)
Harga per opsi diset owner (0 WL = disabled)
```

### Struktur Data (per entrance)
```lua
db["WORLDNAME:x:y"] = {
    prices      = { ["3h"]=5, ["6h"]=8, ["12h"]=15, ["24h"]=25, ["permanent"]=0 },
    max_renters = 5,
    earned_wl   = 0,
    renters     = {
        ["u12345"] = { name="GrowID", option="24h", expires_at=1234567890 }
    }
}
```

### Akses & Permission
```
isPrivileged = isWorldOwner OR isDeveloper (role 51)
isWorldOwner → world:getOwner(player)
Hanya isPrivileged yang bisa place + wrench (owner panel)
Player lain (dengan/tanpa world access) → buy panel saat wrench
```

### Catatan Teknis
```
- Anti-spam bubble: safeBubbleWhileVisible (bubble sama tidak spam selama masih visible)
- Visual access: world:setTileForeground(tile, id, 1, player) — per-player
- onWorldTick cek expired renters setiap 100ms (in-memory cache, no file I/O)
- Extend sewa: tambah durasi ke expires_at yang sudah ada (bukan reset dari sekarang)
- Currency: WL/DL(×100)/BGL(×10000)/GGL(×1000000), deduct prioritas GGL→BGL→DL→WL
- Withdraw tax: 10% (configurable WITHDRAW_TAX_PERCENT)
```

---

## ════════════════════════════════════
## FITUR: Backpack
## ════════════════════════════════════

**File:** `scripts/Backpack.lua`, `scripts/item_categorizer.lua`
**Storage:** File JSON `backpack_data.json`
**Status:** ✅ Done

---

### Fitur
- `/bp` atau `/backpack` — buka backpack sendiri
- Category grid 6×3 (18 kategori): Gacha, Locks, Block, Machine, Background, Seeds, Consumables, Hat, Hair, Face, Chest, Shirt, Pants, Shoes, Hand, Wing, Artifact, Pets
- Per item: Amount input, Put in Inventory, Drop in World, Take All, Drop All
- Store items dari inventory → backpack
- Clear All per kategori (dengan konfirmasi)

### Developer Commands (role 51)
- `/givebp growid itemid amount` — beri item langsung ke backpack player
- `/editbp growid` — buka & edit backpack player lain (wajib online)
  - Take to Inventory, Take All to Inventory, Take All to My Backpack, Drop All, Clear All per kategori

### Catatan Teknis
```
- Auto-detect kategori via item_categorizer.lua
  (actionType: 1=Seeds, 3=BG, 8=Consumable, 18=Locks, 28=Vending, 40=Weather)
  (clothingType: 1-9 = Shirt/Pants/Shoes/Face/Hand/Wing/Hair/Chest/Artifact)
- Manual override di item_categorizer.lua untuk Gacha, Pets, Magplant, dll.
- Backpack tidak ada batas jumlah item (unlimited storage)
- Drop All capped 200 per aksi
- Take All capped oleh sisa slot inventory (max 200)
- Sort A-Z: pre-cache nama sebelum table.sort (bukan getItem() di dalam comparator)
- Category grid: is_count_label (tanpa frame) | Item list: staticBlueFrame,is_count_label
```

---

## ════════════════════════════════════
## FITUR: Item Info Editor + Effects Display
## ════════════════════════════════════

**File:** `scripts/iteminfo.lua`, `scripts/itemeffectlua.lua`
**Storage Key:** `"ITEM_INFOS_V3"`, `"ITEM_EFFECTS_V2_4552"`
**Status:** ✅ Done

---

### Fitur
- `/editinfo` (role 51) — edit tampilan info item (deskripsi, warna, special effect, bonus drop)
- `/effectadmin` (role 51) — tambah/edit item effects (extraGems, extraXP, oneHit, breakRange, buildRange, treeGrowth, farmSpeed, drops)
- Non-admin: price info, item ID, item slot **disembunyikan** dari dialog item info
- Item effects dari itemeffectlua ditampilkan di item info untuk **semua player** (admin & non-admin)
- Urutan tampil: Judul → Deskripsi → **Item Effects** → Properties (spliced/dll) → **Bonus Drops button**

### Catatan Teknis
```
- onPlayerVariantCallback intercept "OnDialogRequest" server
- Server GTPS Cloud pakai "add_label_with_ele_icon" (bukan "add_label_with_icon")
- Pattern extract itemID: match "add_label_with_ele_icon|big|[^\n]+|left|(%d+)|"
- embed_data|info_custom|1| dipakai sebagai marker anti-loop
- Jangan print raw dialog ke onConsoleMessage — escape | dan ` dulu
```

---

## ════════════════════════════════════
## TEMPLATE FITUR BARU
## ════════════════════════════════════
> Copy section ini setiap mau tambah fitur baru
> Ganti semua [placeholder] dengan info yang benar

```
## ════════════════════════════════════
## FITUR: [Nama Fitur]
## ════════════════════════════════════

**File:** `scripts/nama-script.lua`
**Storage Key:** `"MULTIVERSE_NAMAFITUR_V1"`
**Status:** [📋 Planned / 🔧 In Progress / ✅ Done]

---

### Konsep
[deskripsi singkat]

### Struktur Data
​```lua
-- struktur data
​```

### Checklist Komponen
- [ ] [komponen]

### Edge Cases
- [edge case]

### Progress Coding
​```
Next step: [langkah pertama]
​```
```

---

## Status Legend
```
📋 Planned     = belum mulai, masih rencana
🔧 In Progress = sedang dikerjakan
⏸️ Paused      = ditunda sementara
✅ Done        = selesai dan sudah di-upload ke server
🐛 Bug         = ada masalah yang perlu difix
```
