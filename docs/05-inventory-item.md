# Inventory Item Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/inventory-item) + [Nperma Docs](https://docs.nperma.my.id/docs/inventory-item.html)

Inventory item object didapat dari `player:getInventoryItems()`. Merepresentasikan satu slot item di inventory player.

---

## Methods

```lua
inventory_item:getItemID()      -- Return: number (item ID)
inventory_item:getItemCount()   -- Return: number (jumlah item)
```

---

## Contoh Penggunaan

```lua
-- Iterasi semua inventory items
local items = player:getInventoryItems()
for _, item in pairs(items) do
    local id = item:getItemID()
    local count = item:getItemCount()
    player:onConsoleMessage("Item " .. id .. " x" .. count)
end

-- Cari item tertentu di inventory
local items = player:getInventoryItems()
for _, item in pairs(items) do
    if item:getItemID() == 242 then -- World Lock
        player:onConsoleMessage("Kamu punya " .. item:getItemCount() .. " World Lock!")
    end
end
```
