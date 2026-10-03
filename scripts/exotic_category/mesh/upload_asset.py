"""Upload an FBX to Roblox as a Model asset through Open Cloud and print the asset id.

    py -3 scripts/exotic_category/mesh/upload_asset.py <file.fbx> "<display name>" <user id>

The API key is read from the ROBLOX_ASSETS_KEY environment variable (or the user-level variable in
the Windows registry). It is never printed or written anywhere.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1/"


def api_key():
    key = os.environ.get("ROBLOX_ASSETS_KEY")
    if not key and os.name == "nt":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            key = winreg.QueryValueEx(k, "ROBLOX_ASSETS_KEY")[0]
    if not key:
        raise SystemExit("ROBLOX_ASSETS_KEY is not set")
    return key.strip()


def call(req):
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:600]}")


def upload(path, name, user_id, description=""):
    key = api_key()
    boundary = uuid.uuid4().hex
    request = json.dumps({"assetType": "Model", "displayName": name, "description": description,
                          "creationContext": {"creator": {"userId": str(user_id)}}})
    with open(path, "rb") as f:
        blob = f.read()
    body = b"".join([
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{request}\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'
        f"Content-Type: model/fbx\r\n\r\n".encode(), blob, f"\r\n--{boundary}--\r\n".encode()])
    req = urllib.request.Request(API + "assets", data=body, method="POST", headers={
        "x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"})
    op = call(req)
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(3)
        op = call(urllib.request.Request(API + op["path"], headers={"x-api-key": key}))
    if not op.get("done"):
        raise SystemExit("upload still processing: " + op.get("path", "?"))
    if "error" in op:
        raise SystemExit("upload failed: " + json.dumps(op["error"])[:600])
    return op["response"]


if __name__ == "__main__":
    res = upload(sys.argv[1], sys.argv[2], sys.argv[3], "Space Racers Exotic pilot meshes.")
    print(json.dumps({k: res.get(k) for k in ("assetId", "displayName", "assetType", "moderationResult")}))
