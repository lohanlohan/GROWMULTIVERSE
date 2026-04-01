-- MODULE
-- surgery_test.lua — /surgery dev command: pick any diagnosis for instant testing (role 51 only)

local M  = {}
local SD = _G.SurgeryData
local SE = _G.SurgeryEngine
local SU = _G.SurgeryUI
local DB = _G.DB

local ROLE       = 51
local DEV_TILE_Y = -1   -- virtual tile Y for dev test sessions

-- Virtual tile X = negative UID so each developer has their own isolated session slot
local function devTileX(player)
    return -(player:getUserID())
end

local function getSurgeonSkill(player)
    local data = DB.getPlayer("surgeon_skill", player:getUserID()) or {}
    return tonumber(data.skill) or 0
end

-- =======================================================
-- PANEL BUILDER
-- =======================================================

local function buildSelectPanel()
    local d = ""
    d = d .. "set_default_color|`o\n"
    d = d .. "add_label_with_icon|big|`wSurgery Test|left|25028|\n"
    d = d .. "add_textbox|`7Pick a diagnosis to open its surgery panel instantly.|\n"
    d = d .. "add_spacer|small|\n"

    local function addGroup(label, keys)
        d = d .. "add_smalltext|`w" .. label .. "|left|\n"
        for _, key in ipairs(keys) do
            local name = (SD.DIAG[key] or {}).name or key
            d = d .. "add_button|test_" .. key .. "|`o" .. name .. " `7(" .. key .. ")|noflags|0|0|\n"
        end
        d = d .. "add_spacer|small|\n"
    end

    addGroup("Standard (" .. #SD.DIAG_KEYS_STANDARD .. ")", SD.DIAG_KEYS_STANDARD)
    addGroup("Malady ("   .. #SD.DIAG_KEYS_MALADY    .. ")", SD.DIAG_KEYS_MALADY)
    addGroup("Vile Vial (" .. #SD.DIAG_KEYS_VILE_VIAL .. ")", SD.DIAG_KEYS_VILE_VIAL)

    d = d .. "add_button|btn_close|`7Close|noflags|0|0|\n"
    d = d .. "end_dialog|surg_test|||\n"
    return d
end

-- =======================================================
-- COMMANDS
-- =======================================================

registerLuaCommand({
    command      = "surgery",
    roleRequired = ROLE,
    description  = "Dev: open surgery test panel to test any diagnosis.",
})

registerLuaCommand({
    command      = "surgeonskill",
    roleRequired = ROLE,
    description  = "Dev: set surgeon skill for a player. Usage: /surgeonskill <GrowID> <amount>",
})

onPlayerCommandCallback(function(world, player, full)
    local parts = {}
    for w in full:gmatch("%S+") do parts[#parts + 1] = w end
    local cmd = (parts[1] or ""):lower()

    -- /surgery
    if cmd == "surgery" then
        if not player:hasRole(ROLE) then
            player:onConsoleMessage("`4Access denied.")
            return true
        end
        player:onDialogRequest(buildSelectPanel(), 0)
        return true
    end

    -- /surgeonskill <GrowID> <amount>
    if cmd == "surgeonskill" then
        if not player:hasRole(ROLE) then
            player:onConsoleMessage("`4Access denied.")
            return true
        end

        local targetName = parts[2]
        local amount     = tonumber(parts[3])

        if not targetName or not amount then
            player:onConsoleMessage("`7Usage: /surgeonskill `w<GrowID> <amount>")
            return true
        end

        amount = math.min(100, math.max(0, math.floor(amount)))

        -- getPlayerByName returns a table of matching players (Nperma API)
        local found = getPlayerByName(targetName)
        local target = found and found[1] or nil
        if not target then
            player:onConsoleMessage("`4Player '`w" .. targetName .. "`4' not found or is offline.")
            return true
        end

        local uid     = target:getUserID()
        local dbData  = DB.getPlayer("surgeon_skill", uid) or {}
        local oldSkill = tonumber(dbData.skill) or 0
        dbData.skill  = amount
        DB.setPlayer("surgeon_skill", uid, dbData)

        player:onConsoleMessage(
            "`2Surgeon skill for `w" .. target:getName() ..
            "`2 set: `7" .. oldSkill .. " `w→ `2" .. amount
        )
        target:onConsoleMessage("`7Your surgeon skill was set to `w" .. amount .. "`7 by an admin.")
        return true
    end

    return false
end)

-- =======================================================
-- DIALOG CALLBACK: surg_test  (diagnosis selection)
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    if (data["dialog_name"] or "") ~= "surg_test" then return false end
    if not player:hasRole(ROLE) then return true end

    local btn = data["buttonClicked"] or ""
    if btn == "btn_close" then return true end

    local diagKey = btn:match("^test_(.+)$")
    if not diagKey or not SD.DIAG[diagKey] then return true end

    local worldName = world:getName()
    local tx        = devTileX(player)
    local ty        = DEV_TILE_Y

    -- Clear any leftover dev session for this player before starting a new one
    SE.clearSession(worldName, tx, ty)

    local session = SE.newSession(diagKey, player, tx, ty, {})
    if not session then
        player:onConsoleMessage("`4Failed to create test session for " .. diagKey .. ".")
        return true
    end
    SE.setSession(worldName, tx, ty, session)

    player:onConsoleMessage("`7[dev] Started test session: `w" .. diagKey)
    local panel = SU.buildPanel(player, session, getSurgeonSkill(player))
    player:onDialogRequest(panel, 0)
    return true
end)

return M
