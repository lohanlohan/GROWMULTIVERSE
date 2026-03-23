# Player Object API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/player) + [Nperma Docs](https://docs.nperma.my.id/docs/player.html)

Player object diakses dengan colon operator: `player:methodName()`

---

## Currency (Mata Uang)

```lua
player:getGems()                                          -- Return: number (jumlah gems)
player:addGems(amount, sendPacket?, isDisplay?)            -- Tambah gems
player:removeGems(amount, sendPacket?, isDisplay?)         -- Kurangi gems
player:setGems(number)                                    -- Set gems langsung
player:getCoins()                                         -- Return: number (jumlah coins)
player:addCoins(amount, sendPacket?)                      -- Tambah coins (nperma)
player:removeCoins(amount, sendPacket?)                   -- Kurangi coins
player:setCoins(number)                                   -- Set coins langsung
player:getBankBalance()                                   -- Return: number (bank balance)
player:addBankBalance(amount)                             -- Tambah bank balance
player:setBankBalance(number)                             -- Set bank balance
player:removeBankBalance(amount)                          -- Kurangi bank balance
```

---

## Position (Posisi)

```lua
player:getPosX()          -- Return: number (X position pixel)
player:getPosY()          -- Return: number (Y position pixel)
player:getMiddlePosX()    -- Return: number (middle X position)
```

---

## Inventory

```lua
player:getInventorySize()                    -- Return: number (total slot)
player:isMaxInventorySpace()                 -- Return: boolean (true jika penuh)
player:upgradeInventorySpace(amount)         -- Tambah slot inventory
player:getItemAmount(itemID)                 -- Return: number (jumlah item tertentu)
player:changeItem(itemID, amount, sendPacket) -- Tambah/kurangi item (amount negatif = kurangi)
player:getInventoryItems()                   -- Return: table of inventory_item objects
player:getBackpackUsedSize()                 -- Return: number (slot terpakai)
player:getBackpackItems()                    -- Return: table of backpack items (nperma)
player:getExpansiveInventoryEnabled()        -- Return: boolean
player:setExpansiveInventoryEnabled(enabled) -- Enable/disable expansive inventory (200 slots)
```

---

## Clothing (Pakaian)

```lua
player:getClothingItemID(clothesID)       -- Return: number (item ID di slot)
player:getClothes(slot)                   -- Return: number (item ID di slot)
player:setClothes(slot, itemID)           -- Equip item ke slot
player:getClothesColor(slot)              -- Return: number (warna di slot)
player:setClothesColor(slot, color)       -- Set warna slot (hex color)
```

**Clothing Slots (PlayerClothes):**
| Slot | Nilai |
|------|-------|
| Hat | 0 |
| Shirt | 1 |
| Pants | 2 |
| Feet | 3 |
| Face | 4 |
| Hand | 5 |
| Back | 6 |
| Hair | 7 |

---

## Stats

```lua
player:getGems()
player:getCoins()
player:getLevel()                         -- Return: number (nperma)
player:getUnlockedAchievementsCount()     -- Return: number
player:getAchievementsCount()             -- Return: number (total achievements)
player:isFacingLeft()                     -- Return: boolean
player:isOnline()                         -- Return: boolean
player:getGameVersion()                   -- Return: float (misal 3.02)
player:getPlaytime()                      -- Return: number (total detik, nperma)
```

---

## UI & Dialogs

```lua
player:onConsoleMessage(message)                     -- Kirim pesan console
player:onTalkBubble(netID, message, isApi)           -- Talk bubble (isApi: 0=false, 1=true)
player:onDialogRequest(dialog, delay?, callback?)    -- Buka dialog (callback optional)
player:setNextDialogRGBA(r, g, b, a)                -- Warna background dialog berikutnya
player:setNextDialogBorderRGBA(r, g, b, a)          -- Warna border dialog berikutnya
player:resetDialogColor()                            -- Reset warna dialog ke default
player:onTextOverlay(text)                           -- Text overlay di layar
```

