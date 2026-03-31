# Item Editable Flags (Skoobz)

> Sumber utama: https://docs.skoobz.dev/structures/constants#item-editable-flags

Dokumen ini melengkapi `12-constants-enums.md` dengan penamaan flag versi Skoobz terbaru.

## Tujuan

- Menjelaskan cara membaca `item:getEditableFlags()`.
- Menjelaskan batasan: flag item bersifat data item global, bukan kontrol runtime per-player.
- Menyediakan pola runtime untuk benar-benar blok `drop` dan `trade` item tertentu.

## Daftar Flag

```lua
ItemEditableFlags = {
    ITEM_EDITABLE_FLAG_WRENCHABLE   = bit.lshift(1, 0),
    ITEM_EDITABLE_FLAG_CAN_EQUIP    = bit.lshift(1, 1),
    ITEM_EDITABLE_FLAG_UNTRADEABLE  = bit.lshift(1, 2),
    ITEM_EDITABLE_FLAG_PERMANENT    = bit.lshift(1, 3),
    ITEM_EDITABLE_FLAG_UNDROPPABLE  = bit.lshift(1, 4),
    ITEM_EDITABLE_FLAG_AUTO_PICKUP  = bit.lshift(1, 5),
    ITEM_EDITABLE_FLAG_MODDABLE     = bit.lshift(1, 6),
    ITEM_EDITABLE_FLAG_GUILD_ITEM   = bit.lshift(1, 7),
    ITEM_EDITABLE_FLAG_NO_DROP      = bit.lshift(1, 8),
    ITEM_EDITABLE_FLAG_NO_SELF      = bit.lshift(1, 9)
}
```

## Contoh Cek Flag

```lua
local item = getItem(242)
local flags = item:getEditableFlags()

if bit.band(flags, ItemEditableFlags.ITEM_EDITABLE_FLAG_UNTRADEABLE) ~= 0 then
    print("Item cannot be traded")
end

if bit.band(flags, ItemEditableFlags.ITEM_EDITABLE_FLAG_UNDROPPABLE) ~= 0 then
    print("Item cannot be dropped")
end
```

## Penting: Flag vs Runtime Enforcement

`item:getEditableFlags()` digunakan untuk membaca properti item dari database item.
Untuk kebutuhan gameplay custom (misalnya hanya item tertentu tidak boleh drop/trade), enforcement paling aman tetap di callback:

- `onPlayerDropCallback` untuk blok drop.
- `onPlayerTradeCallback` (Nperma) untuk blok trade.

Kenapa?
- Lebih presisi per item, per kondisi, dan per fitur.
- Tidak mengubah data global semua item di server.

## Template Runtime No-Drop / No-Trade

```lua
local LOCKED_ITEMS = {
    [25036] = true,
    [25038] = true,
}

onPlayerDropCallback(function(world, player, itemID, itemCount)
    if not LOCKED_ITEMS[itemID] then
        return false
    end

    player:onConsoleMessage("`4This item cannot be dropped.")
    player:playAudio("bleep_fail.wav")
    return true
end)

onPlayerTradeCallback(function(world, player1, player2, items1, items2)
    local function hasLocked(items)
        if type(items) ~= "table" then
            return false
        end

        for _, invItem in pairs(items) do
            if invItem and invItem.getItemID and LOCKED_ITEMS[invItem:getItemID()] then
                return true
            end
        end

        return false
    end

    if not hasLocked(items1) and not hasLocked(items2) then
        return false
    end

    player1:onConsoleMessage("`4This item cannot be traded.")
    player2:onConsoleMessage("`4This item cannot be traded.")
    player1:playAudio("bleep_fail.wav")
    player2:playAudio("bleep_fail.wav")
    return true
end)
```

## Rekomendasi Proyek Ini

Untuk item inject role (`25036`, `25038`), gunakan callback guard runtime seperti di atas.
Ini konsisten dengan architecture nested loader dan lebih aman daripada mengandalkan asumsi flag saja.
