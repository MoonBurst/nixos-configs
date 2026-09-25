{ config, pkgs, lib, ... }:

let
  # =====================================================================
  # GLOBAL DECLARATIVE THEME & SETTINGS VARIABLES
  # =====================================================================
  shareDomain       = "share.moonburst.net";
  storageDir        = "/mnt/3TBHDD/microbin-storage";
  tmpDir            = "/mnt/3TBHDD/microbin-tmp";

  accentBlue        = "#003399";
  accentYellow      = "#F7F700";
  accentGold        = "#FABD2F";
  darkBg            = "#0F0F0F";
  cardBg            = "#12131c";
  dangerRed         = "#f87171";

  # Border & Hover Variables (12px test)
  borderThickness   = "5px";
  borderRadius      = "8px";
  baseBorderColor   = accentBlue;
  hoverBorderColor  = accentYellow;

  hoverGlow         = "0 0 25px 6px rgba(247, 247, 0, 0.75)";
  # =====================================================================

  chunkUploaderScript = pkgs.writeText "microbin-chunk-uploader.py" ''
import os
import sys
import time
import shutil
import subprocess
import threading
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

DATA_DIR = "${storageDir}"
UPLOAD_TMP_DIR = "${tmpDir}"
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(UPLOAD_TMP_DIR, exist_ok=True)

EXPIRY_MAP = {
    "1hour": 3600,
    "6hours": 21600,
    "24hours": 86400,
    "1week": 604800
}

def expiry_cleaner_loop():
    while True:
        try:
            now = time.time()
            if os.path.exists(DATA_DIR):
                for sid in os.listdir(DATA_DIR):
                    sdir = os.path.join(DATA_DIR, sid)
                    if not os.path.isdir(sdir):
                        continue
                    mpath = os.path.join(sdir, "meta.json")
                    ttl = 86400
                    ctime = os.path.getmtime(sdir)
                    if os.path.exists(mpath):
                        try:
                            with open(mpath, "r") as mf:
                                m = json.load(mf)
                            ctime = m.get("created_at", os.path.getmtime(mpath))
                            exp_str = m.get("expiry", "24hours")
                            ttl = EXPIRY_MAP.get(exp_str, 86400)
                        except Exception:
                            pass
                    if now - ctime >= ttl:
                        shutil.rmtree(sdir, ignore_errors=True)

            if os.path.exists(UPLOAD_TMP_DIR):
                for tid in os.listdir(UPLOAD_TMP_DIR):
                    tdir = os.path.join(UPLOAD_TMP_DIR, tid)
                    if os.path.isdir(tdir) and now - os.path.getmtime(tdir) > 14400:
                        shutil.rmtree(tdir, ignore_errors=True)
        except Exception:
            pass
        time.sleep(30)

