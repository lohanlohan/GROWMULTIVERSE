# Item Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/item) + [Nperma Docs](https://docs.nperma.my.id/docs/item.html)

Item object menyimpan data global item (berlaku untuk semua instance item tersebut). Akses via `getItem(itemID)`.

---

## Accessing Item Data

```lua
getItem(itemID)   -- Return: Item object (global data)
getItemsCount()   -- Return: number (total items di server, nperma)
```

---

## Item Information

```lua
item:getName()            -- Return: string (nama item)
item:getRarity()          -- Return: number (rarity)
item:getPricedRarity()    -- Return: number (0-7, berdasarkan harga real GT)
item:getActionType()      -- Return: number (action type, e.g. clothing, seed)
item:getCategoryType()    -- Return: number (category type, bitwise flags)
item:getEditableType()    -- Return: number (editable type, bitwise flags)
item:getNetID()           -- Return: number (item net ID)
```

### Priced Rarity Scale
| Value | Level | Deskripsi |
|-------|-------|-----------|
| 0 | No Info | Tidak ada informasi |
| 1 | Common | Umum |
| 2 | Uncommon | Tidak umum |
| 3 | Rare | Langka |
| 4 | Very Rare | Sangat langka |
| 5 | Epic | Epic |
| 6 | Legendary | Legendary |
| 7 | Mythical | Mythical |

### ItemCategoryFlags (Bitwise, dari Nperma)
| Flag | Bit Value |
|------|-----------|
| BETA | bit.lshift(1, 0) |
| AUTO_PICKUP | bit.lshift(1, 1) |
| MOD | bit.lshift(1, 2) |
| RANDOM_GROW | bit.lshift(1, 3) |
| PUBLIC | bit.lshift(1, 4) |
| FOREGROUND | bit.lshift(1, 5) |
| HOLIDAY | bit.lshift(1, 6) |
| UNTRADABLE | bit.lshift(1, 7) |

### ItemEditableFlags (Bitwise, dari Nperma)
| Flag | Bit Value |
|------|-----------|
| FLIPPED | bit.lshift(1, 0) |
| EDITABLE | bit.lshift(1, 1) |
| SEEDLESS | bit.lshift(1, 2) |
| PERMANENT | bit.lshift(1, 3) |
| DROPLESS | bit.lshift(1, 4) |
| NOSELF | bit.lshift(1, 5) |
| NOSHADOW | bit.lshift(1, 6) |
| WORLDLOCK | bit.lshift(1, 7) |

---

## Growth & Behavior

```lua
item:getGrowTime()            -- Return: number (grow time dalam detik)
item:setGrowTime(seconds)     -- Set grow time (GLOBAL, affects semua instance)
item:setActionType(type)      -- Set action type (GLOBAL)
```

---

## Description & Display

```lua
item:setDescription(text)     -- Set description (GLOBAL)
```

---

## Item Value & Economy

```lua
item:setPrice(price)      -- Set harga item
item:isObtainable()       -- Return: boolean (bisa diperoleh?)
```

---

## XP & Gem Rewards

```lua
item:getGems(world, player)   -- Return: number (gems yang di-drop, consider player buffs)
item:getXP(world, player)     -- Return: number (XP yang didapat, consider player buffs)
```

> `getGems()` dan `getXP()` bisa memperhitungkan player buffs jika parameter world & player diberikan.
