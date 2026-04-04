-- MODULE
-- marvelous_missions_loader.lua — Marvelous Missions standalone loader

local modules = { "marvelous_missions" }
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [marvelous_missions] ✓ " .. name)
end

_G.MarvelousMissionsSystem = M
return M
