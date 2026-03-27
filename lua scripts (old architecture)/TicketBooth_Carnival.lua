-- ========================================================
-- ⚙️ CONFIGURATION
-- ========================================================
local CONFIG = {
    BOOTH_ID = 1902,
    GOLDEN_TICKET_ID = 1898,
    
    RARITY_PER_TICKET = 50,
    MIN_RARITY = 10,
    
    -- ====================================================
    -- 🚫 BLACKLISTED ITEMS
    -- Add or remove item IDs here as needed
    -- ====================================================
    BLACKLISTED_ITEMS = {
        242,  -- World Lock
        1796, -- Diamond Lock
        7188, -- Blue Gem Lock
        1898, -- Golden Ticket (self)
        25036, -- Golden Ticket (self)
        18,
        32,
        
        -- Add more items here:
        -- 528,  -- Example: Dirt
        -- 2,    -- Example: Bedrock
    },
    -- ====================================================
    
    USE_COOLDOWN = 3
}

-- ========================================================
-- 💾 DATA STORAGE
-- ========================================================
local playerCooldowns = {}
local playerSelectedItems = {}

-- ========================================================
-- 🛠️ HELPER FUNCTIONS
-- ========================================================
local function formatNumber(num)
    if not num then return "0" end
    local formatted = tostring(num)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then break end
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

local function isBlacklisted(itemId)
    for _, blackId in ipairs(CONFIG.BLACKLISTED_ITEMS) do
        if blackId == itemId then return true end
    end
    return false
end

local function calculateTickets(itemId, amount)
    if isBlacklisted(itemId) then
        return 0, "Item cannot be exchanged!"
    end
    
    local rarity = getItemRarity(itemId)
    if rarity < CONFIG.MIN_RARITY then
        return 0, "Rarity too low!"
    end
    
    local totalRarity = rarity * amount
    local tickets = math.floor(totalRarity / CONFIG.RARITY_PER_TICKET)
    
    if tickets < 1 then
        return 0, "Not enough rarity!"
    end
    
    return tickets, nil
end

local function checkCooldown(player)
    local netID = player:getNetID()
    local lastUse = playerCooldowns[netID]
    
    if lastUse then
        local elapsed = os.time() - lastUse
        if elapsed < CONFIG.USE_COOLDOWN then
            return false, CONFIG.USE_COOLDOWN - elapsed
        end
    end
    return true
end

local function setCooldown(player)
    playerCooldowns[player:getNetID()] = os.time()
end

-- ========================================================
-- 💼 INVENTORY MANAGEMENT
-- ========================================================
local function giveItemSmart(player, itemId, amount)
    -- Try to give to inventory first
    local success = player:changeItem(itemId, amount, 0)
    
    if not success then
        -- Inventory full, send to backpack
        player:changeItem(itemId, amount, 1)
        return true, "backpack"
    end
    
    return true, "inventory"
end

