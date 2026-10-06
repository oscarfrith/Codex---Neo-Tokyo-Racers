"""One-shot loopback receiver: saves posted {path: source} JSON as files under step2/before/."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
OUT = Path(__file__).resolve().parent / 'before'
done = []
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        for path, source in data.items():
            (OUT / (path.split('.')[-1] + '.lua')).write_bytes(source.encode('utf8'))
        (OUT / 'paths.json').write_text(json.dumps(sorted(data), indent=1) + '\n', encoding='utf8', newline='\n')
        self.send_response(200); self.send_header('Content-Length', '2'); self.end_headers(); self.wfile.write(b'ok'); done.append(len(data))
server = HTTPServer(('127.0.0.1', 8767), Handler)
while not done: server.handle_request()
print('saved', done[0])
