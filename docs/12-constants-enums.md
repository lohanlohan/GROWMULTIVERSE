# Constants & Enumerations API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/constants) + [Nperma Docs](https://docs.nperma.my.id/docs/enumerations.html)

---

## World Punishment Types

```lua
WORLD_BAN = 1    -- Ban player dari world
WORLD_MUTE = 2   -- Mute player di world
```

---

## World Flags

Digunakan dengan `world:hasFlag(id)`:

| ID | Property | Deskripsi |
|----|----------|-----------|
| 0 | Open to public | World publik |
| 1 | Signal jammer | Signal dijam |
| 2 | Punch jammer | Punch disabled |
| 3 | Zombie jammer | Zombie disabled |
| 4 | Balloon jammer | Balloon disabled |
| 5 | Antigravity | Gravitasi terbalik |
| 6 | Ghost jammed | Ghost disabled |
| 7 | Pineapple guardian | Pineapple guardian |
| 8 | Firehouse | Firehouse aktif |
| 9 | Mini-mod | Mini-mod enabled |
| 10 | Xenonite crystal | Xenonite aktif |
| 11 | Silenced | Chat silenced |
| 12 | Silenced admins ignore | Silence kecuali admin |
| 13 | Instant collect gems | Gems auto-collect |
| 14 | Block dropped items | Tidak bisa drop |
| 15 | Disable ghost | Ghost disabled |
| 16 | Disable cheats | Cheat disabled |
| 17 | Disable one-hit | One-hit disabled |

---

## Ghost Types

```lua
GHOST_NORMAL     = 1    -- Speed: 33
GHOST_ANCESTOR   = 4    -- Speed: 33
GHOST_SHARK      = 6    -- Speed: 33
GHOST_WINTERFEST = 7    -- Speed: 33
GHOST_BOSS       = 11   -- Speed: 33
GHOST_MIND       = 12   -- Speed: 132
```

---

## Subscription Types

```lua
TYPE_SUPPORTER                = 0
TYPE_SUPER_SUPPORTER          = 1
TYPE_YEAR_SUBSCRIPTION        = 2
TYPE_MONTH_SUBSCRIPTION       = 3
TYPE_GROWPASS                  = 4
TYPE_TIKTOK                   = 5
TYPE_BOOST                    = 6
TYPE_STAFF                    = 7
TYPE_FREE_DAY_SUBSCRIPTION    = 8
TYPE_FREE_3_DAY_SUBSCRIPTION  = 9
TYPE_FREE_14_DAY_SUBSCRIPTION = 10
```

---

## Item Priced Rarity

| Value | Level |
|-------|-------|
| 0 | No Info |
| 1 | Common |
| 2 | Uncommon |
| 3 | Rare |
| 4 | Very Rare |
| 5 | Epic |
| 6 | Legendary |
| 7 | Mythical |

---

## Discord ReplyFlags

```lua
ReplyFlags = {
    CROSSPOSTED              = bit.lshift(1, 0),
    IS_CROSSPOST             = bit.lshift(1, 1),
    SUPRESS_EMBEDS           = bit.lshift(1, 2),
    SOURCE_MESSAGE_DELETED   = bit.lshift(1, 3),
    URGENT                   = bit.lshift(1, 4),
    HAS_THREAD               = bit.lshift(1, 5),
    EPHEMERAL                = bit.lshift(1, 6),
    LOADING                  = bit.lshift(1, 7),
    THREAD_MENTION_FAILED    = bit.lshift(1, 8),
    SUPRESS_NOTIFICATIONS    = bit.lshift(1, 12),
    IS_VOICE_MESSAGE         = bit.lshift(1, 13),
    HAS_SNAPSHOT             = bit.lshift(1, 14),
    USING_COMPONENTS_V2      = bit.lshift(1, 15)
}
```

---

## Tile Flags

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

---

## Tile Data Properties

```lua
TILE_DATA_TYPE_SEED_FRUITS_COUNT       = 0
TILE_DATA_TYPE_SEED_PLANTED_TIME       = 1
TILE_DATA_TYPE_MAGPLANT_ITEM_COUNT     = 2
TILE_DATA_TYPE_VENDING_ITEM_COUNT      = 3
TILE_DATA_TYPE_SIGN_TEXT               = 4
TILE_DATA_TYPE_DOOR_TEXT               = 5
TILE_DATA_TYPE_DOOR_IS_OPEN            = 6
TILE_DATA_TYPE_DOOR_DESTINATION        = 7
TILE_DATA_TYPE_DOOR_ID                 = 8
TILE_DATA_TYPE_VENDING_ITEM_ID         = 9
TILE_DATA_TYPE_VENDING_PRICE           = 10
TILE_DATA_TYPE_VENDING_EARNED          = 11
TILE_DATA_TYPE_DISPLAY_BLOCK_ITEM_ID   = 12
TILE_DATA_TYPE_MAGPLANT_ITEM_ID        = 13
TILE_DATA_TYPE_MAGPLANT_IS_ACTIVE      = 14
TILE_DATA_TYPE_MAGPLANT_IS_MAGNET      = 15
TILE_DATA_TYPE_MAGPLANT_SPACE          = 16
TILE_DATA_TYPE_MAGPLANT_GEMS           = 17
TILE_DATA_TYPE_MAGPLANT_SECOND_ITEM_ID = 18
TILE_DATA_TYPE_MAGPLANT_IS_ENABLED     = 19
TILE_DATA_TYPE_MAGPLANT_HARVEST_TREES  = 20
TILE_DATA_TYPE_MAGPLANT_COLLECT_SEEDS  = 21
```

