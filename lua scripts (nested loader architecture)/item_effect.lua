-- MODULE
-- item_effect.lua — /effectadmin: manage item effects (drops, gems, xp, range, tree growth, farm speed)

local M      = {}
local DB     = _G.DB
local Config = _G.Config

local SAVE_KEY    = "ITEM_EFFECTS_V2_4552"
local ROLE_ADMIN  = 51
local HEADER_ICON = 4802

_G.itemEffects = _G.itemEffects or {}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function getItemName(id)
    local item = getItem(id)
    return item and item:getName() or ("Item #" .. id)
end

local function isAuthorized(player)
    return player:hasRole(ROLE_ADMIN)
end

-- ============================================================================
-- NATIVE EFFECTS
-- ============================================================================
local function applyNative(itemID)
    local effects = _G.itemEffects[itemID]
    if not effects then return end
    local item = getItem(itemID)
    if not item then return end
    item:setEffects({
        extra_gems  = effects.extraGems  or 0,
        extra_xp    = effects.extraXP    or 0,
        one_hit     = effects.oneHit and 1 or 0,
        break_range = effects.breakRange or 0,
        build_range = effects.buildRange or 0,
    })
end

local function applyAllNative()
    for itemID, e in pairs(_G.itemEffects) do
        if e.extraGems or e.extraXP or e.oneHit or e.breakRange or e.buildRange then
            applyNative(itemID)
        end
    end
end

