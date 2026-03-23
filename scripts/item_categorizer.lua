-- MODULE

local ItemCategorizer = {}

-- Helper: daftarkan banyak ID ke satu kategori sekaligus
-- Contoh: reg("Gacha", {9752, 9753, 9754})
local function reg(cat, ids)
    for _, id in ipairs(ids) do
        ItemCategorizer.MANUAL[id] = cat
    end
end

-- ============================================================================
-- CATEGORY LIST (urutan tampil di main panel, 6 per baris)
-- ============================================================================
ItemCategorizer.LIST = {
    "Gacha",  "Locks",  "Block",  "Machine", "Background", "Seeds",
    "Consumables", "Hat", "Hair", "Face",    "Chest",      "Shirt",
    "Pants",  "Shoes",  "Hand",   "Wing",    "Artifact",   "Pets",
}

-- ============================================================================
-- NAMA PENDEK PER KATEGORI (max ~6 char agar tidak overflow di button)
-- ============================================================================
ItemCategorizer.DISPLAY = {
    Gacha      = "Gacha",
    Locks      = "Locks",
    Block      = "Block",
    Machine    = "Machine",
    Background = "Background",
    Seeds      = "Seeds",
    Consumables= "Consumables",
    Hat        = "Hat",
    Hair       = "Hair",
    Face       = "Face",
    Chest      = "Chest",
    Shirt      = "Shirt",
    Pants      = "Pants",
    Shoes      = "Shoes",
    Hand       = "Hand",
    Wing       = "Wing",
    Artifact   = "Artifact",
    Pets       = "Pets",
}

-- ============================================================================
-- ICON ITEM ID PER KATEGORI (placeholder - ganti sesuai item ID server)
-- ============================================================================
ItemCategorizer.ICON = {
    Gacha      = 9752,   -- TODO: ganti dengan item gacha yang ada di server
    Locks      = 32,     -- TODO: ganti dengan item lock yang ada di server
    Block      = 2,      -- Dirt
    Machine    = 4994,   -- TODO: ganti dengan item machine yang ada di server
    Background = 14,     -- Cave Background
    Seeds      = 3,      -- Dirt Seed
    Consumables= 504,    -- placeholder consumable
    Hat        = 26,     -- placeholder hat
    Hair       = 1506,   -- placeholder hair
    Face       = 202,    -- placeholder face/mask
    Chest      = 5894,   -- placeholder chest/neck
    Shirt      = 24,     -- placeholder shirt
    Pants      = 28,     -- placeholder pants
    Shoes      = 22,     -- placeholder shoes
    Hand       = 30,     -- placeholder hand
    Wing       = 3020,   -- placeholder wing
    Artifact   = 7652,   -- placeholder artifact
    Pets       = 4690,   -- TODO: ganti dengan item pet yang ada di server
}

-- ============================================================================
-- MANUAL OVERRIDE — item ID spesifik yang tidak terdeteksi otomatis
-- Gunakan reg("Kategori", {id1, id2, id3, ...}) per grup
-- ============================================================================
ItemCategorizer.MANUAL = {}

reg("Gacha", {
    -- 9752,
    -- 9753,
})

reg("Locks", {
    -- 32,   -- Small Lock
    -- 800,  -- World Lock
})

reg("Machine", {
    -- 1234,
})

reg("Pets", {
    -- 1234,
})

reg("Wing", {
    -- 3020,
    -- 3021,
})

reg("Hat", {
    -- 1234,
})

reg("Hair", {
    -- 1234,
})

reg("Face", {
    -- 1234,
})

reg("Chest", {
    -- 1234,
})

reg("Shirt", {
    -- 1234,
})

reg("Pants", {
    -- 1234,
})

reg("Shoes", {
    -- 1234,
})

reg("Hand", {
    -- 1234,
})

reg("Artifact", {
    -- 1234,
})

reg("Consumables", {
    -- 1234,
})

reg("Seeds", {
    -- 1234,
})

reg("Background", {
    -- 1234,
})

reg("Block", {
    -- 1234,
})

-- ============================================================================
-- GETATEGORY
-- Asumsi:
--   actionType 1 = Seed
--   actionType 3 = Background
--   actionType 8 = Consumable
--   clothingType nil  = bukan clothing
--   clothingType 0    = Hat   (+ actionType 0 sebagai extra check)
--   clothingType 1-9  = Shirt/Pants/Shoes/Face/Hand/Wing/Hair/Chest/Artifact
-- NOTE: Locks, Machine, Pets tidak punya auto-detect standar —
--       daftarkan ID nya di bagian MANUAL OVERRIDE di atas.
-- ============================================================================
function ItemCategorizer.getCategory(itemID)
    -- Manual override: cek tabel MANUAL dulu sebelum deteksi otomatis
    if ItemCategorizer.MANUAL[itemID] then
        return ItemCategorizer.MANUAL[itemID]
    end

    local item = getItem(itemID)
    if not item then return "Block" end

    local atype = item:getActionType()
    local ct    = item:getClothingType()

    -- Seeds
    if atype == 1 then return "Seeds" end

    -- Background
    if atype == 3 then return "Background" end

    -- Consumables
    if atype == 8 then return "Consumables" end

    -- Clothing dengan clothingType > 0 (pasti clothing, tidak ambigu)
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

    -- Hat: clothingType == 0 DAN actionType == 0
    -- (non-clothing items biasanya punya actionType >= 2)
    if ct == 0 and atype == 0 then return "Hat" end

    -- Locks: Small Lock, World Lock, Diamond Lock, dll.
    if atype == 18 then return "Locks" end

    -- Machine: Vending Machine & Weather Machine (auto-detect)
    -- Magplant, Jammer, dll. tidak punya actionType khusus — daftarkan manual di reg("Machine")
    if atype == 28 then return "Machine" end  -- Vending Machine
    if atype == 40 then return "Machine" end  -- Weather Machine

    -- Gacha: TODO — tambahkan deteksi custom action type atau item ID range di sini
    -- Contoh: if atype == XX then return "Gacha" end

    -- Default: Block (foreground, sign, dll.)
    return "Block"
end

-- ============================================================================
-- HELPER: group storedItems by category
-- Input : storedItems table { [itemID] = count }
-- Output: { ["Block"] = {{id, count}, ...}, ... }
-- ============================================================================
function ItemCategorizer.groupByCategory(storedItems)
    local groups = {}
    for _, cat in ipairs(ItemCategorizer.LIST) do
        groups[cat] = {}
    end
    for itemID, count in pairs(storedItems) do
        local cat = ItemCategorizer.getCategory(itemID)
        if groups[cat] then
            table.insert(groups[cat], { id = itemID, count = count })
        end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return a.id < b.id end)
    end
    return groups
end

print("(item_categorizer) module loaded successfully.")
return ItemCategorizer
