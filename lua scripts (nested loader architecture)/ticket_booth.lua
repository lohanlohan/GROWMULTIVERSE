-- MODULE
-- ticket_booth.lua — Golden Ticket Booth (item rarity exchange → Golden Tickets)

local M = {}

-- ── Config ────────────────────────────────────────────────────────────────────

local BOOTH_ID          = 1902
local GOLDEN_TICKET_ID  = 1898
local RARITY_PER_TICKET = 50
local MIN_RARITY        = 10
local USE_COOLDOWN      = 3

local BLACKLISTED = {
    [242]   = true,  -- World Lock
    [1796]  = true,  -- Diamond Lock
    [7188]  = true,  -- Blue Gem Lock
    [1898]  = true,  -- Golden Ticket (self)
    [25036] = true,
    [18]    = true,
    [32]    = true,
}

-- ── State ─────────────────────────────────────────────────────────────────────

local playerCooldowns     = {}   -- [netID] = timestamp
local playerSelectedItems = {}   -- [netID] = itemId (step 1) or {itemId,amount,tickets} (step 2)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function formatNumber(num)
    if not num then return "0" end
    local formatted = tostring(num)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function getItemName(id)
    local item = getItem(id)
    return item and item:getName() or "Unknown"
end

local function getItemRarity(id)
    local item = getItem(id)
    return item and item:getRarity() or 0
end

local function calculateTickets(itemId, amount)
    if BLACKLISTED[itemId] then
        return 0, "Item cannot be exchanged!"
    end
    local rarity = getItemRarity(itemId)
    if rarity < MIN_RARITY then
        return 0, "Rarity too low!"
    end
    local tickets = math.floor(rarity * amount / RARITY_PER_TICKET)
    if tickets < 1 then
        return 0, "Not enough rarity!"
    end
    return tickets, nil
end

local function checkCooldown(player)
    local last = playerCooldowns[player:getNetID()]
    if last then
        local remaining = USE_COOLDOWN - (os.time() - last)
        if remaining > 0 then return false, remaining end
    end
    return true, nil
end

-- ── Dialogs ───────────────────────────────────────────────────────────────────

