-- MODULE
-- give_supporter.lua — /givesupp /giveinv /sublist: grant subscriptions or inventory slots

local M = {}
local DB = _G.DB
local Utils = _G.Utils

local ROLE_DEV = 51
local MAX_INVENTORY = 396
local SUB_SUPPORTER = 0
local SUB_SUPER_SUPP = 1

local KNOWN_SUBSCRIPTIONS = {
    { id = 0, name = "TYPE_SUPPORTER" },
    { id = 1, name = "TYPE_SUPER_SUPPORTER" },
    { id = 2, name = "TYPE_YEAR_SUBSCRIPTION" },
    { id = 3, name = "TYPE_MONTH_SUBSCRIPTION" },
    { id = 4, name = "TYPE_GROWPASS" },
    { id = 5, name = "TYPE_TIKTOK" },
    { id = 6, name = "TYPE_BOOST" },
    { id = 7, name = "TYPE_STAFF" },
    { id = 8, name = "TYPE_FREE_DAY_SUBSCRIPTION" },
    { id = 9, name = "TYPE_FREE_3_DAY_SUBSCRIPTION" },
    { id = 10, name = "TYPE_FREE_14_DAY_SUBSCRIPTION" },
}

registerLuaCommand({ command = "givesupp", roleRequired = ROLE_DEV, description = "Grant Supporter/Super Supporter subscription." })
registerLuaCommand({ command = "giveinv", roleRequired = ROLE_DEV, description = "Give inventory space to a player." })
registerLuaCommand({ command = "sublist", roleRequired = ROLE_DEV, description = "Show active subscriptions of self/target." })

local function sanitizeDisplayName(name)
    if type(name) ~= "string" then
        return ""
    end
    local cleaned = name:gsub("`.", "")
    cleaned = cleaned:gsub("^%s*(.-)%s*$", "%1")
    return cleaned
end

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

local function sendResetVariants(target)
    if not target or not target.sendVariant then
        return
    end

    target:sendVariant({ "OnTransmutateLinkDataModified" })
    target:sendVariant({ "OnSetRoleSkinsAndIcons", 6, 6, 0 })
    target:sendVariant({ "OnSetClothing", "x: 1442.000000 y: 0.000000 z: 3172.000000", "x: 0.000000 y: 3774.000000 z: 0.000000", "x: 818.000000 y: 0.000000 z: 16076.000000", 3370516479, "x: 0.000000 y: 1.000000 z: 0.000000" })
    target:sendVariant({ "OnGuildDataChanged", 0, 0, 0, 0 })
    target:sendVariant({ "OnFlagMay2019", 0 })
    target:sendVariant({ "OnClearItemTransforms" })
    target:sendVariant({ "OnBillboardChange", 6, 25038, "0,0", 1, 1 })

    local country = "us"
    if target.getCountry then
        country = target:getCountry() or country
    end
    target:sendVariant({ "OnCountryState", country })

    local clearedName = sanitizeDisplayName(target:getName() or "")
    target:sendVariant({ "OnNameChanged", clearedName, "{}" })
end

local function resetSupporterPersonalization(target)
    if target.resetNickname then
        target:resetNickname()
    end
    if target.setCountryFlagBackground then
        target:setCountryFlagBackground(0)
    end
    if target.setCountryFlagForeground then
        target:setCountryFlagForeground(0)
    end
    if DB and DB.updatePlayer then
        DB.updatePlayer("player", tostring(target:getUserID()), {
            titles = { useIcon = false, prefixDr = false, suffixLegend = false, mentorTitle = false }
        })
    end
end

local function resetSupporterSubscription(target)
    if not target then return end
    target:removeSubscription(SUB_SUPPORTER)
    target:removeSubscription(SUB_SUPER_SUPP)
    resetSupporterPersonalization(target)
    sendResetVariants(target)
end

local function applySupporterSubscription(target, tier)
    if not target then return "" end
    target:removeSubscription(SUB_SUPPORTER)
    target:removeSubscription(SUB_SUPER_SUPP)
    sendResetVariants(target)

    if tier == "sup" then
        target:addSubscription(SUB_SUPPORTER, 0)
        return "Supporter"
    elseif tier == "ssup" then
        target:addSubscription(SUB_SUPER_SUPP, 0)
        return "Super Supporter"
    end
    return ""
end

local function formatSubscriptionStatus(sub)
    if not sub then return "inactive" end
    if sub.isPermanent and sub:isPermanent() then
        return "active (permanent)"
    end
    if sub.getExpireTime then
        local exp = sub:getExpireTime()
        if exp and exp > 0 then
            return "active (expires=" .. exp .. ")"
        end
    end
    return "active"
end

