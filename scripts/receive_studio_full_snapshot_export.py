#!/usr/bin/env python3
"""
Receive a Neo Tokyo Racers full Roblox Studio snapshot export over local HTTP.

Usage:
    python scripts/receive_studio_full_snapshot_export.py

Then run this in Roblox Studio:
    scripts/roblox_studio_export_full_snapshot_for_github_v2.lua

The Studio exporter posts the full export to:
    http://127.0.0.1:8765/ntr-studio-export

This receiver writes:
    docs/studio-full-export-paste.txt

Then imports it into:
    roblox/exported_scripts/
    roblox/studio_snapshot/
"""

from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

import import_studio_full_snapshot_export as importer


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PASTE_FILE = REPO_ROOT / "docs" / "studio-full-export-paste.txt"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
EXPORT_PATH = "/ntr-studio-export"


class ExportReceiver(BaseHTTPRequestHandler):
    paste_file: Path = DEFAULT_PASTE_FILE
    imported: bool = False
    error: str | None = None

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        if self.path != EXPORT_PATH:
            self.send_error(404, "Use /ntr-studio-export")
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(content_length).decode("utf-8")
            if "NTR_STUDIO_FULL_EXPORT_V2" not in body:
                raise ValueError("Request body does not look like an NTR Studio full export.")

            self.paste_file.parent.mkdir(parents=True, exist_ok=True)
            self.paste_file.write_text(body, encoding="utf-8", newline="\n")

            payload = importer.read_payload(self.paste_file)
            scripts = importer.decode_scripts(payload)
            manifest = importer.write_scripts(scripts, importer.DEFAULT_SCRIPTS_DIR)
            importer.write_snapshot(payload, manifest, importer.DEFAULT_SNAPSHOT_DIR)

            self.__class__.imported = True
            response = (
                "OK\n"
                f"Imported {len(scripts)} scripts.\n"
                f"Paste file: {self.paste_file}\n"
                f"Scripts: {importer.DEFAULT_SCRIPTS_DIR}\n"
                f"Snapshot: {importer.DEFAULT_SNAPSHOT_DIR}\n"
            )
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(response.encode("utf-8"))))
            self.end_headers()
            self.wfile.write(response.encode("utf-8"))
        except Exception as exc:  # noqa: BLE001 - command-line receiver should return useful error text.
            self.__class__.error = str(exc)
            response = f"ERROR\n{exc}\n"
            self.send_response(500)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(response.encode("utf-8"))))
            self.end_headers()
            self.wfile.write(response.encode("utf-8"))

    def log_message(self, format: str, *args: Any) -> None:
        print("[receiver] " + format % args)


def main() -> None:
    parser = argparse.ArgumentParser(description="Receive one Roblox Studio full snapshot export over local HTTP.")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host to bind. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to bind. Default: 8765")
    parser.add_argument("--paste-file", default=str(DEFAULT_PASTE_FILE), help="Where to store the raw export text.")
    args = parser.parse_args()

    ExportReceiver.paste_file = Path(args.paste_file)
    if not ExportReceiver.paste_file.is_absolute():
        ExportReceiver.paste_file = REPO_ROOT / ExportReceiver.paste_file

    server = HTTPServer((args.host, args.port), ExportReceiver)
    print(f"Waiting for Studio export at http://{args.host}:{args.port}{EXPORT_PATH}")
    print("Leave this window open, then run scripts/roblox_studio_export_full_snapshot_for_github_v2.lua in Studio.")

    while not ExportReceiver.imported and ExportReceiver.error is None:
        server.handle_request()

    server.server_close()
    if ExportReceiver.error:
        raise SystemExit(f"Import failed: {ExportReceiver.error}")

    print("Studio export received and imported successfully.")


if __name__ == "__main__":
    main()