### Menu/Interface Methods
```lua
player:onTradeScanUI()
player:onGrow4GoodUI()
player:onGuildNotebookUI()
player:onGrowmojiUI()
player:onGrowpassUI()
player:onNotebookUI()
player:onBillboardUI()
player:onPersonalizeWrenchUI()
player:onOnlineStatusUI()
player:onFavItemsUI()
player:onCoinsBankUI()
player:onUnlinkDiscordUI()
player:onLinkDiscordUI()
player:onClothesUI(targetPlayer)
player:onAchievementsUI(targetPlayer)
player:onTitlesUI(targetPlayer)
player:onWrenchIconsUI(targetPlayer)
player:onNameIconsUI(targetPlayer)
player:onVouchersUI()
player:onMentorshipUI()
player:onBackpackUI(targetPlayer)
player:onStorePurchaseResult()
player:onRedeemMenu()
player:onGrow4GoodDonate()
```

---

## Audio & Display

```lua
player:playAudio("audio.wav")              -- Play audio (nperma: playAudio(filePath, delay))
player:setNickname(name)                   -- Set display name (support warna, spasi, '@', persist)
player:resetNickname()                     -- Reset ke nama asli
player:setBubbleChatColor(color)           -- Set warna chat bubble (hex)
player:setBubbleStyle(style)               -- Set style chat bubble
```

---

## Role Management

```lua
player:hasRole(roleID)       -- Return: boolean
player:setRole(roleID)       -- Set role (replace existing)
player:addRole(roleID)       -- Tambah role (bisa multiple)
player:removeRole(roleID)    -- Hapus role
player:getRoles()            -- Return: table of roles
player:getRole()             -- Return: role object (nperma — berisi flags, priority, name, dll)
```

---

## Titles

```lua
player:hasTitle(id)          -- Return: boolean
player:addTitle(id)          -- Tambah title
player:removeTitle(id)       -- Hapus title
player:getActiveTitles()     -- Return: table of active titles
player:getTitles()           -- Return: array of title objects
```

**Title object properties:**
- `titleID` — ID unik
- `titleName` — Nama title
- `titleLabel` — Label text
- `titleDisplay` — Display format
- `titleFlagItemID` — Associated flag item ID
- `isActive` — Boolean, sedang digunakan atau tidak

---

## Actions & Packets

```lua
player:sendAction("action|play_sfx\nfile|audio/blabla.mp3\ndelayMS|0")
player:sendVariant({"OnTalkBubble", player:getNetID(), "Hello", 0, 0})
player:sendVariant({"OnConsoleMessage", "Hello"})
player:sendVariant({"OnConsoleMessage", "Hello"}, delay, netID)
player:doAction(actionString)  -- (nperma) kirim packet atas nama player
```

---

## World & Connection

```lua
player:getWorld()                        -- Return: World object atau nil
player:getWorldName()                    -- Return: string (nama world)
player:enterWorld(worldName, doorID?)    -- Masuk world (doorID optional)
player:disconnect()                      -- Disconnect player
player:setBroadcastWorld(worldName)      -- Set broadcast world (/go)
```

---

## Identity

```lua
player:getNetID()                    -- Return: number (net ID)
player:getUserID()                   -- Return: number (user ID)
player:getName()                     -- Return: string (display name)
player:getCleanName()                -- Return: string (nama tanpa format)
player:getRealName()                 -- Return: string (nama asli meski pakai nickname)
player:getRealCleanName()            -- Return: string (nama asli clean)
player:lower()                       -- Return: string (lowercase)
player:getEmail()                    -- Return: string
player:getGender()                   -- Return: number (0=Male, 1=Female)
player:getCountry()                  -- Return: string (kode negara, online only)
player:setCountry(country)           -- Set kode negara ("US", "GB", dll)
player:getPlatform()                 -- Return: number (0=Win, 1=iOS, 2=macOS, 4=Android)
player:getDiscordID()                -- Return: string
player:getAccountCreationDateStr()   -- Return: string
player:getType()                     -- Return: number (non-zero = NPC, 25 = Lua NPC)
player:hasGrowID()                   -- Return: boolean
```

