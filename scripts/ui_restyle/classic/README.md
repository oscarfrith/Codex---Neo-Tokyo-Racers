# Classic baseline record

The proof that the Classic UI is unchanged while Pulse is built beside it (recommended plan, section 1.8).

**Taken:** 2026-10-09, Space Racers v3 (placeId 93959280828322), Studio Edit, read-only. 221 scripts, 3,518,053 bytes.

| File | What it is |
|---|---|
| `sources/*.lua`, `manifest_raw.json`, `config_raw.json` | The integrator's dump. Byte-exact. Never edited. |
| `manifest.json` | Per script: path, class, file, length (bytes) and two hashes. |
| `config.json` | Typed record of `ReplicatedStorage.Config.UI`, `.Development`, `.Player` (attributes and Value objects, flattened by path, sorted) plus three StarterGui settings. One hash pair per folder. |
| `out_verify_classic.lua` | Generated read-only Studio check with the expected table embedded. |

## Hashes

Both run over the raw source bytes and give the same numbers in Python and in Luau.

- `djb2`: `x = (x * 33 + byte) % 2^32`, seed 5381. The existing project convention (`scripts/hover_feel`).
- `fnv1a32`: FNV-1a 32-bit. In Luau the multiply is split (`bit32.lshift(f, 24) + f * 403`) so nothing passes 2^53.

The config hashes are over canonical JSON and are a Python-side record only. Studio compares config value by value: numbers and Color3/Vector3 components within 1e-6, everything else exactly.

## Rebuild and test

```
py -3 build_manifest.py     # checks every file length, writes manifest.json and config.json
py -3 build_verify.py       # writes out_verify_classic.lua (fails at 190,000 characters)
py -3 test_manifest.py      # hashes against a line-by-line port of the Luau arithmetic, all 221 sources
```

## Run the check

Studio in Edit, the v3 place. Send the whole of `out_verify_classic.lua` through `execute_luau`. It asserts the placeId and Edit mode, writes nothing, yields every 20 scripts, and returns one JSON string:

```
{ ok, failures, truncated, scannedScripts, seconds,
  scripts:  { same, changed:[{path, was, now}], missing:[], added:[] },
  config:   { same, nodes, diffs:[{path, attr, was, now}], added:[], removed:[] },
  declared: { scripts:[], addedScripts:[], config:[], services:[] } }
```

`ok` is true only when every failure list is empty. Config `added`/`removed` entries are `path` for an instance and `path@Attribute` for an attribute; `@Value` and `@Class` are a Value object's value and a node's class. Lists stop at 300 entries (`truncated`).

## Declared changes

Later phases will change Classic on purpose in a few named places and add Pulse instances. Those go in a `declared.json` and are built in with `py -3 build_verify.py --declared declared.json`. The check then lists them under `declared` instead of failing. Anything not declared still fails.

```
{
  "scripts":      { "<path>": { "file": "after.lua" } },     an edited script; live must equal the baseline
                                                              ("before") or this after-hash ("after")
  "addedScripts": { "<path>": {} },                          a new script; give file or hashes to pin it
  "configNodes":  [ "UI.Pulse" ],                            a new instance under Config, with its subtree
  "configAttrs":  [ "UI.Some.Folder@Attr" ],                 a new attribute on a recorded instance
  "services":     { "StarterGuiChildren": 1 }                a new value for a recorded StarterGui setting
}
```

`file` is relative to `declared.json`; `{ "length", "djb2", "fnv1a32" }` works in its place. The committed `out_verify_classic.lua` is the build with nothing declared, and `test_manifest.py` checks that.
