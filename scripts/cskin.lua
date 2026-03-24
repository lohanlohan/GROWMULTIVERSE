-- Define roles
local Roles = {
    ROLE_NONE = 0,
    ROLE_DEVELOPER = 51,
}

-- Register commands
registerLuaCommand({
    command = "skin",
    roleRequired = Roles.ROLE_NONE,
    description = "Change your skin color from presets"
})

--[[registerLuaCommand({
    command = "customskin",
    roleRequired = Roles.ROLE_DEVELOPER,
    description = "Set custom RGBA skin color. Usage: /customskin <R> <G> <B> <A>"
})

registerLuaCommand({
    command = "resetskin",
    roleRequired = Roles.ROLE_NONE,
    description = "Reset your skin color to default"
})]]

-- Skin color presets with RGBA values
local SKIN_COLORS = {
    -- Basic
    { name = "Default (Reset)", modID = nil, color = "`o", rgba = {255, 206, 180, 255} },
    { name = "Green", modID = -1100, color = "`2", rgba = {52, 235, 107, 255} },
    { name = "Blue", modID = -30, color = "`1", rgba = {100, 149, 237, 255} },
    { name = "Red", modID = -5001, color = "`4", rgba = {220, 20, 60, 255} },
    { name = "Purple", modID = -5002, color = "`5", rgba = {147, 112, 219, 255} },
    { name = "Yellow", modID = -5003, color = "`e", rgba = {255, 215, 0, 255} },
    { name = "Pink", modID = -5004, color = "`#", rgba = {255, 182, 193, 255} },
    { name = "Orange", modID = -5005, color = "`6", rgba = {255, 140, 0, 255} },
    { name = "Dark", modID = -5006, color = "`8", rgba = {47, 79, 79, 255} },
    { name = "White", modID = -5007, color = "`w", rgba = {245, 245, 245, 255} },
    
    -- Skin Tones
    { name = "Light Peach", modID = -5008, color = "`o", rgba = {255, 220, 177, 255} },
    { name = "Medium Brown", modID = -5009, color = "`6", rgba = {194, 140, 98, 255} },
    { name = "Dark Brown", modID = -5010, color = "`8", rgba = {141, 85, 36, 255} },
    
    -- Neon/Glow
    { name = "Neon Green", modID = -5011, color = "`2", rgba = {57, 255, 20, 255} },
    { name = "Neon Pink", modID = -5012, color = "`#", rgba = {255, 20, 147, 255} },
    { name = "Neon Cyan", modID = -5013, color = "`b", rgba = {0, 255, 255, 255} },
    
    -- Metallic
    { name = "Gold", modID = -5014, color = "`e", rgba = {255, 215, 0, 255} },
    { name = "Silver", modID = -5015, color = "`w", rgba = {192, 192, 192, 255} },
    
    -- Fantasy
    { name = "Vampire Purple", modID = -5016, color = "`5", rgba = {148, 0, 211, 255} },
    { name = "Zombie Green", modID = -5017, color = "`2", rgba = {143, 188, 143, 255} },

    -- Nature and Element
    { name = "Ocean Blue", modID = -5027, color = "`b", rgba = {0, 105, 148, 255} },
    { name = "Seafoam Green", modID = -5028, color = "`2", rgba = {159, 226, 191, 255} },
    { name = "Sand Yellow", modID = -5029, color = "`e", rgba = {194, 178, 128, 255} },
    { name = "Volcanic Ash", modID = -5030, color = "`8", rgba = {56, 62, 66, 255} },
    { name = "Magma Red", modID = -5031, color = "`4", rgba = {255, 69, 0, 255} },
    { name = "Sky Blue", modID = -5032, color = "`b", rgba = {135, 206, 235, 255} },
    { name = "Autumn Leaf", modID = -5033, color = "`6", rgba = {210, 105, 30, 255} },
    { name = "Moss Green", modID = -5034, color = "`2", rgba = {138, 154, 91, 255} },
    { name = "Ice White", modID = -5035, color = "`w", rgba = {240, 248, 255, 255} },
    { name = "Thunder Cloud", modID = -5036, color = "`8", rgba = {112, 128, 144, 255} },
    { name = "Coral Pink", modID = -5037, color = "`#", rgba = {255, 127, 80, 255} },
    { name = "Sunlight Gold", modID = -5038, color = "`e", rgba = {253, 253, 150, 255} },
    { name = "Clay Brown", modID = -5039, color = "`6", rgba = {182, 115, 82, 255} },
    { name = "Emerald", modID = -5040, color = "`2", rgba = {80, 200, 120, 255} },
    { name = "Night Sky", modID = -5041, color = "`1", rgba = {6, 12, 47, 255} },

    -- Pastel and Soft Vibes
    { name = "Cotton Candy", modID = -5042, color = "`#", rgba = {255, 183, 197, 255} },
    { name = "Soft Lavender", modID = -5043, color = "`5", rgba = {204, 153, 255, 255} },
    { name = "Baby Blue", modID = -5044, color = "`b", rgba = {137, 207, 240, 255} },
    { name = "Pale Mint", modID = -5045, color = "`2", rgba = {189, 252, 201, 255} },
    { name = "Peach Puff", modID = -5046, color = "`o", rgba = {255, 218, 185, 255} },
    { name = "Lemon Chiffon", modID = -5047, color = "`e", rgba = {255, 250, 205, 255} },
    { name = "Misty Rose", modID = -5048, color = "`w", rgba = {255, 228, 225, 255} },
    { name = "Periwinkle", modID = -5049, color = "`b", rgba = {204, 204, 255, 255} },
    { name = "Apricot", modID = -5050, color = "`6", rgba = {251, 206, 177, 255} },
    { name = "Mauve", modID = -5051, color = "`5", rgba = {224, 176, 255, 255} },
    { name = "Cream", modID = -5052, color = "`w", rgba = {255, 253, 208, 255} },
    { name = "Thistle", modID = -5053, color = "`5", rgba = {216, 191, 216, 255} },
    { name = "Powder Blue", modID = -5054, color = "`b", rgba = {176, 224, 230, 255} },
    { name = "Honeydew", modID = -5055, color = "`2", rgba = {240, 255, 240, 255} },
    { name = "Blush", modID = -5056, color = "`#", rgba = {222, 165, 164, 255} },

    -- Cyberpunk and Neon
    { name = "Retrowave Pink", modID = -5057, color = "`#", rgba = {255, 0, 255, 255} },
    { name = "Cyber Purple", modID = -5058, color = "`p", rgba = {112, 0, 255, 255} },
    { name = "Toxic Green", modID = -5059, color = "`2", rgba = {0, 255, 65, 255} },
    { name = "Laser Blue", modID = -5060, color = "`b", rgba = {0, 238, 255, 255} },
    { name = "Plasma Orange", modID = -5061, color = "`6", rgba = {255, 83, 0, 255} },
    { name = "Neon Red", modID = -5062, color = "`4", rgba = {255, 0, 60, 255} },
    { name = "High-Vis Yellow", modID = -5063, color = "`e", rgba = {223, 255, 0, 255} },
    { name = "Synth Blue", modID = -5064, color = "`1", rgba = {2, 0, 158, 255} },
    { name = "Glitch White", modID = -5065, color = "`w", rgba = {220, 255, 255, 255} },
    { name = "Ultra Violet", modID = -5066, color = "`5", rgba = {93, 0, 255, 255} },
    { name = "Acid Lime", modID = -5067, color = "`q", rgba = {191, 255, 0, 255} },
    { name = "Deep Fusion", modID = -5068, color = "`4", rgba = {128, 0, 32, 255} },
    { name = "Voltage", modID = -5069, color = "`e", rgba = {255, 255, 51, 255} },
    { name = "Hex Code", modID = -5070, color = "`2", rgba = {45, 255, 194, 255} },
    { name = "Dark Circuit", modID = -5071, color = "`8", rgba = {15, 15, 15, 255} },

    --Metalic and Jewels
    { name = "Platinum", modID = -5072, color = "`w", rgba = {229, 228, 226, 255} },
    { name = "Bronze", modID = -5073, color = "`6", rgba = {205, 127, 50, 255} },
    { name = "Ruby Red", modID = -5074, color = "`4", rgba = {224, 17, 95, 255} },
    { name = "Sapphire", modID = -5075, color = "`1", rgba = {15, 82, 186, 255} },
    { name = "Amethyst", modID = -5076, color = "`5", rgba = {153, 102, 204, 255} },
    { name = "Topaz", modID = -5077, color = "`e", rgba = {255, 200, 124, 255} },
    { name = "Obsidian", modID = -5078, color = "`8", rgba = {11, 18, 21, 255} },
    { name = "Copper", modID = -5079, color = "`6", rgba = {184, 115, 51, 255} },
    { name = "Rose Gold", modID = -5080, color = "`#", rgba = {183, 110, 121, 255} },
    { name = "Titanium", modID = -5081, color = "`w", rgba = {135, 134, 129, 255} },
    { name = "Turquoise", modID = -5082, color = "`b", rgba = {64, 224, 208, 255} },
    { name = "Garnet", modID = -5083, color = "`4", rgba = {106, 13, 13, 255} },
    { name = "Pearl", modID = -5084, color = "`w", rgba = {240, 234, 214, 255} },
    { name = "Jade", modID = -5085, color = "`2", rgba = {0, 168, 107, 255} },
    { name = "Onyx", modID = -5086, color = "`8", rgba = {53, 57, 62, 255} },

    -- Deep, Dark & Moody
    { name = "Blood Red", modID = -5087, color = "`4", rgba = {138, 3, 3, 255} },
    { name = "Abyss Blue", modID = -5088, color = "`1", rgba = {0, 3, 58, 255} },
    { name = "Void", modID = -5089, color = "`8", rgba = {2, 2, 2, 255} },
    { name = "Charcoal", modID = -5090, color = "`8", rgba = {54, 69, 79, 255} },
    { name = "Dark Wine", modID = -5091, color = "`4", rgba = {103, 3, 45, 255} },
    { name = "Deep Plum", modID = -5092, color = "`5", rgba = {48, 25, 52, 255} },
    { name = "Gothic Grey", modID = -5093, color = "`8", rgba = {105, 105, 105, 255} },
    { name = "Shadow Brown", modID = -5094, color = "`6", rgba = {62, 39, 35, 255} },
    { name = "Cursed Green", modID = -5095, color = "`2", rgba = {26, 47, 0, 255} },
    { name = "Steel Blue", modID = -5096, color = "`b", rgba = {70, 130, 180, 255} },
    { name = "Maroon", modID = -5097, color = "`4", rgba = {128, 0, 0, 255} },
    { name = "Slate Grey", modID = -5098, color = "`8", rgba = {112, 128, 144, 255} },
    { name = "Ink Black", modID = -5099, color = "`8", rgba = {7, 10, 13, 255} },
    { name = "Dark Olive", modID = -5100, color = "`2", rgba = {85, 107, 47, 255} },
    { name = "Navy", modID = -5101, color = "`1", rgba = {0, 0, 128, 255} },
    { name = "Grape", modID = -5102, color = "`5", rgba = {111, 45, 189, 255} },
    { name = "Dim Gray", modID = -5103, color = "`8", rgba = {105, 105, 105, 255} },
    { name = "Espresso", modID = -5104, color = "`6", rgba = {56, 34, 15, 255} },
    { name = "Burgundy", modID = -5105, color = "`4", rgba = {128, 0, 32, 255} },
    { name = "Cold Steel", modID = -5106, color = "`w", rgba = {176, 196, 222, 255} },

    -- Vibrant & Exotic
    { name = "Lava Orange", modID = -5107, color = "`6", rgba = {255, 102, 0, 255} },
    { name = "Electric Blue", modID = -5108, color = "`b", rgba = {0, 255, 255, 255} },
    { name = "Hot Pink", modID = -5109, color = "`#", rgba = {255, 105, 180, 255} },
    { name = "Sunshine", modID = -5110, color = "`e", rgba = {255, 255, 0, 255} },
    { name = "Forest Green", modID = -5111, color = "`2", rgba = {34, 139, 34, 255} },
    { name = "Royal Blue", modID = -5112, color = "`1", rgba = {65, 105, 225, 255} },
    { name = "Orchid", modID = -5113, color = "`5", rgba = {218, 112, 214, 255} },
    { name = "Tangerine", modID = -5114, color = "`6", rgba = {242, 133, 0, 255} },
    { name = "Lime Punch", modID = -5115, color = "`q", rgba = {210, 255, 0, 255} },
    { name = "Cherry", modID = -5116, color = "`4", rgba = {222, 49, 99, 255} },
    { name = "Aqua", modID = -5117, color = "`b", rgba = {0, 255, 191, 255} },
    { name = "Violet", modID = -5118, color = "`5", rgba = {127, 0, 255, 255} },
    { name = "Fire", modID = -5119, color = "`4", rgba = {226, 88, 34, 255} },
    { name = "Malachite", modID = -5120, color = "`2", rgba = {11, 218, 81, 255} },
    { name = "Dodger Blue", modID = -5121, color = "`b", rgba = {30, 144, 255, 255} },
    { name = "Flamingo", modID = -5122, color = "`#", rgba = {252, 142, 172, 255} },
    { name = "Goldenrod", modID = -5123, color = "`e", rgba = {218, 165, 32, 255} },
    { name = "Indigo", modID = -5124, color = "`5", rgba = {75, 0, 130, 255} },
    { name = "Veridian", modID = -5125, color = "`2", rgba = {64, 130, 109, 255} },
    { name = "Scarlet", modID = -5126, color = "`4", rgba = {255, 36, 0, 255} },
    { name = "Cyanide", modID = -5127, color = "`b", rgba = {0, 183, 235, 255} },
    { name = "Plum", modID = -5128, color = "`5", rgba = {142, 69, 133, 255} },
    { name = "Saffron", modID = -5129, color = "`e", rgba = {244, 196, 48, 255} },
    { name = "Candy Apple", modID = -5130, color = "`4", rgba = {255, 8, 0, 255} },
}

