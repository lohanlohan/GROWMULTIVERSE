-- MODULE
-- backpack_loader.lua — Backpack feature loader

local modules = { "backpack" }
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [backpack] ✓ " .. name)
end

_G.BackpackSystem = M
return M
