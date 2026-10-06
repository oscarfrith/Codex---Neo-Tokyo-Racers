"""Local file bridge for the driving_tune delivery (driving balance, speed readout, hover settle, bank lift, steering direction).

    py -3 scripts/driving_tune/serve.py

Binds 127.0.0.1:8796 at the repository root.
  GET  /<path>            serves a repository file (the installer reads after-sources this way).
  POST /put/<name>        writes the request body, byte for byte, to scripts/driving_tune/before/<name>.
Only names made of letters, digits, dot, dash and underscore are accepted for POST.
"""
import http.server
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BEFORE = os.path.join(ROOT, "scripts", "driving_tune", "before")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_POST(self):
        match = re.fullmatch(r"/put/([A-Za-z0-9._-]+)", self.path.split("?")[0])
        if not match:
            self.send_error(400, "bad name")
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        os.makedirs(BEFORE, exist_ok=True)
        with open(os.path.join(BEFORE, match.group(1)), "wb") as handle:
            handle.write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(str(len(body)).encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8796), Handler).serve_forever()
