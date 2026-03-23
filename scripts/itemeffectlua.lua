print("(Loaded) Item Effect System V2.0")

local CONFIG = {
    ADMIN_ROLE = 51,
    SERVER_ID = 4552,
    SAVE_KEY = "ITEM_EFFECTS_V2_",
    HEADER_ICON = 4802,
}

_G.itemEffects = _G.itemEffects or {}

-- ════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ════════════════════════════════════════════════════════════════════

local function table_count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function getItemName(itemID)
    local item = getItem(itemID)
    return item and item:getName() or ("Item #" .. itemID)
end

local function isAuthorized(player)
    if getServerID() ~= CONFIG.SERVER_ID then
        player:onConsoleMessage("`4Error: Locked to specific server ID.``")
        return false
    end
    return player:hasRole(CONFIG.ADMIN_ROLE)
end

-- ════════════════════════════════════════════════════════════════════
-- NATIVE EFFECTS APPLICATION
-- ════════════════════════════════════════════════════════════════════

local function applyNativeEffects(itemID)
    local effects = _G.itemEffects[itemID]
    if not effects then return end
    
    local item = getItem(itemID)
    if not item then 
        print("[ItemEffect] WARNING: Item " .. itemID .. " not found")
        return 
    end
    
    -- Apply native effects
    item:setEffects({
        extra_gems = effects.extraGems or 0,  -- This is percentage (%)
        extra_xp = effects.extraXP or 0,      -- This is percentage (%)
        one_hit = effects.oneHit and 1 or 0,
        break_range = effects.breakRange or 0,
        build_range = effects.buildRange or 0,
    })
    
end

local function applyAllNativeEffects()
    for itemID, effects in pairs(_G.itemEffects) do
        if effects.extraGems or effects.extraXP or effects.oneHit or
           effects.breakRange or effects.buildRange then
            applyNativeEffects(itemID)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════
-- SAVE / LOAD
-- ════════════════════════════════════════════════════════════════════

local function saveEffects()
    local json = "{"
    local first = true
    
    for itemID, effects in pairs(_G.itemEffects) do
        if not first then json = json .. "," end
        first = false
        
        json = json .. '"' .. itemID .. '":{'
        local hasData = false
        
        if effects.drops and #effects.drops > 0 then
            json = json .. '"drops":['
            for i, drop in ipairs(effects.drops) do
                if i > 1 then json = json .. "," end
                json = json .. string.format('{"dropID":%d,"amount":%d,"chance":%d}', drop.dropID, drop.amount, drop.chance)
            end
            json = json .. '],'
            hasData = true
        end
        
        if effects.extraGems then json = json .. '"extraGems":' .. effects.extraGems .. ',' hasData = true end
        if effects.extraXP then json = json .. '"extraXP":' .. effects.extraXP .. ',' hasData = true end
        if effects.oneHit then json = json .. '"oneHit":true,' hasData = true end
        if effects.breakRange then json = json .. '"breakRange":' .. effects.breakRange .. ',' hasData = true end
        if effects.buildRange then json = json .. '"buildRange":' .. effects.buildRange .. ',' hasData = true end
        if effects.treeGrowth then json = json .. '"treeGrowth":' .. effects.treeGrowth .. ',' hasData = true end
        if effects.farmSpeed then json = json .. '"farmSpeed":' .. effects.farmSpeed .. ',' hasData = true end
        
        if json:sub(-1) == "," then json = json:sub(1, -2) end
        json = json .. '}'
    end
    
    json = json .. "}"
    saveStringToServer(CONFIG.SAVE_KEY .. CONFIG.SERVER_ID, json)
    
    -- Apply native effects after saving
    applyAllNativeEffects()
    
    print("[ItemEffect] Saved " .. table_count(_G.itemEffects) .. " items")
end

