# Dialog Syntax API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/dialog-syntax) + [Nperma Docs](https://docs.nperma.my.id/docs/dialog-element.html)

Dialog dibuat sebagai string, setiap command dipisah `\n`. Dikirim via `player:onDialogRequest(dialogString)`.

---

## Basic Settings

```lua
"set_default_color|`o"           -- Set default text color. ✅ Bisa dipanggil MID-DIALOG untuk ganti warna elemen berikutnya
"set_border_color|r,g,b,a|"     -- Set border color RGBA ✅
"set_bg_color|r,g,b,a|"         -- Set background color RGBA ✅
"set_custom_spacing|x:val;y:val|" -- Custom spacing (y = gap vertikal) ✅
"add_custom_break|"              -- Line break
"disable_resize|"               -- Disable dialog resize
"reset_placement_x|"            -- Reset X placement — WAJIB setelah add_custom_button/add_custom_margin ✅
```

> **`end_dialog` button labels:** Parameter ke-2 dan ke-3 = label tombol bawah dialog.  
> `end_dialog|nama|OK|Cancel|` → tombol **OK (kuning/gold)** + **Cancel (biru)** ✅  
> `end_dialog|nama|||` → tidak ada tombol bawah

---

## Text Elements

```lua
"add_label|size|message|alignment|"              -- Label (size: big/small)
"add_textbox|message|"                            -- Text box
"add_smalltext|message|"                          -- Small text
"add_custom_textbox|text|size:value|"             -- Custom sized textbox
"add_custom_label|option1|option2|"               -- Custom label
```

---

## Input Elements

```lua
"add_text_input|name|label|defaultValue|maxLength|"  -- ✅ Text input. Value terbaca di callback via data["name"]
"add_checkbox|name|label|checked|"                   -- ✅ Checkbox. checked: 0=unchecked, 1=checked. Value di callback: "0" atau "1"
"add_item_picker|name|label|defaultItemId|"          -- ✅ Render sebagai button clickable, opens item picker. Value di callback = item ID (string), nil jika tidak dipick
```

---

## Buttons

```lua
"add_button|name|label|noflags|0|0|"              -- Standard button
"add_small_font_button|name|label|noflags|0|0|"   -- Small font button
"add_button|name|label|off|0|0|"                   -- Disabled button (grayed out)
"add_button_with_icon|name|text|option|itemID|val|" -- Button with icon
"add_button_with_icon|big/small|label|flags|iconID|hoverNumber|"
"add_custom_button|name|option|"                   -- Custom button (lihat section Custom Buttons)
"add_community_button|name|label|noflags|0|0|"     -- Community button (style beda, format SAMA seperti add_button) ✅
"add_achieve_button|achName|achToGet|achID|unk|"   -- Achievement button ✅
```

### Button with Icon Variants
```lua
"add_button_with_icon|btnName|text|staticBlueFrame|itemID|left|"                    -- ✅ confirmed
"add_button_with_icon|btnName|text|staticBlueFrame[is_count_label]|itemID|left|"    -- ✅ confirmed
"add_button_with_icon|btnName|text|staticBlueFrame[no_padding_x]|itemID|left|"      -- ✅ confirmed
"add_button_with_icon|btnName|progress|itemID|"   -- ❌ tidak muncul
"add_button_with_icon|btnName|underText|itemID|"  -- ❌ tidak muncul
"add_button_with_icon|btnName|itemID|"            -- ❌ tidak muncul
```

---

## Labels with Icons

```lua
"add_label_with_icon|size|message|alignment|iconID|"
-- Extended format (dari dungeon debug) — pakai image path+frame langsung:
"add_label_with_icon|big|`wJudul|left||image:game/tiles_page17.rttex;frame:4,30;frameSize:32;|"

