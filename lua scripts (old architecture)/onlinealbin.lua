--free script

local Roles = {
    PLAYER = 0,
    VIP = 1,
    SUPER_VIP = 2,
    MODERATOR = 3,
    ADMINISTRATOR = 4,
    COMMUNITY_MANAGER = 5,
    CREATOR = 6,
    GOD = 7,
    DEVELOPER = 51
}

local statsCommands = {"online", "on"}
local serverStartTime = os.time()
local cache = {}

local COUNTRY_NAME_MAP = {
{"af", "Afghanistan"}, {"al", "Albania"}, {"dz", "Algeria"}, {"as", "American Samoa"}, {"ad", "Andorra"},
{"ao", "Angola"}, {"ai", "Anguilla"}, {"aq", "Antarctica"}, {"ag", "Antigua and Barbuda"}, {"ar", "Argentina"},
{"am", "Armenia"}, {"aw", "Aruba"}, {"au", "Australia"}, {"at", "Austria"}, {"az", "Azerbaijan"},
{"bs", "Bahamas"}, {"bh", "Bahrain"}, {"bd", "Bangladesh"}, {"bb", "Barbados"}, {"by", "Belarus"},
{"be", "Belgium"}, {"bz", "Belize"}, {"bj", "Benin"}, {"bm", "Bermuda"}, {"bt", "Bhutan"},
{"bo", "Bolivia"}, {"ba", "Bosnia and Herzegovina"}, {"bw", "Botswana"}, {"br", "Brazil"}, {"bn", "Brunei"},
{"bg", "Bulgaria"}, {"bf", "Burkina Faso"}, {"bi", "Burundi"}, {"cv", "Cabo Verde"}, {"kh", "Cambodia"},
{"cm", "Cameroon"}, {"ca", "Canada"}, {"ky", "Cayman Islands"}, {"cf", "Central African Republic"}, {"td", "Chad"},
{"cl", "Chile"}, {"cn", "China"}, {"co", "Colombia"}, {"km", "Comoros"}, {"cg", "Congo"},
{"cd", "Congo, Democratic Republic of the"}, {"ck", "Cook Islands"}, {"cr", "Costa Rica"}, {"ci", "Côte d'Ivoire"}, {"hr", "Croatia"},
{"cu", "Cuba"}, {"cy", "Cyprus"}, {"cz", "Czech Republic"}, {"dk", "Denmark"}, {"dj", "Djibouti"},
{"dm", "Dominica"}, {"do", "Dominican Republic"}, {"ec", "Ecuador"}, {"eg", "Egypt"}, {"sv", "El Salvador"},
{"gq", "Equatorial Guinea"}, {"er", "Eritrea"}, {"ee", "Estonia"}, {"sz", "Eswatini"}, {"et", "Ethiopia"},
{"fj", "Fiji"}, {"fi", "Finland"}, {"fr", "France"}, {"ga", "Gabon"}, {"gm", "Gambia"},
{"ge", "Georgia"}, {"de", "Germany"}, {"gh", "Ghana"}, {"gi", "Gibraltar"}, {"gr", "Greece"},
{"gl", "Greenland"}, {"gd", "Grenada"}, {"gu", "Guam"}, {"gt", "Guatemala"}, {"gn", "Guinea"},
{"gw", "Guinea-Bissau"}, {"gy", "Guyana"}, {"ht", "Haiti"}, {"hn", "Honduras"}, {"hk", "Hong Kong"},
{"hu", "Hungary"}, {"is", "Iceland"}, {"in", "India"}, {"id", "Indonesia"}, {"ir", "Iran"},
{"iq", "Iraq"}, {"ie", "Ireland"}, {"il", "Israel"}, {"it", "Italy"}, {"jm", "Jamaica"},
{"jp", "Japan"}, {"jo", "Jordan"}, {"kz", "Kazakhstan"}, {"ke", "Kenya"}, {"ki", "Kiribati"},
{"kp", "Korea, Democratic People's Republic of"}, {"kr", "Korea, Republic of"}, {"kw", "Kuwait"}, {"kg", "Kyrgyzstan"}, {"la", "Lao People's Democratic Republic"},
{"lv", "Latvia"}, {"lb", "Lebanon"}, {"ls", "Lesotho"}, {"lr", "Liberia"}, {"ly", "Libya"},
{"li", "Liechtenstein"}, {"lt", "Lithuania"}, {"lu", "Luxembourg"}, {"mo", "Macao"}, {"mg", "Madagascar"},
{"mw", "Malawi"}, {"my", "Malaysia"}, {"mv", "Maldives"}, {"ml", "Mali"}, {"mt", "Malta"},
{"mh", "Marshall Islands"}, {"mr", "Mauritania"}, {"mu", "Mauritius"}, {"mx", "Mexico"}, {"fm", "Micronesia"},
{"md", "Moldova"}, {"mc", "Monaco"}, {"mn", "Mongolia"}, {"me", "Montenegro"}, {"ma", "Morocco"},
{"mz", "Mozambique"}, {"mm", "Myanmar"}, {"na", "Namibia"}, {"nr", "Nauru"}, {"np", "Nepal"},
{"nl", "Netherlands"}, {"nz", "New Zealand"}, {"ni", "Nicaragua"}, {"ne", "Niger"}, {"ng", "Nigeria"},
{"mk", "North Macedonia"}, {"no", "Norway"}, {"om", "Oman"}, {"pk", "Pakistan"}, {"pw", "Palau"},
{"ps", "Palestine"}, {"pa", "Panama"}, {"pg", "Papua New Guinea"}, {"py", "Paraguay"}, {"pe", "Peru"},
{"ph", "Philippines"}, {"pl", "Poland"}, {"pt", "Portugal"}, {"qa", "Qatar"}, {"ro", "Romania"},
{"ru", "Russian Federation"}, {"rw", "Rwanda"}, {"kn", "Saint Kitts and Nevis"}, {"lc", "Saint Lucia"}, {"vc", "Saint Vincent and the Grenadines"},
{"ws", "Samoa"}, {"sm", "San Marino"}, {"st", "Sao Tome and Principe"}, {"sa", "Saudi Arabia"}, {"sn", "Senegal"},
{"rs", "Serbia"}, {"sc", "Seychelles"}, {"sl", "Sierra Leone"}, {"sg", "Singapore"}, {"sk", "Slovakia"},
{"si", "Slovenia"}, {"sb", "Solomon Islands"}, {"so", "Somalia"}, {"za", "South Africa"}, {"ss", "South Sudan"},
{"es", "Spain"}, {"lk", "Sri Lanka"}, {"sd", "Sudan"}, {"sr", "Suriname"}, {"se", "Sweden"},
{"ch", "Switzerland"}, {"sy", "Syrian Arab Republic"}, {"tw", "Taiwan"}, {"tj", "Tajikistan"}, {"tz", "Tanzania"},
{"th", "Thailand"}, {"tl", "Timor-Leste"}, {"tg", "Togo"}, {"to", "Tonga"}, {"tt", "Trinidad and Tobago"},
{"tn", "Tunisia"}, {"tr", "Turkey"}, {"tm", "Turkmenistan"}, {"tv", "Tuvalu"}, {"ug", "Uganda"},
{"ua", "Ukraine"}, {"ae", "United Arab Emirates"}, {"gb", "United Kingdom"}, {"us", "United States of America"}, {"uy", "Uruguay"},
{"uz", "Uzbekistan"}, {"vu", "Vanuatu"}, {"ve", "Venezuela"}, {"vn", "Viet Nam"}, {"ye", "Yemen"},
{"zm", "Zambia"}, {"zw", "Zimbabwe"}
}