threading.Thread(target=expiry_cleaner_loop, daemon=True).start()

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
            is_encrypted = meta.get("is_encrypted", False)
            auth_hash = meta.get("auth_hash", "")
            salt = meta.get("salt", "")
            expiry = meta.get("expiry", "24hours")
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

            share_id = os.urandom(8).hex()
            file_dest_dir = os.path.join(DATA_DIR, share_id)
            os.makedirs(file_dest_dir, exist_ok=True)

            final_filename = filename if filename.endswith(".zip") else filename + ".zip"
            final_file_path = os.path.join(file_dest_dir, final_filename)

            if is_encrypted:
                shutil.move(temp_raw_file, final_file_path)
            else:
                staging_dir = os.path.join(session_dir, "staging")
                os.makedirs(staging_dir, exist_ok=True)
                if len(files_manifest) > 1:
                    subprocess.run(["${pkgs.p7zip}/bin/7z", "x", temp_raw_file, f"-o{staging_dir}", "-y"], check=False)
                    if os.path.exists(temp_raw_file):
                        os.remove(temp_raw_file)
                    cmd = ["${pkgs.p7zip}/bin/7z", "a", "-tzip", final_file_path, os.path.join(staging_dir, "*"), "-y"]
                    subprocess.run(cmd, check=True)
                else:
                    real_name = files_manifest[0] if files_manifest else filename
                    target_inside = os.path.join(staging_dir, real_name)
                    shutil.move(temp_raw_file, target_inside)
                    cmd = ["${pkgs.p7zip}/bin/7z", "a", "-tzip", final_file_path, target_inside, "-y"]
                    subprocess.run(cmd, check=True)

            metadata = {
                "filename": final_filename,
                "size": os.path.getsize(final_file_path),
                "is_encrypted": is_encrypted,
                "auth_hash": auth_hash if is_encrypted else None,
                "salt": salt if is_encrypted else None,
                "created_at": time.time(),
                "expiry": expiry
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
            provided_hash = req_data.get("auth_hash", "")

            if meta.get("is_encrypted"):
                if provided_hash != meta.get("auth_hash"):
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
            self.send_header("Content-Type", "application/octet-stream")
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
            is_encrypted = meta["is_encrypted"]
            salt = meta.get("salt", "")
            enc_tag = "(Zero-Knowledge E2EE)" if is_encrypted else ""
            input_html = "<input type=\"password\" id=\"pw\" class=\"pw-input\" placeholder=\"Enter password to decrypt and download...\" />" if is_encrypted else ""
            icon = "🔒" if is_encrypted else "📁"

            html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Download {filename}</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    *, *::before, *::after {{
      box-sizing: border-box !important;
    }}
    body {{
      background-color: ${darkBg};
      color: ${accentYellow};
      font-family: system-ui, sans-serif;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      gap: 16px;
    }}
    .card {{
      background-color: ${cardBg};
      box-shadow: 0 0 0 ${borderThickness} ${baseBorderColor} !important;
      border-radius: ${borderRadius} !important;
      padding: 32px;
      max-width: 480px;
      width: 90%;
      text-align: center;
      display: flex;
      flex-direction: column;
      gap: 14px;
      border: none !important;
    }}
    .filename {{
      font-size: 20px;
      font-weight: bold;
      color: ${accentGold};
      word-break: break-all;
    }}
    .size {{
      font-size: 14px;
      color: #888;
      margin-bottom: 4px;
    }}
    .pw-input {{
      all: unset !important;
      box-sizing: border-box !important;
      width: 100%;
      height: 60px;
      padding: 10px 16px;
      border-radius: ${borderRadius} !important;
      background-color: ${darkBg} !important;
      box-shadow: 0 0 0 ${borderThickness} ${baseBorderColor} !important;
      color: ${accentYellow};
      font-size: 15px;
      outline: none;
      transition: box-shadow 0.15s ease-in-out;
    }}
    .pw-input:hover, .pw-input:focus {{
      box-shadow: 0 0 0 ${borderThickness} ${hoverBorderColor}, ${hoverGlow} !important;
    }}
    .download-btn, .back-btn {{
      all: unset !important;
      box-sizing: border-box !important;
      background-color: ${darkBg} !important;
      color: ${accentYellow} !important;
      box-shadow: 0 0 0 ${borderThickness} ${baseBorderColor} !important;
      border-radius: ${borderRadius} !important;
      padding: 14px 24px;
      font-size: 15px;
      font-weight: bold;
      cursor: pointer;
      display: block;
      text-align: center;
      width: 100%;
      outline: none;
      transition: box-shadow 0.15s ease-in-out;
    }}
    .download-btn:hover, .download-btn:focus,
    .back-btn:hover, .back-btn:focus {{
      box-shadow: 0 0 0 ${borderThickness} ${hoverBorderColor}, ${hoverGlow} !important;
      color: ${accentYellow} !important;
      transform: scale(1.01);
    }}
    .error-msg {{
      color: ${dangerRed};
      font-size: 14px;
      font-weight: bold;
      display: none;
    }}
  </style>
</head>
<body>
  <div class="card">
    <div style="font-size: 40px;">{icon}</div>
    <div class="filename">{filename}</div>
    <div class="size">Size: {size_mb} {enc_tag}</div>
    <div id="error" class="error-msg">❌ Incorrect password. Please try again.</div>
    {input_html}
    <button type="button" id="dl-btn" class="download-btn" onclick="requestDownload()">⬇️ Download File</button>
    <button type="button" class="back-btn" onclick="window.location.href='/'">⬅️ Upload Another File</button>
  </div>

  <script>
    async function computeHash(password, salt) {{
      const enc = new TextEncoder();
      const data = enc.encode(password + salt);
      const hashBuffer = await crypto.subtle.digest("SHA-256", data);
      return Array.from(new Uint8Array(hashBuffer)).map(function(b) {{ return b.toString(16).padStart(2, "0"); }}).join("");
    }}

    async function decryptZipBlob(encryptedBlob, password, saltStr) {{
      const buffer = await encryptedBlob.arrayBuffer();
      const iv = buffer.slice(0, 12);
      const data = buffer.slice(12);

      const enc = new TextEncoder();
      const keyMaterial = await crypto.subtle.importKey(
        "raw", enc.encode(password), {{ name: "PBKDF2" }}, false, ["deriveKey"]
      );

      const key = await crypto.subtle.deriveKey(
        {{
          name: "PBKDF2",
          salt: enc.encode(saltStr),
          iterations: 100000,
          hash: "SHA-256"
        }},
        keyMaterial,
        {{ name: "AES-GCM", length: 256 }},
        false,
        ["decrypt"]
      );

      const decrypted = await crypto.subtle.decrypt(
        {{ name: "AES-GCM", iv: iv }},
        key,
        data
      );

      return new Blob([decrypted], {{ type: "application/zip" }});
    }}

    async function requestDownload() {{
      const errorEl = document.getElementById("error");
      const btn = document.getElementById("dl-btn");
      errorEl.style.display = "none";
      const pwInput = document.getElementById("pw");
      const password = pwInput ? pwInput.value.trim() : "";

      if ("{is_encrypted}" === "True") {{
        btn.disabled = true;
        btn.textContent = "Verifying password...";
        const authHash = await computeHash(password, "{salt}");

        const verifyRes = await fetch("/api/verify-download/{share_id}", {{
          method: "POST",
          headers: {{ "Content-Type": "application/json" }},
          body: JSON.stringify({{ auth_hash: authHash }})
        }});

        if (!verifyRes.ok) {{
          errorEl.style.display = "block";
          btn.disabled = false;
          btn.textContent = "⬇️ Download File";
          if (pwInput) {{ pwInput.value = ""; pwInput.focus(); }}
          return;
        }}

        btn.textContent = "Decrypting locally (E2EE)...";
        const fileRes = await fetch("/download-file/{share_id}");
        const encryptedBlob = await fileRes.blob();

        try {{
          const decryptedBlob = await decryptZipBlob(encryptedBlob, password, "{salt}");
          const url = URL.createObjectURL(decryptedBlob);
          const a = document.createElement("a");
          a.href = url;
          a.download = "{filename}";
          document.body.appendChild(a);
          a.click();
          a.remove();
          btn.disabled = false;
          btn.textContent = "Complete!";
          setTimeout(function() {{ btn.textContent = "⬇️ Download File"; }}, 3000);
        }} catch(err) {{
          errorEl.textContent = "Decryption error: Failed to decrypt payload.";
          errorEl.style.display = "block";
          btn.disabled = false;
          btn.textContent = "⬇️ Download File";
        }}
      }} else {{
        window.location.href = "/download-file/{share_id}";
      }}
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
    *, *::before, *::after {
      box-sizing: border-box !important;
    }

    /* PRE-RENDER CLOAK */
    #pasta-form, form {
      opacity: 0;
      visibility: hidden;
      transition: opacity 0.15s ease-in-out;
    }

    body, main, #main, form, #pasta-form {
      max-width: 980px !important;
      width: 100% !important;
      margin: 0 auto !important;
      display: flex !important;
      flex-direction: column !important;
      gap: 1.5rem !important;
    }

    header, nav, .header, .navbar, .logo, a.logo, a[href="/"], a[href*="upload"], .nav-links,
    footer, .footer, a[href*="/list"], a[href*="/guide"], a[href$="/list"], a[href$="/guide"] {
      display: none !important;
      visibility: hidden !important;
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
      align-items: flex-end !important;
    }

    .form-col {
      flex: 1 !important;
      display: flex !important;
      flex-direction: column !important;
      min-width: 0 !important;
    }

    .field-header-box {
      height: 46px !important;
      display: flex !important;
      flex-direction: column !important;
      justify-content: flex-end !important;
      margin-bottom: 8px !important;
    }

    .field-label {
      font-weight: bold !important;
      color: ${accentYellow} !important;
      font-size: 15px !important;
      line-height: 1.2 !important;
      margin: 0 !important;
    }

    .sub-label {
      font-weight: normal !important;
      font-size: 12px !important;
      opacity: 0.85 !important;
      color: ${accentGold} !important;
      margin-top: 4px !important;
      line-height: 1.2 !important;
    }

    /* ====================================================================
       ALL: UNSET & BORDER SHIFT (BYPASSES LINUX GTK WIDGET ENGINE COMPLETELY)
       ==================================================================== */
    button,
    select,
    input,
    .file-select-btn,
    .action-btn-main,
    .clear-history-btn,
    .history-open-btn,
    .copy-link-btn,
    .zip-name-box,
    .modal-input,
    .modal-submit-btn,
    .modal-cancel-btn {
      all: unset !important;
      box-sizing: border-box !important;
      font-family: system-ui, sans-serif !important;
      border: none !important;
    }

    /* ====================================================================
       UNIVERSAL BASE BORDER (USES BOX-SHADOW TO GUARANTEE 12PX IN ALL BROWSERS)
       ==================================================================== */
    .history-card,
    .file-select-btn,
    .action-btn-main,
    .clear-history-btn,
    .history-open-btn,
    .copy-link-btn,
    .zip-name-box,
    .modal-card,
    .modal-input,
    .modal-submit-btn,
    .modal-cancel-btn,
    button,
    select,
    input {
      box-shadow: 0 0 0 ${borderThickness} ${baseBorderColor} !important;
      border-radius: ${borderRadius} !important;
      outline: none !important;
      border: none !important;
      background-color: ${darkBg} !important;
      color: ${accentYellow} !important;
      transition: box-shadow 0.15s ease-in-out !important;
    }

    /* Select Dropdown */
    select, #expiration, .form-col select {
      display: block !important;
      cursor: pointer !important;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%23F7F700' stroke-width='2'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E") !important;
      background-repeat: no-repeat !important;
      background-position: right 16px center !important;
      padding-right: 42px !important;
    }

    /* Form Fields */
    .form-col input, .form-col select {
      width: 100% !important;
      height: 60px !important;
      padding: 0 16px !important;
      display: block !important;
    }

    /* Buttons */
    .file-select-btn {
      padding: 10px 24px !important;
      font-weight: bold !important;
      font-size: 15px !important;
      cursor: pointer !important;
      display: inline-block !important;
      margin-top: 10px !important;
      text-align: center !important;
    }

    .action-btn-main {
      padding: 10px 24px !important;
      font-weight: bold !important;
      font-size: 16px !important;
      cursor: pointer !important;
      margin-top: 6px !important;
      width: 100% !important;
      height: 64px !important;
      display: block !important;
      text-align: center !important;
      line-height: 40px !important;
    }

    .action-btn-main:hover {
      transform: scale(1.005) !important;
    }

    .clear-history-btn {
      padding: 8px 18px !important;
      font-size: 13px !important;
      font-weight: bold !important;
      cursor: pointer !important;
      display: inline-block !important;
    }

    .history-open-btn,
    .copy-link-btn {
      padding: 0 18px !important;
      font-size: 13px !important;
      font-weight: bold !important;
      display: inline-flex !important;
      align-items: center !important;
      justify-content: center !important;
      height: 48px !important;
      margin: 0 !important;
      cursor: pointer !important;
    }

    /* ====================================================================
       UNIVERSAL HOVER & FOCUS (TURNS YELLOW AND GLOWS)
       ==================================================================== */
    .file-select-btn:hover, .file-select-btn:focus,
    .action-btn-main:hover, .action-btn-main:focus,
    .clear-history-btn:hover, .clear-history-btn:focus,
    .history-open-btn:hover, .history-open-btn:focus,
    .copy-link-btn:hover, .copy-link-btn:focus,
    .zip-name-box:hover, .zip-name-box:focus,
    .modal-input:hover, .modal-input:focus,
    .modal-submit-btn:hover, .modal-submit-btn:focus,
    .modal-cancel-btn:hover, .modal-cancel-btn:focus,
    button:hover, button:focus,
    select:hover, select:focus,
    input:hover, input:focus {
      box-shadow: 0 0 0 ${borderThickness} ${hoverBorderColor}, ${hoverGlow} !important;
    }

    /* Dotted Upload Box */
    .file-drop-area {
      border: ${borderThickness} dashed ${baseBorderColor} !important;
      border-radius: ${borderRadius} !important;
      padding: 28px !important;
      text-align: center !important;
      background-color: ${cardBg} !important;
      cursor: pointer !important;
      transition: border-color 0.2s ease-in-out, box-shadow 0.2s ease-in-out !important;
      box-sizing: border-box !important;
      box-shadow: none !important;
    }

    .file-drop-area:hover,
    .file-drop-area.dragover {
      border: ${borderThickness} dashed ${hoverBorderColor} !important;
      box-shadow: ${hoverGlow} !important;
    }

    .zip-name-box {
      width: 100% !important;
      height: 60px !important;
      padding: 0 16px !important;
      display: block !important;
    }

    .history-card {
      background-color: ${cardBg} !important;
      padding: 20px !important;
      margin-top: 10px !important;
      border: none !important;
    }

    .history-title {
      font-size: 16px !important;
      font-weight: bold !important;
      color: ${accentGold} !important;
      margin-bottom: 14px !important;
      display: flex !important;
      justify-content: space-between !important;
      align-items: center !important;
    }

    .history-table {
      width: 100% !important;
      border-collapse: separate !important;
      border-spacing: 0 !important;
    }

    .history-table th {
      text-align: left !important;
      color: ${accentYellow} !important;
      padding: 10px 12px !important;
      border-bottom: ${borderThickness} solid ${baseBorderColor} !important;
      font-size: 13px !important;
    }

    .history-table td {
      padding: 12px !important;
      border-bottom: 1px solid #1a1b26 !important;
      font-size: 14px !important;
      color: #eee !important;
      vertical-align: middle !important;
    }

    .action-btn-cell {
      display: inline-flex !important;
      flex-direction: row !important;
      gap: 12px !important;
      align-items: center !important;
      white-space: nowrap !important;
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
      background-color: ${cardBg};
      padding: 24px;
      width: 90%;
      max-width: 520px;
      display: flex;
      flex-direction: column;
      gap: 16px;
      border: none !important;
    }

    .modal-title {
      font-size: 18px;
      font-weight: bold;
      color: ${accentGold};
    }

    .modal-input {
      width: 100%;
      height: 60px;
      padding: 0 16px;
      background-color: #0a0a0f !important;
      font-size: 15px;
      display: block !important;
    }

    .modal-btn-row {
      display: flex;
      gap: 12px;
      justify-content: flex-end;
    }

    .modal-submit-btn {
      padding: 10px 20px !important;
      font-size: 14px;
      font-weight: bold;
      cursor: pointer !important;
      display: inline-block !important;
    }

    .modal-cancel-btn {
      background-color: #222 !important;
      color: #bbb !important;
      padding: 10px 18px !important;
      font-size: 14px;
      cursor: pointer !important;
      display: inline-block !important;
    }

    @media (max-width: 700px) {
      .form-row-duo {
        flex-direction: column !important;
        gap: 14px !important;
        align-items: stretch !important;
      }
      .field-header-box {
        height: auto !important;
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
      }
      encPass.id = "custom-password-field";
      encPass.setAttribute("autocomplete", "new-password");

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

      var row1 = document.createElement("div");
      row1.className = "form-row-duo";

      var colExp = document.createElement("div");
      colExp.className = "form-col";
      colExp.innerHTML = `
        <div class="field-header-box">
          <label class="field-label">Expiration Time</label>
        </div>
      `;
      if (expSelect) colExp.appendChild(expSelect);

      var colEnc = document.createElement("div");
      colEnc.className = "form-col";
      colEnc.innerHTML = `
        <div class="field-header-box">
          <label class="field-label">🔒 Password Protection</label>
          <span class="sub-label">(optional, zero-knowledge AES-256; required for recipient to decrypt and unzip)</span>
        </div>
      `;
      encPass.placeholder = "Leave blank for no password";
      colEnc.appendChild(encPass);

      row1.appendChild(colExp);
      row1.appendChild(colEnc);
      cleanContainer.appendChild(row1);

      var rowFile = document.createElement("div");
      rowFile.className = "form-col";
      rowFile.innerHTML = `
        <div class="field-header-box" style="height: auto; margin-bottom: 8px;">
          <label class="field-label">📁 File Upload</label>
          <span class="sub-label">(drag & drop or browse)</span>
        </div>
        <div id="drop-zone" class="file-drop-area">
          <div id="file-status-text" style="color: ${accentGold}; font-size: 15px; margin-bottom: 8px;">
            Drag files here or click to select
          </div>
          <button type="button" id="browse-btn" class="file-select-btn">Choose File(s)</button>
        </div>
        <div id="zip-name-container" style="display: none; margin-top: 12px;">
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
          <button type="button" id="clear-history-btn" class="clear-history-btn">Clear History</button>
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
            "<td><div class=\"action-btn-cell\">" +
            "<button type=\"button\" class=\"history-open-btn\" onclick=\"window.open('" + item.url + "', '_blank')\">Open Link</button>" +
            "<button type=\"button\" class=\"copy-link-btn\" onclick=\"window.copyUrlToClipboard(this, '" + item.url + "')\">Copy Link</button>" +
            "</div></td>" +
            "</tr>";
        });
        html += "</tbody></table>";
        container.innerHTML = html;
      }

      renderLocalHistory();

      form.style.setProperty("visibility", "visible", "important");
      form.style.setProperty("opacity", "1", "important");

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
          <div style="color: ${accentGold}; font-size: 14px; line-height: 1.4;">
            Your upload exceeds the 50 MB limit. Moonburst needs to approve it to unlock up to 10 GB.
          </div>
          <input type="text" id="popup-reason-input" class="modal-input" placeholder="Who are you / what is this file for?..." />
          <div id="modal-status-text" style="color: ${accentYellow}; font-size: 14px; display: none;"></div>
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

      async function uploadFileChunked(fileBlob, filename, displayName, displaySize, manifest, isEncrypted, authHash, salt) {
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

        mainActionBtn.textContent = isEncrypted ? "Saving E2EE encrypted blob on server..." : "Finalizing upload...";

        var exp = expSelect ? expSelect.value : "24hours";

        var finishRes = await fetch("/assemble-chunk", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            upload_id: uploadId,
            filename: filename,
            is_encrypted: isEncrypted,
            auth_hash: authHash,
            salt: salt,
            expiry: exp,
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

      async function encryptZipBlob(zipBlob, password, salt) {
        const enc = new TextEncoder();
        const rawBuffer = await zipBlob.arrayBuffer();

        const keyMaterial = await crypto.subtle.importKey(
          "raw", enc.encode(password), { name: "PBKDF2" }, false, ["deriveKey"]
        );

        const key = await crypto.subtle.deriveKey(
          {
            name: "PBKDF2",
            salt: enc.encode(salt),
            iterations: 100000,
            hash: "SHA-256"
          },
          keyMaterial,
          { name: "AES-GCM", length: 256 },
          false,
          ["encrypt"]
        );

        const iv = crypto.getRandomValues(new Uint8Array(12));
        const encryptedContent = await crypto.subtle.encrypt(
          { name: "AES-GCM", iv: iv },
          key,
          rawBuffer
        );

        const combined = new Uint8Array(iv.length + encryptedContent.byteLength);
        combined.set(iv, 0);
        combined.set(new Uint8Array(encryptedContent), iv.length);

        return new Blob([combined], { type: "application/octet-stream" });
      }

      async function computeHash(password, salt) {
        const enc = new TextEncoder();
        const data = enc.encode(password + salt);
        const hashBuffer = await crypto.subtle.digest("SHA-256", data);
        return Array.from(new Uint8Array(hashBuffer)).map(function(b) { return b.toString(16).padStart(2, "0"); }).join("");
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
        mainActionBtn.textContent = "Packaging archive...";

        var zip = new JSZip();
        activeFiles.forEach(function(f) { zip.file(f.name, f); });
        var manifest = activeFiles.map(function(f) { return f.name; });

        var rawZipBlob = await zip.generateAsync({ type: "blob", compression: "STORE" });

        if (pwd) {
          mainActionBtn.textContent = "Encrypting (Client-Side AES-256)...";
          var salt = Array.from(crypto.getRandomValues(new Uint8Array(16))).map(function(b) { return b.toString(16).padStart(2, "0"); }).join("");
          var authHash = await computeHash(pwd, salt);
          var encryptedBlob = await encryptZipBlob(rawZipBlob, pwd, salt);

          uploadFileChunked(encryptedBlob, displayName.replace(" 🔒", ""), displayName, displaySize, manifest, true, authHash, salt);
        } else {
          uploadFileChunked(rawZipBlob, displayName, displayName, displaySize, manifest, false, null, null);
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
        modalStatus.style.color = "${accentGold}";
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
                modalStatus.style.color = "${accentYellow}";
                modalStatus.innerText = "✅ Approved! Starting upload now...";
                setTimeout(function() {
                  modalOverlay.style.display = "none";
                  window.triggerFinalUpload();
                }, 800);
              } else if (res.status === "denied") {
                clearInterval(poll);
                modalConfirmBtn.disabled = false;
                modalCancelBtn.style.display = "inline-block";
                modalStatus.style.color = "${dangerRed}";
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
    description = "Microbin Zero-Knowledge Storage Daemon";
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
        sub_filter '</head>' '<link rel="stylesheet" href="/custom-microbin.css?v=20261027_universal_shadow"><script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script><script src="/custom-microbin.js?v=20261027_universal_shadow"></script></head>';
      '';

      locations."= /list" = {
        return = "404";
      };

      locations."~* /(static/)?water.*\.css" = {
        return = "200 \"\"";
        extraConfig = "default_type text/css;";
      };

      locations."= /custom-microbin.css" = {
        alias = "${customCss}";
        extraConfig = ''
          default_type text/css;
          add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        '';
      };

      locations."= /custom-microbin.js" = {
        alias = "${customJs}";
        extraConfig = ''
          default_type application/javascript;
          add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        '';
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
