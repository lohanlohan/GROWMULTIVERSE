# Dialog Syntax API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/dialog-syntax) + [Nperma Docs](https://docs.nperma.my.id/docs/dialog-element.html)

Dialog dibuat sebagai string, setiap command dipisah `\n`. Dikirim via `player:onDialogRequest(dialogString)`.

---

## Basic Settings

```lua
"set_default_color|`o"           -- Set default text color
"set_border_color|r,g,b,a|"     -- Set border color RGBA
"set_bg_color|r,g,b,a|"         -- Set background color RGBA
"set_custom_spacing|x:val;y:val|" -- Custom spacing
"add_custom_break|"              -- Line break
"disable_resize|"               -- Disable dialog resize
"reset_placement_x|"            -- Reset X placement
```

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
"add_text_input|name|message|defaultInput|length|" -- Text input field
"add_checkbox|name|message|checked|"               -- Checkbox (checked: 0/1)
"add_item_picker|name|message|placeholder|"        -- Item picker
```

---

## Buttons

```lua
"add_button|name|label|noflags|0|0|"              -- Standard button
"add_small_font_button|name|label|noflags|0|0|"   -- Small font button
"add_button|name|label|off|0|0|"                   -- Disabled button
"add_button_with_icon|name|text|option|itemID|val|" -- Button with icon
"add_button_with_icon|big/small|label|flags|iconID|hoverNumber|"
"add_custom_button|name|option|"                   -- Custom button
"add_community_button|button|btnName|noflags|0|0|" -- Community button
"add_achieve_button|achName|achToGet|achID|unk|"   -- Achievement button
```

### Button with Icon Variants
```lua
"add_button_with_icon|btnName|text|staticBlueFrame|itemID|left|"
"add_button_with_icon|btnName|text|staticBlueFrame[is_count_label]|itemID|left|"
"add_button_with_icon|btnName|text|staticBlueFrame[no_padding_x]|itemID|left|"
"add_button_with_icon|btnName|progress|itemID|"
"add_button_with_icon|btnName|underText|itemID|"
"add_button_with_icon|btnName|itemID|"
```

---

## Labels with Icons

```lua
"add_label_with_icon|size|message|alignment|iconID|"
"add_label_with_icon_button|size|message|alignment|iconID|buttonName|"
"add_dual_layer_icon_label|size|message|alignment|iconID|background|foreground|size|toggle|"
"add_seed_color_icons|itemId|"
"add_friend_image_label_button|name|label|texture_path|size|texture_x|texture_y|"
```

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
```

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
