-- MODULE
-- xqsb.lua — /qsb: Quantum Broadcast (role 51/7/6)

local M = {}

registerLuaCommand({ command = "qsb", roleRequired = 51, description = "Quantum Broadcast." })

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "qsb" then return false end

    if not (player:hasRole(51) or player:hasRole(7) or player:hasRole(6)) then
        player:sendVariant({ "OnConsoleMessage", "You don't have a valid role." })
        return true
    end

    local text = full:match("^%S+%s+(.+)$")
    if not text or text == "" then
        player:sendVariant({ "OnConsoleMessage", "`oUsage: /qsb <text>" })
        return true
    end

    local senderName     = player:getName()
    local formatted      = string.format("`cQuantum Broadcast [`0From `c%s`0]: `^%s", senderName, text)
    local notifText      = string.format("[`c%s``] `o\n`^%s", senderName, text)

    for _, p in ipairs(getServerPlayers() or {}) do
        if p:isOnline() then
            p:sendVariant({ "OnConsoleMessage", formatted })
            p:sendVariant({ "OnAddNotification", "interface/science_button.rttex", notifText, "audio/hub_open.wav" })
        end
    end

    return true
end)

return M
