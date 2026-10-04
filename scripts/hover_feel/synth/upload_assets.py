"""Uploads the synthesised sounds to Roblox through Open Cloud and records their asset ids.

Run by Oscar, not by the assistant: the API key is his and is read from the environment only.

    set ROBLOX_API_KEY=<key with the Assets API "write" and "read" permission for your user>
    py -3 scripts/hover_feel/synth/upload_assets.py              (uploads every WAV not yet recorded)
    py -3 scripts/hover_feel/synth/upload_assets.py boost_loop pop_1    (only the named files)

Creates or updates output/hover_feel_audio/exotic/asset_ids.json ({"file name": asset id}). A file already
in that record is skipped unless it is named on the command line, so a rerun after a failure continues.
scrape_loop is skipped: no slot uses it. Roblox moderates each upload and limits audio uploads per month.

Not run or tested by the assistant: written from the Open Cloud Assets API documentation (create asset,
then poll the returned operation). If Roblox rejects a request the response text is printed.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.abspath(os.path.join(HERE, "..", "..", "..", "output", "hover_feel_audio", "exotic"))
RECORD = os.path.join(AUDIO, "asset_ids.json")
USER_ID = "7915427645"  # owner of Space Racers v3 (game.CreatorId)
API = "https://apis.roblox.com/assets/v1/"
SKIP = {"scrape_loop"}


def call(url, key, data=None, content_type=None):
    request = urllib.request.Request(url, data=data, method="POST" if data is not None else "GET")
    request.add_header("x-api-key", key)
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise SystemExit("%s -> HTTP %d: %s" % (url, error.code, error.read().decode("utf-8", "replace")))


def upload(name, key):
    with open(os.path.join(AUDIO, name + ".wav"), "rb") as handle:
        audio = handle.read()
    meta = json.dumps({"assetType": "Audio", "displayName": "SR exotic " + name,
                       "description": "Space Racers Exotic vehicle sound: " + name,
                       "creationContext": {"creator": {"userId": USER_ID}}})
    boundary = uuid.uuid4().hex
    body = (("--%s\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n%s\r\n" % (boundary, meta)).encode()
            + ("--%s\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"%s.wav\"\r\n"
               "Content-Type: audio/wav\r\n\r\n" % (boundary, name)).encode()
            + audio + ("\r\n--%s--\r\n" % boundary).encode())
    operation = call(API + "assets", key, body, "multipart/form-data; boundary=" + boundary)
    path = operation.get("path")
    for _ in range(60):
        if operation.get("done"):
            break
        time.sleep(2)
        operation = call(API + path, key)
    asset_id = (operation.get("response") or {}).get("assetId")
    if not asset_id:
        raise SystemExit("%s: no asset id in %s" % (name, json.dumps(operation)))
    return int(asset_id)


def main():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        raise SystemExit("Set ROBLOX_API_KEY first (see the top of this file).")
    record = json.load(open(RECORD)) if os.path.exists(RECORD) else {}
    named = sys.argv[1:]
    names = named or sorted(f[:-4] for f in os.listdir(AUDIO) if f.endswith(".wav"))
    for name in names:
        if name in SKIP or (name in record and not named):
            continue
        record[name] = upload(name, key)
        json.dump(record, open(RECORD, "w"), indent=1, sort_keys=True)
        print(name, record[name])
    print("recorded", len(record), "ids in", RECORD)


if __name__ == "__main__":
    main()
