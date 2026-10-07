#!/usr/bin/env python3
import json, urllib.request, os, sys, datetime

cache_file = "/tmp/weather_cache_j1.json"
storm_flag_file = "/dev/shm/weather-storm-active.txt"

# 1. Fetch live wttr.in JSON with fallback cache
data = None
try:
    req = urllib.request.Request(
        "https://wttr.in/?format=j1",
        headers={"User-Agent": "curl/7.88.1"}
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        if resp.status == 200:
            content = resp.read().decode('utf-8', errors='ignore')
            if '"current_condition"' in content and '"weather"' in content:
                data = json.loads(content)
                with open(cache_file, "w") as cf:
                    cf.write(content)
except Exception:
    pass

if not data and os.path.exists(cache_file):
    try:
        with open(cache_file, "r") as cf:
            data = json.load(cf)
    except Exception:
        pass

if not data:
    print(json.dumps({"status": "error", "msg": "Weather forecast unavailable."}))
    sys.exit(0)

# Current condition
cur = data.get("current_condition", [{}])[0]
cur_f = cur.get("temp_F", "0")
cur_c = cur.get("temp_C", "0")
cur_desc = (cur.get("weatherDesc", [{}])[0].get("value") or "Clear").strip()
cur_wind = cur.get("windspeedMiles", "0")

# Heuristic for detecting bad weather / hazards
def check_bad_weather(desc, code_str, wind_str, precip_str, thunder_str, rain_str):
    d = (desc or "").lower()
    c = int(code_str) if code_str and code_str.isdigit() else 0
    w = float(wind_str) if wind_str else 0
    p = float(precip_str) if precip_str else 0
    t_prob = float(thunder_str) if thunder_str else 0
    r_prob = float(rain_str) if rain_str else 0

    if "tornado" in d or "hurricane" in d:
        return True, "Tornado / Hurricane"
    if "thunder" in d or "lightning" in d or t_prob >= 35 or (386 <= c <= 395):
        return True, "Thunderstorm"
    if "blizzard" in d or c in [227, 230]:
        return True, "Blizzard"
    if "ice" in d or "freezing rain" in d or "hail" in d or (314 <= c <= 317):
        return True, "Freezing Rain / Hail"
    if "heavy rain" in d or "torrential" in d or "downpour" in d or p >= 4.0 or (r_prob >= 80 and "rain" in d):
        return True, "Heavy Rain"
    if w >= 38 or "gale" in d:
        return True, f"High Winds ({int(w)}mph)"
    return False, None

def get_icon(desc, is_night):
    d = (desc or "").lower()
    if "thunder" in d or "lightning" in d: return "⛈️"
    if "snow" in d or "blizzard" in d or "ice" in d: return "❄️"
    if "heavy rain" in d or "torrential" in d: return "🌧️"
    if "rain" in d or "drizzle" in d or "shower" in d: return "🌦️"
    if "fog" in d or "mist" in d or "haze" in d: return "🌫️"
    if "partly" in d or "scattered" in d: return "☁️" if is_night else "⛅"
    if "overcast" in d or "cloud" in d: return "☁️"
    return "🌙" if is_night else "☀️"

now = datetime.datetime.now()
days = data.get("weather", [])

all_slots = []
for day_idx, day_obj in enumerate(days[:3]):
    date_str = day_obj.get("date", "")
    for h in day_obj.get("hourly", []):
        time_int = int(h.get("time", "0"))  # 0, 300, 600, 900, 1200, 1500, 1800, 2100
        hour = time_int // 100
        try:
            slot_dt = datetime.datetime.strptime(f"{date_str} {hour:02d}:00", "%Y-%m-%d %H:%M")
        except Exception:
            slot_dt = now + datetime.timedelta(hours=(day_idx * 24 + hour - now.hour))

        diff_hours = (slot_dt - now).total_seconds() / 3600.0
        h["_dt"] = slot_dt
        h["_diff_hours"] = diff_hours
        h["_hour"] = hour
        all_slots.append(h)

# Filter to the next 8 three-hour intervals (Next 24 Hours)
future_slots = [s for s in all_slots if s["_diff_hours"] > -0.5]
future_slots.sort(key=lambda s: s["_diff_hours"])
selected_slots = future_slots[:8]

# Danger (active) = within next 1 hour (or occurring now)
# Warning (upcoming) = within next 3 hours
warning_level = "none"
warning_cause = ""

bad_cur, cause_cur = check_bad_weather(cur_desc, cur.get("weatherCode"), cur_wind, cur.get("precipMM"), 0, 0)
if bad_cur:
    warning_level = "active"
    warning_cause = cause_cur

for slot in selected_slots:
    s_desc = (slot.get("weatherDesc", [{}])[0].get("value") or "").strip()
    s_wind = slot.get("windspeedMiles", "0")
    s_precip = slot.get("precipMM", "0")
    s_thunder = slot.get("chanceofthunder", "0")
    s_rain = slot.get("chanceofrain", "0")
    s_code = slot.get("weatherCode", "0")

    is_bad, cause = check_bad_weather(s_desc, s_code, s_wind, s_precip, s_thunder, s_rain)
    if is_bad:
        diff = slot["_diff_hours"]
        if diff <= 1.2:
            warning_level = "active"
            warning_cause = cause
            break
        elif diff <= 3.2 and warning_level != "active":
            warning_level = "upcoming"
            warning_cause = f"{cause} in ~{max(1, round(diff))}h"

# Keep system sentinel synced
if warning_level == "active":
    try:
        with open(storm_flag_file, "w") as f:
            f.write("1\n")
    except Exception:
        pass
else:
    try:
        if os.path.exists(storm_flag_file):
            os.remove(storm_flag_file)
    except Exception:
        pass

# Format 24-hour lines
lines = []
now_icon = get_icon(cur_desc, now.hour < 6 or now.hour >= 20)
lines.append(f"Now:       {now_icon} {cur_f:>2}°F / {cur_c:>2}°C, {cur_desc} (💨 {cur_wind}mph)")

for s in selected_slots:
    dt = s["_dt"]
    time_label = dt.strftime("%I:%M %p").lstrip("0")
    time_padded = f"{time_label:>8}"

    h_desc = (s.get("weatherDesc", [{}])[0].get("value") or "Clear").strip()
    tf = s.get("tempF", "0")
    tc = s.get("tempC", "0")
    icon = get_icon(h_desc, dt.hour < 6 or dt.hour >= 20)

    r_ch = int(s.get("chanceofrain", 0))
    t_ch = int(s.get("chanceofthunder", 0))
    s_ch = int(s.get("chanceofsnow", 0))

    extra = ""
    if t_ch >= 30:
        extra = f" (⛈️ {t_ch}%)"
    elif r_ch >= 25:
        extra = f" (🌧️ {r_ch}%)"
    elif s_ch >= 25:
        extra = f" (❄️ {s_ch}%)"

    line = f"{time_padded}: {icon} {tf:>2}°F / {tc:>2}°C, {h_desc[:18]}{extra}"
    lines.append(line)

tooltip_str = "\n".join(lines)

result = {
    "status": "ok",
    "temp_f": cur_f,
    "temp_c": cur_c,
    "desc": cur_desc,
    "warning_level": warning_level,
    "warning_cause": warning_cause,
    "tooltip_text": tooltip_str
}
print(json.dumps(result))
