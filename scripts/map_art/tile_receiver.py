"""Loopback receiver for export_tiles.lua: writes each minimap tile as a PNG in scripts/map_art/tiles/."""
import base64
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "route_guide"))
import struct
import zlib

OUT = HERE / "tiles"
OUT.mkdir(exist_ok=True)
tiles = {}
done = set()


def write_rgba_png(path, width, height, raw):
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(raw[y * stride:(y + 1) * stride])

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(bytes(rows), 6)))
        handle.write(chunk(b"IEND", b""))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        if self.path != "/tile" or length <= 0 or length > 400_000:
            self.send_error(400)
            return
        message = json.loads(self.rfile.read(length))
        record = tiles.setdefault(message["name"], {"parts": {}, "meta": message})
        record["parts"][message["index"]] = message["data"]
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
        if len(record["parts"]) == message["total"]:
            raw = base64.b64decode("".join(record["parts"][i] for i in range(1, message["total"] + 1)))
            meta = record["meta"]
            write_rgba_png(OUT / (message["name"] + ".png"), meta["width"], meta["height"], raw)
            (OUT / (message["name"] + ".json")).write_text(json.dumps({"asset": meta["asset"], "width": meta["width"], "height": meta["height"]}))
            print("wrote", message["name"], meta["width"], meta["height"])
            done.add(message["name"])


def main():
    server = HTTPServer(("127.0.0.1", 8769), Handler)
    server.timeout = 1
    print("Ready on 127.0.0.1:8769/tile")
    waited = 0
    while len(done) < 4 and waited < 900:
        server.handle_request()
        waited += 1
    server.server_close()


if __name__ == "__main__":
    main()
