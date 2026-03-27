# Custom Name, Title, and Icon (/titles)

Sumber script: `scripts/custom-titles.lua`

Script `/titles` sekarang menangani **semua** kustomisasi nama:
- warna nama putih (`0`)
- prefix title (contoh: `Dr.`)
- suffix title (contoh: `of Legend`)
- mentor mode (bukan suffix teks, tapi mode warna/title)
- icon di samping nama (TitleTexture)

Sistem `/icon` terpisah sudah dihapus supaya tidak bentrok `OnNameChanged` antar script.

## Cara Kerja

1. Player membuka menu lewat command `/titles`.
2. Dialog menampilkan checkbox untuk icon dan title.
3. Saat klik Apply, profile disimpan per-UID via `saveDataToServer`.
4. Script mengirim `OnNameChanged` dengan:
  - `param 1` = nama final (warna + prefix/suffix sesuai checkbox)
   - `param 2` = JSON payload TitleTexture + wrench customization
5. Saat player masuk world, profile otomatis di-apply ulang.
6. Script mengirim format final langsung via `OnNameChanged` untuk menjaga hasil stabil.
7. Untuk chat biasa (non-command), script intercept `action=input` lalu relay custom chat line agar nama pada console mengikuti format title yang diinginkan.

## Format Nama

Nama display (OnNameChanged) dibentuk tanpa prefix `@`:

```text
Dr + Legend -> `4Dr. Fry of Legend``
Dr only     -> `4Dr. Fry``
Legend only -> `9Fry of Legend``
Mentor only -> `6Fry``
None        -> `0Fry``
```

## Aturan Mods (@)

- Untuk role Moderator (`roleID = 6`) dan role di atasnya, nama otomatis memakai prefix `@`.
- Contoh untuk mods:
  - `` `4@Dr. Fry`` ``
  - `` `4@Dr. Fry of Legend`` ``
  - `` `9@Fry of Legend`` ``
- Jika semua toggle title dimatikan, akun mods kembali ke warna role masing-masing dari Role Manager (bukan dipaksa `0`).

Contoh hasil:
- `` `4Dr. Fry of Legend`` ``
- `` `4Dr. Fry`` ``
- `` `9Fry of Legend`` ``

## Mapping Title ke Warna

- `Dr.` -> `4`
- `of Legend` -> `9`
- Mentor Title -> `6` (color mode only, bukan penambahan teks)

## Format Chat Name

Nama chat memakai format custom relay:

- Dr + of Legend: `` `0Fry ``
- Dr only: `` `4Dr. Fry ``
- of Legend only: `` `9Fry of Legend ``
- Mentor only: `` `6Fry ``
- None: default behavior GTPS

Warna isi pesan chat (variable `text`) mengikuti warna role aktif dari Role Manager:
- Prioritas 1: color code dari `chatPrefix`
- Prioritas 2: color code dari `namePrefix`
- Fallback: warna default chat (`$)

## Payload Icon

Untuk icon aktif, payload mengikuti packet debug native:

```json
{
  "PlayerWorldID": 1,
  "TitleTexture": "game/tiles_page16.rttex",
  "TitleTextureCoordinates": "1,25",
  "WrenchCustomization": {
    "WrenchForegroundCanRotate": false,
    "WrenchForegroundID": -1,
    "WrenchIconID": -1
  }
}
```

Jika icon dimatikan, script kirim:
- `TitleTexture = ""`
- `TitleTextureCoordinates = "0,0"`

## Catatan Implementasi

- Gunakan `player:getRealCleanName()` / `player:getCleanName()` untuk base name bersih.
- Jangan jalankan script lain yang juga mengirim `OnNameChanged` untuk fitur nama yang sama.
- Jika nanti ingin banyak icon, cukup tambah opsi texture/coords di script `/titles` yang sama.
- Script `/titles` melakukan normalisasi nama dasar (hapus color code lama, leading `@`, prefix/suffix lama) agar tidak terjadi nama dobel.
- Tidak memakai `setNickname(...)` untuk menghindari `OnNameChanged` tambahan yang memotong format nama.
- Limit engine GTPS: format nama chat default sering tidak mengikuti `OnNameChanged` secara penuh. Workaround-nya adalah custom relay chat di script `/titles`.
