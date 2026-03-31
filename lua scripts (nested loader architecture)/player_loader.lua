-- MODULE
-- player_loader.lua — Player feature loader

local modules = {
    "login_message",
    "default_slots",
    "starter_pack",
    "profile",
    "set_slots",
    "custom_titles",
    "custom_help",
    "commands",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [player] ✓ " .. name)
end

_G.PlayerSystem = M
return M
