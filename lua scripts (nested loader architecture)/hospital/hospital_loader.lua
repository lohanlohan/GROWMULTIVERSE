-- MODULE
-- hospital_loader.lua — Loads all hospital sub-modules in dependency order

local modules = {
    "malady_rng",
    "hospital",
    "reception_desk",
    "operating_table",
    "auto_surgeon"
}

local M = {}
for _, name in ipairs(modules) do
    M[name] = require(name)
    print("  [hospital] ✓ " .. name)
end
return M
