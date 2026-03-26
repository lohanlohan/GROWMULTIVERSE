# Debug Variant Script — `player:sendVariant()` Guide

> Dokumentasi untuk `debug-variant.lua` — Debug dan discovery tool untuk GTPS Cloud sendVariant calls

## Overview

`player:sendVariant()` adalah method untuk mengirim custom packets/events ke game client. Ini powerful untuk UI, notifications, animations, dan effects.

Namun, **tidak ada dokumentasi lengkap** di GTPS Cloud docs. Script ini membantu **discover** dan **test** variant types.

---

## Cara Pakai

### Command 1: `/debugvariant`

Buka dialog interaktif untuk test variant types:

```
1. /debugvariant
2. Dialog terbuka dengan input field
3. Masukkan variant name (atau gunakan default)
4. Click "Test Variant"
5. Lihat effect di game
6. Check console untuk logs
```

**Contoh:**
- Input: `OnConsoleMessage` → Send test message ke chat
- Input: `OnTalkBubble` → Show talk bubble di atas player
- Input: `OnNameChanged` → Ubah nama player temporarily

### Command 2: `/debuglog`

Enable logging untuk track semua variant packets:
```
1. /debuglog
2. Console akan show:
   [DEBUG-LOG] Logging enabled for player: YourName
   [DEBUG-LOG] All variant calls to this player will be logged below:
```

---

## Known Variant Types

Script sudah berisi 15+ known variants. Lihat table di bawah:

### UI & Display
| Variant | Signature | Contoh |
|---------|-----------|--------|
| `OnConsoleMessage` | `{name, message}` | `{"OnConsoleMessage", "Hello"}` |
| `OnTalkBubble` | `{name, netID, msg, x, y}` | `{"OnTalkBubble", 123, "Hi", 0, 0}` |
| `OnNameChanged` | `{name, newName, jsonPayload}` | Ubah nama + title + icon |
| `OnAddNotification` | `{name, icon, title, sound, unk}` | Notification popup |

### UI Panels
| Variant | Signature | Contoh |
|---------|-----------|--------|
| `OnClothesUI` | `{name, targetNetID}` | Buka clothes customization |
| `OnTitlesUI` | `{name, targetNetID}` | Buka titles panel |
| `OnTradeStart` | `{name, targetNetID}` | Start trade UI |

### Audio & Effects
| Variant | Signature | Contoh |
|---------|-----------|--------|
| `OnPlaySFX` | `{name, filePath, delayMS}` | `{"OnPlaySFX", "audio/sfx/click.wav", 0}` |
| `OnEmote` | `{name, emoteID}` | Play emote animation |
| `OnParticleEffect` | `{name, effectType, x, y}` | Show particle effect |

### Server/World
| Variant | Signature | Contoh |
|---------|-----------|--------|
| `OnSetFreezePlayer` | `{name, playerNetID, state}` | Freeze player |
| `OnKnockback` | `{name, x, y}` | Apply knockback force |

### Observed from Real Packet Logs
Berikut variant yang terpantau dari log client/server nyata (sesuai screenshot), dan bisa dipakai sebagai target debugging/reverse-engineering:

| Variant | Signature (observed) | Catatan |
|---------|-----------------------|---------|
| `OnNameChanged` | `{name, newName, jsonPayload}` | Dipakai untuk update nama/title/icon + wrench customization payload |
| `OnTransmutateLinkDataModified` | `{name}` | Event notifikasi perubahan data link transmutate |
| `OnSetRoleSkinsAndIcons` | `{name, p1, p2, p3}` | Umumnya terkait refresh role skin/icon client |
| `OnSetClothing` | `{name, p1, p2, p3, p4, p5}` | Sinkronisasi state clothing/appearance |
| `OnGuildDataChanged` | `{name, p1, p2, p3, p4}` | Trigger saat data guild berubah/refresh |
| `OnFlagMay2019` | `{name, p1}` | Legacy/internal flag update |
| `OnClearItemTransforms` | `{name}` | Reset transform item state di client |
| `OnBillboardChange` | `{name, p1, p2, p3, p4, p5}` | Update billboard state/data |
| `OnCountryState` | `{name, countryCode}` | Update state negara (contoh: `us`) |

> Note: beberapa signature di atas masih bersifat observed/inferred dari packet log, bukan final API resmi.

### Native Dialog + OnNameChanged Findings (/icons and /titles)

Berikut temuan langsung dari packet debug native GTPS/Growtopia:

#### 1) Native `/icons`
- `OnDialogRequest` berisi:
  - `embed_data|applyNameIcon|1`
  - checkbox contoh: `nameIcon_14410`
- Apply menghasilkan `OnNameChanged` dengan:
  - Nama: `` `a@Fry`` ``
  - Payload icon:
    - `TitleTexture = game/tiles_page16.rttex`
    - `TitleTextureCoordinates = 1,25`

#### 2) Native `/titles`
- `OnDialogRequest` berisi:
  - `embed_data|applyTitle|1`
  - checkbox title contoh: `title_9`, `title_12`, `title_4`
- Apply menghasilkan `OnNameChanged` dengan nama gabungan title, contoh:
  - `` `a@Dr.Fry of Legend`` ``
