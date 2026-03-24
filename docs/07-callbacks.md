# Callbacks API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/callback) + [Nperma Docs](https://docs.nperma.my.id/docs/callback-event.html)

Callbacks adalah event handlers yang trigger saat aksi game tertentu terjadi.
- `return true` = **prevent** default behavior
- `return false` = **allow** default behavior

---

## Global Tick

```lua
-- (Nperma only) Global tick setiap 100ms
onTick(function()
end)
```

---

## World & Player Tick

```lua
-- ⚠️ Dipanggil setiap 100ms PER WORLD — jaga agar ringan!
onWorldTick(function(world)
end)

-- ⚠️ Dipanggil setiap 1000ms PER PLAYER
onPlayerTick(function(player)
end)
```

---

## Login & Connection

```lua
onPlayerLoginCallback(function(player)
end)

onPlayerFirstTimeLoginCallback(function(player)
end)

onPlayerDisconnectCallback(function(player)
end)

-- (Nperma only) Saat player register akun baru
onPlayerRegisterCallback(function(world, player)
end)
```

---

## World Enter/Leave

```lua
onPlayerEnterWorldCallback(function(world, player)
end)

onPlayerLeaveWorldCallback(function(world, player)
end)

onPlayerEnterDoorCallback(function(world, player, targetWorldName, doorID)
    -- return true = prevent enter
end)

-- (Nperma only) World loaded/offloaded dari memory
onWorldLoaded(function(world)
end)

onWorldOffloaded(function(world)
end)
```

---

## Commands & Dialog

```lua
onPlayerCommandCallback(function(world, player, fullCommand)
    -- return false = disable command
end)

-- Alias: onPlayerDialogCallback / onPlayerDialogResponseCallback
onPlayerDialogCallback(function(world, player, data)
    -- data["dialog_name"] = string
    -- data["buttonClicked"] = string
    -- return true = prevent default
end)
```

---

## Tile Interactions

```lua
onTilePunchCallback(function(world, avatar, tile)
    -- return true = prevent breaking
end)

onTilePlaceCallback(function(world, player, tile, placingID)
    -- return true = prevent placement
end)

onTileWrenchCallback(function(world, player, tile)
    -- return true = prevent default wrench
end)

-- (Nperma only) Tile break event
onTileBreakCallback(function(world, player, tile)
end)

onPlayerActivateTileCallback(function(world, player, tile)
    -- Triggers: Legendary Orb, Wolf Totem, Spirit Board, dll
    -- return true = block default behavior
end)
```

---

## Tile Extra Data

> ⚠️ **Advanced** — Bekerja langsung dengan binary structure Growtopia. Salah format bisa crash client.

```lua
onGetTileExtraDataCallback(function(world, tile, game_version)
    -- Dipanggil saat client meminta extra data tile (label, icon, display info, dll)
    -- game_version = float (e.g. 4.65) — cek versi client sebelum kirim data
    -- return BinaryWriter string = kirim custom extra data
    -- return false = gunakan default behavior
end)
```

**Contoh — Auto Surgeon Station (item 14666):**
```lua
onGetTileExtraDataCallback(function(world, tile, game_version)
    if tile:getTileForeground() == 14666 then
        if game_version < 4.65 then return false end  -- old client tidak support

        local wr = BinaryWriter("")
        wr:WriteUInt32(39)
        wr:WriteUInt8(163)

        wr:WriteUInt8(106)          -- 96 + len("outOfOrder") = 106
        wr:WriteString("outOfOrder")
        wr:WriteUInt8(0)            -- 0 = NO, 1 = YES

        wr:WriteUInt8(111)          -- 96 + len("selectedIllness") = 111
        wr:WriteString("selectedIllness")
        wr:WriteUInt8(21)           -- Illness ID

        wr:WriteUInt8(103)          -- 96 + len("wlCount") = 103
        wr:WriteString("wlCount")
        wr:WriteUInt8(1)            -- WL count (> 0 = golden display)

        return wr:GetCurrentString()
    end
    return false
end)
```

**BinaryWriter API:**
```lua
local wr = BinaryWriter("")        -- Buat writer baru
wr:WriteUInt8(value)               -- Tulis 1 byte (0–255)
wr:WriteUInt32(value)              -- Tulis 4 byte unsigned int
wr:WriteString(str)                -- Tulis string
wr:GetCurrentString()              -- Return: binary string hasil
```

> **Tips:** String key length prefix = `96 + #str` (ditulis sebagai UInt8 sebelum WriteString).
> Berlaku untuk: Auto Surgeon Station, Vending Machine, Magplant, Display Block, Display Shelf, dll.

