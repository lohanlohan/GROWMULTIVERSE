# Custom Name Title

Sumber script: `scripts/custom-nameTitle.lua`

Script ini mengganti tampilan title/nama player saat player masuk world dengan mengirim variant `OnNameChanged`.

## Cara Kerja

1. Callback `onPlayerEnterWorldCallback` dipanggil saat player masuk world.
2. Script mengambil item ID `1446` lewat `getItem(1446)`.
3. Texture item dipakai sebagai `TitleTexture` dan koordinat texture dipakai sebagai `TitleTextureCoordinates`.
4. Script mengirim packet variant `OnNameChanged` ke netID player agar title tampil di client.

## Kode

```lua
print('(premium-script) custom name title by Nperma')

onPlayerEnterWorldCallback(function(world, player)
  local item = getItem(1446)
  player:sendVariant({
    "OnNameChanged",
    player:getName(),
    string.format(
      "{\"PlayerWorldID\":%d,\"TitleTexture\":\"game/%s\",\"TitleTextureCoordinates\":\"%d,%d\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
      player:getNetID(), item:getTexture(), item:getTextureX(), item:getTextureY())
  }, 0, player:getNetID())
end)
```

## Catatan

- Pastikan item ID `1446` valid di data item server.
- Jika `getItem(1446)` mengembalikan `nil`, script akan error saat mengakses `item:getTexture()`.
- Jika ingin aman untuk production, tambahkan validasi `if not item then return end` sebelum `sendVariant`.
