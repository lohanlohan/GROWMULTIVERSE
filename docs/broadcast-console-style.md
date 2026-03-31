# Broadcast Console Styling (CT Prefix)
> Last updated: April 2026
> Scope: command broadcast seperti /lsb, /msb, /osb, /ssb, /scsb

## Ringkasan

Untuk membuat tampilan console message berbeda, gunakan variant:

```lua
player:sendVariant({"OnConsoleMessage", "CT:[SB] your message"})
```

Format di atas bisa memberi style chat yang berbeda dibanding `player:onConsoleMessage(...)` biasa.

## Kenapa Echo Command Tidak Bisa Di-overwrite

Saat player mengetik command (contoh `/lsb a`), baris pertama yang muncul adalah **echo bawaan client**.

Echo ini:
- Bukan output dari script Lua server.
- Tidak bisa diubah dengan `gsub`.
- Tidak bisa dihapus/replace penuh dari server packet biasa.

Jadi `gsub` hanya mempengaruhi string yang server kirim, bukan input line milik client.

## Pola yang Direkomendasikan

1. Biarkan echo client apa adanya (hindari kirim echo tambahan agar tidak dobel).
2. Kirim hasil broadcast dengan `CT:[SB]` supaya tampilan utama tetap custom.
3. Untuk pesan sistem internal (usage, sukses potong gems, denied), boleh tetap pakai `onConsoleMessage` jika ingin tampak sebagai system default.

## Helper yang Disarankan

```lua
local function sendConsole(player, message, channel)
    if not player then
        return
    end

    local ch = channel or "SB"
    local prefix = "CT:[" .. ch .. "] "

    if player.sendVariant then
        player:sendVariant({"OnConsoleMessage", prefix .. tostring(message or "")})
    else
        player:onConsoleMessage(tostring(message or ""))
    end
end
```

## Contoh Pemakaian

```lua
-- Message broadcast ke semua player dengan style SB
for _, p in ipairs(getAllPlayers()) do
    sendConsole(p, "** [Lord] ** from (Hello) in [START] ** : a", "SB")
end

-- Message sistem ke sender (default style)
sender:onConsoleMessage(">> Lord-Broadcast sent. Used 200 Gems. (196830 left)")
```

## Catatan Debug Cepat

Jika style CT tidak muncul:
- Cek apakah payload variant benar: `{"OnConsoleMessage", "CT:[SB] ..."}`.
- Cek apakah script tidak fallback ke `onConsoleMessage` karena `sendVariant` unavailable.
- Cek apakah ada command lain yang juga mengirim pesan mirror sehingga terlihat dobel.
