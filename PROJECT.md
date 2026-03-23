# Growtopia Multiverse — Project Overview
> Last updated: March 2026
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

### 🔧 Sedang Dikerjakan
| Fitur | Prioritas | Catatan |
|-------|-----------|---------|
| Core GT features (semua fitur GT real) | HIGH | Target utama saat ini |

### 📋 Direncanakan (Backlog)
| Fitur | Prioritas | Catatan |
|-------|-----------|---------|
| Event Seasonal | HIGH | Custom event di atas GT event system |
| Custom Shop / Store | HIGH | Toko custom dengan Premium Gems |
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
- Satu fitur = satu script file
- Semua script ikut konvensi di docs/conventions.md
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

## Progress Log

### March 2026
- Project dimulai
- Setup dokumentasi (CLAUDE.md, docs/, PROJECT.md)
- 5 script dasar sudah ada (missions, quest, starter pack, item effects, delete account)
- Target: selesaikan semua core GT features
