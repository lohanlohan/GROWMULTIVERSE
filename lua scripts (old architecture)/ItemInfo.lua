-- Item Info Editor with In-Game Manager

local ROLE_ADMIN = 51
local DB_KEY = "ITEM_INFOS_V3"

local insert = table.insert
local concat = table.concat
local format = string.format
local sub = string.sub
local match = string.match
local find = string.find
local tonum = tonumber

local function safeStr(val)
    if val == nil then return "" end
    return tostring(val)
end

local infoCache = {}
local infoSessions = {}
local SESSION_KEY = "ITEM_INFO_SESSION_"

-- JSON encode/decode (manual, no pcall needed)
local function escJson(s)
    s = tostring(s or "")
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return s
end

local function encodeEntry(e)
    if e.type == "spacer" then return '{"type":"spacer"}' end
    if e.type == "break"  then return '{"type":"break"}'  end
    local parts = {'"type":"text"', '"text":"'..escJson(e.text or "")..'"'}
    if e.big    ~= nil then parts[#parts+1] = '"big":'..(e.big and "true" or "false") end
    if e.iconID ~= nil then parts[#parts+1] = '"iconID":'..tostring(e.iconID)  end
    if e.amount ~= nil then parts[#parts+1] = '"amount":'..tostring(e.amount)  end
    return "{"..table.concat(parts, ",").."}"
end

local function encodeList(lst)
    if not lst or #lst == 0 then return "[]" end
    local parts = {}
    for _, e in ipairs(lst) do parts[#parts+1] = encodeEntry(e) end
    return "["..table.concat(parts, ",").."]"
end

local function decodeList(raw)
    if not raw or raw == "" or raw == "[]" then return {} end
    local lst = {}
    for obj in raw:gmatch("%b{}") do
        local t   = obj:match('"type"%s*:%s*"(%a+)"')
        local txt = obj:match('"text"%s*:%s*"(.-)"')
        if txt then txt = txt:gsub('\\"','"'):gsub('\\n','\n') end
        local big    = obj:match('"big"%s*:%s*(true)') ~= nil
        local iconID = tonumber(obj:match('"iconID"%s*:%s*(%d+)'))
        local amount = tonumber(obj:match('"amount"%s*:%s*(%d+)'))
        if t == "spacer" then
            lst[#lst+1] = {type="spacer"}
        elseif t == "break" then
            lst[#lst+1] = {type="break"}
        elseif t == "text" or txt then
            lst[#lst+1] = {type="text", text=txt or "", big=big, iconID=iconID, amount=amount}
        end
    end
    return lst
end

local function saveInfoDB()
    local parts = {}
    for key, v in pairs(infoCache) do
        local entry = string.format(
            '"%s":{"bgColor":"%s","borderColor":"%s","useDefaultDesc":%s,"customPropsText":"%s","descList":%s,"specialList":%s,"bonusList":%s}',
            escJson(key),
            escJson(v.bgColor or ""),
            escJson(v.borderColor or ""),
            (v.useDefaultDesc == false) and "false" or "true",
            escJson(v.customPropsText or ""),
            encodeList(v.descList),
            encodeList(v.specialList),
            encodeList(v.bonusList)
        )
        parts[#parts+1] = entry
    end
    saveStringToServer(DB_KEY, "{"..table.concat(parts, ",").."}")
end

local function loadInfoDB()
    local raw = loadStringFromServer(DB_KEY)
    infoCache = {}
    if not raw or raw == "" then return end
    for key, body in raw:gmatch('"(%d+)"%s*:%s*(%b{})') do
        local bg     = body:match('"bgColor"%s*:%s*"(.-)"')            or ""
        local border = body:match('"borderColor"%s*:%s*"(.-)"')        or ""
        local useD   = body:match('"useDefaultDesc"%s*:%s*(true)') ~= nil
        local cProps = body:match('"customPropsText"%s*:%s*"(.-)"')    or ""
        local descRaw    = body:match('"descList"%s*:%s*(%b[])')    or "[]"
        local specialRaw = body:match('"specialList"%s*:%s*(%b[])') or "[]"
        local bonusRaw   = body:match('"bonusList"%s*:%s*(%b[])')   or "[]"
        infoCache[key] = {
            bgColor         = bg,
            borderColor     = border,
            useDefaultDesc  = useD,
            customPropsText = cProps,
            descList        = decodeList(descRaw),
            specialList     = decodeList(specialRaw),
            bonusList       = decodeList(bonusRaw),
        }
    end
end
loadInfoDB()

local DEFAULT_PROPS = "This item can't be spliced.\n`1This item never drops any seeds.``\n`1This item cannot be dropped or traded.``"

local function getItemName(itemID)
    local item = getItem(itemID)
    return item and item:getName() or "Unknown Item"
end

local function getSession(player)
    local uid = player:getUserID()
    if not infoSessions[uid] then
        infoSessions[uid] = {
            targetID = nil,
            bgColor = "",
            borderColor = "",
            useDefaultDesc = true,
            customPropsText = "",
            descList = {},
            specialList = {},
            bonusList = {},
            currentEdit = nil,
            currentMode = nil,
            currentIndex = nil
        }
    end
    return infoSessions[uid]
end

-- Command registration
registerLuaCommand({
    command = "editinfo",
    roleRequired = ROLE_ADMIN,
    description = "Edit item information"
})

-- UI Functions
local function showItemPicker(player)
    local dialog = {}
    
    insert(dialog, "disable_resize|\n")
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, "add_label_with_icon|big|`wSelect Item to Edit|left|242|\n")
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, "add_textbox|`oSelect an item from your inventory to edit its information.|\n")
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, "add_item_picker|info_pick_item|`wPick Item|`oClick to select from inventory|\n")
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, "add_button|info_cancel|`wCancel|noflags|\n")
    insert(dialog, "add_quick_exit|\n")
    insert(dialog, "end_dialog|info_item_picker|||\n")
    
    player:onDialogRequest(concat(dialog))
end

local function showMainMenu(player)
    local sess = getSession(player)
    local itemID = sess.targetID
    local itemName = getItemName(itemID)
    
    local dialog = {}
    
    insert(dialog, "disable_resize|\n")
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, format("add_label_with_icon|big|`wInfo Editor: %s|left|%d|\n", itemName, itemID))
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_spacer|small|\n")
    
    -- Colors
    insert(dialog, "add_label|small|`wBackground & Border Colors:`w|\n")
    insert(dialog, format("add_text_input|info_bg_color|Background Color (r,g,b,a):|%s|30|\n", safeStr(sess.bgColor)))
    insert(dialog, format("add_text_input|info_border_color|Border Color (r,g,b,a):|%s|30|\n", safeStr(sess.borderColor)))
    insert(dialog, "add_spacer|small|\n")
    
    -- Properties
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_label|small|`wProperties (Item Description):`w|\n")
    local useDefault = (sess.useDefaultDesc ~= false)
    insert(dialog, string.format("add_checkbox|info_use_default_desc|`oUse item default description|%d|\n", useDefault and 1 or 0))
    if not useDefault then
        insert(dialog, string.format("add_text_input|info_custom_props|Custom Text:|%s|150|\n", safeStr(sess.customPropsText)))
    else
        insert(dialog, "add_smalltext|`8Using the item built-in description.|\n")
    end
    insert(dialog, "add_spacer|small|\n")

    -- Description Editor
    insert(dialog, "add_label|small|`wDescription:`w|\n")
    local descCount = sess.descList and #sess.descList or 0
    insert(dialog, format("add_textbox|%d line(s) configured| \n", descCount))
    insert(dialog, "add_button|info_edit_desc|`wEdit Description|noflags|\n")
    insert(dialog, "add_spacer|small|\n")
    
    -- Special Effect Editor
    insert(dialog, "add_label|small|`wSpecial Effect:`w|\n")
    local specialCount = sess.specialList and #sess.specialList or 0
    insert(dialog, format("add_textbox|%d effect(s) configured| \n", specialCount))
    insert(dialog, "add_button|info_edit_special|`wEdit Special Effect|noflags|\n")
    insert(dialog, "add_spacer|small|\n")
    
    -- Bonus Drop Editor
    insert(dialog, "add_label|small|`wBonus Drop:`w|\n")
    local bonusCount = sess.bonusList and #sess.bonusList or 0
    insert(dialog, format("add_textbox|%d drop(s) configured| \n", bonusCount))
    insert(dialog, "add_button|info_edit_bonus|`wEdit Bonus Drop|noflags|\n")
    insert(dialog, "add_spacer|small|\n")
    
    -- Save/Delete buttons
    insert(dialog, "add_button|info_save|`2SAVE CONFIGURATION|noflags|\n")
    insert(dialog, "add_button|info_delete|`4DELETE CONFIGURATION|noflags|\n")
    insert(dialog, "add_button|info_back_to_picker|`wSelect Another Item|noflags|\n")
    insert(dialog, "add_quick_exit|\n")
    insert(dialog, "end_dialog|info_main_menu|||\n")
    
    player:onDialogRequest(concat(dialog))
end

local function showListEditor(player, mode)
    local sess = getSession(player)
    local listData = {}
    local title = ""
    local addTextLabel = ""
    
    if mode == "desc" then
        listData = sess.descList
        title = "Description Editor"
        addTextLabel = "Add Text Line"
    elseif mode == "special" then
        listData = sess.specialList
        title = "Special Effect Editor"
        addTextLabel = "Add Effect (with Icon)"
    elseif mode == "bonus" then
        listData = sess.bonusList
        title = "Bonus Drop Editor"
        addTextLabel = "Add Drop Button"
    end
    
    local dialog = {}
    
    insert(dialog, "disable_resize|\n")
    insert(dialog, format("add_label_with_icon|big|`w%s|left|242|\n", title))
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_spacer|small|\n")
    
    if #listData == 0 then
        insert(dialog, "add_textbox|`oNo items configured. Add your first one below!| \n")
    else
        for i, entry in ipairs(listData) do
            local preview = ""
            if entry.type == "text" then
                if mode == "desc" then
                    local sizeTag = entry.big and "`2[NORMAL]" or "`8[SMALL]"
                    preview = format("%s %s", sizeTag, sub(safeStr(entry.text), 1, 30))
                elseif mode == "special" then
                    local iconName = getItemName(entry.iconID or 482)
                    preview = format("`6[%s]`w %s", iconName, sub(safeStr(entry.text), 1, 30))
                elseif mode == "bonus" then
                    local iconName = getItemName(entry.iconID or 482)
                    preview = format("`3[%s]`w %s x%d", iconName, sub(safeStr(entry.text), 1, 20), entry.amount or 1)
                end
            elseif entry.type == "spacer" then
                preview = "`5[ SPACER ]"
            elseif entry.type == "break" then
                preview = "`5[ CUSTOM BREAK ]"
            end
            insert(dialog, format("add_button|info_edit_%s_%d|`9[%d] %s|noflags|\n", mode, i, i, preview))
        end
    end
    
    insert(dialog, "add_spacer|small|\n")
    insert(dialog, "add_label|small|`wAdd New Element:|left|\n")
    insert(dialog, format("add_button|info_add_text_%s|`2+ %s|noflags|\n", mode, addTextLabel))
    insert(dialog, format("add_button|info_add_spacer_%s|`w+ Spacer|noflags|\n", mode))
    insert(dialog, format("add_button|info_add_break_%s|`w+ Break|noflags|\n", mode))
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_button|info_back_to_main|`w< Back to Main Menu|noflags|\n")
    insert(dialog, "end_dialog|info_list_editor|||\n")
    
    player:onDialogRequest(concat(dialog))
end

local function showTextEditor(player, mode, index)
    local sess = getSession(player)
    local entry = nil
    if index then
        if mode == "desc" then entry = sess.descList[index]
        elseif mode == "special" then entry = sess.specialList[index]
        elseif mode == "bonus" then entry = sess.bonusList[index] end
    end
    
    local dialog = {}
    
    insert(dialog, "disable_resize|\n")
    insert(dialog, format("add_label_with_icon|big|`w%s Editor|left|242|\n", 
        (mode == "desc" and "Description" or mode == "special" and "Special Effect" or "Bonus Drop")))
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_spacer|small|\n")
    
    -- Text Input
    local defaultText = entry and entry.text or ""
    insert(dialog, format("add_text_input|info_edit_text|Text:|%s|100|\n", safeStr(defaultText)))
    insert(dialog, "add_spacer|small|\n")
    
    if mode == "desc" then
        -- Big/Small option for description
        local isBig = (entry and entry.big) and 1 or 0
        insert(dialog, format("add_checkbox|info_text_big|Use Normal Text (uncheck = small)|%d|\n", isBig))
    elseif mode == "special" or mode == "bonus" then
        -- Icon selection for special and bonus
        local iconID = (entry and entry.iconID) or 482
        local iconName = getItemName(iconID)
        insert(dialog, format("add_label_with_icon|small|Current Icon: %s|left|%d|\n", iconName, iconID))
        insert(dialog, "add_item_picker|info_pick_icon|`wPick Icon|`oClick to select from inventory|\n")
        insert(dialog, "add_spacer|small|\n")
        
        if mode == "bonus" then
            -- Amount for bonus drop
            local amount = (entry and entry.amount) or 1
            insert(dialog, format("add_text_input|info_bonus_amount|Amount:|%d|5|numeric|\n", amount))
        end
    end
    
    insert(dialog, "add_spacer|small|\n")
    
    if index then
        insert(dialog, format("add_button|info_update_%s_%d|`2Update|noflags|\n", mode, index))
        insert(dialog, format("add_button|info_delete_%s_%d|`4Delete|noflags|\n", mode, index))
    else
        insert(dialog, format("add_button|info_save_%s|`2Save New|noflags|\n", mode))
    end
    
    insert(dialog, "add_button|info_cancel_edit|`wCancel|noflags|\n")
    insert(dialog, "add_quick_exit|\n")
    insert(dialog, "end_dialog|info_text_editor|||\n")
    
    player:onDialogRequest(concat(dialog))
end

-- Handle item picker selections
local function handleItemPicker(player, data)
    local sess = getSession(player)
    
    -- Main item picker
    if data.info_pick_item and tonumber(data.info_pick_item) > 0 then
        local itemID = tonumber(data.info_pick_item)
        sess.targetID = itemID
        
        -- Load existing data if any
        local existing = infoCache[tostring(itemID)]
        if existing then
            sess.bgColor = existing.bgColor or ""
            sess.borderColor = existing.borderColor or ""
            sess.useDefaultDesc = not (existing.useDefaultDesc == false or existing.useDefaultDesc == 0)
            sess.customPropsText = existing.customPropsText or ""
            sess.descList = existing.descList or {}
            sess.specialList = existing.specialList or {}
            sess.bonusList = existing.bonusList or {}
        else
            sess.bgColor = ""
            sess.borderColor = ""
            sess.useDefaultDesc = true
            sess.customPropsText = ""
            sess.descList = {}
            sess.specialList = {}
            sess.bonusList = {}
        end
        
        player:onConsoleMessage(format("`2Editing: %s (ID: %d)``", getItemName(itemID), itemID))
        showMainMenu(player)
        return true
    end
    
    -- Icon picker for special/bonus
    if data.info_pick_icon and tonumber(data.info_pick_icon) > 0 then
        local iconID = tonumber(data.info_pick_icon)
        sess.currentEdit = sess.currentEdit or {}
        sess.currentEdit.iconID = iconID
        player:onConsoleMessage(format("`2Icon set: %s``", getItemName(iconID)))
        
        -- Refresh editor
        timer.setTimeout(0.1, function()
            showTextEditor(player, sess.currentMode, sess.currentIndex)
        end)
        return true
    end
    
    return false
end


local function showBonusDropMenu(player)
    local sess = getSession(player)
    local bonusList = sess.bonusList or {}
    local dialog = {}
    insert(dialog, "disable_resize|\n")
    insert(dialog, "add_label_with_icon|big|`wBonus Drops|left|3032|\n")
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_spacer|small|\n")
    if #bonusList == 0 then
        insert(dialog, "add_textbox|`oNo bonus drops yet. Add one below!|\n")
        insert(dialog, "add_spacer|small|\n")
    else
        insert(dialog, "text_scaling_string|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|\n")
        for i, entry in ipairs(bonusList) do
            if entry.type == "text" then
                local iname = getItemName(entry.iconID or 482)
                local labelText = format("`w%s`o  x%d  `8(%s)", iname, entry.amount or 1, sub(safeStr(entry.text), 1, 20))
                insert(dialog, format("add_button_with_icon|info_bonus_edit_%d|%s|staticBlueFrame|%d|%d|\n",
                    i, labelText, entry.iconID or 482, entry.amount or 1))
                insert(dialog, format("add_small_font_button|info_bonus_del_%d|`4Remove|noflags|0|0|\n", i))
            elseif entry.type == "spacer" then
                insert(dialog, "add_spacer|small|\n")
            end
        end
        insert(dialog, "add_button_with_icon||END_LIST|noflags|0||\n")
        insert(dialog, "add_spacer|small|\n")
    end
    insert(dialog, "add_button|info_bonus_add|`2+ Add New Drop|noflags|\n")
    insert(dialog, "add_button|info_bonus_add_spacer|`w+ Spacer|noflags|\n")
    insert(dialog, "add_custom_break|\n")
    insert(dialog, "add_button|info_back_to_main|`w← Back|noflags|\n")
    insert(dialog, "add_quick_exit|\n")
    insert(dialog, "end_dialog|info_bonus_menu|||\n")
    player:onDialogRequest(concat(dialog))
end

-- Command handler
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd, arg = safeStr(fullCommand):match("^(%S+)%s*(.*)")
    if cmd == "editinfo" then
        local uid = player:getUserID()
        infoSessions[uid] = nil
        showItemPicker(player)
        return true
    end
    return false
end)