local function loadEffects()
    local raw = loadStringFromServer(CONFIG.SAVE_KEY .. CONFIG.SERVER_ID)
    if not raw or raw == "" then
        print("[ItemEffect] No saved effects")
        return
    end
    
    for itemID, effectsStr in raw:gmatch('"(%d+)"%s*:%s*(%b{})') do
        local itemIDNum = tonumber(itemID)
        _G.itemEffects[itemIDNum] = {}
        
        local dropsStr = effectsStr:match('"drops"%s*:%s*(%b[])')
        if dropsStr then
            _G.itemEffects[itemIDNum].drops = {}
            for dropData in dropsStr:gmatch('%b{}') do
                local dropID = tonumber(dropData:match('"dropID"%s*:%s*(%d+)'))
                local amount = tonumber(dropData:match('"amount"%s*:%s*(%d+)'))
                local chance = tonumber(dropData:match('"chance"%s*:%s*(%d+)'))
                if dropID and amount and chance then
                    table.insert(_G.itemEffects[itemIDNum].drops, {dropID = dropID, amount = amount, chance = chance})
                end
            end
        end
        
        local extraGems = tonumber(effectsStr:match('"extraGems"%s*:%s*(%d+)'))
        if extraGems then _G.itemEffects[itemIDNum].extraGems = extraGems end
        
        local extraXP = tonumber(effectsStr:match('"extraXP"%s*:%s*(%d+)'))
        if extraXP then _G.itemEffects[itemIDNum].extraXP = extraXP end
        
        if effectsStr:match('"oneHit"%s*:%s*true') then _G.itemEffects[itemIDNum].oneHit = true end
        
        local breakRange = tonumber(effectsStr:match('"breakRange"%s*:%s*(%d+)'))
        if breakRange then _G.itemEffects[itemIDNum].breakRange = breakRange end
        
        local buildRange = tonumber(effectsStr:match('"buildRange"%s*:%s*(%d+)'))
        if buildRange then _G.itemEffects[itemIDNum].buildRange = buildRange end
        
        local treeGrowth = tonumber(effectsStr:match('"treeGrowth"%s*:%s*(%d+)'))
        if treeGrowth then _G.itemEffects[itemIDNum].treeGrowth = treeGrowth end
        
        local farmSpeed = tonumber(effectsStr:match('"farmSpeed"%s*:%s*(%d+)'))
        if farmSpeed then _G.itemEffects[itemIDNum].farmSpeed = farmSpeed end
    end
    
    -- Apply native effects after loading
    applyAllNativeEffects()
    
    print("[ItemEffect] Loaded effects")
end

loadEffects()

-- ════════════════════════════════════════════════════════════════════
-- ADMIN MENU DIALOGS
-- ════════════════════════════════════════════════════════════════════

