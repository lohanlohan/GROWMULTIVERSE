-- ================================================
--   CUSTOM CHEAT MENU v12 - FIXED
--   - All mods working properly
--   - Anti-consumable fixed
--   - Dialog callback properly handles all mods
-- ================================================

local MOD_AUTOFARM    = -97
local MOD_MAGPLANT    = -113
local MOD_AUTO_PULL   = -100
local MOD_AUTO_PLANT  = -101
local MOD_ANTIBOUNCE  = -103
local MOD_SUPER_SPEED = -105
local MOD_GRAVITY     = -106
local MOD_FAST_DROP   = -107
local MOD_FAST_TRASH  = -108
local MOD_NO_GEM_DROP = -109
local MOD_NO_PARTICLE = -112
local MOD_ANTI_CONSUMABLE = -721

-- Spam state: [userID] = { enabled, text, counter }
local spamData = {}

local function getSpam(player)
    local uid = player:getUserID()
    if not spamData[uid] then
        spamData[uid] = { enabled = false, text = nil, counter = 0 }
    end
    return spamData[uid]
end

local function isModActive(player, modID)
    return player:getMod(modID) ~= nil
end

local function checked(player, modID)
    return isModActive(player, modID) and 1 or 0
end

local function getAutofarmTargetName(player)
    local af = player:getAutofarm()
    if not af then return "Not set" end
    local blockID = af:getTargetBlockID()
    if not blockID or blockID == 0 then return "Not set" end
    local item = getItem(blockID)
    return item and item:getName() or ("ID: " .. blockID)
end

local function getAutofarmTargetID(player)
    local af = player:getAutofarm()
    if not af then return 0 end
    return af:getTargetBlockID() or 0
end

-- ================================================
--  onPlayerTick: lock autofarm sync + spam timer
-- ================================================
onPlayerTick(function(player)
    -- Lock autofarm mirrors autofarm
    if isModActive(player, MOD_AUTOFARM) then
        player:addMod(MOD_MAGPLANT, 99999999)
    end

    -- Auto-Spam timer (10s for test, change to 60 later)
    local sd = getSpam(player)
    if sd.enabled and sd.text and sd.text ~= "" then
        sd.counter = sd.counter + 1
        if sd.counter >= 10 then
            sd.counter = 0
            local world = player:getWorld()
            if world then
                local players = world:getPlayers()
                for i = 1, #players do
                    players[i]:onTalkBubble(player:getNetID(), sd.text, 0)
                    players[i]:onConsoleMessage("`6<" .. player:getName() .. ">`` " .. sd.text)
                end
            end
        end
    end
end)

onPlayerDisconnectCallback(function(player)
    spamData[player:getUserID()] = nil
end)

