-- MODULE
-- grow_matic.lua — Grow-o-Matic machine (item 25006): proses benih → blok + gems

local M     = {}
local Utils = _G.Utils
local DB    = _G.DB

local MACHINE_ID = 25006
local DIALOG     = "furnace_ui"

local LEVELS = {
    [1] = { cap = 5000,    upgrade_item = 0,     desc = "Basic"      },
    [2] = { cap = 10000,   upgrade_item = 9642,  desc = "Advanced"   },
    [3] = { cap = 100000,  upgrade_item = 10424, desc = "Industrial"  },
    [4] = { cap = 1000000, upgrade_item = 11550, desc = "Godly"       },
}

-- =======================================================
-- STATE (in-memory + server key-value save)
-- =======================================================

local MACH       = {}
local SAVE_DIRTY = false
local ACTIVE_UI  = {}   -- "u:{uid}" → machine key

local function machLoad()
    local t = DB.load("GROWMATIC")
    MACH = (type(t) == "table") and t or {}
end

local function machSave(force)
    if force or SAVE_DIRTY then
        DB.save("GROWMATIC", MACH)
        SAVE_DIRTY = false
    end
end

onAutoSaveRequest(function() machSave(true) end)
machLoad()

-- =======================================================
-- HELPERS
-- =======================================================

local function machKey(world, tile)
    return "w:" .. world:getID() .. ":" .. tile:getPosX() .. "," .. tile:getPosY()
end

local function isValidInput(itemID)
    local item = getItem(itemID)
    if not item then return false end
    return item:getActionType() == 19
end

local function getOutputID(inputID)
    if not isValidInput(inputID) then return nil end
    return inputID - 1
end

local function formatTime(seconds)
    if seconds <= 0 then return "00D 00H 00M 00S" end
    local days  = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins  = math.floor((seconds % 3600) / 60)
    local secs  = seconds % 60
    return string.format("%02dD %02dH %02dM %02dS", days, hours, mins, secs)
end

-- =======================================================
-- PROCESS LOGIC
-- =======================================================

local function processFurnace(m)
    if not m or (m.input_count or 0) <= 0 or m.input_id == 0 then
        m.elapsed_stored = 0
        m.last_calc      = os.time()
        return
    end

    local item     = getItem(m.input_id)
    local duration = (item and item:getGrowTime() > 0) and item:getGrowTime() or 10
    local now      = os.time()

    if not m.last_calc or m.last_calc == 0 then m.last_calc = now end

    local diff = now - m.last_calc
    if m.is_active then m.elapsed_stored = (m.elapsed_stored or 0) + diff end
    m.last_calc = now

    if (m.elapsed_stored or 0) >= duration then
        m.ready_count    = (m.ready_count or 0) + m.input_count
        m.active_id      = m.input_id
        m.input_count    = 0
        m.elapsed_stored = 0
        SAVE_DIRTY       = true
    end
end

-- =======================================================
-- CALLBACKS
-- =======================================================

onTilePlaceCallback(function(world, player, tile, placingID)
    if placingID ~= MACHINE_ID then return false end
    local mk = machKey(world, tile)
    MACH[mk] = {
        input_id     = 0,
        input_count  = 0,
        ready_count  = 0,
        last_calc    = os.time(),
        level        = 1,
        is_active    = false,
    }
    SAVE_DIRTY = true
    player:onConsoleMessage("`w[Grow-o-Matic]`` Machine placed! Status: `4OFF``. `wPunch to Activate!``")
    return false
end)

onTilePunchCallback(function(world, avatar, tile)
    if tile:getTileID() ~= MACHINE_ID then return false end

    if not world:hasAccess(avatar) then return true end

    local mk = machKey(world, tile)
    local m  = MACH[mk]
    if not m then return false end

    processFurnace(m)

    local isEmpty = (m.input_count or 0) == 0 and (m.ready_count or 0) == 0

    if not isEmpty then
        avatar:adjustBlockHitCount(10)
        m.is_active = not m.is_active

        local flags      = tile:getFlags()
        local FLAG_ON    = 64
        local isVisualOn = bit.band(flags, FLAG_ON) ~= 0

        if m.is_active then
            avatar:onConsoleMessage("`2[Grow-o-Matic]`` Machine is now `2ON``.")
            if not isVisualOn then tile:setFlags(flags + FLAG_ON) end
        else
            avatar:onConsoleMessage("`4[Grow-o-Matic]`` Machine is now `4OFF``.")
            if isVisualOn then tile:setFlags(flags - FLAG_ON) end
        end

        world:updateTile(tile)
        SAVE_DIRTY = true
        return true
    else
        avatar:onConsoleMessage("`w[Grow-o-Matic]`` Machine is empty. You can break it now.")
        avatar:adjustBlockHitCount(0)
        MACH[mk]   = nil
        SAVE_DIRTY = true
        return false
    end
end)

