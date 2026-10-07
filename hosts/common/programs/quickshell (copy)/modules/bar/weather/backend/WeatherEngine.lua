-- modules/bar/weather/backend/WeatherEngine.lua
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or ""
local py_script = script_dir .. "WeatherEngine.py"

local p = io.popen("python3 " .. py_script .. " 2>/dev/null")
if p then
    local out = p:read("*a")
    p:close()
    if out and #out > 10 then
        io.write(out)
        os.exit(0)
    end
end

print('{"status":"error","msg":"Forecast temporarily unavailable."}')
