#!/usr/bin/env lua

local email = (arg[1] or ""):gsub("^%s*(.-)%s*$", "%1")
local name = (arg[2] or ""):gsub("^%s*(.-)%s*$", "%1")
local password = (arg[3] or ""):gsub("^%s*(.-)%s*$", "%1")
local imap_host = (arg[4] or ""):gsub("^%s*(.-)%s*$", "%1")
local imap_port = tonumber(arg[5]) or 993
local smtp_host = (arg[6] or ""):gsub("^%s*(.-)%s*$", "%1")
local smtp_port = tonumber(arg[7]) or 465

local home = os.getenv("HOME") or ""
local him_dir = home .. "/.config/himalaya"
local mbsync_dir = home .. "/.config/mbsync"
local bin_dir = home .. "/.local/bin"
local systemd_dir = home .. "/.config/systemd/user"
local maildir = home .. "/.local/share/mail/gmail"

os.execute("mkdir -p " .. him_dir .. " " .. mbsync_dir .. " " .. bin_dir .. " " .. systemd_dir .. " " .. maildir)

-- 1. Write Himalaya config.toml
local him_conf = him_dir .. "/config.toml"
local f_him = io.open(him_conf, "w")
if f_him then
    f_him:write(string.format([=[
[accounts.gmail]
default = true
display-name = "%s"
email = "%s"

[accounts.gmail.backend]
type = "maildir"
root-dir = "%s"
maildirpp = true
delimiter = "."

[accounts.gmail.folder.aliases]
inbox = "INBOX"
all = ".[Gmail].All Mail"
steam = ".Steam"
drafts = ".[Gmail].Drafts"
sent = ".[Gmail].Sent Mail"
trash = ".[Gmail].Trash"
spam = ".[Gmail].Spam"
starred = ".[Gmail].Starred"

[accounts.gmail.message.send.backend]
type = "smtp"
host = "%s"
port = %d
auth.type = "password"
login = "%s"
auth.cmd = "echo '%s'"

[accounts.gmail.message.send.backend.encryption]
type = "tls"

[accounts.gmail.message.read]
text-mime-header = "text/plain"

[accounts.gmail.envelope.list]
page-size = 3000
]=], name, email, maildir, smtp_host, smtp_port, email, password))
    f_him:close()
    os.execute("chmod 600 " .. him_conf)
end

-- 2. Write mbsyncrc
local mbsync_conf = mbsync_dir .. "/mbsyncrc"
local f_mb = io.open(mbsync_conf, "w")
if f_mb then
    f_mb:write(string.format([=[
SyncState *
IMAPAccount gmail
Host %s
Port %d
User "%s"
Pass "%s"
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt
AuthMechs PLAIN
PipelineDepth 1

IMAPStore gmail-remote
Account gmail

MaildirStore gmail-local
SubFolders Maildir++
Inbox %s

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Patterns "INBOX" "Steam" "[Gmail]/All Mail" "[Gmail]/Drafts" "[Gmail]/Trash" "[Gmail]/Sent Mail" "[Gmail]/Spam" "[Gmail]/Starred"
Create Near
Sync All
Expunge Both
]=], imap_host, imap_port, email, password, maildir))
    f_mb:close()
    os.execute("chmod 600 " .. mbsync_conf)
end

-- 3. Write user systemd sync service
local svc_path = systemd_dir .. "/himalaya-sync.service"
local f_svc = io.open(svc_path, "w")
if f_svc then
    f_svc:write(string.format([=[
[Unit]
Description=Himalaya mail sync and queue processor
After=network.target

[Service]
Type=oneshot
ExecStart=mbsync -c %s/mbsyncrc gmail

[Install]
WantedBy=default.target
]=], mbsync_dir))
    f_svc:close()
    os.execute("systemctl --user daemon-reload 2>/dev/null; systemctl --user enable himalaya-sync.service 2>/dev/null")
end

os.exit(0)
