-- MODULE
-- rent_entrance.lua — Rent Entrance (item 25004): sewa akses tile per player

local M      = {}
local Utils  = _G.Utils
local Config = _G.Config
local DB     = _G.DB

-- =======================================================
-- CONFIG
-- =======================================================

local RENT_ENTRANCE_ID        = 25004  -- collision none (passable)
local RENT_ENTRANCE_CLOSED_ID = 25002  -- collision normal (blocked)
local WORLD_LOCK_ID           = Config.ITEMS.WORLD_LOCK    -- 242
local DIAMOND_LOCK_ID         = Config.ITEMS.DIAMOND_LOCK  -- 1796
local BGL_ID                  = 7188
local GGL_ID                  = 0   -- pending

local WITHDRAW_TAX_PERCENT = 10

local RENT_OPTIONS = {
    { key = "3h",        label = "3 Hours",  duration = 3  * 3600 },
    { key = "6h",        label = "6 Hours",  duration = 6  * 3600 },
    { key = "12h",       label = "12 Hours", duration = 12 * 3600 },
    { key = "24h",       label = "24 Hours", duration = 24 * 3600 },
    { key = "permanent", label = "Forever",  duration = 0         },
}

-- =======================================================
-- STORAGE (JSON + in-memory cache)
-- File: currentState/luaData/rent_entrance.json
-- =======================================================

local DB_CACHE = nil

local function readDB()
    if DB_CACHE then return DB_CACHE end
    DB_CACHE = DB.loadFeature("rent_entrance")
    return DB_CACHE
end

local function writeDB(data)
    DB_CACHE = data
    DB.saveFeature("rent_entrance", data)
end

local function eKey(worldName, x, y)
    return tostring(worldName) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function getEntrance(worldName, x, y)
    local db    = readDB()
    local entry = db[eKey(worldName, x, y)]
    if type(entry) ~= "table" then return nil end
    if type(entry.prices)  ~= "table" then entry.prices  = {} end
    if type(entry.renters) ~= "table" then entry.renters = {} end
    return entry
end

local function ensureEntrance(worldName, x, y)
    local ex = getEntrance(worldName, x, y)
    if ex then return ex end
    local prices = {}
    for _, opt in ipairs(RENT_OPTIONS) do prices[opt.key] = 0 end
    local entry = { prices = prices, max_renters = 5, earned_wl = 0, renters = {} }
    local db = readDB()
    db[eKey(worldName, x, y)] = entry
    writeDB(db)
    return entry
end

local function saveEntrance(worldName, x, y, data)
    local db = readDB()
    db[eKey(worldName, x, y)] = {
        prices      = type(data.prices)  == "table" and data.prices  or {},
        max_renters = math.max(1, math.floor(tonumber(data.max_renters) or 5)),
        earned_wl   = math.max(0, math.floor(tonumber(data.earned_wl)  or 0)),
        renters     = type(data.renters) == "table" and data.renters or {},
    }
    writeDB(db)
end

local function deleteEntrance(worldName, x, y)
    local db = readDB()
    db[eKey(worldName, x, y)] = nil
    writeDB(db)
end

-- =======================================================
-- HELPERS
-- =======================================================

local function now()
    return math.floor(tonumber(os.time()) or 0)
end

local function isPrivileged(world, player)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return false end
    return world:getOwner(player) == true or Utils.isPrivileged(player)
end

local function getPlayerItemCount(player, itemID)
    if type(player) ~= "userdata" or itemID <= 0 then return 0 end
    return tonumber(player:getItemAmount(itemID)) or 0
end

local function getTotalWLEquiv(player)
    local wl  = getPlayerItemCount(player, WORLD_LOCK_ID)
    local dl  = getPlayerItemCount(player, DIAMOND_LOCK_ID)
    local bgl = BGL_ID > 0 and getPlayerItemCount(player, BGL_ID) or 0
    local ggl = GGL_ID > 0 and getPlayerItemCount(player, GGL_ID) or 0
    return wl + (dl * 100) + (bgl * 10000) + (ggl * 1000000)
end

