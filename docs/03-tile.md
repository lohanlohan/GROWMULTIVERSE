# Tile Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/tile) + [Nperma Docs](https://docs.nperma.my.id/docs/tile.html)

Tile object merepresentasikan satu block/tile di world. Coordinate system: (0,0) di top-left.

---

## Position

```lua
tile:getPosX()    -- Return: number (X coordinate dalam world grid)
tile:getPosY()    -- Return: number (Y coordinate dalam world grid)
```

---

## Structure

```lua
tile:getTileID()              -- Return: number (foreground item ID)
tile:getTileForeground()      -- Return: number (sama dengan getTileID)
tile:getTileBackground()      -- Return: number (background item ID)
tile:getTileItem()            -- Return: Item object (item data dari foreground)
```

---

## Tile Data

```lua
tile:getTileData(property)              -- Return: value (data property tertentu)
tile:setTileDataInt(property, value)    -- Set integer data property
```

> **PENTING:** Setelah `setTileDataInt`, panggil `world:updateTile(tile)` untuk refresh visual!

### TileDataProperties (Enumerations)

| Property | Value | Deskripsi |
|----------|-------|-----------|
| TILE_DATA_TYPE_SEED_FRUITS_COUNT | 0 | Jumlah buah di tree |
| TILE_DATA_TYPE_SEED_PLANTED_TIME | 1 | Waktu tanam seed |
| TILE_DATA_TYPE_MAGPLANT_ITEM_COUNT | 2 | Jumlah item di magplant |
| TILE_DATA_TYPE_VENDING_ITEM_COUNT | 3 | Jumlah item di vending |
| TILE_DATA_TYPE_SIGN_TEXT | 4 | Text di sign |
| TILE_DATA_TYPE_DOOR_TEXT | 5 | Text di door |
| TILE_DATA_TYPE_DOOR_IS_OPEN | 6 | Door terbuka? |
| TILE_DATA_TYPE_DOOR_DESTINATION | 7 | Destinasi door |
| TILE_DATA_TYPE_DOOR_ID | 8 | Door ID |
| TILE_DATA_TYPE_VENDING_ITEM_ID | 9 | Item ID di vending |
| TILE_DATA_TYPE_VENDING_PRICE | 10 | Harga vending |
| TILE_DATA_TYPE_VENDING_EARNED | 11 | Earning vending |
| TILE_DATA_TYPE_DISPLAY_BLOCK_ITEM_ID | 12 | Item ID display block |
| TILE_DATA_TYPE_MAGPLANT_ITEM_ID | 13 | Item ID di magplant |
| TILE_DATA_TYPE_MAGPLANT_IS_ACTIVE | 14 | Magplant aktif? |
| TILE_DATA_TYPE_MAGPLANT_IS_MAGNET | 15 | Mode magnet? |
| TILE_DATA_TYPE_MAGPLANT_SPACE | 16 | Magplant space |
| TILE_DATA_TYPE_MAGPLANT_GEMS | 17 | Gems di magplant |
| TILE_DATA_TYPE_MAGPLANT_SECOND_ITEM_ID | 18 | Second item ID |
| TILE_DATA_TYPE_MAGPLANT_IS_ENABLED | 19 | Magplant enabled? |
| TILE_DATA_TYPE_MAGPLANT_HARVEST_TREES | 20 | Harvest trees mode? |
| TILE_DATA_TYPE_MAGPLANT_COLLECT_SEEDS | 21 | Collect seeds mode? |

---

## Tile Flags

```lua
tile:getFlags()       -- Return: number (current flags)
tile:setFlags(flags)  -- Set flags
```

> **PENTING:** Setelah `setFlags`, panggil `world:updateTile(tile)` untuk apply!

### Flag Constants

```lua
TILE_FLAG_HAS_EXTRA_DATA       = bit.lshift(1, 0)
TILE_FLAG_HAS_PARENT           = bit.lshift(1, 1)
TILE_FLAG_WAS_SPLICED          = bit.lshift(1, 2)
TILE_FLAG_WILL_SPAWN_SEEDS_TOO = bit.lshift(1, 3)
TILE_FLAG_IS_SEEDLING          = bit.lshift(1, 4)
TILE_FLAG_FLIPPED_X            = bit.lshift(1, 5)
TILE_FLAG_IS_ON                = bit.lshift(1, 6)
TILE_FLAG_IS_OPEN_TO_PUBLIC    = bit.lshift(1, 7)
TILE_FLAG_BG_IS_ON             = bit.lshift(1, 8)
TILE_FLAG_FG_ALT_MODE          = bit.lshift(1, 9)
TILE_FLAG_IS_WET               = bit.lshift(1, 10)
TILE_FLAG_GLUED                = bit.lshift(1, 11)
TILE_FLAG_ON_FIRE              = bit.lshift(1, 12)
TILE_FLAG_PAINTED_RED          = bit.lshift(1, 13)
TILE_FLAG_PAINTED_GREEN        = bit.lshift(1, 14)
TILE_FLAG_PAINTED_BLUE         = bit.lshift(1, 15)
```

### Bitwise Operations

Gunakan `bit` library Lua untuk manipulasi flags:

```lua
-- Cek flag
if bit.band(tile:getFlags(), TILE_FLAG_PAINTED_RED) ~= 0 then
    -- tile berwarna merah
end

-- Tambah flag
local flags = bit.bor(tile:getFlags(), TILE_FLAG_IS_ON)
tile:setFlags(flags)
world:updateTile(tile)

-- Hapus flag
local flags = bit.band(tile:getFlags(), bit.bnot(TILE_FLAG_IS_ON))
tile:setFlags(flags)
world:updateTile(tile)

-- Combine paint colors (RGB)
local flags = bit.bor(TILE_FLAG_PAINTED_RED, TILE_FLAG_PAINTED_GREEN) -- kuning
tile:setFlags(bit.bor(tile:getFlags(), flags))
world:updateTile(tile)
```

### Common Use Cases
- **Paint Colors** — Combine RED, GREEN, BLUE untuk RGB
- **On/Off States** — Untuk switches, doors, interactive blocks
- **Visual Effects** — Flipped, wet, fire, glued states
