local Roles = {
  ROLE_NONE            = 0,
  ROLE_VIP             = 1,
  ROLE_SUPER_VIP       = 2,
  ROLE_MODERATOR       = 3,
  ROLE_ULTRA_MODERATOR = 4,
  ROLE_DIVINE          = 5,
  ROLE_SUPER_DIVINE    = 7,
  ROLE_RESTOCKER       = 8,
  ROLE_RESTOCKER_MAX   = 9,
  ROLE_MERCHANTS       = 10,
  ROLE_CO_OWNER        = 11,
  ROLE_SERVER_CREATOR  = 12,
  ROLE_DEVELOPER       = 51
}

local SFX = {
  VSB   = "audio/terraform.wav",       -- VIP / Super VIP
  MODS  = "audio/secret.wav",          -- Moderator / Ultra Moderator
  DIV   = "audio/friend_logon.wav",    -- Divine / Super Divine
  RST   = "audio/double_chance.wav",   -- Restocker / Restocker Max
  MERCH = "audio/cumbia_horns.wav",    -- Merchants
  CO    = "audio/choir.wav",           -- Co-Owner
  SC    = "audio/already_used.wav"     -- Server Creator / Developer
}

local function getName(p)  return p and p.getName and p:getName() or "Unknown" end
local function getWorld(p) return p and p.getWorldName and p:getWorldName() or "??" end
local function getUID(p)   return p and p.getUserID and p:getUserID() or -1 end
local function say(p,t)    if p and p.onConsoleMessage then p:onConsoleMessage(t) end end
local function sfx(p,f)    if p and f and p.sendAction then p:sendAction("action|play_sfx\nfile|"..f.."\ndelayMS|0") end end
local function allPlayers() if type(getServerPlayers)=="function" then return getServerPlayers() end return {} end

local function makeLine(tag, sender, world, msg)
  return string.format("** [%s] ** from (`#%s`o) in [`#%s`o] ** : `w%s", tag, sender, world, msg)
end

local function tagFor(cmd, p)
  if not p or not p.hasRole then return nil end
  if cmd=="vsb" then
    if p:hasRole(Roles.ROLE_SUPER_VIP) then return "`aSUPER VIP`o" end
    if p:hasRole(Roles.ROLE_VIP)      then return "`sVIP`o" end
  elseif cmd=="modsb" then
    if p:hasRole(Roles.ROLE_ULTRA_MODERATOR) then return "`#ULTRA MODERATOR`o" end
    if p:hasRole(Roles.ROLE_MODERATOR)       then return "`5SUPER MODERATOR`o" end
  elseif cmd=="divsb" then
    if p:hasRole(Roles.ROLE_SUPER_DIVINE) then return "`3SUPER DIVINE`o" end
    if p:hasRole(Roles.ROLE_DIVINE)       then return "`cDIVINE`o" end
  elseif cmd=="rsb" then
    if p:hasRole(Roles.ROLE_RESTOCKER_MAX) then return "`rRESTOCKER MAX`o" end
    if p:hasRole(Roles.ROLE_RESTOCKER)     then return "`tRESTOCKER`o" end
  elseif cmd=="msb" then
    if p:hasRole(Roles.ROLE_MERCHANTS) then return "`&MERCHANTS`o" end
  elseif cmd=="cosb" then
    if p:hasRole(Roles.ROLE_CO_OWNER) then return "`pCO-OWNER`o" end
  elseif cmd=="scsb" then
    if p:hasRole(Roles.ROLE_DEVELOPER)      then return "`@DEVELOPER`o" end
    if p:hasRole(Roles.ROLE_SERVER_CREATOR) then return "`@SERVER CREATOR`o" end
  end
  return nil
end

local function hasAny(p, roles)
  if not p or not p.hasRole then return false end
  for _,r in ipairs(roles) do if p:hasRole(r) then return true end end
  return false
end

