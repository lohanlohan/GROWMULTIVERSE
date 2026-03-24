ITEM_BALLOON = 338
players = {}

function createPlayer(id)
    players[id] = {
        gravity = 1.0,
        jump = 1.0,
        mods = {
            lowGravity = false,
            highJump = false
        }
    }
end
function onEquipItem(playerID, itemID)
    local player = players[playerID]
    if not player then return end

    if itemID == ITEM_BALLOON then
        player.mods.lowGravity = true
        player.mods.highJump = true

        sendMessage(playerID, "You feel lighter with the balloon!")
    end
end
function onUnequipItem(playerID, itemID)
    local player = players[playerID]
    if not player then return end

    if itemID == ITEM_BALLOON then
        player.mods.lowGravity = false
        player.mods.highJump = false

        sendMessage(playerID, "The balloon effect disappeared.")
    end
end
function applyPhysics(playerID)
    local player = players[playerID]
    if not player then return end

    local gravity = 1.0
    local jump = 1.0

    if player.mods.lowGravity then
        gravity = gravity * 0.4
    end

    if player.mods.highJump then
        jump = jump * 1.5
    end

    player.gravity = gravity
    player.jump = jump
end