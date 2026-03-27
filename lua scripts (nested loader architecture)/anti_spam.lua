-- MODULE
-- anti_spam.lua — Chat spam detection dan cooldown

local M = {}

local MOD_ID = registerLuaPlaymod({
    modID           = -1000,
    modName         = "Chat Cooldown",
    onAddMessage    = "You need to chill a little bit!",
    onRemoveMessage = "You can now be no-chill again.",
    iconID          = 660,
})

local COOLDOWN_MS  = 1500   -- jarak minimum antar chat (ms)
local SPAM_LIMIT   = 5      -- jumlah chat cepat sebelum kena cooldown
local MUTE_SECONDS = 10     -- durasi mute saat kena cooldown

local cooldowns = {}        -- { [uid] = { lastChatTime, spamCount } }

onPlayerChatCallback(function(world, player, message)
    local uid = player:getUserID()

    if player:hasMod(MOD_ID) then
        player:onConsoleMessage("`6>> `4Spam detected! ``Please wait before typing again. Any bot/macro/auto-paste will get your accounts banned.")
        return true
    end

    local now = os.time() * 1000

    if not cooldowns[uid] then
        cooldowns[uid] = { lastChatTime = 0, spamCount = 0 }
    end

    local data = cooldowns[uid]

    if now - data.lastChatTime < COOLDOWN_MS then
        data.spamCount = data.spamCount + 1
        if data.spamCount >= SPAM_LIMIT then
            player:addMod(MOD_ID, MUTE_SECONDS)
            return true
        end
    else
        data.spamCount = 0
    end

    data.lastChatTime = now
    return false
end)

onPlayerLeaveWorldCallback(function(world, player)
    cooldowns[player:getUserID()] = nil
end)

return M
