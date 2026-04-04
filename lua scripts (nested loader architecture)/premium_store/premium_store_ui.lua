-- MODULE
-- premium_store_ui.lua — Premium Store dialog builder (gold theme, tabbed)

local M      = {}
local PG_ITEM_ID = 20234

-- =======================================================
-- THEME
-- =======================================================

local BG_R, BG_G, BG_B, BG_A         = 30,  20,  2,  252
local BORDER_R, BORDER_G, BORDER_B, BORDER_A = 210, 170, 30, 255

local function rgba(r,g,b,a) return r*16777216 + g*65536 + b*256 + a end

-- Apply gold theme before onDialogRequest; call resetTheme after
function M.applyTheme(player)
    player:setNextDialogRGBA(BG_R, BG_G, BG_B, BG_A)
    player:setNextDialogBorderRGBA(BORDER_R, BORDER_G, BORDER_B, BORDER_A)
end

function M.resetTheme(player)
    player:resetDialogColor()
end

local TAB_ICONS = {
    featured = 20234,
    items    = 18,
    roles    = 1796,
    titles   = 4298,
    topup    = 242,
}

local TAB_LABELS = {
    featured = "`9Featured",
    items    = "`wItems",
    roles    = "`wRoles",
    titles   = "`wTitles",
    topup    = "`9Top Up",
}

local TABS = { "featured", "items", "roles", "titles", "topup" }

-- =======================================================
-- HELPERS
-- =======================================================

local function pgLabel(amount)
    local s = tostring(math.floor(amount or 0))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "`9" .. s .. " `oPG"
end

local function stockLabel(slot)
    if not slot or (slot.id or 0) == 0 then return "" end
    if slot.stock == -1 then return "`2Unlimited" end
    if slot.stock ==  0 then return "`4Out of Stock" end
    return "`3" .. slot.stock .. " left"
end

local function divider(d)
    d = d .. "add_custom_button||display:block;height:2px;width:1.0;state:disabled;middle_colour:" .. rgba(180,140,20,180) .. ";border_colour:" .. rgba(180,140,20,0) .. ";|\n"
    d = d .. "reset_placement_x|\n"
    return d
end

-- =======================================================
-- HEADER
-- =======================================================

