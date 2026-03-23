# Growtopia Knowledge Base
> Referensi mekanik game Growtopia real untuk konteks development Growtopia Multiverse
> Source: growtopia.fandom.com, growtopiagame.com
> Last updated: March 2026

---

## Tentang Growtopia

Growtopia adalah 2D sandbox MMO free-to-play oleh Ubisoft Abu Dhabi. Core loop:
- **Punch** blok untuk pecahkan dan dapat seeds
- **Plant** seeds untuk tumbuhkan pohon
- **Harvest** pohon untuk dapat blok dan seeds baru
- **Splice** dua seeds untuk buat item baru
- **Trade** item dengan player lain menggunakan Lock sebagai mata uang

Player mulai dengan dua tool default:
- **Fist** — untuk punch/break blok, push player
- **Wrench** — untuk interaksi blok, lihat info player, konfigurasi lock

---

## Sistem Ekonomi & Lock (Mata Uang)

Lock punya dua fungsi: **proteksi world** dan **mata uang trading**.

| Item | ID | Nilai | Cara Dapat |
|------|----|-------|-----------|
| World Lock (WL) | 242 | 1 WL | Beli di store 2.000 Gems |
| Diamond Lock (DL) | 7188 | 100 WL | Compress 100 WL |
| Blue Gem Lock (BGL) | 20628 | 100 DL = 10.000 WL | Sales-Man (dial 53785) dengan 100 DL |
| Golden Gem Lock (GGL) | — | 100 BGL | Ultra high-tier |

**Konversi:** 100 WL = 1 DL → 100 DL = 1 BGL → 100 BGL = 1 GGL

**Mekanik World Lock:**
- Hanya owner yang bisa break World Lock
- Owner bisa add/remove access player lain
- Player dengan access bisa build tapi tidak bisa manipulate Vending Machine
- Lock tidak pernah drop seeds
- Lock tidak bisa ditaruh di Display Block (anti-scam)

**Lock sizes lain:**
- Small Lock — 10 tiles
- Big Lock — 48 tiles
- Huge Lock — 200 tiles
- World Lock — seluruh world

---

## Sistem XP & Level

- XP dari: break blok, harvest pohon, surgery, fishing, cooking, dll.
- Formula XP dari blok: `rarity / 5` dibulatkan ke atas
  - Contoh: Crystal Block (rarity 100) = 20 XP
- Level 50 = dapat Mini Growtopian reward
- Item dan consumable tertentu memberikan **XP Buff mod** untuk bonus XP
- Setelah XP patch 2016: collecting gems tidak kasih XP, breaking blocks kasih lebih banyak XP

---

## Sistem Role Quest

6 role dengan quest harian masing-masing:

| Role | getRoleQuestDay() | Aktivitas Utama |
|------|------------------|----------------|
| Jack of All Trades | 1 | Semua role |
| Surgery | 2 | Operasi player di Hospital Bed |
| Fishing | 3 | Catch fish dengan fishing rod |
| Farmer | 4 | Harvest pohon |
| Builder | 5 | Break/place blok |
| Chef | 6 | Masak di oven/lab |
| Star Captain | 7 | Startopia voyages |

**Bonus:**
- Jack Set (Hat + Vest + Jeans + Shoes) = +3% bonus poin
- Supplier's Cape = +5% (Farmer, Surgeon, Fishing, Star Captain)
- Crafter's Cape = +5% (Builder, Chef)
- Completing all roles = Jack of All Trades achievement

---

## Sistem Mods (Playmods)

Mods adalah efek sementara/permanen dari item atau consumable. Bisa di-stack.

| Mod | Efek | Durasi |
|-----|------|--------|
| Lucky! | 5x gems dari break blok (chance) | Sementara |
| XP Buff | Bonus XP dari aktivitas | Sementara |
| ON FIRE!!! | Move faster | 5 detik |
| Caffeinated | Walk faster | 5 detik |
| Infected! | Jadi Zombie | 90 detik |
| Frozen | Membeku | Sementara |
| Curse | Tidak bisa keluar world | 10 menit |
| Silenced | Tidak bisa chat | 10 menit |
| Duct Tape | Chat jadi tidak terbaca | 10 menit |
| Doctor Repulsion | Tidak bisa di-surgery | 4 jam |
| Recovering | Tidak bisa di-surgery lagi | Cooldown setelah surgery |
| Noob! | Diberikan ke akun baru | Sampai selesai Growpedia |

---

## Surgery (Operasi)

Surgery = player operasi player lain di **Hospital Bed** atau **Starship Sickbay Bed**.

