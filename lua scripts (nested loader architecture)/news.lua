-- MODULE
-- news.lua — News gazette dialog on login and /news command

local M = {}

local function showNews(player)
    local serverName               = getServerName()
    local newsBanner               = getNewsBanner()
    local newsBannerDimensions     = getNewsBannerDimensions()
    local todaysDate               = getTodaysDate()
    local todaysEvents             = getTodaysEvents()
    local currentEventDescription  = getCurrentEventDescription()
    local currentDailyDescription  = getCurrentDailyEventDescription()
    local currentRoleDescription   = getCurrentRoleDayDescription()
    local topWorld                 = getTopWorldByVisitors()
    local topWorldStr = (topWorld ~= nil) and
        "add_button|warpwotd|`#World of the Week:`` `$" .. topWorld:getName() .. "``|noflags|0|0|\nadd_spacer|small|\n"
        or ""

    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`wThe " .. serverName .. " Gazette``|left|5016|\n" ..
        "add_custom_button|game_title|image:" .. newsBanner .. ";image_size:" .. newsBannerDimensions .. ";width:0.5;state:disabled;|\n" ..
        "reset_placement_x|\n" ..
        "add_textbox|`w" .. todaysDate .. ": ``" .. todaysEvents .. "|left|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|" .. resetColor(currentEventDescription) .. "|left|\n" ..
        "add_textbox|" .. resetColor(currentDailyDescription) .. "|left|\n" ..
        "add_spacer|small|\n" ..
        "add_label_with_icon|small|`2NEW``: Prisoner NPC Arrives, he's in love with his `#Rare Locks``! Find him!``|left|482|\n" ..
        "add_label_with_icon|small|`2NEW``: Blessings Update is here! Unlock various buffs for the price of `#Soul Stones````|left|482|\n" ..
        "add_label_with_icon|small|`2NEW``: Gembot is waiting for you in `8GROWMINES`` with awesome gems for `2Ores````|left|482|\n" ..
        "add_label_with_icon|small|`2NEW``: Lot of new cool items are available in the `2Store````|left|482|\n" ..
        "add_label_with_icon|small|`6COMING SOON``: A lot of events and features are waiting for you in `2" .. serverName .. "``! Enjoy your stay!``|left|482|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|" .. resetColor(currentRoleDescription) .. "|\n" ..
        "add_spacer|small|\n" ..
        "add_label_with_icon|small|Need support? Type `$/discord`` or send in-game message to `pModerators````|left|482|\n" ..
        "add_spacer|small|\n" ..
        topWorldStr ..
        "add_label_with_icon|small|`8NOTE:`` This server is `#stable`` and never has rollback because of Anti-Rollback system.|left|4|\n" ..
        "add_spacer|small|\n" ..
        "add_button|rules|`wRules``|left|\n" ..
        "add_spacer|small|\n" ..
        "add_button|joinus|`wOK``|left|\n" ..
        "add_quick_exit|\n" ..
        "end_dialog|gazette|||"
    )
end

onPlayerLoginCallback(function(player)
    showNews(player)
end)

onPlayerCommandCallback(function(world, player, command)
    if command:lower() == "news" then
        showNews(player)
        return true
    end
    return false
end)

return M
