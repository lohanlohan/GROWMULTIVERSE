-- MODULE
-- consumable_loader.lua — Consumable feature loader

local modules = {
    "green_beer",
    "coconut_tart",
    "consumable_coin",
    "antidote",
    "vile_vial",
    "firewand",
    "freezewand",
    "cursewand",
    "banwand",
    "duct_tape",
    "fireworks",
    "autofarm_speed",
    "challenge_fenrir",
    "clash_finale",
    "wolf_whistle",
    "role_inject",
    "snowball",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [consumable] ✓ " .. name)
end

_G.ConsumableSystem = M
return M