**Cara kerja:**
- Surgeon pakai surgical tools (Scalpel, Sponge, Stitches, Antibiotics, dll.)
- Ada **Skill Fail** — semakin tinggi Surgeon Skill (max 100), semakin kecil chance fail
- Pasien dapat reward (gems + random tool) kalau operasi sukses
- Pasien dapat **Recovering mod** setelah operasi — tidak bisa di-surgery lagi selama cooldown

**Maladies (penyakit) yang bisa disembuhkan:**
- Brainworms → reward: Clockwork Fish, Wormtouch
- Fatty Liver → reward: Cupcake Hat, Big Belly, The Fattenator
- Ecto-Bones → reward: Ghostking's Glory
- Chaos Infection → reward: Hands/Feet of the Void, Chaos Corruption, Scarf of Prometheus

**Hospital System (2024):**
- World bisa dijadikan Hospital dengan Reception Desk
- Level up hospital untuk dapat Auto Surgeon Station
- Auto Surgeon Station = player malady bisa sembuhkan diri sendiri dengan bayar
- Surg-E = NPC yang bisa melakukan surgery otomatis

**Lua:** `onPlayerSurgeryCallback(world, player, rewardID, rewardCount, targetPlayer)`
- `targetPlayer` = nil kalau pakai Surg-E (bukan player lain)

---

## Farming & Splicing

**Farming:**
- Tanam seed → tunggu pohon tumbuh → harvest → dapat blok + seeds
- Grow time bervariasi per item (dari detik sampai berhari-hari)
- 1 farm = sekitar 2.650 seeds
- Tanaman populer: Pepper Tree, Fish Tank, Laser Grid, Chandelier

**Splicing:**
- Tanam seed A → gunakan seed B pada pohon A → hybrid tree baru
- Semua item punya seed kecuali unsplicable items
- Resep splicing bisa dikustomisasi di server GTPS

**Lua callbacks:**
- `onPlayerPlantCallback` — saat tanam
- `onPlayerHarvestCallback` — saat harvest
- `onPlayerSpliceSeedCallback` — saat splice (bisa di-block, return true)
- Config resep: tidak ada file khusus, biasanya via item data

---

## Fishing

- Cast fishing rod di dekat air untuk catch fish
- Berbagai jenis fish dengan rarity berbeda
- Fish bisa di-train untuk dijual atau dipakai di Fish Tank
- **Lobster Trap** untuk tangkap lobster
- Perfect fish = fish dengan stat maksimal, harga lebih tinggi

**Lua callbacks:**
- `onPlayerCatchFishCallback(world, player, itemID, itemCount)`
- `onPlayerTrainFishCallback(world, player)`
- Config reward: `config/recipes/train.json`, `config/recipes/lobster.json`

---

## Startopia (Space Voyage)

Startopia = player buat Starship world dan lakukan Star Voyages.

**Setup:**
- Buat world dengan Imperial Starship Helm (bisa di-upgrade)
- Bawa Star Fuel dan tools (AI Brain, Galactibolt, HyperShields, Space Meds, dll.)
- Wrench Helm → Begin a Star Voyage

**Progression Sectors:**
1. Alpha Sector
2. Beta Sector
3. Delta Sector
4. Epsilon Sector
5. Galactic Nexus
6. Growlactus (boss)
7. Heart of the Galaxy (setelah kalahkan Growlactus)

**Mekanik:**
- Ada **Skill Fail** seperti surgery
- **Buckazoids & Starmiles** = reward currency Startopia
- 33+ jenis misi berbeda
- Side missions bisa terjadi selama main mission

**Lua:**
- `onPlayerStartopiaCallback(world, player, itemID, itemCount, missionID)`
- `missionID` = ID misi yang selesai (untuk custom reward per misi)
- Config: `config/startopia.json`

---

## Cooking

- Masak bahan di oven atau lab untuk buat makanan/item
- Ada berbagai resep dengan hasil berbeda
- **Lua:** `onPlayerCookingCallback(world, player, itemID, itemCount)`
- Config reward: `config/recipes/sew.json` (sewing), `config/recipes/crime.json` (crime fighting)

---

## Ghost Hunting

- Ghost muncul di world secara acak
- Equipment: Neutron Pack, Neutron Goggles, Neutron Gun, Jars
- Cara catch: taruh Jar → tunggu terbuka → arahkan ghost ke Jar dengan Neutron Gun sebelum Jar tutup
- **Lua:** `onPlayerCatchGhostCallback(world, player, itemID, itemCount)`
- Ghost bisa di-spawn manual: `world:spawnGhost(tile, type, userID, removeIn, speed)`

