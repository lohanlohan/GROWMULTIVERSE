-- ================== CONFIG ==================

-- Save key for finale claims
local FINALE_CLAIMS_SAVE_KEY = "finale_claims_rewards_v1"

-- Finale Claim Blocks (9 different claim points)
local FINALE_CLAIMS = {
    [8776] = { name = "Finale Claim 1", rewards = {} },
    [8778] = { name = "Finale Claim 2", rewards = {} },
    [8780] = { name = "Finale Claim 3", rewards = {} },
    [8782] = { name = "Finale Claim 4", rewards = {} },
    [8784] = { name = "Finale Claim 5", rewards = {} },
    [8786] = { name = "Finale Claim 6", rewards = {} },
    [8788] = { name = "Finale Claim 7", rewards = {} },
    [8790] = { name = "Finale Claim 8", rewards = {} },
    [8792] = { name = "Finale Claim 9", rewards = {} },
}

-- Temporary storage for item picker
local pending_item_selection = {} -- [userID] = {tileID, slotIndex, itemID}

-- ================== Helper: item name → ID (used only for migration) ==================

local function getItemIDByName(itemName)
    if not itemName then return nil end
    for id = 1, 25000 do
        local item = getItem(id)
        if item then
            local name = item:getName()
            if name and name:lower() == itemName:lower() then
                return id
            end
        end
    end
    return nil
end

-- ================== SAVE/LOAD CLAIMS ==================

local function saveClaimRewards()
    local parts = {}
    for tileID, config in pairs(FINALE_CLAIMS) do
        local rparts = {}
        for _, r in ipairs(config.rewards) do
            table.insert(rparts, r.itemName .. "|" .. r.amount .. "|" .. r.chance .. "|" .. tostring(r.itemID or 0))
        end
        table.insert(parts, tostring(tileID) .. "=" .. table.concat(rparts, ","))
    end
    saveStringToServer(FINALE_CLAIMS_SAVE_KEY, table.concat(parts, ";"))
end

local function loadClaimRewards()
    local raw = loadStringFromServer(FINALE_CLAIMS_SAVE_KEY)
    if not raw or raw == "" then
        return
    end

    local migrated = false
    for segment in (raw .. ";"):gmatch("([^;]+);") do
        local tileID, rewardStr = segment:match("^(%d+)=(.*)$")
        tileID = tonumber(tileID)
        if tileID and FINALE_CLAIMS[tileID] then
            FINALE_CLAIMS[tileID].rewards = {}
            if rewardStr and rewardStr ~= "" then
                for entry in (rewardStr .. ","):gmatch("([^,]+),") do
                    -- try new format: name|amount|chance|itemID
                    local name, amt, chance, iid = entry:match("^(.+)|(%d+)|(%d+)|(%d+)$")
                    if not name then
                        -- old format: name|amount|chance (no itemID)
                        name, amt, chance = entry:match("^(.+)|(%d+)|(%d+)$")
                    end
                    if name then
                        local itemID = tonumber(iid)
                        if not itemID or itemID == 0 then
                            itemID = getItemIDByName(name)
                            migrated = true
                        end
                        table.insert(FINALE_CLAIMS[tileID].rewards, {
                            itemName = name,
                            itemID   = itemID,
                            amount   = tonumber(amt),
                            chance   = tonumber(chance)
                        })
                    end
                end
            end
        end
    end

    if migrated then
        saveClaimRewards()
    end
end

-- Load on startup
loadClaimRewards()

local TICKET_CONFIG = {
    [9216] = { -- Winter Clash Finale Ticket
        name = "Winter Clash Finale",
        worlds = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id = -15983,
        mod_name = "Winter Weakness",
        reward_item = 4354, -- Change to actual reward item
    },
    [8774] = { -- Summer Clash Finale Ticket
        name = "Summer Clash Finale",
        worlds = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id = -15984,
        mod_name = "Summer Weakness",
        reward_item = 4354, -- Change to actual reward item
    },
    [9220] = { -- Spring Clash Finale Ticket
        name = "Spring Clash Finale",
        worlds = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id = -15985,
        mod_name = "Spring Weakness",
        reward_item = 4354, -- Change to actual reward item
    },
}

local COUNTDOWN_DURATION = 1800 -- 30 minutes in seconds
local MOD_DURATION = 600 -- 10 minutes penalty

