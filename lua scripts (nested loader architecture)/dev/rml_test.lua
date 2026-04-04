-- rml_test.lua — /rmltest: discover sidebar PG button callback (role 51 only)

local ROLE = 51

registerLuaCommand({
    command      = "rmltest",
    roleRequired = ROLE,
    description  = "Dev: discover sidebar PG button callback.",
})

onPlayerCommandCallback(function(world, player, full)
    local args = {}
    for w in full:gmatch("%S+") do args[#args + 1] = w end
    local cmd = (args[1] or ""):lower()
    if cmd ~= "rmltest" then return false end
    if not player:hasRole(ROLE) then return true end

    local sub = args[2] or "log"
    _G.__rmlLog = _G.__rmlLog or {}

    if sub == "log" then
        _G.__rmlLog[player:getName()] = true
        player:onConsoleMessage("`2Logging ON. Click the PG sidebar button now.")
    elseif sub == "off" then
        _G.__rmlLog[player:getName()] = nil
        player:onConsoleMessage("`4Logging OFF.")
    end
    return true
end)

-- Log ALL incoming variants from player
onPlayerVariantCallback(function(world, player, variant, delay, netID)
    if not (_G.__rmlLog and _G.__rmlLog[player:getName()]) then return false end
    local v0 = tostring(variant[1] or "nil")
    if v0 ~= "OnPlayerMoved" and v0 ~= "OnSetPos" and v0 ~= "OnSetHeroState"
       and v0 ~= "OnSpawn" and v0 ~= "OnSendToServer" then
        player:onConsoleMessage("`3[VAR] " .. v0 .. " | " .. tostring(variant[2] or ""))
    end
    return false
end)

-- Log ALL dialog callbacks from player
onPlayerDialogCallback(function(world, player, data)
    if not (_G.__rmlLog and _G.__rmlLog[player:getName()]) then return false end
    local dlg = data["dialog_name"] or ""
    local btn = data["buttonClicked"] or ""
    if dlg ~= "" then
        player:onConsoleMessage("`2[DLG] name=" .. dlg .. " btn=" .. btn)
    end
    return false
end)
