-- MODULE
-- custom_titles.lua — /titles command: white name + Dr./Legend/Mentor + icon
-- Data disimpan di currentState/luaData/player.json → per UID → key "titles"

local M = {}
local Utils = _G.Utils
local DB    = _G.DB

local CMD         = "titles"
local DIALOG_NAME = "custom_titles_dialog"
local ICON_TEXTURE = "game/tiles_page16.rttex"
local ICON_COORDS  = "1,25"
local NAME_COLOR   = "`0"

registerLuaCommand({
    command      = CMD,
    roleRequired = 0,
    description  = "Set white name color + custom title + icon in one menu."
})

-- ─── Storage ───────────────────────────────────────────────────────
local function loadProfile(player)
    local record = DB.getPlayer("player", Utils.uid(player))
    local t = record.titles or {}
    return {
        useIcon       = t.useIcon == true,
        prefixDr      = t.prefixDr == true,
        suffixLegend  = t.suffixLegend == true,
        mentorTitle   = t.mentorTitle == true,
    }
end

local function saveProfile(player, profile)
    DB.updatePlayer("player", Utils.uid(player), { titles = profile })
end

-- ─── Name helpers ──────────────────────────────────────────────────
local function normalize(raw)
    local s = tostring(raw or "")
    s = s:gsub("`.", ""):gsub("^@+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^Dr%.", ""):gsub(" of Legend$", ""):gsub(" Mentor$", "")
    return s
end

local function getBaseName(player)
    if player.getRealCleanName then
        local n = normalize(player:getRealCleanName())
        if n ~= "" then return n end
    end
    local n = normalize(player:getCleanName())
    return n ~= "" and n or "Player"
end

local function canUseAtPrefix(player)
    if not player.hasRole then return false end
    if player:hasRole(6) then return true end
    if not getRoles then return false end
    local roleList = getRoles() or {}
    local modPriority
    for _, role in ipairs(roleList) do
        if role.roleID == 6 then modPriority = role.rolePriority; break end
    end
    if not modPriority then return false end
    for _, role in ipairs(roleList) do
        if role.roleID and role.rolePriority and player:hasRole(role.roleID) then
            if role.rolePriority <= modPriority then return true end
        end
    end
    return false
end

local function extractColor(s)
    return tostring(s or ""):match("(`.)")
end

local function getRoleColor(player, preferChat)
    if not player then return NAME_COLOR end
    if player.getRole then
        local r = player:getRole()
        if r then
            local c = preferChat and (extractColor(r.chatPrefix) or extractColor(r.namePrefix))
                               or   (extractColor(r.namePrefix)  or extractColor(r.chatPrefix))
            if c then return c end
        end
    end
    if getRoles and player.hasRole then
        local best
        for _, role in ipairs(getRoles() or {}) do
            if role.roleID and player:hasRole(role.roleID) then
                if not best or (role.rolePriority or 999999) < (best.rolePriority or 999999) then
                    best = role
                end
            end
        end
        if best then
            local c = preferChat and (extractColor(best.chatPrefix) or extractColor(best.namePrefix))
                                or   (extractColor(best.namePrefix)  or extractColor(best.chatPrefix))
            if c then return c end
        end
    end
    return NAME_COLOR
end

local function buildDisplayName(player, profile)
    local base  = getBaseName(player)
    local at    = canUseAtPrefix(player) and "@" or ""
    local color = getRoleColor(player, false)
    if profile.prefixDr and profile.suffixLegend then return "`4" .. at .. "Dr. " .. base .. " of Legend``" end
    if profile.prefixDr      then return "`4" .. at .. "Dr. " .. base .. "``" end
    if profile.suffixLegend  then return "`9" .. at .. base .. " of Legend``" end
    if profile.mentorTitle   then return "`6" .. at .. base .. "``" end
    if at ~= ""              then return color .. at .. base .. "``" end
    return NAME_COLOR .. base .. "``"
end

local function buildChatName(player, profile)
    local base  = getBaseName(player)
    local at    = canUseAtPrefix(player) and "@" or ""
    local color = getRoleColor(player, false)
    if profile.prefixDr and profile.suffixLegend then return "`4" .. at .. "Dr. " .. base .. " of Legend" end
    if profile.prefixDr      then return "`4" .. at .. "Dr. " .. base end
    if profile.suffixLegend  then return "`9" .. at .. base .. " of Legend" end
    if profile.mentorTitle   then return "`6" .. at .. base end
    if at ~= ""              then return color .. at .. base end
    return "`0" .. base
