# World Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/world) + [Nperma Docs](https://docs.nperma.my.id/docs/world.html)

World object diakses dengan colon operator: `world:methodName()`

---

## World Info

```lua
world:getName()                      -- Return: string (nama world)
world:getID()                        -- Return: number (world ID)
world:getSizeX()                     -- Return: number (horizontal size)
world:getSizeY()                     -- Return: number (vertical size)
world:getWorldSizeX()                -- Alias getSizeX
world:getWorldSizeY()                -- Alias getSizeY
world:getTiles()                     -- Return: table of all Tile objects
world:getTilesByActionType(actionType) -- Return: tiles dengan action type tertentu
world:getWorldLock()                 -- Return: Tile (world lock) atau nil
world:setLobbyWorld(lobbyWorldName)  -- Set lobby world untuk minigames
```

---

## Ownership

```lua
world:getOwner(player)       -- Return: boolean (player adalah owner?)
world:setOwner(userID)       -- Set player sebagai owner
world:removeOwner(userID)    -- Hapus player dari ownership
```

---

## Access Management

```lua
world:hasAccess(player)              -- Return: boolean (punya build access ke world?)
world:hasTileAccess(player, tile)    -- Return: boolean (punya access ke tile tertentu?)

-- Hanya bekerja jika world di-World Lock
world:addAccess(player, adminType)   -- Beri access (0=regular, 1=super-admin)
world:removeAccess(player)           -- Hapus world access

-- Tile-specific access (HATI-HATI — sangat powerful)
world:addTileAccess(player, tile)    -- Beri tile access permanent (BISA break locks!)
world:removeTileAccess(player, tile) -- Hapus tile access
world:removeAllTileAccess()          -- EMERGENCY: hapus semua tile access
```

> ⚠️ `addTileAccess` sangat powerful — jika beri access ke tile lock, player bisa break lock tersebut!

---

## Punishments

```lua
world:addPunishment(player, type, expire_timestamp, reason, by_user_id)
world:removePunishment(player, type)
world:clearPunishment(player, type)
world:getPunishment(player, type)    -- Return: punishment object atau nil
world:getAllPunishments()             -- Return: table of all punishments
```

**Punishment Types:**
- `WORLD_BAN = 1` — Ban dari world
- `WORLD_MUTE = 2` — Mute di world

**Punishment object properties:**
`invokerID`, `userID`, `type`, `expires`, `reason`, `IP`

---

## World Flags

```lua
world:hasFlag(id)  -- Return: boolean
```

| Flag ID | Property | Deskripsi |
|---------|----------|-----------|
| 0 | Open to public | World publik |
| 1 | Signal jammer | Signal dijam |
| 2 | Punch jammer | Punch disabled |
| 3 | Zombie jammer | Zombie disabled |
| 4 | Balloon jammer | Balloon disabled |
| 5 | Antigravity | Gravitasi terbalik |
| 6 | Ghost jammed | Ghost disabled |
| 7 | Pineapple guardian | Pineapple guardian aktif |
| 8 | Firehouse | Firehouse aktif |
| 9 | Mini-mod | Mini-mod enabled |
| 10 | Xenonite crystal | Xenonite aktif |
| 11 | Silenced | Chat di-silence |
| 12 | Silenced, admins ignore | Silence kecuali admin |
| 13 | Instant collect gems | Gems langsung terkumpul |
| 14 | Block dropped items | Item tidak bisa di-drop |
| 15 | Disable ghost | Ghost disabled |
| 16 | Disable cheats | Cheat/mod disabled |
| 17 | Disable one-hit | One-hit break disabled |

---

## Player Interaction

```lua
world:setPlayerPosition(player, x, y)            -- Teleport player ke tile coordinate
world:kill(player)                                 -- Kill player
world:setClothing(player, itemID)                 -- Force equip item
world:updateClothing(player)                       -- Update clothing visual
world:addXP(player, amount)                        -- Tambah XP
world:adjustGems(player, tile, gem_count, val)     -- Adjust gems dari tile action
```

---

## Players in World

```lua
world:getPlayers()                           -- Return: table of Player objects
world:getPlayersCount(includeInvisible)      -- Return: number (pass 1 untuk include invisible)
world:getVisiblePlayersCount()               -- Return: number
world:setPlayerCount(count)                  -- Set displayed count (cosmetic only)
```