local function showMainAdminMenu(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wItem Effect Admin``|left|" .. CONFIG.HEADER_ICON .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|create_new|`2Create New Effect``|noflags|0|0|\n"
    dialog = dialog .. "add_spacer|small|\n"
    
    if next(_G.itemEffects) then
        for itemID in pairs(_G.itemEffects) do
            dialog = dialog .. "add_label_with_icon|small|`w" .. getItemName(itemID) .. " (" .. itemID .. ")``|left|" .. itemID .. "|\n"
            dialog = dialog .. "add_button|edit_" .. itemID .. "|`6Edit``|noflags|0|0|\n"
            dialog = dialog .. "add_button|remove_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        end
    end
    
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_main|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

local function showCreateMenu(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wCreate Effect``|left|" .. CONFIG.HEADER_ICON .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_item_picker|selected_item|`wPick Item``|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|btn_back|`wBack``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_create|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

local function showEditMenu(player, itemID)
    local effects = _G.itemEffects[itemID] or {}
    
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`w" .. getItemName(itemID) .. "``|left|" .. itemID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`wAdd Effects:``|left|\n"
    dialog = dialog .. "add_button|add_drop_" .. itemID .. "|`2+ Item Drop``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_gems_" .. itemID .. "|`2+ Extra Gems``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_xp_" .. itemID .. "|`2+ Extra XP``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_onehit_" .. itemID .. "|`2+ One Hit Break``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_brange_" .. itemID .. "|`2+ Break Range``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_burange_" .. itemID .. "|`2+ Build Range``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_tree_" .. itemID .. "|`2+ Tree Growth``|noflags|0|0|\n"
    dialog = dialog .. "add_button|add_farm_" .. itemID .. "|`2+ Farm Speed``|noflags|0|0|\n"
    dialog = dialog .. "add_spacer|small|\n"
    
    -- Show current effects
    local hasEffects = false
    
    if effects.drops and #effects.drops > 0 then
        dialog = dialog .. "add_smalltext|`wItem Drops:``|left|\n"
        for i, drop in ipairs(effects.drops) do
            dialog = dialog .. "add_label_with_icon|small|`o" .. getItemName(drop.dropID) .. " x" .. drop.amount .. " (" .. drop.chance .. "%)``|left|" .. drop.dropID .. "|\n"
            dialog = dialog .. "add_button|del_drop_" .. itemID .. "_" .. i .. "|`4Remove``|noflags|0|0|\n"
        end
        hasEffects = true
    end
    
    if effects.extraGems then
        dialog = dialog .. "add_smalltext|`wExtra Gems: `5+" .. effects.extraGems .. "%``|left|\n"
        dialog = dialog .. "add_button|del_gems_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.extraXP then
        dialog = dialog .. "add_smalltext|`wExtra XP: `5+" .. effects.extraXP .. "%``|left|\n"
        dialog = dialog .. "add_button|del_xp_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.oneHit then
        dialog = dialog .. "add_smalltext|`wOne Hit Break: `2Enabled``|left|\n"
        dialog = dialog .. "add_button|del_onehit_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.breakRange then
        dialog = dialog .. "add_smalltext|`wBreak Range: `5+" .. effects.breakRange .. "``|left|\n"
        dialog = dialog .. "add_button|del_brange_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.buildRange then
        dialog = dialog .. "add_smalltext|`wBuild Range: `5+" .. effects.buildRange .. "``|left|\n"
        dialog = dialog .. "add_button|del_burange_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.treeGrowth then
        dialog = dialog .. "add_smalltext|`wTree Growth: `5" .. effects.treeGrowth .. "s``|left|\n"
        dialog = dialog .. "add_button|del_tree_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if effects.farmSpeed then
        dialog = dialog .. "add_smalltext|`wFarm Speed: `5+" .. effects.farmSpeed .. "%``|left|\n"
        dialog = dialog .. "add_button|del_farm_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
        hasEffects = true
    end
    
    if not hasEffects then
        dialog = dialog .. "add_smalltext|`4No effects added yet``|left|\n"
    end
    
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|back_main|`wBack``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_edit_" .. itemID .. "|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

local function showAddDropDialog(player, itemID)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wAdd Drop``|left|" .. CONFIG.HEADER_ICON .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oStep 1: Select drop item from inventory``|\n"
    dialog = dialog .. "add_item_picker|drop_item|`wDrop Item``|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_add_drop_" .. itemID .. "|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

local function showAmountDialog(player, itemID, dropItemID)
    local item = getItem(dropItemID)
    if not item then return end
    
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wSet Amount & Chance``|left|" .. dropItemID .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_textbox|`oSelected: `5" .. item:getName() .. "``|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_text_input|drop_amount|Amount:|1|10|\n"
    dialog = dialog .. "add_text_input|drop_chance|Chance (%):|10|10|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|confirm_amount|`2Add Drop``|noflags|0|0|\n"
    dialog = dialog .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_amount_" .. itemID .. "_" .. dropItemID .. "|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

local function showValueDialog(player, itemID, effectType, title, prompt, defaultVal)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`w" .. title .. "``|left|" .. CONFIG.HEADER_ICON .. "|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_text_input|effect_value|" .. prompt .. ":|" .. defaultVal .. "|10|\n"
    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_button|confirm_value|`2Add Effect``|noflags|0|0|\n"
    dialog = dialog .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|effectadmin_value_" .. itemID .. "_" .. effectType .. "|Close|Cancel|\n"
    
    player:onDialogRequest(dialog)
end

registerLuaCommand({
    command = "effectadmin",
    roleRequired = 51,
    description = "Open item effect admin panel"
})

onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"] or ""
    local buttonClicked = data["buttonClicked"] or ""
    
    if dialogName == "effectadmin_main" then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "create_new" then
            showCreateMenu(player)
            return true
        end
        
        local editID = tonumber(buttonClicked:match("^edit_(%d+)$"))
        if editID then
            showEditMenu(player, editID)
            return true
        end
        
        local removeID = tonumber(buttonClicked:match("^remove_(%d+)$"))
        if removeID then
            _G.itemEffects[removeID] = nil
            saveEffects()
            player:onConsoleMessage("`2Removed " .. getItemName(removeID) .. "``")
            showMainAdminMenu(player)
            return true
        end
        
        return true
    end
    
    if dialogName == "effectadmin_create" then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "btn_back" then
            showMainAdminMenu(player)
            return true
        end
        
        local selectedItem = tonumber(data["selected_item"])
        if selectedItem and selectedItem > 0 then
            _G.itemEffects[selectedItem] = _G.itemEffects[selectedItem] or {}
            saveEffects()
            showEditMenu(player, selectedItem)
            return true
        end
        
        return true
    end
    
    local editItemID = tonumber(dialogName:match("^effectadmin_edit_(%d+)$"))
    if editItemID then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "back_main" then
            showMainAdminMenu(player)
            return true
        end
        
        if buttonClicked:match("^add_drop_") then
            showAddDropDialog(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^add_gems_") then
            showValueDialog(player, editItemID, "gems", "Extra Gems", "Gem boost (%)", "50")
            return true
        end
        
        if buttonClicked:match("^add_xp_") then
            showValueDialog(player, editItemID, "xp", "Extra XP", "XP boost (%)", "50")
            return true
        end
        
        if buttonClicked:match("^add_onehit_") then
            _G.itemEffects[editItemID].oneHit = true
            saveEffects()
            player:onConsoleMessage("`2Added One Hit Break!``")
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^add_brange_") then
            showValueDialog(player, editItemID, "brange", "Break Range", "Range increase", "1")
            return true
        end
        
        if buttonClicked:match("^add_burange_") then
            showValueDialog(player, editItemID, "burange", "Build Range", "Range increase", "1")
            return true
        end
        
        if buttonClicked:match("^add_tree_") then
            showValueDialog(player, editItemID, "tree", "Tree Growth", "Growth time (seconds)", "60")
            return true
        end
        
        if buttonClicked:match("^add_farm_") then
            showValueDialog(player, editItemID, "farm", "Farm Speed", "Speed boost (%)", "25")
            return true
        end
        
        -- Delete buttons
        local dropIndex = tonumber(buttonClicked:match("^del_drop_" .. editItemID .. "_(%d+)$"))
        if dropIndex then
            table.remove(_G.itemEffects[editItemID].drops, dropIndex)
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_gems_") then
            _G.itemEffects[editItemID].extraGems = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_xp_") then
            _G.itemEffects[editItemID].extraXP = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_onehit_") then
            _G.itemEffects[editItemID].oneHit = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_brange_") then
            _G.itemEffects[editItemID].breakRange = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_burange_") then
            _G.itemEffects[editItemID].buildRange = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_tree_") then
            _G.itemEffects[editItemID].treeGrowth = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        if buttonClicked:match("^del_farm_") then
            _G.itemEffects[editItemID].farmSpeed = nil
            saveEffects()
            showEditMenu(player, editItemID)
            return true
        end
        
        return true
    end
    
    local addDropItemID = tonumber(dialogName:match("^effectadmin_add_drop_(%d+)$"))
    if addDropItemID then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "btn_back" then
            showEditMenu(player, addDropItemID)
            return true
        end
        
        -- When item is selected from picker, show amount dialog
        local dropItem = tonumber(data["drop_item"])
        if dropItem and dropItem > 0 then
            showAmountDialog(player, addDropItemID, dropItem)
            return true
        end
        
        -- Stay in dialog if nothing selected
        return true
    end
    
    -- Handle amount/chance confirmation
    local amountItemID, dropItemID = dialogName:match("^effectadmin_amount_(%d+)_(%d+)$")
    amountItemID = tonumber(amountItemID)
    dropItemID = tonumber(dropItemID)
    
    if amountItemID and dropItemID then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "btn_back" then
            showEditMenu(player, amountItemID)
            return true
        end
        
        if buttonClicked == "confirm_amount" then
            local amount = tonumber(data["drop_amount"]) or 1
            local chance = tonumber(data["drop_chance"]) or 10
            
            _G.itemEffects[amountItemID].drops = _G.itemEffects[amountItemID].drops or {}
            table.insert(_G.itemEffects[amountItemID].drops, {dropID = dropItemID, amount = amount, chance = chance})
            
            saveEffects()
            player:onConsoleMessage("`2Added drop!``")
            showEditMenu(player, amountItemID)
            return true
        end
        
        return true
    end
    
    -- Handle value confirmation (gems, xp, ranges, etc)
    local valueItemID, effectType = dialogName:match("^effectadmin_value_(%d+)_(.+)$")
    valueItemID = tonumber(valueItemID)
    
    if valueItemID and effectType then
        if not isAuthorized(player) then return false end
        
        if buttonClicked == "btn_back" then
            showEditMenu(player, valueItemID)
            return true
        end
        
        if buttonClicked == "confirm_value" then
            local value = tonumber(data["effect_value"])
            if not value then
                player:onConsoleMessage("`4Invalid value!``")
                return true
            end
            
            if effectType == "gems" then
                _G.itemEffects[valueItemID].extraGems = value
            elseif effectType == "xp" then
                _G.itemEffects[valueItemID].extraXP = value
            elseif effectType == "brange" then
                _G.itemEffects[valueItemID].breakRange = value
            elseif effectType == "burange" then
                _G.itemEffects[valueItemID].buildRange = value
            elseif effectType == "tree" then
                _G.itemEffects[valueItemID].treeGrowth = value
            elseif effectType == "farm" then
                _G.itemEffects[valueItemID].farmSpeed = value
            end
            
            saveEffects()
            player:onConsoleMessage("`2Added effect!``")
            showEditMenu(player, valueItemID)
            return true
        end
        
        return true
    end
    
    return false
end)

onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then return false end
    
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    
    cmd = cmd:lower()
    
    if cmd == "effectadmin" then
        if not isAuthorized(player) then
            player:onConsoleMessage("`4Unknown command.``")
            return true
        end
        
        showMainAdminMenu(player)
        return true
    end
    
    return false
end)

print(">> Item Effect System V2.0 - Type /effectadmin")
print(">> Native Effects: Extra Gems, Extra XP, One Hit, Break Range, Build Range")
print(">> Custom Effects: Item Drops, Tree Growth, Farm Speed")

-- ════════════════════════════════════════════════════════════════════
-- FARM SPEED - HELPER FUNCTION
-- ════════════════════════════════════════════════════════════════════

local function calculateFarmSpeedBoost(player)
    local totalBoost = 0
    for slot = 0, 16 do
        local itemID = player:getClothingItemID(slot)
        if itemID and _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then
            totalBoost = totalBoost + _G.itemEffects[itemID].farmSpeed
        end
    end
    return totalBoost
end

-- ════════════════════════════════════════════════════════════════════
-- GLOBAL EXPORT FOR EXTERNAL BOOST SYSTEM
-- ════════════════════════════════════════════════════════════════════

-- Export function for external autofarm boost system to query our farm speed
_G.getItemEffectFarmSpeedBoost = function(userID)
    local player = nil
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == userID then
            player = p
            break
        end
    end
    if not player then return 0 end
    return calculateFarmSpeedBoost(player)
end

print("[ItemEffect] Global function '_G.getItemEffectFarmSpeedBoost' exported!")
print("[ItemEffect] Test: _G.getItemEffectFarmSpeedBoost = " .. tostring(_G.getItemEffectFarmSpeedBoost))

-- ════════════════════════════════════════════════════════════════════
-- FARM SPEED - INTEGRATION WITH AUTOFARM BOOST SYSTEM
-- ════════════════════════════════════════════════════════════════════

local function applyFarmSpeed(player)
    local boost = calculateFarmSpeedBoost(player)
    
    -- Check if external boost system exists
    if _G.isAutofarmBoostSystemActive and _G.isAutofarmBoostSystemActive() then
        -- External system handles delay calculation via _G.getItemEffectFarmSpeedBoost
        if _G.addItemEffectBoost then
            _G.addItemEffectBoost(player:getUserID(), boost)
        end
    else
        -- Standalone mode - apply directly
        if boost > 0 then
            local baseDelay = 200
            local reducedDelay = math.floor(baseDelay * (1 - (boost / 100)))
            if reducedDelay < 20 then reducedDelay = 20 end
            player:setCustomAutofarmDelay(reducedDelay)
        else
            player:setCustomAutofarmDelay(200)
        end
    end
end

onPlayerEquippedClothingCallback(function(player, itemID, slot)
    if _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then
        applyFarmSpeed(player)
    end
end)

onPlayerUnequippedClothingCallback(function(player, itemID, slot)
    if _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then
        applyFarmSpeed(player)
    end
end)

onPlayerLoginCallback(function(player)
    applyFarmSpeed(player)
end)

-- ════════════════════════════════════════════════════════════════════
-- TREE GROWTH - TILE PLACE HANDLER
-- ════════════════════════════════════════════════════════════════════

onTilePlaceCallback(function(world, player, tile, placingID)
    -- Check if player is wearing item with tree growth effect
    for slot = 0, 16 do
        local itemID = player:getClothingItemID(slot)
        if itemID and _G.itemEffects[itemID] and _G.itemEffects[itemID].treeGrowth then
            local growthTime = _G.itemEffects[itemID].treeGrowth
            
            -- Set grow time for seeds/trees
            tile:setGrowTime(growthTime)
            break
        end
    end
    
    return false
end)

-- ════════════════════════════════════════════════════════════════════
-- TILE BREAK - DROP EFFECTS
-- ════════════════════════════════════════════════════════════════════

onTileBreakCallback(function(world, player, tile)
    for slot = 0, 16 do
        local itemID = player:getClothingItemID(slot)
        if itemID and _G.itemEffects[itemID] then
            local effects = _G.itemEffects[itemID]
            
            if effects.drops then
                for _, drop in ipairs(effects.drops) do
                    if math.random() * 100 <= drop.chance then
                        for i = 1, drop.amount do
                            world:spawnItem(tile:getPosX(), tile:getPosY(), drop.dropID, 1)
                        end
                        player:onTextOverlay("`2BONUS: `w" .. getItemName(drop.dropID))
                    end
                end
            end
        end
    end
    
    return false
end)