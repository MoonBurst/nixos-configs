#!/usr/bin/env lua
-- modules/overlays/email/backend/HimalayaEngine.lua
-- Dedicated backend engine for Himalaya CLI with universal runtime SOPS

local action = arg[1] or ""
local home_dir = os.getenv("HOME") or "/tmp"
local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local script_dir = (debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./")
local cache_dir = home_dir .. "/.cache/himalaya"
local cache_file = cache_dir .. "/emails.json"
local config_dir = home_dir .. "/.config/himalaya"
local config_file = config_dir .. "/config.toml"

local path_prefix = 'export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/${USER:-$(id -un 2>/dev/null)}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin:$PATH"; '

local function run_cmd(cmd)
    local pipe = io.popen(path_prefix .. cmd)
    if not pipe then return "" end
    local output = pipe:read("*a") or ""
    pipe:close()
    return output
end

local function escape_json(s)
    if not s then return '""' end
    local escapes = {
        ['\\'] = '\\\\',
        ['"']  = '\\"',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
    }
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
        return escapes[c] or string.format('\\u%04x', c:byte())
    end) .. '"'
end

-- Find SOPS file dynamically across standard repo locations
local function find_sops_file()
    local env_override = os.getenv("SOPS_FILE") or os.getenv("SOPS_SECRETS_FILE")
    if env_override then
        local f = io.open(env_override, "r")
        if f then f:close(); return env_override end
    end

    local standard_locations = {
        home_dir .. "/nix/secrets/secrets.yaml",
        home_dir .. "/nix/sops/secrets.yaml",
        home_dir .. "/nix/secrets.yaml",
        home_dir .. "/dotfiles/secrets/secrets.yaml",
        home_dir .. "/dotfiles/sops/secrets.yaml",
        home_dir .. "/dotfiles/secrets.yaml",
        home_dir .. "/.config/sops/secrets.yaml",
        home_dir .. "/.config/nix/secrets.yaml",
        "/etc/nixos/secrets/secrets.yaml",
        "/etc/nixos/secrets.yaml"
    }
    for _, path in ipairs(standard_locations) do
        local f = io.open(path, "r")
        if f then f:close(); return path end
    end

    local search_roots = {
        home_dir .. "/nix",
        home_dir .. "/dotfiles",
        home_dir .. "/.config/nix",
        home_dir .. "/.config/sops",
        "/etc/nixos"
    }
    for _, root in ipairs(search_roots) do
        local cmd = string.format("find %q -maxdepth 4 -type f \\( -name 'secrets*.yaml' -o -name 'secrets*.yml' \\) 2>/dev/null", root)
        local pipe = io.popen(cmd)
        if pipe then
            for match in pipe:lines() do
                local f = io.open(match, "r")
                if f then
                    local head = f:read(1024) or ""
                    f:close()
                    if head:match("sops:") or head:match("gmail") or match:match("secrets") then
                        pipe:close()
                        return match
                    end
                end
            end
            pipe:close()
        end
    end

    return nil
end

-- Read secret from /run/secrets or decrypt directly via SOPS CLI
local function get_sops_secret(key)
    local uid = run_cmd("id -u 2>/dev/null"):gsub("[\r\n%s]+", "")
    if #uid == 0 then uid = "1000" end

    local runtime_candidates = {
        "/run/secrets/" .. key,
        "/run/secrets.d/" .. key,
        "/run/user/" .. uid .. "/secrets/" .. key,
        runtime_dir .. "/secrets/" .. key
    }

    for _, p in ipairs(runtime_candidates) do
        local f = io.open(p, "r")
        if f then
            local val = f:read("*a")
            f:close()
            if val then
                val = val:gsub("[\r\n%s]+$", ""):gsub("^[\r\n%s]+", "")
                if #val > 0 then return val, p end
            end
        end
    end

    local sops_file = find_sops_file()
    if sops_file then
        local cmd = string.format("sops -d --extract '[%q]' %q 2>/dev/null", key, sops_file)
        local out = run_cmd(cmd):gsub("[\r\n%s]+$", ""):gsub("^[\r\n%s]+", "")
        if #out > 0 then return out, nil end
    end

    return nil, nil
end

local function save_to_sops(email, code)
    local sops_file = find_sops_file()
    if not sops_file then return false end

    if email and #email > 0 then
        local cmd = string.format('sops --set \'["gmail_address_himalaya"] "%s"\' %q 2>/dev/null', email, sops_file)
        os.execute(path_prefix .. cmd)
    end
    if code and #code > 0 then
        local cmd = string.format('sops --set \'["gmail_code_himalaya"] "%s"\' %q 2>/dev/null', code, sops_file)
        os.execute(path_prefix .. cmd)
    end
    return true
