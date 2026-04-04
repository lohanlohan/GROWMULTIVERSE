-- MODULE
-- surgery_loader.lua — Surgery minigame system loader
-- Load order: surgery_data → surgery_engine → surgery_ui → surgery_callbacks → surgprize

local modules = {
    "surgery_data",
    "surgery_engine",
    "surgery_ui",
    "surgery_callbacks",
    "surgprize",
    "surgery_test",
}

-- Each module sets its _G global immediately after load so the next
-- module can reference it via _G.SurgeryData / _G.SurgeryEngine / etc.
local M = {}

for _, name in ipairs(modules) do
    local mod = require(name)
    M[name] = mod
    -- Map module to its global name
    local gname = ({
        surgery_data      = "SurgeryData",
        surgery_engine    = "SurgeryEngine",
        surgery_ui        = "SurgeryUI",
        surgery_callbacks = "SurgerySystem",
    })[name]
    if gname then
        _G[gname] = mod
    end
    print("  [surgery] ✓ " .. name)
end

_G.SurgeryLoader = M
return M
