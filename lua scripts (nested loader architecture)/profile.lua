-- MODULE
-- profile.lua — Player profile dialog (wrench self)

local M = {}
local Utils = _G.Utils
local ROLE_DEVELOPER = 51

-- ─── Local constants ───────────────────────────────────────────────
local ProfileCat = {
    INFO_MENU         = 0,
    LEVEL_UP_MENU     = 1,
    SKILLS_MENU       = 2,
    QUESTS_MENU       = 3,
    BADGES_MENU       = 4,
    CHEATS_MENU       = 5,
    LOCKED_WORLDS_MENU = 6,
}

local PlayerSubscriptions = {
    TYPE_SUPPORTER        = 0,
    TYPE_SUPER_SUPPORTER  = 1,
    TYPE_YEAR_SUBSCRIPTION = 2,
    TYPE_MONTH_SUBSCRIPTION = 3,
    TYPE_GROWPASS         = 4,
    TYPE_TIKTOK           = 5,
    TYPE_BOOST            = 6,
    TYPE_STAFF            = 7,
    TYPE_FREE_DAY_SUBSCRIPTION = 8,
    TYPE_FREE_3_DAY_SUBSCRIPTION = 9,
    TYPE_FREE_14_DAY_SUBSCRIPTION = 10,
}

local PlayerClothes = { HAND_ITEM = 5 }

local PlayerStatus = {
    PLAYER_ONLINE = 0,
    PLAYER_BUSY   = 1,
    PLAYER_AWAY   = 2,
}

local PlayerStats = { FiresPutout = 29 }

-- ─── Helpers ───────────────────────────────────────────────────────
--local function shortenNumber(n)
--     local suffixes = { "", "k", "m", "b", "t" }
--     local idx = 1
--     while n >= 1000 and idx < #suffixes do
--         n = n / 1000
--         idx = idx + 1
--     end
--     local precision = (n < 10) and 2 or 1
--     return string.format("%." .. precision .. "f%s", n, suffixes[idx])
-- end

local function canAccessBillboard(player)
    return player:getSubscription(PlayerSubscriptions.TYPE_SUPPORTER) ~= nil
        or player:getSubscription(PlayerSubscriptions.TYPE_SUPER_SUPPORTER) ~= nil
        or player:hasRole(ROLE_DEVELOPER)
end

