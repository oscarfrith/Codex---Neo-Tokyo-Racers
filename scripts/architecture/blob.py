"""Print or copy the source blob for a Roblox path from a verified capture (read-only helper)."""
import json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def find(capture, dotted):
    d = json.loads((ROOT/capture).read_text(encoding='utf8'))
    parts = dotted.split('.')
    rows = [r for r in d['manifest'] if r['path_parts'] == parts]
    if len(rows) != 1: raise SystemExit(f'not found/ambiguous: {dotted} ({len(rows)})')
    return ROOT/rows[0]['file']
if __name__ == '__main__':
    cap, path = sys.argv[1], sys.argv[2]
    src = find(cap, path)
    if len(sys.argv) > 3:
        Path(sys.argv[3]).write_bytes(src.read_bytes()); print(sys.argv[3])
    else:
        sys.stdout.buffer.write(src.read_bytes())