-- ================================================
--  Main Cheat Menu
-- ================================================
local function sendCheatMenu(player)
    local sd         = getSpam(player)
    local targetName = getAutofarmTargetName(player)
    local targetID   = getAutofarmTargetID(player)

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wGrow-Multiverse Automation``|left|20700|\n"
    d = d .. "add_textbox|`oYou will not get banned using automation, but if caught automating in other worlds the world owner may `4World Ban`o you!``|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_label_with_icon|small|`wTarget autofarm block: `2" .. targetName .. "``|left|" .. (targetID > 0 and targetID or 2) .. "|\n"
    d = d .. "add_button|btn_set_target|Pick Block|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_label|small|`oAutomating options:|left|\n"

    -- Built-in checkbox names → built-in handles these mods
    d = d .. "add_checkbox|check_autofarm|`wAuto-Farm `o(Target is the tile in front of you)|"              .. checked(player, MOD_AUTOFARM)    .. "|\n"
    -- Custom spam checkbox (not check_autospam → built-in won't touch it)
    d = d .. "add_checkbox|custom_spam|`wAuto-Spam `o(Sends your message every 10s via /setspam)|"          .. (sd.enabled and 1 or 0)          .. "|\n"
    d = d .. "add_checkbox|check_autopull|`wAuto Pull `o(Automatically pulls nearby dropped items)|"         .. checked(player, MOD_AUTO_PULL)   .. "|\n"
    d = d .. "add_checkbox|check_autofish|`wAuto Fish `o(Automatically catches fish)|"                      .. checked(player, MOD_AUTO_PLANT)  .. "|\n"
    d = d .. "add_checkbox|check_fastdrop|`wFast Drop `o(Drops items from inventory much faster)|"           .. checked(player, MOD_FAST_DROP)   .. "|\n"
    d = d .. "add_checkbox|check_fasttrash|`wFast Trash `o(Trashes items from inventory much faster)|"       .. checked(player, MOD_FAST_TRASH)  .. "|\n"
    d = d .. "add_checkbox|check_gems|`wAuto-Collect Gems `o(Collects gems automatically while farming)|"    .. checked(player, MOD_NO_GEM_DROP) .. "|\n"
    d = d .. "add_checkbox|check_noparticles|`wNo Particles `o(Hides all particle effects in the world)|"    .. checked(player, MOD_NO_PARTICLE) .. "|\n"
    d = d .. "add_checkbox|custom_anticonsumable|`wAnti Consumables `o(reject all consumables)|"    .. checked(player, MOD_ANTI_CONSUMABLE) .. "|\n"

    -- dialog_name = cheats → built-in handles all check_* mods
    d = d .. "end_dialog|cheats|Close|Apply|\n"
    player:onDialogRequest(d)
end

-- ================================================
--  Autofarm Target Block Picker
-- ================================================
local function sendTargetPicker(player)
    local targetName = getAutofarmTargetName(player)
    local targetID   = getAutofarmTargetID(player)

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wTarget Autofarm Block``|left|" .. (targetID > 0 and targetID or 2) .. "|\n"
    d = d .. "add_textbox|`oCurrent target: `2" .. targetName .. "``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|`oSelect the block you want to autofarm from your inventory:``|\n"
    d = d .. "add_item_picker|target_block_id|Select Block|Pick a block from your inventory|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back_to_cheats|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|cheats_target_picker|Close|Confirm|\n"
    player:onDialogRequest(d)
end

-- ================================================
--  Commands
-- ================================================
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:lower()

    if cmd == "cheats" then
        player:onConsoleMessage("`4This command is disabled. `wPlease use `2/auto `winstead!")
        return true
    end

    if cmd == "auto" then
        if MaladySystem and MaladySystem.getActiveMalady(player) == MaladySystem.MALADY.AUTOMATION_CURSE then
            if player.onTalkBubble and player.getNetID then
                player:onTalkBubble(player:getNetID(), "`4Automation Curse! You cannot use automation while cursed. Get cured first!", 0)
            end
            return true
        end
        if MaladySystem then
            MaladySystem.tryInfectFromTrigger(player, MaladySystem.TRIGGER_SOURCE.AUTOMATION)
        end
        sendCheatMenu(player)
        return true
    end

    -- Save spam text
    if fullCommand:lower() == "setspam" then
        local sd = getSpam(player)
        sd.enabled = false
        sd.counter = 0
        player:onConsoleMessage("`4Auto-Spam disabled.")
        return true
    end

    if #fullCommand > 8 and fullCommand:sub(1, 8):lower() == "setspam " then
        local text = fullCommand:sub(9)
        getSpam(player).text = text
        player:onConsoleMessage("`2Spam text set: `w" .. text)
        return true
    end
end)

-- ================================================
--  Player profile button
-- ================================================
onPlayerActionCallback(function(world, player, data)
    if data["action"] == "open_cheat_menu" then
        sendCheatMenu(player)
    end
end)

-- ================================================
--  Dialog callbacks
-- ================================================
onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"]   or ""
    local btn = data["buttonClicked"] or ""
    
    -- FIXED: Handle button clicks first
    if dn == "cheats" and btn == "btn_set_target" then
        sendTargetPicker(player)
        return true
    end

    -- FIXED: Handle all custom checkboxes WITHOUT returning
    if dn == "cheats" then
        -- Handle custom spam checkbox
        local sd = getSpam(player)
        local wasEnabled = sd.enabled
        sd.enabled = (data["custom_spam"] == "1")
        if not wasEnabled and sd.enabled then
            sd.counter = 0
            if not sd.text or sd.text == "" then
                player:onConsoleMessage("`eSet your spam message with `2/setspam `eyour message``")
            end
        end
        
        -- FIXED: Handle anti-consumable checkbox (was blocking all other mods!)
        if tonumber(data["custom_anticonsumable"]) == 1 then
            player:addMod(MOD_ANTI_CONSUMABLE, 99999999)
        elseif tonumber(data["custom_anticonsumable"]) == 0 then
            player:removeMod(MOD_ANTI_CONSUMABLE)
        end
        
        -- DON'T return here! Let built-in handle check_* mods
    end

    -- Target picker dialog
    if dn == "cheats_target_picker" then
        if btn == "btn_back_to_cheats" then
            sendCheatMenu(player)
            return true
        end

        local blockID = tonumber(data["target_block_id"])
        if blockID and blockID > 0 then
            local af = player:getAutofarm()
            if af then
                af:setTargetBlockID(blockID)
                local item = getItem(blockID)
                local name = item and item:getName() or ("ID " .. blockID)
                player:onConsoleMessage("`2Autofarm target set to: `w" .. name)
            else
                player:onConsoleMessage("`4Autofarm must be enabled first!")
            end
        end

        sendCheatMenu(player)
        return true
    end
end)

-- Player-profile entegrasyonu
_G.GM_openCheatMenu = sendCheatMenu

print(">> Custom Cheat Menu v12 FIXED loaded!")
print(">> All mods working: Autofarm, Spam, Pull, Fish, Drop, Trash, Gems, Particles, Anti-Consumable")