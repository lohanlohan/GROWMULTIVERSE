-- MODULE
-- carnival_loader.lua — Carnival system loader (shared + 8 minigames + ticket booth + ringmaster)

local modules = {
    "carnival_shared",
    "concentration",
    "shooting_gallery",
    "death_race",
    "mirror_maze",
    "growganoth_gulch",
    "spiky_survivor",
    "brutal_bounce",
    "ticket_booth",
    "ringmaster",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [carnival] ✓ " .. name)
end

return {}