---

## World Lists

```lua
player:getOwnedWorlds()           -- Return: table of world IDs (milik player)
player:getRecentWorlds()          -- Return: table of world IDs (recent)
player:getAccessWorlds()          -- Return: table of world IDs (punya akses)
player:getSmallLockedWorlds()     -- Return: table of world IDs (dikunci dgn SL/BL/HL)
```

---

## Security & History

```lua
player:getIPHistory()     -- Return: table of strings (IP history)
player:getRIDHistory()    -- Return: table of strings (RID history)
player:getIP()            -- Return: string (nperma)
player:getRID()           -- Return: string (nperma)
player:getAltAccounts()   -- Return: array of alt accounts (nperma)
```

---

## AAP (Advanced Account Protection)

```lua
player:setAAPEnabled(1)   -- Enable AAP (1=enable, 0=disable)
player:setAAP(enabled)    -- Enable/disable AAP (boolean)
-- PERLU Discord linked, jika tidak akan gagal
```

---

## Friends

```lua
player:getFriends()              -- Return: table of friend user IDs
player:addFriend(targetPlayer)   -- Tambah teman (bidirectional)
player:removeFriend(targetPlayer) -- Hapus teman (bidirectional)
```

---

## Quests & Goals

```lua
player:getLifeGoals()        -- Return: table of life goal task objects
player:getBiweeklyQuests()   -- Return: table of biweekly quest objects
getJimDailyQuest()           -- (Global) Return: Jim daily quest object
```

**Life Goal / Biweekly properties:**
`taskID`, `taskTargetValue`, `taskCompletedValue`, `taskReward`, `deliverItem`, `rewardAmount`, `claimed`, `givenup`, `completed`, `lastAnnouncePercentage`

**Jim Daily Quest properties:**
`firstItemID`, `firstItemCount`, `secondItemID`, `secondItemCount`, `completedPlayers`

---

## Network

```lua
player:getPing()   -- Return: number (ms)
```

---

## Modifiers & Buffs

```lua
player:getMod(modID)                       -- Return: mod status
player:addMod(modID, durationSeconds)      -- Tambah mod/buff
player:removeMod(modID)                    -- Hapus mod (nperma)
player:setFlag(flag, enabled)              -- Set player flag
player:setGodMode(enabled)                 -- God mode (invincible)
player:setGuildName(name)                  -- Set guild name display
player:setBadge(badgeID)                   -- Set badge
player:getPlaymodStatus()                  -- Return: playmod status
player:setPlaymodStatus(status)            -- Set playmod status
player:getOwnerRole()                      -- Return: owner role ID
player:setOwnerRole(roleID)               -- Set owner role ID
player:getHomeWorldID()                    -- Return: home world ID
player:getOnlineStatus()                   -- Return: online status
player:getGuildID()                        -- Return: guild ID
player:getTransformProfileButtons()        -- Return: transform profile buttons
player:setCustomAutofarmDelay(ms)          -- Set autofarm delay (0=reset default)
```

### Auto-Farm
```lua
player:setSlots(slotAmount)                       -- Set autofarm slots
player:getAutofarm():getTargetBlockID()            -- Return: item ID target autofarm
player:getAutofarm():setTargetBlockID(id)          -- Set target block
player:setCustomAutofarmDelay(ms)                  -- Custom delay (WARNING: <100ms = high CPU!)
```

---

## Subscriptions

```lua
player:getSubscription(type)                              -- Return: subscription object atau nil
player:addSubscription(type, expire_timestamp_seconds)    -- Tambah subscription (0=permanent)
player:removeSubscription(type)                           -- Hapus subscription
```

