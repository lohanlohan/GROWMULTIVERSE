-- MODULE
-- automation_menu.lua — /auto: player automation menu with mod toggles and anti-consumable

local M = {}

local MOD_AUTOFARM        = -97
local MOD_MAGPLANT        = -113
local MOD_AUTO_PULL       = -100
local MOD_AUTO_PLANT      = -101
local MOD_FAST_DROP       = -107
local MOD_FAST_TRASH      = -108
local MOD_NO_GEM_DROP     = -109
local MOD_NO_PARTICLE     = -112
local MOD_ANTI_CONSUMABLE = -721

-- Spam state per player
local spamData = {}

local function getSpam(player)
    local uid = player:getUserID()
    if not spamData[uid] then spamData[uid] = { enabled = false, text = nil, counter = 0 } end
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

-- ============================================================================
-- PLAYER TICK: autofarm lock + spam timer
-- ============================================================================
onPlayerTick(function(player)
    if isModActive(player, MOD_AUTOFARM) then
        player:addMod(MOD_MAGPLANT, 99999999)
    end
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

-- ============================================================================
-- MAIN MENU
-- ============================================================================
local function sendCheatMenu(player)
    local sd         = getSpam(player)
    local targetName = getAutofarmTargetName(player)
    local targetID   = getAutofarmTargetID(player)

    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wGrow-Multiverse Automation``|left|20700|\n"
    d = d .. "add_textbox|`oYou will not get banned using automation, but if caught automating in other worlds the world owner may `4World Ban`o you!``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label_with_icon|small|`wTarget autofarm block: `2" .. targetName .. "``|left|" .. (targetID > 0 and targetID or 2) .. "|\n"
    d = d .. "add_button|btn_set_target|Pick Block|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_label|small|`oAutomating options:|left|\n"
    d = d .. "add_checkbox|check_autofarm|`wAuto-Farm `o(Target is the tile in front of you)|"        .. checked(player, MOD_AUTOFARM)        .. "|\n"
    d = d .. "add_checkbox|custom_spam|`wAuto-Spam `o(Sends your message every 10s via /setspam)|"    .. (sd.enabled and 1 or 0)              .. "|\n"
    d = d .. "add_checkbox|check_autopull|`wAuto Pull `o(Automatically pulls nearby dropped items)|"  .. checked(player, MOD_AUTO_PULL)        .. "|\n"
    d = d .. "add_checkbox|check_autofish|`wAuto Fish `o(Automatically catches fish)|"                .. checked(player, MOD_AUTO_PLANT)       .. "|\n"
    d = d .. "add_checkbox|check_fastdrop|`wFast Drop `o(Drops items from inventory much faster)|"    .. checked(player, MOD_FAST_DROP)        .. "|\n"
    d = d .. "add_checkbox|check_fasttrash|`wFast Trash `o(Trashes items much faster)|"               .. checked(player, MOD_FAST_TRASH)       .. "|\n"
    d = d .. "add_checkbox|check_gems|`wAuto-Collect Gems `o(Collects gems while farming)|"           .. checked(player, MOD_NO_GEM_DROP)      .. "|\n"
    d = d .. "add_checkbox|check_noparticles|`wNo Particles `o(Hides all particle effects)|"          .. checked(player, MOD_NO_PARTICLE)      .. "|\n"
    d = d .. "add_checkbox|custom_anticonsumable|`wAnti Consumables `o(reject all consumables)|"      .. checked(player, MOD_ANTI_CONSUMABLE)  .. "|\n"
    d = d .. "end_dialog|cheats|Close|Apply|\n"
    player:onDialogRequest(d)
end

local function sendTargetPicker(player)
    local targetName = getAutofarmTargetName(player)
    local targetID   = getAutofarmTargetID(player)
    local d = "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wTarget Autofarm Block``|left|" .. (targetID > 0 and targetID or 2) .. "|\n"
    d = d .. "add_textbox|`oCurrent target: `2" .. targetName .. "``|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_item_picker|target_block_id|Select Block|Pick a block from your inventory|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_back_to_cheats|Back|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|cheats_target_picker|Close|Confirm|\n"
    player:onDialogRequest(d)
end

-- ============================================================================
-- COMMANDS
-- ============================================================================
onPlayerCommandCallback(function(world, player, full)
    local cmd = full:lower()

    if cmd == "cheats" then
        player:onConsoleMessage("`4This command is disabled. `wPlease use `2/auto `winstead!")
        return true
    end

    if cmd == "auto" then
        local MS = _G.MaladySystem
        if MS and MS.MALADY and MS.getActiveMalady and MS.getActiveMalady(player) == MS.MALADY.AUTOMATION_CURSE then
            player:onTalkBubble(player:getNetID(), "`4Automation Curse! Get cured first!", 0)
            return true
        end
        if MS and MS.tryInfectFromTrigger and MS.TRIGGER_SOURCE then
            MS.tryInfectFromTrigger(player, MS.TRIGGER_SOURCE.AUTOMATION)
        end
        sendCheatMenu(player)
        return true
    end

    if cmd == "setspam" then
        local sd = getSpam(player)
        sd.enabled = false
        sd.counter = 0
        player:onConsoleMessage("`4Auto-Spam disabled.")
        return true
    end

    if #full > 8 and full:sub(1, 8):lower() == "setspam " then
        local text = full:sub(9)
        getSpam(player).text = text
        player:onConsoleMessage("`2Spam text set: `w" .. text)
        return true
    end
end)

-- Player profile action hook
onPlayerActionCallback(function(world, player, data)
    if data["action"] == "open_cheat_menu" then
        sendCheatMenu(player)
    end
end)

-- ============================================================================
-- DIALOG CALLBACKS
-- ============================================================================
onPlayerDialogCallback(function(world, player, data)
    local dn  = data["dialog_name"]   or ""
    local btn = data["buttonClicked"] or ""

    if dn == "cheats" and btn == "btn_set_target" then
        sendTargetPicker(player)
        return true
    end

    if dn == "cheats" then
        -- Handle custom spam
        local sd = getSpam(player)
        local wasEnabled = sd.enabled
        sd.enabled = (data["custom_spam"] == "1")
        if not wasEnabled and sd.enabled and (not sd.text or sd.text == "") then
            player:onConsoleMessage("`eSet your spam message with `2/setspam `eyour message``")
        end
        -- Handle anti-consumable
        if tonumber(data["custom_anticonsumable"]) == 1 then
            player:addMod(MOD_ANTI_CONSUMABLE, 99999999)
        elseif tonumber(data["custom_anticonsumable"]) == 0 then
            player:removeMod(MOD_ANTI_CONSUMABLE)
        end
        -- Let built-in handle check_* mods (don't return true here)
    end

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
                player:onConsoleMessage("`2Autofarm target set to: `w" .. (item and item:getName() or "ID " .. blockID))
            else
                player:onConsoleMessage("`4Autofarm must be enabled first!")
            end
        end
        sendCheatMenu(player)
        return true
    end
end)

-- Global export for player-profile integration
_G.GM_openCheatMenu = sendCheatMenu

return M
