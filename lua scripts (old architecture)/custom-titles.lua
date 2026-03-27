print('(Loaded) Custom Titles script')

local TITLE_COMMAND = "titles"
local TITLE_DIALOG_NAME = "custom_titles_dialog"
local TITLE_STATE_KEY = "CUSTOM_TITLE_PROFILE"

-- White color code requested: `0
local NAME_COLOR = "`0"

-- Based on your native packet debug for /icons and /titles.
local ICON_TEXTURE = "game/tiles_page16.rttex"
local ICON_COORDS = "1,25"

registerLuaCommand({
  command = TITLE_COMMAND,
  roleRequired = 0,
  description = "Set white name color + custom title + icon in one menu."
})

local function getUID(player)
  if not player or not player.getUserID then return -1 end
  return player:getUserID()
end

local function loadProfiles()
  return loadDataFromServer(TITLE_STATE_KEY) or {}
end

local function loadProfile(player)
  local uid = getUID(player)
  if uid < 0 then
    return {
      useIcon = false,
      prefixDr = false,
      suffixLegend = false,
      mentorTitle = false
    }
  end

  local profiles = loadProfiles()
  local profile = profiles[uid] or {}
  return {
    useIcon = profile.useIcon == true,
    prefixDr = profile.prefixDr == true,
    suffixLegend = profile.suffixLegend == true,
    mentorTitle = profile.mentorTitle == true
  }
end

local function saveProfile(player, profile)
  local uid = getUID(player)
  if uid < 0 then return end

  local profiles = loadProfiles()
  profiles[uid] = {
    useIcon = profile.useIcon == true,
    prefixDr = profile.prefixDr == true,
    suffixLegend = profile.suffixLegend == true,
    mentorTitle = profile.mentorTitle == true
  }
  saveDataToServer(TITLE_STATE_KEY, profiles)
end

local function getBaseName(player)
  local function normalize(raw)
    local s = tostring(raw or "")
    s = s:gsub("`.", "")
    s = s:gsub("^@+", "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^Dr%.", "")
    s = s:gsub(" of Legend$", "")
    s = s:gsub(" Mentor$", "")
    return s
  end

  if player and player.getRealCleanName then
    local n = player:getRealCleanName()
    n = normalize(n)
    if n ~= "" then return n end
  end

  if player and player.getCleanName then
    local n = player:getCleanName()
    n = normalize(n)
    if n ~= "" then return n end
  end

  local fallback = (player and player.getName and player:getName()) or "Player"
  fallback = normalize(fallback)
  if fallback == "" then return "Player" end
  return fallback
end

local function canUseModAtPrefix(player)
  if not player or not player.hasRole then
    return false
  end

  if player:hasRole(6) then
    return true
  end

  if not getRoles then
    return false
  end

  local roleList = getRoles() or {}
  local moderatorPriority = nil

  for i = 1, #roleList do
    local role = roleList[i]
    if role and role.roleID == 6 then
      moderatorPriority = role.rolePriority
      break
    end
  end

  if moderatorPriority == nil then
    return false
  end

  for i = 1, #roleList do
    local role = roleList[i]
    if role and role.roleID and role.rolePriority and player:hasRole(role.roleID) then
      if role.rolePriority <= moderatorPriority then
        return true
      end
    end
  end

  return false
end

local function extractColorCode(s)
  local str = tostring(s or "")
  local code = str:match("(`.)")
  return code
end

local function getPlayerRoleNameColor(player)
  if not player then
    return NAME_COLOR
  end

  if player.getRole then
    local activeRole = player:getRole()
    if activeRole then
      local c = extractColorCode(activeRole.namePrefix)
      if c then return c end
      c = extractColorCode(activeRole.chatPrefix)
      if c then return c end
    end
  end

  if getRoles and player.hasRole then
    local roleList = getRoles() or {}
    local chosen = nil
    for i = 1, #roleList do
      local role = roleList[i]
      if role and role.roleID and player:hasRole(role.roleID) then
        if not chosen then
          chosen = role
        else
          local p1 = role.rolePriority or 999999
          local p2 = chosen.rolePriority or 999999
          if p1 < p2 then
            chosen = role
          end
        end
      end
    end

    if chosen then
      local c = extractColorCode(chosen.namePrefix)
      if c then return c end
      c = extractColorCode(chosen.chatPrefix)
      if c then return c end
    end
  end

  return NAME_COLOR
