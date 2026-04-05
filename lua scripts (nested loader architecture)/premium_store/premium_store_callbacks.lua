-- MODULE
-- premium_store_callbacks.lua — Premium Store commands and all dialog callbacks

local M = {}

local PG_ITEM_ID = 20234
local ROLE_ADMIN = 51

-- =======================================================
-- HELPERS
-- =======================================================

local function openStore(player, tab)
    local SUI = _G.StoreUI
    if not SUI then return end
    SUI.applyTheme(player)
    player:onDialogRequest(SUI.buildMain(player, tab or "featured"), 500)
    SUI.resetTheme(player)
end

local function openConfirm(player, source, tab)
    local SUI = _G.StoreUI
    if not SUI then return end
    local dlg = SUI.buildBuyConfirm(player, source, tab)
    if not dlg then
        player:onTalkBubble(player:getNetID(), "`4Item not found.", 0)
        openStore(player, tab)
        return
    end
    SUI.applyTheme(player)
    player:onDialogRequest(dlg, 500)
    SUI.resetTheme(player)
end

local function openAdmin(player)
    local SUI = _G.StoreUI
    if not SUI then return end
    SUI.applyTheme(player)
    player:onDialogRequest(SUI.buildAdminPanel(player), 500)
    SUI.resetTheme(player)
end

local function openFeaturedEdit(player, slotIdx)
    local SUI = _G.StoreUI
    if not SUI then return end
    SUI.applyTheme(player)
    player:onDialogRequest(SUI.buildFeaturedSlotEdit(player, slotIdx), 500)
    SUI.resetTheme(player)
end

local function openGachaConfirm(player, bannerIdx)
    local SUI = _G.StoreUI
    if not SUI then return end
    local dlg = SUI.buildGachaConfirm(player, bannerIdx)
    if not dlg then
        player:onTalkBubble(player:getNetID(), "`4Banner not found.", 0)
        openStore(player, "gacha")
        return
    end
    SUI.applyTheme(player)
    player:onDialogRequest(dlg, 500)
    SUI.resetTheme(player)
end

local function openGachaResult(player, bannerIdx, itemId)
    local SUI = _G.StoreUI
    if not SUI then return end
    SUI.applyTheme(player)
    player:onDialogRequest(SUI.buildGachaResult(player, bannerIdx, itemId), 500)
    SUI.resetTheme(player)
end

local function openFeaturedList(player)
    local SUI = _G.StoreUI
    if not SUI then return end
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`9Featured Slots|left|" .. PG_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_edit_slot_1|Edit Slot 1|noflags|0|0|\n"
    d = d .. "add_button|btn_edit_slot_2|Edit Slot 2|noflags|0|0|\n"
    d = d .. "add_button|btn_edit_slot_3|Edit Slot 3|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back_admin|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|premium_admin_featuredlist|||\n"
    SUI.applyTheme(player)
    player:onDialogRequest(d, 500)
    SUI.resetTheme(player)
end

-- =======================================================
-- SIDEBAR BUTTON SETUP
-- =======================================================

local STORE_EVENT = {
    id          = 50,
    title       = "`9Premium Store``",
    description = "Open the Growtopia Multiverse Premium Store.",
    message     = "`9Welcome to the Premium Store!``",
}

local STORE_BUTTON = {
    active         = true,
    buttonAction   = "premiummenu",
    buttonTemplate = "BaseEventButton",
    counter        = 0,
    counterMax     = 0,
    itemIdIcon     = PG_ITEM_ID,
    name           = "PremiumStore",
    order          = STORE_EVENT.id,
    rcssClass      = "daily_challenge",
    text           = "`9Shop``",
}

registerLuaEvent(STORE_EVENT)
addSidebarButton(json.encode(STORE_BUTTON))

local function sendStoreButton(player)
    player:sendVariant({"OnEventButtonDataSet", STORE_BUTTON.name, 1, json.encode(STORE_BUTTON)})
end

onPlayerLoginCallback(function(player)
    sendStoreButton(player)
end)

onPlayerEnterWorldCallback(function(world, player)
    sendStoreButton(player)
end)

-- Sidebar button click → open Premium Store
onPlayerActionCallback(function(world, player, data)
    local action = data["action"] or ""
    if action ~= STORE_BUTTON.buttonAction then return false end
    openStore(player, "featured")
    return true
end)

-- =======================================================
-- COMMAND: /premium
-- =======================================================

