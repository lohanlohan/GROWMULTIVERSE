-- MODULE
-- premium_currency.lua — Premium Gems balance management + /premgems admin command

local M  = {}
local DB = _G.DB

local PG_ITEM_ID  = 20234  -- icon only (for dialog display)
local DB_KEY      = "premium_gems"
local ROLE_ADMIN  = 51

-- =======================================================
-- BALANCE API — stored in our own DB per player
-- =======================================================

function M.getBalance(player)
    local uid  = player:getUserID()
    local data = DB.getPlayer(DB_KEY, uid) or {}
    return tonumber(data.balance) or 0
end

function M.give(player, amount)
    local uid   = player:getUserID()
    local data  = DB.getPlayer(DB_KEY, uid) or {}
    data.balance = (tonumber(data.balance) or 0) + math.floor(amount)
    DB.setPlayer(DB_KEY, uid, data)
end

-- Returns true if successfully spent, false if insufficient
function M.spend(player, amount)
    local uid   = player:getUserID()
    local data  = DB.getPlayer(DB_KEY, uid) or {}
    local bal   = tonumber(data.balance) or 0
    if bal < amount then return false end
    data.balance = bal - math.floor(amount)
    DB.setPlayer(DB_KEY, uid, data)
    return true
end

-- =======================================================
-- /premgems command
-- =======================================================

registerLuaCommand({
    command      = "premgems",
    roleRequired = ROLE_ADMIN,
    description  = "Admin: give Premium Gems to a player.",
})

onPlayerCommandCallback(function(world, player, full)
    local args = {}
    for w in full:gmatch("%S+") do args[#args + 1] = w end
    local cmd = (args[1] or ""):lower()
    if cmd ~= "premgems" then return false end
    if not player:hasRole(ROLE_ADMIN) then
        player:onTalkBubble(player:getNetID(), "`4Access denied.", 0)
        return true
    end

    local targetName = args[2]
    local amount     = tonumber(args[3])

    if not targetName or not amount or amount <= 0 then
        player:onConsoleMessage("`wUsage: /premgems `2<GrowID> <amount>")
        return true
    end

    -- Show confirmation panel
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|15,10,3,250|\n"
    d = d .. "set_border_color|200,165,40,255|\n"
    d = d .. "add_label_with_icon|big|`wGive Premium Gems|left|" .. PG_ITEM_ID .. "|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_textbox|Give `2" .. math.floor(amount) .. " `wPremium Gems`` to `2" .. targetName .. "``?|\n"
    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_confirm|`2Confirm|noflags|0|0|\n"
    d = d .. "add_button|btn_cancel|`4Cancel|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    -- Store target name in global table keyed by admin name to avoid encoding issues
    _G.__premgemsQueue = _G.__premgemsQueue or {}
    _G.__premgemsQueue[player:getName()] = { targetName = targetName, amount = math.floor(amount) }

    d = d .. "end_dialog|premgems_confirm|||\n"
    player:onDialogRequest(d, 0)
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    if dlg ~= "premgems_confirm" then return false end
    if not player:hasRole(ROLE_ADMIN) then return true end

    local btn = data["buttonClicked"] or ""
    _G.__premgemsQueue = _G.__premgemsQueue or {}
    local q = _G.__premgemsQueue[player:getName()]
    _G.__premgemsQueue[player:getName()] = nil

    if btn ~= "btn_confirm" or not q then return true end

    -- Find player by name
    local target = nil
    local targets = getPlayerByName(q.targetName)
    if targets and #targets > 0 then
        target = targets[1]
    end

    if not target then
        player:onConsoleMessage("`4Player `w" .. q.targetName .. "`` is not online.")
        return true
    end

    M.give(target, q.amount)
    player:onConsoleMessage("`2Gave `w" .. q.amount .. " `2Premium Gems to `w" .. q.targetName .. "``.")
    target:onConsoleMessage("`2You received `w" .. q.amount .. " Premium Gems`` from an admin!")
    target:onTalkBubble(target:getNetID(), "`2+" .. q.amount .. " Premium Gems!", 0)
    return true
end)

return M
