local Roles = {
  ROLE_NONE            = 0,
  ROLE_FEATURE         = 1,
  ROLE_LORD            = 2,
  ROLE_OVERLORD        = 3,
  ROLE_SUPREME         = 4,
  ROLE_GUARDIAN        = 5,
  ROLE_MODERATOR       = 6,
  ROLE_SERVER_CREATOR  = 12,
  ROLE_DEVELOPER       = 51
}

local SFX = {
  LSB   = "audio/terraform.wav",       -- LORD
  OSB   = "audio/friend_logon.wav",   -- OVERLORD
  SSB   = "audio/double_chance.wav",   -- SUPREME
  MODS  = "audio/secret.wav",          -- Moderator / Ultra Moderator
  MERCH = "audio/cumbia_horns.wav",    -- Merchants
  CO    = "audio/choir.wav",           -- Co-Owner
  SC    = "audio/already_used.wav",     -- Server Creator / Developer
  qsb   = "audio/hub_open.wav"         -- Quantum SB (unused)
}

local BROADCAST_COST = {
  lsb = { perPlayer = 100, maxCost = 500000 },
  osb = { perPlayer = 200, maxCost = 1000000 },
  ssb = { perPlayer = 400, maxCost = 2000000 }
}

local function getName(p)  return p and p.getName and p:getName() or "Unknown" end
local function getWorld(p) return p and p.getWorldName and p:getWorldName() or "??" end
local function getUID(p)   return p and p.getUserID and p:getUserID() or -1 end
local function say(p,t)    if p and p.onConsoleMessage then p:onConsoleMessage(t) end end
local function sfx(p,f)    if p and f and p.sendAction then p:sendAction("action|play_sfx\nfile|"..f.."\ndelayMS|0") end end
local function allPlayers() if type(getServerPlayers)=="function" then return getServerPlayers() end return {} end

local function makeLine(tag, sender, world, msg, isJammed)
  local displayWorld = world
  if isJammed then
    displayWorld = "`4JAMMED`o"
  end
  return string.format("** [%s] ** from (`#%s`o) in [%s] ** : `$%s", tag, sender, displayWorld, msg)
end

local function tagFor(cmd, p)
  if not p or not p.hasRole then return nil end
  if cmd=="lsb" then
    if p:hasRole(Roles.ROLE_LORD) or p:hasRole(Roles.ROLE_OVERLORD) or p:hasRole(Roles.ROLE_SUPREME) then return "`eLord-Broadcast`o" end
  elseif cmd=="osb" then
    if p:hasRole(Roles.ROLE_OVERLORD) or p:hasRole(Roles.ROLE_SUPREME) then return "`4Overlord-Broadcast`o" end
  elseif cmd=="ssb" then
    if p:hasRole(Roles.ROLE_SUPREME) then return "`bSupreme-Broadcast`o" end
  elseif cmd=="scsb" then
    if p:hasRole(Roles.ROLE_DEVELOPER) then return "`@Developer`o" end
    if p:hasRole(Roles.ROLE_SERVER_CREATOR) then return "`@Server-Creator`o" end
  elseif cmd=="qsb" then
    if p:hasRole(Roles.ROLE_DEVELOPER) then return "`aQuantum-Broadcast`o" end
  end
  return nil
end

local function hasAny(p, roles)
  if not p or not p.hasRole then return false end
  for _,r in ipairs(roles) do if p:hasRole(r) then return true end end
  return false
end

local function calcBroadcastCost(cmd, onlineCount)
  local cfg = BROADCAST_COST[cmd]
  if not cfg then return 0 end
  local rawCost = cfg.perPlayer * math.max(onlineCount or 0, 0)
  return math.min(rawCost, cfg.maxCost)
end

registerLuaCommand({ command="lsb",   roleRequired=Roles.ROLE_LORD,           description="Lord / Overlord / Supreme Broadcast" })
registerLuaCommand({ command="osb",   roleRequired=Roles.ROLE_OVERLORD,       description="Overlord / Supreme Broadcast" })
registerLuaCommand({ command="ssb",   roleRequired=Roles.ROLE_SUPREME,        description="Supreme Broadcast" })
registerLuaCommand({ command="scsb",  roleRequired=Roles.ROLE_SERVER_CREATOR, description="Server Creator / Developer Broadcast (Atomic Notice Only)" })
registerLuaCommand({ command="qsb",   roleRequired=Roles.ROLE_SERVER_CREATOR, description="Quantum Broadcast (Developer Only, Atomic Notice Only)" })

-- meta grup + sfx
local GROUPS = {
  lsb   = { roles={Roles.ROLE_LORD, Roles.ROLE_OVERLORD, Roles.ROLE_SUPREME},   sfx=SFX.LSB },
  osb   = { roles={Roles.ROLE_OVERLORD, Roles.ROLE_SUPREME},                    sfx=SFX.OSB },
  ssb   = { roles={Roles.ROLE_SUPREME},                                         sfx=SFX.SSB },
  scsb  = { roles={Roles.ROLE_SERVER_CREATOR, Roles.ROLE_DEVELOPER},            sfx=SFX.SC },
  qsb   = { roles={Roles.ROLE_DEVELOPER},                                       sfx=SFX.qsb }
}

local function broadcastAll(sender, tag, msg, soundFile, usedGems, world)
  local sname, wname, suid = getName(sender), getWorld(sender), getUID(sender)
  local isJammed = world and world:hasFlag(1) or false
  local text = makeLine(tag, sname, wname, msg, isJammed)
  local currentGems = (sender and sender.getGems and sender:getGems()) or 0
  
  say(sender, string.format(">> %s sent. Used `$%d Gems`o. `o(%d left)", tag, usedGems, currentGems or 0))

  for _, p in ipairs(allPlayers()) do
    if getUID(p) ~= suid then
      say(p, text)
      sfx(p, soundFile)
    end
  end
  say(sender, text)
  sfx(sender, soundFile)
end

local function atomicNoticeAll(sender, tag, msg)
  local sname = getName(sender)
  local title = string.format("`0[%s]`w %s\n`w%s", tag, sname, msg)

  say(sender, ">> "..tag.." sent.")

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
    say(player, "`4Unknown command. `oEnter `$/help `ofor a list of valid commands.")
    return true
  end

  local tag = tagFor(cmd, player)
  if not tag then
    say(player, "`4Unknown command. `oEnter `$/help `ofor a list of valid commands.")
    return true
  end

  local usedGems = 0
  local pricing = BROADCAST_COST[cmd]
  if pricing then
    local onlineCount = #allPlayers()
    usedGems = calcBroadcastCost(cmd, onlineCount)
    local currentGems = (player and player.getGems and player:getGems()) or 0

    if currentGems < usedGems then
      say(player, string.format("`4Not enough Gems. Need `$%d Gems`o, you have `$%d Gems`o.", usedGems, currentGems))
      return true
    end

    if player and player.removeGems then
      if not player:removeGems(usedGems, 1, 1) then
        say(player, "`4Failed to deduct Gems. Please try again.")
        return true
      end
    end
  end

  if cmd == "scsb" then
    -- khusus SC: HANYA atomic overlay + sfx, tidak ada baris chat broadcast
    atomicNoticeAll(player, tag, msg)
  elseif cmd == "qsb" then
    atomicNoticeAll(player, tag, msg)
  else
    -- grup lain: chat broadcast + sfx
    broadcastAll(player, tag, msg, meta.sfx, usedGems, world)
  end

  return true
end)