local function deductWL(player, amount)
    if getTotalWLEquiv(player) < amount then return false end
    local rem = amount
    if GGL_ID > 0 and rem >= 1000000 then
        local use = math.min(getPlayerItemCount(player, GGL_ID), math.floor(rem / 1000000))
        if use > 0 then player:changeItem(GGL_ID, -use, 0); rem = rem - use * 1000000 end
    end
    if BGL_ID > 0 and rem >= 10000 then
        local use = math.min(getPlayerItemCount(player, BGL_ID), math.floor(rem / 10000))
        if use > 0 then player:changeItem(BGL_ID, -use, 0); rem = rem - use * 10000 end
    end
    if rem >= 100 then
        local use = math.min(getPlayerItemCount(player, DIAMOND_LOCK_ID), math.floor(rem / 100))
        if use > 0 then player:changeItem(DIAMOND_LOCK_ID, -use, 0); rem = rem - use * 100 end
    end
    if rem > 0 then player:changeItem(WORLD_LOCK_ID, -rem, 0) end
    return true
end

local function convertWLToItems(wlAmount)
    local items = {}
    local rem   = wlAmount
    if GGL_ID > 0 and rem >= 1000000 then
        local n = math.floor(rem / 1000000); rem = rem - n * 1000000
        items[#items + 1] = { id = GGL_ID, amount = n, label = "GGL" }
    end
    if BGL_ID > 0 and rem >= 10000 then
        local n = math.floor(rem / 10000); rem = rem - n * 10000
        items[#items + 1] = { id = BGL_ID, amount = n, label = "BGL" }
    end
    if rem >= 100 then
        local n = math.floor(rem / 100); rem = rem - n * 100
        items[#items + 1] = { id = DIAMOND_LOCK_ID, amount = n, label = "DL" }
    end
    if rem > 0 then
        items[#items + 1] = { id = WORLD_LOCK_ID, amount = rem, label = "WL" }
    end
    return items
end

local function formatTime(seconds)
    if seconds <= 0 then return "Expired" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600)  / 60)
    if d > 0 then return d .. "d " .. h .. "h " .. m .. "m" end
    if h > 0 then return h .. "h " .. m .. "m" end
    return m .. "m " .. (seconds % 60) .. "s"
end

local function isRenterValid(renter)
    if not renter then return false end
    local exp = tonumber(renter.expires_at) or 0
    if exp == 0 then return true end
    return exp > now()
end

local function getRemainingText(renter)
    if not renter then return "`4None" end
    local exp = tonumber(renter.expires_at) or 0
    if exp == 0 then return "`5Permanent" end
    local rem = exp - now()
    if rem <= 0 then return "`4Expired" end
    return "`e" .. formatTime(rem)
end

local function countActiveRenters(ent)
    local n = 0
    for _, r in pairs(ent.renters or {}) do
        if isRenterValid(r) then n = n + 1 end
    end
    return n
end

local function getOptByKey(key)
    for _, o in ipairs(RENT_OPTIONS) do
        if o.key == key then return o end
    end
    return nil
end

local function safeBubble(player, text)
    if player and player.onTalkBubble and player.getNetID then
        player:onTalkBubble(player:getNetID(), text, 0)
    end
end

local PLACE_BUBBLE_ACTIVE = {}

local function safeBubbleWhileVisible(player, text, reason, visibleSec)
    local uid = tonumber(player:getUserID()) or 0
    if uid <= 0 then safeBubble(player, text); return true end

    local key      = tostring(reason or text)
    local byPlayer = PLACE_BUBBLE_ACTIVE[uid]
    if type(byPlayer) ~= "table" then
        byPlayer = {}
        PLACE_BUBBLE_ACTIVE[uid] = byPlayer
    end

    if byPlayer[key] == true then return false end
    byPlayer[key] = true
    safeBubble(player, text)

    local hold = tonumber(visibleSec) or 2.8
    timer.setTimeout(math.max(0.5, hold), function()
        local entry = PLACE_BUBBLE_ACTIVE[uid]
        if type(entry) ~= "table" then return end
        entry[key] = nil
        if next(entry) == nil then PLACE_BUBBLE_ACTIVE[uid] = nil end
    end)
    return true
end

local function getWorldName(world, player)
    if type(world) == "userdata" and world.getName then
        local n = tostring(world:getName() or "")
        if n ~= "" then return n end
    end
    if type(player) == "userdata" and player.getWorldName then
        return tostring(player:getWorldName() or "")
    end
    return ""
end

local function getTileAt(world, x, y)
    return world:getTile(math.floor(x / 32), math.floor(y / 32))
end

local function spawnParticle(player, x, y)
    if player and player.onParticleEffect then
        player:onParticleEffect(46, x + 15, y + 15, 0, 0, 0)
    end
end

local function grantVisualAccess(world, player, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local tile = getTileAt(world, x, y)
    if tile and tile:getTileID() == RENT_ENTRANCE_ID then
        world:setTileForeground(tile, RENT_ENTRANCE_ID, 1, player)
    end
end

local function revokeVisualAccess(world, player, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local tile = getTileAt(world, x, y)
    if tile and tile:getTileID() == RENT_ENTRANCE_ID then
        world:setTileForeground(tile, RENT_ENTRANCE_CLOSED_ID, 1, player)
    end
end

local function resetVisualForAll(world, x, y)
    if type(world) ~= "userdata" then return end
    local tile = getTileAt(world, x, y)
    if not tile or tile:getTileID() ~= RENT_ENTRANCE_ID then return end
    local players = world:getPlayers()
    if type(players) ~= "table" then return end
    for _, p in pairs(players) do
        world:setTileForeground(tile, RENT_ENTRANCE_CLOSED_ID, 1, p)
        spawnParticle(p, x, y)
    end
end

local function refreshAccessForPlayer(world, player, worldName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local db  = readDB()
    local uid = tonumber(player:getUserID()) or 0

    for key, ent in pairs(db) do
        local wn, xs, ys = key:match("^(.+):(%d+):(%d+)$")
        if wn == worldName then
            local x, y = tonumber(xs), tonumber(ys)
            if isPrivileged(world, player) then
                grantVisualAccess(world, player, x, y)
            else
                local renter = (ent.renters or {})["u" .. uid]
                if renter and isRenterValid(renter) then
                    grantVisualAccess(world, player, x, y)
                else
                    revokeVisualAccess(world, player, x, y)
                end
            end
        end
    end
end

-- =======================================================
-- FORWARD DECLARATIONS
-- =======================================================

local showOwnerPanel
local showRenterListPanel
local showOwnerPickPlayerPanel
local showOwnerPickOptionPanel
local showPlayerBuyPanel
local showPlayerConfirmPanel
local showPlayerStatusPanel

-- =======================================================
-- OWNER PANEL
-- =======================================================

showOwnerPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg = "re_owner_" .. x .. "_" .. y

    local ent         = ensureEntrance(worldName, x, y)
    local prices      = ent.prices or {}
    local maxRenters  = tonumber(ent.max_renters) or 5
    local earnedWL    = tonumber(ent.earned_wl)   or 0
    local activeCount = countActiveRenters(ent)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wRent Entrance|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_smalltext|`wRenters: `o" .. activeCount .. "/" .. maxRenters .. "  `wStored WL: `o" .. earnedWL .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`wSet Rent Prices (`70 WL = disabled`w):|left|\n"
    for _, opt in ipairs(RENT_OPTIONS) do
        local cur = tonumber(prices[opt.key]) or 0
        d = d .. "add_text_input|price_" .. opt.key .. "|" .. opt.label .. " (WL)|" .. cur .. "|6|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_text_input|max_renters|Max Renters (min 1)|" .. maxRenters .. "|3|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "set_custom_spacing|x:5;y:5|\n"
    d = d .. "add_button_with_icon|btn_owner_renterlist|`9View Renters|staticBlueFrame|" .. RENT_ENTRANCE_ID .. "|0|left|\n"
    d = d .. "add_button_with_icon|btn_owner_addrenter|`2Add Renter|staticBlueFrame|" .. RENT_ENTRANCE_ID .. "|0|left|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "set_custom_spacing|x:0;y:0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_owner_withdraw|`6Withdraw WL|noflags|0|0|\n"
    d = d .. "add_smalltext|`7(total WL withdrawn will be taxed " .. WITHDRAW_TAX_PERCENT .. "%)|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_owner_close|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        local e = ensureEntrance(worldName, x, y)
        for _, opt in ipairs(RENT_OPTIONS) do
            e.prices[opt.key] = math.max(0, math.floor(tonumber(data["price_" .. opt.key]) or 0))
        end
        e.max_renters = math.max(1, math.floor(tonumber(data["max_renters"]) or 5))
        saveEntrance(worldName, x, y, e)

        if btn == "btn_owner_renterlist" then
            showRenterListPanel(cbWorld, cbPlayer, worldName, x, y)

        elseif btn == "btn_owner_addrenter" then
            showOwnerPickPlayerPanel(cbWorld, cbPlayer, worldName, x, y)

        elseif btn == "btn_owner_withdraw" then
            local e2 = getEntrance(worldName, x, y)
            local wl = tonumber(e2 and e2.earned_wl) or 0
            if wl <= 0 then
                safeBubble(cbPlayer, "`4No World Locks to withdraw.")
                showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
                return true
            end
            local afterTax = math.floor(wl * (100 - WITHDRAW_TAX_PERCENT) / 100)
            local items    = convertWLToItems(afterTax)
            local summary  = {}
            for _, item in ipairs(items) do
                cbPlayer:changeItem(item.id, item.amount, 0)
                summary[#summary + 1] = item.amount .. " " .. item.label
            end
            e2.earned_wl = 0
            saveEntrance(worldName, x, y, e2)
            safeBubble(cbPlayer, "`2Withdrew: " .. table.concat(summary, " + ") .. " (after " .. WITHDRAW_TAX_PERCENT .. "% tax)")
            showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)

        elseif btn == "btn_owner_remove" then
            local e2      = getEntrance(worldName, x, y)
            local active2  = e2 and countActiveRenters(e2) or 0
            local earned2  = e2 and (tonumber(e2.earned_wl) or 0) or 0
            if active2 > 0 then
                safeBubble(cbPlayer, "`4Cannot remove: " .. active2 .. " active renter(s) remaining!")
                showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
                return true
            end
            if earned2 > 0 then
                safeBubble(cbPlayer, "`4Cannot remove: withdraw the " .. earned2 .. " stored WL first!")
                showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
                return true
            end
            local tileToBreak = cbWorld:getTile(x, y)
            if tileToBreak and tileToBreak:getTileID() == RENT_ENTRANCE_ID then
                deleteEntrance(worldName, x, y)
                cbWorld:punchTile(tileToBreak)
                safeBubble(cbPlayer, "`2Rent Entrance removed.")
            else
                safeBubble(cbPlayer, "`4Could not find the tile.")
            end
        end

        return true
    end)
end

-- =======================================================
-- RENTER LIST PANEL
-- =======================================================

showRenterListPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg = "re_rlist_" .. x .. "_" .. y

    local ent     = ensureEntrance(worldName, x, y)
    local renters = ent.renters or {}

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wActive Renters|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_smalltext|`wEntrance `o(" .. x .. ", " .. y .. ") `win `o" .. worldName .. "|\n"
    d = d .. "add_spacer|small|\n"

    local hasAny = false
    for key, renter in pairs(renters) do
        if isRenterValid(renter) then
            hasAny      = true
            local uidStr  = key:gsub("^u", "")
            local name    = tostring(renter.name or uidStr)
            local timeStr = getRemainingText(renter)
            local optKey  = tostring(renter.option or "?")
            d = d .. string.format(
                "add_button_with_icon|btn_rmv_%s|`w%s `7[%s] %s `4[Remove]|staticBlueFrame|%d|0|left|\n",
                uidStr, name, optKey, timeStr, RENT_ENTRANCE_ID
            )
        end
    end

    if not hasAny then d = d .. "add_smalltext|`7No active renters.|\n" end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_rlist_back|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        if btn and btn:match("^btn_rmv_") then
            local uid = tonumber((btn:gsub("^btn_rmv_", ""))) or 0
            if uid > 0 then
                local e   = getEntrance(worldName, x, y)
                local key = "u" .. uid
                if e and e.renters[key] then
                    local rName = tostring(e.renters[key].name or uid)
                    e.renters[key] = nil
                    saveEntrance(worldName, x, y, e)
                    local wps = cbWorld:getPlayers()
                    if type(wps) == "table" then
                        for _, p in pairs(wps) do
                            if (tonumber(p:getUserID()) or 0) == uid then
                                revokeVisualAccess(cbWorld, p, x, y)
                                spawnParticle(p, x, y)
                                safeBubble(p, "`4Your rental access has been removed by the owner.")
                                break
                            end
                        end
                    end
                    safeBubble(cbPlayer, "`4Removed renter: " .. rName)
                end
            end
            showRenterListPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn == "btn_rlist_back" then showOwnerPanel(cbWorld, cbPlayer, worldName, x, y) end
        return true
    end)
end

-- =======================================================
-- OWNER: PICK PLAYER → PICK OPTION
-- =======================================================

showOwnerPickPlayerPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg = "re_pickp_" .. x .. "_" .. y

    local ent = ensureEntrance(worldName, x, y)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wAdd Renter — Pick Player|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_smalltext|`wSlots: `o" .. countActiveRenters(ent) .. "/" .. (ent.max_renters or 5) .. "|\n"
    d = d .. "add_spacer|small|\n"

    local wPlayers = world:getPlayers()
    local anyAdded = false
    if type(wPlayers) == "table" then
        for _, p in pairs(wPlayers) do
            if not isPrivileged(world, p) then
                anyAdded  = true
                local pid = tonumber(p:getUserID()) or 0
                local tag = ent.renters["u" .. pid] and " `7(renter)" or ""
                d = d .. "add_button|btn_pickp_" .. pid .. "|`w" .. p:getName() .. tag .. "|noflags|0|0|\n"
            end
        end
    end
    if not anyAdded then d = d .. "add_smalltext|`7No eligible players in world.|\n" end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_pickp_back|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        if btn and btn:match("^btn_pickp_%d+") then
            local targetUID  = tonumber((btn:gsub("^btn_pickp_", ""))) or 0
            if targetUID > 0 then
                local targetName = tostring(targetUID)
                local wps = cbWorld:getPlayers()
                if type(wps) == "table" then
                    for _, p in pairs(wps) do
                        if (tonumber(p:getUserID()) or 0) == targetUID then
                            targetName = p:getName(); break
                        end
                    end
                end
                showOwnerPickOptionPanel(cbWorld, cbPlayer, worldName, x, y, targetUID, targetName)
            end
            return true
        end

        if btn == "btn_pickp_back" then showOwnerPanel(cbWorld, cbPlayer, worldName, x, y) end
        return true
    end)
end

showOwnerPickOptionPanel = function(world, player, worldName, x, y, targetUID, targetName)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg = "re_picko_" .. x .. "_" .. y

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wAdd Renter — Pick Duration|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_smalltext|`wAdding: `w" .. targetName .. "|\n"
    d = d .. "add_smalltext|`eOwner add is FREE — no WL deducted.|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "set_custom_spacing|x:5;y:5|\n"
    for _, opt in ipairs(RENT_OPTIONS) do
        d = d .. "add_button_with_icon|btn_picko_" .. opt.key .. "|`w" .. opt.label .. "|staticBlueFrame|" .. RENT_ENTRANCE_ID .. "|0|left|\n"
    end
    d = d .. "add_custom_break|\n"
    d = d .. "set_custom_spacing|x:0;y:0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_picko_back|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        if btn == "btn_picko_back" then
            showOwnerPickPlayerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        if btn and btn:match("^btn_picko_") then
            local optKey = btn:gsub("^btn_picko_", "")
            local opt    = getOptByKey(optKey)
            if opt then
                local e         = ensureEntrance(worldName, x, y)
                local renterKey = "u" .. targetUID
                local isExisting = e.renters[renterKey] ~= nil
                local active    = countActiveRenters(e)
                local maxR      = tonumber(e.max_renters) or 5

                if not isExisting and active >= maxR then
                    safeBubble(cbPlayer, "`4Entrance is full! Max: " .. maxR)
                    showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
                    return true
                end

                local expiresAt
                if opt.duration == 0 then
                    expiresAt = 0
                elseif isExisting then
                    local existExp = tonumber(e.renters[renterKey].expires_at) or 0
                    local base     = (existExp > 0) and math.max(now(), existExp) or now()
                    expiresAt      = base + opt.duration
                else
                    expiresAt = now() + opt.duration
                end

                e.renters[renterKey] = { name = targetName, option = opt.key, expires_at = expiresAt }
                saveEntrance(worldName, x, y, e)

                local wps = cbWorld:getPlayers()
                if type(wps) == "table" then
                    for _, p in pairs(wps) do
                        if (tonumber(p:getUserID()) or 0) == targetUID then
                            grantVisualAccess(cbWorld, p, x, y)
                            spawnParticle(p, x, y)
                            local msg = opt.duration == 0
                                and "`2You've been granted permanent access to an entrance (free)!"
                                or  "`2You've been granted " .. opt.label .. " access to an entrance (free)!"
                            safeBubble(p, msg)
                            break
                        end
                    end
                end
                safeBubble(cbPlayer, "`2Added " .. targetName .. " as renter (" .. opt.label .. ") — free.")
            end
            showOwnerPanel(cbWorld, cbPlayer, worldName, x, y)
            return true
        end

        return true
    end)
end

-- =======================================================
-- PLAYER BUY PANEL
-- =======================================================

showPlayerBuyPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg = "re_buy_" .. x .. "_" .. y

    local ent = getEntrance(worldName, x, y)
    if not ent then
        safeBubble(player, "`4This entrance is not configured yet.")
        return
    end
    local prices      = ent.prices or {}
    local maxRenters  = tonumber(ent.max_renters) or 5
    local activeCount = countActiveRenters(ent)
    local balance     = getTotalWLEquiv(player)

    local d = "set_default_color|`o\n"
    d = d .. "text_scaling_string|aaaaaaaaaa|\n"
    d = d .. "add_label_with_icon|big|`wRent Entrance|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_smalltext|`wAvailable Slots: `o" .. (maxRenters - activeCount) .. "/" .. maxRenters .. "|\n"
    d = d .. "add_smalltext|`wYour Balance: `o" .. balance .. " WL|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`wChoose Rent Duration:|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "set_custom_spacing|x:5;y:5|\n"
    for _, opt in ipairs(RENT_OPTIONS) do
        local price = tonumber(prices[opt.key]) or 0
        local color = price > 0 and "`2" or "`4"
        d = d .. "add_button_with_icon|btn_buy_" .. opt.key .. "|" .. color .. opt.key .. "|staticBlueFrame|" .. RENT_ENTRANCE_ID .. "|0|left|\n"
    end
    d = d .. "add_custom_break|\n"
    d = d .. "set_custom_spacing|x:0;y:0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_buy_close|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        if btn == "btn_buy_close" then return true end

        if btn and btn:match("^btn_buy_") then
            local optKey = btn:gsub("^btn_buy_", "")
            local opt    = getOptByKey(optKey)
            if opt then
                local e     = getEntrance(worldName, x, y)
                local price = e and tonumber((e.prices or {})[opt.key]) or 0
                if price == 0 then
                    safeBubble(cbPlayer, "`4This option is not available.")
                    return true
                end
                showPlayerConfirmPanel(cbWorld, cbPlayer, worldName, x, y, opt, price)
            end
            return true
        end

        return true
    end)
