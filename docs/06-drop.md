# Drop Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/drop) + [Nperma Docs](https://docs.nperma.my.id/docs/drop.html)

Drop object merepresentasikan item yang di-drop (jatuh) di world. Didapat dari `world:getDroppedItems()`.

---

## Methods

```lua
drop:getItemID()       -- Return: number (item ID, sama dengan getItem(id))
drop:getItemCount()    -- Return: number (stack count)
drop:getPosX()         -- Return: number (X pixel position)
drop:getPosY()         -- Return: number (Y pixel position)
drop:getUID()          -- Return: number (unique identifier, untuk tracking)
drop:getFlags()        -- Return: number (flags, ownership/pickup restrictions)
```

---

## Contoh Penggunaan

```lua
-- List semua dropped items di world
local drops = world:getDroppedItems()
for _, drop in pairs(drops) do
    print(string.format("UID:%d ID:%d Count:%d Pos:(%d,%d)",
        drop:getUID(), drop:getItemID(), drop:getItemCount(),
        drop:getPosX(), drop:getPosY()))
end

-- Hapus dropped item tertentu
local drops = world:getDroppedItems()
for _, drop in pairs(drops) do
    if drop:getItemID() == 242 then -- Hapus semua World Lock drops
        world:removeDroppedItem(drop:getUID())
    end
end

-- Spawn item dan dapatkan UID-nya
local droppedItem = world:spawnItem(5, 5, 2, 1, 0) -- 1 dirt at (5,5)
if droppedItem then
    local uid = droppedItem:getUID()
    print("Spawned item UID: " .. uid)
end
```

> UID bersifat unik dan persist sampai item dipickup atau server restart. Gunakan untuk tracking system.
