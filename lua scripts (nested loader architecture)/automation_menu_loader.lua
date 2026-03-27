-- MODULE
-- automation_menu_loader.lua — Automation Menu standalone loader
-- Loads: anti_consumable (registers mod) + automation_menu (UI + commands)

local modules = { "anti_consumable", "automation_menu" }
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [automation_menu] ✓ " .. name)
end

_G.AutomationMenuSystem = M
return M
