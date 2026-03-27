-- MODULE
-- item_info.lua — /editinfo: admin editor untuk item info box + variant inject

local M      = {}
local Config = _G.Config
local DB     = _G.DB

local DB_KEY = "ITEM_INFOS_V3"

local infoCache    = {}
local infoSessions = {}

-- =======================================================
-- CUSTOM JSON ENCODE/DECODE (format khusus, bukan generic)
-- =======================================================

local function escJson(s)
    s = tostring(s or "")
    s = s:gsub('\\', '\\\\'); s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n');  s = s:gsub('\r', '\\r'); s = s:gsub('\t', '\\t')
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
        if     t == "spacer"          then lst[#lst+1] = {type="spacer"}
        elseif t == "break"           then lst[#lst+1] = {type="break"}
        elseif t == "text" or txt     then lst[#lst+1] = {type="text", text=txt or "", big=big, iconID=iconID, amount=amount}
        end
    end
    return lst
end

local function saveInfoDB()
    local parts = {}
    for key, v in pairs(infoCache) do
        parts[#parts+1] = string.format(
            '"%s":{"bgColor":"%s","borderColor":"%s","useDefaultDesc":%s,"customPropsText":"%s","descList":%s,"specialList":%s,"bonusList":%s}',
            escJson(key), escJson(v.bgColor or ""), escJson(v.borderColor or ""),
            (v.useDefaultDesc == false) and "false" or "true",
            escJson(v.customPropsText or ""),
            encodeList(v.descList), encodeList(v.specialList), encodeList(v.bonusList)
        )
    end
    DB.saveStr(DB_KEY, "{"..table.concat(parts, ",").."}")
end

local function loadInfoDB()
    local raw = DB.loadStr(DB_KEY)
    infoCache = {}
    if not raw or raw == "" then return end
    for key, body in raw:gmatch('"(%d+)"%s*:%s*(%b{})') do
        infoCache[key] = {
            bgColor         = body:match('"bgColor"%s*:%s*"(.-)"')         or "",
            borderColor     = body:match('"borderColor"%s*:%s*"(.-)"')     or "",
            useDefaultDesc  = body:match('"useDefaultDesc"%s*:%s*(true)') ~= nil,
            customPropsText = body:match('"customPropsText"%s*:%s*"(.-)"') or "",
            descList        = decodeList(body:match('"descList"%s*:%s*(%b[])') or "[]"),
            specialList     = decodeList(body:match('"specialList"%s*:%s*(%b[])') or "[]"),
            bonusList       = decodeList(body:match('"bonusList"%s*:%s*(%b[])') or "[]"),
        }
    end
end
loadInfoDB()

-- =======================================================
-- SESSION
-- =======================================================

local function getSession(player)
    local uid = player:getUserID()
    if not infoSessions[uid] then
        infoSessions[uid] = {
            targetID=nil, bgColor="", borderColor="", useDefaultDesc=true,
            customPropsText="", descList={}, specialList={}, bonusList={},
            currentEdit=nil, currentMode=nil, currentIndex=nil,
        }
    end
    return infoSessions[uid]
end

local function getItemName(itemID)
    local item = getItem(itemID)
    return item and item:getName() or "Unknown Item"
end

-- =======================================================
-- UI FUNCTIONS
-- =======================================================

local function showItemPicker(player)
    local d = {}
    d[#d+1] = "disable_resize|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label_with_icon|big|`wSelect Item to Edit|left|242|\n"
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_textbox|`oSelect an item from your inventory to edit its information.|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_item_picker|info_pick_item|`wPick Item|`oClick to select from inventory|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_button|info_cancel|`wCancel|noflags|\n"
    d[#d+1] = "add_quick_exit|\n"
    d[#d+1] = "end_dialog|info_item_picker|||\n"
    player:onDialogRequest(table.concat(d))
end

local function showMainMenu(player)
    local sess = getSession(player)
    local itemID = sess.targetID
    local d = {}
    d[#d+1] = "disable_resize|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = string.format("add_label_with_icon|big|`wInfo Editor: %s|left|%d|\n", getItemName(itemID), itemID)
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label|small|`wBackground & Border Colors:`w|\n"
    d[#d+1] = string.format("add_text_input|info_bg_color|Background Color (r,g,b,a):|%s|30|\n", sess.bgColor or "")
    d[#d+1] = string.format("add_text_input|info_border_color|Border Color (r,g,b,a):|%s|30|\n", sess.borderColor or "")
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_label|small|`wProperties (Item Description):`w|\n"
    local useDefault = (sess.useDefaultDesc ~= false)
    d[#d+1] = string.format("add_checkbox|info_use_default_desc|`oUse item default description|%d|\n", useDefault and 1 or 0)
    if not useDefault then
        d[#d+1] = string.format("add_text_input|info_custom_props|Custom Text:|%s|150|\n", sess.customPropsText or "")
    else
        d[#d+1] = "add_smalltext|`8Using the item built-in description.|\n"
    end
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label|small|`wDescription:`w|\n"
    d[#d+1] = string.format("add_textbox|%d line(s) configured| \n", #(sess.descList or {}))
    d[#d+1] = "add_button|info_edit_desc|`wEdit Description|noflags|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label|small|`wSpecial Effect:`w|\n"
    d[#d+1] = string.format("add_textbox|%d effect(s) configured| \n", #(sess.specialList or {}))
    d[#d+1] = "add_button|info_edit_special|`wEdit Special Effect|noflags|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label|small|`wBonus Drop:`w|\n"
    d[#d+1] = string.format("add_textbox|%d drop(s) configured| \n", #(sess.bonusList or {}))
    d[#d+1] = "add_button|info_edit_bonus|`wEdit Bonus Drop|noflags|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_button|info_save|`2SAVE CONFIGURATION|noflags|\n"
    d[#d+1] = "add_button|info_delete|`4DELETE CONFIGURATION|noflags|\n"
    d[#d+1] = "add_button|info_back_to_picker|`wSelect Another Item|noflags|\n"
    d[#d+1] = "add_quick_exit|\n"
    d[#d+1] = "end_dialog|info_main_menu|||\n"
    player:onDialogRequest(table.concat(d))
end

local function showListEditor(player, mode)
    local sess = getSession(player)
    local listData = mode == "desc" and sess.descList or mode == "special" and sess.specialList or sess.bonusList
    local TITLES   = { desc="Description Editor", special="Special Effect Editor", bonus="Bonus Drop Editor" }
    local ADDLABEL = { desc="Add Text Line", special="Add Effect (with Icon)", bonus="Add Drop Button" }
    local d = {}
    d[#d+1] = "disable_resize|\n"
    d[#d+1] = string.format("add_label_with_icon|big|`w%s|left|242|\n", TITLES[mode])
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_spacer|small|\n"
    if #listData == 0 then
        d[#d+1] = "add_textbox|`oNo items configured. Add your first one below!| \n"
    else
        for i, entry in ipairs(listData) do
            local preview = ""
            if entry.type == "text" then
                if mode == "desc" then
                    preview = string.format("%s %s", entry.big and "`2[NORMAL]" or "`8[SMALL]", string.sub(tostring(entry.text or ""), 1, 30))
                elseif mode == "special" then
                    preview = string.format("`6[%s]`w %s", getItemName(entry.iconID or 482), string.sub(tostring(entry.text or ""), 1, 30))
                elseif mode == "bonus" then
                    preview = string.format("`3[%s]`w %s x%d", getItemName(entry.iconID or 482), string.sub(tostring(entry.text or ""), 1, 20), entry.amount or 1)
                end
            elseif entry.type == "spacer" then preview = "`5[ SPACER ]"
            elseif entry.type == "break"  then preview = "`5[ CUSTOM BREAK ]"
            end
            d[#d+1] = string.format("add_button|info_edit_%s_%d|`9[%d] %s|noflags|\n", mode, i, i, preview)
        end
    end
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_label|small|`wAdd New Element:|left|\n"
    d[#d+1] = string.format("add_button|info_add_text_%s|`2+ %s|noflags|\n", mode, ADDLABEL[mode])
    d[#d+1] = string.format("add_button|info_add_spacer_%s|`w+ Spacer|noflags|\n", mode)
    d[#d+1] = string.format("add_button|info_add_break_%s|`w+ Break|noflags|\n", mode)
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_button|info_back_to_main|`w< Back to Main Menu|noflags|\n"
    d[#d+1] = "end_dialog|info_list_editor|||\n"
    player:onDialogRequest(table.concat(d))
end

local function showTextEditor(player, mode, index)
    local sess  = getSession(player)
    local entry = nil
    if index then
        entry = (mode == "desc" and sess.descList or mode == "special" and sess.specialList or sess.bonusList)[index]
    end
    local LABELS = { desc="Description", special="Special Effect", bonus="Bonus Drop" }
    local d = {}
    d[#d+1] = "disable_resize|\n"
    d[#d+1] = string.format("add_label_with_icon|big|`w%s Editor|left|242|\n", LABELS[mode])
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = string.format("add_text_input|info_edit_text|Text:|%s|100|\n", tostring(entry and entry.text or ""))
    d[#d+1] = "add_spacer|small|\n"
    if mode == "desc" then
        local isBig = (entry and entry.big) and 1 or 0
        d[#d+1] = string.format("add_checkbox|info_text_big|Use Normal Text (uncheck = small)|%d|\n", isBig)
    elseif mode == "special" or mode == "bonus" then
        local iconID = (entry and entry.iconID) or 482
        d[#d+1] = string.format("add_label_with_icon|small|Current Icon: %s|left|%d|\n", getItemName(iconID), iconID)
        d[#d+1] = "add_item_picker|info_pick_icon|`wPick Icon|`oClick to select from inventory|\n"
        d[#d+1] = "add_spacer|small|\n"
        if mode == "bonus" then
            d[#d+1] = string.format("add_text_input|info_bonus_amount|Amount:|%d|5|numeric|\n", (entry and entry.amount) or 1)
        end
    end
    d[#d+1] = "add_spacer|small|\n"
    if index then
        d[#d+1] = string.format("add_button|info_update_%s_%d|`2Update|noflags|\n", mode, index)
        d[#d+1] = string.format("add_button|info_delete_%s_%d|`4Delete|noflags|\n", mode, index)
    else
        d[#d+1] = string.format("add_button|info_save_%s|`2Save New|noflags|\n", mode)
    end
    d[#d+1] = "add_button|info_cancel_edit|`wCancel|noflags|\n"
    d[#d+1] = "add_quick_exit|\n"
    d[#d+1] = "end_dialog|info_text_editor|||\n"
    player:onDialogRequest(table.concat(d))
end

local function showBonusDropMenu(player)
    local sess      = getSession(player)
    local bonusList = sess.bonusList or {}
    local d = {}
    d[#d+1] = "disable_resize|\n"
    d[#d+1] = "add_label_with_icon|big|`wBonus Drops|left|3032|\n"
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_spacer|small|\n"
    if #bonusList == 0 then
        d[#d+1] = "add_textbox|`oNo bonus drops yet. Add one below!|\n"
        d[#d+1] = "add_spacer|small|\n"
    else
        d[#d+1] = "text_scaling_string|aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|\n"
        for i, entry in ipairs(bonusList) do
            if entry.type == "text" then
                local label = string.format("`w%s`o  x%d  `8(%s)", getItemName(entry.iconID or 482), entry.amount or 1, string.sub(tostring(entry.text or ""), 1, 20))
                d[#d+1] = string.format("add_button_with_icon|info_bonus_edit_%d|%s|staticBlueFrame|%d|%d|\n", i, label, entry.iconID or 482, entry.amount or 1)
                d[#d+1] = string.format("add_small_font_button|info_bonus_del_%d|`4Remove|noflags|0|0|\n", i)
            elseif entry.type == "spacer" then
                d[#d+1] = "add_spacer|small|\n"
            end
        end
        d[#d+1] = "add_button_with_icon||END_LIST|noflags|0||\n"
        d[#d+1] = "add_spacer|small|\n"
    end
    d[#d+1] = "add_button|info_bonus_add|`2+ Add New Drop|noflags|\n"
    d[#d+1] = "add_button|info_bonus_add_spacer|`w+ Spacer|noflags|\n"
    d[#d+1] = "add_custom_break|\n"
    d[#d+1] = "add_button|info_back_to_main|`w← Back|noflags|\n"
    d[#d+1] = "add_quick_exit|\n"
    d[#d+1] = "end_dialog|info_bonus_menu|||\n"
    player:onDialogRequest(table.concat(d))
end

-- =======================================================
-- COMMAND
-- =======================================================

registerLuaCommand({ command = "editinfo", roleRequired = Config.ROLES.STAFF, description = "Edit item information." })

onPlayerCommandCallback(function(world, player, fullCommand)
    if fullCommand:lower():match("^/editinfo") then
        infoSessions[player:getUserID()] = nil
        showItemPicker(player)
        return true
    end
    return false
end)

-- =======================================================
-- DIALOG CALLBACKS
-- =======================================================

local VALID_DIALOGS = {
    info_item_picker=true, info_main_menu=true, info_list_editor=true,
    info_text_editor=true, info_bonus_menu=true, info_box=true, fx_drops_popup=true,
}

onPlayerDialogCallback(function(world, player, data)
    local dn  = tostring(data.dialog_name or "")
    if not VALID_DIALOGS[dn] then return false end

    local uid  = player:getUserID()
    local sess = infoSessions[uid] or getSession(player)
    local btn  = tostring(data.buttonClicked or "")

    -- Item picker (main + icon)
    if (data.info_pick_item or data.info_pick_icon) and
       (dn == "info_item_picker" or dn == "info_main_menu" or dn == "info_text_editor") then
        if data.info_pick_item and tonumber(data.info_pick_item) and tonumber(data.info_pick_item) > 0 then
            local itemID  = tonumber(data.info_pick_item)
            sess.targetID = itemID
            local existing = infoCache[tostring(itemID)]
            if existing then
                sess.bgColor = existing.bgColor or ""; sess.borderColor = existing.borderColor or ""
                sess.useDefaultDesc = not (existing.useDefaultDesc == false)
                sess.customPropsText = existing.customPropsText or ""
                sess.descList = existing.descList or {}; sess.specialList = existing.specialList or {}; sess.bonusList = existing.bonusList or {}
            else
                sess.bgColor=""; sess.borderColor=""; sess.useDefaultDesc=true
                sess.customPropsText=""; sess.descList={}; sess.specialList={}; sess.bonusList={}
            end
            player:onConsoleMessage(string.format("`2Editing: %s (ID: %d)``", getItemName(itemID), itemID))
            showMainMenu(player)
            return true
        end
        if data.info_pick_icon and tonumber(data.info_pick_icon) and tonumber(data.info_pick_icon) > 0 then
            local iconID = tonumber(data.info_pick_icon)
            sess.currentEdit = sess.currentEdit or {}
            sess.currentEdit.iconID = iconID
            player:onConsoleMessage(string.format("`2Icon set: %s``", getItemName(iconID)))
            timer.setTimeout(0.1, function() showTextEditor(player, sess.currentMode, sess.currentIndex) end)
            return true
        end
        return true
    end

    -- info_item_picker
    if dn == "info_item_picker" then return true end

    -- info_main_menu
    if dn == "info_main_menu" then
        sess.bgColor = data.info_bg_color or ""
        sess.borderColor = data.info_border_color or ""
        sess.useDefaultDesc = (data.info_use_default_desc == "1")
        sess.customPropsText = data.info_custom_props or ""
        if btn == "info_edit_desc"    then showListEditor(player, "desc")
        elseif btn == "info_edit_special" then showListEditor(player, "special")
        elseif btn == "info_edit_bonus"   then showBonusDropMenu(player)
        elseif btn == "info_save" then
            infoCache[tostring(sess.targetID)] = {
                bgColor=sess.bgColor, borderColor=sess.borderColor, useDefaultDesc=sess.useDefaultDesc,
                customPropsText=sess.customPropsText or "",
                descList=sess.descList, specialList=sess.specialList, bonusList=sess.bonusList,
            }
            saveInfoDB()
            player:onConsoleMessage("`2Configuration saved successfully!``")
            player:playAudio("kaching.wav")
        elseif btn == "info_delete" then
            infoCache[tostring(sess.targetID)] = nil
            saveInfoDB()
            player:onConsoleMessage("`4Configuration deleted!``")
            showMainMenu(player)
        elseif btn == "info_back_to_picker" then
            infoSessions[uid] = nil
            showItemPicker(player)
        end
        return true
    end

    -- info_list_editor
    if dn == "info_list_editor" then
        if btn == "info_back_to_main" then showMainMenu(player); return true end
        local mode = btn:find("_desc") and "desc" or btn:find("_special") and "special" or btn:find("_bonus") and "bonus"
        if not mode then return true end
        local listData = mode == "desc" and sess.descList or mode == "special" and sess.specialList or sess.bonusList
        if btn:find("info_add_text_")   then sess.currentMode=mode; sess.currentIndex=nil; sess.currentEdit={}; showTextEditor(player, mode, nil); return true end
        if btn:find("info_add_spacer_") then table.insert(listData, {type="spacer"}); showListEditor(player, mode); return true end
        if btn:find("info_add_break_")  then table.insert(listData, {type="break"});  showListEditor(player, mode); return true end
        local editMode, editIdx = btn:match("info_edit_(%a+)_(%d+)")
        if editIdx then
            local idx = tonumber(editIdx)
            sess.currentMode=editMode; sess.currentIndex=idx; sess.currentEdit={}
            showTextEditor(player, editMode, idx)
        end
        return true
    end

    -- info_text_editor
    if dn == "info_text_editor" then
        if btn == "info_cancel_edit" then showListEditor(player, sess.currentMode); return true end
        local text     = data.info_edit_text or ""
        local mode     = sess.currentMode
        local listData = mode == "desc" and sess.descList or mode == "special" and sess.specialList or sess.bonusList
        local saveMode = btn:match("info_save_(%a+)")
        if saveMode then
            if saveMode == "desc" then
                table.insert(listData, {type="text", text=text, big=(data.info_text_big=="1")})
            elseif saveMode == "special" then
                table.insert(listData, {type="text", text=text, iconID=(sess.currentEdit and sess.currentEdit.iconID) or 482})
            elseif saveMode == "bonus" then
                table.insert(listData, {type="text", text=text, iconID=(sess.currentEdit and sess.currentEdit.iconID) or 482, amount=tonumber(data.info_bonus_amount or 1) or 1})
            end
            player:onConsoleMessage("`2Item added!``")
            showListEditor(player, saveMode); return true
        end
        local updMode, updIdx = btn:match("info_update_(%a+)_(%d+)")
        if updIdx then
            local idx = tonumber(updIdx)
            if updMode == "desc" then
                listData[idx] = {type="text", text=text, big=(data.info_text_big=="1")}
            elseif updMode == "special" then
                listData[idx] = {type="text", text=text, iconID=(sess.currentEdit and sess.currentEdit.iconID) or listData[idx].iconID or 482}
            elseif updMode == "bonus" then
                listData[idx] = {type="text", text=text, iconID=(sess.currentEdit and sess.currentEdit.iconID) or listData[idx].iconID or 482, amount=tonumber(data.info_bonus_amount or 1) or 1}
            end
            player:onConsoleMessage("`2Item updated!``")
            showListEditor(player, updMode); return true
        end
        local delMode, delIdx = btn:match("info_delete_(%a+)_(%d+)")
        if delIdx then
            table.remove(listData, tonumber(delIdx))
            player:onConsoleMessage("`4Item deleted!``")
            showListEditor(player, delMode)
        end
        return true
    end

    -- info_bonus_menu
    if dn == "info_bonus_menu" then
        if btn == "info_back_to_main" then showMainMenu(player); return true end
        if btn == "info_bonus_add" then
            sess.currentMode="bonus"; sess.currentIndex=nil; sess.currentEdit={}
            showTextEditor(player, "bonus", nil); return true
        end
        if btn == "info_bonus_add_spacer" then
            table.insert(sess.bonusList, {type="spacer"}); showBonusDropMenu(player); return true
        end
        local editIdx = btn:match("^info_bonus_edit_(%d+)$")
        if editIdx then
            local idx = tonumber(editIdx)
            sess.currentMode="bonus"; sess.currentIndex=idx
            sess.currentEdit = { iconID = (sess.bonusList[idx] and sess.bonusList[idx].iconID) or 482 }
            showTextEditor(player, "bonus", idx); return true
        end
        local delIdx = btn:match("^info_bonus_del_(%d+)$")
        if delIdx then
            table.remove(sess.bonusList, tonumber(delIdx))
            showBonusDropMenu(player)
        end
        return true
    end

    -- info_box: fx drops popup
    if dn == "info_box" then
        local fxItemID = tonumber(btn:match("^show_fx_drops_(%d+)$"))
        if fxItemID and _G.itemEffects and _G.itemEffects[fxItemID] and _G.itemEffects[fxItemID].drops then
            local drops = _G.itemEffects[fxItemID].drops
            local iname = getItemName(fxItemID)
            local d = string.format("set_default_color|`o\nadd_label_with_icon|big|`wBonus Drops``|left|%d|\nadd_textbox|`oWearing `w%s`o may drop:``|left|\nadd_spacer|small|\ntext_scaling_string|aaaaaaaaaa|\n", fxItemID, iname)
            for _, drop in ipairs(drops) do
                local dn2 = getItemName(drop.dropID)
                if #dn2 > 8 then dn2 = string.sub(dn2, 1, 8) .. "..." end
                d = d .. string.format("add_button_with_icon||%s|staticBlueFrame,is_count_label|%d|%d|\n", dn2, drop.dropID, drop.amount)
            end
            d = d .. "add_custom_break|\nend_dialog|fx_drops_popup||OK|"
            player:onDialogRequest(d); return true
        end
        return false
    end

    return true
end)

-- =======================================================
-- VARIANT CALLBACK — inject item effects ke info_box
-- =======================================================

onPlayerVariantCallback(function(player, variant, delay, netID)
    if variant[1] ~= "OnDialogRequest" then return false end
    local content = tostring(variant[2] or "")
    if not content:find("info_box") or content:find("info_custom") then return false end

    local isAdmin = player:hasRole(Config.ROLES.STAFF)

    local stolenID = content:match("This item ID is (%d+)")
                  or content:match("add_label_with_ele_icon|big|[^\n]+|left|(%d+)|")
                  or content:match("|left|(%d+)|")
    local itemID   = stolenID and tonumber(stolenID)

    local fx         = itemID and _G.itemEffects and _G.itemEffects[itemID]
    local hasEffects = fx and next(fx) ~= nil

    if isAdmin and not hasEffects then return false end

    local fxStatsStr, fxDropsStr = "", ""
    if hasEffects and fx then
        local fxLines = {}
        if fx.extraGems  and fx.extraGems  > 0 then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$Extra Gems -`2 %d%%``|left|25008|\n", fx.extraGems) end
        if fx.extraXP    and fx.extraXP    > 0 then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$Extra XP -`2 %d%%``|left|25006|\n", fx.extraXP) end
        if fx.farmSpeed  and fx.farmSpeed  > 0 then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$Autofarm Speed Booster -`2 %d%%``|left|25004|\n", fx.farmSpeed) end
        if fx.oneHit                            then fxLines[#fxLines+1] = "add_label_with_icon|small|`$One Hit Break``|left|25010|\n" end
        if fx.breakRange and fx.breakRange > 0  then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$+%d Break Range``|left|18|\n", fx.breakRange) end
        if fx.buildRange and fx.buildRange > 0  then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$+%d Build Range``|left|2|\n", fx.buildRange) end
        if fx.treeGrowth and fx.treeGrowth > 0  then fxLines[#fxLines+1] = string.format("add_label_with_icon|small|`$Tree Growth: %ds``|left|25012|\n", fx.treeGrowth) end
        if #fxLines > 0 then
            fxStatsStr = "add_spacer|small|\nadd_textbox|`oItem Effects``|\n"
            for _, line in ipairs(fxLines) do fxStatsStr = fxStatsStr .. line end
        end
        if fx.drops and #fx.drops > 0 then
            fxDropsStr = string.format("add_button|show_fx_drops_%d|`wBonus Drops``|noflags|0|0|\n", itemID)
        end
    end

    local modified = content

    if not isAdmin then
        modified = modified:gsub("[^\n]*This item ID is %d+[^\n]*\n?", "")
        modified = modified:gsub("[^\n]*This item Slot is %d+[^\n]*\n?", "")
        modified = modified:gsub("[^\n]*[Pp]rice info[^\n]*\n?", "")
        modified = modified:gsub("[^\n]*[Pp]rice is[^\n]*\n?", "")
        modified = modified:gsub("\\n[Tt]his item [Rr]arity is [^\\|]+%.?", "")
        modified = modified:gsub("[Tt]his item [Rr]arity is [^\\|\n]+%.?", "")
    end

    if fxStatsStr ~= "" then
        local _, txtEnd = modified:find("add_textbox|[^\n]*\n")
        if txtEnd then
            modified = modified:sub(1, txtEnd) .. fxStatsStr .. modified:sub(txtEnd + 1)
        else
            local pos = modified:find("end_dialog", 1, true)
            if pos then modified = modified:sub(1, pos-1) .. fxStatsStr .. modified:sub(pos) end
        end
    end

    if fxDropsStr ~= "" then
        local pos = modified:find("end_dialog", 1, true)
        if pos then
            modified = modified:sub(1, pos-1) .. fxDropsStr .. modified:sub(pos)
        else
            modified = modified .. fxDropsStr .. "end_dialog|info_box||OK|"
        end
    end

    modified = modified:gsub("\nadd_spacer|[^\n]*\nend_dialog|info_box", "\nend_dialog|info_box")
    modified = modified:gsub("\nadd_spacer|[^\n]*\nend_dialog|info_box", "\nend_dialog|info_box")
    modified = "embed_data|info_custom|1|\n" .. modified

    player:onDialogRequest(modified)
    return true
end)

-- Cleanup session on disconnect
onPlayerDisconnectCallback(function(player)
    infoSessions[player:getUserID()] = nil
end)

return M
