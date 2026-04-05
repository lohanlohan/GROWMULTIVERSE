-- MODULE
-- premium_store_data.lua — Premium Store data layer (config, catalog, featured, stock)

local M  = {}
local DB = _G.DB

local JSON_KEY = "premium_store"

-- =======================================================
-- DEFAULT CONFIG STRUCTURE
-- =======================================================

local function defaultConfig()
    return {
        featured = {
            -- 3 slots, each: { type, id, name, price, stock, soldCount, endDate }
            -- type: "item" | "role" | "title"
            -- stock: -1 = unlimited
            -- endDate: unix timestamp (0 = no expiry / manual only)
            { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 },
            { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 },
            { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 },
        },
        catalog = {
            items  = {},  -- { id, name, price, stock, soldCount }
            roles  = {},  -- { roleId, name, price, permanent, durationDays, consumableId }
            titles = {},  -- { titleKey, name, price, eventOnly }
        },
        topup = {
            -- packages: { name, pgAmount, price (in WL), consumableId }
            packages = {},
        },
        gacha = {
            -- banners: { name, icon, price, description, pool=[{itemId, weight},...] }
            banners = {},
        },
    }
end

-- =======================================================
-- LOAD / SAVE
-- =======================================================

function M.load()
    local data = DB.loadFeature(JSON_KEY) or {}
    -- Merge defaults for missing keys
    local def = defaultConfig()
    if type(data.featured) ~= "table" then data.featured = def.featured end
    if type(data.catalog)  ~= "table" then data.catalog  = def.catalog  end
    if type(data.topup)    ~= "table" then data.topup    = def.topup    end
    if type(data.catalog.items)  ~= "table" then data.catalog.items  = {} end
    if type(data.catalog.roles)  ~= "table" then data.catalog.roles  = {} end
    if type(data.catalog.titles) ~= "table" then data.catalog.titles = {} end
    if type(data.topup.packages) ~= "table" then data.topup.packages = {} end
    if type(data.gacha)          ~= "table" then data.gacha          = { banners = {} } end
    if type(data.gacha.banners)  ~= "table" then data.gacha.banners  = {} end
    -- Ensure exactly 3 featured slots
    while #data.featured < 3 do
        data.featured[#data.featured + 1] = { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 }
    end
    return data
end

function M.save(data)
    DB.saveFeature(JSON_KEY, data)
end

-- =======================================================
-- FEATURED — auto-expire check
-- =======================================================

-- Returns featured slot table, replacing expired slots with empty
function M.getFeatured()
    local cfg  = M.load()
    local now  = os.time()
    local dirty = false
    for i, slot in ipairs(cfg.featured) do
        if slot.endDate and slot.endDate > 0 and now >= slot.endDate then
            cfg.featured[i] = { type = "item", id = 0, name = "", price = 0, stock = -1, soldCount = 0, endDate = 0 }
            dirty = true
        end
    end
    if dirty then M.save(cfg) end
    return cfg.featured
end

-- =======================================================
-- STOCK MANAGEMENT
-- =======================================================

-- Decrement stock for a purchase. Returns true if OK, false if out of stock.
-- source: "featured_1"|"featured_2"|"featured_3"|"item_N"|"role_N"|"title_N"
function M.purchase(source)
    local cfg = M.load()
    local slot = M.resolveSlot(cfg, source)
    if not slot then return false end
    if slot.stock == -1 then
        slot.soldCount = (slot.soldCount or 0) + 1
        M.save(cfg)
        return true
    end
    if slot.stock <= 0 then return false end
    slot.stock     = slot.stock - 1
    slot.soldCount = (slot.soldCount or 0) + 1
    M.save(cfg)
    return true
end

-- Roll gacha from a banner's pool using weighted random.
-- Returns itemId or nil if pool is empty.
function M.rollGacha(banner)
    local pool = banner.pool or {}
    if #pool == 0 then return nil end
    local total = 0
    for _, entry in ipairs(pool) do
        total = total + (tonumber(entry.weight) or 1)
    end
    local roll = math.random() * total
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + (tonumber(entry.weight) or 1)
        if roll <= cumulative then
            return tonumber(entry.itemId)
        end
    end
    return tonumber(pool[#pool].itemId)
end

function M.resolveSlot(cfg, source)
    local fIdx = source:match("^featured_(%d+)$")
    if fIdx then return cfg.featured[tonumber(fIdx)] end
    local iIdx = source:match("^item_(%d+)$")
    if iIdx then return cfg.catalog.items[tonumber(iIdx)] end
    local rIdx = source:match("^role_(%d+)$")
    if rIdx then return cfg.catalog.roles[tonumber(rIdx)] end
    local tIdx = source:match("^title_(%d+)$")
    if tIdx then return cfg.catalog.titles[tonumber(tIdx)] end
    return nil
end

return M
