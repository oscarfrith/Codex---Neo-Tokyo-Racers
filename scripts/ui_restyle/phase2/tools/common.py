"""Shared paths, unit order and file discovery for the Pulse wave-2 integration tools.

Units, in install order (CONTRACT.md section 5 / section 2): kit, race_menu, free_roam, world_map, race_session,
race_entry, garage, shell, flip. The install folder of a unit is install/<NN>_<unit> with NN = its index.

Every tool accepts these overrides (tests point them at a temporary tree; defaults are the phase2 folders):
    --kit-dir <dir>  --families-dir <dir>  --install-dir <dir>  --integrator-dir <dir>
Nothing here talks to Studio or git.
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PHASE2 = os.path.dirname(HERE)
RESTYLE = os.path.dirname(PHASE2)
REPO = os.path.abspath(os.path.join(RESTYLE, "..", ".."))
PHASE1 = os.path.join(RESTYLE, "phase1")
CLASSIC = os.path.join(RESTYLE, "classic")
ENGINE = os.path.join(RESTYLE, "engine")
CONTRACTS = os.path.join(CLASSIC, "contracts")
ASSETS_JSON = os.path.join(RESTYLE, "assets", "uploaded_assets.json")

UIP = "ReplicatedStorage.Modules.Game.UIPulse"
UIP_DOT = UIP + "."
ROUTES_PATH = UIP + ".Routes"
NOOP_PATH = UIP + ".NoOp"
LATCH_PATH = "ReplicatedFirst.UIStyleSwitch"
CLIENTBASE_PATH = "StarterPlayer.StarterPlayerScripts.ClientBase"

ORDER = ["kit", "race_menu", "free_roam", "world_map", "race_session", "race_entry", "garage", "shell", "flip"]
FAMILY_NAMES = {"race_menu": "RaceMenu", "free_roam": "FreeRoam", "world_map": "WorldMap",
                "race_session": "RaceSession", "race_entry": "RaceEntry", "garage": "Garage", "shell": "Shell"}
FAMILIES = [u for u in ORDER if u in FAMILY_NAMES]
KIT_AGENTS = ["k1", "k2", "k3", "k4"]
ROOTS = ("ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "ServerScriptService", "StarterPlayer",
         "StarterGui", "StarterPack", "Workspace", "Lighting", "SoundService")
FRAGMENT_SUFFIXES = ("", "_a", "_b", "_shared")


class ToolError(Exception):
    """A problem the integrator must fix; .lines is the list to print."""

    def __init__(self, title, lines=()):
        Exception.__init__(self, title)
        self.title, self.lines = title, list(lines)

    def show(self):
        print("FAILED: " + self.title)
        for line in self.lines:
            print("  - " + line)


class Layout:
    def __init__(self, kit=None, families=None, install=None, integrator=None):
        self.kit = os.path.abspath(kit or os.path.join(PHASE2, "kit"))
        self.families = os.path.abspath(families or os.path.join(PHASE2, "families"))
        self.install = os.path.abspath(install or os.path.join(PHASE2, "install"))
        self.integrator = os.path.abspath(integrator or os.path.join(PHASE2, "integrator"))

    def family_dir(self, family):
        return os.path.join(self.families, family)

    def unit_dir(self, unit):
        return os.path.join(self.install, unit_folder(unit))

    def forks_out(self, family):
        return os.path.join(self.integrator, "forks_out", family)

    def state_path(self):
        return os.path.join(self.install, "state.json")


def parse_args(argv, flags=(), values=()):
    """-> (Layout, positional, {flag: True | value}). Unknown --options raise ToolError."""
    layout_keys = {"--kit-dir": "kit", "--families-dir": "families", "--install-dir": "install",
                   "--integrator-dir": "integrator"}
    chosen, positional, options = {}, [], {}
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg in layout_keys or arg in values:
            if index + 1 >= len(argv):
                raise ToolError("%s needs a value" % arg)
            if arg in layout_keys:
                chosen[layout_keys[arg]] = argv[index + 1]
            else:
                options[arg] = argv[index + 1]
            index += 2
            continue
        if arg.startswith("--"):
            if arg not in flags:
                raise ToolError("unknown option %s" % arg)
            options[arg] = True
        else:
            positional.append(arg)
        index += 1
    return Layout(**chosen), positional, options


def unit_folder(unit):
    if unit not in ORDER:
        raise ToolError("unknown unit %r" % unit, ["units: " + ", ".join(ORDER)])
    return "%02d_%s" % (ORDER.index(unit), unit)


def read_bytes(path):
    with open(path, "rb") as handle:
        return handle.read()


def read_text(path):
    return io.open(path, encoding="utf-8", newline="").read()


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def write_bytes(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)


def read_json(path):
    with io.open(path, encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, value):
    write_text(path, json.dumps(value, indent=1, sort_keys=False) + "\n")


def repo_relative(path):
    """Repo path with forward slashes, or None when the file is outside the repository (a test tree)."""
    relative = os.path.relpath(os.path.abspath(path), REPO).replace(os.sep, "/")
    return None if relative.startswith("..") else relative


def djb2(data):
    x = 5381
    for b in data:
        x = (x * 33 + b) % 4294967296
    return x


def fnv1a32(data):
    x = 2166136261
    for b in data:
        x = ((x ^ b) * 16777619) % 4294967296
    return x


def fingerprint(data):
    return "%d-%d-%d" % (djb2(data), fnv1a32(data), len(data))


def lua_files(folder):
    """{instance path: file} for <folder>/*.lua (not *_test.lua)."""
    out = {}
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.endswith(".lua") and not name.endswith("_test.lua"):
                out[name[:-4]] = os.path.join(folder, name)
    return out


def test_files(folder):
    """{instance path: file} for <folder>/*_test.lua."""
    out = {}
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.endswith("_test.lua"):
                out[name[:-9]] = os.path.join(folder, name)
    return out


_MANIFEST = None


def classic_manifest():
    """{script path: manifest row} from classic/manifest.json."""
    global _MANIFEST
    if _MANIFEST is None:
        _MANIFEST = {row["path"]: row for row in read_json(os.path.join(CLASSIC, "manifest.json"))["scripts"]}
    return _MANIFEST


def classic_source_file(path):
    row = classic_manifest().get(path)
    return os.path.join(CLASSIC, "sources", row["file"]) if row else None


def clientbase_entries():
    return read_json(os.path.join(CONTRACTS, "_clientbase_entries.json"))["entries"]


def phase1_sources():
    """{instance path: file} of phase1/after (the installed Phase 1 baseline, ClientBase included)."""
    return lua_files(os.path.join(PHASE1, "after"))


def phase1_tests():
    return test_files(os.path.join(PHASE1, "tests"))


def kit_sources(layout):
    """-> ({path: file}, {path: file} tests, [problems], [agent folders present]).
    Sources come from kit/k1..k4/after and integrator/kit_after (the integrator's own kit files, e.g. a rebuilt gallery)."""
    sources, tests, problems, present = {}, {}, [], []
    folders = [(agent, os.path.join(layout.kit, agent, "after"), os.path.join(layout.kit, agent, "tests"))
               for agent in KIT_AGENTS]
    folders.append(("integrator", os.path.join(layout.integrator, "kit_after"),
                    os.path.join(layout.integrator, "kit_tests")))
    for agent, after, tests_dir in folders:
        if not os.path.isdir(after):
            if agent != "integrator":
                problems.append("missing folder %s" % after)
            continue
        present.append(agent)
        for path, file in lua_files(after).items():
            if path in sources:
                problems.append("%s is supplied twice: %s and %s" % (path, sources[path], file))
            sources[path] = file
        for path, file in test_files(tests_dir).items():
            if path in tests:
                problems.append("test for %s is supplied twice: %s and %s" % (path, tests[path], file))
            tests[path] = file
    return sources, tests, problems, present


def fragments(family_dir, base):
    """[(file name, parsed JSON)] for base.json, base_a.json, base_b.json, base_shared.json that exist."""
    out = []
    for suffix in FRAGMENT_SUFFIXES:
        name = "%s%s.json" % (base, suffix)
        full = os.path.join(family_dir, name)
        if os.path.isfile(full):
            try:
                out.append((name, read_json(full)))
            except ValueError as error:
                raise ToolError("%s is not valid JSON" % full, [str(error)])
    return out


def document_present(family_dir, name):
    """CONTRACT.md / NOTES.md, or the _a / _b / _shared files of a two-agent family."""
    stem, ext = os.path.splitext(name)
    return any(os.path.isfile(os.path.join(family_dir, stem + suffix + ext)) for suffix in FRAGMENT_SUFFIXES)


def family_contract(family_dir):
    """Merged parity declaration: a list of owner objects from contract.json and its _a/_b variants."""
    owners = []
    for name, data in fragments(family_dir, "contract"):
        rows = data.get("owners") if isinstance(data, dict) and "owners" in data else data
        if isinstance(rows, dict):
            rows = [rows]
        if not isinstance(rows, list):
            raise ToolError("%s must be a list with one object per Pulse owner (API2 6.5)" % name)
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get("owner"), str):
                raise ToolError("%s: every entry needs an \"owner\" (API2 6.5)" % name)
            owners.append(dict(row, _file=name))
    return owners


def family_sources(layout, family, use_forks=True):
    """-> ({path: file}, {path: file} tests, {path: fork build record}). A fork-built file replaces a hand-assembled
    after/ file of the same path (build_forks.py must have run; assemble.py runs it)."""
    folder = layout.family_dir(family)
    sources = lua_files(os.path.join(folder, "after"))
    tests = test_files(os.path.join(folder, "tests"))
    forks = {}
    index = os.path.join(layout.forks_out(family), "forks.json")
    if use_forks and os.path.isfile(index):
        for record in read_json(index)["forks"]:
            built = os.path.join(layout.forks_out(family), "after", record["path"] + ".lua")
            if os.path.isfile(built):
                sources[record["path"]] = built
                forks[record["path"]] = record
    return sources, tests, forks


def short(path):
    return path[len(UIP_DOT):] if path.startswith(UIP_DOT) else path


def table(rows, header):
    """Plain text table."""
    rows = [header] + [[str(cell) for cell in row] for row in rows]
    widths = [max(len(row[i]) for row in rows) for i in range(len(header))]
    lines = []
    for number, row in enumerate(rows):
        lines.append("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)).rstrip())
        if number == 0:
            lines.append("  ".join("-" * width for width in widths))
    return "\n".join(lines)


def run_main(main):
    try:
        sys.exit(main(sys.argv[1:]))
    except ToolError as error:
        error.show()
        sys.exit(1)


IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