-- ========================================================
-- 📋 MAIN DIALOG (Selection)
-- ========================================================
local function showMainDialog(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Golden Ticket Booth``|left|" .. CONFIG.BOOTH_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Detailed description
    d = d .. "add_textbox|`oWelcome to the Golden Ticket Booth! Here you can exchange your items for valuable `6Golden Tickets`` based on their rarity value. The rarer the item, the more tickets you'll receive!|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oHow it works: Every `w" .. CONFIG.RARITY_PER_TICKET .. " rarity points`` equals `61 Golden Ticket``. For example, if you exchange an item with 100 rarity, you'll receive 2 Golden Tickets!|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oMinimum rarity required: `w" .. CONFIG.MIN_RARITY .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    
    d = d .. "add_item_picker|selected_item|`wSelect Item``|Choose an item to exchange|\n"
    
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_select|||\n"
    
    player:onDialogRequest(d)
end

-- ========================================================
-- 📋 CONFIRM DIALOG (Amount input)
-- ========================================================
local function showConfirmDialog(player, itemId)
    local itemName = getItemName(itemId)
    local rarity = getItemRarity(itemId)
    local hasAmount = player:getItemAmount(itemId)
    
    -- Check blacklist
    if isBlacklisted(itemId) then
        player:onConsoleMessage("`4This item cannot be exchanged!")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end
    
    -- Check rarity
    if rarity < CONFIG.MIN_RARITY then
        player:onConsoleMessage("`4Rarity too low! (Min: " .. CONFIG.MIN_RARITY .. ")")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end
    
    -- Check has items
    if hasAmount < 1 then
        player:onConsoleMessage("`4You don't have this item!")
        player:playAudio("audio/bleep_fail.wav")
        showMainDialog(player)
        return
    end
    
    -- Store item ID in memory
    playerSelectedItems[player:getNetID()] = itemId
    
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Exchange " .. itemName .. "``|left|" .. itemId .. "|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Vend-style message with XXX placeholders
    d = d .. "add_textbox|`oYou will gain `6XXX Tickets`` by giving me `wXXX " .. itemName .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Amount input
    d = d .. "add_text_input|exchange_amount|How many " .. itemName .. "?|1|10|\n"
    d = d .. "add_spacer|small|\n"
    
    d = d .. "add_smalltext|`oYou have: `w" .. formatNumber(hasAmount) .. "``|left|\n"
    d = d .. "add_smalltext|`oRarity per item: `w" .. rarity .. "``|left|\n"
    d = d .. "add_smalltext|`oExchange rate: " .. CONFIG.RARITY_PER_TICKET .. " rarity = 1 ticket|left|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Vend-style buttons
    d = d .. "add_button|confirm_exchange|`2Confirm``|noflags|0|0|\n"
    d = d .. "add_button|cancel_exchange|`4Cancel``|noflags|0|0|\n"
    
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_confirm|||\n"
    
    player:onDialogRequest(d)
end

-- ========================================================
-- 📋 FINAL CONFIRM DIALOG (With real amounts)
-- ========================================================
local function showFinalConfirmDialog(player, itemId, amount, tickets)
    local itemName = getItemName(itemId)
    
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`6Confirm Purchase``|left|" .. itemId .. "|\n"
    d = d .. "add_spacer|small|\n"
    
    -- Vend-style display with REAL amounts
    d = d .. "add_textbox|`oYou are purchasing `6" .. formatNumber(tickets) .. " Golden Tickets`` for `w" .. formatNumber(amount) .. " " .. itemName .. "``|left|\n"
    d = d .. "add_spacer|small|\n"
    
    d = d .. "add_button|execute_exchange|`2Confirm``|noflags|0|0|\n"
    d = d .. "add_button|cancel_final|`4Cancel``|noflags|0|0|\n"
    
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|booth_final|||\n"
    
    player:onDialogRequest(d)
end

-- ========================================================
-- 🎮 DIALOG CALLBACK
-- ========================================================
onPlayerDialogCallback(function(world, player, data)
    local netID = player:getNetID()
    
    -- Selection dialog
    if data.dialog_name == "booth_select" then
        if data.selected_item then
            local itemId = tonumber(data.selected_item)
            if itemId and itemId > 0 then
                showConfirmDialog(player, itemId)
            end
        end
        return true
    end
    
    -- Confirm dialog (amount input)
    if data.dialog_name == "booth_confirm" then
        if data.buttonClicked == "cancel_exchange" then
            showMainDialog(player)
            return true
        end
        
        if data.buttonClicked == "confirm_exchange" then
            -- Get item ID from memory
            local itemId = playerSelectedItems[netID]
            
            -- Parse amount
            local amountStr = data.exchange_amount or ""
            local amount = tonumber(amountStr)
            
            -- Validation
            if not itemId then
                player:onConsoleMessage("`4Error: Item not selected!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end
            
            if not amount or amount < 1 or amount ~= math.floor(amount) then
                player:onConsoleMessage("`4Please enter a valid amount (whole number, at least 1)!")
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end
            
            -- Check player has items
            local hasAmount = player:getItemAmount(itemId)
            if hasAmount < amount then
                player:onConsoleMessage("`4You only have " .. hasAmount .. "!")
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end
            
            -- Calculate tickets
            local tickets, error = calculateTickets(itemId, amount)
            
            if error then
                player:onConsoleMessage("`4" .. error)
                player:playAudio("audio/bleep_fail.wav")
                showConfirmDialog(player, itemId)
                return true
            end
            
            -- Store data for final step
            playerSelectedItems[netID] = {
                itemId = itemId,
                amount = amount,
                tickets = tickets
            }
            
            -- Show final confirmation
            showFinalConfirmDialog(player, itemId, amount, tickets)
        end
        return true
    end
    
    -- Final confirmation dialog
    if data.dialog_name == "booth_final" then
        if data.buttonClicked == "cancel_final" then
            showMainDialog(player)
            return true
        end
        
        if data.buttonClicked == "execute_exchange" then
            -- Get data from memory
            local storedData = playerSelectedItems[netID]
            
            if not storedData or not storedData.itemId then
                player:onConsoleMessage("`4Error: Data not found!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end
            
            local itemId = storedData.itemId
            local amount = storedData.amount
            local tickets = storedData.tickets
            
            -- Check cooldown
            local canUse, remaining = checkCooldown(player)
            if not canUse then
                player:onConsoleMessage("`4Wait " .. remaining .. " seconds!")
                player:playAudio("audio/bleep_fail.wav")
                return true
            end
            
            -- Final check: player still has items
            local hasAmount = player:getItemAmount(itemId)
            if hasAmount < amount then
                player:onConsoleMessage("`4You no longer have enough items!")
                player:playAudio("audio/bleep_fail.wav")
                showMainDialog(player)
                return true
            end
            
            -- Execute exchange
            player:changeItem(itemId, -amount, 0)
            
            -- Give tickets (with inventory check)
            local success, destination = giveItemSmart(player, CONFIG.GOLDEN_TICKET_ID, tickets)
            
            setCooldown(player)
            
            -- Clear stored data
            playerSelectedItems[netID] = nil
            
            -- Success messages
            local itemName = getItemName(itemId)
            local destMsg = ""
            
            if destination == "backpack" then
                destMsg = " `o(Sent to backpack - inventory full)"
            end
            
            player:onConsoleMessage("`2Success! Exchanged `w" .. formatNumber(amount) .. "x " .. itemName .. " `2for `6" .. formatNumber(tickets) .. " Golden Tickets``" .. destMsg)
            player:onTalkBubble(player:getNetID(), "`6+" .. tickets .. " Tickets``", 0)
            player:playAudio("audio/kaching.wav")
        end
        return true
    end
    
    return false
end)

-- ========================================================
-- 🔧 TILE CALLBACKS
-- ========================================================
onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() == CONFIG.BOOTH_ID then
        showMainDialog(player)
        return true
    end
    return false
end)

onTilePunchCallback(function(world, player, tile)
    if tile:getTileID() == CONFIG.BOOTH_ID then
        showMainDialog(player)
        return true
    end
    return false
end)

-- ========================================================
-- 🧹 CLEANUP
-- ========================================================
onPlayerDisconnectCallback(function(player)
    if player and player.getNetID then
        local netID = player:getNetID()
        playerCooldowns[netID] = nil
        playerSelectedItems[netID] = nil
    end
end)

-- ========================================================
-- ✅ INITIALIZATION
-- ========================================================
