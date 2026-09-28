{ config, pkgs, lib, ... }:

let
  registerPort = 8089;
  absTokenFile = "/var/lib/audiobookshelf-token";

  serverScript = pkgs.writeScriptBin "matrix-register-server" ''#!${pkgs.python3}/bin/python3
import os
import json
import urllib.request
import urllib.error
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Register - Moon Burst Hub</title>
  <style>
    *, *::before, *::after {
      box-sizing: border-box !important;
    }
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
    h1 {
      color: #F7F700;
      font-size: 1.8rem;
      font-weight: 800;
      margin: 0;
      text-align: center;
    }
    .subtitle {
      color: #FABD2F;
      font-size: 0.9rem;
      text-align: center;
      margin: 0;
      opacity: 0.85;
    }
    .field-group {
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    label {
      font-size: 14px;
      font-weight: bold;
      color: #F7F700;
    }
    input {
      all: unset;
      box-sizing: border-box;
      width: 100%;
      height: 48px;
      padding: 0 14px;
      border-radius: 8px;
      background-color: #0F0F0F;
      box-shadow: 0 0 0 5px #003399;
      color: #F7F700;
      font-size: 15px;
      transition: box-shadow 0.15s ease-in-out;
    }
    input:focus {
      box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75);
    }
    .btn {
      all: unset;
      box-sizing: border-box;
      display: flex;
      align-items: center;
      justify-content: center;
      background-color: #0F0F0F;
      color: #F7F700;
      box-shadow: 0 0 0 5px #003399;
      border-radius: 8px;
      padding: 14px 20px;
      font-size: 15px;
      font-weight: bold;
      cursor: pointer;
      text-align: center;
      margin-top: 6px;
      transition: box-shadow 0.15s ease-in-out, transform 0.15s ease-in-out;
      text-decoration: none;
    }
    .btn:hover, .btn:focus {
      box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75);
      transform: scale(1.01);
    }
    .btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
      transform: none;
    }
    .secondary-link {
      color: #FABD2F;
      text-align: center;
      font-size: 13px;
      text-decoration: none;
      margin-top: 4px;
      display: inline-block;
      cursor: pointer;
    }
    .secondary-link:hover {
      text-decoration: underline;
      color: #F7F700;
    }
    .msg-box {
      display: none;
      padding: 12px;
      border-radius: 6px;
      font-size: 14px;
      font-weight: bold;
      text-align: center;
      word-break: break-word;
    }
    .error-box {
      background-color: #3b1111;
      color: #f87171;
      border: 1px solid #f87171;
    }
    .success-box {
      background-color: #0d2b16;
      color: #4ade80;
      border: 1px solid #4ade80;
    }
  </style>