end

-- =======================================================
-- PLAYER CONFIRM PANEL
-- =======================================================

showPlayerConfirmPanel = function(world, player, worldName, x, y, opt, price)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg       = "re_confirm_" .. x .. "_" .. y
    local balance   = getTotalWLEquiv(player)
    local canAfford = balance >= price

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wConfirm Purchase|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`wDuration: `o" .. opt.label .. "|\n"
    d = d .. "add_smalltext|`wPrice: `o" .. price .. " WL|\n"
    d = d .. "add_smalltext|`wYour Balance: `o" .. balance .. " WL|\n"
    d = d .. "add_spacer|small|\n"

    if not canAfford then
        d = d .. "add_smalltext|`4Not enough World Locks!|\n"
        d = d .. "add_button|btn_cfm_back|Back|noflags|0|0|\n"
    else
        d = d .. "add_button|btn_cfm_yes|`2Yes, Rent!|noflags|0|0|\n"
        d = d .. "add_button|btn_cfm_back|Cancel|noflags|0|0|\n"
    end

    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]

        if btn == "btn_cfm_yes" then
            local uid        = tonumber(cbPlayer:getUserID()) or 0
            local e          = ensureEntrance(worldName, x, y)
            local curPrice   = tonumber((e.prices or {})[opt.key]) or 0
            local maxR       = tonumber(e.max_renters) or 5
            local active     = countActiveRenters(e)
            local renterKey  = "u" .. uid
            local isExisting = e.renters[renterKey] ~= nil

            if curPrice == 0 then safeBubble(cbPlayer, "`4This option is no longer available."); return true end
            if not isExisting and active >= maxR then safeBubble(cbPlayer, "`4This entrance is full!"); return true end
            if getTotalWLEquiv(cbPlayer) < curPrice then safeBubble(cbPlayer, "`4Not enough World Locks!"); return true end
            if not deductWL(cbPlayer, curPrice) then safeBubble(cbPlayer, "`4Payment failed."); return true end

            e.earned_wl = (tonumber(e.earned_wl) or 0) + curPrice

            local expiresAt
            if opt.duration == 0 then
                expiresAt = 0
            elseif isExisting then
                local existExp = tonumber(e.renters[renterKey].expires_at) or 0
                local base     = (existExp > 0) and math.max(now(), existExp) or now()
                expiresAt      = base + opt.duration
            else
                expiresAt = now() + opt.duration
            end

            e.renters[renterKey] = {
                name       = cbPlayer:getName(),
                option     = opt.key,
                expires_at = expiresAt,
            }
            saveEntrance(worldName, x, y, e)

            grantVisualAccess(cbWorld, cbPlayer, x, y)
            spawnParticle(cbPlayer, x, y)

            local msg = expiresAt == 0
                and "`2Rental confirmed! You now have permanent access."
                or  "`2Rental confirmed! Access for: " .. formatTime(expiresAt - now())
            safeBubble(cbPlayer, msg)
            return true
        end

        if btn == "btn_cfm_back" then showPlayerBuyPanel(cbWorld, cbPlayer, worldName, x, y) end
        return true
    end)
