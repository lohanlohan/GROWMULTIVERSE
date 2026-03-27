-- MODULE
-- item_categorizer.lua — Kategorisasi item berdasarkan actionType & clothingType
-- Dipakai oleh item_browser dan backpack (cross-feature via _G.ItemCategorizer)

local M = {}

local function reg(cat, ids)
    for _, id in ipairs(ids) do
        M.MANUAL[id] = cat
    end
end

M.LIST = {
    "Gacha",  "Locks",  "Block",  "Machine", "Background", "Seeds",
    "Consumables", "Hat", "Hair", "Face",    "Chest",      "Shirt",
    "Pants",  "Shoes",  "Hand",   "Wing",    "Artifact",   "Pets",
}

M.DISPLAY = {
    Gacha      = "Gacha",       Locks      = "Locks",
    Block      = "Block",       Machine    = "Machine",
    Background = "Background",  Seeds      = "Seeds",
    Consumables= "Consumables", Hat        = "Hat",
    Hair       = "Hair",        Face       = "Face",
    Chest      = "Chest",       Shirt      = "Shirt",
    Pants      = "Pants",       Shoes      = "Shoes",
    Hand       = "Hand",        Wing       = "Wing",
    Artifact   = "Artifact",    Pets       = "Pets",
}

M.ICON = {
    Gacha      = 9752,  Locks      = 32,    Block      = 2,
    Machine    = 4994,  Background = 14,    Seeds      = 3,
    Consumables= 504,   Hat        = 26,    Hair       = 1506,
    Face       = 202,   Chest      = 5894,  Shirt      = 24,
    Pants      = 28,    Shoes      = 22,    Hand       = 30,
    Wing       = 3020,  Artifact   = 7652,  Pets       = 4690,
}

M.MANUAL = {}

reg("Gacha",       {})
reg("Locks",       {})
reg("Machine",     {})
reg("Pets",        {})
reg("Wing",        {})
reg("Hat",         {})
reg("Hair",        {})
reg("Face",        {})
reg("Chest",       {})
reg("Shirt",       {})
reg("Pants",       {})
reg("Shoes",       {})
reg("Hand",        {})
reg("Artifact",    {})
reg("Consumables", {})
reg("Seeds",       {})
reg("Background",  {})
reg("Block",       {})

function M.getCategory(itemID)
    if M.MANUAL[itemID] then return M.MANUAL[itemID] end

    local item = getItem(itemID)
    if not item then return "Block" end

    local atype = item:getActionType()
    local ct    = item:getClothingType()

    if atype == 1  then return "Seeds"      end
    if atype == 3  then return "Background" end
    if atype == 8  then return "Consumables" end
    if atype == 18 then return "Locks"      end
    if atype == 28 or atype == 40 then return "Machine" end

    if ct and ct > 0 then
        if     ct == 1 then return "Shirt"
        elseif ct == 2 then return "Pants"
        elseif ct == 3 then return "Shoes"
        elseif ct == 4 then return "Face"
        elseif ct == 5 then return "Hand"
        elseif ct == 6 then return "Wing"
        elseif ct == 7 then return "Hair"
        elseif ct == 8 then return "Chest"
        elseif ct == 9 then return "Artifact"
        end
    end

    if ct == 0 and atype == 0 then return "Hat" end

    return "Block"
end

function M.groupByCategory(storedItems)
    local groups = {}
    for _, cat in ipairs(M.LIST) do groups[cat] = {} end
    for itemID, count in pairs(storedItems) do
        local cat = M.getCategory(itemID)
        if groups[cat] then
            table.insert(groups[cat], { id = itemID, count = count })
        end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return a.id < b.id end)
    end
    return groups
end

_G.ItemCategorizer = M
return M
