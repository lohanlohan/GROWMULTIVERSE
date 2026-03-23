local FURNACE = {
  MACHINE_ID      = 25014,
  
  STORE           = "furnace_db_v1",
  MACH            = {},        
  SAVE_DIRTY      = false,
  DIALOG          = "furnace_ui",
  ACTIVE_UI       = {},        

  LEVELS = { -- Upgrade Machine
    [1] = { cap = 5000,    upgrade_item = 0,     desc = "Basic" },
    [2] = { cap = 10000,   upgrade_item = 9642,  desc = "Advanced" }, 
    [3] = { cap = 100000,  upgrade_item = 10424, desc = "Industrial" }, 
    [4] = { cap = 1000000, upgrade_item = 11550, desc = "Godly" }       
  }
}

local function format_time(seconds)
  if seconds <= 0 then return "00D 00H 00M 00S" end
  local days  = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local mins  = math.floor((seconds % 3600) / 60)
  local secs  = seconds % 60
  return string.format("%02dD %02dH %02dM %02dS", days, hours, mins, secs)
end

local function get_machine_key(world, tile)
  return "w:" .. world:getID() .. ":" .. tile:getPosX() .. "," .. tile:getPosY()
end

local function is_valid_input(itemID)
  local item = getItem(itemID) 
  if not item then return false end
  return item:getActionType() == 19
end

local function get_output_id(inputID)
  if not is_valid_input(inputID) then return nil end
  return inputID - 1 
end

local function furnace_load()
  local t = loadDataFromServer(FURNACE.STORE) or {}
  FURNACE.MACH = (type(t) == "table") and t or {}
end

local function furnace_save(force)
  if force or FURNACE.SAVE_DIRTY then
    saveDataToServer(FURNACE.STORE, FURNACE.MACH)
    FURNACE.SAVE_DIRTY = false
  end
end

onAutoSaveRequest(function() furnace_save(true) end)
furnace_load()

local function process_furnace(m)
    if not m or (m.input_count or 0) <= 0 or m.input_id == 0 then 
        m.elapsed_stored = 0
        m.last_calc = os.time()
        return 
    end

    local item = getItem(m.input_id)
    local duration = (item and item:getGrowTime() > 0) and item:getGrowTime() or 10
    local now = os.time()

    if not m.last_calc or m.last_calc == 0 then
        m.last_calc = now
    end

    local diff = now - m.last_calc
    
    if m.is_active then
        m.elapsed_stored = (m.elapsed_stored or 0) + diff
    end
  
    m.last_calc = now

    if (m.elapsed_stored or 0) >= duration then
        local processed_all = m.input_count
        
        m.ready_count = (m.ready_count or 0) + processed_all
        m.active_id = m.input_id 
        m.input_count = 0 
        
        m.elapsed_stored = 0 
        FURNACE.SAVE_DIRTY = true
    end
end

onTilePlaceCallback(function(world, player, tile, placingID)
  if placingID ~= FURNACE.MACHINE_ID then return false end
  local mk = get_machine_key(world, tile)
  
  FURNACE.MACH[mk] = { 
    input_id = 0, 
    input_count = 0, 
    ready_count = 0, 
    last_calc = os.time(),
    level = 1,
    is_active = false 
  }
  
  FURNACE.SAVE_DIRTY = true 
  player:onConsoleMessage("`w[Grow-o-Matic]`` Machine placed! Status: `4OFF``. `wPunch to Activate!``")
  return false
end)