end

local function buildDisplayName(player, profile)
  local baseName = getBaseName(player)
  local useAt = canUseModAtPrefix(player)
  local at = useAt and "@" or ""
  local roleColor = getPlayerRoleNameColor(player)

  -- Final display format mapping:
  -- Dr + Legend -> `4Dr. Fry of Legend
  -- Dr only     -> `4Dr. Fry
  -- Legend only -> `9Fry of Legend
  -- Mentor only -> `6Fry
  -- None        -> role color (mods) or `0
  if profile.prefixDr and profile.suffixLegend then
    return "`4" .. at .. "Dr. " .. baseName .. " of Legend``"
  end

  if profile.prefixDr then
    return "`4" .. at .. "Dr. " .. baseName .. "``"
  end

  if profile.suffixLegend then
    return "`9" .. at .. baseName .. " of Legend``"
  end

  if profile.mentorTitle then
    return "`6" .. at .. baseName .. "``"
  end

  if useAt then
    return roleColor .. at .. baseName .. "``"
  end

  return NAME_COLOR .. baseName .. "``"
end

local function buildNickname(player, profile)
  local baseName = getBaseName(player)
  local useAt = canUseModAtPrefix(player)
  local at = useAt and "@" or ""
  local roleColor = getPlayerRoleNameColor(player)

  -- Chat display mapping from user request:
  -- Dr+Legend => `4Dr. Fry of Legend
  -- Dr only    => `4Dr. Fry
  -- Legend only=> `9Fry of Legend
  -- Mentor only=> `6Fry
  -- None (mods)=> role color + @Fry
  if profile.prefixDr and profile.suffixLegend then
    return "`4" .. at .. "Dr. " .. baseName .. " of Legend"
  end

  if profile.prefixDr then
    return "`4" .. at .. "Dr. " .. baseName
  end

  if profile.suffixLegend then
    return "`9" .. at .. baseName .. " of Legend"
  end

  if profile.mentorTitle then
    return "`6" .. at .. baseName
  end

  if useAt then
    return roleColor .. at .. baseName
  end

  return "`0" .. baseName
end

local function hasAnyTitleState(profile)
  return profile and (profile.prefixDr or profile.suffixLegend or profile.mentorTitle)
end

local function getPlayerRoleTextColor(player)
  if not player then
    return "`$"
  end

  if player.getRole then
    local activeRole = player:getRole()
    if activeRole then
      local c = extractColorCode(activeRole.chatPrefix)
      if c then return c end
      c = extractColorCode(activeRole.namePrefix)
      if c then return c end
    end
  end

  if getRoles and player.hasRole then
    local roleList = getRoles() or {}
    local chosen = nil
    for i = 1, #roleList do
      local role = roleList[i]
      if role and role.roleID and player:hasRole(role.roleID) then
        if not chosen then
          chosen = role
        else
          local p1 = role.rolePriority or 999999
          local p2 = chosen.rolePriority or 999999
          if p1 < p2 then
            chosen = role
          end
        end
      end
    end

    if chosen then
      local c = extractColorCode(chosen.chatPrefix)
      if c then return c end
      c = extractColorCode(chosen.namePrefix)
      if c then return c end
    end
  end

  return "`$"
end

local function relayCustomChat(world, player, text)
  local profile = loadProfile(player)
  if not hasAnyTitleState(profile) then
    return false
  end

  if not world or not world.getPlayers then
    return false
  end

  local players = world:getPlayers()
  if type(players) ~= "table" then
    return false
  end

  local chatName = buildNickname(player, profile)
  local textColor = getPlayerRoleTextColor(player)
  local senderNetID = player:getNetID()

  for _, p in pairs(players) do
    if p and p.onConsoleMessage then
      p:onConsoleMessage("`6<" .. chatName .. "`6> " .. textColor .. text .. "``")
    end
    if p and p.onTalkBubble then
      p:onTalkBubble(senderNetID, text, 0)
    end
  end

  return true
