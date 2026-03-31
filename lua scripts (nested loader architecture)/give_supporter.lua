-- MODULE
-- give_supporter.lua — /givesupp /giveinv: grant subscriptions or inventory slots

local M = {}
local DB = _G.DB
local Utils = _G.Utils

local ROLE_DEV        = 51
local MAX_INVENTORY   = 396
local SUB_SUPPORTER   = 0
local SUB_SUPER_SUPP  = 1

local KNOWN_SUBSCRIPTIONS = {
    { id = 0,  name = "TYPE_SUPPORTER" },
    { id = 1,  name = "TYPE_SUPER_SUPPORTER" },
    { id = 2,  name = "TYPE_YEAR_SUBSCRIPTION" },
    { id = 3,  name = "TYPE_MONTH_SUBSCRIPTION" },
    { id = 4,  name = "TYPE_GROWPASS" },
    { id = 5,  name = "TYPE_TIKTOK" },
    { id = 6,  name = "TYPE_BOOST" },
    { id = 7,  name = "TYPE_STAFF" },
    { id = 8,  name = "TYPE_FREE_DAY_SUBSCRIPTION" },
    { id = 9,  name = "TYPE_FREE_3_DAY_SUBSCRIPTION" },
    { id = 10, name = "TYPE_FREE_14_DAY_SUBSCRIPTION" },
}

registerLuaCommand({ command = "givesupp", roleRequired = ROLE_DEV, description = "Grant Supporter/Super Supporter subscription." })
registerLuaCommand({ command = "giveinv",  roleRequired = ROLE_DEV, description = "Give inventory space to a player." })
registerLuaCommand({ command = "sublist",  roleRequired = ROLE_DEV, description = "Show active subscriptions of self/target." })

local function uidKey(player)
    if Utils and Utils.uid then
        return Utils.uid(player)
    end
    return tostring(player:getUserID())
end

local function normalizeBaseName(raw)
    local s = tostring(raw or "")
    s = s:gsub("`.", ""):gsub("^@+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^Dr%.", ""):gsub(" of Legend$", ""):gsub(" Mentor$", "")
    return s
end

local function getDefaultDisplayName(target)
    local base = ""
    if target.getRealCleanName then
        base = normalizeBaseName(target:getRealCleanName())
    end
    if base == "" and target.getCleanName then
        base = normalizeBaseName(target:getCleanName())
    end
    if base == "" then
        base = normalizeBaseName(target:getName())
    end
    if base == "" then
        base = "Player"
    end
    return "`0" .. base .. "``"
end

local function formatSubscriptionStatus(sub)
    if not sub then
        return "inactive"
    end
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
    requester:onConsoleMessage("`w[SubList] Target: `2" .. target:getName() .. "`` (UID: " .. target:getUserID() .. ")")

    local knownSet = {}
    local activeKnown = 0
    for _, entry in ipairs(KNOWN_SUBSCRIPTIONS) do
        knownSet[entry.id] = true
        local sub = target:getSubscription(entry.id)
        local status = formatSubscriptionStatus(sub)
        requester:onConsoleMessage("`o- " .. entry.name .. " (" .. entry.id .. "): `w" .. status)
        if sub ~= nil then
            activeKnown = activeKnown + 1
        end
    end

    local foundUnknown = false
    for id = 11, 64 do
        local sub = target:getSubscription(id)
        if sub ~= nil then
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

-- =======================================================
-- HIDESTATUS TRACKER
-- count even = visual showing, count odd = visual hidden
-- internalUID: flag to skip counting when WE trigger /hidestatus
-- pendingResets: delay removeSubscription by 1 tick after doAction
-- =======================================================

local pendingResets  = {}  -- uid → true
local internalUID    = {}  -- uid → true (our doAction, skip callback count)

local function getHideCount(player)
    local data = DB.getPlayer("hidestatus_v2", tostring(player:getUserID())) or {}
    return tonumber(data.count) or 0
end

local function setHideCount(player, count)
    DB.setPlayer("hidestatus_v2", tostring(player:getUserID()), { count = count })
end

local function doReset(target)
    target:removeSubscription(SUB_SUPPORTER)
    target:removeSubscription(SUB_SUPER_SUPP)
    resetSupporterPersonalization(target)
    savePlayer(target)
    pendingResets[target:getUserID()] = nil
end