end

-- =======================================================
-- PLAYER STATUS PANEL
-- =======================================================

showPlayerStatusPanel = function(world, player, worldName, x, y)
    if type(world) ~= "userdata" or type(player) ~= "userdata" then return end
    local dlg       = "re_status_" .. x .. "_" .. y
    local uid       = tonumber(player:getUserID()) or 0
    local renterKey = "u" .. uid
    local ent       = ensureEntrance(worldName, x, y)
    local renter    = ent.renters[renterKey]

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wRent Entrance|left|" .. RENT_ENTRANCE_ID .. "|\n"
    d = d .. "add_spacer|small|\n"

    if renter and isRenterValid(renter) then
        d = d .. "add_smalltext|`2You have active access to this entrance.|\n"
        d = d .. "add_smalltext|`wTime Remaining: " .. getRemainingText(renter) .. "|\n"
        d = d .. "add_smalltext|`wOption: `o" .. tostring(renter.option or "?") .. "|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_button|btn_status_extend|`6Extend / Add Time|noflags|0|0|\n"
    else
        revokeVisualAccess(world, player, x, y)
        d = d .. "add_smalltext|`4Your access to this entrance has expired.|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_button|btn_status_buy|`2Rent Again|noflags|0|0|\n"
    end

    d = d .. "add_button|btn_status_close|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|" .. dlg .. "|||\n"

    player:onDialogRequest(d, 0, function(cbWorld, cbPlayer, data)
        if type(data) ~= "table" or data["dialog_name"] ~= dlg then return end
        local btn = data["buttonClicked"]
        if btn == "btn_status_extend" or btn == "btn_status_buy" then
            showPlayerBuyPanel(cbWorld, cbPlayer, worldName, x, y)
        end
        return true
    end)