end

local function buildPayload(player, profile)
  local texture = ""
  local coords = "0,0"

  if profile.useIcon then
    texture = ICON_TEXTURE
    coords = ICON_COORDS
  end

  return string.format(
    "{\"PlayerWorldID\":%d,\"TitleTexture\":\"%s\",\"TitleTextureCoordinates\":\"%s\",\"WrenchCustomization\":{\"WrenchForegroundCanRotate\":false,\"WrenchForegroundID\":-1,\"WrenchIconID\":-1}}",
    player:getNetID(), texture, coords
  )
end

local function applyProfile(player, profile)
  if not player or not player.sendVariant or not player.getNetID then
    return false
  end

  local newName = buildDisplayName(player, profile)
  local payload = buildPayload(player, profile)

  player:sendVariant({
    "OnNameChanged",
    newName,
    payload
  }, 0, player:getNetID())

  return true
end

local function openTitlesDialog(player)
  local profile = loadProfile(player)

  local dialog =
    "set_default_color|`o\n" ..
    "add_quick_exit|\n" ..
    "add_label_with_icon|big|`wCustom Titles & Icon``|left|11816|\n" ..
    "add_textbox|`oAll settings moved into /titles. Name will use white color code (`0).``|left|\n" ..
    "add_spacer|small|\n" ..
    "add_checkbox|use_icon|Enable Name Icon (tiles_page16 1,25)|" .. (profile.useIcon and "1" or "0") .. "|\n" ..
    "add_checkbox|prefix_dr|`4Dr. Prefix|" .. (profile.prefixDr and "1" or "0") .. "|\n" ..
    "add_checkbox|suffix_legend|`9of Legend Suffix|" .. (profile.suffixLegend and "1" or "0") .. "|\n" ..
    "add_checkbox|mentor_title|`6Mentor Title (color mode, no suffix)|" .. (profile.mentorTitle and "1" or "0") .. "|\n" ..
    "add_button|titles_apply|`2Apply|noflags|0|0|\n" ..
    "end_dialog|" .. TITLE_DIALOG_NAME .. "|||"

  player:onDialogRequest(dialog, 0)
end

onPlayerCommandCallback(function(world, player, fullCommand)
  if type(fullCommand) ~= "string" then
    return false
  end

  local cmd = fullCommand:lower():gsub("^/", ""):match("^%S+") or ""
  if cmd ~= TITLE_COMMAND then
    return false
  end

  if not player or not player.onDialogRequest then
    return true
  end

  openTitlesDialog(player)
  return true
end)

onPlayerDialogCallback(function(world, player, data)
  if not data or data["dialog_name"] ~= TITLE_DIALOG_NAME then
    return false
  end

  if data["buttonClicked"] ~= "titles_apply" then
    return true
  end

  local profile = {
    useIcon = data["use_icon"] == "1",
    prefixDr = data["prefix_dr"] == "1",
    suffixLegend = data["suffix_legend"] == "1",
    mentorTitle = data["mentor_title"] == "1"
  }

  saveProfile(player, profile)

  if applyProfile(player, profile) then
    player:onConsoleMessage("`2Profile applied from /titles (white name + title/icon).")
  else
    player:onConsoleMessage("`4Failed to apply /titles profile.")
  end

  return true
end)

onPlayerActionCallback(function(world, player, data)
  if type(data) ~= "table" then
    return
  end

  if data["action"] ~= "input" then
    return
  end

  local text = tostring(data["|text"] or "")
  if text == "" then
    return
  end

  if text:sub(1, 1) == "/" then
    return
  end

  if relayCustomChat(world, player, text) then
    return true
  end
end)

onPlayerEnterWorldCallback(function(world, player)
  if not player then return end

  local profile = loadProfile(player)
  if profile.useIcon or profile.prefixDr or profile.suffixLegend or profile.mentorTitle then
    applyProfile(player, profile)
  end
end)

print('(Ready) Custom Titles script')