local function ensureHiddenThenReset(target)
    local count = getHideCount(target)
    if count % 2 == 0 then
        -- Visual showing → /hidestatus first, doReset on next tick
        internalUID[target:getUserID()] = true
        target:doAction("action|input\n|text|/hidestatus")
        setHideCount(target, count + 1)
        pendingResets[target:getUserID()] = true
    else
        -- Already hidden → reset immediately
        doReset(target)
    end
end

onPlayerTick(function(world, player)
    local uid = player:getUserID()
    if pendingResets[uid] then
        doReset(player)
    end
end)

local function applySupporterSubscription(target, tier)
    -- Reset hidestatus counter: subscription baru = visual showing dari awal
    setHideCount(target, 0)
    if tier == "sup" then
        target:removeSubscription(SUB_SUPER_SUPP)
        target:addSubscription(SUB_SUPPORTER, 0)
        return "Supporter"
    end

    target:removeSubscription(SUB_SUPPORTER)
    target:addSubscription(SUB_SUPER_SUPP, 0)
    return "Super Supporter"
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
        DB.updatePlayer("player", uidKey(target), {
            titles = {
                useIcon = false,
                prefixDr = false,
                suffixLegend = false,
                mentorTitle = false,
            }
        })
    end

    if _G.PlayerSystem
        and _G.PlayerSystem.custom_titles
        and _G.PlayerSystem.custom_titles.resetProfile
    then
        _G.PlayerSystem.custom_titles.resetProfile(target)
        return
    end

    if target.sendVariant then
        local displayName = getDefaultDisplayName(target)
        local payload = string.format(
            "{\"PlayerWorldID\":%d,\"TitleTexture\":\"\",\"TitleTextureCoordinates\":\"0,0\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
            target:getNetID()
        )
        target:sendVariant({ "OnNameChanged", displayName, payload }, 0, target:getNetID())
    end
end

local function resetSupporterSubscription(target)
    ensureHiddenThenReset(target)
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
                if liveTarget:getUserID() == player:getUserID() then
                    liveTarget:onConsoleMessage("`2Your subscription has been reset to Default Player. You will be disconnected to refresh visuals.")
                else
                    liveTarget:onConsoleMessage("`2Your subscription has been reset to Default Player by a Developer. You will be disconnected to refresh visuals.")
                end
                liveTarget:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
                resetSupporterSubscription(liveTarget)
                player:onConsoleMessage("`2Reset subscription of " .. liveTarget:getName() .. " to Default Player.")
                player:playAudio("piano_nice.wav")
            else
                local roleName = applySupporterSubscription(liveTarget, btn == "grant_sup" and "sup" or "ssup")
                player:onConsoleMessage("`2Granted " .. roleName .. " subscription to `w" .. liveTarget:getCleanName() .. "``.")
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

-- Track /hidestatus toggles to maintain accurate parity
onPlayerCommandCallback(function(world, player, full)
    if (full or ""):lower() == "/hidestatus" then
        setHideCount(player, getHideCount(player) + 1)
    end
    return false
end)

onPlayerCommandCallback(function(world, player, full)
    local cmd, args = full:match("^(%S+)%s*(.*)$")
    if cmd ~= "givesupp" and cmd ~= "giveinv" and cmd ~= "sublist" then return false end

    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4Unknown command. `oEnter /? for a list of valid commands.")
        player:playAudio("bleep_fail.wav")
        return true
    end

    local targetName, param = args:match("^(%S+)%s*(%S*)$")

    if cmd == "sublist" then
        if args == "" then
            showSubscriptionList(player, player)
            return true
        end

        local target = findPlayer(targetName or "")
        if not target then
            player:onConsoleMessage("Player '" .. (targetName or "") .. "' not found or not online.")
            player:playAudio("bleep_fail.wav")
            return true
        end

        showSubscriptionList(player, target)
        return true
    end

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
            if target:getUserID() == player:getUserID() then
                target:onConsoleMessage("`2Your subscription has been reset to Default Player. You will be disconnected to refresh visuals.")
            else
                target:onConsoleMessage("`2Your subscription has been reset to Default Player by a Developer. You will be disconnected to refresh visuals.")
            end
            target:sendVariant({ "OnAddNotification", "", "`wYour subscription is now `oDefault Player`w.", "audio/success.wav", 0 })
            resetSupporterSubscription(target)
            player:onConsoleMessage("`2Reset subscription of " .. target:getName() .. " to Default Player.")
            player:playAudio("piano_nice.wav")
            return true
        end

        local roleName = applySupporterSubscription(target, tier)
        player:onConsoleMessage("`2Granted " .. roleName .. " subscription to `w" .. target:getCleanName() .. "``.")
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
