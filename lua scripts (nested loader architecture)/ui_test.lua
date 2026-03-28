-- MODULE
-- ui_test.lua — Dialog UI eksperimen panel

local TILE_FLAG_HAS_EXTRA_DATA = bit.lshift(1, 0)
local AUTO_SURGEON_ID          = 14666
local ROLE_DEV                 = 51

onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd then return false end
    if cmd:lower() == "clearxdata" then
        if not player:hasRole(ROLE_DEV) then
            player:onConsoleMessage("`4No permission.")
            return true
        end
        local tiles, cleared = world:getTiles(), 0
        for _, tile in ipairs(tiles) do
            local flags = tile:getFlags()
            if bit.band(flags, TILE_FLAG_HAS_EXTRA_DATA) ~= 0 then
                local fg = tonumber(tile:getTileForeground()) or 0
                if fg ~= AUTO_SURGEON_ID then
                    tile:setFlags(bit.band(flags, bit.bnot(TILE_FLAG_HAS_EXTRA_DATA)))
                    world:updateTile(tile)
                    cleared = cleared + 1
                end
            end
        end
        player:onConsoleMessage("`2[clearxdata] Done — `w" .. cleared .. " `2tiles cleared.")
        return true
    end
end)

onPlayerCommandCallback(function(world, player, fullCommand)
    local args = {}
    for word in fullCommand:gmatch("%S+") do
        table.insert(args, word)
    end
    if args[1] == nil then return false end
    if args[1]:lower() ~= "panel" then return false end

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|54,152,198,180|\n"
    d = d .. "add_label_with_icon|big|`wUI Test Panel|left|18|\n"
    d = d .. "add_spacer|small|\n"

    -- ============================================================
    -- B showed icon on same row! Fix: reset_placement_x before icon
    -- ============================================================

    -- C1: height:1px sep + reset_placement_x + top:-80px
    d = d .. "add_smalltext|`oC1: sep + reset + top:-80px|\n"
    d = d .. "add_button_with_icon|btnC1|27W|staticGreyFrame,is_count_label|1784|27|\n"
    d = d .. "add_custom_button||display:block;height:1px;width:1.0;state:disabled;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_button||icon:7188;width:0.10;margin-top:-80px;state:disabled;|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|big|\n"

    -- C2: height:1px sep + reset_placement_x + top:-90px
    d = d .. "add_smalltext|`oC2: sep + reset + top:-90px|\n"
    d = d .. "add_button_with_icon|btnC2|27W|staticGreyFrame,is_count_label|1784|27|\n"
    d = d .. "add_custom_button||display:block;height:1px;width:1.0;state:disabled;|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_button||icon:7188;width:0.10;margin-top:-90px;state:disabled;|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|big|\n"

    -- C3: tanpa separator, langsung reset_placement_x + top:-80px
    d = d .. "add_smalltext|`oC3: no sep, reset + top:-80px|\n"
    d = d .. "add_button_with_icon|btnC3|27W|staticGreyFrame,is_count_label|1784|27|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_button||icon:7188;width:0.10;margin-top:-80px;state:disabled;|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_spacer|big|\n"

    -- C4: tanpa separator, langsung reset_placement_x + top:-90px
    d = d .. "add_smalltext|`oC4: no sep, reset + top:-90px|\n"
    d = d .. "add_button_with_icon|btnC4|27W|staticGreyFrame,is_count_label|1784|27|\n"
    d = d .. "reset_placement_x|\n"
    d = d .. "add_custom_button||icon:7188;width:0.10;margin-top:-90px;state:disabled;|\n"
    d = d .. "add_custom_break|\n"

    -- ============================================================

    d = d .. "add_spacer|big|\n"
    d = d .. "add_button|btn_close|`wClose|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|ui_test_panel|||\n"

    player:onDialogRequest(d, 0)
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialogName"] or ""
    if dlg ~= "ui_test_panel" then return false end
    return true
end)

return {}