onTilePunchCallback(function(world, avatar, tile)
    if tile:getTileID() ~= FURNACE.MACHINE_ID then return false end

    if not world:hasAccess(avatar) then 
       -- avatar:onConsoleMessage("`4[Security]`` You don't have access to this machine!")
        return true 
    end

    local mk = get_machine_key(world, tile)
    local m = FURNACE.MACH[mk]
    
    if not m then return false end

    process_furnace(m)
    
    local is_empty = (m.input_count or 0) == 0 and (m.ready_count or 0) == 0

    if not is_empty then
        avatar:adjustBlockHitCount(10) 
        
        m.is_active = not m.is_active
        
        local flags = tile:getFlags()
        local FLAG_ON = 64
        local is_visually_on = bit.band(flags, FLAG_ON) ~= 0

        if m.is_active then
            avatar:onConsoleMessage("`2[Grow-o-Matic]`` Machine is now `2ON``.")
            if not is_visually_on then tile:setFlags(flags + FLAG_ON) end
        else
            avatar:onConsoleMessage("`4[Grow-o-Matic]`` Machine is now `4OFF``.")
            if is_visually_on then tile:setFlags(flags - FLAG_ON) end
        end
        
        world:updateTile(tile)
        FURNACE.SAVE_DIRTY = true
        return true 
    else
        avatar:onConsoleMessage("`w[Grow-o-Matic]`` Machine is empty. You can break it now.")
        avatar:adjustBlockHitCount(0) 
        FURNACE.MACH[mk] = nil 
        FURNACE.SAVE_DIRTY = true
        
        return false 
    end
end)

onTileWrenchCallback(function(world, player, tile)
  if tile:getTileID() ~= FURNACE.MACHINE_ID then return false end
  if not world:hasAccess(player) then
        player:onConsoleMessage("`4[Security]`` Only world admins can configure this machine!")
        return true 
    end
  local mk = get_machine_key(world, tile)
  local m = FURNACE.MACH[mk] or { 
    input_id = 0, 
    input_count = 0, 
    ready_count = 0, 
    last_calc = os.time(), 
    level = 1,
    elapsed_stored = 0,
    is_active = false
  }
  FURNACE.MACH[mk] = m

  process_furnace(m)
  FURNACE.ACTIVE_UI["u:" .. player:getUserID()] = mk

  local currentLv = m.level or 1
  local config = FURNACE.LEVELS[currentLv]
  local nextLv = currentLv + 1
  local maxCap = config.cap
  local upgradeConfig = FURNACE.LEVELS[nextLv]

  local item = getItem(m.input_id)
  local input_name = item and item:getName() or "None"
  local duration = (item and item:getGrowTime() > 0) and item:getGrowTime() or 10

  local status_txt = m.is_active and "`2ACTIVE (ON)``" or "`4INACTIVE (OFF)``"
  local time_status = "Status: `4Waiting for input...``"

  if m.input_count > 0 then
    local remaining = duration - (m.elapsed_stored or 0)
    if remaining < 0 then remaining = 0 end
    
    if m.is_active then
        time_status = "Batch Processing: `w" .. format_time(remaining) .. " left``"
    else
        time_status = "Status: `4Paused`` (`w" .. format_time(remaining) .. " remaining``)"
    end
  elseif (m.ready_count or 0) > 0 then
    time_status = "Status: `2Batch Completed! (" .. m.ready_count .. " items ready)``"
  end
  
  local dialog = {
    "set_default_color|`o|",
    "add_label_with_icon|big|`wGrow-o-Matic (Lv. " .. currentLv .. ")``|left|" .. FURNACE.MACHINE_ID .. "|",
    "add_smalltext|Machine Type: `^" .. config.desc .. "``|",
    "add_spacer|small|",
    "add_smalltext|Machine Status: " .. status_txt .. "|",
    "add_smalltext|Capacity: `w" .. m.input_count .. "`` / `^" .. maxCap .. "``|",
    "add_smalltext|Input: `w" .. input_name .. " (x" .. m.input_count .. ")``|",
    "add_smalltext|Ready: `5" .. m.ready_count .. " trees``|",
    "add_smalltext|Base Growtime: `w" .. format_time(duration) .. "/item``|",
    "add_smalltext|" .. time_status .. "|",
    
    "add_custom_break|",
    "add_item_picker|input_item|Insert Seeds|Select seeds to plant|",
    "add_button|btn_collect|Collect Harvest|noflags|0|0|",
    "add_button|btn_cancel|`4Cancel & Refund Input``|noflags|0|0|"
  }

  if upgradeConfig then
    local reqItem = getItem(upgradeConfig.upgrade_item)
    table.insert(dialog, "add_custom_break|")
    table.insert(dialog, "add_label_with_icon|small|`2Upgrade to Lv. " .. nextLv .. "``|left|" .. upgradeConfig.upgrade_item .. "|")
    table.insert(dialog, "add_smalltext|Req: `w1x " .. (reqItem and reqItem:getName() or "Upgrade Part") .. "``|")
    table.insert(dialog, "add_smalltext|New Capacity: `^" .. upgradeConfig.cap .. "``|")
    table.insert(dialog, "add_button|btn_upgrade|Upgrade Machine|noflags|0|0|")
  else
    table.insert(dialog, "add_custom_break|")
    table.insert(dialog, "add_smalltext|`#Max Level Reached!``|")
  end

  table.insert(dialog, "end_dialog|" .. FURNACE.DIALOG .. "|Close||")
  
  player:onDialogRequest(table.concat(dialog, "\n"))
  return true
end)

