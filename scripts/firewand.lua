-- File: firewand.lua

local FIRE_WAND_ID = 276

-- Register Mod (Opsional: Jika ingin memberi debuff terbakar/damage)
local fire_mod_id = -94
local fire_duration_sec = 30 -- 30 detik

local fireModData = {
    modID = fire_mod_id, 
    modName = "Burning", 
    onAddMessage = "You are burning!", 
    onRemoveMessage = "The fire has gone out.", 
    iconID = FIRE_WAND_ID, 
    changeSkin = {255, 128, 0, 255}, -- Warna orange/merah
    modState = {}
}
local fireWandModID = registerLuaPlaymod(fireModData)

onPlayerConsumableCallback(function(world, player, tile, clickedPlayer, itemID)
    if itemID == FIRE_WAND_ID then
        if clickedPlayer == nil then
            player:onTalkBubble(player:getNetID(), "`wMust be used on a person.``", 1)
            return true
        end
        if clickedPlayer:hasMod(fireWandModID) then
            player:onTalkBubble(player:getNetID(), "`wThis player is already burning.``", 1)
            return true
        end
        
        if player:changeItem(itemID, -1, 0) then
            -- Memberi Mod debuff dan Efek
            clickedPlayer:addMod(fireWandModID, fire_duration_sec)
            world:useItemEffect(player:getNetID(), itemID, clickedPlayer:getNetID(), 0)
            clickedPlayer:playAudio("fireworks.wav")
            
            -- Efek khusus: Teleport ke HELL (seperti Curse Wand)
            clickedPlayer:onConsoleMessage("`4You have been incinerated and sent to HELL!")
            clickedPlayer:enterWorld("HELL", "")
            
            -- player:updateStats(world, PlayerStats.ConsumablesUsed, 1) -- PlayerStats harus didefinisikan secara global
            return true
        end
        return true
    end
    return false
end)