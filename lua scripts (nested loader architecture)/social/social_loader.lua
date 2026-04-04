-- MODULE
-- social_loader.lua — Social feature loader: portal, news, broadcast

local modules = { "social_portal", "news", "broadcast" }
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [social] ✓ " .. name)
end

_G.SocialSystem = M
return M
