-- MODULE
-- store.lua — Growtopia Store handler (purchase, navigation, premium tab)

local M = {}
local Utils = _G.Utils

-- ─── Constants ─────────────────────────────────────────────────────
local StoreCat = {
    MAIN_MENU    = 0,
    LOCKS_MENU   = 1,
    ITEMPACK_MENU = 2,
    BIGITEMS_MENU = 3,
    IOTM_MENU    = 4,
    TOKEN_MENU   = 5,
    PREMIUM_MENU = 6,
}

local ServerEvents = {
    EVENT_VALENTINE          = 1,
    EVENT_ECO                = 2,
    EVENT_HALLOWEEN          = 3,
    EVENT_NIGHT_OF_THE_COMET = 4,
    EVENT_HARVEST            = 5,
    EVENT_GROW4GOOD          = 6,
    EVENT_EASTER             = 7,
    EVENT_ANNIVERSARY        = 8,
}

local DailyEvents = {
    DAILY_EVENT_GEIGER_DAY   = 40,
    DAILY_EVENT_DARKMAGE_DAY = 41,
    DAILY_EVENT_SURGERY_DAY  = 42,
    DAILY_EVENT_VOUCHER_DAYZ = 43,
    DAILY_EVENT_RAYMAN_DAY   = 44,
    DAILY_EVENT_LOCKE_DAY    = 45,
    DAILY_EVENT_XP_DAY       = 46,
}

local storeNavigation = {
    { name = "Features",      target = "main_menu",    cat = StoreCat.MAIN_MENU,    texture = "interface/large/btn_shop2.rttex", texture_y = "0" },
    { name = "Player Items",  target = "locks_menu",   cat = StoreCat.LOCKS_MENU,   texture = "interface/large/btn_shop2.rttex", texture_y = "1" },
    { name = "World Building",target = "itempack_menu",cat = StoreCat.ITEMPACK_MENU,texture = "interface/large/btn_shop2.rttex", texture_y = "3" },
    { name = "Custom Items",  target = "bigitems_menu",cat = StoreCat.BIGITEMS_MENU,texture = "interface/large/btn_shop2.rttex", texture_y = "4" },
    { name = "IOTM",          target = "iotm_menu",    cat = StoreCat.IOTM_MENU,    texture = "interface/large/btn_shop2.rttex", texture_y = "5" },
    { name = "Growtokens",    target = "token_menu",   cat = StoreCat.TOKEN_MENU,   texture = "interface/large/btn_shop2.rttex", texture_y = "2" },
    { name = "Premium",       target = "premium_menu", cat = StoreCat.PREMIUM_MENU, texture = "interface/large/btn_shop2.rttex", texture_y = "6" },
}

-- ─── Premium items ─────────────────────────────────────────────────
local PREMIUM_ITEMS = {
    {
        id      = "prem_starter",
        title   = "Starter Pack",
        desc    = "A handy starter pack! Includes a World Lock and seeds to get you going.",
        texture = "interface/large/store_buttons/store_buttons.rttex",
        tex_x   = "0",
        tex_y   = "6",
        price   = 5,
        gives   = {
            { id = 242, count = 1  },
            { id = 2,   count = 50 },
            { id = 4,   count = 50 },
        },
    },
}

