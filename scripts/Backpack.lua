print("(Backpack) loading...")

local ItemCat = require("item_categorizer")

-- ============================================================================
-- SAVE / LOAD  (satu file JSON, satu baris per player)
-- ============================================================================
local BACKPACK_FILE = "backpack_data.json"

-- Baca seluruh DB dari file. Return table { ["uid"] = [{id,count},...], ... }
local function readDB()
    if not file.exists(BACKPACK_FILE) then return {} end
    local raw  = file.read(BACKPACK_FILE)
    if not raw or raw == "" then return {} end
    local data = json.decode(raw)
    return type(data) == "table" and data or {}
end

-- Tulis DB ke file. Format: satu baris per player, diurutkan by UID.
local function writeDB(db)
    local keys = {}
    for k in pairs(db) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)

    local lines = {"{"}
    for i, key in ipairs(keys) do
        local comma = (i < #keys) and "," or ""
        local itemsJson = json.encode(db[key]) or "[]"
        table.insert(lines, '  "' .. key .. '": ' .. itemsJson .. comma)
    end
    table.insert(lines, "}")
    file.write(BACKPACK_FILE, table.concat(lines, "\n"))
end

local function saveBackpack(player, state)
    local uid   = tostring(player:getUserID())
    local items = {}
    for itemID, count in pairs(state.storedItems) do
        if count and count > 0 then
            table.insert(items, { id = tostring(itemID), count = count })
        end
    end
    local db  = readDB()
    db[uid]   = items
    writeDB(db)
end

local function loadBackpack(userID)
    local db  = readDB()
    local raw = db[tostring(userID)]
    if not raw or type(raw) ~= "table" then return {} end
    local storedItems = {}
    for _, entry in ipairs(raw) do
        local id  = tonumber(entry.id)
        local cnt = tonumber(entry.count)
        if id and cnt and cnt > 0 then
            storedItems[id] = cnt
        end
    end
    return storedItems
end

-- ============================================================================
-- STATE
-- ============================================================================
local PlayerBackpackState = {}

local function getState(player)
    local uid = player:getUserID()
    if not PlayerBackpackState[uid] then
        PlayerBackpackState[uid] = { storedItems = loadBackpack(uid) }
    end
    return PlayerBackpackState[uid]
end

-- ============================================================================
-- CORE: ADD / REMOVE
-- ============================================================================

-- Simpan item dari inventory ke backpack. Return jumlah yang berhasil disimpan.
local function addToBackpack(player, itemID, count)
    count = tonumber(count) or 1
    if count <= 0 then return 0 end
    local hasCount = player:getItemAmount(itemID) or 0
    count = math.min(count, hasCount)
    if count <= 0 then return 0 end
    player:changeItem(itemID, -count, 0)
    local state = getState(player)
    state.storedItems[itemID] = (state.storedItems[itemID] or 0) + count
    saveBackpack(player, state)
    return count
end

-- Hapus item dari backpack storage (tanpa beri ke inventory).
-- Return jumlah yang berhasil dihapus.
local function removeFromBackpack(player, itemID, count)
    local state = getState(player)
    local stored = state.storedItems[itemID] or 0
    if stored <= 0 or count <= 0 then return 0 end
    count = math.min(count, stored)
    state.storedItems[itemID] = stored - count
    if state.storedItems[itemID] <= 0 then state.storedItems[itemID] = nil end
    saveBackpack(player, state)
    return count
end

-- ============================================================================
-- PANEL: MAIN (5x3 category grid)
-- ============================================================================
local function sendMainPanel(player)
    local state  = getState(player)
    local groups = ItemCat.groupByCategory(state.storedItems)

    local total = 0
    for _ in pairs(state.storedItems) do total = total + 1 end

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. player:getName() .. "'s Backpack``|left|4516|\n"
    d = d .. "add_textbox|`o" .. total .. " total item types stored``|\n"
    d = d .. "add_spacer|small|\n"

    -- 6x3 category grid
    d = d .. "text_scaling_string|aaaaaaaaaa|\n"
    local idx = 0
    for _, cat in ipairs(ItemCat.LIST) do
        local icon    = ItemCat.ICON[cat] or 2
        local display = ItemCat.DISPLAY[cat] or cat
        local cnt     = #groups[cat]
        local label   = display
        d = d .. "add_button_with_icon|bpCat_" .. cat .. "|" .. label .. "|is_count_label|" .. icon .. "|" .. cnt .. "|left|\n"
        idx = idx + 1
        if idx % 6 == 0 then
            d = d .. "add_custom_break|\n"
        end
    end

    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_store_items|`2Store Items|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bp_main|||\n"

    player:onDialogRequest(d)
end

-- ============================================================================
-- PANEL: STORE (item picker langsung, tanpa konfirmasi amount)
-- ============================================================================
local function sendStorePanel(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wStore Items``|left|4516|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|selectedItem|Select Item|Choose an item to store|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bp_store|||\n"
    player:onDialogRequest(d)
end

-- ============================================================================
-- PANEL: CATEGORY (daftar item, 6x5 per page, sort A-Z)
-- ============================================================================
local ITEMS_PER_ROW  = 6
local ITEMS_PER_PAGE = 30  -- 6 x 5

local function sendCategoryPanel(player, catName, page)
    local state  = getState(player)
    state.currentCat  = catName

    local groups = ItemCat.groupByCategory(state.storedItems)
    local items  = groups[catName] or {}

    -- Sort A-Z by item name (pre-cache names to avoid repeated getItem() per comparison)
    local nameCache = {}
    for _, item in ipairs(items) do
        local obj = getItem(item.id)
        nameCache[item.id] = obj and obj:getName():lower() or ""
    end
    table.sort(items, function(a, b)
        return nameCache[a.id] < nameCache[b.id]
    end)

    local totalItems = #items
    local totalPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
    page = math.max(1, math.min(page or 1, totalPages))
    state.currentPage = page

    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local endIdx   = math.min(startIdx + ITEMS_PER_PAGE - 1, totalItems)

    local icon = ItemCat.ICON[catName] or 2

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. catName .. "``|left|" .. icon .. "|\n"

    if totalItems == 0 then
        d = d .. "add_textbox|`7No " .. catName .. " items stored.``|\n"
    else
        d = d .. "add_smalltext|`o" .. totalItems .. " type(s)  |  Page `w" .. page .. "`o/" .. totalPages .. "``|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "text_scaling_string|aaaaaaaaaa|\n"

        local col = 0
        for i = startIdx, endIdx do
            local item = items[i]
            local obj  = getItem(item.id)
            local name = obj and obj:getName() or ("ID:" .. item.id)
            if #name > 7 then name = name:sub(1, 7) .. "..." end
            d = d .. "add_button_with_icon|bpItem_" .. item.id .. "|" .. name .. "|staticBlueFrame,is_count_label|" .. item.id .. "|" .. item.count .. "|left|\n"
            col = col + 1
            if col % ITEMS_PER_ROW == 0 then
                d = d .. "add_custom_break|\n"
            end
        end
        if col % ITEMS_PER_ROW ~= 0 then
            d = d .. "add_custom_break|\n"
        end
    end

    -- Navigation + Back selalu di bawah
    d = d .. "add_spacer|small|\n"
    if page > 1 then
        d = d .. "add_button|btn_cat_prev|< Prev|noflags|0|0|\n"
    end
    if page < totalPages then
        d = d .. "add_button|btn_cat_next|Next >|noflags|0|0|\n"
    end
    if totalItems > 0 then
        d = d .. "add_button|btn_clear_cat|`4Clear All``|noflags|0|0|\n"
    end
    d = d .. "add_button|btn_back_main|`oBack``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bp_cat|||\n"

    player:onDialogRequest(d)
end

-- ============================================================================
-- PANEL: CLEAR CONFIRM
-- ============================================================================
local function sendClearConfirmPanel(player, catName)
    local state = getState(player)
    local groups = ItemCat.groupByCategory(state.storedItems)
    local cnt = #(groups[catName] or {})

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`4Clear All " .. catName .. "``|left|" .. (ItemCat.ICON[catName] or 2) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`4WARNING: `oThis will permanently delete `w" .. cnt .. " type(s)`o of " .. catName .. " items from your backpack.``|\n"
    d = d .. "add_textbox|`4This action cannot be undone!``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_confirm_clear|`4Yes, Delete All!``|noflags|0|0|\n"
    d = d .. "add_button|btn_cancel_clear|`oCancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bp_clear_confirm|||\n"

    player:onDialogRequest(d)
end

-- ============================================================================
-- PANEL: ITEM ACTION (pilih drop atau taruh di inventory)
-- ============================================================================
local function sendItemActionPanel(player, itemID)
    local state  = getState(player)
    local stored = state.storedItems[itemID] or 0
    if stored <= 0 then
        sendCategoryPanel(player, state.currentCat or "Block")
        return
    end

    state.selectedItem = itemID

    local item  = getItem(itemID)
    local name  = item and item:getName() or ("Item " .. itemID)
    local inInv = player:getItemAmount(itemID) or 0
    local maxInv = math.min(stored, math.max(0, 200 - inInv))

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. name .. "``|left|" .. itemID .. "|\n"
    d = d .. "add_smalltext|`oStored in backpack: `2" .. stored .. "``|\n"
    d = d .. "add_smalltext|`oIn inventory: `2" .. inInv .. "``|\n"
    d = d .. "add_spacer|small|\n"

    -- Amount input di paling atas
    d = d .. "add_text_input|bp_amount|Amount:|1|6|\n"
    d = d .. "add_spacer|small|\n"

    -- Amount-based actions
    if maxInv > 0 then
        d = d .. "add_button|btn_to_inventory|`2Put in Inventory|noflags|0|0|\n"
    else
        d = d .. "add_textbox|`4Inventory full for this item!``|\n"
    end
    d = d .. "add_button|btn_drop_item|`eDrop in World|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"

    -- Quick actions (Take All / Drop All)
    if maxInv > 0 then
        d = d .. "add_button|btn_takeall|`2Take All|noflags|0|0|\n"
    end
    d = d .. "add_button|btn_dropall|`eDrop All|noflags|0|0|\n"
    d = d .. "add_button|btn_back_cat|`oBack|noflags|0|0|\n"
    d = d .. "end_dialog|bp_item|||\n"

    player:onDialogRequest(d)
end

-- ============================================================================
-- ADMIN: HELPER
-- ============================================================================
local function getOnlinePlayerByUID(uid)
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == uid then return p end
    end
    return nil
end

-- ============================================================================
-- ADMIN: PANELS (/editbp)
-- ============================================================================
local function sendAdminMainPanel(admin, target)
    local aState = getState(admin)
    aState.editTarget      = target:getUserID()
    aState.adminCurrentCat  = nil
    aState.adminCurrentPage = 1

    local tState = getState(target)
    local groups = ItemCat.groupByCategory(tState.storedItems)

    local total = 0
    for _ in pairs(tState.storedItems) do total = total + 1 end

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. target:getName() .. "'s Backpack``|left|4516|\n"
    d = d .. "add_textbox|`o" .. total .. " total item types stored``|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "text_scaling_string|aaaaaaaaaa|\n"
    local idx = 0
    for _, cat in ipairs(ItemCat.LIST) do
        local icon    = ItemCat.ICON[cat] or 2
        local display = ItemCat.DISPLAY[cat] or cat
        local cnt     = #groups[cat]
        d = d .. "add_button_with_icon|bpadminCat_" .. cat .. "|" .. display .. "|is_count_label|" .. icon .. "|" .. cnt .. "|left|\n"
        idx = idx + 1
        if idx % 6 == 0 then d = d .. "add_custom_break|\n" end
    end

    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bpadmin_main|||\n"
    admin:onDialogRequest(d)
end

local function sendAdminCategoryPanel(admin, catName, page)
    local aState = getState(admin)
    local target = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
    if not target then
        admin:onConsoleMessage("`4Target player went offline.")
        return
    end

    aState.adminCurrentCat  = catName
    local tState = getState(target)
    local groups = ItemCat.groupByCategory(tState.storedItems)
    local items  = groups[catName] or {}

    local nameCache = {}
    for _, item in ipairs(items) do
        local obj = getItem(item.id)
        nameCache[item.id] = obj and obj:getName():lower() or ""
    end
    table.sort(items, function(a, b)
        return nameCache[a.id] < nameCache[b.id]
    end)

    local totalItems = #items
    local totalPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
    page = math.max(1, math.min(page or 1, totalPages))
    aState.adminCurrentPage = page

    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local endIdx   = math.min(startIdx + ITEMS_PER_PAGE - 1, totalItems)
    local icon     = ItemCat.ICON[catName] or 2

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. catName .. " - " .. target:getName() .. "``|left|" .. icon .. "|\n"

    if totalItems == 0 then
        d = d .. "add_textbox|`7No " .. catName .. " items stored.``|\n"
    else
        d = d .. "add_smalltext|`o" .. totalItems .. " type(s)  |  Page `w" .. page .. "`o/" .. totalPages .. "``|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "text_scaling_string|aaaaaaaaaa|\n"

        local col = 0
        for i = startIdx, endIdx do
            local item = items[i]
            local obj  = getItem(item.id)
            local name = obj and obj:getName() or ("ID:" .. item.id)
            if #name > 7 then name = name:sub(1, 7) .. "..." end
            d = d .. "add_button_with_icon|bpadminItem_" .. item.id .. "|" .. name .. "|staticBlueFrame,is_count_label|" .. item.id .. "|" .. item.count .. "|left|\n"
            col = col + 1
            if col % ITEMS_PER_ROW == 0 then d = d .. "add_custom_break|\n" end
        end
        if col % ITEMS_PER_ROW ~= 0 then d = d .. "add_custom_break|\n" end
    end

    d = d .. "add_spacer|small|\n"
    if page > 1 then d = d .. "add_button|btn_admincat_prev|< Prev|noflags|0|0|\n" end
    if page < totalPages then d = d .. "add_button|btn_admincat_next|Next >|noflags|0|0|\n" end
    if totalItems > 0 then d = d .. "add_button|btn_admincat_clear|`4Clear All``|noflags|0|0|\n" end
    d = d .. "add_button|btn_admincat_back|`oBack``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bpadmin_cat|||\n"
    admin:onDialogRequest(d)
end

local function sendAdminClearConfirmPanel(admin, catName)
    local aState = getState(admin)
    local target = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
    if not target then admin:onConsoleMessage("`4Target player went offline."); return end

    local tState = getState(target)
    local groups = ItemCat.groupByCategory(tState.storedItems)
    local cnt    = #(groups[catName] or {})

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`4Clear All " .. catName .. "``|left|" .. (ItemCat.ICON[catName] or 2) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`4WARNING: `oThis will permanently delete `w" .. cnt .. " type(s)`o of " .. catName .. " from `w" .. target:getName() .. "`o's backpack.``|\n"
    d = d .. "add_textbox|`4This action cannot be undone!``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_adminconfirm_clear|`4Yes, Delete All!``|noflags|0|0|\n"
    d = d .. "add_button|btn_admincancel_clear|`oCancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|bpadmin_clear_confirm|||\n"
    admin:onDialogRequest(d)
end

local function sendAdminItemActionPanel(admin, itemID)
    local aState = getState(admin)
    local target = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
    if not target then admin:onConsoleMessage("`4Target player went offline."); return end

    local tState = getState(target)
    local stored = tState.storedItems[itemID] or 0
    if stored <= 0 then
        sendAdminCategoryPanel(admin, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
        return
    end

    aState.adminSelectedItem = itemID

    local item   = getItem(itemID)
    local name   = item and item:getName() or ("Item " .. itemID)
    local inInv  = admin:getItemAmount(itemID) or 0
    local maxInv = math.min(stored, math.max(0, 200 - inInv))

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. name .. "``|left|" .. itemID .. "|\n"
    d = d .. "add_smalltext|`o" .. target:getName() .. "'s backpack: `2" .. stored .. "``|\n"
    d = d .. "add_smalltext|`oYour inventory: `2" .. inInv .. "``|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_text_input|bp_admin_amount|Amount:|1|6|\n"
    d = d .. "add_spacer|small|\n"

    if maxInv > 0 then
        d = d .. "add_button|btn_admintake_inv|`2Take to My Inventory|noflags|0|0|\n"
    else
        d = d .. "add_textbox|`4Your inventory is full for this item!``|\n"
    end
    d = d .. "add_button|btn_admindrop_item|`eDrop in World|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"

    if maxInv > 0 then
        d = d .. "add_button|btn_admintakeall|`2Take All to Inventory|noflags|0|0|\n"
    end
    d = d .. "add_button|btn_admintakeall_bp|`9Take All to My Backpack|noflags|0|0|\n"
    d = d .. "add_button|btn_admindropall|`eDrop All|noflags|0|0|\n"
    d = d .. "add_button|btn_adminitem_back|`oBack|noflags|0|0|\n"
    d = d .. "end_dialog|bpadmin_item|||\n"
    admin:onDialogRequest(d)
end

-- ============================================================================
-- COMMAND
-- ============================================================================
onPlayerCommandCallback(function(world, player, cmd)
    if cmd:lower() == "backpack" or cmd:lower() == "bp" then
        sendMainPanel(player)
        return true
    end
    return false
end)

-- /editbp growid  (developer only, role 51)
onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do table.insert(args, word) end
    if (args[1] or ""):lower() ~= "editbp" then return false end

    if not player:hasRole(51) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end

    local targetName = args[2]
    if not targetName then
        player:onConsoleMessage("`4Usage: /editbp [growid]")
        return true
    end

    local targets = getPlayerByName(targetName)
    local target  = (targets and #targets > 0) and targets[1] or nil
    if not target then
        player:onConsoleMessage("`4Player '" .. targetName .. "' is not online.")
        return true
    end

    sendAdminMainPanel(player, target)
    return true
end)

-- /givebp growid itemid amount  (developer only, role 51)
onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do
        table.insert(args, word)
    end
    if (args[1] or ""):lower() ~= "givebp" then return false end

    if not player:hasRole(51) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end

    local targetName = args[2]
    local itemID     = tonumber(args[3])
    local amount     = tonumber(args[4])

    if not targetName or not itemID or not amount then
        player:onConsoleMessage("`4Usage: /givebp [growid] [itemid] [amount]")
        return true
    end
    if itemID <= 0 or amount <= 0 then
        player:onConsoleMessage("`4Invalid item ID or amount.")
        return true
    end

    local item = getItem(itemID)
    if not item then
        player:onConsoleMessage("`4Item ID " .. itemID .. " does not exist.")
        return true
    end

    -- Cari player online by name
    local targets = getPlayerByName(targetName)
    local target  = (targets and #targets > 0) and targets[1] or nil

    if not target then
        player:onConsoleMessage("`4Player '" .. targetName .. "' is not online.")
        return true
    end

    -- Tambah ke backpack target
    local targetState = getState(target)
    targetState.storedItems[itemID] = (targetState.storedItems[itemID] or 0) + amount
    saveBackpack(target, targetState)

    local itemName = item:getName()
    local cat      = ItemCat.getCategory(itemID)

    player:onConsoleMessage("`2Gave `w" .. amount .. "x " .. itemName .. " `2to `w" .. target:getName() .. "`2's backpack! `o(Category: " .. cat .. ")")
    target:onConsoleMessage("`2You received `w" .. amount .. "x " .. itemName .. " `2in your backpack from `w" .. player:getName() .. "`2! `o(Category: " .. cat .. ")")

    return true
end)

-- ============================================================================
-- DIALOG CALLBACK
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn    = data["dialog_name"]   or ""
    local btn   = data["buttonClicked"] or ""
    local state = getState(player)

    -- -----------------------------------------------------------------------
    -- MAIN PANEL
    -- -----------------------------------------------------------------------
    if dn == "bp_main" then
        if btn == "btn_store_items" then
            sendStorePanel(player)
            return true
        end
        local cat = btn:match("^bpCat_(.+)$")
        if cat then
            sendCategoryPanel(player, cat)
            return true
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- STORE PANEL: setelah item dipilih, langsung simpan semua dari inventory
    -- -----------------------------------------------------------------------
    if dn == "bp_store" then
        local sel = tonumber(data["selectedItem"])
        if sel and sel > 0 then
            local count = player:getItemAmount(sel) or 0
            if count > 0 then
                local stored = addToBackpack(player, sel, count)
                local obj    = getItem(sel)
                local name   = obj and obj:getName() or "item"
                player:onTalkBubble(player:getNetID(), "`2Stored " .. stored .. "x " .. name .. "!", 0)
            else
                player:onTalkBubble(player:getNetID(), "`4You don't have that item!", 0)
            end
        end
        sendMainPanel(player)
        return true
    end

    -- -----------------------------------------------------------------------
    -- CATEGORY PANEL
    -- -----------------------------------------------------------------------
    if dn == "bp_cat" then
        if btn == "btn_back_main" then
            sendMainPanel(player)
            return true
        end
        if btn == "btn_cat_prev" then
            sendCategoryPanel(player, state.currentCat or "Block", (state.currentPage or 1) - 1)
            return true
        end
        if btn == "btn_cat_next" then
            sendCategoryPanel(player, state.currentCat or "Block", (state.currentPage or 1) + 1)
            return true
        end
        if btn == "btn_clear_cat" then
            sendClearConfirmPanel(player, state.currentCat or "Block")
            return true
        end
        local itemID = tonumber(btn:match("^bpItem_(%d+)$"))
        if itemID then
            sendItemActionPanel(player, itemID)
            return true
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- CLEAR CONFIRM PANEL
    -- -----------------------------------------------------------------------
    if dn == "bp_clear_confirm" then
        local catName = state.currentCat or "Block"
        if btn == "btn_cancel_clear" then
            sendCategoryPanel(player, catName, state.currentPage or 1)
            return true
        end
        if btn == "btn_confirm_clear" then
            local groups = ItemCat.groupByCategory(state.storedItems)
            local items  = groups[catName] or {}
            local count  = 0
            for _, item in ipairs(items) do
                state.storedItems[item.id] = nil
                count = count + 1
            end
            saveBackpack(player, state)
            player:onTalkBubble(player:getNetID(), "`4Cleared " .. count .. " type(s) from " .. catName .. "!", 0)
            sendCategoryPanel(player, catName, 1)
            return true
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- ITEM ACTION PANEL
    -- -----------------------------------------------------------------------
    if dn == "bp_item" then
        if btn == "btn_back_cat" then
            sendCategoryPanel(player, state.currentCat or "Block", state.currentPage or 1)
            return true
        end

        local itemID = state.selectedItem
        if not itemID then
            sendMainPanel(player)
            return true
        end

        -- Take All
        if btn == "btn_takeall" then
            local inInv  = player:getItemAmount(itemID) or 0
            local amount = math.min(state.storedItems[itemID] or 0, math.max(0, 200 - inInv))
            if amount > 0 then
                local taken = removeFromBackpack(player, itemID, amount)
                if taken > 0 then
                    player:changeItem(itemID, taken, 0)
                    local obj  = getItem(itemID)
                    local name = obj and obj:getName() or "item"
                    player:onTalkBubble(player:getNetID(), "`2Took " .. taken .. "x " .. name .. "!", 0)
                end
            else
                player:onTalkBubble(player:getNetID(), "`4Inventory full!", 0)
            end
            sendCategoryPanel(player, state.currentCat or "Block", state.currentPage or 1)
            return true
        end

        -- Drop All (max 200 per drop)
        if btn == "btn_dropall" then
            local amount = math.min(200, state.storedItems[itemID] or 0)
            if amount > 0 then
                local dropped = removeFromBackpack(player, itemID, amount)
                if dropped > 0 then
                    world:spawnItem(player:getPosX() + 32, player:getPosY(), itemID, dropped, 1)
                    local obj  = getItem(itemID)
                    local name = obj and obj:getName() or "item"
                    player:onTalkBubble(player:getNetID(), "`eDropped " .. dropped .. "x " .. name .. "!", 0)
                end
            else
                player:onTalkBubble(player:getNetID(), "`4Nothing to drop!", 0)
            end
            sendCategoryPanel(player, state.currentCat or "Block", state.currentPage or 1)
            return true
        end

        local rawAmt = tonumber(data["bp_amount"]) or 1
        rawAmt = math.max(1, rawAmt)

        -- Put in Inventory
        if btn == "btn_to_inventory" then
            local inInv  = player:getItemAmount(itemID) or 0
            local maxInv = math.min(state.storedItems[itemID] or 0, math.max(0, 200 - inInv))
            local amount = math.min(rawAmt, maxInv)
            if amount > 0 then
                local taken = removeFromBackpack(player, itemID, amount)
                if taken > 0 then
                    player:changeItem(itemID, taken, 0)
                    local obj  = getItem(itemID)
                    local name = obj and obj:getName() or "item"
                    player:onTalkBubble(player:getNetID(), "`2Took " .. taken .. "x " .. name .. "!", 0)
                end
            else
                player:onTalkBubble(player:getNetID(), "`4Inventory full!", 0)
            end
            sendCategoryPanel(player, state.currentCat or "Block", state.currentPage or 1)
            return true
        end

        -- Drop in World
        if btn == "btn_drop_item" then
            local stored = state.storedItems[itemID] or 0
            local amount = math.min(rawAmt, stored)
            if amount > 0 then
                local dropped = removeFromBackpack(player, itemID, amount)
                if dropped > 0 then
                    -- spawn 1 block (32px) di kanan player
                    world:spawnItem(player:getPosX() + 32, player:getPosY(), itemID, dropped, 1)
                    local obj  = getItem(itemID)
                    local name = obj and obj:getName() or "item"
                    player:onTalkBubble(player:getNetID(), "`eDropped " .. dropped .. "x " .. name .. "!", 0)
                end
            else
                player:onTalkBubble(player:getNetID(), "`4Nothing to drop!", 0)
            end
            sendCategoryPanel(player, state.currentCat or "Block", state.currentPage or 1)
            return true
        end

        return true
    end

    return false
end)

-- ============================================================================
-- DIALOG CALLBACK: ADMIN PANELS
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn    = data["dialog_name"]   or ""
    local btn   = data["buttonClicked"] or ""
    local aState = getState(player)

    -- -----------------------------------------------------------------------
    -- ADMIN MAIN PANEL
    -- -----------------------------------------------------------------------
    if dn == "bpadmin_main" then
        local cat = btn:match("^bpadminCat_(.+)$")
        if cat then
            sendAdminCategoryPanel(player, cat, 1)
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- ADMIN CATEGORY PANEL
    -- -----------------------------------------------------------------------
    if dn == "bpadmin_cat" then
        if btn == "btn_admincat_back" then
            local target = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
            if target then sendAdminMainPanel(player, target)
            else player:onConsoleMessage("`4Target player went offline.") end
            return true
        end
        if btn == "btn_admincat_prev" then
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", (aState.adminCurrentPage or 1) - 1)
            return true
        end
        if btn == "btn_admincat_next" then
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", (aState.adminCurrentPage or 1) + 1)
            return true
        end
        if btn == "btn_admincat_clear" then
            sendAdminClearConfirmPanel(player, aState.adminCurrentCat or "Block")
            return true
        end
        local itemID = tonumber(btn:match("^bpadminItem_(%d+)$"))
        if itemID then
            sendAdminItemActionPanel(player, itemID)
            return true
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- ADMIN CLEAR CONFIRM PANEL
    -- -----------------------------------------------------------------------
    if dn == "bpadmin_clear_confirm" then
        local catName = aState.adminCurrentCat or "Block"
        local target  = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
        if not target then
            player:onConsoleMessage("`4Target player went offline.")
            return true
        end
        if btn == "btn_admincancel_clear" then
            sendAdminCategoryPanel(player, catName, aState.adminCurrentPage or 1)
            return true
        end
        if btn == "btn_adminconfirm_clear" then
            local tState = getState(target)
            local groups = ItemCat.groupByCategory(tState.storedItems)
            local items  = groups[catName] or {}
            local count  = 0
            for _, item in ipairs(items) do
                tState.storedItems[item.id] = nil
                count = count + 1
            end
            saveBackpack(target, tState)
            player:onConsoleMessage("`4Cleared " .. count .. " type(s) of " .. catName .. " from " .. target:getName() .. "'s backpack!")
            target:onConsoleMessage("`4An admin cleared " .. count .. " type(s) of " .. catName .. " from your backpack!")
            sendAdminCategoryPanel(player, catName, 1)
            return true
        end
        return true
    end

    -- -----------------------------------------------------------------------
    -- ADMIN ITEM ACTION PANEL
    -- -----------------------------------------------------------------------
    if dn == "bpadmin_item" then
        if btn == "btn_adminitem_back" then
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        local target = aState.editTarget and getOnlinePlayerByUID(aState.editTarget) or nil
        if not target then
            player:onConsoleMessage("`4Target player went offline.")
            return true
        end

        local itemID = aState.adminSelectedItem
        if not itemID then
            sendAdminMainPanel(player, target)
            return true
        end

        local tState = getState(target)

        -- Take All to Inventory
        if btn == "btn_admintakeall" then
            local inInv  = player:getItemAmount(itemID) or 0
            local amount = math.min(tState.storedItems[itemID] or 0, math.max(0, 200 - inInv))
            if amount > 0 then
                local taken = removeFromBackpack(target, itemID, amount)
                if taken > 0 then
                    player:changeItem(itemID, taken, 0)
                    local name = getItem(itemID) and getItem(itemID):getName() or "item"
                    player:onConsoleMessage("`2Took " .. taken .. "x " .. name .. " from " .. target:getName() .. "'s backpack!")
                end
            else
                player:onConsoleMessage("`4Your inventory is full!")
            end
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        -- Take All to My Backpack
        if btn == "btn_admintakeall_bp" then
            local amount = tState.storedItems[itemID] or 0
            if amount > 0 then
                local taken = removeFromBackpack(target, itemID, amount)
                if taken > 0 then
                    local myState = getState(player)
                    myState.storedItems[itemID] = (myState.storedItems[itemID] or 0) + taken
                    saveBackpack(player, myState)
                    local name = getItem(itemID) and getItem(itemID):getName() or "item"
                    player:onConsoleMessage("`9Moved " .. taken .. "x " .. name .. " from " .. target:getName() .. "'s backpack to yours!")
                end
            else
                player:onConsoleMessage("`4Nothing to take!")
            end
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        -- Drop All (max 200)
        if btn == "btn_admindropall" then
            local amount = math.min(200, tState.storedItems[itemID] or 0)
            if amount > 0 then
                local dropped = removeFromBackpack(target, itemID, amount)
                if dropped > 0 then
                    world:spawnItem(player:getPosX() + 32, player:getPosY(), itemID, dropped, 1)
                    local name = getItem(itemID) and getItem(itemID):getName() or "item"
                    player:onConsoleMessage("`eDropped " .. dropped .. "x " .. name .. " from " .. target:getName() .. "'s backpack!")
                end
            else
                player:onConsoleMessage("`4Nothing to drop!")
            end
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        local rawAmt = math.max(1, tonumber(data["bp_admin_amount"]) or 1)

        -- Take to My Inventory
        if btn == "btn_admintake_inv" then
            local inInv  = player:getItemAmount(itemID) or 0
            local maxInv = math.min(tState.storedItems[itemID] or 0, math.max(0, 200 - inInv))
            local amount = math.min(rawAmt, maxInv)
            if amount > 0 then
                local taken = removeFromBackpack(target, itemID, amount)
                if taken > 0 then
                    player:changeItem(itemID, taken, 0)
                    local name = getItem(itemID) and getItem(itemID):getName() or "item"
                    player:onConsoleMessage("`2Took " .. taken .. "x " .. name .. " from " .. target:getName() .. "'s backpack!")
                end
            else
                player:onConsoleMessage("`4Your inventory is full!")
            end
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        -- Drop in World
        if btn == "btn_admindrop_item" then
            local stored = tState.storedItems[itemID] or 0
            local amount = math.min(rawAmt, stored)
            if amount > 0 then
                local dropped = removeFromBackpack(target, itemID, amount)
                if dropped > 0 then
                    world:spawnItem(player:getPosX() + 32, player:getPosY(), itemID, dropped, 1)
                    local name = getItem(itemID) and getItem(itemID):getName() or "item"
                    player:onConsoleMessage("`eDropped " .. dropped .. "x " .. name .. " from " .. target:getName() .. "'s backpack!")
                end
            else
                player:onConsoleMessage("`4Nothing to drop!")
            end
            sendAdminCategoryPanel(player, aState.adminCurrentCat or "Block", aState.adminCurrentPage or 1)
            return true
        end

        return true
    end

    return false
end)

-- ============================================================================
-- ENTER / DISCONNECT
-- ============================================================================
onPlayerEnterWorldCallback(function(world, player)
    local uid = player:getUserID()
    PlayerBackpackState[uid] = { storedItems = loadBackpack(uid) }
end)

onPlayerDisconnectCallback(function(player)
    PlayerBackpackState[player:getUserID()] = nil
end)

-- ============================================================================
-- GLOBAL HOOK (untuk player-profile integration)
-- ============================================================================
_G.BP_openBackpack = sendMainPanel

-- Tambah item langsung ke backpack storage (tanpa ambil dari inventory).
-- Dipanggil oleh script lain (misal GrowMatic) saat ingin refund ke backpack.
-- Return: jumlah item yang berhasil disimpan.
_G.BP_storeItem = function(player, itemID, count)
    count = math.max(0, tonumber(count) or 0)
    if count <= 0 then return 0 end
    if not getItem(itemID) then return 0 end
    local state = getState(player)
    state.storedItems[itemID] = (state.storedItems[itemID] or 0) + count
    saveBackpack(player, state)
    return count
end

print("(Backpack) module loaded successfully.")