registerLuaCommand({
    command      = "premium",
    roleRequired = 0,
    description  = "Open the Premium Store.",
})

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "premium" then return false end
    openStore(player, "featured")
    return true
end)

-- =======================================================
-- MAIN STORE DIALOG CALLBACK
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local tab = dlg:match("^premium_store_(.+)$")
    if not tab then return false end

    local btn = data["buttonClicked"] or ""
    local SD  = _G.StoreData
    if not SD then return true end

    -- Tab navigation
    if btn:match("^btn_tab_") then
        local newTab = btn:match("^btn_tab_(.+)$")
        openStore(player, newTab)
        return true
    end

    -- Close
    if btn == "btn_close" or btn == "" then return true end

    -- Empty slot click → reopen same tab
    if btn:match("^btn_na_") then
        openStore(player, tab)
        return true
    end

    -- Buy button
    local buySource = btn:match("^btn_buy_(.+)$")
    if buySource then
        openConfirm(player, buySource, tab)
        return true
    end

    -- Top-up slot click
    if btn:match("^btn_topup_") then
        player:onTalkBubble(player:getNetID(), "`oContact the server owner to top up.", 0)
        openStore(player, tab)
        return true
    end

    -- Gacha banner click
    local gachaIdx = btn:match("^btn_gacha_(%d+)$")
    if gachaIdx then
        openGachaConfirm(player, tonumber(gachaIdx))
        return true
    end

    return true
end)

-- =======================================================
-- GACHA CONFIRM DIALOG CALLBACK
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local idx = dlg:match("^premium_gacha_confirm_(%d+)$")
    if not idx then return false end

    local btn       = data["buttonClicked"] or ""
    local bannerIdx = tonumber(idx)
    local SD        = _G.StoreData
    local PC        = _G.PremiumCurrency
    if not SD or not PC then return true end

    if btn == "btn_gacha_back" or btn == "" then
        openStore(player, "gacha")
        return true
    end

    if btn ~= "btn_gacha_pull" then return true end

    local cfg     = SD.load()
    local banners = cfg.gacha and cfg.gacha.banners or {}
    local banner  = banners[bannerIdx]
    if not banner then
        player:onTalkBubble(player:getNetID(), "`4Banner not found.", 0)
        openStore(player, "gacha")
        return true
    end

    local pool = banner.pool or {}
    if #pool == 0 then
        player:onTalkBubble(player:getNetID(), "`4This banner has no items yet.", 0)
        openStore(player, "gacha")
        return true
    end

    if not PC.spend(player, banner.price or 0) then
        player:onTalkBubble(player:getNetID(), "`4Insufficient Premium Gems.", 0)
        openGachaConfirm(player, bannerIdx)
        return true
    end

    local itemId = SD.rollGacha(banner)
    if itemId and itemId > 0 then
        player:changeItem(itemId, 1, 0)
    end

    openGachaResult(player, bannerIdx, itemId)
    return true
end)

-- =======================================================
-- GACHA RESULT DIALOG CALLBACK
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local idx = dlg:match("^premium_gacha_result_(%d+)$")
    if not idx then return false end

    local btn       = data["buttonClicked"] or ""
    local bannerIdx = tonumber(idx)

    if btn == "btn_gacha_done" or btn == "" then
        openStore(player, "gacha")
        return true
    end

    local again = btn:match("^btn_gacha_again_(%d+)$")
    if again then
        openGachaConfirm(player, tonumber(again))
        return true
    end

    return true
end)