end

-- =======================================================
-- CALLBACKS
-- =======================================================

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() ~= RENT_ENTRANCE_ID then return false end

    local worldName = getWorldName(world, player)
    local x         = tile:getPosX()
    local y         = tile:getPosY()

    if isPrivileged(world, player) then
        ensureEntrance(worldName, x, y)
        showOwnerPanel(world, player, worldName, x, y)
        return true
    end

    local ent = getEntrance(worldName, x, y)
    if not ent then
        safeBubble(player, "`4This entrance is not configured yet.")
        return true
    end

    local uid    = tonumber(player:getUserID()) or 0
    local renter = ent.renters["u" .. uid]

    if renter and isRenterValid(renter) then
        showPlayerStatusPanel(world, player, worldName, x, y)
    else
        showPlayerBuyPanel(world, player, worldName, x, y)
    end
    return true
end)

onTilePunchCallback(function(world, player, tile)
    if tile:getTileID() ~= RENT_ENTRANCE_ID then return false end

    local worldName = getWorldName(world, player)
    local x         = tile:getPosX()
    local y         = tile:getPosY()

    if isPrivileged(world, player) then
        local ent      = getEntrance(worldName, x, y)
        local active   = ent and countActiveRenters(ent) or 0
        local earnedWL = ent and (tonumber(ent.earned_wl) or 0) or 0

        if active > 0 then
            player:adjustBlockHitCount(10)
            safeBubbleWhileVisible(player, "`4Cannot break! Remove all " .. active .. " renter(s) first.", "punch_active_renters", 2.8)
            return true
        end
        if earnedWL > 0 then
            player:adjustBlockHitCount(10)
            safeBubbleWhileVisible(player, "`4Cannot break! Withdraw the " .. earnedWL .. " stored WL first.", "punch_earned_wl", 2.8)
            return true
        end
        return false
    end

    player:adjustBlockHitCount(10)
    safeBubbleWhileVisible(player, "`4You don't have permission to break this entrance!", "punch_no_perm", 2.8)
    return true
end)

