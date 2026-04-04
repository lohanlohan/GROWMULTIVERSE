-- MODULE
-- machine_loader.lua — Machine feature loader (Rent Entrance + Grow-o-Matic)

local modules = {
    "rent_entrance",
    "grow_matic",
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [machine] ✓ " .. name)
end

_G.MachineSystem = M
return M
