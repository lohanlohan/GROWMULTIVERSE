print("(Loaded) side-button-remake script for GrowSoft")

local disable_for_everyone = true 

onPlayerVariantCallback(function(player, variant, delay, netID)
    local first_element = variant[1]
    if disable_for_everyone or (player:getPlatform() == "4" or player:getPlatform() == "1") then
        if first_element == "OnEventButtonDataSet" then
            if variant[2] == "Coins" then
				-- player:sendVariant({"OnEventButtonDataSet", variant[2], 0, variant[4]}, delay, netID)
				player:sendVariant({ "OnEventButtonDataSet", "Premgems", 1, "{\"active\":true,\"buttonAction\":\"premiummenu\",\"buttonState\":0,\"buttonTemplate\":\"BaseEventButton\",\"counter\":" .. player:GetCoins() .. ",\"counterMax\":0,\"itemIdIcon\":20234,\"name\":\"Premgems\",\"notification\":0,\"order\":5,\"rcssClass\":\"daily_challenge\",\"text\":\"0\"}" }, delay, netID) 
				player:onConsoleMessage(json.encode(variant)) 
				return true
            end
        end
    end
    return false
end)