-- MODULE
-- give_skin.lua — /giveskin: set role quest levels (skins/icons) via dialog

local M = {}

local ROLE_ADMIN = 7
local ROLE_DEV   = 51
local UI         = "giveskin_ui"

local ROLE_KEYS = {
    farmer    = 0,
    builder   = 1,
    fishing   = 2,
    chef      = 3,
    chief     = 3,
    surgery   = 4,
    startopia = 5,
}
local ROLE_ORDER = { "farmer", "builder", "fishing", "chef", "surgery", "startopia" }

local function isStaff(player)
    return player:hasRole(ROLE_ADMIN) or player:hasRole(ROLE_DEV)
end

local function findPlayer(name)
    if not name or name == "" then return nil end
    local needle = name:lower()
    for _, p in ipairs(getServerPlayers() or {}) do
        local nm = (p.getCleanName and p:getCleanName()) or p:getName()
        if nm and nm:lower() == needle then return p end
    end
    return nil
end

local function openUI(sender, presetTarget)
    if not isStaff(sender) then
        sender:onConsoleMessage("`4No permission.")
        return
    end
    local d = {}
    d[#d+1] = "set_default_color|`w\n"
    d[#d+1] = "add_label_with_icon|big|Give Role Skins / Icons|left|242|\n"
    d[#d+1] = "add_textbox|Enter exact player name.|\n"
    d[#d+1] = string.format("add_text_input|gs_target|Player Name|%s|24|\n", presetTarget or "")
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_textbox|Select roles to set (or tick All).|\n"
    d[#d+1] = "add_checkbox|gs_all|All roles|0|\n"
    for _, key in ipairs(ROLE_ORDER) do
        local label = key:sub(1,1):upper() .. key:sub(2)
        d[#d+1] = string.format("add_checkbox|gs_%s|%s|0|\n", key, label)
    end
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_textbox|Level 10 unlocks all icons/skins.|\n"
    d[#d+1] = "add_text_input|gs_level|Level|10|5|numeric|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_button|gs_set10|Set 10|noflags|\n"
    d[#d+1] = "add_button|gs_set0|Set 0|noflags|\n"
    d[#d+1] = "add_spacer|small|\n"
    d[#d+1] = "add_button|gs_apply|`2Apply|noflags|\n"
    d[#d+1] = "add_button|gs_close|Close|noflags|\n"
    d[#d+1] = "end_dialog|" .. UI .. "|||\n"
    sender:onDialogRequest(table.concat(d))
end

registerLuaCommand({ command = "giveskin", roleRequired = ROLE_DEV, description = "Open set Role Quest levels." })

onPlayerCommandCallback(function(world, player, cmd)
    if cmd == "giveskin" then
        openUI(player, "")
        return true
    end
    return false
end)

onPlayerDialogCallback(function(world, player, data)
    if data.dialog_name ~= UI then return false end
    local btn = data.buttonClicked or ""

    if btn == "gs_close" then return true end

    if btn == "gs_set10" then
        openUI(player, tostring(data.gs_target or ""))
        return true
    end
    if btn == "gs_set0" then
        openUI(player, tostring(data.gs_target or ""))
        return true
    end

    if btn == "gs_apply" then
        if not isStaff(player) then player:onConsoleMessage("`4No permission."); return true end

        local targetName = tostring(data.gs_target or "")
        local target = findPlayer(targetName)
        if not target then
            player:onConsoleMessage("`4Player not found: `w" .. (targetName == "" and "(empty)" or targetName))
            openUI(player, targetName)
            return true
        end

        local level = math.max(0, math.min(tonumber(data.gs_level or "10") or 10, 10))
        local enums = {}
        local all = tostring(data.gs_all or "0") == "1"
        if all then
            for _, key in ipairs(ROLE_ORDER) do enums[#enums+1] = ROLE_KEYS[key] end
        else
            for _, key in ipairs(ROLE_ORDER) do
                if tostring(data["gs_" .. key] or "0") == "1" then
                    enums[#enums+1] = ROLE_KEYS[key]
                end
            end
        end

        if #enums == 0 then
            player:onConsoleMessage("`4No role selected.")
            openUI(player, targetName)
            return true
        end

        for _, enumVal in ipairs(enums) do
            target:setRoleQuestLevel(enumVal, level)
        end
        target:onConsoleMessage("`2Your role levels were updated to `#" .. level .. "`2 (" .. #enums .. " roles).")
        target:playAudio("piano_nice.wav")
        player:onConsoleMessage(string.format("`2Updated `w%s`2 → level `#%d`2 (%d roles).", target:getName(), level, #enums))
        return true
    end

    return true
end)

return M