local COUNTRY_MAP = {}
for _, v in ipairs(COUNTRY_NAME_MAP) do COUNTRY_MAP[v[1]:lower()] = v[2] end

local DEVICE_ORDER = { "Android", "IOS", "PC", "MacBook", "Linux", "Other Device" }

local function updateStatsCache()
    local onlinePlayers = getServerPlayers()
    local newCache = {
        onlineCount = #onlinePlayers,
        serverName = tostring(getServerName() or "Unknown Server"),
        uptime = os.time() - serverStartTime,
        devices = {
            ["Android"] = 0,
            ["IOS"] = 0,
            ["PC"] = 0,
            ["MacBook"] = 0,
            ["Linux"] = 0,
            ["Other Device"] = 0
        },
        countries = {},
        worlds = {},
        playerListStr = ""
    }

    local playerList = {}
    local worldCounts = {}

    for _, p in ipairs(onlinePlayers) do
        local platform = tostring(p:getPlatform() or "")
        local device = "Other Device"

        if platform == "4" then
            device = "Android"
        elseif platform == "1" then
            device = "IOS"
        elseif platform == "0,1,1" or platform:match("^0,") then
            device = "PC"
        elseif platform == "2" then
            device = "MacBook"
        elseif platform == "3" then
            device = "Linux"
        end

        newCache.devices[device] = (newCache.devices[device] or 0) + 1

        local ping = math.random(30, 350)
        local pingColor = "`2"
        if ping >= 81 and ping <= 120 then pingColor = "`8" end
        if ping > 120 then pingColor = "`4" end

        local country = tostring(p:getCountry() or ""):lower()
        if country and country ~= "" then
            newCache.countries[country] = (newCache.countries[country] or 0) + 1
        end

        local worldName = p:getWorldName() or "EXIT"
        worldCounts[worldName] = (worldCounts[worldName] or 0) + 1

        table.insert(playerList, string.format("`w%s [%s%dms``]", p:getName(), pingColor, ping))
    end

    local sortedWorlds = {}
    for name, count in pairs(worldCounts) do
        table.insert(sortedWorlds, { name = name, count = count })
    end
    table.sort(sortedWorlds, function(a, b) return a.count > b.count end)

    newCache.worlds = sortedWorlds
    newCache.playerListStr = table.concat(playerList, ", ")
    cache = newCache