</head>
<body>
  <div class="card">
    <div>
      <h1>Moon Burst</h1>
      <p class="subtitle">Matrix Chat & Audiobooks Registration</p>
    </div>

    <div id="error-box" class="msg-box error-box"></div>
    <div id="success-box" class="msg-box success-box"></div>

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
        <label for="invite-token">Invite Code</label>
        <input type="password" id="invite-token" placeholder="Enter registration secret..." required />
      </div>

      <button type="submit" id="submit-btn" class="btn">✨ Create Account</button>
      
      <div style="text-align: center; margin-top: 6px;">
        <a href="https://matrix.moonburst.net" class="secondary-link">Already have an account? Log in here →</a>
      </div>
    </form>

    <div id="success-actions" style="display: none; flex-direction: column; gap: 12px;">
      <a href="https://matrix.moonburst.net" class="btn">🚀 Open Matrix Chat (Sable)</a>
      <a href="https://audiobooks.moonburst.net" class="btn">🎧 Open Audiobookshelf</a>
    </div>
  </div>

  <script>
    async function handleRegister(e) {
      e.preventDefault();
      const errBox = document.getElementById("error-box");
      const succBox = document.getElementById("success-box");
      const btn = document.getElementById("submit-btn");
      const form = document.getElementById("reg-form");
      const actions = document.getElementById("success-actions");

      errBox.style.display = "none";
      succBox.style.display = "none";

      let username = document.getElementById("username").value.trim().toLowerCase();
      if (username.startsWith("@")) username = username.substring(1);
      if (username.includes(":")) username = username.split(":")[0];

      const password = document.getElementById("password").value;
      const token = document.getElementById("invite-token").value.trim();

      if (!username || !password || !token) {
        errBox.textContent = "Please fill in all fields.";
        errBox.style.display = "block";
        return;
      }

      btn.disabled = true;
      btn.textContent = "Creating accounts...";

      try {
        const res = await fetch("/api/register", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ username, password, token })
        });
        const data = await res.json();

        if (res.ok && data.success) {
          form.style.display = "none";
          succBox.innerHTML = "🎉 Account <strong>" + data.user_id + "</strong> ready for Matrix & Audiobooks!";
          succBox.style.display = "block";
          actions.style.display = "flex";
        } else {
          errBox.textContent = data.error || "Registration failed. Please check your token.";
          errBox.style.display = "block";
          btn.disabled = false;
          btn.textContent = "✨ Create Account";
        }
      } catch (err) {
        errBox.textContent = "Network error connecting to registration service.";
        errBox.style.display = "block";
        btn.disabled = false;
        btn.textContent = "✨ Create Account";
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
        if self.path != "/api/register":
            self.send_response(404)
            self.end_headers()
            return

        content_len = int(self.headers.get("Content-Length", 0))
        post_body = self.rfile.read(content_len).decode("utf-8")

        try:
            req_data = json.loads(post_body)
            username = req_data.get("username", "").strip()
            if username.startswith("@"):
                username = username[1:]
            if ":" in username:
                username = username.split(":")[0]

            password = req_data.get("password", "")
            token = req_data.get("token", "").strip()

            # 1. Create Matrix Account
            matrix_payload = json.dumps({
                "username": username,
                "password": password,
                "auth": {
                    "type": "m.login.registration_token",
                    "token": token
                }
            }).encode("utf-8")

            req = urllib.request.Request(
                "http://127.0.0.1:6167/_matrix/client/v3/register",
                data=matrix_payload,
                headers={"Content-Type": "application/json"}
            )

            with urllib.request.urlopen(req) as resp:
                resp_data = json.loads(resp.read().decode("utf-8"))
                user_id = resp_data.get("user_id", "@" + username + ":moonburst.net")

            # 2. Automatically Create Matching Audiobookshelf Account
            abs_token = None
            if os.path.exists("${absTokenFile}"):
                try:
                    with open("${absTokenFile}", "r") as f:
                        abs_token = f.read().strip()
                except Exception:
                    pass

            if abs_token:
                try:
                    abs_payload = json.dumps({
                        "username": username,
                        "password": password,
                        "type": "user",
                        "isActive": True,
                        "permissions": {
                            "download": True,
                            "update": False,
                            "delete": False,
                            "upload": False,
                            "accessAllLibraries": True,
                            "accessAllTags": True
                        }
                    }).encode("utf-8")

                    abs_req = urllib.request.Request(
                        "http://127.0.0.1:8000/api/users",
                        data=abs_payload,
                        headers={
                            "Content-Type": "application/json",
                            "Authorization": "Bearer " + abs_token
                        }
                    )
                    urllib.request.urlopen(abs_req)
                except Exception as abs_err:
                    pass  # User already exists or non-fatal

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "user_id": user_id}).encode("utf-8"))

        except urllib.error.HTTPError as e:
            try:
                err_json = json.loads(e.read().decode("utf-8"))
                err_msg = err_json.get("error", "Registration rejected by Matrix homeserver.")
            except Exception:
                err_msg = "Homeserver returned error code " + str(e.code)

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
  systemd.services.matrix-registration-portal = {
    description = "Invite-Only Matrix and Audiobooks Web Registration Portal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "continuwuity.service" "audiobookshelf.service" ];
    serviceConfig = {
      ExecStart = "${serverScript}/bin/matrix-register-server";
      Restart = "always";
      RestartSec = 3;
      DynamicUser = true;
    };
  };

  services.nginx.virtualHosts."register.moonburst.net" = {
    listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString registerPort}";
      proxyWebsockets = true;
    };
  };

  services.nginx.virtualHosts."moonburst.net".locations."/register" = {
    proxyPass = "http://127.0.0.1:${toString registerPort}";
    proxyWebsockets = true;
  };
}
