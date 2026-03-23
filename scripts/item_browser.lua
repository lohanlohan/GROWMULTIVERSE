print("(item_browser) loading...")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    MIN_ITEM_ID = 1,
    MAX_ITEM_ID = 1000,
    ITEMS_PER_PAGE = 20
}

-- Global browser state tracking
local PlayerBrowserData = {}

-- ============================================================================
-- ITEM CATEGORIZATION
-- ============================================================================
local function isSeed(itemID)
    local item = getItem(itemID)
    if not item then return false end
    return item:getActionType() == 1
end

local function isClothing(itemID)
    if isSeed(itemID) then return false end
    local item = getItem(itemID)
    if not item then return false end
    local ct = item:getClothingType()
    return ct ~= nil and ct > 0
end

local function isConsumable(itemID)
    if isSeed(itemID) then return false end
    local item = getItem(itemID)
    if not item then return false end
    return item:getActionType() == 8
end

local function isBlock(itemID)
    if isSeed(itemID) then return false end
    if isClothing(itemID) then return false end
    if isConsumable(itemID) then return false end
    return true
end

local function getItemCategory(itemID)
    if isClothing(itemID) then return "Clothing"
    elseif isSeed(itemID) then return "Seed"
    elseif isConsumable(itemID) then return "Consumable"
    elseif isBlock(itemID) then return "Block"
    else return "Other"
    end
end

-- ============================================================================
-- GET ALL ITEMS WITH CATEGORY
-- ============================================================================
local function getAllItems(minID, maxID)
    local items = {}
    
    for id = minID, maxID do
        local item = getItem(id)
        if item then
            local name = item:getName()
            -- Only include valid items (skip empty/invalid)
            if name and name ~= "" and name ~= "Null Item" then
                table.insert(items, {
                    id = id,
                    name = name,
                    category = getItemCategory(id)
                })
            end
        end
    end
    
    return items
end

-- ============================================================================
-- FILTER BY CATEGORY
-- ============================================================================
local function filterByCategory(items, category)
    if category == "all" then return items end
    
    local filtered = {}
    for _, item in ipairs(items) do
        if item.category == category then
            table.insert(filtered, item)
        end
    end
    return filtered
end

-- ============================================================================
-- ITEM BROWSER DIALOG
-- ============================================================================
local function sendItemBrowser(player, page, category)
    page = page or 1
    category = category or "all"
    
    -- Get all items
    local allItems = getAllItems(CONFIG.MIN_ITEM_ID, CONFIG.MAX_ITEM_ID)
    
    -- Filter by category
    local items = filterByCategory(allItems, category)
    
    -- Calculate pagination
    local totalItems = #items
    local totalPages = math.ceil(totalItems / CONFIG.ITEMS_PER_PAGE)
    page = math.max(1, math.min(page, totalPages))
    
    local startIdx = (page - 1) * CONFIG.ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + CONFIG.ITEMS_PER_PAGE - 1, totalItems)
    
    -- Build dialog
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wItem Browser``|left|18|\n"
    d = d .. "add_textbox|`oShowing items " .. startIdx .. "-" .. endIdx .. " of " .. totalItems .. " (Page " .. page .. "/" .. totalPages .. ")``|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Category filter buttons
    d = d .. "add_label|small|`oFilter by category:|left|\n"
    d = d .. "add_smalltext|`o"
    if category == "all" then d = d .. "`2[All]`` " else d = d .. "[All] " end
    if category == "Block" then d = d .. "`2[Blocks]`` " else d = d .. "[Blocks] " end
    if category == "Clothing" then d = d .. "`2[Clothing]`` " else d = d .. "[Clothing] " end
    if category == "Seed" then d = d .. "`2[Seeds]`` " else d = d .. "[Seeds] " end
    if category == "Consumable" then d = d .. "`2[Consumables]`` " else d = d .. "[Consumables] " end
    d = d .. "|\n"
    
    d = d .. "add_button|cat_all|All|noflags|0|0|\n"
    d = d .. "add_button|cat_block|Blocks|noflags|0|0|\n"
    d = d .. "add_button|cat_clothing|Clothing|noflags|0|0|\n"
    d = d .. "add_button|cat_seed|Seeds|noflags|0|0|\n"
    d = d .. "add_button|cat_consumable|Consumables|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Items list
    d = d .. "add_label|small|`oItems:|left|\n"
    
    for i = startIdx, endIdx do
        local item = items[i]
        if item then
            local color = ""
            if item.category == "Block" then color = "`9"
            elseif item.category == "Clothing" then color = "`2"
            elseif item.category == "Seed" then color = "`6"
            elseif item.category == "Consumable" then color = "`4"
            else color = "`o"
            end
            
            d = d .. "add_label_with_icon|small|" .. color .. item.name .. " `0(ID: " .. item.id .. ")``|left|" .. item.id .. "|\n"
        end
    end
    
    d = d .. "add_spacer|small|\n"
    
    -- Navigation buttons
    if page > 1 then
        d = d .. "add_button|page_prev|<< Previous|noflags|0|0|\n"
    end
    if page < totalPages then
        d = d .. "add_button|page_next|Next >>|noflags|0|0|\n"
    end
    
    -- Go to page input
    d = d .. "add_text_input|goto_page|Go to page:|" .. page .. "|5|\n"
    d = d .. "add_smalltext|`oTotal pages: " .. totalPages .. "``|\n"
    
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|item_browser|Close|Go|\n"
    
    player:onDialogRequest(d)
    
    -- Store current state
    local uid = player:getUserID()
    PlayerBrowserData[uid] = {
        page = page,
        category = category
    }
