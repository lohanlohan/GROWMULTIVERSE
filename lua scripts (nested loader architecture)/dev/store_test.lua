-- store_test.lua — /storetest: populate featured slot 1 with test item (role 51 only)

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "storetest" then return false end
    if not player:hasRole(51) then return true end

    local SD = _G.StoreData
    if not SD then
        player:onConsoleMessage("`4StoreData not loaded.")
        return true
    end

    local cfg = SD.load()
    cfg.featured[1] = {
        type      = "item",
        id        = 1784,
        name      = "Test Item",
        price     = 10000,
        stock     = -1,
        soldCount = 0,
        endDate   = 0,
    }
    SD.save(cfg)
    player:onConsoleMessage("`2Featured slot 1 set: item 1784, price 10000 PG, unlimited stock.")
    return true
end)
