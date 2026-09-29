{ config, pkgs, lib, ... }:

let
  registerPort = 8089;
  pythonWithArgon = pkgs.python3.withPackages (ps: [ ps.argon2-cffi ]);

  serverScript = pkgs.writeScriptBin "matrix-register-server" ''#!${pythonWithArgon}/bin/python3
import os
import json
import sqlite3
import secrets
import smtplib
import time
from email.message import EmailMessage
import urllib.request
import urllib.error
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from argon2 import PasswordHasher

ABS_DB = "/var/lib/audiobookshelf/config/absdatabase.sqlite"
CONDUIT_DB = "/var/lib/continuwuity/conduit.db"
EMAILS_FILE = "/var/lib/continuwuity/user_recovery_emails.json"

RECOVERY_CODES = {}
ph = PasswordHasher()

def get_secret(path):
    try:
        if os.path.exists(path):
            with open(path, "r") as f:
                return f.read().strip()
    except Exception as e:
        print(f"Warning: Could not read secret {path}: {e}")
    return None

GMAIL_USER = get_secret("${config.sops.secrets.gmail_address.path}") or "moonburstplays@gmail.com"
GMAIL_PASS = get_secret("${config.sops.secrets.gmail_app_password.path}")

def send_recovery_email(to_email, username, code):
    if not GMAIL_PASS:
        print("Error: GMAIL_PASS secret not found.")
        return False
    try:
        msg = EmailMessage()
        msg["Subject"] = "Moon Burst - Account Recovery Code"
        msg["From"] = GMAIL_USER
        msg["To"] = to_email
        msg.set_content(f"""Hello {username},

You requested a password reset for your Moon Burst Matrix and Audiobooks account.

Your 6-digit recovery code is:

    {code}

This code will expire in 15 minutes. If you did not request this, please ignore this email.
""")
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(GMAIL_USER, GMAIL_PASS)
            server.send_message(msg)
        return True
    except Exception as e:
        print("SMTP Error:", e)
        return False

def save_user_email(username, email):
    data = {}
    if os.path.exists(EMAILS_FILE):
        try:
            with open(EMAILS_FILE, "r") as f: data = json.load(f)
        except Exception: data = {}
    data[username.lower()] = email
    try:
        with open(EMAILS_FILE, "w") as f: json.dump(data, f)
    except Exception as e:
        print("Error saving email:", e)

def get_user_email(username):
    if os.path.exists(EMAILS_FILE):
        try:
            with open(EMAILS_FILE, "r") as f: data = json.load(f)
            return data.get(username.lower())
        except Exception: pass
    return None

def reset_matrix_password(username, new_password):
    try:
        hashed = ph.hash(new_password)
        conn = sqlite3.connect(CONDUIT_DB)
        cur = conn.cursor()
        key = f"@{username}:moonburst.net".encode("utf-8")
        cur.execute("UPDATE userid_password SET value = ? WHERE key = ?", (hashed.encode("utf-8"), key))
        conn.commit()
        conn.close()
        print(f"Matrix password reset for {username}")
        return True
    except Exception as e:
        print("Matrix password reset error:", e)
        return False

def get_audiobookshelf_token():
    try:
        if not os.path.exists(ABS_DB): return None
        conn = sqlite3.connect(ABS_DB)
        cur = conn.cursor()
        cur.execute("SELECT id, token FROM users WHERE type = 'root' LIMIT 1")
        row = cur.fetchone()
        if not row: conn.close(); return None
        user_id, token = row[0], row[1]
        if not token:
            token = "abs_portal_" + secrets.token_hex(24)
            cur.execute("UPDATE users SET token = ? WHERE id = ?;", (token, user_id))
            conn.commit()
        conn.close()
        return token
    except Exception: return None

def provision_audiobookshelf_user(username, password, email=""):
    abs_token = get_audiobookshelf_token()
    if not abs_token: return False
    try:
        abs_payload = json.dumps({
            "username": username,
            "password": password,
            "email": email,
            "type": "user",
            "isActive": True,
            "permissions": {"download": True, "update": False, "delete": False, "upload": False, "accessAllLibraries": True, "accessAllTags": True}
        }).encode("utf-8")
        abs_req = urllib.request.Request("http://127.0.0.1:8000/api/users", data=abs_payload, headers={"Content-Type": "application/json", "Authorization": "Bearer " + abs_token})
        urllib.request.urlopen(abs_req)
        return True
    except Exception: return False