-- Custom skin mod ID (for /customskin command)
local CUSTOM_SKIN_MOD_ID = -6000

-- Track active custom skin colors per player (netID -> {r, g, b, a})
local activeCustomSkins = {}

-- Helper function to validate RGBA values
local function validateRGBA(r, g, b, a)
    if not r or not g or not b then
        return false, "Missing RGB values"
    end
    
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    a = tonumber(a) or 255 -- Default alpha to 255 if not provided
    
    if not r or not g or not b or not a then
        return false, "Invalid number format"
    end
    
    if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 or a < 0 or a > 255 then
        return false, "RGBA values must be between 0-255"
    end
    
    return true, r, g, b, a
end

-- Remove all skin mods from player
local function removeAllSkinMods(player)
    -- Remove preset mods
    for _, skin in ipairs(SKIN_COLORS) do
        if skin.modID and player:hasMod(skin.modID) then
            player:removeMod(skin.modID)
        end
    end
    
    -- Remove custom skin mod
    if player:hasMod(CUSTOM_SKIN_MOD_ID) then
        player:removeMod(CUSTOM_SKIN_MOD_ID)
    end
    
    -- Clear tracking
    activeCustomSkins[player:getNetID()] = nil
end

-- Apply custom RGBA skin to player
local function applyCustomSkin(player, r, g, b, a)
    -- Remove existing skins first
    removeAllSkinMods(player)
    
    -- Register/update custom mod with new RGBA
    local modData = {
        modID = CUSTOM_SKIN_MOD_ID,
        modName = "Custom Skin Color",
        onAddMessage = "Custom skin color applied! (R:" .. r .. " G:" .. g .. " B:" .. b .. " A:" .. a .. ")",
        onRemoveMessage = "Custom skin color removed.",
        iconID = 7074,
        changeSkin = {r, g, b, a},
        modState = {},
        changeMovementSpeed = 0,
        changeAcceleration = 0,
        changeGravity = 0,
        changePunchStrength = 0,
        changeBuildRange = 0,
        changePunchRange = 0,
        changeWaterMovementSpeed = 0
    }
    
    registerLuaPlaymod(modData)
    
    -- Apply the mod
    player:addMod(CUSTOM_SKIN_MOD_ID, 0)
    
    -- Track for display
    activeCustomSkins[player:getNetID()] = {r = r, g = g, b = b, a = a}
