#!/usr/bin/env python3
"""Local dev server for the desktop comment tracker.

Serves site/ as static files AND handles /api/config, so the page's
"Save settings"/API-key flow works against a single localhost port
without nginx in front of it. No password gate - this only binds to
localhost for a single local user.

GET  /api/config  -> {"apiKey": "...", "handle": "..."}
POST /api/config  -> body {"apiKey": "...", "handle": "..."} writes key.json
"""

import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

SITE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "site")
KEY_PATH = os.path.join(SITE_DIR, "key.json")
DEFAULT_HANDLE = "@ssmedja"
PORT = 8000


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


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SITE_DIR, **kwargs)

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
            super().do_GET()

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

        api_key = (body.get("apiKey") or "").strip()
        handle = (body.get("handle") or "").strip()
        if not api_key and not handle:
            self._send_json(400, {"error": "apiKey or handle required"})
            return

        save_config(api_key, handle)
        self._send_json(200, {"ok": True})


if __name__ == "__main__":
    print(f"Serving {SITE_DIR} + /api/config on http://localhost:{PORT}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