**Ghost types:** Normal(1), Ancestor(4), Shark(6), Winterfest(7), Boss(11), Mind(12)

---

## Vending Machine & Trading

**Vending Machine:**
- Taruh item + set harga dalam WL → player lain bisa beli offline
- Max item: 5.199, max WL: 1.000.000
- Butuh 15 detik "warm up" setelah item ditaruh
- Upgrade ke DigiVend Machine (4.000 gems) untuk price check otomatis

**DigiVend Machine:**
- Connect ke multiversal economy untuk price check
- Bisa dihubungkan dengan Vending Hub untuk row shopping
- Hanya bisa dipakai di world-locked worlds

**Lua:** `onPlayerVendingBuyCallback(world, player, tile, itemID, itemCount)` — bisa di-block

---

## Donation Box

- Player deposit item ke Donation Box milik world owner
- Hanya terima item rarity 2+
- Tidak terima fish
- **Lua:** `onPlayerDepositCallback(world, player, tile, itemID, itemCount)` — bisa di-block

---

## Grow Pass

- Battle pass-style system, update tiap bulan
- Complete daily/weekly/monthly quests untuk earn Growpass Points
- Reward: item eksklusif, XP, gems, skins, flags, Growtokens
- **Item of the Season** = item limited time, ada regular dan Royal variant
- Royal variant = butuh 2100 Growpass Points

**Lua:**
- `player:getGrowpassPoints()`
- `player:setGrowpassPoints(points)`
- `player:addGrowpassPoints(points)`

---

## Marvelous Missions

- Sistem koleksi misi seasonal
- Player submit items tertentu untuk dapat exclusive reward
- Beberapa misi locked, unlock setelah misi sebelumnya selesai
- **Event Exclusive Missions** = hanya tersedia selama event tertentu
- Server Growtopia Multiverse sudah punya ini di `marvelous-missions.lua`

---

## Event Seasonal

Event rutin tiap tahun — relevan untuk planning event server:

| Event | Waktu |
|-------|-------|
| Valentine's Week | Februari |
| St. Patrick's Week | Maret |
| Easter Week | Maret-April |
| Cinco De Mayo Week | Mei |
| Super Pineapple Party | Juni |
| SummerFest | Juli-Agustus |
| Player Appreciation Week (PAW) | Agustus |
| Harvest Festival | September-Oktober |
| Halloween | Oktober |
| WinterFest | Desember |
| Anniversary Week | Januari |
| Lunar New Year | Januari-Februari |

**Catatan GTPS:** Event ID custom harus di range **21-255**. ID 1-20 reserved untuk GT official.

---

## Guilds & Seasonal Clash

**Guild:**
- Grup player, bisa ikut Guild Daily Challenge
- Seasonal Clash = event 4 bulan, tiap bulan ada Grow Event (Jumat-Senin, 3 hari)
- Player earn poin dengan tools khusus
- Reward: Seasonal Tokens, Growtokens, Guild Potions, medals
- Top 2000 player dan top 500 guild dapat extra prizes

---

## Dungeon

- Instance-based combat area
- Player butuh Dungeon Scrolls untuk masuk
- **Lua:**
  - `player:getDungeonScrolls()` / `player:setDungeonScrolls(number)` — max 255
  - `onPlayerDungeonEntitySlainCallback(world, player, entityType)`

---

## Geiger Counter

- Dipakai untuk cari hidden items di world
- **Lua:** `onPlayerGeigerCallback(world, player, itemID, itemCount)`

---

## Block/Tile Categories Penting

| Kategori | Contoh | Keterangan |
|----------|--------|-----------|
| Lock | World Lock, Small Lock | Proteksi area + currency |
| Door | Basic Door, Portal | Teleport antar world |
| Sign | Sign, Bulletin Board | Tampilkan teks |
| Vending | Vending Machine, DigiVend | Jual item offline |
| Storage | Donation Box | Terima donasi item |
| Display | Display Block | Tampilkan item |
| Provider | Magic Egg | Kasih item ke player |
| Magplant | Magplant 5000 | Auto farm tool |
| Seed/Tree | Dirt Seed, Rock Seed | Farming |
| Consumable | Apple, Coffee | Kasih mods ke player |

---

## Item ID Penting

| Item | ID |
|------|----|
| World Lock | 242 |
| Diamond Lock | 7188 |
| Blue Gem Lock | 20628 |
| Dirt | 2 |
| Rock | 4 |
| Cave Background | 14 |