end

local function showSkinColorDialog(player)
    local dialog = "set_default_color|`o\n"
    dialog = dialog .. "add_label_with_icon|big|`wSkin Color Changer|left|7074|\n"
    dialog = dialog .. "add_smalltext|`oChoose your desired skin color|left|\n"
    dialog = dialog .. "add_spacer|small|\n"

    for i, skin in ipairs(SKIN_COLORS) do
        local buttonText = skin.color .. skin.name

        if skin.modID == nil then
            dialog = dialog .. "add_button|skincolor_" .. i .. "|" .. buttonText .. " `o(Remove Effect)|noflags|0|0|\n"
        else
            dialog = dialog .. "add_button|skincolor_" .. i .. "|" .. buttonText .. "|noflags|0|0|\n"
        end
    end

    dialog = dialog .. "add_spacer|small|\n"
    dialog = dialog .. "add_smalltext|`9Note: Skin colors are temporary and will reset on relog|left|\n"
    dialog = dialog .. "add_button|close_skincolor|`wClose|noflags|0|0|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|skincolor_dialog|||\n"

    player:onDialogRequest(dialog)
end


-- Register custom skin color playmods (if not already registered)
local function registerSkinColorMods()
    for _, skin in ipairs(SKIN_COLORS) do
        if skin.modID and skin.modID < -5000 then -- Custom mods
            local modData = {
                modID = skin.modID,
                modName = skin.name .. " Skin",
                onAddMessage = "Your skin is now " .. skin.name:lower() .. "!",
                onRemoveMessage = "Skin color restored.",
                iconID = 7074,
                changeSkin = skin.rgba,
                modState = {},
                changeMovementSpeed = 0,
                changeAcceleration = 0,
                changeGravity = 0,
                changePunchStrength = 0,
                changeBuildRange = 0,
                changePunchRange = 0,
                changeWaterMovementSpeed = 0
            }
            
            registerLuaPlaymod(modData)
        end
    end
