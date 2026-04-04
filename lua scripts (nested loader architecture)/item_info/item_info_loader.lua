-- MODULE
-- item_info_loader.lua — Item Info feature loader

local modules = {
    "item_categorizer",
    "item_browser",
    "item_info",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [item_info] ✓ " .. name)
end

_G.ItemInfoSystem = M
return M
