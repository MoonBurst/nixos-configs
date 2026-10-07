#!/usr/bin/env lua

local function get_cmd_output(cmd)
    local p = io.popen(cmd)
    if not p then return "" end
    local r = p:read("*a") or ""
    p:close()
    return r:gsub("^%s*(.-)%s*$", "%1")
end

-- 1. Count Nix Generations
local gen_count = 0
local p_gens = io.popen("find /nix/var/nix/profiles/ -maxdepth 1 -name 'system-*-link' 2>/dev/null | wc -l")
if p_gens then
    gen_count = tonumber(p_gens:read("*l")) or 0
    p_gens:close()
end
if gen_count == 0 then
    local p_env = io.popen("nix-env --list-generations -p /nix/var/nix/profiles/system 2>/dev/null | wc -l")
    if p_env then
        gen_count = tonumber(p_env:read("*l")) or 0
        p_env:close()
    end
end

-- 2. Kernel comparison
local cur_k = get_cmd_output("uname -r")
local sys_k = get_cmd_output("ls /run/current-system/kernel-modules/lib/modules 2>/dev/null | head -n 1")
if sys_k == "" then
    sys_k = get_cmd_output("ls /lib/modules 2>/dev/null | sort -V | tail -n 1")
end
if sys_k == "" then sys_k = cur_k end

local reboot_req = (cur_k ~= sys_k) and 1 or 0

-- 3. Git dirty & Flake age
local git_dirty = 0
local nix_dir = (os.getenv("HOME") or "") .. "/nix"
local p_git = io.popen("git -C " .. string.format("%q", nix_dir) .. " status --porcelain 2>/dev/null | wc -l")
if p_git then
    git_dirty = tonumber(p_git:read("*l")) or 0
    p_git:close()
end

local flake_age = 0
local flake_file = nix_dir .. "/flake.lock"
local p_stat = io.popen("stat -c %Y " .. string.format("%q", flake_file) .. " 2>/dev/null")
if p_stat then
    local mtime = tonumber(p_stat:read("*l"))
    p_stat:close()
    if mtime then
        flake_age = math.floor((os.time() - mtime) / 86400)
    end
end

io.write(string.format(
    '{"gens":%d,"cur_k":"%s","sys_k":"%s","reboot":%d,"git_dirty":%d,"flake_age":%d}\n',
    gen_count, cur_k, sys_k, reboot_req, git_dirty, flake_age
))