def reset_audiobookshelf_password(username, new_password):
    abs_token = get_audiobookshelf_token()
    if not abs_token: return False
    try:
        conn = sqlite3.connect(ABS_DB)
        cur = conn.cursor()
        cur.execute("SELECT id FROM users WHERE LOWER(username) = LOWER(?)", (username,))
        row = cur.fetchone()
        conn.close()
        if not row: return False
        uid = row[0]
        abs_payload = json.dumps({"password": new_password}).encode("utf-8")
        abs_req = urllib.request.Request(f"http://127.0.0.1:8000/api/users/{uid}", data=abs_payload, headers={"Content-Type": "application/json", "Authorization": "Bearer " + abs_token}, method="PATCH")
        urllib.request.urlopen(abs_req)
        print(f"Audiobookshelf password reset for {username}")
        return True
    except Exception as e:
        print("Audiobookshelf password reset error:", e)
        return False

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Portal - Moon Burst Hub</title>
  <style>
    *, *::before, *::after { box-sizing: border-box !important; }
    body {
      font-family: system-ui, -apple-system, sans-serif;
      background-color: #0F0F0F;
      color: #F7F700;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }
    .card {
      background-color: #12131c;
      padding: 2.5rem;
      border-radius: 8px;
      box-shadow: 0 0 0 5px #003399;
      max-width: 440px;
      width: 100%;
      display: flex;
      flex-direction: column;
      gap: 1.25rem;
    }
    h1 { color: #F7F700; font-size: 1.8rem; font-weight: 800; margin: 0; text-align: center; }
    .subtitle { color: #FABD2F; font-size: 0.9rem; text-align: center; margin: 0; opacity: 0.85; }
    .tabs { display: flex; gap: 8px; border-bottom: 2px solid #003399; padding-bottom: 8px; margin-bottom: 8px; }
    .tab-btn {
      all: unset; cursor: pointer; padding: 6px 12px; font-size: 14px; font-weight: bold; color: #888; border-radius: 4px;
    }
    .tab-btn.active { color: #F7F700; background-color: #003399; }
    .field-group { display: flex; flex-direction: column; gap: 6px; }
    label { font-size: 14px; font-weight: bold; color: #F7F700; }
    input {
      all: unset; box-sizing: border-box; width: 100%; height: 48px; padding: 0 14px; border-radius: 8px;
      background-color: #0F0F0F; box-shadow: 0 0 0 5px #003399; color: #F7F700; font-size: 15px;
      transition: box-shadow 0.15s ease-in-out;
    }
    input:focus { box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75); }
    .btn {
      all: unset; box-sizing: border-box; display: flex; align-items: center; justify-content: center;
      background-color: #0F0F0F; color: #F7F700; box-shadow: 0 0 0 5px #003399; border-radius: 8px;
      padding: 14px 20px; font-size: 15px; font-weight: bold; cursor: pointer; text-align: center;
      margin-top: 6px; transition: box-shadow 0.15s ease-in-out, transform 0.15s ease-in-out; text-decoration: none;
    }
    .btn:hover, .btn:focus { box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75); transform: scale(1.01); }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
    .secondary-link { color: #FABD2F; text-align: center; font-size: 13px; text-decoration: none; margin-top: 4px; display: inline-block; cursor: pointer; }
    .secondary-link:hover { text-decoration: underline; color: #F7F700; }
    .msg-box { display: none; padding: 12px; border-radius: 6px; font-size: 14px; font-weight: bold; text-align: center; word-break: break-word; }
    .error-box { background-color: #3b1111; color: #f87171; border: 1px solid #f87171; }
    .success-box { background-color: #0d2b16; color: #4ade80; border: 1px solid #4ade80; }
  </style>
</head>
<body>
  <div class="card">
    <div>
      <h1>Moon Burst</h1>
      <p id="page-subtitle" class="subtitle">Account Portal</p>
    </div>

    <div class="tabs">
      <button type="button" id="tab-reg" class="tab-btn active" onclick="switchTab('reg')">✨ Register / Sync</button>
      <button type="button" id="tab-rec" class="tab-btn" onclick="switchTab('rec')">🔑 Forgot Password</button>
    </div>

    <div id="error-box" class="msg-box error-box"></div>
    <div id="success-box" class="msg-box success-box"></div>

    <!-- REGISTRATION FORM -->
    <form id="reg-form" onsubmit="handleRegister(event)" style="display: flex; flex-direction: column; gap: 14px;">
      <div class="field-group">
        <label for="username">Desired Username</label>
        <input type="text" id="username" placeholder="e.g. alice" required autocomplete="username" />
      </div>

      <div class="field-group">
        <label for="password">Password</label>
        <input type="password" id="password" placeholder="••••••••••••" required autocomplete="new-password" />
      </div>

      <div class="field-group">
        <label for="email">Recovery Email <span style="font-size:12px; font-weight:normal; opacity:0.8;">(optional, for password resets)</span></label>
        <input type="email" id="email" placeholder="alice@gmail.com" autocomplete="email" />
      </div>

      <div class="field-group">
        <label for="invite-token">Invite Code</label>
        <input type="password" id="invite-token" placeholder="Enter registration secret..." required />
      </div>

      <button type="submit" id="submit-btn" class="btn">✨ Create / Sync Account</button>
      
      <div style="text-align: center; margin-top: 6px;">
        <a href="https://matrix.moonburst.net" class="secondary-link">Already have an account? Log in here →</a>
      </div>
    </form>

    <!-- RECOVERY STEP 1: REQUEST CODE -->
    <form id="rec-req-form" onsubmit="handleRequestCode(event)" style="display: none; flex-direction: column; gap: 14px;">
      <div class="field-group">
        <label for="rec-username">Your Matrix Username</label>
        <input type="text" id="rec-username" placeholder="e.g. alice" required />
      </div>
      <button type="submit" id="rec-send-btn" class="btn">📧 Send Recovery Code</button>
      <div style="text-align: center; margin-top: 6px;">
        <a onclick="switchTab('reg')" class="secondary-link">Back to registration</a>
      </div>
    </form>

    <!-- RECOVERY STEP 2: ENTER CODE & NEW PASSWORD -->
    <form id="rec-verify-form" onsubmit="handleVerifyReset(event)" style="display: none; flex-direction: column; gap: 14px;">
      <div class="field-group">
        <label for="rec-code">6-Digit Code (Sent to your email)</label>
        <input type="text" id="rec-code" placeholder="123456" required />
      </div>
      <div class="field-group">
        <label for="rec-new-password">New Password</label>
        <input type="password" id="rec-new-password" placeholder="••••••••••••" required />
      </div>
      <button type="submit" id="rec-submit-btn" class="btn">🔒 Reset Password</button>
    </form>

    <div id="success-actions" style="display: none; flex-direction: column; gap: 12px;">
      <a href="https://matrix.moonburst.net" class="btn">🚀 Open Matrix Chat (Sable)</a>
      <a href="https://audiobooks.moonburst.net" class="btn">🎧 Open Audiobookshelf</a>
    </div>
  </div>

  <script>
    let activeRecoveryUser = "";

    function switchTab(tab) {
      document.getElementById("error-box").style.display = "none";
      document.getElementById("success-box").style.display = "none";
      document.getElementById("success-actions").style.display = "none";

      if (tab === 'reg') {
        document.getElementById("tab-reg").classList.add("active");
        document.getElementById("tab-rec").classList.remove("active");
        document.getElementById("reg-form").style.display = "flex";
        document.getElementById("rec-req-form").style.display = "none";
        document.getElementById("rec-verify-form").style.display = "none";
        document.getElementById("page-subtitle").textContent = "Matrix Chat & Audiobooks Registration";
      } else {
        document.getElementById("tab-rec").classList.add("active");
        document.getElementById("tab-reg").classList.remove("active");
        document.getElementById("reg-form").style.display = "none";
        document.getElementById("rec-req-form").style.display = "flex";
        document.getElementById("rec-verify-form").style.display = "none";
        document.getElementById("page-subtitle").textContent = "Reset Account Password";
      }
    }

    if (window.location.search.includes("tab=recovery")) {
      switchTab("rec");
    }

    async function handleRegister(e) {
      e.preventDefault();
      const errBox = document.getElementById("error-box");
      const succBox = document.getElementById("success-box");
      const btn = document.getElementById("submit-btn");
      errBox.style.display = "none"; succBox.style.display = "none";

      let username = document.getElementById("username").value.trim().toLowerCase();
      if (username.startsWith("@")) username = username.substring(1);
      if (username.includes(":")) username = username.split(":")[0];
      const password = document.getElementById("password").value;
      const email = document.getElementById("email").value.trim();
      const token = document.getElementById("invite-token").value.trim();

      if (!username || !password || !token) {
        errBox.textContent = "Please fill in all fields.";
        errBox.style.display = "block";
        return;
      }

      btn.disabled = true; btn.textContent = "Setting up accounts...";
      try {
        const endpoint = window.location.pathname.startsWith("/register") ? "/register/api" : "/api/register";
        const res = await fetch(endpoint, {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ username, password, email, token })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          document.getElementById("reg-form").style.display = "none";
          succBox.innerHTML = "🎉 Account <strong>" + data.user_id + "</strong> ready for Matrix & Audiobooks!";
          succBox.style.display = "block";
          document.getElementById("success-actions").style.display = "flex";
        } else {
          errBox.textContent = data.error || "Registration failed. Check your token.";
          errBox.style.display = "block";
          btn.disabled = false; btn.textContent = "✨ Create / Sync Account";
        }
      } catch (err) {
        errBox.textContent = "Network error connecting to registration service.";
        errBox.style.display = "block";
        btn.disabled = false; btn.textContent = "✨ Create / Sync Account";
      }
    }

    async function handleRequestCode(e) {
      e.preventDefault();
      const errBox = document.getElementById("error-box");
      const succBox = document.getElementById("success-box");
      const btn = document.getElementById("rec-send-btn");
      errBox.style.display = "none"; succBox.style.display = "none";

      let username = document.getElementById("rec-username").value.trim().toLowerCase();
      if (username.startsWith("@")) username = username.substring(1);
      if (username.includes(":")) username = username.split(":")[0];
      activeRecoveryUser = username;

      btn.disabled = true; btn.textContent = "Sending code...";
      try {
        const res = await fetch("/api/recovery/request", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ username })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          document.getElementById("rec-req-form").style.display = "none";
          document.getElementById("rec-verify-form").style.display = "flex";
          succBox.textContent = data.message || "Recovery code sent to your registered email!";
          succBox.style.display = "block";
        } else {
          errBox.textContent = data.error || "Could not find registered email for this user.";
          errBox.style.display = "block";
          btn.disabled = false; btn.textContent = "📧 Send Recovery Code";
        }
      } catch (err) {
        errBox.textContent = "Network error connecting to server.";
        errBox.style.display = "block";
        btn.disabled = false; btn.textContent = "📧 Send Recovery Code";
      }
    }

    async function handleVerifyReset(e) {
      e.preventDefault();
      const errBox = document.getElementById("error-box");
      const succBox = document.getElementById("success-box");
      const btn = document.getElementById("rec-submit-btn");
      errBox.style.display = "none"; succBox.style.display = "none";

      const code = document.getElementById("rec-code").value.trim();
      const new_password = document.getElementById("rec-new-password").value;

      btn.disabled = true; btn.textContent = "Resetting password...";
      try {
        const res = await fetch("/api/recovery/verify", {
          method: "POST", headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ username: activeRecoveryUser, code, new_password })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          document.getElementById("rec-verify-form").style.display = "none";
          succBox.innerHTML = "✅ Password reset successfully! You can now log into Matrix and Audiobooks.";
          succBox.style.display = "block";
          document.getElementById("success-actions").style.display = "flex";
        } else {
          errBox.textContent = data.error || "Invalid or expired code.";
          errBox.style.display = "block";
          btn.disabled = false; btn.textContent = "🔒 Reset Password";
        }
      } catch (err) {
        errBox.textContent = "Network error connecting to server.";
        errBox.style.display = "block";
        btn.disabled = false; btn.textContent = "🔒 Reset Password";
      }
    }
  </script>
</body>
</html>
"""

class RegisterHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/register"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0))
        post_body = self.rfile.read(content_len).decode("utf-8")
        req_data = json.loads(post_body) if post_body else {}

        # 1. Recovery: Request Code
        if self.path.endswith("/recovery/request"):
            username = req_data.get("username", "").strip().lower()
            email = get_user_email(username)
            if not email:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": f"No recovery email on file for '{username}'. Please ask the admin."}).encode())
                return
            
            code = f"{secrets.randbelow(900000) + 100000}"
            RECOVERY_CODES[username] = { "code": code, "expires": time.time() + 900, "email": email }
            
            sent = send_recovery_email(email, username, code)
            if sent:
                masked_email = email[:2] + "****@" + email.split("@")[-1]
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True, "message": f"Verification code sent to {masked_email}!"}).encode())
            else:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": "Failed to send email via SMTP server."}).encode())
            return

        # 2. Recovery: Verify Code & Update Password
        if self.path.endswith("/recovery/verify"):
            username = req_data.get("username", "").strip().lower()
            code = req_data.get("code", "").strip()
            new_password = req_data.get("new_password", "")
            
            record = RECOVERY_CODES.get(username)
            if not record or record["code"] != code or time.time() > record["expires"]:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": "Invalid or expired recovery code."}).encode())
                return
            
            reset_matrix_password(username, new_password)
            reset_audiobookshelf_password(username, new_password)
            del RECOVERY_CODES[username]

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True}).encode())
            return

        # 3. Standard Registration / Sync
        try:
            username = req_data.get("username", "").strip()
            if username.startswith("@"): username = username[1:]
            if ":" in username: username = username.split(":")[0]
            password = req_data.get("password", "")
            email = req_data.get("email", "").strip()
            token = req_data.get("token", "").strip()

            matrix_payload = json.dumps({
                "username": username, "password": password,
                "auth": { "type": "m.login.registration_token", "token": token }
            }).encode("utf-8")

            req = urllib.request.Request("http://127.0.0.1:6167/_matrix/client/v3/register", data=matrix_payload, headers={"Content-Type": "application/json"})
            user_id = "@" + username + ":moonburst.net"
            try:
                with urllib.request.urlopen(req) as resp:
                    resp_data = json.loads(resp.read().decode("utf-8"))
                    user_id = resp_data.get("user_id", user_id)
            except urllib.error.HTTPError as m_err:
                err_data = json.loads(m_err.read().decode("utf-8"))
                if err_data.get("errcode") == "M_USER_IN_USE":
                    pass
                else:
                    raise m_err

            if email:
                save_user_email(username, email)

            provision_audiobookshelf_user(username, password, email)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "user_id": user_id}).encode("utf-8"))

        except urllib.error.HTTPError as e:
            try:
                err_json = json.loads(e.read().decode("utf-8"))
                err_msg = err_json.get("error", "Registration rejected by Matrix homeserver.")
            except Exception:
                err_msg = f"Homeserver error: {e.code}"

            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": err_msg}).encode("utf-8"))

        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": str(e)}).encode("utf-8"))

if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", ${toString registerPort}), RegisterHandler)
    server.serve_forever()
'';
in
{
  # Explicitly grant continuwuity user access to the Gmail secrets
  sops.secrets."gmail_address" = {
    mode = lib.mkForce "0444";
  };
  sops.secrets."gmail_app_password" = {
    mode = lib.mkForce "0444";
  };

  systemd.services.matrix-registration-portal = {
    description = "Invite-Only Matrix and Audiobooks Web Registration & Recovery Portal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "continuwuity.service" "audiobookshelf.service" "sops-install-secrets.service" ];
    serviceConfig = {
      ExecStart = "${serverScript}/bin/matrix-register-server";
      Restart = "always";
      RestartSec = 3;
      User = "continuwuity";
      SupplementaryGroups = [ "audiobookshelf" ];
      ReadWritePaths = [ "/var/lib/continuwuity" "/var/lib/audiobookshelf" ];
    };
  };

  services.nginx.virtualHosts."register.moonburst.net" = {
    listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString registerPort}";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."moonburst.net".locations."~* ^/(register|api)" = {
    proxyPass = "http://127.0.0.1:${toString registerPort}";
    proxyWebsockets = true;
  };
}