- Temuan penting: jika hanya `title_4` (Mentor Title) aktif, `OnNameChanged` bisa tetap `@Fry` (tanpa suffix "Mentor").
- Payload icon yang dipakai sama:
  - `TitleTexture = game/tiles_page16.rttex`
  - `TitleTextureCoordinates = 1,25`

#### 3) Burst events setelah apply title/icon
Urutan event tambahan yang sering muncul:
- `OnTransmutateLinkDataModified`
- `OnSetRoleSkinsAndIcons`
- `OnSetClothing`
- `OnGuildDataChanged`
- `OnFlagMay2019`
- `OnClearItemTransforms`
- `OnBillboardChange`
- `OnCountryState`

Implikasi praktis:
- Jika custom script hanya butuh ubah nama/title/icon, fokus utama tetap `OnNameChanged`.
- Event burst lain bisa diperlakukan sebagai side effects refresh state client.

---

## How to Discover New Variants

### Strategy 1: Trial & Error
1. Think of what you want to do (e.g., "play sound", "change player look")
2. Guess variant name based on pattern (e.g., `OnPlaySFX`, `OnNameChanged`)
3. `/debugvariant` → input guess → click "Test Variant"
4. If works → add to `KNOWN_VARIANTS` table
5. If not → try different name

### Strategy 2: Grep Real GTPS Scripts
Check if other GTPS servers use variants in their scripts:
```
grep -r "sendVariant" ./scripts/
```
Look for patterns like:
```lua
player:sendVariant({"OnSomething", param1, param2})
```

### Strategy 3: Monitor Network Traffic
Use game network sniffer to capture packets, then reverse-engineer variant types. (Advanced)

---

## How to Extend Script

### Add New Variant to Test Database

Edit `debug-variant.lua`, find `KNOWN_VARIANTS` table:

```lua
local KNOWN_VARIANTS = {
  -- ... existing variants ...
  
  { name = "MyNewVariant", signature = "{name, param1, param2}", desc = "Does something awesome" },
}
```

### Add Test Payload

Inside `sendTestVariant()` function, add case in `testPayloads`:

```lua
local testPayloads = {
  -- ... existing ...
  
  MyNewVariant = function()
    return {
      "MyNewVariant",
      "test_value_1",
      42,
      "test_string"
    }
  end,
}
```

---

## Common Patterns

### 1. Send Message
```lua
player:sendVariant({"OnConsoleMessage", "`2Hello World"}, 0, player:getNetID())
```

### 2. Show Notification
```lua
player:sendVariant({
  "OnAddNotification",
  "interface/large/smiley.rttex",     -- icon
  "`2Important",                        -- title
  "audio/sfx/sound_collect.wav",       -- sound
  0                                     -- unknown param
}, 0, player:getNetID())
```

### 3. Change Name/Title/Icon
```lua
local payload = string.format(
  "{\"PlayerWorldID\":%d,\"TitleTexture\":\"game/items00\",\"TitleTextureCoordinates\":\"0,0\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
  player:getNetID()
)
player:sendVariant({"OnNameChanged", "New Name", payload}, 0, player:getNetID())
```

### 4. Play Sound
```lua
player:sendVariant({
  "OnPlaySFX",
  "audio/sfx/button_click.wav",   -- file path
  100                             -- delay in ms
}, 0, player:getNetID())
```

---

## Delay & NetID Parameters

```lua
player:sendVariant(variant_array, delay_ms, netID)
```

- **variant_array** — Array dengan variant name + params
- **delay_ms** — Delay before sending (100ms = human-perceivable delay)
- **netID** — Target player's netID (usually `player:getNetID()`)

**Contoh dengan delay:**
```lua
-- Send dengan 500ms delay
player:sendVariant({"OnConsoleMessage", "Delayed message"}, 500, player:getNetID())
```

---

## Troubleshooting

### "Variant not in test database"
- Variant name correct tapi belum ada test payload
- Add ke `testPayloads` table atau coba dengan default test

### "player:sendVariant not available"
- Player object tidak support method ini
- Check jika `player` valid (not nil, online, etc)

### Variant sent tapi tidak ada effect
- Effect invisible/disabled pada client
- Try different variant name (misspelling?)
- Check console logs untuk error message

---

## Future Improvements

- [ ] Persistent variant history (save tested variants)
- [ ] Visual effect preview dialog
- [ ] Auto-generate test cases dari variant signature
- [ ] Export known variants to JSON for documentation
- [ ] Lengkapi parameter map untuk observed variants (tipe data + range nilai)

---

## Related

- [01-player.md](01-player.md#actions--packets) — Player API documentation
- `custom-titles.lua` — Uses `OnNameChanged` for unified name/title/icon system
