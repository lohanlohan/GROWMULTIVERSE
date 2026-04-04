-- MODULE
-- premium_store_loader.lua — Premium Store feature loader

local M       = {}
local modules = {
    "premium_store_data",
    "premium_currency",
    "premium_store_ui",
    "premium_store_callbacks",
}

for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [premium_store] ✓ " .. name)
end

-- Expose globally for cross-module access
_G.StoreData        = M["premium_store_data"]
_G.PremiumCurrency  = M["premium_currency"]
_G.StoreUI          = M["premium_store_ui"]

return M
