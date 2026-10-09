"""Local file bridge for the UI restyle programme (scripts/ui_restyle).

    py -3 scripts/ui_restyle/tools/serve.py

Binds 127.0.0.1:8796 at the repository root.
  GET  /<path>            serves a repository file (installers read after-sources this way).
  POST /put/<name>        writes the request body, byte for byte, to scripts/ui_restyle/classic/sources/<name>.
  POST /json/<name>       writes the request body to scripts/ui_restyle/classic/<name>.
Only names made of letters, digits, dot, dash and underscore are accepted for POST.
"""
import http.server
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CLASSIC = os.path.join(ROOT, "scripts", "ui_restyle", "classic")
ROUTES = {"put": os.path.join(CLASSIC, "sources"), "json": CLASSIC}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_POST(self):
        match = re.fullmatch(r"/(put|json)/([A-Za-z0-9._-]+)", self.path.split("?")[0])
        if not match:
            self.send_error(400, "bad name")
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        folder = ROUTES[match.group(1)]
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, match.group(2)), "wb") as handle:
            handle.write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(str(len(body)).encode())

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", 8796), Handler).serve_forever()