end

local function write_config_toml(email, code_cmd, imap_host, imap_port, smtp_host, smtp_port)
    os.execute(string.format('mkdir -p %q %q', config_dir, cache_dir))

    local toml = string.format([[# Himalaya configuration generated by Quickshell
[accounts.default]
default = true
email = %q
display-name = "User"
downloads-dir = "~/Downloads"

backend.type = "imap"
backend.host = %q
backend.port = %d
backend.encryption.type = "tls"
backend.login = %q
backend.auth.type = "password"
backend.auth.cmd = %q

message.send.backend.type = "smtp"
message.send.backend.host = %q
message.send.backend.port = %d
message.send.backend.encryption.type = "tls"
message.send.backend.login = %q
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = %q
]], email, imap_host or "imap.gmail.com", imap_port or 993, email, code_cmd,
    smtp_host or "smtp.gmail.com", smtp_port or 465, email, code_cmd)

    local f = io.open(config_file, "w")
    if f then
        f:write(toml)
        f:close()
        os.execute(string.format('chmod 600 %q', config_file))
        return true
    end
    return false
end

-- ============================================================================
-- 1. CHECK SOPS SECRETS (Returns 0 if both exist, 1 if missing)
-- ============================================================================
if action == "check-sops" then
    local sops_addr = get_sops_secret("gmail_address_himalaya")
    local sops_code = get_sops_secret("gmail_code_himalaya")

    if sops_addr and #sops_addr > 0 and sops_code and #sops_code > 0 then
        os.exit(0)
    else
        os.exit(1)
    end

-- ============================================================================
-- 2. SETUP WIZARD & SAVING TO SOPS
-- ============================================================================
elseif #arg >= 7 and not action:match("^[A-Z_]+$") and action ~= "sync" and action ~= "watch" then
    local email     = arg[1]
    local name      = arg[2]
    local password  = arg[3]
    local imap_host = arg[4]
    local imap_port = tonumber(arg[5]) or 993
    local smtp_host = arg[6]
    local smtp_port = tonumber(arg[7]) or 465

    -- 1. Save directly into your SOPS secrets file via `sops --set`
    save_to_sops(email, password)

    -- 2. Determine auth command for Himalaya config
    local _, sops_code_path = get_sops_secret("gmail_code_himalaya")
    local sops_file = find_sops_file()
    local auth_cmd = sops_code_path and ("cat " .. sops_code_path)
                  or (sops_file and string.format("sops -d --extract '[\"gmail_code_himalaya\"]' %q", sops_file)
                  or string.format("printf '%%s' %q", password))

    local ok = write_config_toml(email, auth_cmd, imap_host, imap_port, smtp_host, smtp_port)
    if ok then os.exit(0) else os.exit(1) end

-- ============================================================================
-- 3. IMAP IDLE EVENT WATCHER
-- ============================================================================
elseif action == "watch" then
    local p = io.popen(path_prefix .. "himalaya envelope watch 2>&1 || himalaya watch 2>&1")
    if p then
        for line in p:lines() do
            io.write("SYNC\n")
            io.flush()
        end
        p:close()
    end

-- ============================================================================
-- 4. SYNC ENVELOPES (HimalayaSync.py)
-- ============================================================================
elseif action == "sync" or action == "" then
    os.execute(string.format('mkdir -p %q', cache_dir))

    local sync_script = script_dir .. "HimalayaSync.py"
    local fetch_cmd = string.format([[
%s
RAW=$(himalaya envelope list --folder INBOX -s 150 --output json 2>/dev/null || himalaya envelope list -s 150 --json 2>/dev/null)
if [ -n "$RAW" ]; then
    printf '%%s' "$RAW" | python3 %q
fi
]], path_prefix, sync_script)

    os.execute(fetch_cmd)

-- ============================================================================
-- 5. FETCH MESSAGE BODY (Strips MIME markup tags)
-- ============================================================================
elseif action == "FETCH_BODY" or action == "fetch-body" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if not msg_id then return end

    local cmd = string.format('himalaya message read --folder %q %q 2>/dev/null || himalaya message read %q 2>/dev/null', folder, msg_id, msg_id)
    local body = run_cmd(cmd)
    if not body or #body == 0 then
        body = "Message body could not be fetched from server."
    end

    body = body:gsub("<#part[^>]*>", ""):gsub("<#/part>", ""):gsub("^%s+", "")
    io.write(body)

