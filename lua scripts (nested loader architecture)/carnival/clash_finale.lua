-- MODULE
-- clash_finale.lua — Clash Finale Tickets (9216/8774/9220), FINALEWORLD hunt, claim blocks

local M = {}

local DB = _G.DB

local STORAGE_KEY = "finale_claims_rewards_v1"

-- 9 claim blocks, each with its own reward pool
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

local TICKET_CONFIG = {
    [9216] = {
        name        = "Winter Clash Finale",
        worlds      = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id      = -15983,
        mod_name    = "Winter Weakness",
        reward_item = 4354,
    },
    [8774] = {
        name        = "Summer Clash Finale",
        worlds      = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id      = -15984,
        mod_name    = "Summer Weakness",
        reward_item = 4354,
    },
    [9220] = {
        name        = "Spring Clash Finale",
        worlds      = { "FINALEWORLD_1", "FINALEWORLD_2", "FINALEWORLD_3", "FINALEWORLD_4", "FINALEWORLD_5" },
        mod_id      = -15985,
        mod_name    = "Spring Weakness",
        reward_item = 4354,
    },
}

local COUNTDOWN_DURATION  = 1800
local ADMIN_ROLE          = 51

local finale_hunt_active = {}
local finale_hunt_timers = {}
local finale_end_times   = {}
local finale_claimed     = {}

-- ============================================================================
-- SAVE / LOAD (pipe-delimited string per tileID)
-- ============================================================================

local function getItemIDByName(itemName)
    if not itemName then return nil end
    for id = 1, 25000 do
        local item = getItem(id)
        if item then
            local name = item:getName()
            if name and name:lower() == itemName:lower() then return id end
        end
    end
    return nil
end

local function saveClaimRewards()
    local parts = {}
    for tileID, cfg in pairs(FINALE_CLAIMS) do
        local rparts = {}
        for _, r in ipairs(cfg.rewards) do
            table.insert(rparts, r.itemName .. "|" .. r.amount .. "|" .. r.chance .. "|" .. tostring(r.itemID or 0))
        end
        table.insert(parts, tostring(tileID) .. "=" .. table.concat(rparts, ","))
    end
    DB.saveStr(STORAGE_KEY, table.concat(parts, ";"))
end

local function loadClaimRewards()
    local raw = DB.loadStr(STORAGE_KEY)
    if not raw or raw == "" then return end

    local migrated = false
    for segment in (raw .. ";"):gmatch("([^;]+);") do
        local tileID, rewardStr = segment:match("^(%d+)=(.*)$")
        tileID = tonumber(tileID)
        if tileID and FINALE_CLAIMS[tileID] then
            FINALE_CLAIMS[tileID].rewards = {}
            if rewardStr and rewardStr ~= "" then
                for entry in (rewardStr .. ","):gmatch("([^,]+),") do
                    local name, amt, chance, iid = entry:match("^(.+)|(%d+)|(%d+)|(%d+)$")
                    if not name then
                        name, amt, chance = entry:match("^(.+)|(%d+)|(%d+)$")
                    end
                    if name then
                        local itemID = tonumber(iid)
                        if not itemID or itemID == 0 then
                            itemID   = getItemIDByName(name)
                            migrated = true
                        end
                        table.insert(FINALE_CLAIMS[tileID].rewards, {
                            itemName = name,
                            itemID   = itemID,
                            amount   = tonumber(amt),
                            chance   = tonumber(chance),
                        })
                    end
                end
            end
        end
    end

    if migrated then saveClaimRewards() end
end

loadClaimRewards()

-- ============================================================================
-- HELPERS
-- ============================================================================

local function getConfigByWorld(worldName)
    local lowerWorld = worldName:lower()
    for ticketID, cfg in pairs(TICKET_CONFIG) do
        for _, w in ipairs(cfg.worlds) do
            if lowerWorld == w:lower() then return cfg, ticketID end
        end
    end
    return nil, nil
end

-- ============================================================================
-- MOD REGISTRATION
-- ============================================================================

for ticketID, cfg in pairs(TICKET_CONFIG) do
    registerLuaPlaymod({
        modID          = cfg.mod_id,
        modName        = cfg.mod_name,
        onAddMessage   = "`oYou feel the " .. cfg.mod_name .. " take hold...",
        onRemoveMessage= "`oYour ticket crumbles to dust.",
        iconID         = ticketID,
    })
end

