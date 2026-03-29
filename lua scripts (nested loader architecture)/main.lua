-- main.lua
local ALLOWED_IDS = { ["4134"] = true, ["4552"] = true }
if not ALLOWED_IDS[tostring(getServerID())] then
    print("[main] server ID not allowed: " .. tostring(getServerID()))
    return
end

_G.Utils  = require("utils")
_G.Config = require("config")
_G.DB     = require("db")
require("logger")
require("security_loader")
require("economy_loader")
require("player_loader")
require("machine_loader")
require("item_info_loader")
require("consumable_loader")
require("backpack_loader")
require("carnival_loader")
require("hospital_loader")
require("surgery_loader")
require("events_loader")
require("social_loader")
require("admin_loader")
require("marvelous_missions_loader")
require("automation_menu_loader")
print("[main] all loaders OK")