-- ─── Helpers ───────────────────────────────────────────────────────
local function startsWith(s, prefix)
    return string.sub(s, 1, #prefix) == prefix
end

local function findNavCat(target)
    for _, cat in ipairs(storeNavigation) do
        if startsWith(cat.target, target) then return cat end
    end
end

-- ─── Premium tab ───────────────────────────────────────────────────
local function onPurchasePremiumItem(player, itemKey)
    local item
    for _, v in ipairs(PREMIUM_ITEMS) do
        if v.id == itemKey then item = v; break end
    end
    if not item then return end

    local price = item.price
    local bal   = player:getCoins()
    if bal < price then
        player:onStorePurchaseResult(
            "You can't afford `o" .. item.title .. "``! You're `$" ..
            Utils.formatNum(price - bal) .. "`` " .. getCurrencyLongName() .. "s short."
        )
        player:playAudio("bleep_fail.wav")
        return
    end
    if not player:removeCoins(price, 1) then return end

    local received = {}
    for _, give in ipairs(item.gives) do
        player:changeItem(give.id, give.count, 0)
        local obj = getItem(give.id)
        received[#received + 1] = give.count .. " `#" .. (obj and obj:getName() or "Item") .. "``"
    end

    local msg = "You've purchased `o" .. item.title .. "`` for `$" ..
                Utils.formatNum(price) .. "`` " .. getCurrencyLongName() .. "s.\n" ..
                "You have `$" .. Utils.formatNum(player:getCoins()) .. "`` " .. getCurrencyLongName() .. "s left."
    player:onStorePurchaseResult(msg .. "\n\n`5Received: ``" .. table.concat(received, ", "))
    player:onConsoleMessage(msg)
    player:playAudio("piano_nice.wav")
    player:updateGems(0)
    M.openStore(player, StoreCat.PREMIUM_MENU)
end

local function makePremiumButton(player, item)
    local canAfford = player:getCoins() >= item.price
    local giveList  = {}
    for _, give in ipairs(item.gives) do
        local obj = getItem(give.id)
        giveList[#giveList + 1] = give.count .. " " .. (obj and obj:getName() or "Item")
    end
    local fullDesc = "`2You Get:`` " .. table.concat(giveList, ", ") ..
                     ".<CR><CR>`5Description:`` " .. item.desc
    return string.format(
        "add_button|prem_%s|`o%s``|%s|%s|%s|%s|%s|0|%s||-1|-1||-1|-1|%s|%s|||||%s|%s|%s|CustomParams:|",
        item.id, item.title, item.texture, "",
        item.tex_x, item.tex_y, "",
        getCurrencyIcon() .. " " .. Utils.formatNum(item.price) .. " " .. getCurrencyMediumName(),
        fullDesc, canAfford and "1" or "0", "", "-1", "0"
    )
end

-- ─── Inventory upgrade ─────────────────────────────────────────────
local function onPurchaseInventoryUpgrade(player)
    if player:isMaxInventorySpace() then return end
    local price = 1000 * player:getInventorySize() / 16
    if player:getGems() < price then
        player:onStorePurchaseResult(
            "You can't afford `wUpgrade Backpack (10 slots)``! You're `$" ..
            Utils.formatNum(price - player:getGems()) .. "`` Gems short."
        )
        player:playAudio("bleep_fail.wav")
        return
    end
    local result = "You've purchased `wUpgrade Backpack (10 slots)`` for `$" ..
                   Utils.formatNum(price) .. "`` Gems.\n" ..
                   "You have `$" .. Utils.formatNum(player:getGems()) .. "`` Gems left."
    if player:removeGems(price, 1, 1) then
        player:upgradeInventorySpace(10)
        player:onStorePurchaseResult(result .. "\n\n`5Received: ``Backpack Upgrade")
        player:onConsoleMessage(result)
        player:playAudio("piano_nice.wav")
        M.openStore(player, StoreCat.LOCKS_MENU)
    end
end

-- ─── Store button builder ──────────────────────────────────────────
local function makeStoreButton(player, storeItem, isDailyOffer)
    local itemTitle = storeItem:getTitle()
    local giveItems = storeItem:getItems()
    local getItems  = {}
    for i = 1, #giveItems do
        local id, count = giveItems[i][1], giveItems[i][2]
        getItems[#getItems + 1] = count .. " " .. getItem(id):getName()
    end

    local itemsDesc = table.concat(getItems, ", ") .. "."
    if storeItem:getItemsDescription() ~= "" then
        itemsDesc = storeItem:getItemsDescription()
    end

    local isUnlocked   = true
    local iotmStock    = ""
    local extraDesc    = ""

    if storeItem:getCategory() == "iotm" then
        local iotmObj = getIOTMItem(storeItem:getItemID())
        if iotmObj then
            if iotmObj:getAmount() == 0 then
                iotmStock  = "`4Out of Stock``"
                isUnlocked = false
                extraDesc  = "<CR><CR>`5Note:`` This item is sold out, check again later."
            else
                iotmStock = "`wIn stock: " .. Utils.formatNum(iotmObj:getAmount()) .. "``"
                extraDesc = "<CR><CR>`5Note:`` There are " .. Utils.formatNum(iotmObj:getAmount()) .. " items in stock."
            end
        end
    end

    if isDailyOffer and isDailyOfferPurchased(player:getUserID(), storeItem:getItemID()) then
        iotmStock  = "`2Purchased``"
        isUnlocked = false
        extraDesc  = "<CR><CR>`5Note:`` You already purchased this offer."
    end

    local itemDesc = "`2You Get:`` " .. itemsDesc .. "<CR><CR>`5Description:`` " .. storeItem:getDescription() .. extraDesc

    -- Easter egg carton special
    if storeItem:getItemID() == 10756 then
        local progressStr, bigTitle = "", ""
        local offerTill = getEasterBuyTime(player:getUserID())
        local now       = os.time()
        if offerTill - now <= 0 then
            local hasEggs = getEasterEggs(player:getUserID())
            isUnlocked = false
            progressStr = hasEggs .. " / 1000 Magic Eggs Used"
        else
            bigTitle = formatStoreTime(offerTill, now) .. " left"
        end
        return string.format(
            "add_button|%s|`o%s``|%s|%s|%s|%s|%s|0|%s||-1|-1||-1|-1|%s|%s|%s|0|%s|    %s    |%s|%s|%s|CustomParams:|",
            storeItem:getItemID(), itemTitle, storeItem:getTexture(),
            storeItem:isRPC() and "" or itemDesc,
            storeItem:getTexturePosX(), storeItem:getTexturePosY(),
            (storeItem:isRPC() or storeItem:isVoucher()) and "" or storeItem:isGrowtoken() and -storeItem:getPrice() or storeItem:getPrice(),
            storeItem:isRPC() and getCurrencyIcon() .. " " .. Utils.formatNum(storeItem:getPrice()) .. " " .. getCurrencyMediumName() or "",
            storeItem:isRPC() and itemDesc or "",
            isUnlocked and "1" or "0",
            storeItem:getTexture(),
            (not isUnlocked) and tonumber(storeItem:getTexturePosY()) + 1 or storeItem:getTexturePosY(),
            progressStr,
            bigTitle == "" and iotmStock or bigTitle,
            storeItem:isRPC() and "-1" or "0",
            storeItem:isVoucher() and storeItem:getPrice() or "0"
        )
    end

    return string.format(
        "add_button|%s|`o%s``|%s|%s|%s|%s|%s|0|%s||-1|-1||-1|-1|%s|%s|||||%s|%s|%s|CustomParams:|",
        storeItem:getItemID(), itemTitle, storeItem:getTexture(),
        (storeItem:getItemID() == 0) and "OPENDIALOG&warptogrowganoth"
            or (storeItem:getItemID() == 10794) and "OPENDIALOG&donatemenu"
            or storeItem:isRPC() and "" or itemDesc,
        storeItem:getTexturePosX(), storeItem:getTexturePosY(),
        (storeItem:isRPC() or storeItem:isVoucher()) and "" or storeItem:isGrowtoken() and -storeItem:getPrice() or storeItem:getPrice(),
        storeItem:isRPC() and getCurrencyIcon() .. " " .. Utils.formatNum(storeItem:getPrice()) .. " " .. getCurrencyMediumName() or "",
        storeItem:isRPC() and itemDesc or "",
        isUnlocked and "1" or "0",
        iotmStock,
        storeItem:isRPC() and "-1" or "0",
        storeItem:isVoucher() and storeItem:getPrice() or "0"
    )
end

-- ─── Purchase handler ──────────────────────────────────────────────
local function onPurchaseItem(player, storeItem, isDailyOffer)
    local requiredEvent = storeItem:getRequiredEvent()
    if requiredEvent ~= -1 and requiredEvent ~= getCurrentServerEvent() then return end

    if storeItem:isVoucher() and getCurrentServerDailyEvent() ~= DailyEvents.DAILY_EVENT_VOUCHER_DAYZ then return end

    if storeItem:getItemID() == 10756 then
        if getCurrentServerEvent() ~= ServerEvents.EVENT_EASTER then return end
        if getEasterBuyTime(player:getUserID()) - os.time() <= 0 then return end
    end

    if storeItem:getCategory() == "iotm" then
        local iotmObj = getIOTMItem(storeItem:getItemID())
        if iotmObj and iotmObj:getAmount() == 0 then return end
    end

    if isDailyOffer and isDailyOfferPurchased(player:getUserID(), storeItem:getItemID()) then return end

    local getItems = storeItem:makePurchaseItems(1)
    if #getItems == 0 then return end

    if not player:canFit(getItems) then
        player:onStorePurchaseResult("You don't have enough inventory space for that!")
        player:playAudio("bleep_fail.wav")
        return
    end

    local price        = storeItem:getPrice()
    local currencyName = "Gems"
    local currencyLeft = 0

    if storeItem:isRPC() then
        currencyName = getCurrencyLongName() .. "s"
        if player:getCoins() < price then
            player:onStorePurchaseResult("You can't afford `o" .. storeItem:getTitle() .. "``! You're `$" .. Utils.formatNum(price - player:getCoins()) .. "`` " .. currencyName .. " short.")
            player:playAudio("bleep_fail.wav")
            return
        end
        if not player:removeCoins(price, 1) then return end
        currencyLeft = player:getCoins()
    elseif storeItem:isGrowtoken() or storeItem:isVoucher() then
        currencyName = storeItem:isGrowtoken() and "Growtokens" or "Vouchers"
        local neededItem = storeItem:isGrowtoken() and 1486 or 10858
        local has = player:getItemAmount(neededItem)
        if has < price then
            player:onStorePurchaseResult("You can't afford `o" .. storeItem:getTitle() .. "``! You're `$" .. Utils.formatNum(price - has) .. "`` " .. currencyName .. " short.")
            player:playAudio("bleep_fail.wav")
            return
        end
        if not player:changeItem(neededItem, -price, 0) then return end
        currencyLeft = player:getItemAmount(neededItem)
    else
        if player:getGems() < price then
            player:onStorePurchaseResult("You can't afford `o" .. storeItem:getTitle() .. "``! You're `$" .. Utils.formatNum(price - player:getGems()) .. "`` Gems short.")
            player:playAudio("bleep_fail.wav")
            return
        end
        if not player:removeGems(price, 1, 1) then return end
        currencyLeft = player:getGems()
    end

    local purchasedItems, purchasedMsgs = {}, {}
    for i = 1, #getItems do
        local id, count = getItems[i][1], getItems[i][2]
        player:progressQuests(id, count)
        player:changeItem(id, count, 0)
        purchasedItems[#purchasedItems + 1] = (count == 1) and getItem(id):getName() or count .. " " .. getItem(id):getName()
        purchasedMsgs[#purchasedMsgs + 1]  = count .. " `#" .. getItem(id):getName() .. "``"
    end

    local result = "You've purchased `o" .. storeItem:getTitle() .. "`` for `$" ..
                   Utils.formatNum(price) .. "`` " .. currencyName .. ".\n" ..
                   "You have `$" .. Utils.formatNum(currencyLeft) .. "`` " .. currencyName .. " left."
    player:onStorePurchaseResult(result .. "\n\n`5Received: ``" .. table.concat(purchasedItems, ", "))
    player:onConsoleMessage(result)
    for _, msg in ipairs(purchasedMsgs) do player:onConsoleMessage("Got " .. msg .. ".") end
    player:playAudio("piano_nice.wav")
    player:updateGems(0)

    if storeItem:getCategory() == "iotm" then
        local iotmObj = getIOTMItem(storeItem:getItemID())
        if iotmObj then
            iotmObj:setAmount(iotmObj:getAmount() - 1)
            if iotmObj:getAmount() == 0 then
                for _, p in ipairs(getServerPlayers()) do
                    p:onConsoleMessage("ĭ `4All " .. getItem(storeItem:getItemID()):getName() .. " have been sold out!``")
                    p:playAudio("gauntlet_spawn.wav")
                end
            end
        end
    end

    if isDailyOffer then addDailyOfferPurchased(player:getUserID(), storeItem:getItemID()) end

    local currentCat = storeItem:getCategory()
    if isDailyOffer then
        currentCat = "main"
    elseif currentCat ~= "iotm" and currentCat ~= "voucher" then
        if storeItem:getRequiredEvent() == -1 and storeItem:getItemID() > getRealGTItemsCount() then
            currentCat = "bigitems"
        end
    end

    local nav = findNavCat(currentCat)
    if nav then M.openStore(player, nav.cat) end
end

local function onPurchaseItemReq(player, storeItemID)
    if storeItemID == 9412 then
        onPurchaseInventoryUpgrade(player)
        return
    end
    for _, si in ipairs(getStoreItems()) do
        if si:getItemID() == storeItemID then onPurchaseItem(player, si, false); return end
    end
    for _, si in ipairs(getEventOffers()) do
        if si:getItemID() == storeItemID then onPurchaseItem(player, si, true); return end
    end
    for _, si in ipairs(getActiveDailyOffers()) do
        if si:getItemID() == storeItemID then onPurchaseItem(player, si, true); return end
    end
end

-- ─── Main store builder ────────────────────────────────────────────
function M.openStore(player, cat)
    local currentTarget = ""
    local tabs = {}
    for _, nav in ipairs(storeNavigation) do
        local isCurrent = (nav.cat == cat) and "1" or "0"
        if isCurrent == "1" then currentTarget = nav.target end
        tabs[#tabs + 1] = string.format(
            "add_tab_button|%s|%s|%s|%s|%s|%s|0|0||||-1|-1|||0|0|CustomParams:|",
            nav.target, nav.name, nav.texture, "", isCurrent, nav.texture_y
        )
    end

    local content = {}

    if cat == StoreCat.MAIN_MENU then
        content[#content + 1] = "add_big_banner|interface/large/gui_store_alert.rttex|0|0|You have `9" .. Utils.formatNum(player:getCoins()) .. " " .. getCurrencyLongName() .. "s " .. getCurrencyIcon() .. "``. Join `$/discord`` for more!|"
        local topPlayer = getTopPlayerByBalance()
        local topWorld  = getTopWorldByVisitors()
        if topWorld and topPlayer then
            local ownerInfo = topWorld:getOwner() and " (By " .. topWorld:getOwner():getName() .. ")" or ""
            content[#content + 1] = "add_button|top_players_and_worlds|`oTop Player & World ĕ``|interface/large/gtps/store_buttons/store_new_p.rttex||2|5|0|0|||-1|-1||-1|-1|`#Best Player``: " .. topPlayer:getCleanName() .. " (ā " .. Utils.formatNum(topPlayer:getTotalWorldLocks()) .. ")<CR>`#Best World``:  " .. topWorld:getName() .. ownerInfo .. "|0|||||World: " .. topWorld:getName() .. " Player: " .. topPlayer:getCleanName() .. "|0|0|CustomParams:|"
        end
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|0|"
    elseif cat == StoreCat.LOCKS_MENU then
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|7|"
        if not player:isMaxInventorySpace() then
            local invPrice = 1000 * player:getInventorySize() / 16
            content[#content + 1] = "add_button|9412|`0Upgrade Backpack`` (`w10 Slots``)|interface/large/store_buttons/store_buttons.rttex|`2You Get:`` 10 Additional Backpack Slots.<CR><CR>`5Description:`` Sewing an extra pocket onto your backpack.|0|1|" .. invPrice .. "|0|||-1|-1||-1|-1||1||||||0|0|CustomParams:|"
        end
    elseif cat == StoreCat.ITEMPACK_MENU then
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|8|"
    elseif cat == StoreCat.BIGITEMS_MENU then
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|9|"
    elseif cat == StoreCat.IOTM_MENU then
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|19|"
    elseif cat == StoreCat.TOKEN_MENU then
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|11|"
    elseif cat == StoreCat.PREMIUM_MENU then
        content[#content + 1] = "add_big_banner|interface/large/gui_store_alert.rttex|0|0|You have `9" .. Utils.formatNum(player:getCoins()) .. " " .. getCurrencyLongName() .. " " .. getCurrencyIcon() .. "``. Join `$/discord`` for more!|"
        content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|0|"
        for _, item in ipairs(PREMIUM_ITEMS) do
            content[#content + 1] = makePremiumButton(player, item)
        end
    end

    for _, si in ipairs(getStoreItems()) do
        if si:getTexture() ~= "_label_" then
            local itemCat  = si:getCategory()
            local reqEvent = si:getRequiredEvent()
            if itemCat ~= "iotm" and itemCat ~= "voucher" then
                if reqEvent == -1 and si:getItemID() > getRealGTItemsCount() then itemCat = "bigitems" end
            end
            if itemCat == "voucher" and getCurrentServerDailyEvent() == DailyEvents.DAILY_EVENT_VOUCHER_DAYZ then
                itemCat = "main"
            end
            if startsWith(currentTarget, itemCat) then
                if reqEvent == -1 or reqEvent == getCurrentServerEvent() then
                    content[#content + 1] = makeStoreButton(player, si, false)
                end
            end
        end
    end

    if cat == StoreCat.MAIN_MENU then
        local bannerAdded = false
        for _, offer in ipairs(getEventOffers()) do
            if offer:getRequiredEvent() == getCurrentServerEvent() then
                if not bannerAdded then
                    content[#content + 1] = "add_banner|interface/large/gtps_store_overlays.rttex|0|19|"
                    bannerAdded = true
                end
                content[#content + 1] = makeStoreButton(player, offer, true)
            end
        end
        content[#content + 1] = "add_banner|interface/large/gui_shop_featured_header.rttex|0|2|"
        for _, offer in ipairs(getActiveDailyOffers()) do
            content[#content + 1] = makeStoreButton(player, offer, true)
        end
        content[#content + 1] = "add_button|redeem_code|Redeem Code|interface/large/store_buttons/store_buttons40.rttex|OPENDIALOG&showredeemcodewindow|1|5|0|0|||-1|-1||-1|-1||1||||||0|0|CustomParams:|"
    end

    player:onStoreRequest(
        "set_description_text|Welcome to the `2Growtopia Store``! Select the item you'd like more info on.\n" ..
        "enable_tabs|1\n" ..
        table.concat(tabs,    "\n") .. "\n" ..
        table.concat(content, "\n")
    )
end

-- ─── Callbacks ─────────────────────────────────────────────────────
onPlayerActionCallback(function(world, player, data)
    local action = data["action"] or ""

    if action == "donatemenu"          then player:onGrow4GoodDonate(); return true end
    if action == "showredeemcodewindow" then player:onRedeemMenu();     return true end
    if action == "warptogrowganoth" then
        if player:getWorldName() == "GROWGANOTH" then
            player:onTextOverlay("You're already here!")
        else
            player:enterWorld("GROWGANOTH", "Entering Growganoth...")
        end
        return true
    end
    if action == "killstore" then return true end

    if action == "storenavigate" and data["item"] then
        if data["selection"] and startsWith(data["selection"], "s_") then return false end
        local nav = findNavCat(data["item"])
        if nav then M.openStore(player, nav.cat) end
        return true
    end

    if action == "buy" and data["item"] then
        local premKey = data["item"]:match("^prem_(.+)$")
        if premKey then onPurchasePremiumItem(player, premKey); return true end
        local nav = findNavCat(data["item"])
        if nav then M.openStore(player, nav.cat); return true end
        local itemID = tonumber(data["item"])
        if itemID then onPurchaseItemReq(player, itemID) end
        return true
    end

    return false
end)

onStoreRequest(function(world, player)
    M.openStore(player, StoreCat.MAIN_MENU)
    return true
end)

return M