end

-- Initialize on server start
registerSkinColorMods()

-- Handle commands
onPlayerCommandCallback(function(world, player, fullCommand)
    local parts = {}
    for part in fullCommand:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    local command = parts[1]
    
    -- Handle /skincolor command
    if command == "skin" then
        showSkinColorDialog(player)
        player:playAudio("audio/dialog_open.wav", 0)
        return true
    end
    
    --[[ Handle /resetskin command
    if command == "resetskin" then
        removeAllSkinMods(player)
        world:updateClothing(player)
        player:onConsoleMessage("`2Skin color reset to default!")
        player:playAudio("audio/checkpoint.wav", 0)
        return true
    end
    
    -- Handle /customskin command
    if command == "customskin" then
        if #parts < 4 then
            player:onConsoleMessage("`4Usage: /customskin <R> <G> <B> <A>")
            player:onConsoleMessage("`9Example: /customskin 255 100 50 255")
            player:onConsoleMessage("`9RGBA values must be 0-255")
            player:playAudio("audio/bleep_fail.wav", 0)
            return true
        end
        
        local r, g, b = parts[2], parts[3], parts[4]
        local a = parts[5] or "255" -- Default alpha
        
        local valid, rVal, gVal, bVal, aVal = validateRGBA(r, g, b, a)
        
        if not valid then
            player:onConsoleMessage("`4Error: " .. rVal) -- rVal contains error message
            player:onConsoleMessage("`9Usage: /customskin <R> <G> <B> <A>")
            player:onConsoleMessage("`9All values must be 0-255")
            player:playAudio("audio/bleep_fail.wav", 0)
            return true
        end
        
        -- Apply custom skin
        applyCustomSkin(player, rVal, gVal, bVal, aVal)
        player:onConsoleMessage("`2Custom skin applied! `o(R:" .. rVal .. " G:" .. gVal .. " B:" .. bVal .. " A:" .. aVal .. ")")
        player:playAudio("audio/checkpoint.wav", 0)
        return true
    end]]
    
    return false
end)