local function showMainDialog(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Golden Ticket Booth``|left|" .. BOOTH_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oWelcome to the Golden Ticket Booth! Exchange your items for `6Golden Tickets`` based on their rarity value. The rarer the item, the more tickets you'll receive!|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oRate: every `w" .. RARITY_PER_TICKET .. " rarity points`` = `61 Golden Ticket``|left|\n"
    d = d .. "add_smalltext|`oMinimum rarity required: `w" .. MIN_RARITY .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|selected_item|`wSelect Item``|Choose an item to exchange|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_select|||\n"
    player:onDialogRequest(d)
end

local function showConfirmDialog(player, itemId)
    local itemName  = getItemName(itemId)
    local rarity    = getItemRarity(itemId)
    local hasAmount = player:getItemAmount(itemId)

    if BLACKLISTED[itemId] then
        player:onConsoleMessage("`4This item cannot be exchanged!")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end
    if rarity < MIN_RARITY then
        player:onConsoleMessage("`4Rarity too low! (Min: " .. MIN_RARITY .. ")")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end
    if hasAmount < 1 then
        player:onConsoleMessage("`4You don't have this item!")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end

    playerSelectedItems[player:getNetID()] = itemId

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Exchange " .. itemName .. "``|left|" .. itemId .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oYou will gain `6XXX Tickets`` by giving me `wXXX " .. itemName .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_text_input|exchange_amount|How many " .. itemName .. "?|1|10|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oYou have: `w" .. formatNumber(hasAmount) .. "``|left|\n"
    d = d .. "add_smalltext|`oRarity per item: `w" .. rarity .. "``|left|\n"
    d = d .. "add_smalltext|`oExchange rate: " .. RARITY_PER_TICKET .. " rarity = 1 ticket|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|confirm_exchange|`2Confirm``|noflags|0|0|\n"
    d = d .. "add_button|cancel_exchange|`4Cancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_confirm|||\n"
    player:onDialogRequest(d)
end

local function showFinalConfirmDialog(player, itemId, amount, tickets)
    local itemName = getItemName(itemId)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Confirm Exchange``|left|" .. itemId .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oYou are exchanging `w" .. formatNumber(amount) .. " " .. itemName .. "`` for `6" .. formatNumber(tickets) .. " Golden Tickets``|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|execute_exchange|`2Confirm``|noflags|0|0|\n"
    d = d .. "add_button|cancel_final|`4Cancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_final|||\n"
    player:onDialogRequest(d)
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

onPlayerDialogCallback(function(world, player, data)
    local netID = player:getNetID()

    if data.dialog_name == "booth_select" then
        if data.selected_item then
            local itemId = tonumber(data.selected_item)
            if itemId and itemId > 0 then
                showConfirmDialog(player, itemId)
            end
        end
        return true
    end

    if data.dialog_name == "booth_confirm" then
        if data.buttonClicked == "cancel_exchange" then
            showMainDialog(player)
            return true
        end

        if data.buttonClicked == "confirm_exchange" then
            local itemId = playerSelectedItems[netID]
            if not itemId or type(itemId) ~= "number" then
                player:onConsoleMessage("`4Error: Item not selected!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end

            local amount = tonumber(data.exchange_amount or "")
            if not amount or amount < 1 or amount ~= math.floor(amount) then
                player:onConsoleMessage("`4Please enter a valid whole number (at least 1)!")
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end

            local hasAmount = player:getItemAmount(itemId)
            if hasAmount < amount then
                player:onConsoleMessage("`4You only have " .. hasAmount .. "!")
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end

            local tickets, err = calculateTickets(itemId, amount)
            if err then
                player:onConsoleMessage("`4" .. err)
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end

            playerSelectedItems[netID] = {itemId = itemId, amount = amount, tickets = tickets}
            showFinalConfirmDialog(player, itemId, amount, tickets)
        end
        return true
    end

    if data.dialog_name == "booth_final" then
        if data.buttonClicked == "cancel_final" then
            showMainDialog(player)
            return true
        end

        if data.buttonClicked == "execute_exchange" then
            local stored = playerSelectedItems[netID]
            if not stored or not stored.itemId then
                player:onConsoleMessage("`4Error: Data not found!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end

            local canUse, remaining = checkCooldown(player)
            if not canUse then
                player:onConsoleMessage("`4Wait " .. remaining .. " more second(s)!")
                player:playAudio("audio/bleep_fail.wav")
                return true
            end

            local hasAmount = player:getItemAmount(stored.itemId)
            if hasAmount < stored.amount then
                player:onConsoleMessage("`4You no longer have enough items!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end

            player:changeItem(stored.itemId, -stored.amount, 0)

            -- Give tickets: inventory first, fallback to backpack
            local success = player:changeItem(GOLDEN_TICKET_ID, stored.tickets, 0)
            local destMsg = ""
            if not success then
                player:changeItem(GOLDEN_TICKET_ID, stored.tickets, 1)
                destMsg = " `o(Sent to backpack — inventory full)"
            end

            playerCooldowns[netID]     = os.time()
            playerSelectedItems[netID] = nil

            local itemName = getItemName(stored.itemId)
            player:onConsoleMessage("`2Exchanged `w" .. formatNumber(stored.amount) .. "x " .. itemName ..
                " `2for `6" .. formatNumber(stored.tickets) .. " Golden Tickets``" .. destMsg)
            player:onTalkBubble(player:getNetID(), "`6+" .. stored.tickets .. " Tickets``", 0)
            player:playAudio("audio/kaching.wav")
        end
        return true
    end

    return false
end)

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() == BOOTH_ID then
        showMainDialog(player)
        return true
    end
    return false
end)

onTilePunchCallback(function(world, player, tile)
    if tile:getTileID() == BOOTH_ID then
        showMainDialog(player)
        return true
    end
    return false
end)

onPlayerDisconnectCallback(function(player)
    if player and player.getNetID then
        local netID = player:getNetID()
        playerCooldowns[netID]     = nil
        playerSelectedItems[netID] = nil
    end
end)

return M
