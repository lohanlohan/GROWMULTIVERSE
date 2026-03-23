# Dashboard Panel — GTPS Cloud by Sebia
> Platform hosting: GTPS Cloud by Sebia
> Last updated: March 2026

---

## Overview

GTPS Cloud by Sebia adalah platform cloud hosting untuk Growtopia Private Server. Semua management server dilakukan melalui dashboard web panel. Script Lua di-upload manual — tidak ada auto-deploy.

**Cara reload script tanpa restart:**
```
Upload .lua file ke panel → ketik /rs in-game
```

---

## Menu Dashboard

### Databases

| Menu | Fungsi |
|------|--------|
| **Player Database** | Lihat, cari, kelola data akun player (inventory, level, gems, ban, dll.) |
| **World Manager** | Kelola semua world yang ada di server |
| **Shop Manager** | Atur item yang dijual di toko server |
| **Mine Shop Manager** | Atur item yang dijual di Mine Shop |
| **File Manager** | Kelola semua file server (config, assets, lua, dll.) — bisa upload .png |

### Roles & Security

| Menu | Fungsi |
|------|--------|
| **Role Manager** | Buat dan kelola custom roles (ID, nama, icon, permission flags, harga, discord role ID, prefix nama & chat, daily reward DL) |
| **Title Manager** | Buat dan kelola custom titles untuk player |
| **Device Bans** | Kelola ban berdasarkan device/perangkat |

### Custom Items

| Menu | Fungsi |
|------|--------|
| **Resource Manager** | Upload dan kelola resource custom (tekstur, audio, dll.) |
| **Item Manager** | Buat dan edit custom items (nama, deskripsi, tekstur, action type, grow time, harga, rarity, flags, item effects) |
| **Item Effects** | Kelola efek bonus item yang dipakai player — terhubung ke `player:getItemEffects()` dan `item:getEffects()` |
| **Weather Manager** | Buat dan kelola custom weather untuk world |
| **Machine Capacities** | Atur kapasitas mesin (storage, provider, dll.) |

### Settings

| Menu | Fungsi |
|------|--------|
| **Feature Manager** | Aktifkan/nonaktifkan fitur-fitur server (lihat section Feature Toggles) |
| **Configuration** | Pengaturan utama server (nama, port, max players, dll.) |
| **Client Settings** | Pengaturan yang mempengaruhi sisi client player |

### Development

| Menu | Fungsi |
|------|--------|
| **Lua Scripts** | Upload, aktifkan/nonaktifkan Lua script — tab utama untuk semua script |
| **Lua Performance** | Monitor performa script (CPU usage, memory, execution time per script) |

### Recipes

| Menu | Fungsi |
|------|--------|
| **Combiner** | Atur resep DNA Combiner custom |

### Extra Stuff

| Menu | Fungsi |
|------|--------|
| **Discord Bot** | Konfigurasi Discord bot (token, channel ID, guild ID) |
| **Redeem Codes** | Buat dan kelola redeem codes (juga bisa via `createRedeemCode()` di Lua) |
| **Server Templates** | Kelola template world untuk `World.newFromTemplate()` |
| **Update** | Cek dan update versi server GTPS Cloud |

---

## Feature Manager Toggles

Toggle fitur yang tersedia di Feature Manager tanpa perlu coding:

| Toggle | Default | Keterangan |
|--------|---------|-----------|
| AAP System | ON | Advanced Account Protection. Bisa dinonaktifkan terpisah dari Discord bot. Kalau OFF, player masih bisa link Discord tapi tombol "Secure My Account" disembunyikan |
| Locke Limitation | ON | Kalau OFF, Locke bisa dipakai di world manapun (tidak terbatas satu world). Otomatis hapus default Locke world dari world menu |
| Hide Role Flags on /hide | OFF | Sembunyikan role flags saat player pakai /hide |
| Discord Bot DM Features | ON | **Disarankan OFF** — fitur DM bot bisa menyebabkan bot di-flag/disabled oleh Discord |

---

## File Manager — Jenis File

