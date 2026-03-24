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
GrowMatic.lua            ✅ Done  — Grow-o-Matic farming machine (machine ID 25014)
Rent_Entrance.lua        ✅ Done  — rent entrance system
anti-spam.lua            ✅ Done  — anti spam
anti_consumable.lua      ✅ Done  — anti consumable standalone (renamed dari anti_consum.lua)
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
**Status:** ✅ Done (Concentration R1&2 + Shooting Gallery R1&2 + Death Race 5000 + Mirror Maze)

### Minigames Implemented
```
Concentration      — Room 1 (CONCENTRATION01-03) + Room 2 (CONCENTRATION04-06) ✅
Shooting Gallery   — Room 1 (SHOOTING01-03) ✅ | Room 2 (SHOOTING04-06) ✅
Death Race 5000    — DEATH01-04 ✅
Mirror Maze        — MIRROR01-02 ✅
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
Mekanik: 16 kartu tertutup, cocokkan 8 pasang dalam 1 menit
Item kartu tertutup: 1916 | Simbol: 742,744,746,748,1918,1920,1922,1924

Room 1: CONCENTRATION01-03 | cards (39-45,29-35) | posIngame=(42,36) | posExit=(49,33)
Room 2: CONCENTRATION04-06 | cards (64-70,29-35) | posIngame=(67,36) | posExit=(60,36)

Tile change real (visible semua player)
Mismatch: dua kartu tetap terbuka sampai punch ke-3 → kartu 1&2 tutup, kartu ke-3 terbuka sebagai firstPick
Match: dua kartu tetap terbuka permanen
Win: 8 pasang cocok | Lose: timer 1 menit habis
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

Room 2: SHOOTING04-06 | posWait=(78,54) | posIngame=(73,54) | posExit=(79,52)
  Targets: (70,53)(72,53)(74,53)(76,53)(71,51)(73,51)(75,51)(72,49)(74,49)(73,47)
  gameArea: xMin=(70-1)*32, xMax=(76-1)*32, yMin=(46-1)*32, yMax=(54-1)*32

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

9. Cross-minigame guard: getPlayerActiveGame(uid) cek semua ROOMS + SG_ROOMS + DR_ROOMS + MM_ROOMS
   → Cek queue DAN activeUID/activePlayers di semua game type
   → Player sedang active/antri di game lain → block + reanchor ke posIngame game mereka
   → onPlayerDeathCallback: hapus dari queue semua game (bukan forfeit active game)
     DR active tidak disentuh (DR punya death handling sendiri)

10. DR reanchor pakai reanchorList[] (bukan single slot) — support multiple player join bersamaan
    → table of {uid, tickAt, pos} — di-process tiap world tick (iterate reverse)
```

### Progress Coding
```
Status: ✅ Done (fully tested in-game)

Concentration: fully tested, 2 rooms working
Shooting Gallery Room 1: fully tested ✅
Shooting Gallery Room 2: done ✅ (belum tested in-game)
Death Race 5000: done ✅ (belum tested in-game)
Mirror Maze: done ✅ (belum tested in-game, bug fix prize.id→prize.itemID sudah difix)

Mirror Maze: done ✅ — timer bug, maze randomness, posExit, perfect maze algorithm semua fix
Next: Minigame lain (Growganoth Gulch, Brutal Bounce, Hall of Mirrors, Spiky Survivor)
```

---

### Death Race 5000
```
Mekanik: Race parkour kanan-bawah → kiri → atas → kanan-atas, siapa duluan finish = menang
Doors: DEATH01 (entrance) | DEATH02 (CP1 ref) | DEATH03 (CP2 ref) | DEATH04 (exit)
Min players: 2 | Timer: 90 detik | Countdown pre-race: 5 detik (reset tiap player baru masuk)
Bisa lebih dari 2 player, asal masuk sebelum countdown habis

Koordinat:
  posTent=(34,14) | posWait=(34,16) | posCP1=(32,16) | posCP2=(4,12)
  posFinish=(32,12) | posExit=(36,17)
  gameArea: xMin=(2-1)*32, xMax=(33-1)*32, yMin=(9-1)*32, yMax=(17-1)*32
  (1-2 tile buffer agar checkpoint tidak tepat di batas → cegah false death loop)

Obstacle slots: x=6,8,10,...,30 di y=16 (floor 1) dan y=12 (floor 2)
  Death Spike ID 162: 1 tile (floor level only)
  Lava ID 4: 1 tile (floor) atau 2 tile (floor + floor-1)
  Distribution: 25% empty | 17% spike | 25% lava single | 33% lava double
  Consecutive rule: 60% force empty setelah obstacle (kadang 2 consecutive boleh)
  Generate ulang setiap race baru

Checkpoint system (position-based detection):
  CP1 default (32,16) | CP2 unlock saat tx≤5 di floor 2
  Mati = keluar gameArea → 1 detik delay → respawn di checkpoint + 2 detik grace period

Alur:
  1. Masuk DEATH01 → ticket deduct → reanchorList → posWait → antri
  2. Queue ≥ 2 → countdown 5s (reset jika player baru masuk)
  3. Countdown habis → obstacle generate → semua teleport ke CP1 → timer 90s mulai
  4. Pertama sentuh tile finish (32,12) = WIN → prize + notify semua → 5s exit
  5. Timer habis → "No winner" → 5s exit
  6. Semua player di-teleport ke posExit, obstacles di-clear
```