-- Dialog handler - FIXED: Hanya handle dialog milik sendiri
onPlayerDialogCallback(function(world, player, data)
    local dialogName = safeStr(data.dialog_name)
    
    -- CEK DULU: Apakah ini dialog milik script ini?
    local validDialogs = {
        ["info_item_picker"] = true,
        ["info_main_menu"] = true,
        ["info_list_editor"] = true,
        ["info_text_editor"] = true,
        ["info_bonus_menu"]  = true,
        ["info_box"]         = true,
        ["fx_drops_popup"]   = true,
    }
    
    -- Jika bukan dialog milik script ini, return false biar sistem lain yang handle
    if not validDialogs[dialogName] then
        return false
    end
    
    -- Sekarang baru proses dialog milik sendiri
    local uid = player:getUserID()
    local sess = infoSessions[uid]
    local buttonClicked = safeStr(data.buttonClicked)
    
    -- Handle item picker selections (khusus untuk dialog milik sendiri)
    if (data.info_pick_item or data.info_pick_icon) and 
       (dialogName == "info_item_picker" or dialogName == "info_main_menu" or dialogName == "info_text_editor") then
        return handleItemPicker(player, data)
    end
    
    if not sess then
        -- getSession her zaman bir session döndürür (persist'ten yükler)
        -- buraya gelinmemeli ama güvenlik için
        sess = getSession(player)
    end
    
    -- Item picker dialog
    if dialogName == "info_item_picker" then
        if buttonClicked == "info_cancel" then
            return true
        end
        return true
    end
    
    -- Main menu
    if dialogName == "info_main_menu" then
        sess.bgColor = data.info_bg_color or ""
        sess.borderColor = data.info_border_color or ""
        sess.useDefaultDesc = (data.info_use_default_desc == "1")
        sess.customPropsText = data.info_custom_props or ""
        
        if buttonClicked == "info_edit_desc" then
            showListEditor(player, "desc")
        elseif buttonClicked == "info_edit_special" then
            showListEditor(player, "special")
        elseif buttonClicked == "info_edit_bonus" then
            showBonusDropMenu(player)
        elseif buttonClicked == "info_save" then
            infoCache[tostring(sess.targetID)] = {
                bgColor = sess.bgColor,
                borderColor = sess.borderColor,
                useDefaultDesc = sess.useDefaultDesc,
                customPropsText = sess.customPropsText or "",
                descList = sess.descList,
                specialList = sess.specialList,
                bonusList = sess.bonusList,
            }
            saveInfoDB()
            player:onConsoleMessage("`2Configuration saved successfully!``")
            player:playAudio("kaching.wav")
        elseif buttonClicked == "info_delete" then
            infoCache[tostring(sess.targetID)] = nil
            saveInfoDB()
            player:onConsoleMessage("`4Configuration deleted!``")
            showMainMenu(player)
        elseif buttonClicked == "info_back_to_picker" then
                infoSessions[uid] = nil
            showItemPicker(player)
        end
        return true
    end
    
    -- List editor
    if dialogName == "info_list_editor" then
        if buttonClicked == "info_back_to_main" then
            showMainMenu(player)
            return true
        end
        
        local mode = nil
        if find(buttonClicked, "_desc") then mode = "desc"
        elseif find(buttonClicked, "_special") then mode = "special"
        elseif find(buttonClicked, "_bonus") then mode = "bonus" end
        
        if not mode then return true end
        
        local listData = (mode == "desc") and sess.descList or (mode == "special") and sess.specialList or sess.bonusList
        
        if find(buttonClicked, "info_add_text_") then
            sess.currentMode = mode
            sess.currentIndex = nil
            sess.currentEdit = {}
            showTextEditor(player, mode, nil)
            return true
        end
        
        if find(buttonClicked, "info_add_spacer_") then
            insert(listData, {type = "spacer"})
            showListEditor(player, mode)
            return true
        end
        
        if find(buttonClicked, "info_add_break_") then
            insert(listData, {type = "break"})
            showListEditor(player, mode)
            return true
        end
        
        local editMode, editIdx = match(buttonClicked, "info_edit_(%a+)_(%d+)")
        if editIdx then
            local idx = tonumber(editIdx)
            sess.currentMode = editMode
            sess.currentIndex = idx
            sess.currentEdit = {}
            showTextEditor(player, editMode, idx)
            return true
        end
        
        return true
    end
    
    -- Text editor
    if dialogName == "info_text_editor" then
        if buttonClicked == "info_cancel_edit" then
            showListEditor(player, sess.currentMode)
            return true
        end
        
        local text = data.info_edit_text or ""
        local mode = sess.currentMode
        local index = sess.currentIndex
        local listData = (mode == "desc") and sess.descList or (mode == "special") and sess.specialList or sess.bonusList
        
        -- Handle save new
        local saveMode = match(buttonClicked, "info_save_(%a+)")
        if saveMode then
            if saveMode == "desc" then
                local isBig = (data.info_text_big == "1")
                insert(listData, {type = "text", text = text, big = isBig})
            elseif saveMode == "special" then
                local iconID = (sess.currentEdit and sess.currentEdit.iconID) or 482
                insert(listData, {type = "text", text = text, iconID = iconID})
            elseif saveMode == "bonus" then
                local iconID = (sess.currentEdit and sess.currentEdit.iconID) or 482
                local amount = tonumber(data.info_bonus_amount or 1) or 1
                insert(listData, {type = "text", text = text, iconID = iconID, amount = amount})
            end
            player:onConsoleMessage("`2Item added!``")
            showListEditor(player, saveMode)
            return true
        end
        
        -- Handle update
        local updateMode, updateIdx = match(buttonClicked, "info_update_(%a+)_(%d+)")
        if updateMode then
            local idx = tonumber(updateIdx)
            if updateMode == "desc" then
                local isBig = (data.info_text_big == "1")
                listData[idx] = {type = "text", text = text, big = isBig}
            elseif updateMode == "special" then
                local iconID = (sess.currentEdit and sess.currentEdit.iconID) or listData[idx].iconID or 482
                listData[idx] = {type = "text", text = text, iconID = iconID}
            elseif updateMode == "bonus" then
                local iconID = (sess.currentEdit and sess.currentEdit.iconID) or listData[idx].iconID or 482
                local amount = tonumber(data.info_bonus_amount or 1) or 1
                listData[idx] = {type = "text", text = text, iconID = iconID, amount = amount}
            end
            player:onConsoleMessage("`2Item updated!``")
            showListEditor(player, updateMode)
            return true
        end
        
        -- Handle delete
        local deleteMode, deleteIdx = match(buttonClicked, "info_delete_(%a+)_(%d+)")
        if deleteMode then
            local idx = tonumber(deleteIdx)
            table.remove(listData, idx)
            player:onConsoleMessage("`4Item deleted!``")
            showListEditor(player, deleteMode)
            return true
        end
        
        return true
    end
    

    -- Bonus Drop dedicated menu
    if dialogName == "info_bonus_menu" then
        if not sess then return true end
        if buttonClicked == "info_back_to_main" then showMainMenu(player) ; return true end
        if buttonClicked == "info_bonus_add" then
            sess.currentMode = "bonus" ; sess.currentIndex = nil ; sess.currentEdit = {}
            showTextEditor(player, "bonus", nil) ; return true
        end
        if buttonClicked == "info_bonus_add_spacer" then
            insert(sess.bonusList, {type="spacer"}) ; showBonusDropMenu(player) ; return true
        end
        local editIdx = match(buttonClicked, "^info_bonus_edit_(%d+)$")
        if editIdx then
            local idx = tonumber(editIdx)
            sess.currentMode = "bonus" ; sess.currentIndex = idx
            sess.currentEdit = { iconID = (sess.bonusList[idx] and sess.bonusList[idx].iconID) or 482 }
            showTextEditor(player, "bonus", idx) ; return true
        end
        local delIdx = match(buttonClicked, "^info_bonus_del_(%d+)$")
        if delIdx then
            local idx = tonumber(delIdx)
            if sess.bonusList[idx] then table.remove(sess.bonusList, idx) end
            showBonusDropMenu(player) ; return true
        end
        return true
    end

    -- Item info box: fx drops popup
    if dialogName == "info_box" then
        local fxItemID = tonumber(buttonClicked:match("^show_fx_drops_(%d+)$"))
        if fxItemID and _G.itemEffects and _G.itemEffects[fxItemID] and _G.itemEffects[fxItemID].drops then
            local drops = _G.itemEffects[fxItemID].drops
            local iname = (getItem(fxItemID) and getItem(fxItemID):getName()) or ("Item #"..fxItemID)
            local d = "set_default_color|`o\n"
            d = d .. format("add_label_with_icon|big|`wBonus Drops``|left|%d|\n", fxItemID)
            d = d .. format("add_textbox|`oWearing `w%s`o may drop:``|left|\n", iname)
            d = d .. "add_spacer|small|\n"
            d = d .. "text_scaling_string|aaaaaaaaaa|\n"
            for _, drop in ipairs(drops) do
                local dn = (getItem(drop.dropID) and getItem(drop.dropID):getName()) or ("Item #"..drop.dropID)
                if #dn > 8 then dn = string.sub(dn, 1, 8) .. "..." end
                d = d .. format("add_button_with_icon||%s|staticBlueFrame,is_count_label|%d|%d|\n",
                    dn, drop.dropID, drop.amount)
            end
            d = d .. "add_custom_break|\n"
            d = d .. "end_dialog|fx_drops_popup||OK|"
            player:onDialogRequest(d) ; return true
        end
        return false
    end

    return true -- validDialogs tablosunda ama yukarıda handle edilmedi
end)

-- Clean up sessions on disconnect
onPlayerDisconnectCallback(function(player)
    local uid = player:getUserID()
    infoSessions[uid] = nil
end)

-- Variant handler: inject item effects + sembunyikan price/ID/slot untuk non-admin
onPlayerVariantCallback(function(player, variant, delay, netID)
    if variant[1] == "OnDialogRequest" then
        local content = safeStr(variant[2])
        if find(content, "info_box") and not find(content, "info_custom") then
            local isAdmin = player:hasRole(ROLE_ADMIN)

            -- Detect item ID
            -- GTPS Cloud uses "add_label_with_ele_icon" (not "add_label_with_icon")
            local stolenID = match(content, "This item ID is (%d+)")
                          or match(content, "add_label_with_ele_icon|big|[^\n]+|left|(%d+)|")
                          or match(content, "|left|(%d+)|")
            local itemID   = stolenID and tonum(stolenID)

            -- Check item effects
            local fx         = itemID and _G.itemEffects and _G.itemEffects[itemID]
            local hasEffects = fx and next(fx) ~= nil

            -- Admin tanpa effects: tampilkan original
            if isAdmin and not hasEffects then return false end

            -- Build dua bagian terpisah:
            -- fxStatsStr = stat effects (inject tepat setelah deskripsi)
            -- fxDropsStr = Bonus Drops button (inject paling bawah sebelum end_dialog)
            local fxStatsStr = ""
            local fxDropsStr = ""
            if hasEffects and fx then
                local fxLines = {}
                if fx.extraGems  and fx.extraGems  > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$Extra Gems -`2 %d%%``|left|25008|\n", fx.extraGems) end
                if fx.extraXP    and fx.extraXP    > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$Extra XP -`2 %d%%``|left|25006|\n", fx.extraXP) end
                if fx.farmSpeed  and fx.farmSpeed  > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$Autofarm Speed Booster -`2 %d%%``|left|25004|\n", fx.farmSpeed) end
                if fx.oneHit                           then fxLines[#fxLines+1] = "add_label_with_icon|small|`$One Hit Break``|left|25010|\n" end
                if fx.breakRange and fx.breakRange > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$+%d Break Range``|left|18|\n", fx.breakRange) end
                if fx.buildRange and fx.buildRange > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$+%d Build Range``|left|2|\n", fx.buildRange) end
                if fx.treeGrowth and fx.treeGrowth > 0 then fxLines[#fxLines+1] = format("add_label_with_icon|small|`$Tree Growth: %ds``|left|25012|\n", fx.treeGrowth) end
                if #fxLines > 0 then
                    fxStatsStr = "add_spacer|small|\n"
                    fxStatsStr = fxStatsStr .. "add_textbox|`oItem Effects``|\n"
                    for _, line in ipairs(fxLines) do fxStatsStr = fxStatsStr .. line end
                end
                if fx.drops and #fx.drops > 0 then
                    fxDropsStr = format("add_button|show_fx_drops_%d|`wBonus Drops``|noflags|0|0|\n", itemID)
                end
            end

            local modified = content

            -- Non-admin: strip item ID, slot, price info
            if not isAdmin then
                modified = modified:gsub("[^\n]*This item ID is %d+[^\n]*\n?", "")
                modified = modified:gsub("[^\n]*This item Slot is %d+[^\n]*\n?", "")
                modified = modified:gsub("[^\n]*[Pp]rice info[^\n]*\n?", "")
                modified = modified:gsub("[^\n]*[Pp]rice is[^\n]*\n?", "")
                modified = modified:gsub("\\n[Tt]his item [Rr]arity is [^\\|]+%.?", "")
                modified = modified:gsub("[Tt]his item [Rr]arity is [^\\|\n]+%.?", "")
            end

            -- Urutan tampil:
            -- [Judul] → [Deskripsi] → [Item Effects] → [Properties spliced/dll] → [Bonus Drops] → [end_dialog]

            -- 1. Inject stat effects tepat setelah add_textbox pertama (deskripsi item)
            if fxStatsStr ~= "" then
                local _, txtEnd = modified:find("add_textbox|[^\n]*\n")
                if txtEnd then
                    modified = modified:sub(1, txtEnd) .. fxStatsStr .. modified:sub(txtEnd + 1)
                else
                    -- fallback: sebelum end_dialog
                    local pos = modified:find("end_dialog", 1, true)
                    if pos then
                        modified = modified:sub(1, pos - 1) .. fxStatsStr .. modified:sub(pos)
                    end
                end
            end

            -- 2. Inject Bonus Drops button tepat sebelum end_dialog
            if fxDropsStr ~= "" then
                local pos = modified:find("end_dialog", 1, true)
                if pos then
                    modified = modified:sub(1, pos - 1) .. fxDropsStr .. modified:sub(pos)
                else
                    modified = modified .. fxDropsStr .. "end_dialog|info_box||OK|"
                end
            end

            -- Trim trailing spacers sebelum end_dialog untuk kurangi gap bawah
            modified = modified:gsub("\nadd_spacer|[^\n]*\nend_dialog|info_box", "\nend_dialog|info_box")
            modified = modified:gsub("\nadd_spacer|[^\n]*\nend_dialog|info_box", "\nend_dialog|info_box")

            -- Tandai sudah diproses agar tidak loop
            modified = "embed_data|info_custom|1|\n" .. modified

            player:onDialogRequest(modified)
            return true
        end
    end
    return false
end)

