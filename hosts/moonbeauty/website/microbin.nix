{ config, pkgs, lib, ... }:

let
  shareDomain = "share.moonburst.net";

  # Storage Daemon: Native 7z AES-256 Encrypted Zip (Same password for web & zip)
  chunkUploaderScript = pkgs.writeText "microbin-chunk-uploader.py" ''
import os
import sys
import shutil
import subprocess
import hashlib
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

DATA_DIR = "/mnt/3TBHDD/microbin-storage"
UPLOAD_TMP_DIR = "/mnt/3TBHDD/microbin-tmp"
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(UPLOAD_TMP_DIR, exist_ok=True)

def hash_pw(pw, salt):
    return hashlib.sha256((pw + salt).encode()).hexdigest()

class StorageHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        path = self.path

        if path == "/upload-chunk":
            upload_id = self.headers.get("X-Upload-ID")
            chunk_index = int(self.headers.get("X-Chunk-Index", 0))

            if not upload_id:
                self.send_error(400, "Missing X-Upload-ID")
                return

            session_dir = os.path.join(UPLOAD_TMP_DIR, upload_id)
            os.makedirs(session_dir, exist_ok=True)

            chunk_file = os.path.join(session_dir, f"chunk_{chunk_index:05d}")
            chunk_data = self.rfile.read(content_length)
            with open(chunk_file, "wb") as f:
                f.write(chunk_data)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "chunk_received", "index": chunk_index}).encode())

        elif path == "/assemble-chunk":
            body = self.rfile.read(content_length).decode()
            meta = json.loads(body)
            upload_id = meta.get("upload_id")
            filename = meta.get("filename", "archive.zip")
            password = meta.get("password", "").strip()
            files_manifest = meta.get("files", [])

            session_dir = os.path.join(UPLOAD_TMP_DIR, upload_id)
            if not os.path.exists(session_dir):
                self.send_error(404, "Upload session not found")
                return

            temp_raw_file = os.path.join(session_dir, "raw_stream.bin")
            chunk_files = sorted([f for f in os.listdir(session_dir) if f.startswith("chunk_")])
            with open(temp_raw_file, "wb") as outfile:
                for cf in chunk_files:
                    part_path = os.path.join(session_dir, cf)
                    with open(part_path, "rb") as infile:
                        shutil.copyfileobj(infile, outfile)
                    os.remove(part_path)

            staging_dir = os.path.join(session_dir, "staging")
            os.makedirs(staging_dir, exist_ok=True)

            if len(files_manifest) <= 1:
                real_name = files_manifest[0] if files_manifest else filename
                target_inside = os.path.join(staging_dir, real_name)
                shutil.move(temp_raw_file, target_inside)
            else:
                subprocess.run(["${pkgs.p7zip}/bin/7z", "x", temp_raw_file, f"-o{staging_dir}", "-y"], check=False)
                if os.path.exists(temp_raw_file):
                    os.remove(temp_raw_file)

            share_id = os.urandom(8).hex()
            file_dest_dir = os.path.join(DATA_DIR, share_id)
            os.makedirs(file_dest_dir, exist_ok=True)

            final_filename = filename if filename.endswith(".zip") else filename + ".zip"
            final_file_path = os.path.join(file_dest_dir, final_filename)

            # Build standard AES-256 encrypted zip using 7z
            cmd = ["${pkgs.p7zip}/bin/7z", "a", "-tzip", final_file_path, os.path.join(staging_dir, "*"), "-y"]
            if password:
                cmd.append(f"-p{password}")
                cmd.append("-mem=AES256") # Universal standard AES-256 zip encryption
            subprocess.run(cmd, check=True)

            salt = os.urandom(16).hex()
            metadata = {
                "filename": final_filename,
                "size": os.path.getsize(final_file_path),
                "has_password": bool(password),
                "password_hash": hash_pw(password, salt) if password else None,
                "salt": salt if password else None
            }

            with open(os.path.join(file_dest_dir, "meta.json"), "w") as mf:
                json.dump(metadata, mf)

            shutil.rmtree(session_dir, ignore_errors=True)

            download_url = f"https://${shareDomain}/d/{share_id}"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "complete", "url": download_url}).encode())

        elif path.startswith("/api/verify-download/"):
            share_id = path.split("/")[-1]
            file_dest_dir = os.path.join(DATA_DIR, share_id)
            meta_path = os.path.join(file_dest_dir, "meta.json")

            if not os.path.exists(meta_path):
                self.send_error(404, "File not found")
                return

            with open(meta_path, "r") as mf:
                meta = json.load(mf)

            body = self.rfile.read(content_length).decode()
            req_data = json.loads(body) if body else {}
            provided_pw = req_data.get("password", "").strip()

            if meta.get("has_password"):
                expected_hash = meta.get("password_hash")
                salt = meta.get("salt")
                if hash_pw(provided_pw, salt) != expected_hash:
                    self.send_response(401)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": "Incorrect password. Please try again."}).encode())
                    return

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        else:
            self.send_error(404)

    def do_GET(self):
        path = self.path

        if path.startswith("/download-file/"):
            parts = path.split("/")
            share_id = parts[2]
            file_dest_dir = os.path.join(DATA_DIR, share_id)
            meta_path = os.path.join(file_dest_dir, "meta.json")

            if not os.path.exists(meta_path):
                self.send_error(404, "File not found")
                return

            with open(meta_path, "r") as mf:
                meta = json.load(mf)

            filename = meta["filename"]
            filepath = os.path.join(file_dest_dir, filename)

            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Content-Length", str(os.path.getsize(filepath)))
            self.end_headers()

            with open(filepath, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
            return

        if path.startswith("/d/"):
            share_id = path.split("/")[2]
            file_dest_dir = os.path.join(DATA_DIR, share_id)
            meta_path = os.path.join(file_dest_dir, "meta.json")

            if not os.path.exists(meta_path):
                self.send_error(404, "Download link expired or not found.")
                return

            with open(meta_path, "r") as mf:
                meta = json.load(mf)

            filename = meta["filename"]
            size_mb = f"{meta['size'] / (1024 * 1024):.1f} MB"
            has_pw = meta["has_password"]
            enc_tag = "(Password Protected .zip)" if has_pw else ""
            input_html = "<input type=\"password\" id=\"pw\" class=\"pw-input\" placeholder=\"Enter password to unlock and download...\" />" if has_pw else ""
            icon = "🔒" if has_pw else "📁"

            html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Download {filename}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {{
      background-color: #0F0F0F;
      color: #F7F700;
      font-family: system-ui, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
    }}
    .card {{
      background-color: #12131c;
      border: 2px solid #003399;
      border-radius: 12px;
      padding: 32px;
      max-width: 480px;
      width: 90%;
      text-align: center;
      box-shadow: 0 10px 30px rgba(0,0,0,0.8);
    }}
    .filename {{
      font-size: 20px;
      font-weight: bold;
      color: #FABD2F;
      word-break: break-all;
      margin-bottom: 8px;
    }}
    .size {{
      font-size: 14px;
      color: #888;
      margin-bottom: 24px;
    }}
    .pw-input {{
      width: 100%;
      height: 48px;
      padding: 10px 14px;
      border-radius: 8px;
      background-color: #0F0F0F;
      border: 1px solid #003399;
      color: #F7F700;
      font-size: 16px;
      box-sizing: border-box;
      margin-bottom: 16px;
    }}
    .download-btn {{
      background-color: #04f100;
      color: #000;
      border: none;
      padding: 14px 28px;
      border-radius: 8px;
      font-size: 16px;
      font-weight: bold;
      cursor: pointer;
      width: 100%;
      transition: all 0.15s ease-in-out;
    }}
    .download-btn:hover {{
      background-color: #02c000;
      transform: scale(1.01);
    }}
    .error-msg {{
      color: #ff4444;
      font-size: 14px;
      font-weight: bold;
      margin-bottom: 16px;
      display: none;
    }}
  </style>
</head>
<body>
  <div class="card">
    <div style="font-size: 40px; margin-bottom: 12px;">{icon}</div>
    <div class="filename">{filename}</div>
    <div class="size">Size: {size_mb} {enc_tag}</div>
    <div id="error" class="error-msg">❌ Incorrect password. Please try again.</div>
    {input_html}
    <button type="button" id="dl-btn" class="download-btn" onclick="requestDownload()">⬇️ Download File</button>
  </div>

  <script>
    async function requestDownload() {{
      const errorEl = document.getElementById("error");
      const btn = document.getElementById("dl-btn");
      errorEl.style.display = "none";
      const pwInput = document.getElementById("pw");
      const password = pwInput ? pwInput.value.trim() : "";

      if ("{has_pw}" === "True") {{
        btn.disabled = true;
        btn.textContent = "Verifying password...";

        const verifyRes = await fetch("/api/verify-download/{share_id}", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{ password: password }})
        }});

        if (!verifyRes.ok) {{
          errorEl.style.display = "block";
          btn.disabled = false;
          btn.textContent = "⬇️ Download File";
          if (pwInput) {{ pwInput.value = ""; pwInput.focus(); }}
          return;
        }}
      }}

      // Downloads the actual AES-256 encrypted zip file
      window.location.href = "/download-file/{share_id}";
      btn.disabled = false;
      btn.textContent = "Downloading...";
      setTimeout(function() {{ btn.textContent = "⬇️ Download File"; }}, 3000);
    }}

    const pwInput = document.getElementById("pw");
    if (pwInput) {{
      pwInput.addEventListener("keydown", function(e) {{
        if (e.key === "Enter") requestDownload();
      }});
    }}
  </script>