end

local function showServerStatsDialog(player)
    updateStatsCache()
    local dialog = "set_default_color|\n"
    dialog = dialog .. "add_label_with_icon|big|`oServer Statistics|left|3802|\n"
    dialog = dialog .. "add_label_with_icon|medium|`oInfo|left|7190|\n"
    dialog = dialog .. "add_textbox|`oServer: `2Lobby `4PS|left|\n" --ganti nama server kamuuuuu
    dialog = dialog .. "add_textbox|`oOnline: `2" .. cache.onlineCount .. "`o/`43,000`o|\n"
    dialog = dialog .. "add_textbox|`o────────────────────────────|\n"
    dialog = dialog .. "add_label_with_icon|medium|`oPlayer Devices|left|572|\n"

    for _, deviceName in ipairs(DEVICE_ORDER) do
        local v = cache.devices[deviceName] or 0
        dialog = dialog .. "add_textbox|`o" .. deviceName .. " Users: `2" .. v .. "|\n"
    end

    dialog = dialog .. "add_textbox|`o────────────────────────────|\n"

    local countryPairs = {}
    for code, count in pairs(cache.countries) do
        table.insert(countryPairs, { code = code, count = count })
    end
    table.sort(countryPairs, function(a, b) return a.count > b.count end)

    if #countryPairs > 0 then
        dialog = dialog .. "add_label_with_icon|small|`oPlayer Country|left|3394|\n"
        local maxDisplay = 20
        local displayed = 0
        for _, entry in ipairs(countryPairs) do
            if displayed >= maxDisplay then break end
            local code = (entry.code or ""):lower()
            local name = COUNTRY_MAP[code] or code:upper()
            local count = entry.count or 0
            dialog = dialog .. "add_custom_button||image:interface/flags/" .. code .. ".rttex;image_size:16,12;width:0.03;state:visibled;|left|\n"
            dialog = dialog .. "add_textbox|`w" .. name .. " - `2" .. tostring(count) .. " `$User Online|left|\n"
            dialog = dialog .. "reset_placement_x|\n"
            displayed = displayed + 1
        end
        if #countryPairs > maxDisplay then
            dialog = dialog .. "add_textbox|`oAnd more... (" .. tostring(#countryPairs - maxDisplay) .. ")|\n"
        end
        dialog = dialog .. "add_textbox|`o────────────────────────────|\n"
    end

    dialog = dialog .. "add_label_with_icon|small|`oPlayers Username|left|1280|\n"
    dialog = dialog .. "add_custom_break|\n"
    dialog = dialog .. "add_label|small|" .. cache.playerListStr .. "|\n"
    dialog = dialog .. "add_quick_exit|\n"
    dialog = dialog .. "end_dialog|ons_stats|||\n"
    player:onDialogRequest(dialog)
end

-- Define the command
local OnlineCommandData = {
    command = "online",
    roleRequired = Roles.DEVELOPER,
    description = "detail info online in server"
}

-- Register the command
registerLuaCommand(OnlineCommandData)

onPlayerCommandCallback(function(world, player, fullCommand)
    local command = fullCommand:match("^(%S+)")
    if command then
        command = command:lower()
        for _, cmd in ipairs(statsCommands) do
            if command == OnlineCommandData.command then
            if not player:hasRole(OnlineCommandData.roleRequired) then
                player:onConsoleMessage("`4You Dont Have permission to use this command")
                return true
            end
                showServerStatsDialog(player)
                return true
            end
        end
    end
    return false
end)