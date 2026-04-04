-- MODULE
-- events_loader.lua — Events feature loader

local modules = { "lb_event" }
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [events] ✓ " .. name)
end

_G.EventsSystem = M
return M
