-- MODULE
-- config.lua — Global constants & settings (global via _G.Config)
-- Semua ID, nama world, role, dan setting terpusat di sini.
-- Jangan hardcode nilai ini di module lain — selalu pakai Config.

local C = {}

-- ═══════════════════════════════════════════
-- SERVER IDs
-- ADMIN server = beta testing (4134)
-- MAIN server  = production Growtopia Multiverse (4552)
-- Update ACTIVE_SERVER ke MAIN saat feature sudah final product
-- ═══════════════════════════════════════════
C.SERVER = {
    ADMIN  = "4134",   -- beta testing
    MAIN   = "4552",   -- production
}
C.ACTIVE_SERVER = C.SERVER.ADMIN   -- << ganti ke C.SERVER.MAIN saat ready production

-- ═══════════════════════════════════════════
-- WORLDS
-- ═══════════════════════════════════════════
C.WORLDS = {
    CARNIVAL  = "CARNIVAL_2",
    HOSPITAL  = "HOSPITAL",
    -- tambah nama world baru di sini
}

-- ═══════════════════════════════════════════
-- ROLES
-- ═══════════════════════════════════════════
C.ROLES = {
    PLAYER    = 0,
    STAFF     = 51,   -- mod / privileged
    DEV       = 52,   -- developer / admin penuh
}

-- ═══════════════════════════════════════════
-- ITEM IDs
-- ═══════════════════════════════════════════
C.ITEMS = {
    -- Currency
    WORLD_LOCK       = 242,
    DIAMOND_LOCK     = 1796,
    BLUE_GEM_LOCK    = 3796,
    GOLDEN_GEM_LOCK  = 0,     -- TODO: isi ID

    -- Carnival
    GOLDEN_TICKET    = 1898,
    BULLSEYE         = 1908,
    CARD_CLOSED      = 1916,
    RINGMASTER_HAT   = 0,     -- TODO: isi ID

    -- Hospital
    VILE_VIAL        = 0,     -- TODO: isi ID

    -- Misc
    WORLD_SEED       = 0,     -- TODO: isi ID
}

-- ═══════════════════════════════════════════
-- SETTINGS
-- ═══════════════════════════════════════════
C.SETTINGS = {
    -- Economy
    DL_TO_WL          = 100,   -- 1 DL = 100 WL
    BGL_TO_DL         = 100,   -- 1 BGL = 100 DL
    GGL_TO_BGL        = 100,   -- 1 GGL = 100 BGL

    -- Backpack
    MAX_BP_DROP       = 200,   -- max item per drop dari backpack
    DEFAULT_BP_SLOTS  = 4,     -- slot backpack default

    -- Carnival
    CARNIVAL_QUEUE_DELAY = 3,  -- detik delay antar player di queue

    -- Misc
    MAX_INVENTORY_SLOTS = 32,
}

return C
