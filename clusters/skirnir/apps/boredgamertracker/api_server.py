#!/usr/bin/env python3
"""Tiny stdlib HTTP server for the comment tracker's server-saved API key.

Lets the API key be entered once on the page instead of hand-editing a file
over SSH. Password-gated because the key would otherwise be world-writable
to anyone who can reach bg.aegirshus.

GET  /api/config  -> {"apiKey": "...", "handle": "..."}
POST /api/config  -> body {"password": "...", "apiKey": "...", "handle": "..."}
                     writes apiKey/handle if password matches APP_PASSWORD
"""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "site", "key.json")
APP_PASSWORD = os.environ.get("APP_PASSWORD", "")
DEFAULT_HANDLE = "@ssmedja"


def load_config():
    data = {}
    if os.path.exists(KEY_PATH):
        with open(KEY_PATH, "r", encoding="utf-8") as f:
            data = json.load(f) or {}
    return {"apiKey": data.get("apiKey", ""), "handle": data.get("handle", DEFAULT_HANDLE)}


def save_config(api_key, handle):
    data = load_config()
    if api_key:
        data["apiKey"] = api_key
    if handle:
        data["handle"] = handle
    with open(KEY_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f)


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/") == "/api/config":
            self._send_json(200, load_config())
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/api/config":
            self._send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", 0) or 0)
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            self._send_json(400, {"error": "bad json"})
            return

        if not APP_PASSWORD or body.get("password") != APP_PASSWORD:
            self._send_json(403, {"error": "wrong password"})
            return

        api_key = (body.get("apiKey") or "").strip()
        handle = (body.get("handle") or "").strip()
        if not api_key and not handle:
            self._send_json(400, {"error": "apiKey or handle required"})
            return

        save_config(api_key, handle)
        self._send_json(200, {"ok": True})

    def log_message(self, fmt, *args):
        print(f"[api] {self.address_string()} {fmt % args}")


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