"add_label_with_icon_button|size|message|alignment|iconID|buttonName|"  -- ✅ confirmed
"add_dual_layer_icon_label|size|message|alignment|iconID|background|foreground|size|toggle|"  -- ⚠️ muncul tapi overlap, format belum confirmed
"add_seed_color_icons|itemId|"   -- ✅ confirmed: tampil seed icon + 2 color swatch. Hanya untuk item dengan seed color. Item non-seed (misal WL=242) tampil sangat besar.
"add_friend_image_label_button|name|label|texture_path|size|texture_x|texture_y|"  -- ❌ tidak muncul
```

> **`add_community_button`** — muncul tapi menampilkan nama button bukan label. Format parameter belum confirmed.  
> **`enable_tabs` / `add_tab_button`** — ❌ tidak render di dialog Lua.  
> **`add_searchable_item_list`** — ❌ tidak muncul dengan format yang dicoba.

> **GTPS Cloud — Server-Sent Dialog Format:**
> Dialog yang dikirim langsung oleh SERVER (bukan dari Lua script) menggunakan command berbeda:
> ```
> add_label_with_ele_icon|big|`wItem Name``|left|iconID|4|
> ```
> - Command: `add_label_with_ele_icon` (bukan `add_label_with_icon`)
> - Ada extra parameter `4` setelah `iconID`
> - Ini muncul di: item info dialog (wrench item), chest dialog, dll.
> - Penting saat intercept via `onPlayerVariantCallback` — pattern harus pakai `add_label_with_ele_icon`

---

## Progress & Info

```lua
"add_progress_bar|name|size|text|current|max|color|"
"add_player_info|name|level|exp|expRequired|"
-- Textured progress bar (confirmed format):
"add_textured_progress_bar|texturePath|p1|p2||current|max|relative|width|h|pad|unk|unk2|pad2|name|"
-- p1: 0=normal, 1=bar hidden/broken
-- p2: texture variant — 0=striped green hazard, 4=normal blue fill
-- width: 0.0-1.0 fraksi lebar dialog
-- current/max: nilai progress (integer)
-- relative: selalu "relative"
-- Contoh (37.5% blue bar, lebar 80%):
-- add_textured_progress_bar|interface/large/gui_event_bar.rttex|0|4||3750|10000|relative|0.8|0.02|0.007|1000|64|0.007|bar_name|
```

> **`add_progress_bar` color:** String nama warna (`"blue"`, `"red"`, dll) **tidak bekerja** — bar hitam. Integer RGBA juga tidak bekerja — bar putih. **Belum ada format color yang confirmed working.**

> **`add_player_info`:** ✅ Confirmed — tampil nama besar + "Level N [bar] (current/max)".

> **`add_textbox` alignment:** ✅ Confirmed — `|teks|left|`, `|teks|center|`, `|teks|right|` semua bekerja.

---

## Custom Buttons (Confirmed — dari dungeon dialog debug)

```lua
-- Full-width button dengan warna custom
"add_custom_button|btnName|textLabel:Teks;middle_colour:RGBA;border_colour:RGBA;display:block;|"

-- Inline button (tanpa display:block) — berjejer horizontal
"add_custom_button|btnName|textLabel:Teks;middle_colour:RGBA;border_colour:RGBA;|"

-- Icon button (kecil, dari spritesheet)
"add_custom_button|btnName|image:game/tiles_page17.rttex;image_size:32,32;frame:4,31;margin_rself:0.15,0;width:0.09;|"
```

**Format warna RGBA (integer packed):**
```lua
-- Rumus: R*16777216 + G*65536 + B*256 + A
local function rgba(r, g, b, a)
    return r * 16777216 + g * 65536 + b * 256 + a
end
-- Contoh warna dari GT dungeon:
-- 3389566975 = biru (dungeon start button)
-- 431888895  = ungu (purchase button)
-- 3434645503 = abu-abu (info button)
-- Warna custom:
-- rgba(255, 0, 0, 255)   = merah  = 4278190335
-- rgba(0, 255, 0, 255)   = hijau  = 16711935
-- HATI-HATI: nilai > 2147483647 bisa overflow signed 32-bit di beberapa sistem
```

**`middle_colour`** = fill/background button  
**`border_colour`** = warna border/outline  
**`display:block`** = full-width (satu baris sendiri); tanpa ini = inline (berjejer)  
**`width:N`** = lebar button sebagai fraksi 0.0–1.0. ✅ TAPI: `textLabel` + `width` menyebabkan label render sebagai teks raksasa di luar button. **Gunakan `width` hanya dengan `image:`, bukan `textLabel:`**  
**`height:0.15`** = tinggi button custom (nilai fraksi) ✅  

