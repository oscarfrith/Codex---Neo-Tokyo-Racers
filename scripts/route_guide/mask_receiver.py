"""Loopback receiver for the minimap road mask exported from Studio (Edit, read-only).

Studio posts JSON chunks {"token", "index", "total", "data"} to http://127.0.0.1:8768/mask.
The assembled payload is written to scripts/route_guide/road_mask.json.
"""
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = pathlib.Path(__file__).with_name("road_mask.json")
LIMIT = 400_000
chunks = {}
state = {"total": None, "token": None, "done": False}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        if self.path != "/mask":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > LIMIT:
            self.send_error(413)
            return
        message = json.loads(self.rfile.read(length))
        if state["token"] is None:
            state["token"], state["total"] = message["token"], message["total"]
        if message["token"] != state["token"] or message["total"] != state["total"]:
            self.send_error(409)
            return
        chunks[message["index"]] = message["data"]
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
        if len(chunks) == state["total"]:
            text = "".join(chunks[i] for i in range(1, state["total"] + 1))
            payload = json.loads(text)
            OUT.write_text(json.dumps(payload), encoding="utf-8")
            print(f"Wrote {OUT} ({len(text)} chars)")
            state["done"] = True


def main():
    server = HTTPServer(("127.0.0.1", 8768), Handler)
    server.timeout = 1
    print("Ready on 127.0.0.1:8768/mask")
    waited = 0
    while not state["done"] and waited < 600:
        server.handle_request()
        waited += 1
    server.server_close()
    if not state["done"]:
        sys.exit("Timed out; no mask written")


if __name__ == "__main__":
    main()
