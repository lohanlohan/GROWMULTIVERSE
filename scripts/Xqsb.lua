-- Xqsb script

-- [1] REGISTRASI COMMAND
registerLuaCommand({
    command = "qsb",
    roleRequired = 51,
    description = "Quantum Broadcast"
})

-- [2] LOGIKA UTAMA
onPlayerCommandCallback(function(world, player, fullCommand)
    local cmd = fullCommand:match("^(%S+)")
    if not cmd or cmd:lower() ~= "qsb" then
        return false
    end

    -- [3] PROTEKSI ROLE (Gembok Manual)
    -- Cek apakah player punya salah satu role: 51, 7, atau 6
    if not (player:hasRole(51) or player:hasRole(7) or player:hasRole(6)) then
        player:sendVariant({"OnConsoleMessage", "You not have vallid role"})
        return true
    end

    -- [4] VALIDASI TEXT
    local text = fullCommand:match("^%S+%s+(.+)$")
    if not text or text == "" then
        player:sendVariant({"OnConsoleMessage", "`oUsage: /qsb <text>"})
        return true
    end

    local senderName = player:getName()
    local formattedMessage = string.format("`cQuantum Broadcast [`0From `c%s`0]: `^%s", senderName, text)

    -- [5] BROADCAST LOOP (Variant Tetap Utuh)
    for _, plr in ipairs(getServerPlayers() or {}) do
        if plr:isOnline() then
            -- Kirim ke Console masing-masing player
            plr:sendVariant({"OnConsoleMessage", formattedMessage})

            -- Kirim Notifikasi Pop-up di layar (Sesuai script asli ente)
            local notif = string.format("[`c%s``] `o\n`^%s", senderName, text)
            plr:sendVariant({
                "OnAddNotification",
                "interface/science_button.rttex",
                notif,
                "audio/hub_open.wav"
            })
        end
    end

    return true
end)
