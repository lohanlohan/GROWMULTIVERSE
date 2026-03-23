# Server & Global Functions API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/server-and-global) + [Nperma Docs](https://docs.nperma.my.id/docs/functions.html)

Global functions dipanggil langsung tanpa object prefix.

---

## Player & World Lookup

```lua
getPlayer(userID)                     -- Return: Player object (online) atau nil
getPlayerByName(name)                 -- Return: table of Player objects (nperma)
getAllPlayers()                        -- Return: table of ALL players (prefer over getServerPlayers)
getServerPlayers()                    -- Return: table of online players
getActiveWorlds()                     -- Return: table of loaded worlds (nperma)
getServerWorlds()                     -- Return: table of active worlds (skoobz)
getItem(itemID)                       -- Return: Item object
getItemsCount()                       -- Return: number (total items, nperma)
worldExists(name)                     -- Return: boolean (nperma)
```

---

## Event & Offer Management

```lua
getRequiredEvent()                    -- Return: required event
getCurrentServerDailyEvent()          -- Return: daily event
getServerCurrentEvent()               -- Return: current event
getIOTMItem()                         -- Return: IOTM item
setEvent(event_id)                    -- Set server event
setDailyEvent(event_id)               -- Set daily event
getEvents()                           -- Return: list {id, title, description, message}
getDailyEvents()                      -- Return: list {id, title, description}
getEventOffers()                      -- Return: event offers
getActiveDailyOffers()                -- Return: active daily offers
addDailyOfferPurchased(userID, itemID)
getRealGTItemsCount()                 -- Return: total real GT items
```

### Custom Events
```lua
registerLuaEvent({
    id = 50,
    title = "My Event",
    description = "Event description",
    message = "Event message"
})

registerLuaDailyEvent({
    id = 50,
    title = "Daily Event",
    description = "Description"
})
```

---

## Economy Tracking

```lua
getEcoQuantity(item_id)           -- Return: total item count (players + worlds)
getEcoQuantityPlayers(item_id)    -- Return: item count in player inventories
getEcoQuantityWorlds(item_id)     -- Return: item count in worlds
```

---

## XP & Gem Events (Nperma Only)

```lua
setGemEvent(multiplier)   -- Start gem event (0 atau 1 = stop)
setXPEvent(multiplier)    -- Start XP event (0 atau 1 = stop)
```

---

## Redeem Code System

```lua
local result = createRedeemCode({
    redeemCode = "SPECIAL123",
    obtainGems = 50,
    obtainCoins = 1000,
    obtainRole = 2,
    redeemItems = {
        { id = 1001, count = 3 },
        { id = 2002, count = 1 },
    },
    maxUses = 5,
    requireLevel = 10,
    requireRole = 1,
    requireGrowID = 1,          -- 1=true, 0=false
    requirePlaytime = 60,
    requireAccountAge = 7,
    redeemTitles = {
        { titleID = 5 },
        { titleID = 9 },
    }
})
-- result = string (code) atau "" jika gagal
```

---

## Broadcast & Store

```lua
setBroadcastWorld(world_name)              -- Set broadcast world untuk SEMUA online players
onPurchaseItem(player, item, true/false)   -- Fire purchase event
onPurchaseItemReq(player, itemID)          -- Fire purchase request
getStoreItems()                            -- Return: store items
```

---

## Rankings

```lua
getTopPlayerByBalance()     -- Return: top player by balance
getTopWorldByVisitors()     -- Return: top world by visitors
```

---

## Lua Modules

```lua
require("module_name")                    -- Load lua module
registerLuaPlaymod(PLAYMODDATA)           -- Register playmod
reloadScripts()                           -- Reload semua Lua scripts
```

Module files harus dimulai dengan `-- MODULE` di baris pertama:
```lua
-- MODULE
local myModule = {}
function myModule.hello()
    print("Hello!")
end
return myModule
```

---

## Custom Commands (Nperma Only)

```lua
registerLuaCommand({
    command = "mycommand",
    roleRequire = 0,
    description = "My custom command"
})
```

---

## Data Persistence

### Key-Based Storage
```lua
saveDataToServer(key, dataTable)       -- Simpan Lua table
loadDataFromServer(key)                -- Load Lua table
saveStringToServer(key, value)         -- Simpan string
loadStringFromServer(key)              -- Load string
```

### Manual Save (jarang dibutuhkan)
```lua
savePlayer(player)    -- Manual save player ke database
saveWorld(world)      -- Manual save world ke database
```
> Server auto-save. Manual save hanya untuk kasus spesial (modify offline player, critical changes).

### Auto-Save Hook
```lua
onAutoSaveRequest(function()
    saveDataToServer("myKey", myData)
end)
```

---

## File System