-- ============================================================================
-- CONSUMABLE
-- ============================================================================

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    local cfg = TICKET_CONFIG[itemID]
    if not cfg then return false end

    if player:getMod(cfg.mod_id) then
        player:onTalkBubble(player:getNetID(), "`wYou still have " .. cfg.mod_name .. "! Can't use ticket!", 1)
        return true
    end

    if world:getName():lower():find("finaleworld_") then
        player:onTalkBubble(player:getNetID(), "`wYou can't use this while in a finale world!``", 1)
        return true
    end

    player:changeItem(itemID, -1, 0)
    player:onTalkBubble(player:getNetID(), "`6I SHALL FACE THE " .. cfg.name:upper() .. "!!!", 1)

    local randomWorld = cfg.worlds[math.random(1, #cfg.worlds)]
    timer.setTimeout(2, function()
        if player:isOnline() then
            player:enterWorld(randomWorld, "", 1)
        end
    end)

    return true
end)

-- ============================================================================
-- WORLD ENTER
-- ============================================================================

onPlayerEnterWorldCallback(function(world, player)
    local worldName       = world:getName()
    local cfg, ticketID   = getConfigByWorld(worldName)
    if not cfg then return end

    local userID  = player:getUserID()
    finale_hunt_active[userID] = ticketID

    local remaining = COUNTDOWN_DURATION
    if finale_end_times[userID] then
        remaining = finale_end_times[userID] - os.time()
        if remaining <= 0 then
            finale_hunt_active[userID] = nil
            finale_end_times[userID]   = nil
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
            finale_end_times[userID]   = nil
            player:enterWorld("", "", 1)
            player:onTalkBubble(player:getNetID(), "`wYour finale time has ended!", 1)
        end
    end)
    finale_hunt_timers[userID] = timerId
end)

-- ============================================================================
-- WORLD LEAVE
-- ============================================================================

onPlayerLeaveWorldCallback(function(world, player)
    local userID   = player:getUserID()
    local ticketID = finale_hunt_active[userID]
    if not ticketID then return end

    local cfg = TICKET_CONFIG[ticketID]
    if not cfg then return end

    local lowerWorld    = world:getName():lower()
    local isFinaleWorld = false
    for _, w in ipairs(cfg.worlds) do
        if lowerWorld == w:lower() then isFinaleWorld = true ; break end
    end

    if isFinaleWorld and player:isOnline() then
        if finale_hunt_timers[userID] then
            timer.clear(finale_hunt_timers[userID])
            finale_hunt_timers[userID] = nil
        end
        finale_hunt_active[userID] = nil
        finale_end_times[userID]   = nil
    end
end)

-- ============================================================================
-- DISCONNECT
-- ============================================================================

onPlayerDisconnectCallback(function(player)
    local userID   = player:getUserID()
    local ticketID = finale_hunt_active[userID]
    if ticketID then
        if finale_hunt_timers[userID] then
            timer.clear(finale_hunt_timers[userID])
            finale_hunt_timers[userID] = nil
        end
    else
        finale_hunt_active[userID] = nil
        finale_end_times[userID]   = nil
    end
end)

-- ============================================================================
-- CLAIM BLOCK ACTIVATION
-- ============================================================================