local finale_hunt_active = {} -- [userID] = ticket_type (itemID)
local finale_hunt_timers = {}
local finale_end_times = {}  -- [userID] = os.time() bitis zamani
local finale_claimed = {}    -- [userID_tileID] = true, spam korumasi

local ADMIN_ROLE = 51

local RANDOM_REWARDS = {
    "Red Coat",
    "Wolfman Mask",
    "Fuzzy Pants",
    "Vile Vial - Lupus",
    "Wolf Totem|3",
    "Massive Fang|5",
    "Wolfy Block|5",
    "Tousled Hair",
    "Snow Goggles",
    "Hot Dog Hat",
}

-- ================== Helper Functions ==================

local function getConfigByWorld(worldName)
    local lowerWorld = worldName:lower()
    
    for ticketID, config in pairs(TICKET_CONFIG) do
        for _, world in ipairs(config.worlds) do
            if lowerWorld == world:lower() then
                return config, ticketID
            end
        end
    end
    
    return nil, nil
end

-- ================== Mod Registration ==================
for ticketID, config in pairs(TICKET_CONFIG) do
    local modData = {
        modID = config.mod_id,
        modName = config.mod_name,
        onAddMessage = "`oYou feel the " .. config.mod_name .. " take hold...",
        onRemoveMessage = "`oYour ticket crumbles to dust.",
        iconID = ticketID
    }
    
    if registerLuaPlaymod then
        registerLuaPlaymod(modData)
    end
end