</body>
</html>"""
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(html.encode())
        else:
            self.send_error(404)

server = HTTPServer(("127.0.0.1", 8087), StorageHandler)
server.serve_forever()
  '';

  customCss = pkgs.writeText "custom-microbin.css" ''
    body, main, #main, form, #pasta-form {
      max-width: 980px !important;
      width: 100% !important;
      margin: 0 auto !important;
      display: flex !important;
      flex-direction: column !important;
      gap: 1.25rem !important;
    }

    header, nav, .header, .navbar, .logo, a.logo, a[href="/"], a[href*="upload"], .nav-links {
      display: none !important;
    }

    footer, .footer, div:has(> a[href*="microbin.eu"]), p:has(> a[href*="microbin.eu"]), small:has(> a[href*="microbin.eu"]) {
      display: none !important;
    }

    a[href*="/list"], a[href*="/guide"], a[href$="/list"], a[href$="/guide"] {
      display: none !important;
      visibility: hidden !important;
      pointer-events: none !important;
    }

    #content-input, textarea, #file, #attach-file-button, label[for="file"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
      border: none !important;
    }

    .form-row-duo {
      display: flex !important;
      flex-direction: row !important;
      gap: 24px !important;
      width: 100% !important;
    }

    .form-col {
      flex: 1 !important;
      display: flex !important;
      flex-direction: column !important;
      min-width: 0 !important;
    }

    .field-label {
      font-weight: bold !important;
      margin-bottom: 6px !important;
      display: block !important;
      color: #F7F700 !important;
      font-size: 15px !important;
    }

    .sub-label {
      font-weight: normal !important;
      font-size: 12px !important;
      opacity: 0.8 !important;
      color: #FABD2F !important;
    }

    .form-col input, .form-col select {
      width: 100% !important;
      height: 48px !important;
      padding: 10px 14px !important;
      border-radius: 8px !important;
      background-color: #0F0F0F !important;
      border: 1px solid #003399 !important;
      color: #F7F700 !important;
      font-size: 15px !important;
      box-sizing: border-box !important;
    }

    .file-drop-area {
      border: 2px dashed #003399 !important;
      border-radius: 8px !important;
      padding: 24px !important;
      text-align: center !important;
      background-color: #0d0e15 !important;
      cursor: pointer !important;
      transition: all 0.2s ease-in-out !important;
    }

    .file-drop-area.dragover {
      border-color: #04f100 !important;
      background-color: #16201a !important;
    }

    .file-select-btn {
      background-color: #003399 !important;
      color: #F7F700 !important;
      border: 1.5px solid #F7F700 !important;
      padding: 10px 20px !important;
      border-radius: 6px !important;
      cursor: pointer !important;
      font-weight: bold !important;
      font-size: 16px !important;
      display: inline-block !important;
      margin-top: 8px !important;
      transition: all 0.15s ease-in-out !important;
    }

    .file-select-btn:hover {
      background-color: #04f100 !important;
      color: #000 !important;
      border-color: #04f100 !important;
    }

    .action-btn-main {
      background-color: #04f100 !important;
      color: #000000 !important;
      border: none !important;
      padding: 14px 24px !important;
      border-radius: 8px !important;
      font-weight: bold !important;
      font-size: 16px !important;
      cursor: pointer !important;
      margin-top: 12px !important;
      transition: all 0.15s ease-in-out !important;
      width: 100% !important;
      box-sizing: border-box !important;
      display: block !important;
      text-align: center !important;
    }

    .action-btn-main:hover {
      background-color: #02c000 !important;
      transform: scale(1.005) !important;
    }

    .zip-name-box {
      width: 100% !important;
      height: 44px !important;
      padding: 8px 12px !important;
      border-radius: 6px !important;
      background-color: #0F0F0F !important;
      border: 1px solid #3f3f46 !important;
      color: #F7F700 !important;
      box-sizing: border-box !important;
    }

    .modal-overlay {
      display: none;
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: rgba(0, 0, 0, 0.82);
      z-index: 99999;
      justify-content: center;
      align-items: center;
      backdrop-filter: blur(4px);
    }

    .modal-card {
      background-color: #12131c;
      border: 2px solid #FABD2F;
      border-radius: 12px;
      padding: 24px;
      width: 90%;
      max-width: 520px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.8);
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .modal-title {
      font-size: 18px;
      font-weight: bold;
      color: #FABD2F;
    }

    .modal-input {
      width: 100%;
      height: 44px;
      padding: 10px 14px;
      border-radius: 6px;
      background-color: #0a0a0f;
      border: 1px solid #003399;
      color: #F7F700;
      font-size: 15px;
      box-sizing: border-box;
    }

    .modal-btn-row {
      display: flex;
      gap: 12px;
      justify-content: flex-end;
    }

    .modal-submit-btn {
      background-color: #003399;
      color: #F7F700;
      border: 1.5px solid #F7F700;
      padding: 10px 18px;
      border-radius: 6px;
      font-weight: bold;
      cursor: pointer;
      font-size: 14px;
    }

    .modal-submit-btn:hover {
      background-color: #04f100;
      color: #000;
      border-color: #04f100;
    }

    .modal-cancel-btn {
      background-color: #222;
      color: #bbb;
      border: 1px solid #444;
      padding: 10px 16px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 14px;
    }

    .history-card {
      background-color: #10111a !important;
      border: 1px solid #003399 !important;
      border-radius: 8px !important;
      padding: 16px 20px !important;
      margin-top: 25px !important;
    }

    .history-title {
      font-size: 16px !important;
      font-weight: bold !important;
      color: #FABD2F !important;
      margin-bottom: 12px !important;
      display: flex !important;
      justify-content: space-between !important;
      align-items: center !important;
    }

    .history-table {
      width: 100% !important;
      border-collapse: collapse !important;
    }

    .history-table th {
      text-align: left !important;
      color: #F7F700 !important;
      padding: 8px 10px !important;
      border-bottom: 1px solid #003399 !important;
      font-size: 13px !important;
    }

    .history-table td {
      padding: 10px !important;
      border-bottom: 1px solid #1a1b26 !important;
      font-size: 14px !important;
      color: #eee !important;
    }

    .history-link {
      color: #04f100 !important;
      font-weight: bold !important;
      text-decoration: underline !important;
    }

    .copy-link-btn {
      background-color: #003399 !important;
      color: #F7F700 !important;
      border: none !important;
      border-radius: 4px !important;
      padding: 4px 8px !important;
      cursor: pointer !important;
      font-size: 12px !important;
      margin-left: 8px !important;
    }

    @media (max-width: 700px) {
      .form-row-duo {
        flex-direction: column !important;
        gap: 12px !important;
      }
    }
  '';

  customJs = pkgs.writeText "custom-microbin.js" ''
    let isApproved = false;
    let activeFiles = [];
    const CHUNK_SIZE = 20 * 1024 * 1024;

    function recordLocalUpload(item) {
      var history = JSON.parse(localStorage.getItem("my_microbin_uploads") || "[]");
      history.unshift(item);
      if (history.length > 20) history.pop();
      localStorage.setItem("my_microbin_uploads", JSON.stringify(history));
    }

    window.copyUrlToClipboard = function(btn, url) {
      navigator.clipboard.writeText(url).then(function() {
        var original = btn.innerText;
        btn.innerText = "Copied!";
        setTimeout(function() { btn.innerText = original; }, 1500);
      });
    };

    function cleanupHeaderAndFooter() {
      document.querySelectorAll("header, nav, .header, .navbar, .logo, a.logo, a[href='/'], a[href*='/list'], a[href*='/guide']").forEach(function(el) {
        el.remove();
      });
      document.querySelectorAll("footer, .footer").forEach(function(el) {
        el.remove();
      });
      document.querySelectorAll("p, div, small, span").forEach(function(el) {
        if (el.textContent && el.textContent.includes("MicroBin by Dániel Szabó")) {
          el.remove();
        }
      });
    }

    document.addEventListener("DOMContentLoaded", function() {
      cleanupHeaderAndFooter();

      var form = document.getElementById("pasta-form") || document.querySelector("form");
      var contentInput = document.getElementById("content-input");
      var fileInput = document.getElementById("file");
      var expSelect = document.getElementById("expiration") || document.querySelector("select[name=\"expiration\"]");
      var privSelect = document.getElementById("privacy") || document.querySelector("select[name=\"privacy\"]");
      
      var encPass = document.getElementById("password") || document.getElementById("password_field") || document.querySelector("input[type=\"password\"]");
      if (!encPass) {
        encPass = document.createElement("input");
        encPass.type = "password";
        encPass.id = "custom-password-field";
      }

      if (!form) return;

      if (contentInput) {
        contentInput.style.display = "none";
        contentInput.removeAttribute("required");
        contentInput.value = "";
      }

      var oldSubmit = document.getElementById("submit-button") || document.querySelector("button[type=\"submit\"]");
      if (oldSubmit) oldSubmit.style.display = "none";

      var allNativeLabels = form.querySelectorAll("label[for='file'], #attach-file-button");
      allNativeLabels.forEach(function(el) { el.style.display = "none"; });

      if (expSelect) {
        expSelect.innerHTML = 
          '<option value="1hour">1 Hour</option>' +
          '<option value="6hours">6 Hours</option>' +
          '<option value="24hours" selected>24 Hours (Default)</option>' +
          '<option value="1week">7 Days</option>';
      }

      if (privSelect) {
        privSelect.innerHTML = '<option value="private" selected>Private</option>';
      }

      var cleanContainer = document.createElement("div");
      cleanContainer.id = "custom-form-layout";

      // Row 1: Expiration Time & Password
      var row1 = document.createElement("div");
      row1.className = "form-row-duo";

      var colExp = document.createElement("div");
      colExp.className = "form-col";
      colExp.innerHTML = "<label class=\"field-label\">Expiration Time</label>";
      if (expSelect) colExp.appendChild(expSelect);

      var colEnc = document.createElement("div");
      colEnc.className = "form-col";
      colEnc.innerHTML = "<label class=\"field-label\">🔒 Password Protection <span class=\"sub-label\">(optional, AES-256 zip encryption. Using this will require a password to unzip) </span></label>";
      encPass.placeholder = "Leave blank for no password...";
      colEnc.appendChild(encPass);

      row1.appendChild(colExp);
      row1.appendChild(colEnc);
      cleanContainer.appendChild(row1);

      // Row 2: Dedicated File Drop & Upload Area
      var rowFile = document.createElement("div");
      rowFile.className = "form-col";
      rowFile.innerHTML = `
        <label class="field-label">📁 File Upload <span class="sub-label">(drag & drop or browse)</span></label>
        <div id="drop-zone" class="file-drop-area">
          <div id="file-status-text" style="color: #FABD2F; font-size: 15px; margin-bottom: 8px;">
            Drag files here or click to select
          </div>
          <button type="button" id="browse-btn" class="file-select-btn">Choose File(s)</button>
        </div>
        <div id="zip-name-container" style="display: none; margin-top: 10px;">
          <label class="field-label">📦 Archive Name <span class="sub-label">(what the zip will be called)</span></label>
          <input type="text" id="zip-name-input" class="zip-name-box" placeholder="e.g. project-assets, photos-vacation" />
        </div>
      `;
      cleanContainer.appendChild(rowFile);

      var child = form.firstElementChild;
      while (child) {
        var next = child.nextElementSibling;
        if (child !== cleanContainer) {
          child.style.display = "none";
        }
        child = next;
      }

      form.appendChild(cleanContainer);

      if (fileInput) {
        fileInput.setAttribute("multiple", "multiple");
        fileInput.style.display = "none";
      }

      var mainActionBtn = document.createElement("button");
      mainActionBtn.type = "button";
      mainActionBtn.id = "main-action-button";
      mainActionBtn.className = "action-btn-main";
      mainActionBtn.textContent = "🚀 Send / Upload";
      form.appendChild(mainActionBtn);

      var historyBox = document.createElement("div");
      historyBox.id = "user-history-box";
      historyBox.className = "history-card";
      historyBox.innerHTML = `
        <div class="history-title">
          <span>📁 Your Recent Uploads <span style="font-size:12px; opacity:0.8; font-weight:normal;">(Stored locally on your browser only)</span></span>
          <button type="button" id="clear-history-btn" style="background:none; border:none; color:#f87171; cursor:pointer; font-size:12px;">Clear History</button>
        </div>
        <div id="history-content"></div>
      `;
      form.parentNode.appendChild(historyBox);

      function renderLocalHistory() {
        var history = JSON.parse(localStorage.getItem("my_microbin_uploads") || "[]");
        var container = document.getElementById("history-content");
        if (!container) return;

        if (history.length === 0) {
          container.innerHTML = "<div style=\"color:#777; font-size:13px; font-style:italic;\">No recent uploads from this browser.</div>";
          return;
        }

        var html = "<table class=\"history-table\"><thead><tr><th>Name / File</th><th>Size</th><th>Created</th><th>Direct Link</th></tr></thead><tbody>";
        history.forEach(function(item) {
          html += "<tr>" +
            "<td><strong>" + item.name + "</strong></td>" +
            "<td>" + item.size + "</td>" +
            "<td>" + item.date + "</td>" +
            "<td><a href=\"" + item.url + "\" class=\"history-link\" target=\"_blank\">Open Link</a>" +
            "<button type=\"button\" class=\"copy-link-btn\" onclick=\"window.copyUrlToClipboard(this, '" + item.url + "')\">Copy</button></td>" +
            "</tr>";
        });
        html += "</tbody></table>";
        container.innerHTML = html;
      }

      renderLocalHistory();

      var clearBtn = document.getElementById("clear-history-btn");
      if (clearBtn) {
        clearBtn.addEventListener("click", function() {
          localStorage.removeItem("my_microbin_uploads");
          renderLocalHistory();
        });
      }

      var modalOverlay = document.createElement("div");
      modalOverlay.id = "approval-modal";
      modalOverlay.className = "modal-overlay";
      modalOverlay.innerHTML = `
        <div class="modal-card">
          <div class="modal-title">⚠️ Large Upload Approval Required</div>
          <div style="color: #FABD2F; font-size: 14px; line-height: 1.4;">
            Your upload exceeds the 50 MB limit. Moonburst needs to approve it to unlock up to 10 GB.
          </div>
          <input type="text" id="popup-reason-input" class="modal-input" placeholder="Who are you / what is this file for?..." />
          <div id="modal-status-text" style="color: #04f100; font-size: 14px; display: none;"></div>
          <div class="modal-btn-row">
            <button type="button" id="modal-cancel-btn" class="modal-cancel-btn">Cancel</button>
            <button type="button" id="modal-confirm-btn" class="modal-submit-btn">Request Approval</button>
          </div>
        </div>
      `;
      document.body.appendChild(modalOverlay);

      var dropZone = document.getElementById("drop-zone");
      var browseBtn = document.getElementById("browse-btn");
      var fileStatusText = document.getElementById("file-status-text");
      var zipContainer = document.getElementById("zip-name-container");

      var popupReason = document.getElementById("popup-reason-input");
      var modalStatus = document.getElementById("modal-status-text");
      var modalConfirmBtn = document.getElementById("modal-confirm-btn");
      var modalCancelBtn = document.getElementById("modal-cancel-btn");

      modalCancelBtn.addEventListener("click", function() {
        modalOverlay.style.display = "none";
      });

      if (browseBtn && fileInput) {
        browseBtn.addEventListener("click", function(e) {
          e.preventDefault();
          fileInput.click();
        });
      }

      function updateFileStats(files) {
        activeFiles = Array.from(files);
        var totalBytes = 0;
        activeFiles.forEach(function(f) { totalBytes += f.size; });
        var mb = (totalBytes / (1024 * 1024)).toFixed(1);

        if (activeFiles.length === 1) {
          fileStatusText.innerHTML = "Attached: <strong>" + activeFiles[0].name + "</strong> (" + mb + " MB)";
          zipContainer.style.display = "none";
        } else if (activeFiles.length > 1) {
          fileStatusText.innerHTML = "Attached: <strong>" + activeFiles.length + " files</strong> (" + mb + " MB total) [Auto-Zipping]";
          zipContainer.style.display = "block";
        } else {
          fileStatusText.innerText = "Drag files here or click to select";
          zipContainer.style.display = "none";
        }
      }

      if (fileInput) {
        fileInput.addEventListener("change", function() {
          if (fileInput.files) updateFileStats(fileInput.files);
        });
      }

      ["dragenter", "dragover"].forEach(function(eventName) {
        window.addEventListener(eventName, function(e) { e.preventDefault(); }, false);
        if (dropZone) {
          dropZone.addEventListener(eventName, function(e) {
            e.preventDefault();
            dropZone.classList.add("dragover");
          }, false);
        }
      });

      ["dragleave", "drop"].forEach(function(eventName) {
        window.addEventListener(eventName, function(e) { e.preventDefault(); }, false);
        if (dropZone) {
          dropZone.addEventListener(eventName, function(e) {
            e.preventDefault();
            dropZone.classList.remove("dragover");
          }, false);
        }
      });

      if (dropZone) {
        dropZone.addEventListener("drop", function(e) {
          if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
            e.preventDefault();
            fileInput.files = e.dataTransfer.files;
            updateFileStats(e.dataTransfer.files);
          }
        });
      }

      async function uploadFileChunked(fileBlob, filename, displayName, displaySize, manifest, password) {
        mainActionBtn.disabled = true;
        var uploadId = "up_" + Date.now() + "_" + Math.random().toString(36).substr(2, 9);
        var totalChunks = Math.ceil(fileBlob.size / CHUNK_SIZE);

        for (var i = 0; i < totalChunks; i++) {
          var start = i * CHUNK_SIZE;
          var end = Math.min(start + CHUNK_SIZE, fileBlob.size);
          var chunk = fileBlob.slice(start, end);

          var pct = Math.round(((i + 1) / totalChunks) * 100);
          mainActionBtn.textContent = "Uploading " + pct + "% (Part " + (i + 1) + "/" + totalChunks + ")...";

          var res = await fetch("/upload-chunk", {
            method: "POST",
            headers: {
              "X-Upload-ID": uploadId,
              "X-Chunk-Index": i.toString(),
              "X-Total-Chunks": totalChunks.toString(),
              "Content-Type": "application/octet-stream"
            },
            body: chunk
          });

          if (!res.ok) {
            alert("Chunk " + (i + 1) + " upload failed.");
            mainActionBtn.disabled = false;
            mainActionBtn.textContent = "🚀 Send / Upload";
            return;
          }
        }

        mainActionBtn.textContent = password ? "Encrypting with AES-256 on server..." : "Finalizing upload on server...";

        var exp = expSelect ? expSelect.value : "24hours";

        var finishRes = await fetch("/assemble-chunk", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            upload_id: uploadId,
            filename: filename,
            password: password,
            files: manifest
          })
        });

        if (finishRes.ok) {
          var data = await finishRes.json();
          recordLocalUpload({
            name: displayName,
            size: displaySize,
            date: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
            url: data.url
          });
          window.location.href = data.url;
        } else {
          alert("Finalizing upload failed on server.");
          mainActionBtn.disabled = false;
          mainActionBtn.textContent = "🚀 Send / Upload";
        }
      }

      window.triggerFinalUpload = async function() {
        if (!activeFiles || activeFiles.length === 0) {
          alert("Please select a file to upload first!");
          return;
        }

        var zipNameInput = document.getElementById("zip-name-input");
        var customZipName = (zipNameInput && zipNameInput.value.trim()) ? zipNameInput.value.trim() : "archive";
        if (!customZipName.toLowerCase().endsWith(".zip")) {
          customZipName += ".zip";
        }
        
        var totalBytes = 0;
        activeFiles.forEach(function(f) { totalBytes += f.size; });
        var displaySize = (totalBytes / (1024 * 1024)).toFixed(1) + " MB";
        var pwd = (encPass && encPass.value.trim()) ? encPass.value.trim() : "";
        var displayName = activeFiles.length > 1 ? customZipName : (activeFiles[0].name.replace(/\.[^/.]+$/, "") + ".zip");
        if (pwd) {
          displayName += " 🔒";
        }

        mainActionBtn.disabled = true;
        mainActionBtn.textContent = "Packaging...";

        if (activeFiles.length > 1) {
          var zip = new JSZip();
          activeFiles.forEach(function(f) { zip.file(f.name, f); });
          var manifest = activeFiles.map(function(f) { return f.name; });

          var rawZipBlob = await zip.generateAsync({ type: "blob", compression: "STORE" });
          uploadFileChunked(rawZipBlob, customZipName, displayName, displaySize, manifest, pwd);
        } else {
          var manifest = [activeFiles[0].name];
          uploadFileChunked(activeFiles[0], displayName.replace(" 🔒", ""), displayName, displaySize, manifest, pwd);
        }
      };

      function startApprovalProcess() {
        var reason = popupReason ? popupReason.value.trim() : "";
        if (!reason) {
          alert("Please enter who you are or the reason for the file!");
          if (popupReason) popupReason.focus();
          return;
        }

        var totalBytes = 0;
        activeFiles.forEach(function(f) { totalBytes += f.size; });
        var f = activeFiles[0];
        var fname = activeFiles.length === 1 ? f.name : (activeFiles.length + " files (ZIP)");
        var mb = (totalBytes / (1024 * 1024)).toFixed(1) + " MB";
        var exp = expSelect ? expSelect.options[expSelect.selectedIndex].text : "24 Hours";

        modalConfirmBtn.disabled = true;
        modalCancelBtn.style.display = "none";
        modalStatus.style.display = "block";
        modalStatus.style.color = "#FABD2F";
        modalStatus.innerText = "⏳ Waiting for Moonburst's approval on desktop...";

        fetch("/request-approval", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ filename: fname, size: mb, reason: reason, expiry: exp })
        })
        .then(r => r.json())
        .then(data => {
          var reqId = data.request_id;
          var poll = setInterval(function() {
            fetch("/check-approval?id=" + reqId)
            .then(r => r.json())
            .then(res => {
              if (res.status === "approved") {
                clearInterval(poll);
                isApproved = true;
                modalStatus.style.color = "#04f100";
                modalStatus.innerText = "✅ Approved! Starting upload now...";
                setTimeout(function() {
                  modalOverlay.style.display = "none";
                  window.triggerFinalUpload();
                }, 800);
              } else if (res.status === "denied") {
                clearInterval(poll);
                modalConfirmBtn.disabled = false;
                modalCancelBtn.style.display = "inline-block";
                modalStatus.style.color = "#ff4444";
                modalStatus.innerText = "❌ Request Denied by Moonburst";
              }
            });
          }, 2000);
        })
        .catch(function() {
          alert("Approval daemon is unreachable.");
          modalConfirmBtn.disabled = false;
          modalCancelBtn.style.display = "inline-block";
          modalStatus.style.display = "none";
        });
      }

      modalConfirmBtn.addEventListener("click", startApprovalProcess);

      mainActionBtn.addEventListener("click", function(e) {
        e.preventDefault();
        var totalBytes = 0;
        activeFiles.forEach(function(f) { totalBytes += f.size; });

        if (totalBytes > 50 * 1024 * 1024 && !isApproved) {
          modalOverlay.style.display = "flex";
          if (popupReason) popupReason.focus();
        } else {
          window.triggerFinalUpload();
        }
      });

      form.onsubmit = function(e) {
        e.preventDefault();
        mainActionBtn.click();
      };
    });
  '';
in
{
  systemd.services.microbin-chunk-uploader = {
    description = "Microbin Storage & AES-256 Zip Daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "microbin.service" ];
    path = [ pkgs.p7zip ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${chunkUploaderScript}";
      Restart = "always";
      RestartSec = "3s";
    };
  };

  services.microbin = {
    enable = true;
    settings = {
      MICROBIN_PORT = "8086";
      MICROBIN_BIND = "0.0.0.0";
      MICROBIN_PUBLIC_PATH = "https://${shareDomain}/";
      MICROBIN_DEFAULT_EXPIRY = "24hours";
      MICROBIN_ENABLE_FILE_UPLOADS = "true";
      MICROBIN_ENCRYPTION_SERVER_SIDE = "false";
      MICROBIN_ENCRYPTION_CLIENT_SIDE = "false";
      MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB = "10240";
      MICROBIN_MAX_FILE_SIZE_ENCRYPTED_MB = "10240";
      MICROBIN_QR = "true";
      MICROBIN_HIGHLIGHT_SYNTAX = "true";
      MICROBIN_HIDE_PASTA_LIST = "true";
      MICROBIN_HIDE_FOOTER = "true";
      MICROBIN_HIDE_HEADER = "true";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."${shareDomain}" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
      extraConfig = ''
        client_max_body_size 10240M;
        proxy_read_timeout 1800s;
        proxy_send_timeout 1800s;
        proxy_hide_header Content-Security-Policy;
        sub_filter_once on;
        sub_filter '</head>' '<link rel="stylesheet" href="/custom-microbin.css?v=800"><script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script><script src="/custom-microbin.js?v=800"></script></head>';
      '';

      locations."= /list" = {
        return = "404";
      };

      locations."= /custom-microbin.css" = {
        alias = "${customCss}";
        extraConfig = "default_type text/css;";
      };

      locations."= /custom-microbin.js" = {
        alias = "${customJs}";
        extraConfig = "default_type application/javascript;";
      };

      locations."= /request-approval" = {
        proxyPass = "http://127.0.0.1:8088/request-approval";
        extraConfig = "proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;";
      };

      locations."= /check-approval" = {
        proxyPass = "http://127.0.0.1:8088/check-approval";
      };

      locations."~ ^/(upload-chunk|assemble-chunk|d/|download-file/|api/)" = {
        proxyPass = "http://127.0.0.1:8087";
        extraConfig = ''
          proxy_request_buffering off;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };

      locations."= /upload" = {
        proxyPass = "http://127.0.0.1:8086/upload";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_request_buffering off;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:8086";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_request_buffering off;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Accept-Encoding "";
        '';
      };
    };
  };
}
