-- MODULE
-- login_message.lua — Welcome message saat player login

local M = {}

onPlayerLoginCallback(function(player)
    player:onConsoleMessage("`2Welcome to GrowMultiverse``")
    player:onConsoleMessage("`4Try the best profit to carry on your journey on this server``")
    player:onConsoleMessage("Server is owned by `6@Lohan``")
end)

return M
