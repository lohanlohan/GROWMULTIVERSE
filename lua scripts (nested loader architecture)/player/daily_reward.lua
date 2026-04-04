-- MODULE
-- daily_reward.lua — /getdaily command: klaim reward harian via chest dialog

local M = {}
local Utils  = _G.Utils
local Config = _G.Config

local CMD = "getdaily"

local MOD_ID = registerLuaPlaymod({
    modID           = -1001,
    modName         = "Daily Reward Cooldown",
    onAddMessage    = "Next reward tomorrow!",
    onRemoveMessage = "You can claim your daily reward again! Use /" .. CMD,
    iconID          = 242,
})

local REWARD_ITEMS = { 2, 2, 242 }   -- item pool (bisa duplikat untuk bobot)

registerLuaCommand({
    command      = CMD,
    roleRequired = Config.ROLES.STAFF,
    description  = "Claim a random daily reward!",
})

onPlayerCommandCallback(function(world, player, fullCommand)
    if Utils.getCmd(fullCommand) ~= "/" .. CMD then return false end
    if not Utils.isPrivileged(player) then return false end

    if player:hasMod(MOD_ID) then
        local mod = player:getMod(MOD_ID)
        Utils.msg(player, "`4Oops: `6Claim again in `#" .. Utils.formatTime(mod:getExpireTime() - os.time()) .. "``.``")
        return true
    end

    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|Claim Daily Reward|left|242|\n" ..
        "add_spacer|small|\n" ..
        "add_custom_textbox|Click a chest to see what you got!|size:small;|\n" ..
        "add_spacer|small|\n" ..
        "add_button_with_icon|chest0||staticYellowFrame|596||\n" ..
        "add_button_with_icon|chest1||staticYellowFrame|596||\n" ..
        "add_button_with_icon|chest2||staticYellowFrame|596||\n" ..
        "add_button_with_icon||END_LIST|noflags|0||\n" ..
        "end_dialog|daily_reward|Cancel||"
    )
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "daily_reward" then return false end

    if data["claimed"] ~= nil then
        Utils.msg(player, "Don't forget to play again tomorrow!")
        return true
    end
    if not Utils.isPrivileged(player)  then return true end
    if player:hasMod(MOD_ID)           then return true end
    if data["buttonClicked"] == nil    then return true end

    local rewardID = REWARD_ITEMS[math.random(1, #REWARD_ITEMS)]
    local itemObj  = getItem(rewardID)
    Utils.msg(player, "Congratulations! Today you won a " .. itemObj:getName() .. "!")

    local btn = data["buttonClicked"]
    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|" .. itemObj:getName() .. "|left|" .. rewardID .. "|\n" ..
        "add_spacer|small|\n" ..
        "embed_data|claimed|1\n" ..
        "add_custom_textbox|`9Woah you won `$\"" .. itemObj:getName() .. "\"````|size:small;|\n" ..
        "add_spacer|small|\n" ..
        "add_button_with_icon|chest0||staticYellowFrame|" .. (btn == "chest0" and rewardID or 596) .. "||\n" ..
        "add_button_with_icon|chest1||staticYellowFrame|" .. (btn == "chest1" and rewardID or 596) .. "||\n" ..
        "add_button_with_icon|chest2||staticYellowFrame|" .. (btn == "chest2" and rewardID or 596) .. "||\n" ..
        "add_button_with_icon||END_LIST|noflags|0||\n" ..
        "end_dialog|daily_reward||Thank you|"
    )

    if not player:changeItem(rewardID, 1, 0) then
        player:changeItem(rewardID, 1, 1)
    end
    player:addMod(MOD_ID, 86400)
    return true
end)

return M