local function showRefundConfirm(player, mk)
  local m = FURNACE.MACH[mk]
  if not m or (m.input_count or 0) <= 0 or m.input_id == 0 then
    player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
    return
  end
  local item = getItem(m.input_id)
  local itemName = item and item:getName() or "Unknown"
  player:onDialogRequest(
    "set_default_color|`o\n" ..
    "add_label_with_icon|big|`wCancel & Refund``|left|" .. FURNACE.MACHINE_ID .. "|\n" ..
    "add_spacer|small|\n" ..
    "add_textbox|`oReturn `w" .. m.input_count .. "x " .. itemName .. "`` to your `2Backpack``?``|\n" ..
    "add_spacer|small|\n" ..
    "add_button|btn_refund_confirm|`2Yes, Refund``|noflags|0|0|\n" ..
    "add_button|btn_refund_cancel|`oNo, Keep It``|noflags|0|0|\n" ..
    "end_dialog|furnace_refund_confirm|||"
  )
end

onPlayerDialogCallback(function(world, player, data)
  if data.dialog_name ~= FURNACE.DIALOG then return false end
  
  local mk = FURNACE.ACTIVE_UI["u:" .. player:getUserID()]
  local m = FURNACE.MACH[mk]
  if not m then return true end

  local btn = data.buttonClicked
  local currentLv = m.level or 1
  local maxCap = FURNACE.LEVELS[currentLv].cap

  if btn == "btn_upgrade" then
    local nextLv = currentLv + 1
    local upgradeConfig = FURNACE.LEVELS[nextLv]

    if upgradeConfig then
      if player:getItemAmount(upgradeConfig.upgrade_item) >= 1 then
        player:changeItem(upgradeConfig.upgrade_item, -1, 0)
        
        m.level = nextLv 
        
        FURNACE.SAVE_DIRTY = true 
        saveDataToServer(FURNACE.STORE, FURNACE.MACH) 
        
        player:onConsoleMessage("`2[Success]`` Machine upgraded to `wLevel " .. nextLv .. "``!")
        player:sendAction("action|play_sfx\nfile|audio/upgrade.wav\ndelayMS|0")
      else
        player:onConsoleMessage("`4[Failed]`` You don't have the upgrade item!")
      end
    end
    return true

  elseif btn == "btn_collect" then
    process_furnace(m) 
    
    if (m.ready_count or 0) > 0 then
        local inputID = m.active_id or m.input_id 
        local item = getItem(inputID)
        local outputID = get_output_id(inputID) or 2 
        
        if not item then return true end

        local rarity = item:getRarity()
        local maxDrop = 4 
        if rarity >= 0 and rarity <= 14 then maxDrop = 4
        elseif rarity >= 15 and rarity <= 29 then maxDrop = 6
        elseif rarity >= 30 and rarity <= 74 then maxDrop = 8
        elseif rarity > 74 then maxDrop = 12 end

        local gemMin = math.max(1, math.floor(rarity / 5)) 
        local gemMax = math.max(2, math.floor(rarity / 3))

        local avgBlocksPerSeed = (1 + maxDrop) / 2
        local avgGemsPerSeed = (gemMin + gemMax) / 2
        local varianceModifier = math.random(95, 105) / 100 

        local totalBlocks = math.floor((m.ready_count * avgBlocksPerSeed) * varianceModifier)
        local totalGems = math.floor((m.ready_count * avgGemsPerSeed) * varianceModifier)

        local seedDivisor = math.random(10, 16)
        local totalSeeds = math.floor(m.ready_count / seedDivisor)
        if totalSeeds == 0 and m.ready_count >= 10 then totalSeeds = 1 end

        local remainingBlocks = totalBlocks
        local remainingSeeds = totalSeeds
        local blocksToMag = 0
        local seedsToMag = 0
        
        if remainingBlocks > 0 or remainingSeeds > 0 then
            for _, tile in ipairs(world:getTiles()) do
                local tID = tile:getTileID()
                
                if tID == 5638 or tID == 20590 then 
                    local magItemID = tile:getTileData(13)
                    local currentStock = tile:getTileData(2)
                    
                    local magCap = (tID == 5638) and 5000 or 20000
                    local spaceInMag = magCap - currentStock

                    if spaceInMag > 0 then
                        if remainingBlocks > 0 and magItemID == outputID then
                            local toAdd = math.min(remainingBlocks, spaceInMag)
                            tile:setTileData(2, currentStock + toAdd)
                            blocksToMag = blocksToMag + toAdd
                            remainingBlocks = remainingBlocks - toAdd
                            world:updateTile(tile)
                            
                            spaceInMag = magCap - (currentStock + toAdd)
                        end

                        if remainingSeeds > 0 and magItemID == inputID and spaceInMag > 0 then
                            local toAdd = math.min(remainingSeeds, spaceInMag)
                            tile:setTileData(2, tile:getTileData(2) + toAdd)
                            seedsToMag = seedsToMag + toAdd
                            remainingSeeds = remainingSeeds - toAdd
                            world:updateTile(tile)
                        end
                    end
                end
                if remainingBlocks <= 0 and remainingSeeds <= 0 then break end
            end
        end 

        if remainingBlocks > 0 then player:changeItem(outputID, remainingBlocks, 1) end
        if remainingSeeds > 0 then player:changeItem(inputID, remainingSeeds, 1) end
        
        player:addGems(totalGems, 1, 1)
        player:changeItem(0, 0, 1) 

        player:onConsoleMessage("`w[Grow-o-Matic]`` Harvest complete! `w" .. m.ready_count .. " trees`` processed.")
        player:onConsoleMessage("`b- Gems Obtained: `w" .. totalGems .. "``")
        
        if blocksToMag > 0 or seedsToMag > 0 then
            player:onConsoleMessage("`2- Magplant (Filled): `w" .. blocksToMag .. " Blocks, " .. seedsToMag .. " Seeds``")
        end
        
        if remainingBlocks > 0 or remainingSeeds > 0 then
            player:onConsoleMessage("`4- Backpack (Overflow): `w" .. remainingBlocks .. " Blocks, " .. remainingSeeds .. " Seeds``")
        end

        player:sendAction("action|play_sfx\nfile|audio/harvest.wav\ndelayMS|0")
        
m.ready_count = 0
        m.is_active = false 
        
        if (m.input_count or 0) == 0 then 
            m.active_id = 0 
            m.input_id = 0 
        end
        
        local x_str, y_str = mk:match("(%d+),(%d+)$") 
        if x_str and y_str then
            local tx, ty = tonumber(x_str), tonumber(y_str)
            local t_obj = world:getTile(tx, ty)
            
            if t_obj then
                local flags = t_obj:getFlags()
                
                if bit.band(flags, 64) ~= 0 then
                    t_obj:setFlags(flags - 64)
                end
                
                world:updateTile(t_obj) 
            end
        end
        
        FURNACE.SAVE_DIRTY = true
    else
        player:onTalkBubble(player:getNetID(), "`4Nothing to harvest. Load some seeds first!``", 0)
        player:sendAction("action|play_sfx\nfile|audio/punch_air.wav\ndelayMS|0")
    end
    return true

  elseif btn == "btn_cancel" then
    if (m.input_count or 0) > 0 and m.input_id ~= 0 then
      showRefundConfirm(player, mk)
    else
      player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
    end
    return true

  elseif data.input_item then
    local itemID = tonumber(data.input_item)
    if not is_valid_input(itemID) then
      player:onConsoleMessage("`4[Grow-o-Matic]`` Item not compatible!")
      return true
    end

    if m.input_id ~= 0 and m.input_id ~= itemID then
      player:onConsoleMessage("`4[Grow-o-Matic]`` Finish the current batch first!")
      return true
    end

    local spaceLeft = maxCap - (m.input_count or 0)
    if spaceLeft <= 0 then
      player:onConsoleMessage("`4[Grow-o-Matic]`` Machine is full!")
      return true
    end

    local totalAdded = 0
    local backpackAmount = player:getItemAmount(itemID)
    local magplantAmount = 0

    if backpackAmount > 0 then
      local toPull = math.min(backpackAmount, spaceLeft)
      player:changeItem(itemID, -toPull, 0)
      totalAdded = totalAdded + toPull
      spaceLeft = spaceLeft - toPull
    end

    if spaceLeft > 0 then
      for _, tile in ipairs(world:getTiles()) do
        local tID = tile:getTileID()
        if tID == 5638 or tID == 20590 then
          if tile:getTileData(13) == itemID and tile:getTileData(2) > 0 then
            local toPull = math.min(tile:getTileData(2), spaceLeft)
            totalAdded = totalAdded + toPull
            magplantAmount = magplantAmount + toPull
            tile:setTileData(2, tile:getTileData(2) - toPull)
            world:updateTile(tile)
            spaceLeft = spaceLeft - toPull
          end
        end
        if spaceLeft <= 0 then break end
      end
    end

    if totalAdded > 0 then
      m.input_id = itemID
      m.input_count = (m.input_count or 0) + totalAdded
      m.last_calc = os.time()
      
      player:onConsoleMessage("`w[Grow-o-Matic]`` Added `^" .. totalAdded .. "`` seeds.")
      
      if not m.is_active then
        player:onConsoleMessage("`4[Grow-o-Matic]`` Machine is `4OFF``. Punch machine to start processing!")
      end
      
      player:changeItem(0, 0, 1)
    else
      player:onConsoleMessage("`4[Grow-o-Matic]`` No seeds found!")
    end
  end

  FURNACE.SAVE_DIRTY = true
  return true
end)

