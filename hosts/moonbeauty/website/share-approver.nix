{ config, pkgs, lib, ... }:

let
  approverScript = pkgs.writeScriptBin "share-approver" ''#!${pkgs.python3}/bin/python3
import os
import sys
import json
import time
import uuid
import threading
import subprocess
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

HOST = "127.0.0.1"
PORT = 8088

PENDING = {}
APPROVED_TOKENS = {}
LOCK = threading.Lock()

def cleanup_tokens():
    now = time.time()
    with LOCK:
        expired = [t for t, exp in APPROVED_TOKENS.items() if now > exp]
        for t in expired:
            del APPROVED_TOKENS[t]

def handle_desktop_notification(req_id, size_str, filename, reason_str, expiry_str, ip_str):
    summary = f"🔔 Large Upload Request ({size_str})"
    body = f"From: {reason_str}\nFile: {filename}\nRequested Expiration: {expiry_str}\nIP: {ip_str}\nAllow upload up to 10 GB?"
    
    cmd = [
        "${pkgs.libnotify}/bin/notify-send",
        "-a", "Share Drop",
        "-i", "folder-download",
        "-u", "critical",
        summary, body,
        "--action=approve=Approve",
        "--action=deny=Deny"
    ]
    
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        action = proc.stdout.strip()
        
        with LOCK:
            if action == "approve":
                token = str(uuid.uuid4())
                APPROVED_TOKENS[token] = time.time() + 86400
                PENDING[req_id] = {"status": "approved", "token": token}
            else:
                PENDING[req_id] = {"status": "denied"}
    except Exception:
        with LOCK:
            PENDING[req_id] = {"status": "timeout"}

class RequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_POST(self):
        cleanup_tokens()
        parsed = urlparse(self.path)
        
        if parsed.path == "/request-approval":
            length = int(self.headers.get("Content-Length", 0))
            raw_body = self.rfile.read(length).decode("utf-8")
            try:
                data = json.loads(raw_body)
            except Exception:
                data = {}

            size_str = data.get("size", "Unknown Size")
            filename = data.get("filename", "Unknown File")
            reason_str = data.get("reason", "No reason provided")
            expiry_str = data.get("expiry", "24 Hours")
            ip_str = self.headers.get("X-Forwarded-For", self.client_address[0]).split(",")[0].strip()

            req_id = str(uuid.uuid4())
            with LOCK:
                PENDING[req_id] = {"status": "pending"}

            t = threading.Thread(target=handle_desktop_notification, args=(req_id, size_str, filename, reason_str, expiry_str, ip_str))
            t.daemon = True
            t.start()

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"request_id": req_id}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        cleanup_tokens()
        parsed = urlparse(self.path)
        
        if parsed.path == "/check-approval":
            params = parse_qs(parsed.query)
            req_id = params.get("id", [""])[0]
            
            with LOCK:
                res = PENDING.get(req_id, {"status": "not_found"})

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(res).encode())

        elif parsed.path == "/verify-auth":
            try:
                upload_bytes = int(self.headers.get("X-Upload-Size", 0))
            except Exception:
                upload_bytes = 0

            # Public limit 50MB
            if upload_bytes <= 52428800:
                self.send_response(200)
                self.end_headers()
                return

            header_token = self.headers.get("X-Approval-Token", "").strip()
            with LOCK:
                if header_token and (header_token in APPROVED_TOKENS):
                    if time.time() < APPROVED_TOKENS[header_token]:
                        self.send_response(200)
                        self.end_headers()
                        return

            self.send_response(403)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    # Multi-threaded server prevents any request queue deadlocks
    server = ThreadingHTTPServer((HOST, PORT), RequestHandler)
    server.serve_forever()
  '';
in
{
  systemd.user.services.share-approver = {
    description = "Interactive Desktop Approval Daemon for Large File Uploads";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${approverScript}/bin/share-approver";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
