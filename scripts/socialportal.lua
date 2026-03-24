local function socialPortalOverride(player)
    player:onDialogRequest(
        "add_spacer|small|\n" ..
        "add_label_with_icon|big|`wSocial Portal|left|1366|\n" ..
        "add_spacer|small|\n" ..
        "set_custom_spacing|x:5;y:10|\n" ..
        "add_button|open_friends|`wShow Friends|noflags|0|0|\n" ..
        "add_button|open_guild|`wGuild|noflags|0|0|\n" ..
        "add_button|open_settings|`wSettings|noflags|0|0|\n" ..
        --"add_button|npcTeleportMenu|`wTeleport|noflags|0|0|\n" ..
        "add_custom_break|\n" ..
        "add_spacer|small|\n" ..
        "add_button|close_button|`wContinue|noflags|0|0|\n" ..
        "end_dialog|socialPortal|||\n" ..
        "add_custom_break|\n" ..
        "add_label_with_icon|small||left|o|\n"
    )
end

onPlayerActionCallback(function(world, player, data)
    local action = data["action"]
    
    if action == "friends" then
        socialPortalOverride(player)
        return true
    end

    return false
end)

onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] == "socialPortal" then
        if data["buttonClicked"] == "back" then
            socialPortalOverride(player)
            return true
        end
    end

    return false
end)