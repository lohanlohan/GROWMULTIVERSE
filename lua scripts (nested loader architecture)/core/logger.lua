-- MODULE
-- logger.lua — Error tracking for loader failures. Sets _G.Logger.

local M = {}

local MAX_ENTRIES = 50
local buffer      = {}  -- { time, source, message }

local function push(source, message)
    if #buffer >= MAX_ENTRIES then
        table.remove(buffer, 1)
    end
    table.insert(buffer, {
        time    = os.time(),
        source  = tostring(source),
        message = tostring(message),
    })
end

function M.error(source, message)
    push(source, message)
    print("[ERROR][" .. tostring(source) .. "] " .. tostring(message))
end

function M.getAll()
    return buffer
end

function M.clear()
    buffer = {}
end

-- ============================================================================
-- COMMAND: /errorlog [clear]
-- ============================================================================

onPlayerCommandCallback(function(world, player, fullCommand)
    if not fullCommand then return false end
    local parts = {}
    for w in fullCommand:gmatch("%S+") do table.insert(parts, w) end
    local cmd = (parts[1] or ""):lower()

    if cmd ~= "errorlog" then return false end

    if not player:hasRole(51) then
        player:onConsoleMessage("`4Unknown command.")
        return true
    end

    if parts[2] and parts[2]:lower() == "clear" then
        M.clear()
        player:onConsoleMessage("`2Error log cleared.")
        return true
    end

    if #buffer == 0 then
        player:onConsoleMessage("`2No loader errors recorded.")
        return true
    end

    player:onConsoleMessage("`#=== Error Log (" .. #buffer .. "/" .. MAX_ENTRIES .. ") ===``")
    for i = #buffer, math.max(1, #buffer - 19), -1 do
        local entry = buffer[i]
        local t     = os.date("%H:%M:%S", entry.time)
        player:onConsoleMessage("`4[" .. t .. "] `o[" .. entry.source .. "] `w" .. entry.message)
    end

    return true
end)

_G.Logger = M
return M