---

## Player Combat & Death

```lua
onPlayerPunchPlayerCallback(function(player, world, target_player)
    -- Note: parameter order (player, world) berbeda dari biasa!
end)

-- (Nperma only) parameter order berbeda:
-- onPlayerPunchPlayerCallback(function(world, player, second_player)

onPlayerPunchNPCCallback(function(player, world, target_npc)
end)

onPlayerKillCallback(function(world, player, killedPlayer)
end)

onPlayerDeathCallback(function(world, player, isRespawn)
end)

-- Punch position (air punch detection)
onPlayerPunchCallback(function(world, player, x, y)
end)
```

---

## Items: Drop, Pickup, Equip

```lua
onPlayerDropCallback(function(world, player, itemID, itemCount)
    -- return true = prevent drop
end)

onPlayerPickupItemCallback(function(world, player, itemID, itemCount)
    -- return true = prevent pickup
end)

onPlayerEquipClothingCallback(function(world, player, itemID)
    -- return true = prevent equip
end)

onPlayerUnequipClothingCallback(function(world, player, itemID)
    -- return true = prevent unequip
end)

-- (Nperma only) AFTER equip/unequip berhasil
onPlayerEquippedClothingCallback(function(world, player, item_id)
end)

onPlayerUnequippedClothingCallback(function(world, player, item_id)
end)
```

---

## Consumable

```lua
onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    -- clickedPlayer bisa nil
    -- return true = prevent default use
end)
```

---

## Farming & Trees

```lua
onPlayerPlantCallback(function(world, player, tile)
end)

onPlayerHarvestCallback(function(world, player, tile)
end)

onPlayerSpliceSeedCallback(function(world, player, tile, seed_id)
    -- return true = block splicing
end)
```

---

## Fishing

```lua
onPlayerCatchFishCallback(function(world, player, itemID, itemCount)
end)

onPlayerTrainFishCallback(function(world, player)
end)
```

---

## Economy & Gems

```lua
onPlayerGemsObtainedCallback(function(world, player, amount)
end)

onPlayerEarnGrowtokenCallback(function(world, player, itemCount)
end)

onPlayerXPCallback(function(world, player, amount)
end)

onPlayerLevelUPCallback(function(world, player, currentLevel)
    -- return true = block level-up
end)
```

---

## Minigames & Activities

```lua
onPlayerCrimeCallback(function(world, player, itemID, itemCount)
end)

onPlayerSurgeryCallback(function(world, player, reward_id, reward_count, target_player)
    -- target_player = nil jika Surg-E machine
end)

onPlayerGeigerCallback(function(world, player, itemID, itemCount)
end)

onPlayerCatchGhostCallback(function(world, player, itemID, itemCount)
end)

onPlayerFirePutOutCallback(function(world, player, tile)
end)

onPlayerStartopiaCallback(function(world, player, item_id, item_count)
end)

onPlayerCookingCallback(function(world, player, item_id, item_count)
end)

onPlayerDungeonEntitySlainCallback(function(world, player, entity_type)
end)

onPlayerProviderCallback(function(world, player, tile, itemID, itemCount)
end)

onPlayerHarmonicCallback(function(world, player, tile, itemID, itemCount)
end)
```

---

## Vending & Storage

```lua
onPlayerVendingBuyCallback(function(world, player, tile, item_id, item_count)
    -- return true = block purchase
end)

onPlayerDepositCallback(function(world, player, tile, itemid, itemcount)
    -- Donation box / storage box
    -- return true = block deposit
end)
```

---

## Trading & Recycling (Nperma Only)

```lua
onPlayerTradeCallback(function(world, player1, player2, items1, items2)
end)

onPlayerTrashCallback(function(world, player, item_id, item_amount)
    -- return true = prevent trashing
end)

onPlayerRecycleCallback(function(world, player, item_id, item_amount, gems_earned)
    -- return true = prevent recycling
end)

onPlayerConvertItemCallback(function(world, player, item_id)
    -- Double-tap convert (100 WL -> 1 DL)
    -- return true = prevent default
end)
```

---

## Social (Nperma Only)

```lua
onPlayerWrenchCallback(function(world, player, wrenchingPlayer)
    -- wrenchingPlayer:getType() == 25 untuk Lua NPC
end)

onPlayerAddFriendCallback(function(world, player, addedPlayer)
end)

onPlayerBoostClaimCallback(function(player)
end)

onPlayerDNACallback(function(world, player, resultID, resultAmount)
end)
```

---

## Generic Action (Nperma Only)