-- ============================================================================
-- 6. SEND MESSAGE (With authenticated From header)
-- ============================================================================
elseif action == "SEND" or action == "send" then
    local to = arg[2]
    local subject = arg[3]
    local body = arg[4] or ""

    if not to or to == "" then
        io.stderr:write("Recipient address missing.\n")
        return
    end

    local sender_email = get_sops_secret("gmail_address_himalaya") or ""
    if sender_email == "" then
        local cf = io.open(config_file, "r")
        if cf then
            local data = cf:read("*a") or ""
            cf:close()
            sender_email = data:match('email%s*=%s*"([^"]+)"') or to
        else
            sender_email = to
        end
    end

    local email_raw = string.format("From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=utf-8\n\n%s",
        sender_email, to, subject, body)
    local tmp_msg = string.format("%s/qmail_send_%d.eml", runtime_dir, os.time())
    local mf = io.open(tmp_msg, "w")
    if mf then
        mf:write(email_raw)
        mf:close()

        local send_cmd = string.format(
            'himalaya message send < %q 2>&1 || himalaya template send < %q 2>&1',
            tmp_msg, tmp_msg
        )
        local err_pipe = io.popen(path_prefix .. send_cmd)
        local res_msg = err_pipe and err_pipe:read("*a") or ""
        local ok, exit_type, code = err_pipe:close()
        os.remove(tmp_msg)

        if ok or code == 0 then
            os.execute(string.format('notify-send -a Himalaya "Email Sent" "Delivered to %s"', to))
        else
            local clean_err = res_msg:gsub("[\r\n]+", " "):sub(1, 140)
            os.execute(string.format('notify-send -u critical -a Himalaya "Send Failed" %q', clean_err ~= "" and clean_err or "SMTP relay rejected transmission"))
        end
    end

-- ============================================================================
-- 7. FLAGS & FOLDERS
-- ============================================================================
elseif action == "DELETE" or action == "delete" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya message delete --folder %q %q 2>/dev/null || himalaya message delete %q 2>/dev/null', folder, msg_id, msg_id))
    end

elseif action == "STAR" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya flag add --folder %q %q flagged 2>/dev/null || himalaya flag add %q flagged 2>/dev/null', folder, msg_id, msg_id))
    end

elseif action == "UNSTAR" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya flag remove --folder %q %q flagged 2>/dev/null || himalaya flag remove %q flagged 2>/dev/null', folder, msg_id, msg_id))
    end

elseif action == "READ" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya flag add --folder %q %q seen 2>/dev/null || himalaya flag add %q seen 2>/dev/null', folder, msg_id, msg_id))
    end

elseif action == "UNREAD" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya flag remove --folder %q %q seen 2>/dev/null || himalaya flag remove %q seen 2>/dev/null', folder, msg_id, msg_id))
    end

elseif action == "MOVE" then
    local msg_id = arg[2]
    local from_folder = arg[3] or "INBOX"
    local to_folder = arg[4] or "Trash"
    if msg_id then
        os.execute(path_prefix .. string.format('himalaya message move --folder %q %q %q 2>/dev/null', from_folder, msg_id, to_folder))
    end

elseif action == "DOWNLOAD_ATTACHMENTS" then
    local msg_id = arg[2]
    local folder = arg[3] or "INBOX"
    local dest_dir = arg[4] or (home_dir .. "/Downloads")
    if msg_id then
        os.execute(string.format('mkdir -p %q', dest_dir))
        os.execute(path_prefix .. string.format('himalaya attachment download --folder %q %q --dir %q 2>/dev/null', folder, msg_id, dest_dir))
        os.execute(string.format('notify-send -a Himalaya "Attachments Downloaded" "Saved to %s"', dest_dir))
    end

elseif action == "CONTACT" then
    local nick = arg[2] or ""
    local email = arg[3] or ""
    if email ~= "" then
        local contacts_file = home_dir .. "/Documents/Contacts"
        os.execute(string.format('mkdir -p %q', home_dir .. "/Documents"))
        local cf = io.open(contacts_file, "a")
        if cf then
            cf:write(string.format("%s <%s>\n", nick ~= "" and nick or email, email))
            cf:close()
            os.execute(string.format('notify-send -a Himalaya "Contact Saved" "%s <%s>"', nick, email))
        end
    end
end
