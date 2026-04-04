-- MODULE
-- item_browser.lua — /items dan /itemscompact: browse item ID 1-1000 dengan pagination

local M      = {}
local Utils  = _G.Utils
local Config = _G.Config

local MIN_ITEM_ID   = 1
local MAX_ITEM_ID   = 1000
local ITEMS_PER_PAGE = 20

local playerState = {}   -- uid → { page, category }

-- =======================================================
-- HELPERS
-- =======================================================

local CAT_COLOR = {
    Block       = "`9",
    Clothing    = "`2",
    Seed        = "`6",
    Consumable  = "`4",
}

local function isSeed(itemID)
    local item = getItem(itemID)
    return item and item:getActionType() == 1
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
    return item and item:getActionType() == 8
end

local function getSimpleCategory(itemID)
    if isClothing(itemID)  then return "Clothing"   end
    if isSeed(itemID)      then return "Seed"        end
    if isConsumable(itemID) then return "Consumable" end
    return "Block"
end

local function getAllItems()
    local items = {}
    for id = MIN_ITEM_ID, MAX_ITEM_ID do
        local item = getItem(id)
        if item then
            local name = item:getName()
            if name and name ~= "" and name ~= "Null Item" then
                table.insert(items, { id = id, name = name, category = getSimpleCategory(id) })
            end
        end
    end
    return items
end

