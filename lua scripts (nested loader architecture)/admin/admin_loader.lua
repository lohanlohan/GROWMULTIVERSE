-- MODULE
-- admin_loader.lua — Admin feature loader

local modules = {
    "give_token",
    "give_supporter",
    "give_level",
    "give_skin",
    "give_gems",
    "fake_warn",
    "online",
    "reload",
    "gsm",
    "xqsb",
    "tile_debug",
    "xdata_debug",
    "item_effect",
}
local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [admin] ✓ " .. name)
end

_G.AdminSystem = M
return M
