-- tile-extra-example.lua
-- Contoh penggunaan onGetTileExtraDataCallback + BinaryWriter
-- untuk mengontrol tampilan visual tile (label, icon, status, dll)
--
-- Dokumentasi lengkap: docs/07-callbacks.md → Tile Extra Data

print("(Loaded) tile-extra-example script")

onGetTileExtraDataCallback(function(world, tile, game_version)

    -- ============================================================
    -- Auto Surgeon Station (item ID 14666)
    -- ============================================================
    if tile:getTileForeground() == 14666 then

        -- Client lama tidak support extra data Auto Surgeon Station
        if game_version < 4.65 then return false end

        local wr = BinaryWriter("")

        wr:WriteUInt32(39)
        wr:WriteUInt8(163)

        -- outOfOrder: 0 = NO, 1 = YES
        wr:WriteUInt8(106)              -- 96 + #"outOfOrder" = 106
        wr:WriteString("outOfOrder")
        wr:WriteUInt8(0)

        -- selectedIllness: Illness ID (angka)
        wr:WriteUInt8(111)              -- 96 + #"selectedIllness" = 111
        wr:WriteString("selectedIllness")
        wr:WriteUInt8(21)               -- ID penyakit yang dipilih

        -- wlCount: jumlah WL (> 0 = tampilan emas)
        wr:WriteUInt8(103)              -- 96 + #"wlCount" = 103
        wr:WriteString("wlCount")
        wr:WriteUInt8(1)

        return wr:GetCurrentString()
    end

    -- Kembalikan false agar tile lain pakai default behavior
    return false
end)

--[[
CATATAN PENTING:
- String key length prefix = 96 + #str (ditulis sebagai WriteUInt8 sebelum WriteString)
- Berlaku untuk: Auto Surgeon Station, Vending Machine, Magplant, Display Block, Display Shelf, dll.
- Setelah return dari callback, JANGAN panggil world:updateTile() — tidak perlu.
- Jika return false, client pakai data tile bawaan server.
]]