---

## NPC System

```lua
world:createNPC(name, x, y)          -- Spawn NPC, return: Player object
world:removeNPC(npc)                  -- Hapus NPC
world:findNPCByName(name)             -- Return: Player object (NPC)

-- Visual effects (NPC)
npc:visualPunch(tile)                 -- NPC animasi punch/break (auto-rotate)
npc:visualBuild(tile)                 -- NPC animasi build/place (auto-rotate)
```

---

## Messaging & Effects

```lua
world:sendPlayerMessage(player, message)
world:onCreateChatBubble(x, y, text, netID)
world:onCreateExplosion(x, y, radius, power)
world:useItemEffect(playerNetID, itemID, targetNetID, effectDelay)
spawnGems(x, y, amount, player)              -- Global function, spawn gems
```

---

## Ghost Spawning

```lua
world:spawnGhost(tile, type, spawned_by_user_id, remove_in, m_speed)
```

**Parameters:**
- `tile` — Tile object spawn location
- `type` — Ghost type (lihat tabel)
- `spawned_by_user_id` — User ID (0 jika tidak ada)
- `remove_in` — Detik sampai hilang (0=permanent)
- `m_speed` — Movement speed

**Ghost Types:**
| Type | Constant | Speed |
|------|----------|-------|
| 1 | GHOST_NORMAL | 33 |
| 4 | GHOST_ANCESTOR | 33 |
| 6 | GHOST_SHARK | 33 |
| 7 | GHOST_WINTERFEST | 33 |
| 11 | GHOST_BOSS | 33 |
| 12 | GHOST_MIND | 132 |

---

## Path-Finding

```lua
world:findPathByTile(start_tile, end_tile, x, y)
```
- `x`, `y` — Maximum search distance (255 = entire world, tapi lambat)
- Return: table of steps `{x, y}` atau `nil` jika tidak ada path
- **Tips:** Gunakan 6-20 untuk performa bagus, 255 hanya jika perlu full world

---

## Tile Manipulation

```lua
world:getTile(x, y)                                          -- Return: Tile object (implisit dari contoh)
world:setTileForeground(tile, itemID, isVisual?, player?)    -- Set foreground
world:setTileBackground(tile, itemID, isVisual?, player?)    -- Set background
world:updateTile(tile)                                        -- Force visual update
world:punchTile(tile)                                         -- Simulasi punch (break logic)
world:getTileDroppedItems(tile)                               -- Return: table dropped items di tile
world:getPlatformByNetID(netID)                               -- Return: Tile platform object
```

---

## Items & Dropped Objects

```lua
world:getDroppedItems()                          -- Return: table of all Drop objects
world:removeDroppedItem(DropUID)                 -- Hapus dropped item by UID
world:removeAllObjects()                          -- ⚠️ Hapus SEMUA dropped items
world:spawnItem(x, y, itemID, count, center)     -- Spawn item, return: Drop object
-- center: 1 (default)=centered, 0=not centered

world:getMagplantRemoteTile(player)              -- Return: Tile (magplant remote)
world:useConsumable(player, tile, id, should_NOT_trigger_callback)
-- should_NOT_trigger_callback: 1=suppress callback, 0=trigger (default)
```

---

## Game Status

```lua
world:isGameActive()            -- Return: boolean
world:isGameActive(gameID)      -- Return: boolean (specific game)
world:onGameWinHighestScore()   -- Return: highest win score
```

---

## World Themes

```lua
world:getCurseThemeByNetID(netID)       -- Return: theme ID
world:setCurseTheme(netID, themeID)     -- Set curse theme
```

---

## Leaderboards

```lua
world:getLeaderboard(type)          -- Return: leaderboard data by type
world:getLeaderboardByWins()        -- Return: sorted by wins
world:getLeaderboardByBalance()     -- Return: sorted by balance
```

Leaderboard entry properties: `name`, `wins`, `balance`

---

## World Menu Customization

```lua
world:addWorldMenuButtonCallback(text, id)  -- Tambah custom button ke world menu
```

Handle button click via `onPlayerDialogResponseCallback`, cek `data["buttonClicked"]` == id
