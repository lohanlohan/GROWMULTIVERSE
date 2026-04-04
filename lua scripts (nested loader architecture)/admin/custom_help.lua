-- MODULE
-- custom_help.lua — /help dan /? command: daftar command per role

local M = {}
local Utils = _G.Utils

local function collectRoles(player)
    local roleList  = getRoles() or {}
    local roleIndex = {}
    for _, role in ipairs(roleList) do
        roleIndex[role.roleID] = role
    end

    local collected = {}
    local visited   = {}

    local function addRole(id)
        if visited[id] then return end
        visited[id] = true
        local role = roleIndex[id]
        if not role then return end
        collected[#collected + 1] = role
        for _, subID in ipairs(role.allowCommandsFromRoles or {}) do
            addRole(subID)
        end
    end

    for _, role in ipairs(roleList) do
        if player:hasRole(role.roleID) then
            addRole(role.roleID)
        end
    end

    table.sort(collected, function(a, b)
        return (a.rolePriority or 0) < (b.rolePriority or 0)
    end)

    return collected
end

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = Utils.getCmd(fullCommand):gsub("^/", "")
    if cmd ~= "help" and cmd ~= "?" then return false end

    local roles  = collectRoles(player)
    local dialog = {
        "set_bg_color|0,0,0,150|",
        "set_default_color|`o",
        "add_label_with_icon|big|Server Commands|left|3524|",
        "add_smalltext|`#See Command List of Server|",
        "add_spacer|small|",
    }

    local commandOwner = {}
    for _, role in ipairs(roles) do
        local cmdList = role.allowCommands or {}
        dialog[#dialog + 1] = string.format(
            "add_label|small|`o[ %s`o] (%d commands)|left|",
            role.namePrefix .. (role.roleName or "unknown"), #cmdList
        )
        if #cmdList > 0 then
            table.sort(cmdList)
            local lines = {}
            for _, c in ipairs(cmdList) do
                if commandOwner[c] then
                    lines[#lines + 1] = "/" .. c .. " `4(used " .. commandOwner[c] .. ")`w"
                else
                    commandOwner[c] = role.roleName or "unknown"
                    lines[#lines + 1] = "/" .. c
                end
            end
            dialog[#dialog + 1] = "add_smalltext|`w" .. table.concat(lines, ", ") .. "|"
        end
    end

    dialog[#dialog + 1] = "add_quick_exit|\nend_dialog|cmdList||"

    player:onDialogRequest(table.concat(dialog, "\n"), 0, function(world, player, data)
        if data["dialog_name"] == "cmdList" then return true end
    end)
    return true
end)

return M