end

-- Alternative: Compact list view
local function sendCompactBrowser(player, page, category)
    page = page or 1
    category = category or "all"
    
    local allItems = getAllItems(CONFIG.MIN_ITEM_ID, CONFIG.MAX_ITEM_ID)
    local items = filterByCategory(allItems, category)
    
    local totalItems = #items
    local totalPages = math.ceil(totalItems / CONFIG.ITEMS_PER_PAGE)
    page = math.max(1, math.min(page, totalPages))
    
    local startIdx = (page - 1) * CONFIG.ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + CONFIG.ITEMS_PER_PAGE - 1, totalItems)
    
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wItem Browser (Compact)``|left|18|\n"
    d = d .. "add_smalltext|`oPage " .. page .. "/" .. totalPages .. " | Items: " .. totalItems .. "``|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Category buttons
    d = d .. "add_button_with_icon|cat_all|All|staticBlueFrame|2||\n"
    d = d .. "add_button_with_icon|cat_block|Blocks|staticBlueFrame|2||\n"
    d = d .. "add_button_with_icon|cat_clothing|Clothing|staticBlueFrame|1404||\n"
    d = d .. "add_button_with_icon|cat_seed|Seeds|staticBlueFrame|191||\n"
    d = d .. "add_button_with_icon|cat_consumable|Consumables|staticBlueFrame|1496||\n"
    d = d .. "add_spacer|small|\n"
    
    -- Compact item list (text only)
    for i = startIdx, endIdx do
        local item = items[i]
        if item then
            local icon = ""
            if item.category == "Block" then icon = "`9■`` "
            elseif item.category == "Clothing" then icon = "`2▲`` "
            elseif item.category == "Seed" then icon = "`6●`` "
            elseif item.category == "Consumable" then icon = "`4◆`` "
            else icon = "`0○`` "
            end
            
            d = d .. "add_smalltext|" .. icon .. "`w" .. item.name .. " `0(" .. item.id .. ")``|\n"
        end
    end
    
    d = d .. "add_spacer|small|\n"
    
    -- Navigation
    if page > 1 then
        d = d .. "add_button|page_prev|◄ Prev|noflags|0|0|\n"
    end
    d = d .. "add_text_input|goto_page||" .. page .. "|3|\n"
    d = d .. "add_smalltext|/ " .. totalPages .. "``|\n"
    if page < totalPages then
        d = d .. "add_button|page_next|Next ►|noflags|0|0|\n"
    end
    
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|item_browser_compact|Close|Go|\n"
    
    player:onDialogRequest(d)
    
    local uid = player:getUserID()
    PlayerBrowserData[uid] = {
        page = page,
        category = category
    }
end

-- ============================================================================
-- COMMANDS
-- ============================================================================
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:lower()
    
    if cmd == "items" then
        sendItemBrowser(player, 1, "all")
        return true
    end
    
    if cmd == "itemscompact" then
        sendCompactBrowser(player, 1, "all")
        return true
    end
    
    return false
end)

-- ============================================================================
-- DIALOG CALLBACK
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn = data["dialog_name"] or ""
    local btn = data["buttonClicked"] or ""
    
    if dn == "item_browser" or dn == "item_browser_compact" then
        local uid = player:getUserID()
        local browserData = PlayerBrowserData[uid] or {page = 1, category = "all"}
        
        local currentPage = browserData.page or 1
        local currentCategory = browserData.category or "all"
        
        -- Category filters
        if btn == "cat_all" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, 1, "all")
            else
                sendItemBrowser(player, 1, "all")
            end
            return true
        elseif btn == "cat_block" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, 1, "Block")
            else
                sendItemBrowser(player, 1, "Block")
            end
            return true
        elseif btn == "cat_clothing" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, 1, "Clothing")
            else
                sendItemBrowser(player, 1, "Clothing")
            end
            return true
        elseif btn == "cat_seed" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, 1, "Seed")
            else
                sendItemBrowser(player, 1, "Seed")
            end
            return true
        elseif btn == "cat_consumable" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, 1, "Consumable")
            else
                sendItemBrowser(player, 1, "Consumable")
            end
            return true
        end
        
        -- Page navigation
        if btn == "page_prev" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, currentPage - 1, currentCategory)
            else
                sendItemBrowser(player, currentPage - 1, currentCategory)
            end
            return true
        elseif btn == "page_next" then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, currentPage + 1, currentCategory)
            else
                sendItemBrowser(player, currentPage + 1, currentCategory)
            end
            return true
        end
        
        -- Go to page
        local gotoPage = tonumber(data["goto_page"])
        if gotoPage then
            if dn == "item_browser_compact" then
                sendCompactBrowser(player, gotoPage, currentCategory)
            else
                sendItemBrowser(player, gotoPage, currentCategory)
            end
            return true
        end
    end
    
    return false
end)

print("(item_browser) module loaded successfully.")