-- Handle dialog callbacks
onPlayerDialogCallback(function(world, player, data)
    local dialogName = data["dialog_name"]
    local button = data["buttonClicked"]
    
    if dialogName == "skincolor_dialog" then
        -- Check if it's a color selection button
        if button:match("^skincolor_(%d+)$") then
            local index = tonumber(button:match("^skincolor_(%d+)$"))
            local selectedSkin = SKIN_COLORS[index]
            
            if not selectedSkin then
                player:onConsoleMessage("`4Invalid skin color selection!")
                player:playAudio("audio/bleep_fail.wav", 0)
                return true
            end
            
            -- Remove all existing skin mods first
            removeAllSkinMods(player)
            
            -- Apply new skin color or reset
            if selectedSkin.modID == nil then
                -- Reset to default
                world:updateClothing(player)
                player:onConsoleMessage("`2Skin color reset to default!")
                player:playAudio("audio/checkpoint.wav", 0)
            else
                -- Apply preset color
                player:addMod(selectedSkin.modID, 0) -- 0 = permanent until removed
                world:updateClothing(player)
                player:onConsoleMessage(selectedSkin.color .. "Skin color changed to " .. selectedSkin.name .. "`2!")
                player:playAudio("audio/checkpoint.wav", 0)
            end
            
            return true
            
        elseif button == "close_skincolor" then
            player:playAudio("audio/dialog_close.wav", 0)
            return true
        end
    end
    
    return false
end)

-- Cleanup on disconnect
onPlayerDisconnectCallback(function(player)
    local netID = player:getNetID()
    if activeCustomSkins[netID] then
        activeCustomSkins[netID] = nil
    end
end)