local function addHeader(d, player)
    local bal = _G.PremiumCurrency and _G.PremiumCurrency.getBalance(player) or 0
    local balFmt = tostring(math.floor(bal)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    d = d .. "add_label_with_icon|big|`9PREMIUM STORE|left|" .. PG_ITEM_ID .. "|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oCurrent Balance:     `9" .. balFmt .. " PG``|\n"
    d = d .. "add_spacer|small|\n"
    return d
end

-- =======================================================
-- TAB BAR
-- =======================================================

local function addTabBar(d, activeTab)
    d = d .. "start_custom_tabs|\n"
    for _, tab in ipairs(TABS) do
        local isActive = tab == activeTab
        local col = isActive and rgba(190,145,0,240) or rgba(25,18,3,230)
        local bdr = isActive and rgba(230,185,40,255) or rgba(120,90,15,180)
        local icon = TAB_ICONS[tab] or 18
        d = d .. "add_custom_button|btn_tab_" .. tab ..
            "|icon:" .. icon .. ";label:" .. TAB_LABELS[tab] ..
            ";middle_colour:" .. col ..
            ";border_colour:" .. bdr ..
            ";width:0.18;|\n"
    end
    d = d .. "end_custom_tabs|\n"
    return d
end

-- =======================================================
-- FEATURED TAB
-- =======================================================

local function buildFeaturedTab(d, player)
    local SD    = _G.StoreData
    local slots = SD and SD.getFeatured() or {{},{},{}}

    d = d .. "add_label_with_icon|small|`9Today's Featured|left|" .. PG_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oLimited-time items available for a short period only. Stock is limited, so grab them before they're gone!|\n"
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"

    local hasAny = false
    for _, slot in ipairs(slots) do
        if slot.id and slot.id > 0 then hasAny = true break end
    end

    if not hasAny then
        d = d .. "add_textbox|`8No featured items at the moment. Check back soon — exclusive items rotate regularly!|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`oVisit the `9Items``, `9Roles``, and `9Titles`` tabs to browse the full catalog.|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`oNeed more Premium Gems? Check the `9Top Up`` tab for available packages.|\n"
        return d
    end

    for i, slot in ipairs(slots) do
        if slot.id and slot.id > 0 then
            local name       = (slot.name ~= "" and slot.name) or ("Item #" .. slot.id)
            local sLabel     = stockLabel(slot)
            local outOfStock = slot.stock == 0
            local line2      = pgLabel(slot.price or 0) .. "   " .. sLabel
            if outOfStock then
                d = d .. "add_button_with_icon|btn_na_featured_" .. i ..
                    "|`8" .. name .. "\\n`4OUT OF STOCK" ..
                    "|staticGreyFrame|" .. slot.id .. "|64|\n"
            else
                d = d .. "add_button_with_icon|btn_buy_featured_" .. i ..
                    "|`w" .. name .. "\\n" .. line2 ..
                    "|staticGreyFrame|" .. slot.id .. "|64|\n"
            end
        end
    end
    return d
end

-- =======================================================
-- ITEMS TAB
-- =======================================================

local function buildItemsTab(d, player)
    local SD    = _G.StoreData
    local cfg   = SD and SD.load() or { catalog = { items = {} } }
    local items = cfg.catalog.items or {}

    d = d .. "add_label_with_icon|small|`9Items|left|18|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oPurchase exclusive items with Premium Gems. Items are delivered instantly to your inventory!|\n"
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"

    if #items == 0 then
        d = d .. "add_textbox|`8No items available yet. Check back later for exclusive items added by the server owner!|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`o[Coming soon]|\n"
        return d
    end

    for i, item in ipairs(items) do
        if (item.id or 0) > 0 then
            local name   = (item.name ~= "" and item.name) or ("Item #" .. item.id)
            local sLabel = stockLabel(item)
            if item.stock == 0 then
                d = d .. "add_button_with_icon|btn_na_item_" .. i ..
                    "|`8" .. name .. "\\n`4OUT OF STOCK|staticGreyFrame|" .. item.id .. "|48|\n"
            else
                d = d .. "add_button_with_icon|btn_buy_item_" .. i ..
                    "|`w" .. name .. "\\n" .. pgLabel(item.price or 0) .. "   " .. sLabel ..
                    "|staticGreyFrame|" .. item.id .. "|48|\n"
            end
        end
    end
    return d
end

-- =======================================================
-- ROLES TAB
-- =======================================================

local function buildRolesTab(d, player)
    local SD    = _G.StoreData
    local cfg   = SD and SD.load() or { catalog = { roles = {} } }
    local roles = cfg.catalog.roles or {}

    d = d .. "add_label_with_icon|small|`9Roles|left|1796|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oPurchase special server roles with Premium Gems. Roles come with exclusive perks and access!|\n"
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"

    if #roles == 0 then
        d = d .. "add_textbox|`8No roles available yet. Exclusive server roles will appear here when added!|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`o[Coming soon]|\n"
        return d
    end

    for i, role in ipairs(roles) do
        local typeLabel = role.permanent and "`2Permanent" or ("`3" .. (role.durationDays or 30) .. " days")
        d = d .. "add_button_with_icon|btn_buy_role_" .. i ..
            "|`w" .. (role.name or "Role") .. "\\n" ..
            pgLabel(role.price or 0) .. "   " .. typeLabel ..
            "|staticGreyFrame|1796|48|\n"
    end
    return d
end

-- =======================================================
-- TITLES TAB
-- =======================================================

local function buildTitlesTab(d, player)
    local SD     = _G.StoreData
    local cfg    = SD and SD.load() or { catalog = { titles = {} } }
    local titles = cfg.catalog.titles or {}

    d = d .. "add_label_with_icon|small|`9Titles|left|4298|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oShow off a unique title displayed next to your name. Purchased titles are yours permanently!|\n"
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"

    if #titles == 0 then
        d = d .. "add_textbox|`8No titles available yet. Custom display titles will appear here when added!|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`o[Coming soon]|\n"
        return d
    end

    for i, title in ipairs(titles) do
        d = d .. "add_button_with_icon|btn_buy_title_" .. i ..
            "|`w" .. (title.name or "Title") .. "\\n" .. pgLabel(title.price or 0) ..
            "|staticGreyFrame|4298|48|\n"
    end
    return d
end

-- =======================================================
-- TOP UP TAB
-- =======================================================

local function buildTopupTab(d, player)
    local SD   = _G.StoreData
    local cfg  = SD and SD.load() or { topup = { packages = {} } }
    local pkgs = (cfg.topup and cfg.topup.packages) or {}

    d = d .. "add_label_with_icon|small|`9Top Up Premium Gems|left|" .. PG_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oPremium Gems are the exclusive currency of Growtopia Multiverse. Use them to purchase rare items, special roles, and unique titles!|\n"
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"

    if #pkgs == 0 then
        d = d .. "add_textbox|`8No top up packages are currently available. Contact the server owner to purchase Premium Gems.|\n"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_textbox|`o[Coming soon]|\n"
    else
        for i, pkg in ipairs(pkgs) do
            local pgFmt = tostring(pkg.pgAmount or 0):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,","")
            d = d .. "add_button_with_icon|btn_topup_" .. i ..
                "|`w" .. (pkg.name or "Package") ..
                "\\n`9" .. pgFmt .. " PG  `o" .. (pkg.price or 0) .. " WL" ..
                "|staticGreyFrame|" .. PG_ITEM_ID .. "|48|\n"
        end
    end
    return d
end

-- =======================================================
-- PUBLIC: buildMain
-- =======================================================

function M.buildMain(player, activeTab)
    activeTab = activeTab or "featured"
    local d = ""
    -- start_custom_tabs MUST be first (before header) for correct tab positioning
    d = d .. "set_default_color|`o\n"
    d = addTabBar(d, activeTab)
    d = addHeader(d, player)

    if     activeTab == "featured" then d = buildFeaturedTab(d, player)
    elseif activeTab == "items"    then d = buildItemsTab(d, player)
    elseif activeTab == "roles"    then d = buildRolesTab(d, player)
    elseif activeTab == "titles"   then d = buildTitlesTab(d, player)
    elseif activeTab == "topup"    then d = buildTopupTab(d, player)
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_close|Close|noflags|0|0|\n"
    d = d .. "end_dialog|premium_store_" .. activeTab .. "|||\n"
    d = d .. "add_quick_exit|\n"
    return d
end

-- =======================================================
-- PUBLIC: buildBuyConfirm
-- =======================================================

function M.buildBuyConfirm(player, source, tab)
    local SD   = _G.StoreData
    local cfg  = SD and SD.load()
    local slot = cfg and SD.resolveSlot(cfg, source)
    if not slot or (slot.id or 0) == 0 then return nil end

    local bal       = _G.PremiumCurrency and _G.PremiumCurrency.getBalance(player) or 0
    local canAfford = bal >= (slot.price or 0)
    local name      = (slot.name ~= "" and slot.name) or ("Item #" .. (slot.id or 0))
    local after     = bal - (slot.price or 0)

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`9Confirm Purchase|left|" .. PG_ITEM_ID .. "|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|`w" .. name .. "|left|" .. (slot.id or PG_ITEM_ID) .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oPrice:      " .. pgLabel(slot.price or 0) .. "|\n"
    d = d .. "add_smalltext|`oBalance:    " .. pgLabel(bal) .. "|\n"
    if canAfford then
        d = d .. "add_smalltext|`oAfter buy:  " .. pgLabel(after) .. "|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"
    if canAfford then
        d = d .. "add_button|btn_confirm_buy|Confirm Purchase|noflags|0|0|\n"
    else
        d = d .. "add_textbox|`4Insufficient Premium Gems.\\nVisit the Top Up tab to get more.|\n"
    end
    d = d .. "add_button|btn_back_buy|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|premium_buy_" .. source .. "_" .. tab .. "|||\n"
    return d
end

-- =======================================================
-- PUBLIC: buildAdminPanel
-- =======================================================

function M.buildAdminPanel(player)
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`9Store Admin|left|" .. PG_ITEM_ID .. "|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button_with_icon|btn_admin_featured|`9Manage Featured Slots\\n`oSet items + price + stock|staticGreyFrame|" .. PG_ITEM_ID .. "|32|\n"
    d = d .. "add_button_with_icon|btn_admin_items|`wManage Items\\n`oAdd\\/remove catalog items|staticGreyFrame|18|32|\n"
    d = d .. "add_button_with_icon|btn_admin_roles|`wManage Roles\\n`oAdd\\/remove roles for sale|staticGreyFrame|1796|32|\n"
    d = d .. "add_button_with_icon|btn_admin_titles|`wManage Titles\\n`oAdd\\/remove titles for sale|staticGreyFrame|4298|32|\n"
    d = d .. "add_button_with_icon|btn_admin_topup|`9Manage Top Up Packages\\n`oSet WL packages|staticGreyFrame|242|32|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_close_admin|Close|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|premium_admin|||\n"
    return d
end

-- =======================================================
-- PUBLIC: buildFeaturedSlotEdit
-- =======================================================

function M.buildFeaturedSlotEdit(player, slotIdx)
    local SD   = _G.StoreData
    local cfg  = SD and SD.load()
    local slot = (cfg and cfg.featured[slotIdx]) or {}

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`9Featured Slot " .. slotIdx .. "|left|" .. PG_ITEM_ID .. "|\n"
    d = divider(d)
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|fe_item|Item:|" .. (slot.id or 0) .. "|\n"
    d = d .. "add_text_input|fe_name|Display Name:|" .. (slot.name or "") .. "|40|\n"
    d = d .. "add_text_input|fe_price|Price (PG):|" .. (slot.price or 0) .. "|10|\n"
    d = d .. "add_text_input|fe_stock|Stock (-1 = unlimited):|" .. (slot.stock or -1) .. "|10|\n"
    d = d .. "add_text_input|fe_enddate|End Date (unix timestamp, 0 = no expiry):|" .. (slot.endDate or 0) .. "|15|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_save_featured_" .. slotIdx .. "|Save Slot|noflags|0|0|\n"
    d = d .. "add_button|btn_clear_featured_" .. slotIdx .. "|`4Clear Slot|noflags|0|0|\n"
    d = d .. "add_button|btn_back_admin|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|premium_admin_featured_" .. slotIdx .. "|||\n"
    return d
end

return M