-- =======================================================
-- BUY CONFIRM DIALOG CALLBACK
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local source, tab = dlg:match("^premium_buy_(.+)_([^_]+)$")
    if not source then return false end

    local btn = data["buttonClicked"] or ""
    local SD  = _G.StoreData
    local PC  = _G.PremiumCurrency
    if not SD or not PC then return true end

    if btn == "btn_back_buy" then
        openStore(player, tab)
        return true
    end

    if btn ~= "btn_confirm_buy" then return true end

    local cfg  = SD.load()
    local slot = SD.resolveSlot(cfg, source)
    if not slot or slot.id == 0 then
        player:onTalkBubble(player:getNetID(), "`4Item no longer available.", 0)
        openStore(player, tab)
        return true
    end

    if slot.stock == 0 then
        player:onTalkBubble(player:getNetID(), "`4This item is out of stock.", 0)
        openStore(player, tab)
        return true
    end

    if not PC.spend(player, slot.price or 0) then
        player:onTalkBubble(player:getNetID(), "`4Insufficient Premium Gems.", 0)
        openConfirm(player, source, tab)
        return true
    end

    SD.purchase(source)

    local slotType = slot.type or "item"
    local name     = slot.name ~= "" and slot.name or ("ID " .. (slot.id or 0))

    if slotType == "item" then
        player:changeItem(slot.id, 1, 0)
        player:onConsoleMessage("`2You purchased `w" .. name .. "`` for `9" .. slot.price .. " PG``!")
        player:onTalkBubble(player:getNetID(), "`2Purchased: " .. name, 0)
    elseif slotType == "role" then
        if slot.permanent then
            player:addRole(slot.roleId or 0)
        else
            if slot.consumableId and slot.consumableId > 0 then
                player:changeItem(slot.consumableId, 1, 0)
            end
        end
        player:onConsoleMessage("`2You purchased role `w" .. name .. "``!")
        player:onTalkBubble(player:getNetID(), "`2Role unlocked: " .. name, 0)
    elseif slotType == "title" then
        if slot.consumableId and slot.consumableId > 0 then
            player:changeItem(slot.consumableId, 1, 0)
        end
        player:onConsoleMessage("`2You purchased title `w" .. name .. "``!")
        player:onTalkBubble(player:getNetID(), "`2Title unlocked: " .. name, 0)
    end

    openStore(player, tab)
    return true
end)

-- =======================================================
-- ADMIN PANEL CALLBACKS
-- =======================================================

registerLuaCommand({
    command      = "premiumadmin",
    roleRequired = ROLE_ADMIN,
    description  = "Admin: open Premium Store management panel.",
})

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "premiumadmin" then return false end
    if not player:hasRole(ROLE_ADMIN) then
        player:onTalkBubble(player:getNetID(), "`4Access denied.", 0)
        return true
    end
    openAdmin(player)
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    if dlg ~= "premium_admin" then return false end
    if not player:hasRole(ROLE_ADMIN) then return true end

    local btn = data["buttonClicked"] or ""
    if btn == "btn_admin_featured" then
        openFeaturedList(player)
    elseif btn == "btn_close_admin" or btn == "" then
        -- close
    else
        player:onTalkBubble(player:getNetID(), "`oMore admin sections coming soon.", 0)
    end
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    if dlg ~= "premium_admin_featuredlist" then return false end
    if not player:hasRole(ROLE_ADMIN) then return true end

    local btn = data["buttonClicked"] or ""
    local idx = btn:match("^btn_edit_slot_(%d+)$")
    if idx then
        openFeaturedEdit(player, tonumber(idx))
    elseif btn == "btn_back_admin" then
        openAdmin(player)
    end
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local idx = dlg:match("^premium_admin_featured_(%d+)$")
    if not idx then return false end
    if not player:hasRole(ROLE_ADMIN) then return true end

    local btn     = data["buttonClicked"] or ""
    local SD      = _G.StoreData
    if not SD then return true end

    local slotIdx = tonumber(idx)

    if btn == "btn_back_admin" then
        openAdmin(player)
        return true
    end

    if btn:match("^btn_clear_featured_") then
        local cfg = SD.load()
        cfg.featured[slotIdx] = { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 }
        SD.save(cfg)
        player:onTalkBubble(player:getNetID(), "`2Featured slot " .. slotIdx .. " cleared.", 0)
        openAdmin(player)
        return true
    end

    if btn:match("^btn_save_featured_") then
        local itemId  = tonumber(data["fe_item"])    or 0
        local name    = data["fe_name"]              or ""
        local price   = tonumber(data["fe_price"])   or 0
        local stock   = tonumber(data["fe_stock"])   or -1
        local endDate = tonumber(data["fe_enddate"]) or 0

        if itemId == 0 then
            player:onTalkBubble(player:getNetID(), "`4Pick a valid item first.", 0)
            openFeaturedEdit(player, slotIdx)
            return true
        end

        local cfg = SD.load()
        cfg.featured[slotIdx] = {
            type      = "item",
            id        = itemId,
            name      = name,
            price     = math.max(0, price),
            stock     = stock < 0 and -1 or math.max(0, stock),
            soldCount = cfg.featured[slotIdx] and cfg.featured[slotIdx].soldCount or 0,
            endDate   = math.max(0, endDate),
        }
        SD.save(cfg)
        player:onTalkBubble(player:getNetID(), "`2Featured slot " .. slotIdx .. " saved!", 0)
        openAdmin(player)
        return true
    end

    return true
end)

return M
