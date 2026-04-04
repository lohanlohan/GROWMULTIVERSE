-- MODULE
-- surgprize.lua — /surgprize: manage per-disease surgery prize pools (panel UI)

local M = {}
local DB   = _G.DB
local SD   = _G.SurgeryData
local ROLE = 51

local DB_KEY    = "surg_prize"
local MAX_SLOTS = 5   -- prize slots per diagnosis

-- =======================================================
-- HELPERS
-- =======================================================

local function load() return DB.loadFeature(DB_KEY) or {} end
local function save(t) DB.saveFeature(DB_KEY, t) end

local function getSlots(data, key)
    if not data[key] then data[key] = { prizes = {} } end
    local prizes = data[key].prizes
    -- Pad to MAX_SLOTS
    for i = #prizes + 1, MAX_SLOTS do
        prizes[i] = { itemId = 0, amount = 1, chance = 0 }
    end
    return prizes
end

-- =======================================================
-- PANEL BUILDERS
-- =======================================================

local function openMainPanel(player)
    local data = load()
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wSurgery Prizes|left|25028|\n"
    d = d .. "add_textbox|Select a diagnosis to configure its prize pool:|\n"
    d = d .. "add_spacer|small|\n"

    for _, key in ipairs(SD.DIAG_KEYS) do
        local diagName  = (SD.DIAG[key] or {}).name or key
        local prizes    = (data[key] and data[key].prizes) or {}
        local active    = 0
        for _, p in ipairs(prizes) do
            if (tonumber(p.chance) or 0) > 0 and (tonumber(p.itemId) or 0) > 0 then
                active = active + 1
            end
        end
        local countStr = active > 0 and ("`2" .. active .. " prize(s)") or "`7empty"
        local btnID    = "diag_" .. key
        d = d .. "add_button|" .. btnID .. "|`o" .. diagName .. " `7(" .. key .. ") — " .. countStr .. "|noflags|0|0|\n"
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_close|`7Close|noflags|0|0|\n"
    d = d .. "end_dialog|surg_prize_main|||\n"
    player:onDialogRequest(d)
end

local function openEditPanel(player, diagKey, delay)
    local diagName = (SD.DIAG[diagKey] or {}).name or diagKey
    local data     = load()
    local slots    = getSlots(data, diagKey)

    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`w" .. diagName .. "|left|25028|\n"
    d = d .. "add_textbox|`7Set item, amount, and chance (0-100) for each slot. Chance 0 = disabled.|\n"
    d = d .. "embed_data|diag|" .. diagKey .. "|\n"

    for i = 1, MAX_SLOTS do
        local p    = slots[i] or { itemId = 0, amount = 1, chance = 0 }
        local item = (tonumber(p.itemId) or 0) > 0 and getItem(tonumber(p.itemId)) or nil
        local name = item and item:getName() or "Empty"
        d = d .. "add_spacer|small|\n"
        d = d .. "add_smalltext|`wSlot " .. i .. "|\n"
        d = d .. "add_item_picker|slot_item_" .. i .. "|`w" .. name .. "`7:|Select Prize Item|\n"
        d = d .. "add_text_input|slot_amt_" .. i .. "|Amount:|" .. (p.amount or 1) .. "|6|\n"
        d = d .. "add_text_input|slot_chance_" .. i .. "|Chance (%):|" .. (p.chance or 0) .. "|4|\n"
    end

    d = d .. "add_spacer|small|\n"
    d = d .. "add_button|btn_save|`2Save Prizes|noflags|0|0|\n"
    d = d .. "add_button|btn_back|`oBack|noflags|0|0|\n"
    d = d .. "end_dialog|surg_prize_edit|||\n"
    player:onDialogRequest(d, delay or 0)
end

-- =======================================================
-- COMMAND
-- =======================================================

registerLuaCommand({
    command      = "surgprize",
    roleRequired = ROLE,
    description  = "Manage surgery prize pools per diagnosis.",
})

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "surgprize" then return false end
    if not player:hasRole(ROLE) then
        player:onConsoleMessage("`4Access denied!")
        return true
    end
    openMainPanel(player)
    return true
end)

-- =======================================================
-- DIALOG CALLBACKS
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dname = data["dialog_name"] or ""

    -- Main panel
    if dname == "surg_prize_main" then
        if not player:hasRole(ROLE) then return true end
        local btn = data["buttonClicked"] or ""
        if btn == "btn_close" then return true end
        for _, key in ipairs(SD.DIAG_KEYS) do
            if btn == "diag_" .. key then
                openEditPanel(player, key)
                return true
            end
        end
        return true
    end

    -- Edit panel
    if dname == "surg_prize_edit" then
        if not player:hasRole(ROLE) then return true end
        local btn      = data["buttonClicked"] or ""
        local diagKey  = data["diag"] or ""

        if btn == "btn_back" then
            openMainPanel(player)
            return true
        end

        if diagKey == "" then return true end

        -- Read current data, preserve existing slots for items not changed
        local dbData = load()
        local slots  = getSlots(dbData, diagKey)

        for i = 1, MAX_SLOTS do
            local itemId = tonumber(data["slot_item_"   .. i])
            local amount = tonumber(data["slot_amt_"    .. i])
            local chance = tonumber(data["slot_chance_" .. i])

            -- item picker returns 0 if unchanged — keep existing
            if itemId and itemId > 0 then
                slots[i].itemId = itemId
            end
            if amount and amount > 0 then
                slots[i].amount = math.max(1, amount)
            end
            if chance then
                slots[i].chance = math.min(100, math.max(0, chance))
            end
        end

        dbData[diagKey].prizes = slots

        if btn == "btn_save" then
            save(dbData)
            local diagName = (SD.DIAG[diagKey] or {}).name or diagKey
            player:onConsoleMessage("`2Prizes for `w" .. diagName .. "`2 saved!")
        end

        -- Reopen edit panel with updated data
        openEditPanel(player, diagKey, 300)
        return true
    end

    return false
end)

return M