-- =======================================================
-- WRENCH DIALOG
-- =======================================================

onTileWrenchCallback(function(world, player, tile)
    if tile:getTileID() ~= MACHINE_ID then return false end
    if not world:hasAccess(player) then
        player:onConsoleMessage("`4[Security]`` Only world admins can configure this machine!")
        return true
    end

    local mk = machKey(world, tile)
    local m  = MACH[mk] or {
        input_id      = 0,
        input_count   = 0,
        ready_count   = 0,
        last_calc     = os.time(),
        level         = 1,
        elapsed_stored = 0,
        is_active     = false,
    }
    MACH[mk] = m

    processFurnace(m)
    ACTIVE_UI["u:" .. player:getUserID()] = mk

    local currentLv    = m.level or 1
    local config       = LEVELS[currentLv]
    local nextLv       = currentLv + 1
    local maxCap       = config.cap
    local upgradeConfig = LEVELS[nextLv]

    local item       = getItem(m.input_id)
    local inputName  = item and item:getName() or "None"
    local duration   = (item and item:getGrowTime() > 0) and item:getGrowTime() or 10

    local statusTxt  = m.is_active and "`2ACTIVE (ON)``" or "`4INACTIVE (OFF)``"
    local timeStatus = "Status: `4Waiting for input...``"

    if (m.input_count or 0) > 0 then
        local remaining = duration - (m.elapsed_stored or 0)
        if remaining < 0 then remaining = 0 end
        if m.is_active then
            timeStatus = "Batch Processing: `w" .. formatTime(remaining) .. " left``"
        else
            timeStatus = "Status: `4Paused`` (`w" .. formatTime(remaining) .. " remaining``)"
        end
    elseif (m.ready_count or 0) > 0 then
        timeStatus = "Status: `2Batch Completed! (" .. m.ready_count .. " items ready)``"
    end

    local dialog = {
        "set_default_color|`o|",
        "add_label_with_icon|big|`wGrow-o-Matic (Lv. " .. currentLv .. ")``|left|" .. MACHINE_ID .. "|",
        "add_smalltext|Machine Type: `^" .. config.desc .. "``|",
        "add_spacer|small|",
        "add_smalltext|Machine Status: " .. statusTxt .. "|",
        "add_smalltext|Capacity: `w" .. m.input_count .. "`` / `^" .. maxCap .. "``|",
        "add_smalltext|Input: `w" .. inputName .. " (x" .. m.input_count .. ")``|",
        "add_smalltext|Ready: `5" .. m.ready_count .. " trees``|",
        "add_smalltext|Base Growtime: `w" .. formatTime(duration) .. "/item``|",
        "add_smalltext|" .. timeStatus .. "|",
        "add_custom_break|",
        "add_item_picker|input_item|Insert Seeds|Select seeds to plant|",
        "add_button|btn_collect|Collect Harvest|noflags|0|0|",
        "add_button|btn_cancel|`4Cancel & Refund Input``|noflags|0|0|",
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

    table.insert(dialog, "end_dialog|" .. DIALOG .. "|Close||")
    player:onDialogRequest(table.concat(dialog, "\n"))
    return true
end)

-- =======================================================
-- DIALOG CALLBACKS
-- =======================================================

local function showRefundConfirm(player, mk)
    local m = MACH[mk]
    if not m or (m.input_count or 0) <= 0 or m.input_id == 0 then
        player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
        return
    end
    local item     = getItem(m.input_id)
    local itemName = item and item:getName() or "Unknown"
    player:onDialogRequest(
        "set_default_color|`o\n" ..
        "add_label_with_icon|big|`wCancel & Refund``|left|" .. MACHINE_ID .. "|\n" ..
        "add_spacer|small|\n" ..
        "add_textbox|`oReturn `w" .. m.input_count .. "x " .. itemName .. "`` to your `2Backpack``?``|\n" ..
        "add_spacer|small|\n" ..
        "add_button|btn_refund_confirm|`2Yes, Refund``|noflags|0|0|\n" ..
        "add_button|btn_refund_cancel|`oNo, Keep It``|noflags|0|0|\n" ..
        "end_dialog|furnace_refund_confirm|||"
    )
end

onPlayerDialogCallback(function(world, player, data)
    if data.dialog_name ~= DIALOG then return false end

    local mk = ACTIVE_UI["u:" .. player:getUserID()]
    local m  = MACH[mk]
    if not m then return true end

    local btn      = data.buttonClicked
    local currentLv = m.level or 1
    local maxCap    = LEVELS[currentLv].cap

    -- Upgrade
    if btn == "btn_upgrade" then
        local nextLv       = currentLv + 1
        local upgradeConfig = LEVELS[nextLv]
        if upgradeConfig then
            if player:getItemAmount(upgradeConfig.upgrade_item) >= 1 then
                player:changeItem(upgradeConfig.upgrade_item, -1, 0)
                m.level    = nextLv
                SAVE_DIRTY = true
                machSave(true)
                player:onConsoleMessage("`2[Success]`` Machine upgraded to `wLevel " .. nextLv .. "``!")
                player:sendAction("action|play_sfx\nfile|audio/upgrade.wav\ndelayMS|0")
            else
                player:onConsoleMessage("`4[Failed]`` You don't have the upgrade item!")
            end
        end
        return true

    -- Collect harvest
    elseif btn == "btn_collect" then
        processFurnace(m)

        if (m.ready_count or 0) > 0 then
            local inputID  = m.active_id or m.input_id
            local item     = getItem(inputID)
            local outputID = getOutputID(inputID) or 2

            if not item then return true end

            local rarity   = item:getRarity()
            local maxDrop  = 4
            if     rarity >= 75                  then maxDrop = 12
            elseif rarity >= 30                  then maxDrop = 8
            elseif rarity >= 15                  then maxDrop = 6
            end

            local gemMin = math.max(1, math.floor(rarity / 5))
            local gemMax = math.max(2, math.floor(rarity / 3))

            local avgBlocks   = (1 + maxDrop) / 2
            local avgGems     = (gemMin + gemMax) / 2
            local variance    = math.random(95, 105) / 100

            local totalBlocks = math.floor((m.ready_count * avgBlocks) * variance)
            local totalGems   = math.floor((m.ready_count * avgGems)   * variance)

            local seedDivisor  = math.random(10, 16)
            local totalSeeds   = math.floor(m.ready_count / seedDivisor)
            if totalSeeds == 0 and m.ready_count >= 10 then totalSeeds = 1 end

            local remBlocks   = totalBlocks
            local remSeeds    = totalSeeds
            local blocksToMag = 0
            local seedsToMag  = 0

            if remBlocks > 0 or remSeeds > 0 then
                for _, tile in ipairs(world:getTiles()) do
                    local tID = tile:getTileID()
                    if tID == 5638 or tID == 20590 then
                        local magItemID    = tile:getTileData(13)
                        local currentStock = tile:getTileData(2)
                        local magCap       = (tID == 5638) and 5000 or 20000
                        local space        = magCap - currentStock

                        if space > 0 then
                            if remBlocks > 0 and magItemID == outputID then
                                local toAdd = math.min(remBlocks, space)
                                tile:setTileData(2, currentStock + toAdd)
                                blocksToMag = blocksToMag + toAdd
                                remBlocks   = remBlocks - toAdd
                                world:updateTile(tile)
                                space = magCap - (currentStock + toAdd)
                            end
                            if remSeeds > 0 and magItemID == inputID and space > 0 then
                                local toAdd = math.min(remSeeds, space)
                                tile:setTileData(2, tile:getTileData(2) + toAdd)
                                seedsToMag = seedsToMag + toAdd
                                remSeeds   = remSeeds - toAdd
                                world:updateTile(tile)
                            end
                        end
                    end
                    if remBlocks <= 0 and remSeeds <= 0 then break end
                end
            end

            if remBlocks > 0 then player:changeItem(outputID, remBlocks, 1) end
            if remSeeds  > 0 then player:changeItem(inputID,  remSeeds,  1) end

            player:addGems(totalGems, 1, 1)
            player:changeItem(0, 0, 1)

            player:onConsoleMessage("`w[Grow-o-Matic]`` Harvest complete! `w" .. m.ready_count .. " trees`` processed.")
            player:onConsoleMessage("`b- Gems Obtained: `w" .. totalGems .. "``")
            if blocksToMag > 0 or seedsToMag > 0 then
                player:onConsoleMessage("`2- Magplant (Filled): `w" .. blocksToMag .. " Blocks, " .. seedsToMag .. " Seeds``")
            end
            if remBlocks > 0 or remSeeds > 0 then
                player:onConsoleMessage("`4- Backpack (Overflow): `w" .. remBlocks .. " Blocks, " .. remSeeds .. " Seeds``")
            end

            player:sendAction("action|play_sfx\nfile|audio/harvest.wav\ndelayMS|0")

            m.ready_count = 0
            m.is_active   = false
            if (m.input_count or 0) == 0 then
                m.active_id = 0
                m.input_id  = 0
            end

            -- Turn off visual flag
            local xStr, yStr = mk:match("(%d+),(%d+)$")
            if xStr and yStr then
                local tObj = world:getTile(tonumber(xStr), tonumber(yStr))
                if tObj then
                    local flags = tObj:getFlags()
                    if bit.band(flags, 64) ~= 0 then
                        tObj:setFlags(flags - 64)
                        world:updateTile(tObj)
                    end
                end
            end

            SAVE_DIRTY = true
        else
            player:onTalkBubble(player:getNetID(), "`4Nothing to harvest. Load some seeds first!``", 0)
            player:sendAction("action|play_sfx\nfile|audio/punch_air.wav\ndelayMS|0")
        end
        return true

    -- Cancel & refund
    elseif btn == "btn_cancel" then
        if (m.input_count or 0) > 0 and m.input_id ~= 0 then
            showRefundConfirm(player, mk)
        else
            player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
        end
        return true

    -- Item picker: insert seeds
    elseif data.input_item then
        local itemID = tonumber(data.input_item)
        if not isValidInput(itemID) then
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

        local totalAdded    = 0
        local backpackAmount = player:getItemAmount(itemID)

        if backpackAmount > 0 then
            local toPull = math.min(backpackAmount, spaceLeft)
            player:changeItem(itemID, -toPull, 0)
            totalAdded  = totalAdded + toPull
            spaceLeft   = spaceLeft  - toPull
        end

        if spaceLeft > 0 then
            for _, tile in ipairs(world:getTiles()) do
                local tID = tile:getTileID()
                if tID == 5638 or tID == 20590 then
                    if tile:getTileData(13) == itemID and tile:getTileData(2) > 0 then
                        local toPull = math.min(tile:getTileData(2), spaceLeft)
                        totalAdded = totalAdded + toPull
                        tile:setTileData(2, tile:getTileData(2) - toPull)
                        world:updateTile(tile)
                        spaceLeft = spaceLeft - toPull
                    end
                end
                if spaceLeft <= 0 then break end
            end
        end

        if totalAdded > 0 then
            m.input_id    = itemID
            m.input_count = (m.input_count or 0) + totalAdded
            m.last_calc   = os.time()
            player:onConsoleMessage("`w[Grow-o-Matic]`` Added `^" .. totalAdded .. "`` seeds.")
            if not m.is_active then
                player:onConsoleMessage("`4[Grow-o-Matic]`` Machine is `4OFF``. Punch machine to start processing!")
            end
            player:changeItem(0, 0, 1)
        else
            player:onConsoleMessage("`4[Grow-o-Matic]`` No seeds found!")
        end
    end

    SAVE_DIRTY = true
    return true
end)

onPlayerDialogCallback(function(world, player, data)
    if data.dialog_name ~= "furnace_refund_confirm" then return false end
    if data.buttonClicked ~= "btn_refund_confirm" then return true end

    local mk        = ACTIVE_UI["u:" .. player:getUserID()]
    local m         = MACH[mk]
    local refundID  = m and m.input_id    or 0
    local refundAmt = m and m.input_count or 0

    if not m or refundAmt <= 0 or refundID == 0 then
        player:onConsoleMessage("`4[Grow-o-Matic]`` No active input.")
        return true
    end

    local item     = getItem(refundID)
    local itemName = item and item:getName() or "item"

    -- Kembalikan ke Backpack via cross-feature reference, fallback ke inventory
    if type(_G.BP_storeItem) == "function" then
        _G.BP_storeItem(player, refundID, refundAmt)
        player:onConsoleMessage("`w[Grow-o-Matic]`` Input cancelled. `w" .. refundAmt .. "x " .. itemName .. "`` returned to your `2Backpack``.")
    else
        player:changeItem(refundID, refundAmt, 1)
        player:onConsoleMessage("`w[Grow-o-Matic]`` Input cancelled. `w" .. refundAmt .. "x " .. itemName .. "`` returned to your inventory.")
    end

    m.input_id       = 0
    m.input_count    = 0
    m.elapsed_stored = 0
    m.last_calc      = os.time()
    m.is_active      = false

    local x, y = mk:match(":(%d+),(%d+)$")
    if x and y then
        local tObj = world:getTile(tonumber(x), tonumber(y))
        if tObj then
            local flags = tObj:getFlags()
            if bit.band(flags, 64) ~= 0 then
                tObj:setFlags(flags - 64)
                world:updateTile(tObj)
            end
        end
    end

    SAVE_DIRTY = true
    return true
end)

return M
