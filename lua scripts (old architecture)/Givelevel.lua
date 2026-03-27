-- Givelevel script
-- Script: givelevel_growid.lua

-- Tentukan Role ID untuk yang bisa menggunakan perintah ini (ROLE_DEVELOPER = 51)
local ROLE_DEVELOPER = 51

-- Fungsi untuk menemukan pemain (berdasarkan script N_DevOPC.lua (1).txt)
local function findPlayer(name)
    local t = string.lower(name)
    -- Asumsi getServerPlayers() tersedia di lingkungan ini
    for _, p in ipairs(getServerPlayers()) do
        if string.lower(p:getCleanName()) == t then return p end
    end
    return nil
end

-- Daftarkan perintah /givelevel
registerLuaCommand({
    command = "givelevel",
    roleRequired = ROLE_DEVELOPER,
    description = "Give a specific level to a player by GrowID (online only)."
})

onPlayerCommandCallback(function(world, player, fullCommand)
    local commandName, args = fullCommand:match("^(%S+)%s*(.*)")
    if not commandName then return false end

    if commandName:lower() == "givelevel" then
        
        -- 1. Periksa Role
        if not player:hasRole(ROLE_DEVELOPER) then
            player:onConsoleMessage("`4Access denied. `oDeveloper role required.")
            player:playAudio("audio/bleep_fail.wav")
            return true
        end
        
        -- 2. Ambil Argumen (Nama Pemain dan Level)
        local targetName, levelStr = args:match("^(%S+)%s*(%S+)$")
        
        if not targetName or not levelStr then 
            player:onConsoleMessage("`4Usage: /givelevel <GrowID> <level>")
            player:playAudio("audio/bleep_fail.wav")
            return true 
        end
        
        -- 3. Validasi Level
        local level = tonumber(levelStr)
        if not level or level < 0 or level > 999 then -- Batasan level dapat disesuaikan
            player:onConsoleMessage("`4Invalid level! `oLevel must be a number between 0 and 999.")
            player:playAudio("audio/bleep_fail.wav")
            return true
        end

        -- 4. Cari Pemain Target
        local target = findPlayer(targetName)
        if not target then 
            player:onConsoleMessage("`4Player '" .. targetName .. "' not found or not online.")
            player:playAudio("audio/bleep_fail.wav")
            return true 
        end
        
        -- 5. Berikan Level
        -- Asumsi fungsi setLevel(newLevel) tersedia pada objek player
        if target.setLevel then
            target:setLevel(level)
            
            -- Kirim pesan ke admin
            player:onConsoleMessage(string.format("`2Successfully set %s's level to `6%d`2.", target:getName(), level))
            player:playAudio("audio/success.wav")
            
            -- Kirim pesan ke target
            target:onConsoleMessage(string.format("`2Your level has been set to `6%d`2 by Admin %s.", level, player:getName()))
        else
            -- Jika setLevel tidak ada (tergantung API server)
            player:onConsoleMessage("`4Error: `oFunction 'setLevel' not available on player object.")
            player:playAudio("audio/bleep_fail.wav")
        end
        
        return true
    end

    return false
end)