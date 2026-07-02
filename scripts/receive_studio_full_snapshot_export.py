#!/usr/bin/env python3
"""
Receive a Neo Tokyo Racers full Roblox Studio snapshot export over local HTTP.

Usage:
    python scripts/receive_studio_full_snapshot_export.py

Then run this in Roblox Studio:
    scripts/roblox_studio_export_full_snapshot_for_github_v2.lua

The Studio exporter sends chunked POSTs to:
    http://127.0.0.1:8765/ntr-studio-export-chunk

This receiver writes:
    docs/studio-full-export-paste.txt

Then imports it into:
    roblox/exported_scripts/
    roblox/studio_snapshot/
"""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

import import_studio_full_snapshot_export as importer


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PASTE_FILE = REPO_ROOT / "docs" / "studio-full-export-paste.txt"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8765
EXPORT_PATH = "/ntr-studio-export"
CHUNK_PATH = "/ntr-studio-export-chunk"


class ExportReceiver(BaseHTTPRequestHandler):
    paste_file: Path = DEFAULT_PASTE_FILE
    imported: bool = False
    error: str | None = None
    chunks_by_export: dict[str, dict[int, str]] = {}
    totals_by_export: dict[str, int] = {}

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(content_length).decode("utf-8")

            if self.path == EXPORT_PATH:
                self.import_export_text(body)
                self.send_text(200, "OK\nImported full export.\n")
                return

            if self.path == CHUNK_PATH:
                message = json.loads(body)
                export_id = str(message["export_id"])
                index = int(message["index"])
                total = int(message["total"])
                data = str(message["data"])

                if index < 1 or total < 1 or index > total:
                    raise ValueError(f"Invalid chunk index {index} of {total}.")

                self.__class__.totals_by_export[export_id] = total
                self.__class__.chunks_by_export.setdefault(export_id, {})[index] = data
                received = len(self.__class__.chunks_by_export[export_id])

                if received == total:
                    chunks = self.__class__.chunks_by_export.pop(export_id)
                    self.__class__.totals_by_export.pop(export_id, None)
                    export_text = "".join(chunks[i] for i in range(1, total + 1))
                    self.import_export_text(export_text)
                    self.send_text(200, f"OK\nReceived and imported {total} chunks.\n")
                else:
                    self.send_text(200, f"OK\nReceived chunk {index} of {total}. Waiting for {total - received} more.\n")
                return

            self.send_error(404, f"Use {CHUNK_PATH}")
        except Exception as exc:  # noqa: BLE001 - command-line receiver should return useful error text.
            self.__class__.error = str(exc)
            self.send_text(500, f"ERROR\n{exc}\n")

    def import_export_text(self, export_text: str) -> None:
        if "NTR_STUDIO_FULL_EXPORT_V2" not in export_text:
            raise ValueError("Request body does not look like an NTR Studio full export.")

        self.paste_file.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.paste_file.write_text(export_text, encoding="utf-8", newline="\n")
            payload = importer.read_payload(self.paste_file)
        except OSError as exc:
            print(f"Warning: could not write raw paste file {self.paste_file}: {exc}")
            print("Continuing with in-memory import; raw paste file will not be refreshed.")
            start = export_text.find(importer.EXPORT_START)
            if start < 0:
                raise ValueError(f"Export text does not contain {importer.EXPORT_START}.") from exc

            start += len(importer.EXPORT_START)
            end = export_text.find(importer.EXPORT_END, start)
            json_text = export_text[start:] if end < 0 else export_text[start:end]
            json_text = json_text.strip()
            if not json_text:
                raise ValueError("Export marker was found, but no JSON payload followed it.") from exc

            payload = json.loads(json_text)
            if payload.get("format") != importer.EXPORT_START:
                raise ValueError(f"Unexpected export format: {payload.get('format')!r}") from exc

        scripts = importer.decode_scripts(payload)
        manifest = importer.write_scripts(scripts, importer.DEFAULT_SCRIPTS_DIR)
        importer.write_snapshot(payload, manifest, importer.DEFAULT_SNAPSHOT_DIR)

        self.__class__.imported = True
        print(f"Imported {len(scripts)} scripts.")
        print(f"Paste file: {self.paste_file}")
        print(f"Scripts: {importer.DEFAULT_SCRIPTS_DIR}")
        print(f"Snapshot: {importer.DEFAULT_SNAPSHOT_DIR}")

    def send_text(self, status: int, response: str) -> None:
        data = response.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

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
    print(f"Waiting for Studio export chunks at http://{args.host}:{args.port}{CHUNK_PATH}")
    print("Leave this window open, then run scripts/roblox_studio_export_full_snapshot_for_github_v2.lua in Studio.")

    while not ExportReceiver.imported and ExportReceiver.error is None:
        server.handle_request()

    server.server_close()
    if ExportReceiver.error:
        raise SystemExit(f"Import failed: {ExportReceiver.error}")

    print("Studio export received and imported successfully.")


if __name__ == "__main__":
    main()
