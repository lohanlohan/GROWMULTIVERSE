-- MODULE
-- economy_loader.lua — Economy feature loader
-- buy.lua tidak diport (disabled/commented out di old architecture)

local modules = {
    "store",
    "daily_reward",
    "cashback_coupon",
    "transfer_pwl",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [economy] ✓ " .. name)
end

_G.EconomySystem = M
return M