```lua
file.read(path)          -- Return: string (isi file)
file.write(path, content) -- Tulis ke file
file.exists(path)         -- Return: boolean
file.delete(path)         -- Hapus file ⚠️

dir.create(path)          -- Buat directory
dir.exists(path)          -- Return: boolean
dir.delete(path)          -- Hapus directory ⚠️
```

---

## SQLite Database

```lua
local db = sqlite.open("mydata.db")

db:query("CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT)")

local ok, last_id = db:query("INSERT INTO users(name) VALUES('Nyaa')")
if ok then print("ID: " .. last_id) end

local rows = db:query("SELECT * FROM users")
for i, row in ipairs(rows) do
    print(row.id, row.name)
end

db:close()
```

---

## Server Information

```lua
getServerName()                       -- Return: string
getServerID()                         -- Return: string
getServerDefaultPort()                -- Return: number
getExpireTime()                       -- Return: expire time
getNewsBanner()                       -- Return: news banner
getNewsBannerDimensions()             -- Return: dimensions
getTodaysDate()                       -- Return: date
getTodaysEvents()                     -- Return: events
getCurrentEventDescription()          -- Return: string
getCurrentDailyEventDescription()     -- Return: string
getCurrentRoleDayDescription()        -- Return: string
getMaxLevel()                         -- Return: number (nperma)
```

---

## Server Management

```lua
queueRestart(in_seconds, full_restart, message)
-- full_restart: 0=soft, 1=full
-- message: optional message ke players

deleteAccount(user_id)    -- ⚠️ PERMANENT! Data jadi "ERROR"
deleteWorld(world_id)     -- ⚠️ PERMANENT! Data jadi "ERROR"
```

---

## Roles (Nperma Only)

```lua
getRoles()                   -- Return: table of all roles
getHighestPriorityRole()     -- Return: role object with highest priority
```

**Role properties:** `roleID`, `roleDescription`, `rolePrice`, `rolePriority`, `roleName`, `roleItemID`, `textureName`, `textureXY`, `discordRoleID`, `namePrefix`, `chatPrefix`, `dailyRewardDiamondLocksCount`, `computedFlags`

---

## Blessings (Nperma Only)

```lua
getBlessingName(blessing_id)     -- Return: string
getBlessingInfo(blessing_id)     -- Return: string (description)
getBlessingRarity(blessing_id)   -- Return: rarity value
```

---

## World Menu

```lua
addWorldMenuWorld(worldID, displayName, color, priority)  -- priority 1=before special, 0=after
removeWorldMenuWorld(worldID)
hideWorldMenuDefaultSpecialWorlds(0/1)   -- 1=hide, 0=show
```

---

## UI Registration

```lua
addSidebarButton(buttonJson)                  -- Tambah sidebar button
addSocialPortalButton(buttonDef, callback)    -- Tambah social portal button
```

---

## Discord Bot

### Bot Methods
```lua
DiscordBot.messageCreate(channel_id, message, components, flags, type, embeds)
DiscordBot.directMessageCreate(user_id, message, components, flags, type, embeds)
DiscordBot.messageEdit(message_id, channel_id, content, components, flags, type)
DiscordBot.messageDelete(message_id, channel_id)
DiscordBot.globalCommandCreate(name, description, parameters)
DiscordBot.guildMemberSetNickname(guild_id, user_id, nick)
DiscordBot.guildMemberAddRole(guild_id, user_id, role_id)
DiscordBot.guildMemberRemoveRole(guild_id, user_id, role_id)
```

### Component Row Structure
```lua
components = {
    { -- Row 1
        { type = "button", label = "Btn1", style = "primary", id = "btn1" },
        { type = "button", label = "Btn2", style = "success", emoji = "✅", id = "btn2" }
    },
    { -- Row 2
        { type = "button", label = "Btn3", style = "danger", id = "btn3" }
    }
}
```

### Embeds
```lua
{
    title = "Title",
    description = "Description",
    color = 5763719,  -- Decimal color
    author = { name = "Author", icon = "https://..." },
    fields = {
        { name = "Field 1", value = "Value 1" },
    },
    footer = { text = "Footer", icon = "https://..." },
    thumbnail = { url = "https://..." },
    image = { url = "https://..." },
    timestamp = "2025-01-01T00:00:00Z",
    url = "https://..."
}
```

### ReplyFlags
```lua
ReplyFlags.EPHEMERAL              -- Hanya visible untuk user
ReplyFlags.SUPRESS_EMBEDS         -- Tanpa link preview
ReplyFlags.SUPRESS_NOTIFICATIONS  -- Tanpa push notification
-- Combine: bit.bor(ReplyFlags.EPHEMERAL, ReplyFlags.SUPRESS_NOTIFICATIONS)
```

---

## Utility (Nperma Only)

```lua
parseText(text)   -- Convert "key|value" string ke table
```
