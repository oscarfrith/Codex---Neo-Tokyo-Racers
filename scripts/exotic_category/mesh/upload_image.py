"""Upload a PNG to Roblox as an image asset through Open Cloud and print the asset id.

    py -3 scripts/exotic_category/mesh/upload_image.py <file.png> "<display name>" <user id>

It tries the Image asset type first and falls back to Decal. A Decal id is not the image id: in Studio,
`game:GetObjects("rbxassetid://<id>")[1].Texture` gives the image content id. The API key is handled by
upload_asset.py and is never printed.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

from upload_asset import API, api_key


def post(path, name, user_id, asset_type):
    key = api_key()
    boundary = uuid.uuid4().hex
    request = json.dumps({"assetType": asset_type, "displayName": name, "description": "Space Racers paint texture.",
                          "creationContext": {"creator": {"userId": str(user_id)}}})
    with open(path, "rb") as f:
        blob = f.read()
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{request}\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'
        f"Content-Type: image/png\r\n\r\n".encode(), blob, f"\r\n--{boundary}--\r\n".encode()])
    req = urllib.request.Request(API + "assets", data=body, method="POST", headers={
        "x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            op = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}"
    for _ in range(40):
        if op.get("done"):
            break
        time.sleep(3)
        with urllib.request.urlopen(urllib.request.Request(API + op["path"], headers={"x-api-key": key}), timeout=120) as r:
            op = json.loads(r.read().decode("utf-8"))
    if not op.get("done"):
        return None, "still processing: " + op.get("path", "?")
    if "error" in op:
        return None, json.dumps(op["error"])[:300]
    return op["response"], None


if __name__ == "__main__":
    for kind in ("Image", "Decal"):
        res, err = post(sys.argv[1], sys.argv[2], sys.argv[3], kind)
        if res:
            print(json.dumps({"assetType": kind, "assetId": res.get("assetId"), "displayName": res.get("displayName"),
                              "moderation": (res.get("moderationResult") or {}).get("moderationState")}))
            break
        print(json.dumps({"assetType": kind, "failed": err}))
