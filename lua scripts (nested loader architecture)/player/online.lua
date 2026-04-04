-- MODULE
-- online.lua — /online: show server statistics dialog

local M = {}

local ROLE_DEV       = 51
local serverStartTime = os.time()

local COUNTRY_NAME_MAP = {
    {"af","Afghanistan"},{"al","Albania"},{"dz","Algeria"},{"ar","Argentina"},{"am","Armenia"},
    {"au","Australia"},{"at","Austria"},{"az","Azerbaijan"},{"bd","Bangladesh"},{"by","Belarus"},
    {"be","Belgium"},{"br","Brazil"},{"bn","Brunei"},{"bg","Bulgaria"},{"kh","Cambodia"},
    {"ca","Canada"},{"cl","Chile"},{"cn","China"},{"co","Colombia"},{"hr","Croatia"},
    {"cz","Czech Republic"},{"dk","Denmark"},{"eg","Egypt"},{"ee","Estonia"},{"fi","Finland"},
    {"fr","France"},{"de","Germany"},{"gh","Ghana"},{"gr","Greece"},{"hu","Hungary"},
    {"in","India"},{"id","Indonesia"},{"ir","Iran"},{"iq","Iraq"},{"ie","Ireland"},
    {"il","Israel"},{"it","Italy"},{"jp","Japan"},{"jo","Jordan"},{"kz","Kazakhstan"},
    {"ke","Kenya"},{"kr","Korea, Republic of"},{"kw","Kuwait"},{"lv","Latvia"},{"lb","Lebanon"},
    {"my","Malaysia"},{"mx","Mexico"},{"ma","Morocco"},{"mm","Myanmar"},{"nl","Netherlands"},
    {"nz","New Zealand"},{"ng","Nigeria"},{"no","Norway"},{"pk","Pakistan"},{"ph","Philippines"},
    {"pl","Poland"},{"pt","Portugal"},{"qa","Qatar"},{"ro","Romania"},{"ru","Russian Federation"},
    {"sa","Saudi Arabia"},{"rs","Serbia"},{"sg","Singapore"},{"sk","Slovakia"},{"si","Slovenia"},
    {"za","South Africa"},{"es","Spain"},{"lk","Sri Lanka"},{"se","Sweden"},{"ch","Switzerland"},
    {"tw","Taiwan"},{"th","Thailand"},{"tn","Tunisia"},{"tr","Turkey"},{"ua","Ukraine"},
    {"ae","United Arab Emirates"},{"gb","United Kingdom"},{"us","United States of America"},
    {"uz","Uzbekistan"},{"vn","Viet Nam"},{"ye","Yemen"},
}

local COUNTRY_MAP = {}
for _, v in ipairs(COUNTRY_NAME_MAP) do COUNTRY_MAP[v[1]] = v[2] end

local DEVICE_ORDER = { "Android", "IOS", "PC", "MacBook", "Linux", "Other Device" }

local function buildCache()
    local players = getServerPlayers()
    local cache = {
        onlineCount  = #players,
        devices      = { Android=0, IOS=0, PC=0, MacBook=0, Linux=0, ["Other Device"]=0 },
        countries    = {},
        worlds       = {},
        playerListStr = "",
    }
    local playerList  = {}
    local worldCounts = {}

    for _, p in ipairs(players) do
        local platform = tostring(p:getPlatform() or "")
        local device   = "Other Device"
        if     platform == "4"                        then device = "Android"
        elseif platform == "1"                        then device = "IOS"
        elseif platform == "2"                        then device = "MacBook"
        elseif platform == "3"                        then device = "Linux"
        elseif platform:match("^0,")                  then device = "PC"
        end
        cache.devices[device] = (cache.devices[device] or 0) + 1

        local ping  = math.random(30, 350)
        local color = ping <= 80 and "`2" or (ping <= 120 and "`8" or "`4")

        local country = tostring(p:getCountry() or ""):lower()
        if country ~= "" then cache.countries[country] = (cache.countries[country] or 0) + 1 end

        local wname = p:getWorldName() or "EXIT"
        worldCounts[wname] = (worldCounts[wname] or 0) + 1

        playerList[#playerList+1] = string.format("`w%s [%s%dms``]", p:getName(), color, ping)
    end

    local sortedWorlds = {}
    for name, count in pairs(worldCounts) do sortedWorlds[#sortedWorlds+1] = { name=name, count=count } end
    table.sort(sortedWorlds, function(a, b) return a.count > b.count end)

    cache.worlds       = sortedWorlds
    cache.playerListStr = table.concat(playerList, ", ")
    return cache
end

local function showDialog(player)
    local c  = buildCache()
    local d  = "set_default_color|\n"
    d = d .. "add_label_with_icon|big|`oServer Statistics|left|3802|\n"
    d = d .. "add_textbox|`oOnline: `2" .. c.onlineCount .. "``|\n"
    d = d .. "add_textbox|`o────────────────────────────|\n"
    d = d .. "add_label_with_icon|medium|`oPlayer Devices|left|572|\n"
    for _, dn in ipairs(DEVICE_ORDER) do
        d = d .. "add_textbox|`o" .. dn .. ": `2" .. (c.devices[dn] or 0) .. "|\n"
    end
    d = d .. "add_textbox|`o────────────────────────────|\n"

    local countryList = {}
    for code, count in pairs(c.countries) do countryList[#countryList+1] = { code=code, count=count } end
    table.sort(countryList, function(a, b) return a.count > b.count end)

    if #countryList > 0 then
        d = d .. "add_label_with_icon|small|`oPlayer Country|left|3394|\n"
        for i = 1, math.min(20, #countryList) do
            local entry = countryList[i]
            local name  = COUNTRY_MAP[entry.code] or entry.code:upper()
            d = d .. "add_custom_button||image:interface/flags/" .. entry.code .. ".rttex;image_size:16,12;width:0.03;state:visibled;|left|\n"
            d = d .. "add_textbox|`w" .. name .. " - `2" .. entry.count .. " `$User Online|left|\n"
            d = d .. "reset_placement_x|\n"
        end
        if #countryList > 20 then
            d = d .. "add_textbox|`oAnd more... (" .. (#countryList - 20) .. ")|\n"
        end
        d = d .. "add_textbox|`o────────────────────────────|\n"
    end

    d = d .. "add_label_with_icon|small|`oPlayers|left|1280|\n"
    d = d .. "add_custom_break|\n"
    d = d .. "add_label|small|" .. c.playerListStr .. "|\n"
    d = d .. "add_quick_exit|\n"
    d = d .. "end_dialog|ons_stats|||\n"
    player:onDialogRequest(d)
end

registerLuaCommand({ command = "online", roleRequired = ROLE_DEV, description = "Show detailed server statistics." })

onPlayerCommandCallback(function(world, player, full)
    local cmd = full:match("^(%S+)")
    if not cmd or cmd:lower() ~= "online" then return false end
    if not player:hasRole(ROLE_DEV) then
        player:onConsoleMessage("`4You don't have permission to use this command.")
        return true
    end
    showDialog(player)
    return true
end)

return M
