# Growtopia Multiverse — Project Overview
> Last updated: April 2026
> Status: DEVELOPMENT — Fokus core features dulu

---

## Visi Server

Growtopia Multiverse adalah GTPS yang menargetkan **semua tipe player** dengan sistem progression 3 layer:

```
Layer 1 — Easy/Casual
Friendly untuk pemain baru, mudah dapat item dasar,
ekonomi tidak terlalu ketat, bisa menikmati semua
fitur dasar tanpa grind berlebihan.

Layer 2 — Mid/Trader
Player yang mau lebih kaya harus masuk layer ini.
Butuh effort lebih, trading aktif, grinding lebih serius.
Ada batas capaian yang jelas antara layer 1 dan 2.

Layer 3 — Hardcore/Kompetitif
Layer tertinggi untuk player hardcore dan trader besar.
Item langka, kompetisi leaderboard, guild rivalry.
Tidak semua player bisa/perlu sampai sini.
```

**Prinsip utama:**
- Semua fitur Growtopia real diaktifkan (surgery, fishing, startopia, cooking, dll.)
- Custom event dan fitur tambahan di atas fondasi GT real
- Ekonomi seimbang — mudah di awal tapi ada ceiling yang jelas

---

## Sistem Mata Uang

| Currency | Tier | Keterangan |
|----------|------|-----------|
| World Lock (WL) | 1 — Dasar | Mata uang utama sehari-hari |
| Diamond Lock (DL) | 2 — Mid | 100 WL = 1 DL |
| Blue Gem Lock (BGL) | 3 — High | 100 DL = 1 BGL |
| Golden Gem Lock (GGL) | 4 — Elite | 100 BGL = 1 GGL |
| Premium Gems | Premium | Custom currency premium, terpisah dari lock system |

**Catatan ekonomi:**
- Lock system mengikuti konversi GT real (100:1 tiap tier)
- Premium Gems adalah currency terpisah untuk fitur premium
- Jaga keseimbangan — jangan buat fitur yang bisa flood WL/DL terlalu mudah
- Layer 1 player seharusnya bisa dapat WL dengan mudah, tapi DL ke atas butuh effort

---

## Status Pengembangan

### ✅ Fitur yang Sudah Ada
| Fitur | Script | Status |
|-------|--------|--------|
| Marvelous Missions (S1 & S2) | marvelous-missions.lua | Selesai |
| Quest System (deposit item) | examplequest.lua | Selesai |
| Starter Pack | starter-pack.lua | Selesai |
| Enchanted Item Effects | itemeffectlua.lua | Selesai |
| Delete Account (admin) | delaccount.lua | Selesai |
| Hospital System + Surgery Minigame | hospital/ + surgery/ (nested loader) | ✅ Selesai April 2026 |
| Carnival System (6 minigames + ticket booth + ringmaster) | carnival/ (nested loader) | ✅ Selesai |
| Premium Store | premium_store/ (nested loader) | ✅ Selesai April 2026 — 6 tab, gacha, featured, admin panel |

### 🔧 Sedang Dikerjakan
| Fitur | Prioritas | Catatan |
|-------|-----------|---------|
| Core GT features (semua fitur GT real) | HIGH | Target utama saat ini |

### 📋 Direncanakan (Backlog)
| Fitur | Prioritas | Catatan |
|-------|-----------|---------|
| Event Seasonal | HIGH | Custom event di atas GT event system |
| Custom Shop / Store | ~~HIGH~~ | ✅ Selesai — premium_store/ |
| Leaderboard / Ranking | MEDIUM | Ranking per kategori (wealth, level, dll.) |
| Guild / Clan System | MEDIUM | Setelah core selesai |
| Daily Reward / Streak | MEDIUM | Perhatikan balance agar tidak flood currency |

### ❌ Tidak Akan Dibuat
*(Isi kalau ada fitur yang memang tidak mau ada di server)*

---

## Fitur GT Real yang Harus Aktif

Semua fitur Growtopia real ditargetkan aktif:

| Kategori | Fitur |
|----------|-------|
| Activities | Surgery, Fishing, Cooking, Startopia, Crime Fighting |
| Farming | Seed splicing, tree growing, harvesting |
| Social | Trading, guilds, friends |
| Progression | Roles (Farmer/Builder/Surgeon/Fisher/Chef/Star Captain), Level, XP |
| Events | Semua seasonal events GT (Halloween, WinterFest, dll.) + custom |
| Economy | Vending Machine, Donation Box, World Lock system |
| Misc | Ghost hunting, Geiger, Dungeons, Grow Pass |

---

## Aturan Pengembangan

### Ekonomi
- Fitur baru yang memberikan reward **wajib dipertimbangkan dampaknya** ke ekonomi
- Layer 1 reward: WL atau item biasa
- Layer 2 reward: DL atau item mid-tier
- Layer 3 reward: BGL/GGL atau item eksklusif
- Premium Gems hanya dari fitur premium, tidak bisa di-farm bebas

### Gameplay
- Jangan buat fitur yang bisa di-abuse untuk farming currency cepat
- Semua fitur baru harus compatible dengan sistem 3 layer
- Fitur hardcore tidak boleh membuat player casual tidak bisa menikmati server

### Technical
- Script baru ditulis di `lua scripts (nested loader architecture)/` — bukan di `scripts/`
- `lua scripts (old architecture)/` hanya referensi, jangan edit
- Semua script ikut konvensi di `docs/structure.md`
- Test di server dev dulu sebelum production
- Backup script sebelum edit

---

## Catatan Penting untuk Claude

Setiap kali diminta membuat atau mengevaluasi fitur:

1. **Cek layer mana fitur ini ditujukan** — casual, mid, atau hardcore?
2. **Cek dampak ke ekonomi** — apakah bisa di-abuse? Apakah reward terlalu besar/kecil?
3. **Cek compatibility** dengan fitur yang sudah ada di scripts/
4. **Ingatkan owner** kalau fitur bisa merusak keseimbangan 3 layer system
5. **Server masih development** — prioritaskan core GT features dulu sebelum custom features

---

## Struktur Environment

```
GROWMULTIVERSE/ (menyerupai file manager panel dashboard GTPS Cloud by Sebia)
├── audio/          ← File audio real Growtopia (.wav + .ogg)
├── cache/          ← File tambahan GTPS (bukan file GT asli)
├── game/           ← Asset real Growtopia
├── GameData/       ← Data real Growtopia (ItemRenderers, UI, dll.)
├── interface/      ← Interface real Growtopia
├── lua scripts (old architecture)/          ← Referensi script lama (flat)
└── lua scripts (nested loader architecture)/← Target migrasi Phase 1+
```

---

## Progress Log

### April 2026
- Surgery minigame selesai: 28 diagnoses (17 std + 5 malady + 6 vile vial), 14 tools, exact GT messages, player-on-player surgery
- Premium Store selesai: 6 tab (featured/items/roles/titles/topup/gacha), Premium Gems currency, gacha weighted roll, admin panel
- **Next:** admin panel Items/Roles/Titles/Topup management (masih stub "coming soon")

### March 2026
- Project dimulai
- Setup dokumentasi (CLAUDE.md, docs/, PROJECT.md, PROGRESS.md)
- Environment baru dibuat: folder audio/cache/game/GameData/interface + 2 lua folder
- 70+ script lama dipindah ke `lua scripts (old architecture)/` sebagai referensi
- Arsitektur nested loader diimplementasi — semua fitur core selesai di-migrate
- Carnival, Hospital, Surgery, Premium Store — semua selesai dalam March-April 2026