-- ─── Main profile builder ──────────────────────────────────────────
local function onProfile(world, player, cat, flags)
    local tabData = ""

    if cat == ProfileCat.INFO_MENU then
        -- Active effects
        local effectLines = {}
        for _, fx in ipairs(player:getMods()) do
            local name = fx:getName(player)
            if name ~= "" then
                local timeLeft = (fx:getExpireTime() ~= 0)
                    and " (" .. formatTime(fx:getExpireTime(), os.time()) .. " left)"
                    or ""
                local desc = ""
                if player:getClothingItemID(PlayerClothes.HAND_ITEM) == 2286 then
                    desc = " `o" .. fx:getDescription(player) .. "``"
                end
                effectLines[#effectLines + 1] =
                    "add_label_with_icon|small|`w" .. name .. "``" .. timeLeft .. desc .. "|left|" .. fx:getItemID() .. "|"
            end
        end

        -- Supporter status
        local supporterStatus = "You are not yet a `2Supporter`` or `5Super Supporter``."
        if player:getSubscription(PlayerSubscriptions.TYPE_SUPER_SUPPORTER) ~= nil then
            supporterStatus = "You are a `5Super Supporter`` and have the `wRecycler`` and `w/warp``."
        elseif player:getSubscription(PlayerSubscriptions.TYPE_SUPPORTER) ~= nil then
            supporterStatus = "You are a `5Supporter`` and have the `wRecycler``."
        end

        -- Standing note
        local standingNote = ""
        if world:getOwner() ~= nil then
            local tile = world:getTile(player:getBlockPosX(), player:getBlockPosY())
            if tile ~= nil then
                standingNote = "add_textbox|`oYou are standing on the note \"" .. tile:getNote() .. "\".``|left|\n"
            end
        end

        -- Online status banner
        local statusBanner = "interface/large/gui_wrench_online_status_1green.rttex"
        if player:getOnlineStatus() == PlayerStatus.PLAYER_AWAY then
            statusBanner = "interface/large/gui_wrench_online_status_2yellow.rttex"
        elseif player:getOnlineStatus() == PlayerStatus.PLAYER_BUSY then
            statusBanner = "interface/large/gui_wrench_online_status_3red.rttex"
        end

        -- Home world
        local homeInfo = ""
        local homeID = player:getHomeWorldID()
        if homeID ~= 0 then
            local hw = getWorld(homeID)
            if hw ~= nil then
                homeInfo = "add_smalltext|`oHome World: " .. hw:getName() .. "``|left|\n"
            end
        end

        local playtime   = string.format("%.2f", player:getPlaytime() / 3600)
        local worldCount = world:getVisiblePlayersCount()
        local effectStr  = (#effectLines > 0)
            and "add_textbox|`wActive effects:``|left|\n" .. table.concat(effectLines, "\n") .. "\nadd_spacer|small|\n"
            or ""
        local billboardButton = canAccessBillboard(player)
            and "add_custom_button|billboard_edit|image:interface/large/gui_wrench_edit_billboard.rttex;image_size:400,260;width:0.19;|\n"
            or ""

        tabData =
            "add_progress_bar|" .. player:getName() .. "|big|Level " .. player:getLevel() ..
            "|" .. (player:getLevel() == getMaxLevel() and player:getRequiredXP() or player:getXP()) ..
            "|" .. player:getRequiredXP() ..
            "|" .. (player:getLevel() == getMaxLevel() and "(MAX!)" or "(" .. player:getXP() .. "/" .. player:getRequiredXP() .. ")") ..
            "|00000000|\n" ..
            "add_spacer|small|\n" ..
            player:getSubscriptionInfo() ..
            player:getProfileGuildInfo() ..
            player:getProfileGuildJoinButton() ..
            player:getProfileAccessButton() ..
--            player:getCardBattleInfo() ..
            "set_custom_spacing|x:5;y:10|\n" ..
            "add_custom_button|open_personalize_profile|image:interface/large/gui_wrench_personalize_profile.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|set_online_status|image:" .. statusBanner .. ";image_size:400,260;width:0.19;|\n" ..
            billboardButton ..
            "add_custom_button|wardrobe_customization|image:interface/large/gui_wrench_wardrobe.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|seed_diary_customization|image:interface/large/gui_wrench_seed_diary.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|notebook_edit|image:interface/large/gui_wrench_notebook.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|goals|image:interface/large/gui_wrench_goals_quests.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|bonus|image:interface/large/gui_wrench_daily_bonus_active.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|my_worlds|image:interface/large/gui_wrench_my_worlds.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|alist|image:interface/large/gui_wrench_achievements.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_label|(" .. player:getUnlockedAchievementsCount() .. "/" .. getAchievementsCount() .. ")|target:alist;top:0.72;left:0.5;size:small|\n" ..
            "add_custom_button|emojis|image:interface/large/gui_wrench_growmojis.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|marvelous_missions|image:interface/large/gui_wrench_marvelous_missions.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|title_edit|image:interface/large/gui_wrench_title.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|wrench_customization|image:interface/large/gui_wrench_customization.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|trades|image:interface/large/gui_wrench_trades.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|backpack|image:interface/large/gui_wrench_backpack.rttex;image_size:400,260;width:0.19;|\n" ..
--            "add_custom_label|(" .. player:getBackpackUsedSize() .. " items)|target:backpack;top:0.72;left:0.5;size:small|\n" ..
            "add_custom_button|open_worldlock_storage|image:interface/large/gui_wrench_auction.rttex;image_size:400,260;width:0.19;|\n" ..
            "add_custom_button|tab_" .. ProfileCat.CHEATS_MENU + 1 .. "|image:interface/large/gui_wrench_automation.rttex;image_size:400,260;width:0.19;|\n" ..
            ((player:getGuildID() ~= 0) and "add_custom_button|guild_notebook|image:interface/large/gui_wrench_guild_notebook.rttex;image_size:400,260;width:0.19;|\n" or "") ..
            ((world:isGameActive() and world:getOwner():getUserID() == player:getUserID()) and "add_custom_button|end_game|image:interface/large/gui_wrench_end_game.rttex;image_size:400,260;width:0.19;|\n" or "") ..
            player:getTransformProfileButtons() ..
            "add_custom_break|\n" ..
            "add_spacer|small|\n" ..
            "set_custom_spacing|x:0;y:0|\n" ..
            effectStr ..
            "add_smalltext|Fires Put Out: " .. Utils.formatNum(player:getStats(PlayerStats.FiresPutout)) .. "|left|\n" ..
            "add_spacer|small|\n" ..
            "add_textbox|`oYou have `w" .. player:getInventorySize() .. "`` backpack slots.``|left|\n" ..
            "add_textbox|`oCurrent world: `w" .. player:getWorldName() ..
                "`` (`w" .. math.floor(player:getPosX() / 32 + 1) ..
                "``, `w" .. math.floor(player:getPosY() / 32 + 1) ..
                "``) (`w" .. Utils.formatNum(worldCount) .. "`` " ..
                (worldCount == 1 and "person" or "people") .. ")````|left|\n" ..
            homeInfo ..
            "add_textbox|`o" .. supporterStatus .. "``|left|\n" ..
            standingNote ..
            "add_spacer|small|\n" ..
            "add_textbox|`oTotal time played: `w" .. playtime ..
                "`` hours. Account created `w" .. player:getAccountCreationDateStr() .. "`` days ago.``|left|\n" ..
            "add_spacer|small|\n"
    else
        tabData = player:getClassicProfileContent(cat, flags)
    end

    local isInfo = (cat == ProfileCat.INFO_MENU)
    player:onDialogRequest(
        "embed_data|netID|" .. player:getNetID() .. "\n" ..
        "embed_data|flags|" .. flags .. "\n" ..
        "add_popup_name|WrenchMenu|\n" ..
        "set_default_color|`o\n" ..
        tabData ..
        "end_dialog|" .. (isInfo and "playerProfile" or "manoProfile") ..
        "||" .. ((isInfo or cat == ProfileCat.LEVEL_UP_MENU or cat == ProfileCat.QUESTS_MENU
                  or cat == ProfileCat.LOCKED_WORLDS_MENU or cat == ProfileCat.SKILLS_MENU)
                 and "Continue" or "") .. "|\n" ..
        "add_quick_exit|"
    )
end

-- ─── Callbacks ─────────────────────────────────────────────────────
onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "playerProfile" then return false end

    local btn = data["buttonClicked"]
    if not btn then return false end

    local actions = {
        trades                  = function() player:onTradeScanUI() end,
        end_game                = function() world:onGameWinHighestScore() end,
        g4g                     = function() player:onGrow4GoodUI() end,
        guild_notebook          = function() player:onGuildNotebookUI() end,
        emojis                  = function() player:onGrowmojiUI() end,
        bonus                   = function() player:onGrowpassUI() end,
        notebook_edit           = function() player:onNotebookUI() end,
        billboard_edit          = function()
            if not canAccessBillboard(player) then
                player:onConsoleMessage("`4This feature is only for Supporter, Super Supporter, or Developer.")
                player:playAudio("bleep_fail.wav")
                return
            end
            player:onBillboardUI()
        end,
        open_personalize_profile = function() player:onPersonalizeWrenchUI() end,
        set_online_status       = function() player:onOnlineStatusUI() end,
        favorite_items          = function() player:onFavItemsUI() end,
        alist                   = function() player:onAchievementsUI(player) end,
        title_edit              = function() player:onTitlesUI(player) end,
        wrench_customization    = function() player:onWrenchIconsUI(player) end,
        marvelous_missions      = function() _G.openMarvelousMissions(world, player) end,
        backpack                = function() _G.BP_openBackpack(player) end,
        unlink_discord          = function() player:onUnlinkDiscordUI() end,
        link_discord            = function() player:onLinkDiscordUI() end,
        wardrobe_customization  = function() player:sendVariant({"OnDialogRequestRML", "show_wardrobe_main_ui"}) end,
        seed_diary_customization = function() player:sendVariant({"OnDialogRequestRML", "show_seed_diary_ui"}) end,
        open_worldlock_storage  = function() player:sendVariant({"OnDialogRequestRML", "show_world_lock_storage"}) end,
        goals     = function() onProfile(world, player, ProfileCat.QUESTS_MENU,        tonumber(string.sub(data["flags"], 1, -2))) end,
        my_worlds = function() onProfile(world, player, ProfileCat.LOCKED_WORLDS_MENU, tonumber(string.sub(data["flags"], 1, -2))) end,
        ["tab_" .. (ProfileCat.CHEATS_MENU + 1)] = function() _G.GM_openCheatMenu(player) end,
    }

    if actions[btn] then
        actions[btn]()
        return true
    end

    if btn:sub(1, 4) == "tab_" then
        local tabNum = tonumber(btn:sub(5))
        if tabNum then
            onProfile(world, player, tabNum - 1, tonumber(string.sub(data["flags"], 1, -2)))
        end
    end

    return false
end)

onPlayerProfileRequest(function(world, player, tabID, flags)
    onProfile(world, player, tabID - 1, flags)
    return true
end)

return M