registerLuaCommand({ command="vsb",   roleRequired=Roles.ROLE_VIP,            description="VIP / Super VIP Broadcast" })
registerLuaCommand({ command="modsb", roleRequired=Roles.ROLE_MODERATOR,      description="Moderator / Ultra Moderator Broadcast" })
registerLuaCommand({ command="divsb", roleRequired=Roles.ROLE_DIVINE,         description="Divine / Super Divine Broadcast" })
registerLuaCommand({ command="rsb",   roleRequired=Roles.ROLE_RESTOCKER,      description="Restocker / Restocker Max Broadcast" })
registerLuaCommand({ command="msb",   roleRequired=Roles.ROLE_MERCHANTS,      description="Merchants Broadcast" })
registerLuaCommand({ command="cosb",  roleRequired=Roles.ROLE_CO_OWNER,       description="Co-Owner Broadcast" })
registerLuaCommand({ command="scsb",  roleRequired=Roles.ROLE_SERVER_CREATOR, description="Server Creator / Developer Broadcast (Atomic Notice Only)" })

-- meta grup + sfx
local GROUPS = {
  vsb   = { roles={Roles.ROLE_VIP, Roles.ROLE_SUPER_VIP},             sfx=SFX.VSB },
  modsb = { roles={Roles.ROLE_MODERATOR, Roles.ROLE_ULTRA_MODERATOR}, sfx=SFX.MODS },
  divsb = { roles={Roles.ROLE_DIVINE, Roles.ROLE_SUPER_DIVINE},       sfx=SFX.DIV },
  rsb   = { roles={Roles.ROLE_RESTOCKER, Roles.ROLE_RESTOCKER_MAX},   sfx=SFX.RST },
  msb   = { roles={Roles.ROLE_MERCHANTS},                             sfx=SFX.MERCH },
  cosb  = { roles={Roles.ROLE_CO_OWNER},                              sfx=SFX.CO },
  scsb  = { roles={Roles.ROLE_SERVER_CREATOR, Roles.ROLE_DEVELOPER},  sfx=SFX.SC }
}

local function broadcastAll(sender, tag, msg, soundFile)
  local sname, wname, suid = getName(sender), getWorld(sender), getUID(sender)
  local text = makeLine(tag, sname, wname, msg)
  for _, p in ipairs(allPlayers()) do
    if getUID(p) ~= suid then
      say(p, text)
      sfx(p, soundFile)
    end
  end
  say(sender, text)
  sfx(sender, soundFile)
  say(sender, ">> "..tag.."- Broadcast sent.")
end

local function atomicNoticeAll(sender, tag, msg)
  local sname = getName(sender)
  local title = string.format("`0[%s]`w %s\n`w%s", tag, sname, msg)

  for _, p in ipairs(allPlayers()) do
    if p and p.sendVariant then
      p:sendVariant({
        "OnAddNotification",
        "interface/large/atomic_button.rttex",
        title,                                  
        SFX.SC,                                 
        0
      })
    end
  end

  say(sender, ">> "..tag.."- Broadcast sent.")
end

onPlayerCommandCallback(function(world, player, full)
  if type(full) ~= "string" then return false end
  local cmd, msg = full:match("^(%S+)%s*(.*)$")
  if not cmd then return false end
  local meta = GROUPS[cmd]
  if not meta then return false end

  msg = (msg or ""):gsub("^%s+","")
  if msg == "" then
    say(player, "Usage: /"..cmd.." <message>")
    return true
  end
  if not hasAny(player, meta.roles) then
    say(player, "`4Access denied.`")
    return true
  end

  local tag = tagFor(cmd, player)
  if not tag then
    say(player, "`4Access denied.`")
    return true
  end

  if cmd == "scsb" then
    -- khusus SC: HANYA atomic overlay + sfx, tidak ada baris chat broadcast
    atomicNoticeAll(player, tag, msg)
  else
    -- grup lain: chat broadcast + sfx
    broadcastAll(player, tag, msg, meta.sfx)
  end

  return true
end)