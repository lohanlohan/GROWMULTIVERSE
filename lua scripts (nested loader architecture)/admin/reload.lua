-- MODULE
-- reload.lua — /rs /reloadscripts: reload all server scripts

local M = {}

local ROLE_DEV = 51

registerLuaCommand({ command = "rs",            roleRequired = ROLE_DEV, description = "Reload scripts." })
registerLuaCommand({ command = "reloadscripts", roleRequired = ROLE_DEV, description = "Reload scripts." })

onPlayerCommandCallback(function(world, player, cmd)
    local c = cmd:lower()
    if c ~= "rs" and c ~= "reloadscripts" then return false end
    if not player:hasRole(ROLE_DEV) then return false end
    reloadScripts()
    player:onConsoleMessage("`6>> Scripts have been `$reloaded``!``")
    return true
end)

return M