-- ===============================================
-- 🎟️ CONSUMABLE CALLBACK
-- ===============================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    local config = TICKET_CONFIG[itemID]
    if not config then return false end
    
    -- Check if USER has penalty mod for this ticket type
    if player:getMod(config.mod_id) then
        player:onTalkBubble(player:getNetID(), "`wYou still have " .. config.mod_name .. "! Can't use ticket!", 1)
        return true
    end
    
    -- Check if player is already in a finale world
    if world:getName():lower():find("finaleworld_") then
        player:onTalkBubble(player:getNetID(), "`wYou can't use this while in a finale world!``", 1)
        return true
    end
    
    -- Consume the item
    player:changeItem(itemID, -1, 0)

    player:onTalkBubble(player:getNetID(), "`6I SHALL FACE THE " .. config.name:upper() .. "!!!", 1)
    
    -- Random world selection
    local randomWorld = config.worlds[math.random(1, #config.worlds)]
    
    -- Teleport to finale world after 2 seconds
    timer.setTimeout(2, function()
        if player:isOnline() then
            player:enterWorld(randomWorld, "", 1)
        end
    end)
    
    return true
end)

-- ===============================================
-- 🌍 WORLD ENTER CALLBACK
-- ===============================================

onPlayerEnterWorldCallback(function(world, player)
    local worldName = world:getName()
    local config, ticketID = getConfigByWorld(worldName)
    
    if not config then return end
    
    local userID = player:getUserID()
    finale_hunt_active[userID] = ticketID

    -- Kalan sure hesapla
    local remaining = COUNTDOWN_DURATION
    if finale_end_times[userID] then
        remaining = finale_end_times[userID] - os.time()
        if remaining <= 0 then
            finale_hunt_active[userID] = nil
            finale_end_times[userID] = nil
            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour finale time has ended!", 1)
            return
        end
    else
        finale_end_times[userID] = os.time() + COUNTDOWN_DURATION
    end

    player:sendVariant({"OnCountdownStart", remaining, -1}, 0, player:getNetID())

    local timerId = timer.setTimeout(remaining, function()
        if player:isOnline() then
            finale_hunt_active[userID] = nil
            finale_hunt_timers[userID] = nil
            finale_end_times[userID] = nil
            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour finale time has ended!", 1)
        end
    end)

    finale_hunt_timers[userID] = timerId
end)

-- ===============================================
-- 🏃 WORLD LEAVE CALLBACK (PENALTY MOD)
-- ===============================================

onPlayerLeaveWorldCallback(function(world, player)
    local worldName = world:getName()
    local userID = player:getUserID()
    local ticketID = finale_hunt_active[userID]
    
    if not ticketID then return end
    
    local config = TICKET_CONFIG[ticketID]
    if not config then return end
    
    -- Check if player leaves finale world early
    local lowerWorld = worldName:lower()
    local isFinaleWorld = false
    
    for _, world in ipairs(config.worlds) do
        if lowerWorld == world:lower() then
            isFinaleWorld = true
            break
        end
    end
    
    if isFinaleWorld then
        if player:isOnline() then
            -- Gercek erken cikis
            if finale_hunt_timers[userID] then
                timer.clear(finale_hunt_timers[userID])
                finale_hunt_timers[userID] = nil
            end
            finale_hunt_active[userID] = nil
            finale_end_times[userID] = nil
        end
        -- Disconnect ise DisconnectCallback handle eder
    end
end)

-- ===============================================
-- 🚪 DISCONNECT CLEANUP
-- ===============================================

onPlayerDisconnectCallback(function(player)
    local userID = player:getUserID()
    local ticketID = finale_hunt_active[userID]
    
    if ticketID then
        -- endTime koru, geri gelince devam etsin
        if finale_hunt_timers[userID] then
            timer.clear(finale_hunt_timers[userID])
            finale_hunt_timers[userID] = nil
        end
    else
        finale_hunt_active[userID] = nil
        finale_end_times[userID] = nil
    end
end)

-- ===============================================
-- 🗿 FINALE CLAIM BLOCKS ACTIVATION
-- ===============================================

onPlayerActivateTileCallback(function(world, player, tile)
    local tileID = tile:getTileID()

    local claimConfig = FINALE_CLAIMS[tileID]
    if not claimConfig then
        return false
    end

    local userID = player:getUserID()
    local claimKey = tostring(userID) .. "_" .. tostring(tileID)

    -- Spam koruması
    if finale_claimed[claimKey] then return true end
    finale_claimed[claimKey] = true
    local ticketID = finale_hunt_active[userID]

    if not ticketID then
        -- finale_hunt_active nil olabilir (script reload vs), world'den bul
        local _, tid2 = getConfigByWorld(world:getName())
        if tid2 then
            ticketID = tid2
            finale_hunt_active[userID] = tid2
        else
            player:onTalkBubble(player:getNetID(), "`wYou need an active finale ticket!", 1)
            return true
        end
    end
    
    local config = TICKET_CONFIG[ticketID]
    if not config then
        return true
    end
    
    -- Check if player has penalty mod - if yes, block activation
    if player:getMod(config.mod_id) then
        return true
    end
    
    -- Give main reward item from ticket config
    local mainGiven = player:changeItem(config.reward_item, 1, 0)
    if not mainGiven then
        local pX, pY = player:getPosX(), player:getPosY()
        local tileX = math.floor(pX / 32)
        local tileY = math.floor(pY / 32)
        world:spawnItem(tileX * 32, tileY * 32, config.reward_item, 1)
    end
    
    -- Chance bazli random reward sistemi
    local randomRewardName = ""
    if #claimConfig.rewards > 0 then
        -- Toplam chance hesapla
        local totalChance = 0
        for _, r in ipairs(claimConfig.rewards) do totalChance = totalChance + r.chance end

        local chosen = nil
        if totalChance > 0 then
            local roll = math.random(1, totalChance)
            local cumulative = 0
            for _, r in ipairs(claimConfig.rewards) do
                cumulative = cumulative + r.chance
                if roll <= cumulative then
                    chosen = r
                    break
                end
            end
        end

        -- chosen yoksa son elementi ver (fallback)
        if not chosen then
            chosen = claimConfig.rewards[#claimConfig.rewards]
        end

        if chosen then
            randomRewardName = chosen.itemName
            local rewardID = chosen.itemID
            if rewardID and rewardID > 0 then
                local given = player:changeItem(rewardID, chosen.amount, 0)
                if not given then
                    local pX, pY = player:getPosX(), player:getPosY()
                    world:spawnItem(math.floor(pX/32)*32, math.floor(pY/32)*32, rewardID, chosen.amount)
                end
            end
        end
    end
    
    local rewardText = randomRewardName ~= "" and (randomRewardName) or "a reward"
    local message = "`9You completed " .. claimConfig.name .. " `wand you got `2" .. rewardText .. "`w!"
    
    player:onConsoleMessage(message)
    player:onTalkBubble(player:getNetID(), message, 1)
    player:playAudio("level_up.wav")
    local cx = player:getPosX() + 15
    local cy = player:getPosY() + 15
    if player.onParticleEffect then
        player:onParticleEffect(46, cx, cy, 0, 0, 0)
    end

    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())

    -- Basarili tamamlama: cooldown YOK, timer iptal et
    local userID = player:getUserID()
    if finale_hunt_timers[userID] then
        timer.clear(finale_hunt_timers[userID])
        finale_hunt_timers[userID] = nil
    end
    finale_hunt_active[userID] = nil

    -- Teleport back to START after 5 seconds
    timer.setTimeout(5, function()
        finale_claimed[claimKey] = nil
        if player:isOnline() then
            player:enterWorld("", "", 1)
        end
    end)

    return true
end)

-- ===============================================
-- 📝 CONFIG DIALOG HELPER
-- ===============================================

local function showClaimListDialog(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wFinale Claim Config``|left|8776|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`oSelect a claim block to edit rewards:``|\n"
    dialog = dialog .. "add_spacer|small|\n"
    
    local sortedClaims = {}
    for tileID, config in pairs(FINALE_CLAIMS) do
        table.insert(sortedClaims, {tileID=tileID, config=config})
    end
    table.sort(sortedClaims, function(a, b) return a.tileID < b.tileID end)
    for _, entry in ipairs(sortedClaims) do
        local rewardCount = #entry.config.rewards
        dialog = dialog .. "add_button|edit_claim_" .. entry.tileID .. "|" .. entry.config.name .. " `o(" .. rewardCount .. " rewards)``|noflags|0|0|\n"
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|finale_claim_list|||\n"
    
    player:onDialogRequest(dialog)
end

local function showClaimEditDialog(player, tileID)
    local config = FINALE_CLAIMS[tileID]
    if not config then return end
    
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`w" .. config.name .. "``|left|" .. tileID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`oEdit rewards (12 slots):``|\n"
    dialog = dialog .. "add_spacer|small|\n"
    
    -- Show current 12 rewards with remove buttons
    -- Toplam sans kontrol
    local totalChance = 0
    for _, r in ipairs(config.rewards) do totalChance = totalChance + r.chance end
    dialog = dialog .. "add_textbox|`wTotal chance: `2" .. totalChance .. "%`o (max 100%)|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "text_scaling_string|aaaaaaaaaaaaaaaaaaaaa|\n"
    for i, reward in ipairs(config.rewards) do
        dialog = dialog .. "add_button_with_icon|remove_" .. i .. "|`w" .. reward.itemName .. "  `2x" .. reward.amount .. "  `6%" .. reward.chance .. "|staticBlueFrame|" .. (reward.itemID or 2) .. "|\n"
    end
    dialog = dialog .. "add_button_with_icon||END_LIST|noflags|0||\n"
    dialog = dialog .. "add_spacer|small|\n"
    if #config.rewards < 12 then
        dialog = dialog .. "add_button|add_new|`2+ Add Item``|noflags|0|0|\n"
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|clear_all|`4Clear All Rewards``|noflags|0|0|\n"
    dialog = dialog .. "add_button|back_to_list|`wBack to List``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|finale_claim_edit_" .. tileID .. "|||\n"
    
    player:onDialogRequest(dialog)
end

local function showItemPickerDialog(player, tileID)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wSelect Item|left|2|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oPick an item from your inventory:|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_item_picker|item_selected|Select Item|Pick from inventory|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|btn_back|`7Back|noflags|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|finale_item_picker_" .. tileID .. "|Close||\n"

    player:onDialogRequest(dialog)
end

local function showAmountDialog(player, tileID, itemID)
    local item = getItem(itemID)
    if not item then return end

    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wAdd Reward|left|" .. itemID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oSelected: `5" .. item:getName() .. "|left|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_text_input|item_amount|Amount:|1|5|\n"
    dialog = dialog .. "add_text_input|item_chance|Chance (%):|10|3|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|confirm_amount|`2Add Reward|noflags|\n"
    dialog = dialog .. "add_button|btn_back|`7Back|noflags|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|finale_amount_" .. tileID .. "_" .. itemID .. "|Close||\n"

    player:onDialogRequest(dialog)
end

-- ===============================================
-- 📋 DIALOG CALLBACK
-- ===============================================

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    local buttonClicked = data["buttonClicked"] or ""
    
    -- Main list dialog
    if dialogName == "finale_claim_list" then
        local tileID = tonumber(buttonClicked:match("^edit_claim_(%d+)$"))
        if tileID then
            showClaimEditDialog(player, tileID)
            return true
        end
        return true
    end
    
    -- Edit dialog for specific claim
    local editTileID = tonumber(dialogName:match("^finale_claim_edit_(%d+)$"))
    if editTileID then
        if buttonClicked == "back_to_list" then
            showClaimListDialog(player)
            return true
        end
        
        -- Add item button
        if buttonClicked == "add_new" then
            showItemPickerDialog(player, editTileID, 0)
            return true
        end
        
        -- Remove item button
        local removeSlot = tonumber(buttonClicked:match("^remove_(%d+)$"))
        if removeSlot then
            local config = FINALE_CLAIMS[editTileID]
            if config and config.rewards[removeSlot] then
                table.remove(config.rewards, removeSlot)
                saveClaimRewards()
                player:onConsoleMessage("`4Removed reward from slot " .. removeSlot .. "!")
                showClaimEditDialog(player, editTileID)
            end
            return true
        end
        
        -- Clear all button
        if buttonClicked == "clear_all" then
            local config = FINALE_CLAIMS[editTileID]
            if config then
                config.rewards = {}
                
                -- Save to server
                saveClaimRewards()
                
                player:onConsoleMessage("`4Cleared all rewards!``")
                player:playAudio("audio/bleep_fail.wav")
                showClaimEditDialog(player, editTileID)
            end
            return true
        end
        
        return true
    end
    
    -- Item picker dialog (Step 1: Select item)
    local pickerTileID = tonumber(dialogName:match("^finale_item_picker_(%d+)$"))
    if pickerTileID then
        if buttonClicked == "btn_back" then
            showClaimEditDialog(player, pickerTileID)
            return true
        end
        local selectedItem = tonumber(data["item_selected"])
        if selectedItem and selectedItem > 0 then
            showAmountDialog(player, pickerTileID, selectedItem)
            return true
        end
        return true
    end
    
    -- Amount dialog (Step 2: Set amount)
    local amountTileID, amountItemID = dialogName:match("^finale_amount_(%d+)_(%d+)$")
    amountTileID = tonumber(amountTileID)
    amountItemID = tonumber(amountItemID)

    if amountTileID and amountItemID then
        if buttonClicked == "btn_back" then
            showClaimEditDialog(player, amountTileID)
            return true
        end

        if buttonClicked == "confirm_amount" then
            local amount = math.max(1, tonumber(data["item_amount"]) or 1)
            local chance = math.max(1, math.min(100, tonumber(data["item_chance"]) or 10))

            -- Toplam sans 100'u gecmesin
            local config = FINALE_CLAIMS[amountTileID]
            if config then
                local total = 0
                for _, r in ipairs(config.rewards) do total = total + r.chance end
                if total + chance > 100 then
                    player:onConsoleMessage("`4Total chance would exceed 100%! Current total: `w" .. total .. "%")
                    showAmountDialog(player, amountTileID, amountItemID)
                    return true
                end

                local item = getItem(amountItemID)
                if not item then
                    player:onConsoleMessage("`4Item not found!")
                    showClaimEditDialog(player, amountTileID)
                    return true
                end

                table.insert(config.rewards, {
                    itemName = item:getName(),
                    itemID   = amountItemID,
                    amount   = amount,
                    chance   = chance
                })
                saveClaimRewards()
                player:onConsoleMessage("`2Added " .. item:getName() .. " x" .. amount .. " (" .. chance .. "%)!")
                player:playAudio("audio/success.wav")
                showClaimEditDialog(player, amountTileID)
            end
            return true
        end
        return true
    end
    
    return false
end)

-- ===============================================
-- 🎟️ ADMIN COMMANDS
-- ===============================================

onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then return false end
    
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    cmd = cmd:lower()
    
    if cmd == "finaleconfig" then
        -- Check if player is ADMIN (role 51)
        if not player:hasRole(ADMIN_ROLE) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end
        
        showClaimListDialog(player)
        return true
    end
    
    if cmd == "finale" then
        -- Check if player is DEV (role 51)
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end
        
        -- Remove all finale penalty mods
        local removedAny = false
        for ticketID, config in pairs(TICKET_CONFIG) do
            if player:getMod(config.mod_id) then
                player:removeMod(config.mod_id)
                removedAny = true
            end
        end

        if removedAny then
            player:playAudio("audio/success.wav")
        end
        
        return true
    end

    if cmd == "ghost" or cmd == "superbreak" or cmd == "longpunch" or cmd == "tpclick" or cmd == "invis" then
        if world:getName():lower():find("finaleworld_") then
            if not player:hasRole(51) then
                player:onConsoleMessage("`oCommand blocked in Finale World!``")
                return true
            end
        end
    end
    
    return false
end)

