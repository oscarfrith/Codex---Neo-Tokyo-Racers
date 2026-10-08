import json
import re
import sys

d = json.load(open(sys.argv[1], encoding="utf-8"))
rows = []
for item in d.get("creatorStoreAssets", []):
    a = item["asset"]
    desc = a.get("description", "")
    m = re.search(r"Native styles:\s*\n?(.*?)(\n\n|$)", desc, re.S)
    styles = [s.strip() for s in (m.group(1) if m else "").replace("\n", " ").split(",") if s.strip()]
    italics = [s for s in styles if "Italic" in s]
    creator = item.get("creator", {}).get("name", "?")
    lic = "OFL" if "Open Font License" in desc else ("Apache" if "Apache" in desc else "?")
    rows.append((a["name"], a["id"], len(styles), len(italics), creator, lic, a.get("createTime", "")[:10],
                 ", ".join(styles)))
rows.sort(key=lambda r: r[0].lower())
for r in rows:
    print(f"{r[0]} | {r[1]} | faces {r[2]} | italic {r[3]} | {r[4]} | {r[5]} | {r[6]}")
print()
print("WITH ITALIC:")
for r in rows:
    if r[3]:
        print(f"  {r[0]} ({r[1]}): {r[7]}")
