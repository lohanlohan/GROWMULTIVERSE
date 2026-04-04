-- MODULE
-- bb_scan.lua — /bbscan: scan Brutal Bounce spawn zones in CARNIVAL_2

local M = {}

local WORLD   = "CARNIVAL_2"
local BB_AREA = { x1 = 77, y1 = 20, x2 = 88, y2 = 36 }

onPlayerCommandCallback(function(world, player, full)
    if world:getName():upper() ~= WORLD then return false end
    local args = {}
    for w in full:gmatch("%S+") do args[#args+1] = w end
    if (args[1] or ""):lower() ~= "bbscan" then return false end

    if not player:hasRole(51) then
        player:onConsoleMessage("`4No permission.")
        return true
    end

    local zones = {}
    for tx = BB_AREA.x1 - 1, BB_AREA.x2 - 1 do
        for ty = BB_AREA.y1 - 1, BB_AREA.y2 - 1 do
            local tile = world:getTile(tx, ty)
            if tile then
                local fg = tile:getTileForeground()
                local bg = tile:getTileBackground()
                if (fg == 0 or fg == nil) and bg ~= nil and bg ~= 0 then
                    zones[#zones+1] = "(" .. (tx+1) .. "," .. (ty+1) .. ")"
                end
            end
        end
    end

    player:onConsoleMessage("`2BB Scan: `w" .. #zones .. "`2 spawn zones found.")
    local CHUNK = 8
    for i = 1, #zones, CHUNK do
        local line = {}
        for j = i, math.min(i + CHUNK - 1, #zones) do line[#line+1] = zones[j] end
        player:onConsoleMessage("`o" .. table.concat(line, "  "))
    end
    return true
end)

return M