### Mirror Maze
```
Mekanik: Selesaikan labirin tak kasat mata dari posIngame ke posEndgame dalam 40 detik
Doors: MIRROR01 (entrance/antrian 27,29) | MIRROR02 (ingame 15,33)
posWait=(27,29) | posIngame=(15,33) | posEndgame=Bullseye(25,25) | posExit=(27,26)
gameArea: x1=15, y1=25, x2=25, y2=33 (11×9 tiles)

Obstacle: Mirror Maze Block (ID 1926) mengisi seluruh area kecuali posIngame & posEndgame
  OFF state (flag not set) = collision normal (dinding)
  ON state (TILE_FLAG_IS_ON) = no collision (bisa dilewati)
  Semua blok terlihat sama secara visual — player harus tebak jalur

Maze RANDOM tiap game (mmGenerateOpen):
  → Recursive backtracker pada cell grid 2-step (even offsets dari x1,y1)
  → Setiap koridor lebar TEPAT 1 tile: wall | path | wall (perfect maze)
  → Grid 11×9 → 6×5 = 30 cells, setiap cell terhubung (satu jalur unik per pasang titik)
  → math.randomseed(os.time() + gameSession*1337) tiap mmPlaceMaze → maze selalu beda
  Setiap player baru = layout maze berbeda, guaranteed solvable

Win: player step ke posEndgame (25,25) = detected via posisi check di world tick
Lose: timer 40s habis → bubble + regenerate maze → exit 3s delay → MIRROR03 (28,26)
Setelah game selesai: mmPlaceMaze dipanggil (bukan mmClearBlocks) → ruangan tidak kosong

Bug fixes:
  timer.simple → timer.setTimeout | timer.stop → timer.clear
  getWorld(WORLD) → getCarnivalWorld() (dalam timer callback)
  prize.id → prize.itemID | prize.count → prize.amount
  posExit: (27,26) → (28,26) MIRROR03
  OnCountdownStart param 3: 1 → -1 (hapus "Score: 1" text)
```

### Catatan Teknis Death Race 5000
```
- drStartGame: build startList dulu, baru clear queue setelah count valid
  (mencegah queue terhapus kalau ada player offline di queue)
- reanchorList[] bukan single slot — support multiple player join bersamaan
- Fallback auto-trigger di world tick: jika queue ≥ 2 dan tidak ada countdown/game/exit
  → set countdown otomatis (catch edge case brief disconnect/reconnect)
- winner dapat OnCountdownStart(0,-1) agar timer display di-clear
- Snap non-active players keluar gameArea setiap 1 detik (drSnapTick)
- /carnivalreset juga reset DR_ROOMS + clear obstacles
```

---

## ════════════════════════════════════
## FITUR: Grow-o-Matic
## ════════════════════════════════════

**File:** `scripts/GrowMatic.lua`
**Storage Key:** `"furnace_db_v1"`
**Machine ID:** 25014
**Status:** ✅ Done

---

### Fitur
- Place machine → otomatis init state
- Insert seeds via item picker (ambil dari inventory + magplant)
- Punch machine → toggle ON/OFF processing
- Wrench → lihat status, insert seeds, collect harvest, cancel & refund, upgrade
- Collect: output blocks + seeds + gems, overflow ke inventory, sisa ke magplant
- Cancel & Refund: konfirmasi dialog → seeds dikembalikan ke **Backpack** (via `_G.BP_storeItem`)
- Upgrade machine (4 level): Basic→Advanced→Industrial→Godly (cap 5k/10k/100k/1M)

### Catatan Teknis
```
- Cancel & Refund TIDAK panggil process_furnace() sebelum baca input_count
  (process_furnace bisa clear input_count=0 jika grow time sudah lewat → item hilang)
- Backpack integration: _G.BP_storeItem(player, itemID, count) dari Backpack.lua
  (update in-memory state + save file — direct file write tidak cukup karena Backpack.lua punya cache)
- Confirmation dialog: furnace_refund_confirm (dialog terpisah dari furnace_ui)
- Tile flag ON/OFF: bit 64 (bit.band/bor + world:updateTile)
- Harvest: rarity-based output calculation + magplant fill priority
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
- Non-admin: price info, item ID, item slot, **"This item Rarity is X"** disembunyikan dari dialog item info
- Role 51: semua info tampil (termasuk rarity text)
- "Rarity: 96" (numeric native) tetap tampil untuk semua player
- Trailing spacer sebelum end_dialog di-trim untuk kurangi gap bawah
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
