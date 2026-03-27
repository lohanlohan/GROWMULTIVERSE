-- File: banwand.lua

local BAN_WAND_ID = 732
local DEV_ROLE_ID = 51

local ban_mod_id = -95
local ban_duration_sec = 10 -- Durasi 10 detik di dunia saat ini

local banModData = {
    modID = ban_mod_id, 
    modName = "Banned Zone", 
    onAddMessage = "You have been banished!", 
    onRemoveMessage = "The banishment ended.", 
    iconID = BAN_WAND_ID, 
    changeSkin = {255, 0, 0, 255}, -- Warna merah
    modState = {}
}
local banWandModID = registerLuaPlaymod(banModData)


onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == BAN_WAND_ID then
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        
        -- Pengecekan: Jika target adalah Developer, batalkan aksi.
        if clickedPlayer:hasRole(DEV_ROLE_ID) then
            player:onTalkBubble(player:getNetID(), "`4Cannot ban a Developer.``", 1)
            return true
        end
        
        if player:changeItem(itemID, -1, 0) then
            -- Memberi Mod dan Efek Visual
            clickedPlayer:addMod(banWandModID, ban_duration_sec)
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
            clickedPlayer:playAudio("buzz.wav")
            
            -- Aksi utama: Mengeluarkan pemain dari dunia saat ini (warp ke EXIT)
            clickedPlayer:onConsoleMessage("`4You have been banished from this world!")
            clickedPlayer:enterWorld("EXIT", "") 
            
            -- player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats harus didefinisikan secara global
            return true
        end
        return true
    end
    return false
end)