-- MODULE
-- role_inject.lua — Consumable role injectors
--   25036 = Developer Role Inject → setRole(51)
--   25038 = Default Role Inject   → setRole(0)

local M = {}

local DEVELOPER_ROLE_INJECT = 25036
local DEFAULT_ROLE_INJECT   = 25038

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == DEVELOPER_ROLE_INJECT then
        player:changeItem(DEVELOPER_ROLE_INJECT, -1, 0)
        player:setRole(51)
        player:onConsoleMessage("`2[Role Inject] Developer role applied (ID: 51).")
        return true
    end

    if itemID == DEFAULT_ROLE_INJECT then
        player:changeItem(DEFAULT_ROLE_INJECT, -1, 0)
        player:setRole(0)
        player:onConsoleMessage("`o[Role Inject] Role reset to Default (ID: 0).")
        return true
    end

    return false
end)

return M
