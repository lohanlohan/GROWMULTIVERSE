# HTTP & JSON Utilities API

> Sumber: [Skoobz Docs](https://docs.skoobz.dev/structures/http-and-json)

---

## HTTP Requests

> ⚠️ **WAJIB dalam coroutine!** Semua HTTP request harus di-wrap dalam coroutine agar tidak block server.

### GET Request
```lua
http.get(url, headers?)
```
- `url` — string URL
- `headers` — optional table of HTTP headers
- Return: `body` (string), `status` (number)

### POST Request
```lua
http.post(url, headers?, postData)
```
- `url` — string URL
- `headers` — optional table of HTTP headers
- `postData` — string atau table data
- Return: `body` (string), `status` (number)

### Contoh Penggunaan

```lua
-- GET request sederhana
coroutine.wrap(function()
    local body, status = http.get("https://api.example.com/data")
    if status == 200 then
        local data = json.decode(body)
        print("Success: " .. tostring(data))
    else
        print("Error: " .. status)
    end
end)()

-- POST request dengan headers
coroutine.wrap(function()
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer mytoken123"
    }
    local postData = json.encode({ name = "test", value = 123 })
    local body, status = http.post("https://api.example.com/submit", headers, postData)
    if status == 200 then
        print("Posted successfully!")
    end
end)()

-- Webhook Discord
coroutine.wrap(function()
    local webhookUrl = "https://discord.com/api/webhooks/xxx/yyy"
    local payload = json.encode({
        content = "Server notification!",
        username = "GTPS Bot"
    })
    http.post(webhookUrl, { ["Content-Type"] = "application/json" }, payload)
end)()
```

---

## JSON Utilities

### Encode
```lua
json.encode(dataTable)        -- Return: string (compact JSON)
json.encode(dataTable, 4)     -- Return: string (pretty print, 4-space indent)
```

### Decode
```lua
json.decode(jsonString)       -- Return: Lua table, atau nil jika invalid
```

### Contoh
```lua
-- Encode
local data = { name = "Player1", gems = 500, items = {1, 2, 3} }
local jsonStr = json.encode(data)
print(jsonStr) -- {"name":"Player1","gems":500,"items":[1,2,3]}

-- Pretty print
print(json.encode(data, 4))

-- Decode
local parsed = json.decode('{"name":"Test","value":42}')
if parsed then
    print(parsed.name)  -- "Test"
    print(parsed.value) -- 42
end

-- Safe decode
local result = json.decode(someString)
if result == nil then
    print("Invalid JSON!")
end
```
