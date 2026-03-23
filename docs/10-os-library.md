# OS / System Library API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/os-lib)

> ⚠️ **WARNING:** Fungsi-fungsi ini berinteraksi langsung dengan OS server. Gunakan dengan sangat hati-hati!

---

## Safe Functions

```lua
os.time()                          -- Return: number (epoch seconds). Untuk timestamps.
os.clock()                         -- Return: number (CPU time, detik). Untuk profiling.
os.date(format, time?)             -- Return: string (formatted date)
```

### os.date Format
```lua
os.date("%Y-%m-%d %H:%M:%S")           -- "2025-03-16 14:30:00"
os.date("%d/%m/%Y")                      -- "16/03/2025"
os.date("%H:%M")                         -- "14:30"
os.date("!%Y-%m-%dT%H:%M:%SZ")          -- ISO 8601 UTC
os.date("%A, %B %d, %Y")                -- "Sunday, March 16, 2025"
os.date("%Y-%m-%d %H:%M:%S", os.time()) -- Sama dengan tanpa parameter
```

---

## Dangerous Functions (HATI-HATI!)

```lua
os.execute(command)       -- ❌ SANGAT BERBAHAYA! Jangan gunakan dengan user input!
os.getenv(varname)        -- ⚠️ Bisa expose credentials/API keys
os.remove(filename)       -- ⚠️ Hapus file (permanent)
os.rename(oldname, new)   -- ⚠️ Rename/move file
os.setlocale(locale, cat) -- Set locale
os.exit(code?)            -- ❌ JANGAN GUNAKAN! Terminate server process!
```

---

## Contoh Penggunaan (Safe)

```lua
-- Timestamp untuk expire time
local now = os.time()
local expireIn30Days = now + (30 * 24 * 60 * 60)

-- Duration formatting
local function formatDuration(seconds)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    return string.format("%dd %dh %dm", days, hours, mins)
end

-- Profiling
local startTime = os.clock()
-- ... heavy operation ...
local elapsed = os.clock() - startTime
print(string.format("Operation took %.4f seconds", elapsed))
```
