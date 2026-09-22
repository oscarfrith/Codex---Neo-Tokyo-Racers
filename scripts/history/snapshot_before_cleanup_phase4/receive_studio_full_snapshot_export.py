#!/usr/bin/env python3
"""
Receive a Neo Tokyo Racers full Roblox Studio snapshot export over local HTTP.

Usage:
    python scripts/receive_studio_full_snapshot_export.py

Then run this in Roblox Studio:
    scripts/roblox_studio_export_full_snapshot_for_github_v2.lua

The Studio exporter sends chunked POSTs to:
    http://127.0.0.1:8765/ntr-studio-export-chunk

With --write-paste this receiver additionally writes:
    docs/studio-full-export-paste.txt

The default imports directly into these verified mirror outputs without touching the paste blob:
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
    write_paste: bool = False
    chunks_by_export: dict[str, dict[int, str]] = {}
    totals_by_export: dict[str, int] = {}

    def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            if content_length <= 0 or content_length > 1024 * 1024:
                raise ValueError("Invalid/oversize request body")
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
                if total > 4096 or len(data.encode('utf-8')) > 900000:
                    raise ValueError("Export exceeds receiver bounds")
                if self.totals_by_export and export_id not in self.totals_by_export:
                    raise ValueError("Another export is already in progress")
                if export_id in self.totals_by_export and self.totals_by_export[export_id] != total:
                    raise ValueError("Chunk total changed mid-export")
                old = self.chunks_by_export.get(export_id, {}).get(index)
                if old is not None and old != data:
                    raise ValueError("Conflicting duplicate chunk")

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
        payload = importer.parse_payload(export_text)
        manifest = importer.import_payload(payload)
        if self.write_paste:
            self.paste_file.parent.mkdir(parents=True, exist_ok=True)
            self.paste_file.write_text(export_text, encoding="utf-8", newline="\n")

        self.__class__.imported = True
        print(f"PASS: imported {len(manifest)} verified scripts; schema={payload.get('schema_revision', 2)}.")
        print(f"Raw paste {'written' if self.write_paste else 'left untouched'}: {self.paste_file}")
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
        if len(args) < 2 or str(args[1]) != '200':
            print("[receiver] " + format % args)


def main() -> None:
    parser = argparse.ArgumentParser(description="Receive one Roblox Studio full snapshot export over local HTTP.")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Host to bind. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Port to bind. Default: 8765")
    parser.add_argument("--paste-file", default=str(DEFAULT_PASTE_FILE), help="Where to store the raw export text.")
    parser.add_argument("--write-paste", action="store_true", help="Opt in to writing the untracked raw export blob.")
    args = parser.parse_args()
    if args.host != DEFAULT_HOST:
        parser.error("Only the loopback receiver is supported")
    ExportReceiver.write_paste = args.write_paste

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