---

## Player Clothing Slots

```lua
PlayerClothes.Hat    = 0   -- atau PLAYER_CLOTHES_HAT
PlayerClothes.Shirt  = 1
PlayerClothes.Pants  = 2
PlayerClothes.Feet   = 3
PlayerClothes.Face   = 4
PlayerClothes.Hand   = 5   -- atau PLAYER_CLOTHES_HAND
PlayerClothes.Back   = 6
PlayerClothes.Hair   = 7   -- atau PLAYER_CLOTHES_HAIR
```

---

## Role Flags (Bitwise, Nperma)

```lua
ACCESS_ALL_WORLDS                      = bit.lshift(1, 0)
ALLOW_DROPPING_UNTRADEABLE_ITEMS       = bit.lshift(1, 1)
ALLOW_FULL_ACCESS_BLAST_DESIGNER       = bit.lshift(1, 2)
BYPASS_ANTICHEAT                       = bit.lshift(1, 3)
ALLOW_ENTER_NUKED_WORLDS               = bit.lshift(1, 4)
ALLOW_ENTER_ANY_WORLDS                 = bit.lshift(1, 5)
INCREASE_BUILD_PUNCH_RANGE_SMALL       = bit.lshift(1, 6)
INCREASE_BUILD_PUNCH_RANGE_MEDIUM      = bit.lshift(1, 7)
INCREASE_BUILD_PUNCH_RANGE_UNLIMITED   = bit.lshift(1, 8)
BYPASS_ANTICHEAT_RANGE_CHECKS          = bit.lshift(1, 9)
DISABLE_ALL_COOLDOWN_EFFECTS           = bit.lshift(1, 10)
ALLOW_USE_SPK_COMMANDS                 = bit.lshift(1, 11)
ALLOW_FIND_ALL_ITEMS                   = bit.lshift(1, 12)
ALLOW_FIND_ALL_BLOCKS_AND_CLOTHES      = bit.lshift(1, 13)
BYPASS_BAD_WORDS_FILTER                = bit.lshift(1, 14)
BYPASS_BLOCKED_ITEMS_FILTER            = bit.lshift(1, 15)
BYPASS_ECONOMY_SCAN                    = bit.lshift(1, 16)
ADVANCED_ECONOMY_ACCESS                = bit.lshift(1, 17)
ADVANCED_RENDER_ACCESS                 = bit.lshift(1, 18)
DISABLE_SOME_COOLDOWN_EFFECTS          = bit.lshift(1, 19)
ALLOW_UNLIMITED_ZOOM                   = bit.lshift(1, 20)
ALLOW_BREAKING_BEDROCK_AND_MAIN_DOOR   = bit.lshift(1, 21)
ALLOW_PULL_FROM_OTHER_WORLDS           = bit.lshift(1, 22)
SHOW_IN_MODS_LIST                      = bit.lshift(1, 23)
BYPASS_BROADCAST_LEVEL_CHECK           = bit.lshift(1, 24)
GET_BONUS_XP                           = bit.lshift(1, 25)
EXTRA_FISHING_ITEMS                    = bit.lshift(1, 26)
REDUCE_TREE_GROWTIME                   = bit.lshift(1, 27)
```

---

## Item Category Flags (Bitwise, Nperma)

```lua
BETA         = bit.lshift(1, 0)
AUTO_PICKUP  = bit.lshift(1, 1)
MOD          = bit.lshift(1, 2)
RANDOM_GROW  = bit.lshift(1, 3)
PUBLIC       = bit.lshift(1, 4)
FOREGROUND   = bit.lshift(1, 5)
HOLIDAY      = bit.lshift(1, 6)
UNTRADABLE   = bit.lshift(1, 7)
```

---

## Item Editable Flags (Bitwise, Nperma)

```lua
FLIPPED    = bit.lshift(1, 0)
EDITABLE   = bit.lshift(1, 1)
SEEDLESS   = bit.lshift(1, 2)
PERMANENT  = bit.lshift(1, 3)
DROPLESS   = bit.lshift(1, 4)
NOSELF     = bit.lshift(1, 5)
NOSHADOW   = bit.lshift(1, 6)
WORLDLOCK  = bit.lshift(1, 7)
```

---

## Dialog Data Keys

Di `onPlayerDialogCallback`, parameter `data` berisi:

```lua
data["dialog_name"]    -- Nama dialog (dari end_dialog)
data["buttonClicked"]  -- ID button yang diklik
data["input_name"]     -- Value dari text_input dengan name "input_name"
data["checkbox_name"]  -- "0" atau "1" dari checkbox
```

---

## Role Quest Types (Nperma)

Digunakan dengan `player:getRoleQuestLevel(type)`:
- `PlayerRoleQuestTypes.Farmer` (dan type lainnya sesuai server config)