| Ekstensi | Fungsi | Perlu Restart? |
|----------|--------|----------------|
| `.lua` | Lua scripts | ❌ cukup `/rs` in-game |
| `.json` | Config files | ✅ perlu restart |
| `.rml` | UI layout (seperti HTML) | ✅ perlu restart |
| `.rcss` | UI styling (seperti CSS) | ✅ perlu restart |
| `.rttex` | Texture/gambar custom items | ✅ perlu restart |
| `.xml` | Data file tambahan | ✅ perlu restart |
| `.png` | Gambar (bisa upload, konversi manual ke .rttex) | — |
| `.wav/.mp3` | Audio files | ✅ perlu restart |

> ⚠️ Claude tidak bisa generate file `.rttex` — harus konversi manual dari `.png` menggunakan tools konversi

---

## Struktur File di Server

```
/ (root server)
│
├── /config/
│   ├── conf.json              ← konfigurasi utama server
│   ├── startopia.json         ← custom startopia missions & side missions
│   └── /recipes/
│       ├── train.json         ← fish training rewards (edit/tambah)
│       ├── sew.json           ← sewing rewards (edit/tambah)
│       ├── lobster.json       ← lobster rewards (edit/tambah)
│       └── crime.json         ← crime fighting rewards (edit/tambah)
│
├── /interface/                ← file UI (.rml, .rcss)
│   ├── /large/                ← texture besar
│   └── /small/                ← texture kecil
│
├── /audio/                    ← file audio (.wav, .mp3)
│
├── /items/                    ← custom item resources
│   └── *.rttex
│
└── /lua/                      ← semua Lua scripts
    └── *.lua
```

---

## Config Files yang Bisa Diedit

### config/startopia.json
Kustomisasi Startopia missions dan side missions. Bisa tambah misi custom baru.
Detect misi custom via: `onPlayerStartopiaCallback(world, player, id, count, missionID)`

### config/recipes/train.json
Edit atau tambah reward fish training baru.

### config/recipes/sew.json
Edit atau tambah reward sewing baru.

### config/recipes/lobster.json
Edit atau tambah reward lobster catching baru.

### config/recipes/crime.json
Edit atau tambah reward crime fighting baru.

---

## Role Manager — Properties

Saat buat role baru di Role Manager, properties yang tersedia:

| Property | Keterangan |
|----------|-----------|
| roleID | ID unik role (pakai di Lua: `player:hasRole(roleID)`) |
| roleName | Nama role |
| roleDescription | Deskripsi role |
| rolePrice | Harga role |
| rolePriority | Prioritas role (untuk sorting) |
| roleItemID | Item icon untuk role |
| textureName | Texture name |
| discordRoleID | Discord role ID yang terhubung |
| namePrefix | Prefix di nama player |
| chatPrefix | Prefix di chat |
| dailyRewardDiamondLocksCount | Jumlah DL reward harian |
| computedFlags | Permission flags (bitwise) |

**Permission flags penting:**
- `ACCESS_ALL_WORLDS` — akses semua world
- `BYPASS_ANTICHEAT` — bypass anticheat
- `BYPASS_BAD_WORDS_FILTER` — bypass filter kata
- `GET_BONUS_XP` — dapat bonus XP
- `REDUCE_TREE_GROWTIME` — pohon tumbuh lebih cepat
- `SHOW_IN_MODS_LIST` — tampil di mods list

---

## Lua Scripts Tab

- Upload file `.lua` di sini
- Bisa aktifkan/nonaktifkan per script tanpa hapus file
- Setelah upload → ketik `/rs` in-game untuk reload
- Monitor error di konsol server atau Lua Performance tab

---

## Lua Performance Tab

Dipakai untuk monitor kalau ada masalah performa:
- CPU usage per script
- Memory usage
- Execution time
- Error logs

Cek tab ini kalau server terasa lag atau ada script yang bermasalah.

---

## HTTP API URL Format

Untuk akses server via HTTP request dari Lua:
```
https://api.gtps.cloud/g-api/{server_port}/...
```

Callback yang menangani: `onHTTPRequest(function(req) end)`
Request menampilkan real IP bukan localhost.

---

## Catatan Penting

- **Backup selalu** sebelum edit script di production
- **Test di server dev** dulu kalau ada
- Script baru yang di-upload tidak otomatis aktif — cek di Lua Scripts tab
- Kalau server crash setelah upload script baru → kemungkinan ada syntax error di script tersebut
- Cek **Lua Performance** untuk identifikasi script yang menyebabkan masalah