onPlayerDialogCallback(function(world, player, data)
  if data.dialog_name ~= "furnace_refund_confirm" then return false end

  if data.buttonClicked ~= "btn_refund_confirm" then return true end

  local mk = FURNACE.ACTIVE_UI["u:" .. player:getUserID()]
  local m  = FURNACE.MACH[mk]
  -- Baca nilai DULU sebelum apapun diubah
  local refundID     = m and m.input_id    or 0
  local refundAmount = m and m.input_count or 0
  if not m or refundAmount <= 0 or refundID == 0 then
    player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
    return true
  end
  local item         = getItem(refundID)
  local itemName     = item and item:getName() or "item"

  -- Update Backpack via shared global (set by Backpack.lua at load)
  -- _G.BP_storeItem updates in-memory state + saves file atomically
  if type(_G.BP_storeItem) == "function" then
    _G.BP_storeItem(player, refundID, refundAmount)
    player:onConsoleMessage("`w[Grow-o-Matic]`` Input cancelled. `w" .. refundAmount .. "x " .. itemName .. "`` has been returned to your `2Backpack``.")
  else
    -- Backpack module not loaded — give to inventory instead
    player:changeItem(refundID, refundAmount, 1)
    player:onConsoleMessage("`w[Grow-o-Matic]`` Input cancelled. `w" .. refundAmount .. "x " .. itemName .. "`` has been returned to your inventory.")
  end

  m.input_id      = 0
  m.input_count   = 0
  m.elapsed_stored = 0
  m.last_calc     = os.time()
  m.is_active     = false

  local x, y = mk:match(":(%d+),(%d+)$")
  if x and y then
    local t_obj = world:getTile(tonumber(x), tonumber(y))
    if t_obj then
      local flags = t_obj:getFlags()
      if bit.band(flags, 64) ~= 0 then
        t_obj:setFlags(flags - 64)
        world:updateTile(t_obj)
      end
    end
  end

  FURNACE.SAVE_DIRTY = true
  return true
end)