-- ============================================================================
-- SAVE / LOAD (custom JSON format — same as original)
-- ============================================================================
local function saveEffects()
    local json = "{"
    local first = true
    for itemID, effects in pairs(_G.itemEffects) do
        if not first then json = json .. "," end
        first = false
        json = json .. '"' .. itemID .. '":{'
        local parts = {}
        if effects.drops and #effects.drops > 0 then
            local dj = '"drops":['
            for i, d in ipairs(effects.drops) do
                if i > 1 then dj = dj .. "," end
                dj = dj .. string.format('{"dropID":%d,"amount":%d,"chance":%d}', d.dropID, d.amount, d.chance)
            end
            parts[#parts+1] = dj .. "]"
        end
        if effects.extraGems  then parts[#parts+1] = '"extraGems":'  .. effects.extraGems end
        if effects.extraXP    then parts[#parts+1] = '"extraXP":'    .. effects.extraXP end
        if effects.oneHit     then parts[#parts+1] = '"oneHit":true' end
        if effects.breakRange then parts[#parts+1] = '"breakRange":' .. effects.breakRange end
        if effects.buildRange then parts[#parts+1] = '"buildRange":' .. effects.buildRange end
        if effects.treeGrowth then parts[#parts+1] = '"treeGrowth":' .. effects.treeGrowth end
        if effects.farmSpeed  then parts[#parts+1] = '"farmSpeed":'  .. effects.farmSpeed end
        json = json .. table.concat(parts, ",") .. "}"
    end
    json = json .. "}"
    DB.saveStr(SAVE_KEY, json)
    applyAllNative()
end

local function loadEffects()
    local raw = DB.loadStr(SAVE_KEY)
    if not raw or raw == "" then return end
    for itemID, effectsStr in raw:gmatch('"(%d+)"%s*:%s*(%b{})') do
        local id = tonumber(itemID)
        _G.itemEffects[id] = {}
        local dropsStr = effectsStr:match('"drops"%s*:%s*(%b[])')
        if dropsStr then
            _G.itemEffects[id].drops = {}
            for dropData in dropsStr:gmatch('%b{}') do
                local dID  = tonumber(dropData:match('"dropID"%s*:%s*(%d+)'))
                local amt  = tonumber(dropData:match('"amount"%s*:%s*(%d+)'))
                local ch   = tonumber(dropData:match('"chance"%s*:%s*(%d+)'))
                if dID and amt and ch then
                    _G.itemEffects[id].drops[#_G.itemEffects[id].drops+1] = { dropID=dID, amount=amt, chance=ch }
                end
            end
        end
        local function readNum(key) return tonumber(effectsStr:match('"' .. key .. '"%s*:%s*(%d+)')) end
        _G.itemEffects[id].extraGems  = readNum("extraGems")
        _G.itemEffects[id].extraXP    = readNum("extraXP")
        if effectsStr:match('"oneHit"%s*:%s*true') then _G.itemEffects[id].oneHit = true end
        _G.itemEffects[id].breakRange = readNum("breakRange")
        _G.itemEffects[id].buildRange = readNum("buildRange")
        _G.itemEffects[id].treeGrowth = readNum("treeGrowth")
        _G.itemEffects[id].farmSpeed  = readNum("farmSpeed")
    end
    applyAllNative()
end

loadEffects()

-- ============================================================================
-- DIALOGS
-- ============================================================================
local function showMain(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wItem Effect Admin``|left|" .. HEADER_ICON .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|create_new|`2Create New Effect``|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    for itemID in pairs(_G.itemEffects) do
        d = d .. "add_label_with_icon|small|`w" .. getItemName(itemID) .. " (" .. itemID .. ")``|left|" .. itemID .. "|\n"
        d = d .. "add_button|edit_" .. itemID .. "|`6Edit``|noflags|0|0|\n"
        d = d .. "add_button|remove_" .. itemID .. "|`4Remove``|noflags|0|0|\n"
    end
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_main|Close|Cancel|\n"
    player:onDialogRequest(d)
end

local function showCreate(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wCreate Effect``|left|" .. HEADER_ICON .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|selected_item|`wPick Item``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back|`wBack``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_create|Close|Cancel|\n"
    player:onDialogRequest(d)
end

local function showEdit(player, itemID)
    local effects = _G.itemEffects[itemID] or {}
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. getItemName(itemID) .. "``|left|" .. itemID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_smalltext|`wAdd Effects:``|left|\n"
    d = d .. "add_button|add_drop_"    .. itemID .. "|`2+ Item Drop``|noflags|0|0|\n"
    d = d .. "add_button|add_gems_"    .. itemID .. "|`2+ Extra Gems``|noflags|0|0|\n"
    d = d .. "add_button|add_xp_"      .. itemID .. "|`2+ Extra XP``|noflags|0|0|\n"
    d = d .. "add_button|add_onehit_"  .. itemID .. "|`2+ One Hit Break``|noflags|0|0|\n"
    d = d .. "add_button|add_brange_"  .. itemID .. "|`2+ Break Range``|noflags|0|0|\n"
    d = d .. "add_button|add_burange_" .. itemID .. "|`2+ Build Range``|noflags|0|0|\n"
    d = d .. "add_button|add_tree_"    .. itemID .. "|`2+ Tree Growth``|noflags|0|0|\n"
    d = d .. "add_button|add_farm_"    .. itemID .. "|`2+ Farm Speed``|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    local hasEffects = false
    if effects.drops and #effects.drops > 0 then
        d = d .. "add_smalltext|`wItem Drops:``|left|\n"
        for i, drop in ipairs(effects.drops) do
            d = d .. "add_label_with_icon|small|`o" .. getItemName(drop.dropID) .. " x" .. drop.amount .. " (" .. drop.chance .. "%)``|left|" .. drop.dropID .. "|\n"
            d = d .. "add_button|del_drop_" .. itemID .. "_" .. i .. "|`4Remove``|noflags|0|0|\n"
        end
        hasEffects = true
    end
    if effects.extraGems  then d = d .. "add_smalltext|`wExtra Gems: `5+" .. effects.extraGems .. "%``|left|\n" d = d .. "add_button|del_gems_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.extraXP    then d = d .. "add_smalltext|`wExtra XP: `5+" .. effects.extraXP .. "%``|left|\n" d = d .. "add_button|del_xp_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.oneHit     then d = d .. "add_smalltext|`wOne Hit Break: `2Enabled``|left|\n" d = d .. "add_button|del_onehit_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.breakRange then d = d .. "add_smalltext|`wBreak Range: `5+" .. effects.breakRange .. "``|left|\n" d = d .. "add_button|del_brange_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.buildRange then d = d .. "add_smalltext|`wBuild Range: `5+" .. effects.buildRange .. "``|left|\n" d = d .. "add_button|del_burange_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.treeGrowth then d = d .. "add_smalltext|`wTree Growth: `5" .. effects.treeGrowth .. "s``|left|\n" d = d .. "add_button|del_tree_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if effects.farmSpeed  then d = d .. "add_smalltext|`wFarm Speed: `5+" .. effects.farmSpeed .. "%``|left|\n" d = d .. "add_button|del_farm_" .. itemID .. "|`4Remove``|noflags|0|0|\n" hasEffects = true end
    if not hasEffects then d = d .. "add_smalltext|`4No effects added yet``|left|\n" end
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|back_main|`wBack``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_edit_" .. itemID .. "|Close|Cancel|\n"
    player:onDialogRequest(d)
end

local function showAddDrop(player, itemID)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wAdd Drop``|left|" .. HEADER_ICON .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|drop_item|`wDrop Item``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_add_drop_" .. itemID .. "|Close|Cancel|\n"
    player:onDialogRequest(d)
end

local function showAmount(player, itemID, dropItemID)
    local item = getItem(dropItemID)
    if not item then return end
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wSet Amount & Chance``|left|" .. dropItemID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oSelected: `5" .. item:getName() .. "``|\n"
    d = d .. "add_text_input|drop_amount|Amount:|1|10|\n"
    d = d .. "add_text_input|drop_chance|Chance (%):|10|10|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|confirm_amount|`2Add Drop``|noflags|0|0|\n"
    d = d .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_amount_" .. itemID .. "_" .. dropItemID .. "|Close|Cancel|\n"
    player:onDialogRequest(d)
end

local function showValue(player, itemID, effectType, title, prompt, defaultVal)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. title .. "``|left|" .. HEADER_ICON .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_text_input|effect_value|" .. prompt .. ":|" .. defaultVal .. "|10|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|confirm_value|`2Add Effect``|noflags|0|0|\n"
    d = d .. "add_button|btn_back|`wCancel``|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|effectadmin_value_" .. itemID .. "_" .. effectType .. "|Close|Cancel|\n"
    player:onDialogRequest(d)
end

-- ============================================================================
-- COMMAND
-- ============================================================================
registerLuaCommand({ command = "effectadmin", roleRequired = ROLE_ADMIN, description = "Open item effect admin panel." })

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "effectadmin" then return false end
    if not isAuthorized(player) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end
    showMain(player)
    return true
end)

-- ============================================================================
-- DIALOG CALLBACKS
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"]   or ""
    local btn = data["buttonClicked"] or ""

    if dn == "effectadmin_main" then
        if not isAuthorized(player) then return false end
        if btn == "create_new" then showCreate(player); return true end
        local editID = tonumber(btn:match("^edit_(%d+)$"))
        if editID then showEdit(player, editID); return true end
        local removeID = tonumber(btn:match("^remove_(%d+)$"))
        if removeID then
            _G.itemEffects[removeID] = nil
            saveEffects()
            player:onConsoleMessage("`2Removed " .. getItemName(removeID) .. "``")
            showMain(player)
            return true
        end
        return true
    end

    if dn == "effectadmin_create" then
        if not isAuthorized(player) then return false end
        if btn == "btn_back" then showMain(player); return true end
        local sel = tonumber(data["selected_item"])
        if sel and sel > 0 then
            _G.itemEffects[sel] = _G.itemEffects[sel] or {}
            saveEffects()
            showEdit(player, sel)
            return true
        end
        return true
    end

    local editItemID = tonumber(dn:match("^effectadmin_edit_(%d+)$"))
    if editItemID then
        if not isAuthorized(player) then return false end
        if btn == "back_main" then showMain(player); return true end
        if btn:match("^add_drop_")    then showAddDrop(player, editItemID); return true end
        if btn:match("^add_gems_")    then showValue(player, editItemID, "gems",   "Extra Gems",  "Gem boost (%)", "50"); return true end
        if btn:match("^add_xp_")      then showValue(player, editItemID, "xp",     "Extra XP",    "XP boost (%)",  "50"); return true end
        if btn:match("^add_brange_")  then showValue(player, editItemID, "brange", "Break Range", "Range",          "1"); return true end
        if btn:match("^add_burange_") then showValue(player, editItemID, "burange","Build Range", "Range",          "1"); return true end
        if btn:match("^add_tree_")    then showValue(player, editItemID, "tree",   "Tree Growth", "Seconds",       "60"); return true end
        if btn:match("^add_farm_")    then showValue(player, editItemID, "farm",   "Farm Speed",  "Boost (%)",     "25"); return true end
        if btn:match("^add_onehit_")  then
            _G.itemEffects[editItemID].oneHit = true
            saveEffects()
            player:onConsoleMessage("`2Added One Hit Break!")
            showEdit(player, editItemID)
            return true
        end
        -- Delete effects
        local dropIdx = tonumber(btn:match("^del_drop_" .. editItemID .. "_(%d+)$"))
        if dropIdx then table.remove(_G.itemEffects[editItemID].drops, dropIdx); saveEffects(); showEdit(player, editItemID); return true end
        local delMap = { del_gems_="extraGems", del_xp_="extraXP", del_onehit_="oneHit", del_brange_="breakRange", del_burange_="buildRange", del_tree_="treeGrowth", del_farm_="farmSpeed" }
        for prefix, field in pairs(delMap) do
            if btn:match("^" .. prefix) then
                _G.itemEffects[editItemID][field] = nil
                saveEffects()
                showEdit(player, editItemID)
                return true
            end
        end
        return true
    end

    local addDropID = tonumber(dn:match("^effectadmin_add_drop_(%d+)$"))
    if addDropID then
        if not isAuthorized(player) then return false end
        if btn == "btn_back" then showEdit(player, addDropID); return true end
        local dropItem = tonumber(data["drop_item"])
        if dropItem and dropItem > 0 then showAmount(player, addDropID, dropItem); return true end
        return true
    end

    local amtItemID, dropItemID = dn:match("^effectadmin_amount_(%d+)_(%d+)$")
    amtItemID  = tonumber(amtItemID)
    dropItemID = tonumber(dropItemID)
    if amtItemID and dropItemID then
        if not isAuthorized(player) then return false end
        if btn == "btn_back" then showEdit(player, amtItemID); return true end
        if btn == "confirm_amount" then
            local amt = tonumber(data["drop_amount"]) or 1
            local ch  = tonumber(data["drop_chance"]) or 10
            _G.itemEffects[amtItemID].drops = _G.itemEffects[amtItemID].drops or {}
            _G.itemEffects[amtItemID].drops[#_G.itemEffects[amtItemID].drops+1] = { dropID=dropItemID, amount=amt, chance=ch }
            saveEffects()
            player:onConsoleMessage("`2Added drop!")
            showEdit(player, amtItemID)
            return true
        end
        return true
    end

    local valItemID, effectType = dn:match("^effectadmin_value_(%d+)_(.+)$")
    valItemID = tonumber(valItemID)
    if valItemID and effectType then
        if not isAuthorized(player) then return false end
        if btn == "btn_back" then showEdit(player, valItemID); return true end
        if btn == "confirm_value" then
            local val = tonumber(data["effect_value"])
            if not val then player:onConsoleMessage("`4Invalid value!"); return true end
            local fieldMap = { gems="extraGems", xp="extraXP", brange="breakRange", burange="buildRange", tree="treeGrowth", farm="farmSpeed" }
            local field = fieldMap[effectType]
            if field then _G.itemEffects[valItemID][field] = val end
            saveEffects()
            player:onConsoleMessage("`2Added effect!")
            showEdit(player, valItemID)
            return true
        end
        return true
    end

    return false
end)

-- ============================================================================
-- FARM SPEED INTEGRATION
-- ============================================================================
local function calcFarmSpeedBoost(player)
    local total = 0
    for slot = 0, 16 do
        local itemID = player:getClothingItemID(slot)
        if itemID and _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then
            total = total + _G.itemEffects[itemID].farmSpeed
        end
    end
    return total
end

_G.getItemEffectFarmSpeedBoost = function(userID)
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == userID then return calcFarmSpeedBoost(p) end
    end
    return 0
end

local function applyFarmSpeed(player)
    local boost = calcFarmSpeedBoost(player)
    if boost > 0 then
        local delay = math.max(20, math.floor(200 * (1 - boost / 100)))
        player:setCustomAutofarmDelay(delay)
    else
        player:setCustomAutofarmDelay(200)
    end
end

onPlayerEquippedClothingCallback(function(player, itemID, slot)
    if _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then applyFarmSpeed(player) end
end)

onPlayerUnequippedClothingCallback(function(player, itemID, slot)
    if _G.itemEffects[itemID] and _G.itemEffects[itemID].farmSpeed then applyFarmSpeed(player) end
end)

onPlayerLoginCallback(function(player)
    applyFarmSpeed(player)
end)

-- ============================================================================
-- TREE GROWTH + DROP EFFECTS
-- ============================================================================
onTilePlaceCallback(function(world, player, tile, placingID)
    for slot = 0, 16 do
        local itemID = player:getClothingItemID(slot)
        if itemID and _G.itemEffects[itemID] and _G.itemEffects[itemID].treeGrowth then
            tile:setGrowTime(_G.itemEffects[itemID].treeGrowth)
            break
        end
    end
    return false
end)

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

return M