onPlayerActivateTileCallback(function(world, player, tile)
    local tileID      = tile:getTileID()
    local claimConfig = FINALE_CLAIMS[tileID]
    if not claimConfig then return false end

    local userID  = player:getUserID()
    local claimKey = tostring(userID) .. "_" .. tostring(tileID)

    if finale_claimed[claimKey] then return true end
    finale_claimed[claimKey] = true

    local ticketID = finale_hunt_active[userID]
    if not ticketID then
        local _, tid2 = getConfigByWorld(world:getName())
        if tid2 then
            ticketID                   = tid2
            finale_hunt_active[userID] = tid2
        else
            player:onTalkBubble(player:getNetID(), "`wYou need an active finale ticket!", 1)
            return true
        end
    end

    local cfg = TICKET_CONFIG[ticketID]
    if not cfg then return true end

    if player:getMod(cfg.mod_id) then return true end

    -- Main reward
    if not player:changeItem(cfg.reward_item, 1, 0) then
        local pX, pY = player:getPosX(), player:getPosY()
        world:spawnItem(math.floor(pX / 32) * 32, math.floor(pY / 32) * 32, cfg.reward_item, 1)
    end

    -- Weighted random reward
    local randomRewardName = ""
    if #claimConfig.rewards > 0 then
        local totalChance = 0
        for _, r in ipairs(claimConfig.rewards) do totalChance = totalChance + r.chance end
        local chosen = nil
        if totalChance > 0 then
            local roll       = math.random(1, totalChance)
            local cumulative = 0
            for _, r in ipairs(claimConfig.rewards) do
                cumulative = cumulative + r.chance
                if roll <= cumulative then chosen = r ; break end
            end
        end
        if not chosen then chosen = claimConfig.rewards[#claimConfig.rewards] end
        if chosen then
            randomRewardName = chosen.itemName
            local rewardID   = chosen.itemID
            if rewardID and rewardID > 0 then
                if not player:changeItem(rewardID, chosen.amount, 0) then
                    local pX, pY = player:getPosX(), player:getPosY()
                    world:spawnItem(math.floor(pX / 32) * 32, math.floor(pY / 32) * 32, rewardID, chosen.amount)
                end
            end
        end
    end

    local rewardText = randomRewardName ~= "" and randomRewardName or "a reward"
    local message    = "`9You completed " .. claimConfig.name .. " `wand you got `2" .. rewardText .. "`w!"
    player:onConsoleMessage(message)
    player:onTalkBubble(player:getNetID(), message, 1)
    player:playAudio("level_up.wav")

    if player.onParticleEffect then
        player:onParticleEffect(46, player:getPosX() + 15, player:getPosY() + 15, 0, 0, 0)
    end

    player:sendVariant({"OnCountdownStart", 0, -1}, 0, player:getNetID())

    if finale_hunt_timers[userID] then
        timer.clear(finale_hunt_timers[userID])
        finale_hunt_timers[userID] = nil
    end
    finale_hunt_active[userID] = nil

    timer.setTimeout(5, function()
        finale_claimed[claimKey] = nil
        if player:isOnline() then
            player:enterWorld("", "", 1)
        end
    end)

    return true
end)

-- ============================================================================
-- CONFIG DIALOGS
-- ============================================================================

local function showClaimListDialog(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wFinale Claim Config``|left|8776|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`oSelect a claim block to edit rewards:``|\n"
    d = d .. "add_spacer|small|\n"
    local sorted = {}
    for tileID, cfg in pairs(FINALE_CLAIMS) do table.insert(sorted, { tileID = tileID, cfg = cfg }) end
    table.sort(sorted, function(a, b) return a.tileID < b.tileID end)
    for _, entry in ipairs(sorted) do
        d = d .. "add_button|edit_claim_" .. entry.tileID .. "|" .. entry.cfg.name .. " `o(" .. #entry.cfg.rewards .. " rewards)``|noflags|0|0|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|finale_claim_list|||\n"
    player:onDialogRequest(d)
end

local function showClaimEditDialog(player, tileID)
    local cfg = FINALE_CLAIMS[tileID]
    if not cfg then return end
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. cfg.name .. "``|left|" .. tileID .. "|\n"
    d = d .. "add_spacer|small|\n"
    local totalChance = 0
    for _, r in ipairs(cfg.rewards) do totalChance = totalChance + r.chance end
    d = d .. "add_textbox|`wTotal chance: `2" .. totalChance .. "%`o (max 100%)|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "text_scaling_string|aaaaaaaaaaaaaaaaaaaaa|\n"
    for i, r in ipairs(cfg.rewards) do
        d = d .. "add_button_with_icon|remove_" .. i .. "|`w" .. r.itemName .. "  `2x" .. r.amount .. "  `6%" .. r.chance .. "|staticBlueFrame|" .. (r.itemID or 2) .. "|\n"
    end
    d = d .. "add_button_with_icon||END_LIST|noflags|0||\n"
    d = d .. "add_spacer|small|\n"
    if #cfg.rewards < 12 then
        d = d .. "add_button|add_new|`2+ Add Item``|noflags|0|0|\n"
    end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|clear_all|`4Clear All Rewards``|noflags|0|0|\n"
    d = d .. "add_button|back_to_list|`wBack to List``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|finale_claim_edit_" .. tileID .. "|||\n"
    player:onDialogRequest(d)
end

local function showItemPickerDialog(player, tileID)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wSelect Item|left|2|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oPick an item from your inventory:|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|item_selected|Select Item|Pick from inventory|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back|`7Back|noflags|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|finale_item_picker_" .. tileID .. "|Close||\n"
    player:onDialogRequest(d)
end

local function showAmountDialog(player, tileID, itemID)
    local item = getItem(itemID)
    if not item then return end
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wAdd Reward|left|" .. itemID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oSelected: `5" .. item:getName() .. "|left|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_text_input|item_amount|Amount:|1|5|\n"
    d = d .. "add_text_input|item_chance|Chance (%):|10|3|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|confirm_amount|`2Add Reward|noflags|\n"
    d = d .. "add_button|btn_back|`7Back|noflags|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|finale_amount_" .. tileID .. "_" .. itemID .. "|Close||\n"
    player:onDialogRequest(d)
end

-- ============================================================================
-- DIALOG CALLBACK
-- ============================================================================

onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"]   or ""
    local btn = data["buttonClicked"] or ""

    if dn == "finale_claim_list" then
        local tileID = tonumber(btn:match("^edit_claim_(%d+)$"))
        if tileID then showClaimEditDialog(player, tileID) end
        return true
    end

    local editTileID = tonumber(dn:match("^finale_claim_edit_(%d+)$"))
    if editTileID then
        if btn == "back_to_list" then showClaimListDialog(player) ; return true end
        if btn == "add_new"      then showItemPickerDialog(player, editTileID) ; return true end
        local removeSlot = tonumber(btn:match("^remove_(%d+)$"))
        if removeSlot then
            local cfg = FINALE_CLAIMS[editTileID]
            if cfg and cfg.rewards[removeSlot] then
                table.remove(cfg.rewards, removeSlot)
                saveClaimRewards()
                player:onConsoleMessage("`4Removed reward from slot " .. removeSlot .. "!")
                showClaimEditDialog(player, editTileID)
            end
            return true
        end
        if btn == "clear_all" then
            local cfg = FINALE_CLAIMS[editTileID]
            if cfg then
                cfg.rewards = {}
                saveClaimRewards()
                player:onConsoleMessage("`4Cleared all rewards!``")
                player:playAudio("audio/bleep_fail.wav")
                showClaimEditDialog(player, editTileID)
            end
            return true
        end
        return true
    end

    local pickerTileID = tonumber(dn:match("^finale_item_picker_(%d+)$"))
    if pickerTileID then
        if btn == "btn_back" then showClaimEditDialog(player, pickerTileID) ; return true end
        local selectedItem = tonumber(data["item_selected"])
        if selectedItem and selectedItem > 0 then showAmountDialog(player, pickerTileID, selectedItem) end
        return true
    end

    local amountTileID, amountItemID = dn:match("^finale_amount_(%d+)_(%d+)$")
    amountTileID = tonumber(amountTileID)
    amountItemID = tonumber(amountItemID)
    if amountTileID and amountItemID then
        if btn == "btn_back"       then showClaimEditDialog(player, amountTileID) ; return true end
        if btn == "confirm_amount" then
            local amount = math.max(1, tonumber(data["item_amount"]) or 1)
            local chance = math.max(1, math.min(100, tonumber(data["item_chance"]) or 10))
            local cfg    = FINALE_CLAIMS[amountTileID]
            if cfg then
                local total = 0
                for _, r in ipairs(cfg.rewards) do total = total + r.chance end
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
                table.insert(cfg.rewards, {
                    itemName = item:getName(),
                    itemID   = amountItemID,
                    amount   = amount,
                    chance   = chance,
                })
                saveClaimRewards()
                player:onConsoleMessage("`2Added " .. item:getName() .. " x" .. amount .. " (" .. chance .. "%)!")
                player:playAudio("audio/success.wav")
                showClaimEditDialog(player, amountTileID)
            end
        end
        return true
    end

    return false
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then return false end
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    cmd = cmd:lower()

    if cmd == "finaleconfig" then
        if not player:hasRole(ADMIN_ROLE) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end
        showClaimListDialog(player)
        return true
    end

    if cmd == "finale" then
        if not player:hasRole(51) then
            player:onConsoleMessage("`4Unknown command.`o Enter `$/?`` for a list of valid commands.")
            return true
        end
        local removedAny = false
        for _, cfg in pairs(TICKET_CONFIG) do
            if player:getMod(cfg.mod_id) then
                player:removeMod(cfg.mod_id)
                removedAny = true
            end
        end
        if removedAny then player:playAudio("audio/success.wav") end
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

return M
