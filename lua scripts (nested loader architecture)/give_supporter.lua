-- MODULE
-- give_supporter.lua — /givesupp /giveinv: grant subscriptions or inventory slots

local M = {}

local ROLE_DEV        = 51
local MAX_INVENTORY   = 396
local SUB_SUPPORTER   = 0
local SUB_SUPER_SUPP  = 1

registerLuaCommand({ command = "givesupp", roleRequired = ROLE_DEV, description = "Grant Supporter/Super Supporter subscription." })
registerLuaCommand({ command = "giveinv",  roleRequired = ROLE_DEV, description = "Give inventory space to a player." })

local function findPlayer(name)
    local needle = (name or ""):lower()
    for _, p in ipairs(getServerPlayers()) do
        local nm = (p.getCleanName and p:getCleanName()) or p:getName()
        if nm and nm:lower() == needle then
            return p
        end
    end
    return nil
end

local function findPlayerByUID(uid)
    for _, p in ipairs(getServerPlayers()) do
        if p:getUserID() == uid then
            return p
        end
    end
    return nil
end

local function applySupporterSubscription(target, tier)
    if tier == "sup" then
        target:removeSubscription(SUB_SUPER_SUPP)
        target:addSubscription(SUB_SUPPORTER, 0)
        return "Supporter"
    end

    target:removeSubscription(SUB_SUPPORTER)
    target:addSubscription(SUB_SUPER_SUPP, 0)
    return "Super Supporter"
end

local function resetSupporterSubscription(target)
    target:removeSubscription(SUB_SUPPORTER)
    target:removeSubscription(SUB_SUPER_SUPP)
end

local function openGiveSuppDialog(requester, target)
    local targetUID = target:getUserID()
    local targetName = target:getName()

    requester:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label|big|`wGrant Subscription|left|\n" ..
        "add_textbox|Target: `w" .. targetName .. "``|left|\n" ..
        "add_spacer|small|\n" ..
        "add_button|grant_sup|Supporter|noflags|0|0|\n" ..
        "add_button|grant_ssup|Super Supporter|noflags|0|0|\n" ..
        "add_button|grant_default|Default Player|noflags|0|0|\n" ..
        "add_quick_exit|\n" ..
        "end_dialog|givesupp_menu|Cancel||",
        0,
        function(world, player, data)
            local btn = data["buttonClicked"]
            if btn ~= "grant_sup" and btn ~= "grant_ssup" and btn ~= "grant_default" then
                return
            end

            local liveTarget = findPlayerByUID(targetUID)
            if not liveTarget then
                player:onConsoleMessage("`4Target player is no longer online.")
                player:playAudio("bleep_fail.wav")
                return
            end

            if btn == "grant_default" then
                resetSupporterSubscription(liveTarget)
                player:onConsoleMessage("`2Reset subscription of " .. liveTarget:getName() .. " to Default Player.")
                player:playAudio("piano_nice.wav")
                if liveTarget:getUserID() == player:getUserID() then
                    liveTarget:onConsoleMessage("`2Your subscription has been reset to Default Player.")
                else
                    liveTarget:onConsoleMessage("`2Your subscription has been reset to Default Player by a Developer.")
                end
                liveTarget:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
            else
                local roleName = applySupporterSubscription(liveTarget, btn == "grant_sup" and "sup" or "ssup")
                player:onConsoleMessage("`2Granted " .. roleName .. " subscription to " .. liveTarget:getName() .. ".")
                player:playAudio("piano_nice.wav")

                if liveTarget:getUserID() == player:getUserID() then
                    liveTarget:onConsoleMessage("`2Your " .. roleName .. " subscription is now active.")
                else
                    liveTarget:onConsoleMessage("`2You have been granted " .. roleName .. " subscription by a Developer.")
                end
                liveTarget:sendVariant({ "OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Subscription!", "audio/success.wav", 0 })
            end
        end
    )
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "givesupp" and cmd ~= "giveinv" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local targetName, param = args:match("^(%S+)%s*(%S*)$")

    if cmd == "giveinv" then
        if args == "" then
            player:onConsoleMessage("Usage: /giveinv <playerName> <amount>")
            return true
        end

        local target = findPlayer(targetName or "")
        if not target then
            player:onConsoleMessage("Player '" .. (targetName or "") .. "' not found or not online.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        local amount = tonumber(param)
        if not amount then
            player:onConsoleMessage("Usage: /giveinv <playerName> <amount>")
            return true
        end
        if amount <= 0 then
            player:onConsoleMessage("Invalid amount. Must be greater than zero.")
            player:playAudio("bleep_fail.wav")
            return true
        end
        local current = target:getInventorySize()
        local give    = math.min(amount, MAX_INVENTORY - current)
        if give <= 0 then
            player:onConsoleMessage(target:getName() .. " already has max inventory space (" .. current .. ").")
            player:playAudio("bleep_fail.wav")
            return true
        end
        target:upgradeInventorySpace(give)
        player:onConsoleMessage("Increased " .. target:getName() .. "'s inventory by " .. give .. " slots to " .. (current + give) .. ".")
        player:playAudio("piano_nice.wav")
        target:onConsoleMessage("Your inventory space has been increased by " .. give .. " slots!")
        target:playAudio("success.wav")
        return true
    end

    -- /givesupp
    if args == "" then
        openGiveSuppDialog(player, player)
        return true
    end

    local target = findPlayer(targetName or "")
    if not target then
        player:onConsoleMessage("Player '" .. (targetName or "") .. "' not found or not online.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    -- Backward compatibility: /givesupp <name> <sup|ssup|default>
    if param and param ~= "" then
        local tier = param:lower()
        if tier ~= "sup" and tier ~= "ssup" and tier ~= "default" then
            player:onConsoleMessage("Usage: /givesupp OR /givesupp <playerName> OR /givesupp <playerName> <sup/ssup/default>")
            player:playAudio("bleep_fail.wav")
            return true
        end

        if tier == "default" then
            resetSupporterSubscription(target)
            player:onConsoleMessage("`2Reset subscription of " .. target:getName() .. " to Default Player.")
            player:playAudio("piano_nice.wav")
            if target:getUserID() == player:getUserID() then
                target:onConsoleMessage("`2Your subscription has been reset to Default Player.")
            else
                target:onConsoleMessage("`2Your subscription has been reset to Default Player by a Developer.")
            end
            target:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
            return true
        end

        local roleName = applySupporterSubscription(target, tier)
        player:onConsoleMessage("`2Granted " .. roleName .. " subscription to " .. target:getName() .. ".")
        player:playAudio("piano_nice.wav")
        if target:getUserID() == player:getUserID() then
            target:onConsoleMessage("`2Your " .. roleName .. " subscription is now active.")
        else
            target:onConsoleMessage("`2You have been granted " .. roleName .. " subscription by a Developer.")
        end
        target:sendVariant({ "OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Subscription!", "audio/success.wav", 0 })
        return true
    end

    openGiveSuppDialog(player, target)
    return true
end)

return M