local function filterByCategory(items, category)
    if category == "all" then return items end
    local filtered = {}
    for _, item in ipairs(items) do
        if item.category == category then filtered[#filtered + 1] = item end
    end
    return filtered
end

-- =======================================================
-- DIALOGS
-- =======================================================

local function sendItemBrowser(player, page, category)
    page     = page     or 1
    category = category or "all"

    local all        = getAllItems()
    local items      = filterByCategory(all, category)
    local totalItems = #items
    local totalPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
    page = math.max(1, math.min(page, totalPages))

    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local endIdx   = math.min(startIdx + ITEMS_PER_PAGE - 1, totalItems)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wItem Browser``|left|18|\n"
    d = d .. "add_textbox|`oShowing items " .. startIdx .. "-" .. endIdx .. " of " .. totalItems .. " (Page " .. page .. "/" .. totalPages .. ")``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`oFilter by category:|left|\n"
    d = d .. "add_smalltext|`o"
    d = d .. (category == "all"        and "`2[All]`` "         or "[All] ")
    d = d .. (category == "Block"      and "`2[Blocks]`` "      or "[Blocks] ")
    d = d .. (category == "Clothing"   and "`2[Clothing]`` "    or "[Clothing] ")
    d = d .. (category == "Seed"       and "`2[Seeds]`` "       or "[Seeds] ")
    d = d .. (category == "Consumable" and "`2[Consumables]`` " or "[Consumables] ")
    d = d .. "|\n"
    d = d .. "add_button|cat_all|All|noflags|0|0|\n"
    d = d .. "add_button|cat_block|Blocks|noflags|0|0|\n"
    d = d .. "add_button|cat_clothing|Clothing|noflags|0|0|\n"
    d = d .. "add_button|cat_seed|Seeds|noflags|0|0|\n"
    d = d .. "add_button|cat_consumable|Consumables|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`oItems:|left|\n"

    for i = startIdx, endIdx do
        local item = items[i]
        if item then
            local color = CAT_COLOR[item.category] or "`o"
            d = d .. "add_label_with_icon|small|" .. color .. item.name .. " `0(ID: " .. item.id .. ")``|left|" .. item.id .. "|\n"
        end
    end

    d = d .. "add_spacer|small|\n"
    if page > 1          then d = d .. "add_button|page_prev|<< Previous|noflags|0|0|\n" end
    if page < totalPages then d = d .. "add_button|page_next|Next >>|noflags|0|0|\n"     end
    d = d .. "add_text_input|goto_page|Go to page:|" .. page .. "|5|\n"
    d = d .. "add_smalltext|`oTotal pages: " .. totalPages .. "``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|item_browser|Close|Go|\n"

    player:onDialogRequest(d)
    playerState[player:getUserID()] = { page = page, category = category }
end

local function sendCompactBrowser(player, page, category)
    page     = page     or 1
    category = category or "all"

    local all        = getAllItems()
    local items      = filterByCategory(all, category)
    local totalItems = #items
    local totalPages = math.max(1, math.ceil(totalItems / ITEMS_PER_PAGE))
    page = math.max(1, math.min(page, totalPages))

    local startIdx = (page - 1) * ITEMS_PER_PAGE + 1
    local endIdx   = math.min(startIdx + ITEMS_PER_PAGE - 1, totalItems)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wItem Browser (Compact)``|left|18|\n"
    d = d .. "add_smalltext|`oPage " .. page .. "/" .. totalPages .. " | Items: " .. totalItems .. "``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button_with_icon|cat_all|All|staticBlueFrame|2||\n"
    d = d .. "add_button_with_icon|cat_block|Blocks|staticBlueFrame|2||\n"
    d = d .. "add_button_with_icon|cat_clothing|Clothing|staticBlueFrame|1404||\n"
    d = d .. "add_button_with_icon|cat_seed|Seeds|staticBlueFrame|191||\n"
    d = d .. "add_button_with_icon|cat_consumable|Consumables|staticBlueFrame|1496||\n"
    d = d .. "add_spacer|small|\n"

    local ICON_MAP = { Block="`9■`` ", Clothing="`2▲`` ", Seed="`6●`` ", Consumable="`4◆`` " }
    for i = startIdx, endIdx do
        local item = items[i]
        if item then
            local icon = ICON_MAP[item.category] or "`0○`` "
            d = d .. "add_smalltext|" .. icon .. "`w" .. item.name .. " `0(" .. item.id .. ")``|\n"
        end
    end

    d = d .. "add_spacer|small|\n"
    if page > 1          then d = d .. "add_button|page_prev|◄ Prev|noflags|0|0|\n" end
    d = d .. "add_text_input|goto_page||" .. page .. "|3|\n"
    d = d .. "add_smalltext|/ " .. totalPages .. "``|\n"
    if page < totalPages then d = d .. "add_button|page_next|Next ►|noflags|0|0|\n" end
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|item_browser_compact|Close|Go|\n"

    player:onDialogRequest(d)
    playerState[player:getUserID()] = { page = page, category = category }
end

-- =======================================================
-- COMMANDS
-- =======================================================

registerLuaCommand({ command = "items",        roleRequired = 0, description = "Browse item database." })
registerLuaCommand({ command = "itemscompact", roleRequired = 0, description = "Browse item database (compact view)." })

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = Utils.getCmd(fullCommand)
    if cmd == "/items"        then sendItemBrowser(player, 1, "all");  return true end
    if cmd == "/itemscompact" then sendCompactBrowser(player, 1, "all"); return true end
    return false
end)

-- =======================================================
-- DIALOG CALLBACK
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"] or ""
    local btn = data["buttonClicked"] or ""

    if dn ~= "item_browser" and dn ~= "item_browser_compact" then return false end

    local state    = playerState[player:getUserID()] or { page = 1, category = "all" }
    local curPage  = state.page     or 1
    local curCat   = state.category or "all"
    local isCompact = (dn == "item_browser_compact")
    local send     = isCompact and sendCompactBrowser or sendItemBrowser

    local CAT_MAP = {
        cat_all       = "all",
        cat_block     = "Block",
        cat_clothing  = "Clothing",
        cat_seed      = "Seed",
        cat_consumable= "Consumable",
    }
    if CAT_MAP[btn] then send(player, 1, CAT_MAP[btn]); return true end

    if btn == "page_prev" then send(player, curPage - 1, curCat); return true end
    if btn == "page_next" then send(player, curPage + 1, curCat); return true end

    local gotoPage = tonumber(data["goto_page"])
    if gotoPage then send(player, gotoPage, curCat); return true end

    return true
end)

return M
