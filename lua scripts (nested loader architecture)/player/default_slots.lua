-- MODULE
-- default_slots.lua — Set minimum autofarm slots saat player login

local M = {}
local Config = _G.Config

onPlayerLoginCallback(function(player)
    local min = Config.SETTINGS.DEFAULT_AUTOFARM_SLOTS
    if player:getAutofarm():getSlots() < min then
        player:getAutofarm():setSlots(min)
        player:onConsoleMessage("`cYour autofarm slots have been upgraded to `2" .. min .. " SLOTS``!``")
    end
end)

return M