**Subscription object methods:**
```lua
sub:getType()              -- Return: type ID
sub:getExpireTime()        -- Return: timestamp (seconds)
sub:getActivationTime()    -- Return: timestamp (seconds)
sub:isPermanent()          -- Return: boolean
sub:getNextRewardTime()    -- Return: timestamp (seconds)
sub:setExpireTime(timestamp)
sub:setNextRewardTime(timestamp)
```

**Subscription Types:**
| Constant | Value |
|----------|-------|
| TYPE_SUPPORTER | 0 |
| TYPE_SUPER_SUPPORTER | 1 |
| TYPE_YEAR_SUBSCRIPTION | 2 |
| TYPE_MONTH_SUBSCRIPTION | 3 |
| TYPE_GROWPASS | 4 |
| TYPE_TIKTOK | 5 |
| TYPE_BOOST | 6 |
| TYPE_STAFF | 7 |
| TYPE_FREE_DAY_SUBSCRIPTION | 8 |
| TYPE_FREE_3_DAY_SUBSCRIPTION | 9 |
| TYPE_FREE_14_DAY_SUBSCRIPTION | 10 |

> **PENTING:** Setelah modify subscription offline player, panggil `savePlayer(player)`

---

## Item Effects

```lua
player:getItemEffects()  -- Return: table combined buffs dari semua clothing
```
Properties: `extra_gems`, `extra_xp`, `one_hit`, `break_range`, `build_range`

---

## Profile & Misc

```lua
player:getClassicProfileContent(category, flags)
player:getDungeonScrolls()                -- Return: number (max 255)
player:setDungeonScrolls(number)          -- Set dungeon scrolls
player:addGrowpassPoints(points)          -- Tambah growpass points
player:getDiscordInvites()                -- Return: number (nperma)
player:getCountryFlagBackground()         -- Return: item ID (nperma)
player:getCountryFlagForeground()         -- Return: item ID (nperma)
player:setCountryFlagBackground(item_id)  -- Set flag bg (nperma)
player:setCountryFlagForeground(item_id)  -- Set flag fg (nperma)
```

---

## Block Hit Count

```lua
player:adjustBlockHitCount(amount)     -- Adjust (-10 to +10). -10 = semua 1-hit break
player:getAdjustedBlockHitCount()      -- Return: current adjustment
player:setTotalPunchedBlocks(count)    -- Set total punched blocks count
```

---

## Account Settings

```lua
player:setPassword(newPassword)
player:setEmail(email)
player:setGender(gender)           -- 0=Male, 1=Female
player:setAccountLevel(level)
player:setLevel(level)             -- (nperma)
player:addLevel(amount)            -- (nperma)
player:removeLevel(amount)         -- (nperma)
player:setXP(amount)               -- (nperma)
player:removeXP(amount)            -- (nperma)
player:checkPassword(passwordString) -- Return: boolean (nperma)
```

---

## Account Notes & Moderation

```lua
player:addNote("Some note text")     -- Tambah note akun
player:addMod(GAME_BAN, 60)         -- Ban 60 detik (0=permanent)
player:ban(length_seconds, reason, banned_by_player, ban_device, ban_ip) -- (nperma)
```

---

## Blessings (Nperma Only)

```lua
player:addBlessing(blessing_id)
player:hasBlessing(blessing_id)         -- Return: boolean (regardless of power orb)
player:hasActiveBlessing(blessing_id)   -- Return: boolean (false jika power orb disabled)
player:removeBlessing(blessing_id)
```

---

## Stats Management

```lua
player:setStats(type, amount)      -- Set stat tertentu
player:setStats(jsonString)        -- Set multiple stats via JSON
```

---

## Mail (Nperma Only)

```lua
player:addMail(mailDataTable)   -- Tambah mail ke mailbox
player:clearMailbox()           -- Hapus semua mail
```

---

## Role Quest (Nperma Only)

```lua
player:getRoleQuestLevel(type)          -- Get role quest level
player:setRoleQuestLevel(type, level)   -- Set role quest level
```
