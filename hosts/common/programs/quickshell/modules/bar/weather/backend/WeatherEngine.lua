#!/usr/bin/env lua
-- modules/bar/weather/backend/WeatherEngine.lua
-- Pure Lua weather engine replacing WeatherEngine.py

local function fetch_weather()
    local handle = io.popen("curl -s -L --connect-timeout 4 --max-time 8 'https://wttr.in/?format=j1' 2>/dev/null")
    if not handle then return nil end
    local content = handle:read("*a")
    handle:close()
    if not content or content == "" or not content:find("current_condition") then
        return nil
    end
    return content
end

-- Minimal JSON decoder in pure Lua
local function json_parse(str)
    local pos = 1
    local function skip_whitespace()
        pos = str:match("^%s*()", pos)
    end

    local parse_value

    local function parse_string()
        local s = ""
        pos = pos + 1
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return s
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if esc == '"' or esc == '\\' or esc == '/' then s = s .. esc
                elseif esc == 'b' then s = s .. '\b'
                elseif esc == 'f' then s = s .. '\f'
                elseif esc == 'n' then s = s .. '\n'
                elseif esc == 'r' then s = s .. '\r'
                elseif esc == 't' then s = s .. '\t'
                end
                pos = pos + 1
            else
                s = s .. c
                pos = pos + 1
            end
        end
        return s
    end

    local function parse_number()
        local num_str = str:match("^[%-%d%.eE+]+", pos)
        pos = pos + #num_str
        return tonumber(num_str)
    end

    local function parse_array()
        local arr = {}
        pos = pos + 1
        skip_whitespace()
        if str:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end
        while true do
            table.insert(arr, parse_value())
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            elseif c == ',' then
                pos = pos + 1
                skip_whitespace()
            else
                return arr
            end
        end
    end

    local function parse_object()
        local obj = {}
        pos = pos + 1
        skip_whitespace()
        if str:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end
        while true do
            skip_whitespace()
            local key = parse_string()
            skip_whitespace()
            if str:sub(pos, pos) == ':' then pos = pos + 1 end
            skip_whitespace()
            obj[key] = parse_value()
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            elseif c == ',' then
                pos = pos + 1
            else
                return obj
            end
        end
    end

    parse_value = function()
        skip_whitespace()
        local c = str:sub(pos, pos)
        if c == '"' then return parse_string()
        elseif c == '{' then return parse_object()
        elseif c == '[' then return parse_array()
        elseif c == 't' and str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif c == 'f' and str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif c == 'n' and str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        else return parse_number() end
    end

    local ok, res = pcall(parse_value)
    return ok and res or nil
end

local function get_weather_icon(desc)
    local d = (desc or ""):lower()
    if d:find("thunder") or d:find("storm") then return "⛈️"
    elseif d:find("snow") or d:find("sleet") or d:find("blizzard") or d:find("ice") then return "❄️"
    elseif d:find("heavy rain") or d:find("torrential") then return "🚨"
    elseif d:find("rain") or d:find("shower") or d:find("drizzle") then return "🌧️"
    elseif d:find("cloud") or d:find("overcast") then return "☁️"
    elseif d:find("clear") or d:find("sun") then return "☀️"
    else return "🌤️" end
end

local function format_time(time_str)
    local n = tonumber(time_str) or 0
    local hours = math.floor(n / 100)
    local ampm = (hours >= 12) and "PM" or "AM"
    local h12 = hours % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%d%s", h12, ampm)
end

local raw = fetch_weather()
if not raw then
    print('{"status":"error","msg":"Forecast temporarily unavailable."}')
    os.exit(0)
end

local data = json_parse(raw)
if not data or not data.current_condition or #data.current_condition == 0 then
    print('{"status":"error","msg":"Unable to parse weather data."}')
    os.exit(0)
end

local current = data.current_condition[1]
local temp_c = current.temp_C or "0"
local temp_f = current.temp_F or "0"
local desc = "Clear"
if current.weatherDesc and current.weatherDesc[1] and current.weatherDesc[1].value then
    desc = current.weatherDesc[1].value
end

local wind_speed = tonumber(current.windspeedMiles) or 0
local warning_level = "none"
local warning_cause = ""

local lower_desc = desc:lower()
if lower_desc:find("thunder") or lower_desc:find("storm") or lower_desc:find("tornado") then
    warning_level = "active"
    warning_cause = "Thunderstorm Active"
elseif wind_speed >= 40 then
    warning_level = "active"
    warning_cause = "High Wind Warning"
elseif lower_desc:find("blizzard") or lower_desc:find("ice") then
    warning_level = "active"
    warning_cause = "Severe Winter Storm"
elseif lower_desc:find("rain") and lower_desc:find("heavy") then
    warning_level = "upcoming"
    warning_cause = "Heavy Rain"
elseif tonumber(temp_f) and tonumber(temp_f) <= 15 then
    warning_level = "upcoming"
    warning_cause = "Extreme Cold"
end

local lines = {}
table.insert(lines, string.format("Now: %s°F / %s°C, %s %s (Wind: %dmph)", temp_f, temp_c, get_weather_icon(desc), desc, wind_speed))

if data.weather and #data.weather > 0 then
    local count = 0
    for day_idx = 1, math.min(2, #data.weather) do
        local day = data.weather[day_idx]
        if day.hourly then
            for _, hour in ipairs(day.hourly) do
                if count < 10 then
                    local t_label = format_time(hour.time)
                    local h_f = hour.tempF or "0"
                    local h_c = hour.tempC or "0"
                    local h_desc = (hour.weatherDesc and hour.weatherDesc[1]) and hour.weatherDesc[1].value or "Clear"
                    local icon = get_weather_icon(h_desc)
                    table.insert(lines, string.format("%-5s  %s  %s°F / %s°C  %s", t_label, icon, h_f, h_c, h_desc))
                    count = count + 1
                end
            end
        end
    end
end

local tooltip = table.concat(lines, "\\n")

local out = string.format(
    '{"status":"ok","temp_f":"%s","temp_c":"%s","desc":"%s","warning_level":"%s","warning_cause":"%s","tooltip_text":"%s"}',
    temp_f, temp_c, desc:gsub('"', '\\"'), warning_level, warning_cause:gsub('"', '\\"'), tooltip:gsub('"', '\\"')
)

print(out)
