local Roles = { ROLE_ADMIN = 7, ROLE_DEV = 51 }
local function isStaff(p) return p:hasRole(Roles.ROLE_ADMIN) or p:hasRole(Roles.ROLE_DEV) end

if type(PlayerRoleQuestTypes) ~= "table" then
  PlayerRoleQuestTypes = { Farmer=0, Builder=1, Fishing=2, Chief=3, Surgery=4, Startopia=5 }
end

local ROLE_KEYS = {
  farmer    = PlayerRoleQuestTypes.Farmer,
  builder   = PlayerRoleQuestTypes.Builder,
  fishing   = PlayerRoleQuestTypes.Fishing,
  chef      = PlayerRoleQuestTypes.Chief,   
  chief     = PlayerRoleQuestTypes.Chief,
  surgery   = PlayerRoleQuestTypes.Surgery,
  startopia = PlayerRoleQuestTypes.Startopia
}
local ROLE_ORDER = { "farmer","builder","fishing","chef","surgery","startopia" }

local UI = "giveskin_ui"

local function clamp(x, lo, hi) if x<lo then return lo elseif x>hi then return hi else return x end end
local function findPlayerByNameInsensitive(input)
  if not input or input=="" then return nil end
  local needle = string.lower(input)
  for _, pl in ipairs(getServerPlayers() or {}) do
    local nm = (pl.getCleanName and pl:getCleanName()) or pl:getName()
    if nm and string.lower(nm) == needle then return pl end
  end
  return nil
end

local function applyRolesLevel(target, enums, level)
  local count = 0
  for _, enumVal in ipairs(enums) do
    target:setRoleQuestLevel(enumVal, level) 
    count = count + 1
  end
  target:onConsoleMessage("`2Your role levels were updated to `#"..level.."`2 ("..count.." roles).")
  target:playAudio("piano_nice.wav")
end

local function openGiveSkinUI(sender, presetTarget)
  if not isStaff(sender) then
    sender:onConsoleMessage("`4No permission.")
    return
  end

  local d = {}
  d[#d+1] = "set_default_color|`w\n"
  d[#d+1] = "add_label_with_icon|big|Give Role Skins / Icons|left|242|\n"
  d[#d+1] = "add_textbox|Enter exact player name.|\n"
  d[#d+1] = ("add_text_input|gs_target|Player Name|%s|24|\n"):format(presetTarget or "")
  d[#d+1] = "add_spacer|small|\n"

  d[#d+1] = "add_textbox|Select roles to set (or tick All).|\n"
  d[#d+1] = "add_checkbox|gs_all|All roles|0|\n"
  for _, key in ipairs(ROLE_ORDER) do
    local label = key:gsub("^%l", string.upper)
    d[#d+1] = ("add_checkbox|gs_%s|%s|0|\n"):format(key, label)
  end

  d[#d+1] = "add_spacer|small|\n"
  d[#d+1] = "add_textbox|Set Level Level 10 unlocks all icons/skins.|\n"
  d[#d+1] = "add_text_input|gs_level|Level|10|5|numeric|\n"
  d[#d+1] = "add_spacer|small|\n"
  d[#d+1] = "add_button|gs_set10|Set 10|noflags|\n"
  d[#d+1] = "add_button|gs_set0|Set 0|noflags|\n"
  d[#d+1] = "add_spacer|small|\n"
  d[#d+1] = "add_button|gs_apply|`2Apply|noflags|\n"
  d[#d+1] = "add_button|gs_close|Close|noflags|\n"
  d[#d+1] = "end_dialog|"..UI.."|||\n"
  sender:onDialogRequest(table.concat(d))
end

registerLuaCommand({
  command = "giveskin",
  roleRequired = Roles.ROLE_DEV,
  description = "Open set Role Quest levels."
})

onPlayerCommandCallback(function(world, player, cmd)
  if cmd == "giveskin" then openGiveSkinUI(player, ""); return true end
  return false
end)

onPlayerDialogCallback(function(world, player, data)
  if data.dialog_name ~= UI then return false end
  local btn = data.buttonClicked or ""

  if btn == "gs_close" then return true end

  if btn == "gs_set10" then
    data.gs_level = "10"
    openGiveSkinUI(player, tostring(data.gs_target or ""))
    return true
  elseif btn == "gs_set0" then
    data.gs_level = "0"
    openGiveSkinUI(player, tostring(data.gs_target or ""))
    return true
  elseif btn == "gs_apply" then
    if not isStaff(player) then player:onConsoleMessage("`4No permission."); return true end

    local targetName = tostring(data.gs_target or "")
    local target = findPlayerByNameInsensitive(targetName)
    if not target then
      player:onConsoleMessage("`4Player not found: `w"..(targetName=="" and "(empty)" or targetName))
      openGiveSkinUI(player, targetName)
      return true
    end

    local level = clamp(tonumber(data.gs_level or "10") or 10, 0, 10)

    local enums = {}
    local all = tostring(data.gs_all or "0") == "1"
    if all then
      for _, key in ipairs(ROLE_ORDER) do enums[#enums+1] = ROLE_KEYS[key] end
    else
      for _, key in ipairs(ROLE_ORDER) do
        if tostring(data["gs_"..key] or "0") == "1" then
          enums[#enums+1] = ROLE_KEYS[key]
        end
      end
    end

    if #enums == 0 then
      player:onConsoleMessage("`4No role selected.")
      openGiveSkinUI(player, targetName)
      return true
    end

    applyRolesLevel(target, enums, level)
    player:onConsoleMessage(("`2Updated `w%s`2 → level `#%d`2 (%d roles)."):format(target:getName(), level, #enums))
    return true
  end

  return true
end)