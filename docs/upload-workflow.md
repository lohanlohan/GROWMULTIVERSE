# Upload Workflow — GTPS Cloud by Sebia
> Panduan upload file ke panel dan checklist sebelum/sesudah
> Last updated: March 2026

---

## Alur Upload Setiap Kali Ada Script Baru/Edit

```
Selesai coding di VSCode
        ↓
Checklist sebelum upload (lihat di bawah)
        ↓
Buka panel GTPS Cloud
        ↓
Upload file ke lokasi yang sesuai
        ↓
Reload / restart sesuai jenis file
        ↓
Test di game
        ↓
Kalau error → lihat error message → fix → ulangi
```

---

## Checklist Sebelum Upload

### Script Lua Baru
- [ ] Nama file sudah sesuai konvensi (lowercase, pakai `-` atau `_`)
- [ ] Ada header `print("(Loaded) NamaScript")` di atas
- [ ] Ada footer `print("(Ready) NamaScript")` di bawah
- [ ] Storage key pakai prefix `MULTIVERSE_` dan suffix `_V1`
- [ ] Tidak ada storage key yang sama dengan script lain
- [ ] Tidak ada command yang sama dengan script lain
- [ ] Sudah cek nil untuk semua akses data player
- [ ] loadDataFromServer sudah pakai `or {}`
- [ ] Dialog callback sudah cek `dialog_name` dulu
- [ ] Command callback sudah `return true` kalau handled
- [ ] Backup script lama sudah disimpan (kalau edit existing)

### Config JSON
- [ ] Format JSON valid (tidak ada koma berlebih, bracket tidak ketinggalan)
- [ ] Sudah backup file lama

---

## Lokasi Upload per Jenis File

| File | Tab di Panel | Path di Server |
|------|-------------|----------------|
| `*.lua` | **Lua Scripts** | `/lua/` |
| `config/*.json` | **File Manager** | `/config/` |
| `config/recipes/*.json` | **File Manager** | `/config/recipes/` |
| `interface/*.rml` | **File Manager** | `/interface/` |
| `interface/*.rcss` | **File Manager** | `/interface/` |
| `items/*.rttex` | **File Manager** | `/items/` |
| `audio/*.wav` | **File Manager** | `/audio/` |

---

## Cara Reload per Jenis File

| Jenis File | Cara Reload | Perlu Restart? |
|------------|------------|----------------|
| `.lua` | Ketik `/rs` in-game | ❌ |
| `.json` config | Restart server dari panel | ✅ |
| `.rml` / `.rcss` | Restart server dari panel | ✅ |
| `.rttex` | Restart server dari panel | ✅ |
| `.xml` | Restart server dari panel | ✅ |

---

## Checklist Setelah Upload

### Setelah Upload Lua Script
- [ ] Ketik `/rs` in-game
- [ ] Lihat konsol server — ada error tidak?
- [ ] Cek Lua Scripts tab — script aktif tidak?
- [ ] Test fitur langsung di game
- [ ] Kalau error → catat error message lengkap → fix

### Setelah Upload Config JSON
- [ ] Restart server dari panel
- [ ] Tunggu server fully online
- [ ] Test fitur yang berkaitan

---

## Cara Baca Error dari Konsol

Kalau ada error setelah `/rs`, format error biasanya:
```
[NamaScript.lua]:LineNumber: error message
```

Contoh:
```
[daily-reward.lua]:45: attempt to index a nil value (local 'data')
```

Artinya: di file `daily-reward.lua`, line 45, ada akses ke variable `data` yang nilnya nil.

**Langkah fix:**
1. Catat error message lengkap
2. Pergi ke line yang disebutkan
3. Cek apakah ada nil check yang kurang
4. Fix → upload ulang → `/rs` lagi

---

## Cara Backup Script

Sebelum edit script yang sudah ada di production:

**Di VSCode — buat copy manual:**
```
scripts/
├── daily-reward.lua              ← file aktif
└── _backup/
    └── daily-reward_2026-03-20.lua  ← backup dengan tanggal
```

**Naming convention backup:**
```
namafile_YYYY-MM-DD.lua
```

---

## Kalau Server Crash Setelah Upload

```
1. Jangan panik
2. Buka panel GTPS Cloud
3. Pergi ke Lua Scripts tab
4. Nonaktifkan script yang baru di-upload
5. Restart server
6. Server harusnya kembali normal
7. Cek error di Lua Performance tab
8. Fix script → upload ulang
```

---

## Sinkronisasi File Lokal dan Server

Folder lokal di VSCode harus selalu **mirror** struktur di server:

```
VSCode (lokal)              Panel Server
─────────────────────────────────────────
scripts/*.lua         →     /lua/
server/config/*.json  →     /config/
server/interface/*    →     /interface/
server/items/*        →     /items/
server/audio/*        →     /audio/
```

Setiap edit file lokal → upload ke panel → reload/restart sesuai jenis file.

---

## Tips

- **Jangan upload script yang belum selesai** ke production — pakai server dev kalau ada
- **Selalu test satu script baru dulu** sebelum upload banyak sekaligus
- **Monitor Lua Performance** secara berkala untuk cek script yang boros CPU/memory
- **Aktifkan/nonaktifkan script** di Lua Scripts tab untuk testing tanpa hapus file