local function showSubscriptionList(requester, target)
    if not requester or not target then return end
    requester:onConsoleMessage("`w[SubList] Target: `2" .. target:getName() .. "`` (UID: " .. target:getUserID() .. ")")

    local activeKnown = 0
    for _, entry in ipairs(KNOWN_SUBSCRIPTIONS) do
        local sub = target:getSubscription(entry.id)
        local status = formatSubscriptionStatus(sub)
        requester:onConsoleMessage("`o- " .. entry.name .. " (" .. entry.id .. "): `w" .. status)
        if sub then activeKnown = activeKnown + 1 end
    end

    local foundUnknown = false
    for id = 11, 64 do
        local sub = target:getSubscription(id)
        if sub then
            if not foundUnknown then
                requester:onConsoleMessage("`w[SubList] Non-standard active IDs detected:")
                foundUnknown = true
            end
            requester:onConsoleMessage("`o- ID " .. id .. ": `w" .. formatSubscriptionStatus(sub))
        end
    end

    if activeKnown == 0 and not foundUnknown then
        requester:onConsoleMessage("`4[SubList] No active subscriptions.")
    end
end

local function openGiveSuppDialog(requester, target)
    if not requester or not target then return end
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
            local actor = player or requester
            if not actor or not data then return end
            local btn = (data.buttonClicked or ""):lower():match("^([^|]+)") or ""
            if btn == "" then
                if data.grant_sup then btn = "grant_sup" end
                if data.grant_ssup then btn = "grant_ssup" end
                if data.grant_default then btn = "grant_default" end
            end

            local liveTarget = findPlayerByUID(targetUID) or target
            if not liveTarget then
                actor:onConsoleMessage("`4Target player is no longer online.")
                actor:playAudio("bleep_fail.wav")
                return
            end

            if btn == "grant_default" then
                resetSupporterSubscription(liveTarget)
                actor:onConsoleMessage("`2Reset subscription of " .. liveTarget:getName() .. " to Default Player.")
                actor:playAudio("piano_nice.wav")
                liveTarget:onConsoleMessage("`2Your subscription has been reset to Default Player.")
                liveTarget:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
                return
            end

            local tier = (btn == "grant_sup" and "sup") or (btn == "grant_ssup" and "ssup")
            local roleName = applySupporterSubscription(liveTarget, tier)
            if roleName ~= "" then
                actor:onConsoleMessage("`2Granted " .. roleName .. " subscription to " .. liveTarget:getName() .. ".")
                actor:playAudio("piano_nice.wav")
                liveTarget:onConsoleMessage("`2Your " .. roleName .. " subscription is now active.")
                liveTarget:sendVariant({ "OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Subscription!", "audio/success.wav", 0 })
            end
        end
    )
end

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if not cmd then return false end
    cmd = cmd:lower():gsub("^/", "")

    if cmd ~= "givesupp" and cmd ~= "giveinv" and cmd ~= "sublist" then
        return false
    end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    if cmd == "sublist" then
        if args == "" then
            showSubscriptionList(player, player)
            return true
        end
        local target = findPlayer(args)
        if not target then
            player:onConsoleMessage("Player '" .. args .. "' not found or not online.")
            player:playAudio("bleep_fail.wav")
            return true
        end
        showSubscriptionList(player, target)
        return true
    end

    if cmd == "giveinv" then
        local targetName, amountString = args:match("^(%S+)%s*(%S*)$")
        if not targetName or amountString == "" then
            player:onConsoleMessage("Usage: /giveinv <playerName> <amount>")
            return true
        end
        local target = findPlayer(targetName)
        if not target then
            player:onConsoleMessage("Player '" .. targetName .. "' not found or not online.")
            player:playAudio("bleep_fail.wav")
            return true
        end
        local amount = tonumber(amountString)
        if not amount or amount <= 0 then
            player:onConsoleMessage("Invalid amount. Must be greater than zero.")
            player:playAudio("bleep_fail.wav")
            return true
        end
        local current = target:getInventorySize()
        local give = math.min(amount, MAX_INVENTORY - current)
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

    -- givesupp
    local targetName, param = args:match("^(%S+)%s*(%S*)$")
    if targetName == "" then
        openGiveSuppDialog(player, player)
        return true
    end

    local target = findPlayer(targetName)
    if not target then
        openGiveSuppDialog(player, player)
        return true
    end

    if param == "" then
        openGiveSuppDialog(player, target)
        return true
    end

    local tier = param:lower()
    if tier == "default" then
        resetSupporterSubscription(target)
        player:onConsoleMessage("`2Reset subscription of " .. target:getName() .. " to Default Player.")
        target:onConsoleMessage("`2Your subscription has been reset to Default Player.")
        target:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
        return true
    end

    if tier ~= "sup" and tier ~= "ssup" then
        player:onConsoleMessage("Usage: /givesupp OR /givesupp <playerName> OR /givesupp <playerName> <sup/ssup/default>")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local roleName = applySupporterSubscription(target, tier)
    player:onConsoleMessage("`2Granted " .. roleName .. " subscription to " .. target:getName() .. ".")
    target:onConsoleMessage("`2You have been granted " .. roleName .. " subscription.")
    target:sendVariant({ "OnAddNotification", "", "`wYou received `2" .. roleName .. "`w Subscription!", "audio/success.wav", 0 })
    return true
end)

return M
