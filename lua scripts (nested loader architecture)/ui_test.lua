-- ui_test.lua — /uitest: confirm add_smalltext_forced behavior + fix UI card (role 51 only)

local ROLE = 51

registerLuaCommand({
    command      = "uitest",
    roleRequired = ROLE,
    description  = "Dev: experiment dialog syntax.",
})

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "uitest" then return false end
    if not player:hasRole(ROLE) then
        player:onConsoleMessage("`4Access denied.")
        return true
    end

    local function rgba(r,g,b,a) return r*16777216 + g*65536 + b*256 + a end
    local tex = "interface/large/gui_event_bar.rttex"

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "set_bg_color|20,20,60,220|\n"
    d = d .. "set_border_color|0,200,255,255|\n"
    d = d .. "add_label_with_icon|big|`wDialog Exp 9|left|18|\n"
    d = d .. "add_spacer|small|\n"

    -- =============================================
    -- SECTION 1: add_smalltext_forced — confirm behavior
    -- Is it BOLD? DOUBLE? or TWO-COLUMN?
    -- =============================================
    d = d .. "add_smalltext|`w--- smalltext vs forced comparison ---|\n"
    d = d .. "add_smalltext|`oHello World (normal)|\n"
    d = d .. "add_smalltext_forced|`oHello World (forced)||\n"
    d = d .. "add_spacer|small|\n"

    -- try: param2 as number — does it change anything?
    d = d .. "add_smalltext|`w--- forced: param2 variants ---|\n"
    d = d .. "add_smalltext_forced|`oParam2 empty|||\n"
    d = d .. "add_smalltext_forced|`oParam2 = 0|0|\n"
    d = d .. "add_smalltext_forced|`oParam2 = 1|1|\n"
    d = d .. "add_smalltext_forced|`oParam2 = left|left|\n"
    d = d .. "add_smalltext_forced|`oParam2 = right|right|\n"
    d = d .. "add_spacer|small|\n"

    -- try: right col with plain text (no color code)
    d = d .. "add_smalltext|`w--- forced: plain text both cols ---|\n"
    d = d .. "add_smalltext_forced|LeftText|RightText|\n"
    d = d .. "add_smalltext_forced|AAA|BBB|\n"
    d = d .. "add_smalltext_forced|100|200|\n"
    d = d .. "add_spacer|small|\n"

    -- =============================================
    -- SECTION 2: fixed UI card — NO textLabel+width
    -- use: full-width custom_button + label overlay for 2-col buttons
    -- =============================================
    d = d .. "add_smalltext|`w--- fixed UI card (surgeon profile) ---|\n"
    d = d .. "add_label_with_icon|small|`wSurgeon Profile|left||image:game/tiles_page17.rttex;frame:4,30;frameSize:32;|\n"
    d = d .. "add_spacer|small|\n"

    -- stats: use add_label_with_icon for each stat row
    d = d .. "add_label_with_icon|small|`oLevel: `250|left|18|\n"
    d = d .. "add_label_with_icon|small|`oSkill: `275 / 100|left|1796|\n"
    d = d .. "add_label_with_icon|small|`oOps Done: `2142|left|4298|\n"
    d = d .. "add_label_with_icon|small|`oWin Rate: `286%%|left|528|\n"
    d = d .. "add_spacer|small|\n"

    -- progress bar
    d = d .. "add_smalltext|`oSkill Progress:|\n"
    d = d .. "add_textured_progress_bar|" .. tex .. "|0|4||75|100|relative|0.8|0.02|0.007|1000|64|0.007|pb_skill|\n"
    d = d .. "add_spacer|small|\n"

    -- 2-col buttons: icon-only custom_button + label as separate element
    -- since textLabel+width = bug, use: image-only button side by side + add_smalltext below
    d = d .. "add_custom_button|btn_history|image:game/tiles_page17.rttex;image_size:32,32;frame:4,31;middle_colour:" .. rgba(40,80,160,220) .. ";border_colour:" .. rgba(60,120,220,255) .. ";width:0.22;|\n"
    d = d .. "add_custom_button|btn_reset|image:game/tiles_page17.rttex;image_size:32,32;frame:4,30;middle_colour:" .. rgba(140,30,30,220) .. ";border_colour:" .. rgba(200,50,50,255) .. ";width:0.22;|\n"
    d = d .. "reset_placement_x|\n"
    -- labels below
    d = d .. "add_custom_label|`wHistory|target:btn_history;top:1.1;left:0.1;size:small;|\n"
    d = d .. "add_custom_label|`4Reset|target:btn_reset;top:1.1;left:0.1;size:small;|\n"
    d = d .. "add_spacer|small|\n"

    -- =============================================
    -- SECTION 3: full-width custom_button — correct pattern
    -- workaround for textLabel+width bug: use display:block only, no width
    -- =============================================
    d = d .. "add_smalltext|`w--- correct 2-col pattern ---|\n"
    -- use community_button side by side (no width issues)
    d = d .. "add_community_button|btn_ok|`2Confirm|noflags|0|0|\n"
    d = d .. "add_community_button|btn_cancel|`4Cancel|noflags|0|0|\n"
    d = d .. "add_spacer|small|\n"

    d = d .. "add_button|btn_close|`wClose|noflags|0|0|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|ui_test|||\n"

    player:onDialogRequest(d, 0)
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "ui_test" then return false end
    local btn = data["buttonClicked"] or ""
    if btn ~= "" and btn ~= "btn_close" then
        player:onConsoleMessage("`oClicked: `2" .. btn)
    end
    return true
end)
