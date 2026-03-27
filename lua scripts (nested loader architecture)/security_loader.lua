-- MODULE
-- security_loader.lua — Security feature loader

local modules = {
    "anti_spam",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [security] ✓ " .. name)
end

_G.SecuritySystem = M
return M
