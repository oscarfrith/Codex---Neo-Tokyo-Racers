"""One-shot loopback receiver: serves dump_state.lua, saves the JSON it posts back. Usage: receive_dump.py OUT.json"""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
HERE = Path(__file__).resolve().parent
out = Path(sys.argv[1]); assert not out.exists(), 'Refusing to overwrite ' + str(out)
done = []
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        body = (HERE / 'dump_state.lua').read_bytes()
        self.send_response(200); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        n = int(self.headers['Content-Length']); assert n < 5_000_000
        data = json.loads(self.rfile.read(n))
        out.write_text(json.dumps(data, indent=1, sort_keys=True) + '\n', encoding='utf8', newline='\n')
        self.send_response(200); self.send_header('Content-Length', '2'); self.end_headers(); self.wfile.write(b'ok'); done.append(1)
server = HTTPServer(('127.0.0.1', 8767), Handler); server.timeout = 300
while not done: server.handle_request()
print('saved', out, out.stat().st_size)