```lua
onPlayerActionCallback(function(world, player, data)
    -- data["action"] = action name
end)
```

---

## Low-Level Packets (Nperma Only)

### onPlayerVariantCallback

Intercept variant packet yang dikirim server ke client (SEBELUM sampai ke player). Berguna untuk memodifikasi dialog yang dikirim server secara native.

```lua
onPlayerVariantCallback(function(player, variant, delay, netID)
    -- variant[1] = nama variant (string), e.g. "OnDialogRequest", "OnSetClothing", dll.
    -- variant[2..n] = parameter variant
    -- delay = delay pengiriman (ms)
    -- netID = net ID target (-1 = broadcast)

    -- return true  → suppress original variant (tidak dikirim ke client)
    -- return false → biarkan original variant diteruskan ke client
    return false
end)
```

**Contoh: Intercept & modifikasi item info dialog**
```lua
onPlayerVariantCallback(function(player, variant, delay, netID)
    if variant[1] ~= "OnDialogRequest" then return false end

    local content = tostring(variant[2] or "")

    -- Hanya proses dialog item info (end_dialog|info_box)
    -- Skip jika sudah pernah diproses (cegah infinite loop)
    if not content:find("info_box", 1, true) then return false end
    if content:find("already_processed", 1, true) then return false end

    -- Modifikasi dialog
    local modified = content
    modified = modified:gsub("[^\n]*kata_yang_mau_dihapus[^\n]*\n?", "")

    -- Inject konten baru sebelum end_dialog
    local pos = modified:find("end_dialog", 1, true)
    if pos then
        modified = modified:sub(1, pos - 1) .. "add_textbox|Konten baru|\n" .. modified:sub(pos)
    end

    -- Tandai sudah diproses
    modified = "embed_data|already_processed|1|\n" .. modified

    -- Kirim dialog yang sudah dimodifikasi
    player:onDialogRequest(modified)
    return true  -- suppress original
end)
```

> **PENTING — Format Dialog Server:**
> Dialog yang dikirim SERVER menggunakan `add_label_with_ele_icon` (bukan `add_label_with_icon`).
> Saat extract item ID dari dialog server, gunakan pattern ini:
> ```lua
> local itemID = tonumber(
>     content:match("This item ID is (%d+)")
>     or content:match("add_label_with_ele_icon|big|[^\n]+|left|(%d+)|")
>     or content:match("|left|(%d+)|")
> )
> ```

> **DEBUG TIP:**
> Jangan print raw dialog content ke `player:onConsoleMessage()` langsung — karakter `|` dan backtick akan diinterpretasikan oleh console. Escape dulu:
> ```lua
> local debug = content:sub(1, 300)
>     :gsub("\n", "[LF]")
>     :gsub("|", "[P]")
>     :gsub("`", "[BT]")
> player:onConsoleMessage("`0" .. debug)
> ```

---

```lua
onPlayerRawPacketCallback(function(player, data)
end)
```

---

## Server Events

```lua
onAutoSaveRequest(function()
    -- Dipanggil periodik, gunakan saveDataToServer() di sini
end)

-- (Nperma only) Event changed
onEventChangedCallback(function(newEventID, oldEventID)
end)
```

---

## HTTP Request Handler

```lua
onHTTPRequest(function(req)
    -- req.method = "get" / "post"
    -- req.path = "/endpoint"
    -- req.body = string (POST body)
    -- req.headers = table
    -- HARUS return response table!
    return {
        status = 200,
        body = "OK",
        headers = { ["Content-Type"] = "text/plain" }
    }
end)
```

URL format: `https://api.gtps.cloud/g-api/{server_port}/...`

---

## Discord Callbacks

```lua
onDiscordBotReadyCallback(function()
end)

onDiscordSlashCommandCallback(function(event)
    -- event:getCommandName()
    -- event:getParameter(name)
    -- event:thinking() / event:thinking(1) untuk ephemeral
    -- event:editOriginalResponse(content, components, flags)
    -- event:getPlayer() -- jika user linked, return GTPS player
end)

onDiscordMessageCreateCallback(function(event)
    -- event:getContent()
    -- event:getChannelID()
    -- event:getAuthorID()
    -- event:getMentionedUsers()
    -- event:isBot()
    -- event:reply(content, components, flags, mention_replied_user)
end)

onDiscordButtonClickCallback(function(event)
    -- event:getCustomID()
    -- event:reply(content, components, flags)
    -- event:dialog(dialogData)
end)

onDiscordFormSubmitCallback(function(event)
    -- event:getCustomID()
    -- event:getValue(fieldID)
    -- event:reply(content, components, flags)
end)
```