Setelah `add_custom_button`, wajib `reset_placement_x|` sebelum elemen berikutnya agar posisi reset.

**Icon grid pattern (confirmed working):**
```lua
-- 5 icon berjejer horizontal
d = d .. "add_custom_button|btn_i1|image:game/tiles_page1.rttex;image_size:32,32;frame:0,0;width:0.12;|\n"
d = d .. "add_custom_button|btn_i2|image:game/tiles_page1.rttex;image_size:32,32;frame:1,0;width:0.12;|\n"
d = d .. "add_custom_button|btn_i3|image:game/tiles_page1.rttex;image_size:32,32;frame:2,0;width:0.12;|\n"
d = d .. "reset_placement_x|\n"
```

**Icon + text combo (confirmed working):**
```lua
-- image: dan textLabel: bisa dikombinasi — icon di kiri, teks di kanan
"add_custom_button|btn|image:game/tiles_page17.rttex;image_size:32,32;frame:4,30;textLabel:`wTeks;display:block;|"
-- textLabel mendukung color codes: `2, `4, `w, dll ✅
```

**`margin_rself:x,y`** = margin kanan dan bawah relatif terhadap ukuran button. Nilai besar menyebabkan icon scale membesar — gunakan nilai kecil (`0.05,0` atau lebih kecil).

**❌ Tidak supported:**
- `add_banner|path|x|y|` — tidak render (semua path dicoba)
- `add_big_banner|path|x|y|text|` — tidak render
- `add_dual_layer_icon_label` — semua format overlap/broken

---

## Custom Label & Margin

```lua
-- Label bebas posisi (overlay di atas button via target:)
"add_custom_label|Teks|target:btnName;top:0.5;left:0.3;size:small;|"   -- di ATAS button
"add_custom_label|Teks|target:btnName;top:0.5;left:2.5;size:medium;|"  -- di KANAN button (luar)
"add_custom_label|Teks|size:small;|"    -- small / medium / big (tanpa target)

-- Margin vertikal/horizontal
"add_custom_margin|x:0;y:16|"   -- tambah gap vertikal 16px
"add_custom_margin|x:50;y:0|"   -- indent horizontal 50px
"reset_placement_x|"             -- reset posisi X ke awal (wajib setelah custom_button/margin)
```

> **`add_custom_label` positioning:** `top` dan `left` adalah **multiplier relatif** terhadap ukuran button target.  
> - `left < 1.0` → label di dalam area button (overlay)  
> - `left > 1.0` → label di luar button (ke kanan)  
> - `top:0.5` → vertikal center  
> 
> **Use case:** Badge/count di atas icon button — `add_custom_button` (icon) + `add_custom_label` (`+5`, `99`, dll) dengan `top:0.7;left:0.3`

---

## Image Button (Banner Layout)

```lua
-- Banner image full-width dari texture
"add_image_button|noclick|interface/large/gui_dungeons_banner.rttex|bannerlayout|flag_frames:3,2,0,0|flag_surfsize:512,150|"
-- noclick = tidak bisa diklik (display only)
-- flag_frames:cols,rows,startX,startY = frame dalam spritesheet
-- flag_surfsize:width,height = ukuran surface render
```

---

## Smalltext Forced

```lua
"add_smalltext_forced|teks||"
"add_smalltext_forced_alpha|teks||alpha|"
```

> ✅ **CONFIRMED behavior:**  
> `add_smalltext_forced` = render teks yang **sama dua kali berjejer** — efek bold/besar visual. **Parameter ke-2 sepenuhnya diabaikan** apapun isinya (string, angka, left, right — semua ignored). Gunakan hanya param1.  
> `add_smalltext_forced_alpha` — sama, alpha: 0=opaque, 1=invisible. Param ke-2 juga diabaikan.  
> **Tidak ada two-column layout** — untuk dua kolom gunakan `add_label_with_icon` dengan custom formatting.

---

## Advanced Elements

```lua
"add_spacer|size|"                                -- Spacer
"add_quick_exit|"                                  -- Quick exit button
"embed_data|key|value|"                           -- Embedded data (metadata, tidak tampil di UI)
"add_image_button|name|imagePath|flags|open|label|" -- Image button
"add_banner|imagePath|x|y|"                        -- Banner
"add_big_banner|imagePath|x|y|text|"              -- Big banner with text
"add_searchable_item_list|data|listType:iconGrid;resultLimit:[amount]|searchFixedName|"
```