end

local function hasTitle(profile)
    return profile and (profile.prefixDr or profile.suffixLegend or profile.mentorTitle)
end

-- ─── Apply to client ───────────────────────────────────────────────
local function applyProfile(player, profile)
    if not player or not player.sendVariant then return false end
    local texture = profile.useIcon and ICON_TEXTURE or ""
    local coords  = profile.useIcon and ICON_COORDS  or "0,0"
    local payload = string.format(
        "{\"PlayerWorldID\":%d,\"TitleTexture\":\"%s\",\"TitleTextureCoordinates\":\"%s\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
        player:getNetID(), texture, coords
    )
    player:sendVariant({ "OnNameChanged", buildDisplayName(player, profile), payload }, 0, player:getNetID())
    return true
end

local function resetProfile(player)
    local profile = {
        useIcon = false,
        prefixDr = false,
        suffixLegend = false,
        mentorTitle = false,
    }
    saveProfile(player, profile)
    return applyProfile(player, profile)
end

-- ─── Dialog ────────────────────────────────────────────────────────
local function openDialog(player)
    local p = loadProfile(player)
    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_quick_exit|\n" ..
        "add_label_with_icon|big|`wCustom Titles & Icon``|left|11816|\n" ..
        "add_textbox|`oManage your name color, title prefix/suffix, and icon.|left|\n" ..
        "add_spacer|small|\n" ..
        "add_checkbox|use_icon|Enable Name Icon|"       .. (p.useIcon       and "1" or "0") .. "|\n" ..
        "add_checkbox|prefix_dr|`4Dr. Prefix|"          .. (p.prefixDr      and "1" or "0") .. "|\n" ..
        "add_checkbox|suffix_legend|`9of Legend Suffix|" .. (p.suffixLegend  and "1" or "0") .. "|\n" ..
        "add_checkbox|mentor_title|`6Mentor Title|"     .. (p.mentorTitle    and "1" or "0") .. "|\n" ..
        "add_button|titles_apply|`2Apply|noflags|0|0|\n" ..
        "end_dialog|" .. DIALOG_NAME .. "|||",
        0
    )
end

-- ─── Callbacks ─────────────────────────────────────────────────────
onPlayerCommandCallback(function(world, player, fullCommand)
    if Utils.getCmd(fullCommand) ~= "/" .. CMD then return false end
    openDialog(player)
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    if data["dialog_name"] ~= DIALOG_NAME then return false end
    if data["buttonClicked"] ~= "titles_apply" then return true end

    local profile = {
        useIcon      = data["use_icon"]       == "1",
        prefixDr     = data["prefix_dr"]      == "1",
        suffixLegend = data["suffix_legend"]  == "1",
        mentorTitle  = data["mentor_title"]   == "1",
    }
    saveProfile(player, profile)

    if applyProfile(player, profile) then
        Utils.msg(player, "`2Profile applied from /titles.")
    else
        Utils.msg(player, "`4Failed to apply /titles profile.")
    end
    return true
end)

onPlayerActionCallback(function(world, player, data)
    if type(data) ~= "table" then return end
    if data["action"] ~= "input" then return end
    local text = tostring(data["|text"] or "")
    if text == "" or text:sub(1, 1) == "/" then return end

    local profile = loadProfile(player)
    if not hasTitle(profile) then return end

    local chatName  = buildChatName(player, profile)
    local textColor = getRoleColor(player, true)
    local netID     = player:getNetID()

    for _, p in pairs(world:getPlayers()) do
        if p and p.onConsoleMessage then
            p:onConsoleMessage("`6<" .. chatName .. "`6> " .. textColor .. text .. "``")
        end
        if p and p.onTalkBubble then
            p:onTalkBubble(netID, text, 0)
        end
    end
    return true
end)

onPlayerEnterWorldCallback(function(world, player)
    if not player then return end
    local profile = loadProfile(player)
    if profile.useIcon or hasTitle(profile) then
        applyProfile(player, profile)
    end
end)

M.resetProfile = resetProfile

return M
