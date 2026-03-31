-- MODULE
-- surgery_callbacks.lua — Dialog callbacks and public SurgerySystem API

local M  = {}
local SD = _G.SurgeryData
local SE = _G.SurgeryEngine
local SU = _G.SurgeryUI

-- =======================================================
-- SURGEON SKILL  (per-player DB — same as operating_table)
-- =======================================================

local DB = _G.DB

local function getSurgeonSkill(player)
    local uid  = player:getUserID()
    local data = DB.getPlayer("surgeon_skill", uid) or {}
    return tonumber(data.skill) or 0
end

local function addSurgeonSkill(player, amount)
    local uid  = player:getUserID()
    local data = DB.getPlayer("surgeon_skill", uid) or {}
    data.skill = (tonumber(data.skill) or 0) + (amount or 1)
    DB.setPlayer("surgeon_skill", uid, data)
    return data.skill
end

-- =======================================================
-- HELPER: give prizes on success
-- =======================================================

local function giveSuccessPrizes(world, player, cfg)
    -- 1. Always give 1 Caduceus
    local cadId = cfg.caduceusId or SD.TOOL.CADUCEUS
    player:changeItem(cadId, 1, 0)

    -- 2. Roll one random prize from prize pool
    local prizes = cfg.prizePool or {}
    if #prizes == 0 then return end
    -- Collect prizes that win their chance roll
    local winners = {}
    for _, p in ipairs(prizes) do
        if p and tonumber(p.itemId) and tonumber(p.chance) then
            if math.random(1, 100) <= (tonumber(p.chance) or 0) then
                winners[#winners + 1] = p
            end
        end
    end
    -- Give first winner (or pick random)
    if #winners > 0 then
        local pick = winners[math.random(1, #winners)]
        player:changeItem(tonumber(pick.itemId), math.max(1, tonumber(pick.amount) or 1), 0)
    end
end

-- =======================================================
-- HELPER: end surgery (success or fail)
-- =======================================================

local function endSurgery(world, player, session, success, failReason)
    local worldName = world:getName()
    local x, y     = session.tileX, session.tileY
    local cfg       = session.cfg or {}

    local skill     = getSurgeonSkill(player)
    local newSkill  = skill
    local diagName  = (SD.DIAG[session.diagKey] or {}).name or "?"

    if success then
        newSkill = addSurgeonSkill(player, 1)
        giveSuccessPrizes(world, player, cfg)
    end

    -- Clear session FIRST — so even if onEnd crashes, next surgery can start cleanly
    SE.clearSession(worldName, x, y)

    -- Notify caller (tile swap back to empty bed)
    if type(cfg.onEnd) == "function" then
        cfg.onEnd(world, player, success)
    end

    -- Show result panel
    local resultDlg = SU.buildResultPanel(success, failReason, diagName, skill, newSkill, x, y)
    player:onDialogRequest(resultDlg, 0)
end

-- =======================================================
-- HELPER: process one tool click
-- =======================================================

local function processTool(world, player, session, toolId)
    local T  = SD.TOOL
    local st = session

    -- Special: Scalpel on non-unconscious patient → instant fail
    if toolId == T.SCALPEL and st.consciousness ~= "UNCONSCIOUS" then
        endSurgery(world, player, session, false,
            "You just stabbed someone who was fully awake! YOUR MEDICAL LICENSE IS REVOKED!")
        return
    end

    -- Consume 1 tool from inventory (returns false if player doesn't have it)
    if not player:changeItem(toolId, -1, 0) then
        player:onTalkBubble(player:getNetID(), "`4You don't have that tool.", 0)
        local skill = getSurgeonSkill(player)
        local panel = SU.buildPanel(player, session, skill)
        player:onDialogRequest(panel, 0)
        return
    end

    -- RNG: skill fail check
    local failChance = SD.skillFailChance(getSurgeonSkill(player))
    local isFail     = math.random() < failChance

    local msg
    if isFail then
        msg = SE.applySkillFailEffect(session, toolId)
    else
        msg = SE.applyToolEffect(session, toolId)
    end

    -- <<PERMA_DEATH>> = anesthetic overdose
    if msg and msg:sub(1, 14) == "<<PERMA_DEATH>>" then
        endSurgery(world, player, session, false, "You put the patient to sleep. Permanently.")
        return
    end

    -- <<RETRY>> = Fix It retryable fail
    local isRetry = false
    if msg and msg:sub(1, 9) == "<<RETRY>>" then
        isRetry = true
        msg = msg:sub(10)
    end

    -- Passive effects (happen every turn)
    SE.applyPassiveEffects(session)

    -- Update last message
    if st.consciousness == "AWAKE" and st.incisions > 0 then
        msg = (msg or "") .. " `4Patient screams and flails! More bleeding!"
    end
    if st.heartStopped and not (toolId == T.DEFIBRILLATOR) then
        msg = (msg or "") .. " `4HEART STOPPED!"
    end
    session.lastMsg = msg or ""

    -- Check fail
    local failKey, failMsg = SE.checkFail(session)
    if failKey then
        endSurgery(world, player, session, false, failMsg)
        return
    end

    -- Check win
    if SE.checkWin(session) then
        endSurgery(world, player, session, true, nil)
        return
    end

    -- Continue: show updated panel
    local skill = getSurgeonSkill(player)
    local panel = SU.buildPanel(player, session, skill)
    player:onDialogRequest(panel, 0)
end

-- =======================================================
-- DIALOG CALLBACK: surg_play_X_Y  (in-game tool use)
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local tx, ty = dlg:match("^surg_play_(-?%d+)_(-?%d+)$")
    if not tx then return false end

    local worldName = world:getName()
    local x, y     = tonumber(tx), tonumber(ty)
    local session   = SE.getSession(worldName, x, y)

    if not session then
        player:onTalkBubble(player:getNetID(), "`4Surgery session not found.", 0)
        return true
    end

    -- Only the surgeon can submit moves
    if session.surgeonName ~= player:getName() then
        player:onTalkBubble(player:getNetID(), "`4Surgery in progress by someone else.", 0)
        return true
    end

    local btn = data["buttonClicked"] or ""

    if btn == "btn_giveup" then
        local confirmDlg = SU.buildGiveUpConfirm(x, y)
        player:onDialogRequest(confirmDlg, 0)
        return true
    end

    -- Empty tray slot (btn_na_*): redisplay panel so dialog stays open
    if btn:match("^btn_na_") then
        local skill = getSurgeonSkill(player)
        local panel = SU.buildPanel(player, session, skill)
        player:onDialogRequest(panel, 0)
        return true
    end

    -- Tool button: btn_t_<toolId>
    local toolIdStr = btn:match("^btn_t_(%d+)$")
    local toolId    = tonumber(toolIdStr)
    if not toolId then return true end

    -- Validate availability (double-check server-side)
    if not SE.isToolAvailable(session, toolId) then
        player:onTalkBubble(player:getNetID(), "`4That tool can't be used right now.", 0)
        -- Redisplay panel
        local skill = getSurgeonSkill(player)
        local panel = SU.buildPanel(player, session, skill)
        player:onDialogRequest(panel, 0)
        return true
    end

    processTool(world, player, session, toolId)
    return true
end)

-- =======================================================
-- DIALOG CALLBACK: surg_giveup_X_Y  (give up confirmation)
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    local tx, ty = dlg:match("^surg_giveup_(-?%d+)_(-?%d+)$")
    if not tx then return false end

    local worldName = world:getName()
    local x, y     = tonumber(tx), tonumber(ty)
    local session   = SE.getSession(worldName, x, y)
    local btn       = data["buttonClicked"] or ""

    if not session then return true end
    if session.surgeonName ~= player:getName() then return true end

    if btn == "btn_confirm_giveup" then
        endSurgery(world, player, session, false, "You couldn't save them!")
    else
        -- "btn_cancel_giveup" → reopen surgery panel
        local skill = getSurgeonSkill(player)
        local panel = SU.buildPanel(player, session, skill)
        player:onDialogRequest(panel, 0)
    end
    return true
end)

-- =======================================================
-- DIALOG CALLBACK: surg_result_X_Y  (result screen close)
-- =======================================================

onPlayerDialogCallback(function(world, player, data)
    local dlg = data["dialog_name"] or ""
    if not dlg:match("^surg_result_%-?%d+_%-?%d+$") then return false end
    return true  -- just close
end)

-- =======================================================
-- PUBLIC API
-- =======================================================

-- SurgerySystem.start(world, player, tileX, tileY, cfg)
-- cfg = { prizePool = {}, caduceusId = 4298, onEnd = function(world, player, success) end }
function M.start(world, player, tileX, tileY, cfg)
    local worldName = world:getName()
    cfg = cfg or {}

    -- Don't start if a session already exists for this tile
    if SE.getSession(worldName, tileX, tileY) then
        player:onTalkBubble(player:getNetID(), "`4Surgery already in progress here.", 0)
        return false
    end

    -- Pick random diagnosis
    local diagKey = SD.DIAG_KEYS[math.random(1, #SD.DIAG_KEYS)]

    -- Store surgeon skill snapshot for Fix It internal use
    local skill = getSurgeonSkill(player)

    local session = SE.newSession(diagKey, player, tileX, tileY, cfg)
    if not session then
        player:onTalkBubble(player:getNetID(), "`4Failed to start surgery.", 0)
        return false
    end
    session.surgeonSkillSnapshot = skill

    SE.setSession(worldName, tileX, tileY, session)

    -- Show first panel
    local panel = SU.buildPanel(player, session, skill)
    player:onDialogRequest(panel, 0)
    return true
end

-- Allow re-opening panel for the current surgeon (called from OT wrench on insurgery tile)
function M.reopen(world, player, tileX, tileY)
    local worldName = world:getName()
    local session   = SE.getSession(worldName, tileX, tileY)
    if not session then
        player:onTalkBubble(player:getNetID(), "`4No active surgery here.", 0)
        return false
    end
    if session.surgeonName ~= player:getName() then
        player:onTalkBubble(player:getNetID(), "`4Surgery in progress by " .. session.surgeonName .. ".", 0)
        return false
    end
    local skill = getSurgeonSkill(player)
    local panel = SU.buildPanel(player, session, skill)
    player:onDialogRequest(panel, 0)
    return true
end

-- Check if a session is active at a tile
function M.hasSession(worldName, tileX, tileY)
    return SE.getSession(worldName, tileX, tileY) ~= nil
end

return M