onTilePlaceCallback(function(world, player, tile, placingID)
    if tonumber(placingID) ~= RENT_ENTRANCE_ID then return false end

    if not isPrivileged(world, player) then
        safeBubbleWhileVisible(player, "`4Only the world owner can place a Rent Entrance!", "place_not_owner", 2.8)
        return true
    end
    if not world:getWorldLock() then
        safeBubbleWhileVisible(player, "`0This item can only be used in World-Locked worlds!", "place_need_worldlock", 2.8)
        return true
    end

    local px = tile:getPosX()
    local py = tile:getPosY()
    timer.setTimeout(0.2, function()
        local players = world:getPlayers()
        if type(players) ~= "table" then return end
        for _, p in pairs(players) do
            if not isPrivileged(world, p) then
                revokeVisualAccess(world, p, px, py)
            end
        end
    end)

    return false
end)

onTileBreakCallback(function(world, player, tile)
    if tile:getTileID() ~= RENT_ENTRANCE_ID then return end
    local x, y = tile:getPosX(), tile:getPosY()
    local wps   = world:getPlayers()
    if type(wps) == "table" then
        for _, p in pairs(wps) do revokeVisualAccess(world, p, x, y) end
    end
    deleteEntrance(getWorldName(world, player), x, y)
end)

onPlayerEnterWorldCallback(function(world, player)
    local worldName = getWorldName(world, player)
    if worldName == "" then return end
    refreshAccessForPlayer(world, player, worldName)
end)

onWorldTick(function(world)
    local worldName = world:getName()
    local db        = readDB()
    local players   = world:getPlayers()
    if type(players) ~= "table" then return end

    for key, ent in pairs(db) do
        local wn, xs, ys = key:match("^(.+):(%d+):(%d+)$")
        if wn == worldName and type(ent.renters) == "table" then
            local tx, ty  = tonumber(xs), tonumber(ys)
            local changed = false

            for rKey, renter in pairs(ent.renters) do
                if not isRenterValid(renter) then
                    local uid = tonumber((rKey:gsub("^u", ""))) or 0
                    for _, p in pairs(players) do
                        if (tonumber(p:getUserID()) or 0) == uid then
                            revokeVisualAccess(world, p, tx, ty)
                            spawnParticle(p, tx, ty)
                            break
                        end
                    end
                    ent.renters[rKey] = nil
                    changed = true
                end
            end

            if changed then
                saveEntrance(worldName, tx, ty, ent)
                if countActiveRenters(ent) == 0 then resetVisualForAll(world, tx, ty) end
            end
        end
    end
end)

return M
