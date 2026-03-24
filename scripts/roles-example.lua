-- Roles Example script

Roles = {
    ROLE_NONE = 0,
    ROLE_VIP = 1,
    ROLE_SUPER_VIP = 2,
    ROLE_MODERATOR = 3,
    ROLE_ADMIN = 4,
    ROLE_COMMUNITY_MANAGER = 5,
    ROLE_CREATOR = 6,
    ROLE_GOD = 7,
    ROLE_DEVELOPER = 51
}

local warp = {
    command = "warp",
    roleRequired = Roles.ROLE_VIP,
    description = "This command allows you to warp to another world"
}

local buyVIPCommandData = {
    command = "buyvip",
    roleRequired = Roles.ROLE_NONE,
    description = "This command allows you to buy `$VIP`` role for 100 Diamond Lock!"
}

local demoteMyselfCommandData = {
    command = "demotemyself",
    roleRequired = Roles.ROLE_VIP, -- At least VIP
    description = "This command allows you to `$demote`` yourself!"
}

registerLuaCommand(buyVIPCommandData) -- This is just for some places such as role descriptions and help
registerLuaCommand(demoteMyselfCommandData) -- This is just for some places such as role descriptions and help
registerLuaCommand(warp)

---------------------------------------
-- WARP FUNCTION
---------------------------------------

local function warpPlayer(player, worldName)
    if not worldName or worldName == "" then
        player:onConsoleMessage("`4Oops: `6You must enter a world name!``")
        return
    end
    
    -- Warp player to the specified world
    player:warp(worldName)
    player:onConsoleMessage("`2You warped to: `#" .. worldName .. "``")
end

---------------------------------------
-- COMMAND CALLBACK
---------------------------------------

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == demoteMyselfCommandData.command then
        if not player:hasRole(demoteMyselfCommandData.roleRequired) then
            return false
        end
        player:setRole(Roles.ROLE_NONE)
        return true
    end
    
    if command:lower() == buyVIPCommandData.command then
        if player:hasRole(Roles.ROLE_VIP) then
            player:onConsoleMessage("`4Oops: `6You already have `#VIP`` role.``")
            return true
        end
        local hasDiamondLocks = player:getItemAmount(1796)
        if hasDiamondLocks < 100 then
            player:onConsoleMessage("`4Oops: `6You cannot afford `#VIP`` role, you're `#" .. 100 - hasDiamondLocks .. "`` Diamond Locks short!``")
            return true
        end
        if player:changeItem(1796, -100, 0) then
            player:setRole(Roles.ROLE_VIP)
            player:onTalkBubble(player:getNetID(), "Purchased VIP Role for 100 Diamond Locks!", 0)
            return true
        end
        player:onConsoleMessage("`4Oops: `6Something went wrong``")
        return true
    end
    
    if command:lower() == warp.command then
        if not player:hasRole(warp.roleRequired) then
            player:onConsoleMessage("`4Oops: `6You need `#VIP`` role to use this command!``")
            return true
        end
        
        -- Show warp dialog
        local dialog = ""
        dialog = "set_default_color|`w\n" ..
                 "add_label|big|World Warp|left|\n" ..
                 "add_spacer|small|\n" ..
                 "add_textbox|Enter the world name you want to warp to:|\n" ..
                 "add_textinput|world_name|World Name|World Name|27|\n" ..
                 "add_spacer|small|\n" ..
                 "add_button|warp_confirm|Warp|noflags|0|0|\n" ..
                 "add_button|close|Cancel|noflags|0|0|\n" ..
                 "add_quick_exit|\n" ..
                 "end_dialog|warp_dialog|||\n"
        
        player:onDialogRequest(dialog)
        return true
    end
    
    return false
end)

---------------------------------------
-- DIALOG CALLBACK
---------------------------------------

onPlayerDialogCallback(function(world, player, data)
    
    if data.buttonClicked == "warp_confirm" then
        local worldName = data.textInputValue
        warpPlayer(player, worldName)
        return true
    end
    
    if data.buttonClicked == "close" then
        -- Dialog closed, do nothing
        return true
    end
    
    return false
end)