> **`embed_data` Trick:**
> Dipakai untuk menyisipkan metadata ke dialog tanpa tampil di UI. Berguna untuk mencegah re-processing saat intercept via `onPlayerVariantCallback`:
> ```lua
> -- Tandai dialog sudah diproses agar callback tidak infinite loop
> modified = "embed_data|processed|1|\n" .. modified
> -- Cek di callback:
> if content:find("processed", 1, true) then return false end
> ```

---

## Tabs

```lua
"enable_tabs|enable|"
"start_custom_tabs|"
"add_tab_button|name|label|iconPath|x|y|"
"end_custom_tabs|"
```

---

## World/Community Buttons

```lua
"add_cmmnty_ft_wrld_bttn|worldName|ownerName|worldName|"
"add_cmmnty_wotd_bttn|top|worldName|ownerName|imagePath|x|y|worldName|"
"community_hub_type|hubType|"
```

---

## Dialog Ending

```lua
"end_dialog|dialog_name|||"    -- End dialog dengan nama (untuk callback)
```

---

## Contoh Lengkap

### Simple Welcome Dialog
```lua
local dialog =
    "set_default_color|`o\n" ..
    "add_label|big|`wSelamat Datang!|left|\n" ..
    "add_textbox|Pilih menu di bawah ini:|\n" ..
    "add_spacer|small|\n" ..
    "add_button_with_icon|btn_shop|`2Shop|staticBlueFrame|242|left|\n" ..
    "add_button_with_icon|btn_profile|`9Profile|staticBlueFrame|18|left|\n" ..
    "add_spacer|small|\n" ..
    "add_quick_exit|\n" ..
    "end_dialog|welcome_menu|||"
player:onDialogRequest(dialog)
```

### Form Input Dialog
```lua
local dialog =
    "set_default_color|`o\n" ..
    "add_label|big|`wRegistrasi Guild|left|\n" ..
    "add_text_input|guild_name|Nama Guild:|MyGuild|20|\n" ..
    "add_text_input|guild_motto|Motto:|We are the best|50|\n" ..
    "add_checkbox|is_public|Guild Publik?|1|\n" ..
    "add_spacer|small|\n" ..
    "add_button|btn_create|`2Buat Guild|noflags|0|0|\n" ..
    "add_quick_exit|\n" ..
    "end_dialog|guild_create|||"
player:onDialogRequest(dialog)
```

### Dialog with Direct Callback
```lua
player:onDialogRequest(
    "set_default_color|`o\n" ..
    "add_label|big|`wKonfirmasi|left|\n" ..
    "add_textbox|Apakah kamu yakin?|\n" ..
    "add_button|btn_yes|`2Ya|noflags|0|0|\n" ..
    "add_button|btn_no|`4Tidak|noflags|0|0|\n" ..
    "end_dialog|confirm|||",
    0,
    function(world, player, data)
        if data["buttonClicked"] == "btn_yes" then
            player:onConsoleMessage("`2Berhasil!")
        else
            player:onConsoleMessage("`4Dibatalkan.")
        end
    end
)
```

### Handle Dialog via Global Callback
```lua
onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] == "guild_create" then
        if data["buttonClicked"] == "btn_create" then
            local guildName = data["guild_name"]
            local motto = data["guild_motto"]
            local isPublic = data["is_public"] == "1"
            -- process guild creation...
        end
        return true
    end
    return false
end)
```

---

## Color Codes (Growtopia)

| Code | Warna |
|------|-------|
| \`0 | White |
| \`1 | Cyan/Light Blue |
| \`2 | Green |
| \`3 | Light Blue |
| \`4 | Red |
| \`5 | Light Purple |
| \`6 | Gold/Orange |
| \`7 | Gray |
| \`8 | Dark Gray |
| \`9 | Blue |
| \`b | Blueish |
| \`c | Pink |
| \`e | Light Yellow |
| \`o | Default |
| \`w | White (bright) |
| \`p | Bright Pink |
| \`q | Aqua/Dark Aqua |
| \`s | ??? |
| \`t | Turquoise |
| \`\` | Literal backtick |
