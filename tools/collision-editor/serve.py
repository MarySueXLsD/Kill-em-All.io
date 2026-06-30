#!/usr/bin/env python3
"""Serve project files and persist collision editor JSON via a small API."""
from __future__ import annotations

import json
import http.server
import socketserver
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

EDITOR = Path(__file__).resolve().parent
PROJECT = EDITOR.parents[1]
PORT = 8765

COLLISION_FILE = EDITOR / "collision_data.json"
PRESETS_FILE = EDITOR / "collision_presets.json"
BAKE_SCRIPT = PROJECT / "scripts" / "python" / "assets" / "bake_collision_library.py"

API_COLLISION = "/tools/collision-editor/api/collision_data"
API_PRESETS = "/tools/collision-editor/api/presets"


def read_json(path: Path, default):
    if not path.is_file():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def bake_collision_library() -> None:
    if not BAKE_SCRIPT.is_file():
        return
    subprocess.run(
        [sys.executable, str(BAKE_SCRIPT)],
        cwd=str(PROJECT),
        check=False,
    )


class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PROJECT), **kwargs)

    def log_message(self, fmt, *args):
        if args and str(args[0]).startswith("GET /tools/collision-editor/api"):
            return
        super().log_message(fmt, *args)

    def _api_path(self) -> str:
        return urlparse(self.path).path

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        path = self._api_path()
        if path == API_COLLISION:
            self._send_json(read_json(COLLISION_FILE, {}))
            return
        if path == API_PRESETS:
            self._send_json(read_json(PRESETS_FILE, {"presets": []}))
            return
        super().do_GET()

    def do_PUT(self):
        path = self._api_path()
        try:
            if path == API_COLLISION:
                write_json(COLLISION_FILE, self._read_json_body())
                bake_collision_library()
                self._send_json({"ok": True})
                return
            if path == API_PRESETS:
                write_json(PRESETS_FILE, self._read_json_body())
                self._send_json({"ok": True})
                return
        except (json.JSONDecodeError, OSError) as exc:
            self._send_json({"ok": False, "error": str(exc)}, status=400)
            return
        self.send_error(404)


if __name__ == "__main__":
    with ReuseTCPServer(("", PORT), Handler) as httpd:
        url = f"http://localhost:{PORT}/tools/collision-editor/"
        print(f"Serving {PROJECT}")
        print(f"Open {url}")
        print("Auto-save API: collision_data.json + collision_presets.json")
        httpd.serve_forever()
