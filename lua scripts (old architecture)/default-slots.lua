-- Default Slots script

local DEFAULT_SLOTS = 3

onPlayerLoginCallback(function(player)
    if player:getAutofarm():getSlots() < DEFAULT_SLOTS then
        player:getAutofarm():setSlots(DEFAULT_SLOTS)
        player:onConsoleMessage("`cYour autofarm slots have been upgraded to `2" .. DEFAULT_SLOTS .. " SLOTS``!``")
    end
end)
