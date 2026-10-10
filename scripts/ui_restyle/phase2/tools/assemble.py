"""Builds the installable phase folder of one wave-2 unit: install/<NN>_<unit>/ (CONTRACT.md section 5, step 1).

    py -3 assemble.py <unit> [--partial] [--no-build] [--noop-on-first-need] [--forks-win]

unit: kit | race_menu | free_roam | world_map | race_session | race_entry | garage | shell | flip

Writes, inside install/<NN>_<unit>/:
    spec.json            engine format (engine/README.md); ops in the order folders, modules, attributes, sources
    after/ before/       byte copies of every source the spec names
    tests/               the unit's pure tests (and the generated Routes test for a family)
    declared.json        cumulative: Phase 1 + every unit up to this one, for the Classic verify
    out_verify_classic_<NN>_<unit>.lua   built by classic/build_verify.py --declared; spec.classicVerify names it
    test_manifest.json   sources and tests for tools/run_tests_phase2.lua
    out_audit.lua out_apply.lua out_rollback.lua applied_hashes.json     written by engine/build.py
and updates install/state.json, the chain: a unit's "before" for a script an earlier unit (or Phase 1) installed is
that unit's "after". Units must be assembled in order; reassembling a unit drops the later ones from the chain.

kit      source ops for changed Phase 1 modules (before = phase1/after), create ops for new modules, attribute ops for
         the asset ids (assets/uploaded_assets.json) and for new or changed tokens (integrator/tokens_flat.json, made
         by tokens_from_dump.py from the Edit harness). Without the tokens file the spec is PROVISIONAL: not
         installable, exit code 3, but the test manifest is written so the harness can run.
family   the merged spec_ops fragments, the forks built by build_forks.py, the source op that rewrites UIPulse.Routes
         with the family added (gen_routes.py), and UIPulse.NoOp when a route needs it and nothing installed it yet.
flip     the single attribute op Config.UI@UIStyle "Classic" -> "Pulse".

It stops with a list when files are missing, a fragment is wrong, or an op collides with another unit. --partial
turns "expected file is missing" into a warning (dry runs while agents are still writing); collisions always stop.
Nothing here talks to Studio or git.
"""
import os
import re
import shutil
import subprocess
import sys

import common
from common import ToolError
import build_forks
import gen_routes

UIP_PATH = common.UIP.split(".")
CONFIG_UI = ["ReplicatedStorage", "Config", "UI"]
PHASE1_FOLDERS = [common.UIP, common.UIP + ".Kit", common.UIP + ".Toasts", common.UIP + ".Dev", common.UIP + ".Dev.Fixtures"]
PHASE1_DECLARED = os.path.join(common.PHASE1, "declared.json")
KIT_ORDER = ["Sprites", "Contracts", "Perf", "Presence", "Tokens", "Metrics", "Layers", "Text", "Surface", "Input",
             "BigNumber", "Controls", "Collections", "Data", "Gauge", "Minimap", "Touch", "Overlay"]
KIT_NEW = ["Sprites", "Presence", "BigNumber", "Data", "Gauge", "Minimap", "Touch"]                  # API2 section 3
KIT_CHANGED = ["Tokens", "Metrics", "Layers", "Contracts", "Text", "Surface", "Controls", "Collections", "Input",
               "Overlay"]                                                                            # API2 2.2 to 2.11
# API2 1.1: the 31 keys. Keys that were Phase 1 attributes have before "", the others before null.
ASSET_KEYS = ["IconSheet", "MapIconSheet", "GlowSoft", "GlowTight", "GlowLine", "Digits256", "Digits128", "DigitsPunct",
              "GaugeTrack", "GaugeTicks", "GaugeGlow", "GaugeArc", "BoostArc", "MinimapRing", "MinimapVignette",
              "MapPlayerArrow", "RankArc", "SegmentStrip", "TitleSlash", "ChequerCorner", "KeyCap"] + [
    "Touch" + control + state for control in ("Accelerate", "Brake", "Turn", "Drift", "Boost") for state in ("", "Pressed")]
MAX_SOURCE_CHARS = 150000
FAMILY_FILES = ["CONTRACT.md", "NOTES.md"]
SHARED_WORDS = ("ResponsiveUIFoundation",)


def op_id(path):
    dotted = ".".join(path)
    return common.short(dotted)


def source_rank(path):
    if path == common.LATCH_PATH:
        return (0, 0, path)
    if not path.startswith(common.UIP_DOT):
        return (9, 0, path)
    rest = common.short(path)
    head = rest.split(".")[0]
    if rest in ("Routes", "NoOp"):
        return (1, 0, path)
    if head == "Kit":
        name = rest.split(".")[1] if "." in rest else ""
        return (2, KIT_ORDER.index(name) if name in KIT_ORDER else len(KIT_ORDER), path)
    if head == "Dev":
        return (8, 0 if "Fixtures" in rest else 1, path)
    return (5, 0, path)


# ---------------------------------------------------------------------------------------------------- the chain
def phase1_chain():
    scripts, tests = {}, {}
    for path, file in common.phase1_sources().items():
        scripts[path] = {"file": file, "fp": common.fingerprint(common.read_bytes(file)), "unit": "phase1",
                         "class": "LocalScript" if path == common.CLIENTBASE_PATH else "ModuleScript"}
    for path, file in common.phase1_tests().items():
        tests[path] = {"file": file, "unit": "phase1"}
    return {"scripts": scripts, "folders": set(PHASE1_FOLDERS), "tests": tests, "classicEdits": {common.CLIENTBASE_PATH: "phase1"}}


def load_state(layout):
    path = layout.state_path()
    return common.read_json(path) if os.path.isfile(path) else {"units": {}}


def load_chain(layout, unit):
    """What is installed (or pending) before `unit`: Phase 1 plus every earlier unit recorded in state.json."""
    chain = phase1_chain()
    state = load_state(layout)
    missing, stale = [], []
    for earlier in common.ORDER[:common.ORDER.index(unit)]:
        folder = common.unit_folder(earlier)
        record = state["units"].get(folder)
        if record is None:
            missing.append("%s has not been assembled (run assemble.py %s first)" % (folder, earlier))
            continue
        for path, item in record["scripts"].items():
            file = os.path.join(layout.install, *item["file"].split("/"))
            if not os.path.isfile(file) or common.fingerprint(common.read_bytes(file)) != item["fp"]:
                stale.append("%s: %s is missing or was changed after assembly (reassemble %s)" % (folder, item["file"], earlier))
                continue
            chain["scripts"][path] = {"file": file, "fp": item["fp"], "unit": folder, "class": item["class"]}
            if item.get("classic"):
                chain["classicEdits"][path] = folder
        chain["folders"].update(record.get("folders", []))
        for path, relative in record.get("tests", {}).items():
            chain["tests"][path] = {"file": os.path.join(layout.install, *relative.split("/")), "unit": folder}
    if missing or stale:
        raise ToolError("the install chain before %s is incomplete" % unit, missing + stale)
    return chain


def folder_exists(chain, dotted):
    """True when the instance at this path is known to exist: created by the chain, or a parent of a recorded script."""
    if dotted in chain["folders"] or dotted.count(".") == 0:
        return True
    prefix = dotted + "."
    return any(path.startswith(prefix) for path in chain["scripts"]) or any(
        path.startswith(prefix) for path in common.classic_manifest())


# ------------------------------------------------------------------------------------------------ unit builders
class Build:
    def __init__(self, layout, unit, options):
        self.layout, self.unit, self.options = layout, unit, options
        self.folder = common.unit_folder(unit)
        self.out = layout.unit_dir(unit)
        self.chain = load_chain(layout, unit)
        self.problems, self.warnings, self.notes = [], [], []
        self.folders = []          # [dotted path] created by this unit, parents first
        self.folder_ids = {}       # dotted path -> the op id an agent gave its Folder op
        self.creates = {}          # path -> (bytes, op id)
        self.sources = {}          # path -> (before bytes, after bytes, class, op id)
        self.attributes = []       # attribute ops, ready
        self.tests = {}            # path -> bytes
        self.installable = True
        self.provisional = []

    def missing(self, message):
        (self.warnings if "--partial" in self.options else self.problems).append(message)

    def need_folders(self, path):
        parts = path.split(".")
        for depth in range(2, len(parts)):
            dotted = ".".join(parts[:depth])
            if not folder_exists(self.chain, dotted) and dotted not in self.folders:
                self.folders.append(dotted)

    def add_script(self, path, data, origin, given_id=None):
        """Files a source as a create or a source op, by what the chain and the Classic baseline say exists."""
        text = data.decode("utf-8", errors="replace")
        if b"\r" in data:
            self.problems.append("%s: contains CR; after-sources are LF only (%s)" % (path, origin))
        if len(text) > MAX_SOURCE_CHARS:
            self.problems.append("%s: %d characters; the limit is %d (%s)" % (path, len(text), MAX_SOURCE_CHARS, origin))
        if path in self.creates or path in self.sources:
            self.problems.append("%s is supplied twice in this unit (%s)" % (path, origin))
            return
        installed = self.chain["scripts"].get(path)
        classic = common.classic_manifest().get(path)
        if installed is not None:
            before = common.read_bytes(installed["file"])
            if before == data:
                self.notes.append("%s is byte-identical to the installed source (%s); no op" % (common.short(path), installed["unit"]))
                return
            if classic is not None and path != common.ROUTES_PATH:
                self.problems.append("%s: this Classic script was already edited by %s. The Classic verify can pin one "
                                     "after-hash per Classic script, so a second edit needs a decision first." % (
                                         path, self.chain["classicEdits"].get(path, installed["unit"])))
                return
            self.sources[path] = (before, data, installed["class"], given_id or op_id(path.split(".")))
        elif classic is not None:
            before = common.read_bytes(common.classic_source_file(path))
            if before == data:
                self.problems.append("%s: the after-file equals the Classic source; drop the op (%s)" % (path, origin))
                return
            self.sources[path] = (before, data, classic["class"], given_id or op_id(path.split(".")))
            self.notes.append("EDITS A CLASSIC SCRIPT: %s (reviewer reads this diff; CONTRACT section 2)" % path)
        else:
            self.need_folders(path)
            self.creates[path] = (data, given_id or op_id(path.split(".")))

    # ------------------------------------------------------------------------------------------------------ kit
    def build_kit(self):
        sources, tests, problems, present = common.kit_sources(self.layout)
        for problem in problems:
            (self.missing if problem.startswith("missing folder") else self.problems.append)(problem)
        for name in KIT_NEW + KIT_CHANGED:
            if common.UIP_DOT + "Kit." + name not in sources:
                self.missing("kit v2 module Kit.%s is not in any kit/k*/after folder (API2 section %s)" % (
                    name, "3" if name in KIT_NEW else "2"))
        for path in sorted(sources, key=source_rank):
            self.add_script(path, common.read_bytes(sources[path]), sources[path])
        for path, file in tests.items():
            self.tests[path] = common.read_bytes(file)
        if "--noop-on-first-need" not in self.options:
            self.add_noop()
        for path in sorted(set(self.creates) | set(self.sources)):
            leaf = common.short(path)
            if leaf.startswith("Kit.") and path not in self.tests and path not in self.chain["tests"]:
                self.warnings.append("no pure test for %s" % leaf)
        self.asset_attributes()
        self.token_attributes()

    def add_noop(self):
        if common.NOOP_PATH in self.chain["scripts"] or common.NOOP_PATH in self.creates:
            return
        file = os.path.join(self.layout.integrator, "UIPulse.NoOp.lua")
        if not os.path.isfile(file):
            self.problems.append("integrator/UIPulse.NoOp.lua is missing (API2 3.10)")
            return
        self.add_script(common.NOOP_PATH, common.read_bytes(file), file)

    def asset_attributes(self):
        uploaded = common.read_json(common.ASSETS_JSON)["assets"]
        if set(uploaded) != set(ASSET_KEYS):
            self.problems.append("assets/uploaded_assets.json keys differ from API2 1.1: missing %s, extra %s" % (
                sorted(set(ASSET_KEYS) - set(uploaded)), sorted(set(uploaded) - set(ASSET_KEYS))))
            return
        sys.path.insert(0, common.PHASE1)
        import gen_spec
        phase1_keys = set(gen_spec.ASSET_KEYS)
        for key in ASSET_KEYS:
            asset_id = uploaded[key].get("id")
            if not isinstance(asset_id, str) or not re.fullmatch(r"rbxassetid://\d+", asset_id):
                self.problems.append("assets/uploaded_assets.json: %s has no rbxassetid id (%r)" % (key, asset_id))
                continue
            op = {"id": "asset." + key, "kind": "attribute", "path": CONFIG_UI + ["Pulse", "Assets"],
                  "key": key, "before": "" if key in phase1_keys else None, "after": asset_id}
            # Earlier uploads of the same asset (uploaded_assets.json "was"): APPLY replaces them.
            if uploaded[key].get("was"):
                op["was"] = list(uploaded[key]["was"])
            self.attributes.append(op)
        self.notes.append("asset attributes: %d (%d existed as \"\", %d new); removed Phase 1 keys stay \"\": %s" % (
            len(ASSET_KEYS), len(phase1_keys & set(ASSET_KEYS)), len(set(ASSET_KEYS) - phase1_keys),
            ", ".join(sorted(phase1_keys - set(ASSET_KEYS)))))

    def token_attributes(self):
        file = os.path.join(self.layout.integrator, "tokens_flat.json")
        desk = os.path.join(self.layout.kit, "k1", "tokens_flat.json")
        old = common.read_json(os.path.join(common.PHASE1, "tokens_flat.json"))["tokens"]
        desk_tokens = common.read_json(desk).get("tokens", {}) if os.path.isfile(desk) else None
        if not os.path.isfile(file):
            self.installable = False
            if desk_tokens is None:
                self.provisional.append("no tokens file: no token attribute ops. Run the Edit harness on this unit, save "
                                        "its JSON, run tokens_from_dump.py, then assemble kit again.")
                return
            self.provisional.append("token attributes come from kit/k1/tokens_flat.json, K1's desk parse of the Tokens "
                                    "source. The installable build needs integrator/tokens_flat.json: run the Edit "
                                    "harness on this unit, save its JSON, run tokens_from_dump.py, assemble kit again.")
            new = desk_tokens
        else:
            data = common.read_json(file)
            new = data["tokens"]
            if data.get("provisional"):
                self.installable = False
                self.provisional.append("integrator/tokens_flat.json is marked provisional")
            for name in sorted(desk_tokens or {}):
                if name not in new:
                    self.problems.append("token %s is in kit/k1/tokens_flat.json but not in the harness dump" % name)
                elif not same_value(desk_tokens[name], new[name]):
                    self.problems.append("token %s: kit/k1/tokens_flat.json says %r, the harness dump says %r" % (
                        name, desk_tokens[name], new[name]))
        added = changed = 0
        for name in sorted(new):
            if not re.fullmatch(r"[A-Za-z0-9_]+", name):
                self.problems.append("token name %r is not a valid attribute name" % name)
                continue
            if name not in old:
                before, added = None, added + 1
            elif not same_value(old[name], new[name]):
                before, changed = old[name], changed + 1
            else:
                continue
            self.attributes.append({"id": "token." + name, "kind": "attribute", "path": CONFIG_UI + ["Pulse"],
                                    "key": name, "before": before, "after": new[name]})
        gone = sorted(set(old) - set(new) - {"PerfDebug"}) if os.path.isfile(file) else []   # K1's file lists new tokens only
        self.notes.append("token attributes: %d new, %d changed, %d unchanged%s" % (
            added, changed, len(new) - added - changed,
            "; no longer in Tokens.Flatten and left on the folder: " + ", ".join(gone) if gone else ""))

    # --------------------------------------------------------------------------------------------------- family
    def build_family(self):
        family_dir = self.layout.family_dir(self.unit)
        if not os.path.isdir(family_dir):
            raise ToolError("families/%s does not exist" % self.unit, [family_dir])
        for name in FAMILY_FILES:
            if not common.document_present(family_dir, name):
                self.missing("families/%s/%s is missing (API2 6.1; %s_a / _b also read)" % (self.unit, name, name[:-3]))
        for base in ("contract", "spec_ops", "routes"):
            if not common.fragments(family_dir, base):
                self.missing("families/%s/%s.json is missing (also looked for _a, _b, _shared)" % (self.unit, base))
        records, fork_problems = build_forks.build(self.layout, self.unit)
        for problem in fork_problems:
            if "hand-assembled" in problem and "--forks-win" in self.options:
                self.warnings.append(problem + " (the fork build is installed)")
            else:
                self.problems.append("fork: " + problem)
        for record in records:
            self.notes.append("fork %s <- %s: %d spans, %d kept lines, %d new lines, hand-assembled copy: %s" % (
                common.short(record["path"]), record["source"].split(".")[-1], len(record["replaced"]),
                record["keptLines"], record["newLines"], record["handAssembled"]))
        sources, tests, _ = common.family_sources(self.layout, self.unit)
        if not sources:
            self.missing("families/%s/after has no .lua file" % self.unit)
        ops = self.family_ops(family_dir)
        other_creates = self.other_family_creates()
        used = set()
        for op in ops:
            dotted = ".".join(op["path"])
            where = "%s op %s" % (op["_file"], op.get("id") or dotted)
            kind = op.get("kind")
            if kind in ("attribute", "property", "tree"):
                self.problems.append("%s: a family installs no %s op (CONTRACT section 2: no config; API2 6.7)" % (where, kind))
                continue
            if kind == "create" and op.get("class") == "Folder":
                if folder_exists(self.chain, dotted):
                    self.notes.append("%s: folder %s already exists; op dropped" % (where, common.short(dotted)))
                else:
                    if isinstance(op.get("id"), str) and re.fullmatch(r"[A-Za-z0-9_.-]+", op["id"]):
                        self.folder_ids.setdefault(dotted, op["id"])
                    self.need_folders(dotted + ".x")
                continue
            if kind == "create" and op.get("class") != "ModuleScript":
                self.problems.append("%s: only Folder and ModuleScript are created by a family (class %r)" % (where, op.get("class")))
                continue
            if kind not in ("create", "source"):
                self.problems.append("%s: kind must be create or source" % where)
                continue
            expected_after = "after/%s.lua" % dotted
            if op.get("after") != expected_after:
                self.problems.append("%s: \"after\" must be %r (API2 6.1), found %r" % (where, expected_after, op.get("after")))
            if dotted not in sources:
                self.missing("%s: %s does not exist in families/%s/ (and no fork builds it)" % (where, expected_after, self.unit))
                continue
            installed = dotted in self.chain["scripts"] or dotted in common.classic_manifest()
            if kind == "create" and installed:
                self.problems.append("%s: COLLISION: %s already exists (%s); a create op cannot replace it" % (
                    where, dotted, self.chain["scripts"].get(dotted, {}).get("unit", "Classic baseline")))
                continue
            if kind == "source" and not installed:
                self.problems.append("%s: a source op needs an existing script; %s is neither Classic nor installed by an "
                                     "earlier unit" % (where, dotted))
                continue
            if kind == "create" and dotted in other_creates:
                self.problems.append("%s: COLLISION: families/%s also creates %s" % (where, other_creates[dotted], dotted))
                continue
            if kind == "source":
                agent_before = os.path.join(family_dir, "before", dotted + ".lua")
                classic_file = common.classic_source_file(dotted)
                if classic_file and not os.path.isfile(agent_before):
                    self.missing("%s: before/%s.lua is missing (a byte copy of classic/sources; API2 6.1)" % (where, dotted))
                elif classic_file and common.read_bytes(agent_before) != common.read_bytes(classic_file):
                    self.problems.append("%s: before/%s.lua is not a byte copy of classic/sources" % (where, dotted))
            used.add(dotted)
            given = op.get("id") if isinstance(op.get("id"), str) and re.fullmatch(r"[A-Za-z0-9_.-]+", op["id"]) else None
            self.add_script(dotted, common.read_bytes(sources[dotted]), sources[dotted], given)
        for dotted in sorted(set(sources) - used):
            if dotted == common.ROUTES_PATH:
                self.problems.append("after/%s.lua: Routes is generated by the integrator; remove the file" % dotted)
            else:
                self.problems.append("after/%s.lua has no op in spec_ops*.json" % dotted)
        for path, file in tests.items():
            if path not in sources and path not in self.chain["scripts"]:
                self.warnings.append("tests/%s_test.lua has no source in this unit or the chain" % path)
            self.tests[path] = common.read_bytes(file)
        for path in sorted(self.creates):
            leaf = path.split(".")[-1]
            if (leaf.endswith("Model") or leaf.endswith("View")) and path not in self.tests:
                self.warnings.append("no pure test for %s (API2 6.4)" % common.short(path))
        self.family_routes()

    def family_ops(self, family_dir):
        ops, seen = [], {}
        for name, data in common.fragments(family_dir, "spec_ops"):
            rows = data.get("ops") if isinstance(data, dict) else data
            if not isinstance(rows, list):
                self.problems.append("%s: must be a list of ops (or {\"ops\": [...]})" % name)
                continue
            for index, op in enumerate(rows):
                if not isinstance(op, dict) or not isinstance(op.get("path"), list) or len(op["path"]) < 2 \
                        or not all(isinstance(part, str) and part for part in op["path"]) or op["path"][0] not in common.ROOTS:
                    self.problems.append("%s: ops[%d] needs a \"path\" array starting at a service" % (name, index))
                    continue
                op = {key: value for key, value in op.items() if not key.startswith("_")}
                key = ".".join(op["path"])
                comparable = {k: v for k, v in op.items() if k != "id"}
                if key in seen:
                    if seen[key][1] != comparable:
                        self.problems.append("%s: op for %s differs from the one in %s" % (name, key, seen[key][0]))
                    continue
                seen[key] = (name, comparable)
                ops.append(dict(op, _file=name))
        return ops

    def other_family_creates(self):
        out = {}
        for family in common.FAMILIES:
            if family == self.unit or common.ORDER.index(family) < common.ORDER.index(self.unit):
                continue        # earlier units are in the chain already
            for _, data in common.fragments(self.layout.family_dir(family), "spec_ops"):
                rows = data.get("ops") if isinstance(data, dict) else data
                for op in rows if isinstance(rows, list) else []:
                    if isinstance(op, dict) and op.get("kind") == "create" and op.get("class") == "ModuleScript" \
                            and isinstance(op.get("path"), list):
                        out[".".join(op["path"])] = family
        return out

    def family_routes(self):
        try:
            text, data = gen_routes.generate(self.layout, self.unit)
        except ToolError as error:
            self.problems.append("Routes: " + error.title)
            self.problems.extend("Routes: " + line for line in error.lines)
            return
        targets = {row[2] for row in data["swap"]} | {row["path"] for row in data["add"]}
        if common.NOOP_PATH in targets:
            self.add_noop()
        will_exist = set(self.chain["scripts"]) | set(self.creates)
        for target in sorted(targets):
            if target not in will_exist:
                self.problems.append("Routes names %s, which no unit up to %s installs" % (target, self.unit))
        self.add_script(common.ROUTES_PATH, text.encode("utf-8"), "gen_routes.py", "Routes")
        if common.ROUTES_PATH not in self.sources:
            self.problems.append("Routes: the generated source equals the installed one; the family adds no route")
        self.tests[common.ROUTES_PATH] = gen_routes.generate_test(self.layout, self.unit).encode("utf-8")
        self.notes.append("Routes: families %s; %d swaps; %d added entries" % (
            ", ".join(data["families"]), len(data["swap"]), len(data["add"])))

    # ----------------------------------------------------------------------------------------------------- flip
    def build_flip(self):
        self.attributes.append({"id": "attr.UIStyle.flip", "kind": "attribute", "path": CONFIG_UI, "key": "UIStyle",
                                "before": "Classic", "after": "Pulse"})
        self.notes.append("the flip: Config.UI@UIStyle Classic -> Pulse. Run only when Oscar asks (CONTRACT section 5).")

    # ---------------------------------------------------------------------------------------------------- write
    def spec(self, verify_path):
        ops = []
        for dotted in sorted(self.folders, key=lambda d: (d.count("."), d)):
            ops.append({"id": self.folder_ids.get(dotted) or "folder." + op_id(dotted.split(".")), "kind": "create",
                        "class": "Folder", "path": dotted.split(".")})
        for path in sorted(self.creates, key=source_rank):
            ops.append({"id": self.creates[path][1], "kind": "create", "class": "ModuleScript", "path": path.split("."),
                        "after": "after/%s.lua" % path})
        ops.extend(self.attributes)
        for path in sorted(self.sources, key=source_rank):
            _, _, klass, ident = self.sources[path]
            ops.append({"id": ident, "kind": "source", "class": klass, "path": path.split("."),
                        "before": "before/%s.lua" % path, "after": "after/%s.lua" % path})
        ids = [op["id"] for op in ops]
        for ident in sorted({i for i in ids if ids.count(i) > 1}):
            self.problems.append("op id %s is used twice; give the ops distinct ids in spec_ops.json" % ident)
        spec = {
            "_note": "GENERATED by phase2/tools/assemble.py for unit %s. Do not edit by hand. Op ids become install "
                     "marks (\"%s:<id>\"): do not rename one after the first APPLY." % (self.unit, self.folder),
            "phase": self.folder,
            "classicVerify": verify_path,
            "installable": self.installable,
            "ops": ops,
        }
        if self.provisional:
            spec["_provisional"] = self.provisional
        return spec

    def after_chain(self):
        """Every script once this unit is applied: {path: (bytes, class, unit label, changed here: create|source|None)}."""
        out = {}
        for path, item in self.chain["scripts"].items():
            out[path] = (common.read_bytes(item["file"]), item["class"], item["unit"], None)
        for path, (data, _) in self.creates.items():
            out[path] = (data, "ModuleScript", self.folder, "create")
        for path, (_, data, klass, _) in self.sources.items():
            out[path] = (data, klass, self.folder, "source")
        return out

    def declared(self, scripts_after):
        base = common.read_json(PHASE1_DECLARED)
        declared = {"scripts": {}, "addedScripts": {}, "configNodes": list(base.get("configNodes", [])),
                    "configAttrs": list(base.get("configAttrs", []))}
        # Config changes made on purpose after Phase 1 (loading artwork and the like): phase2/declared_config.json.
        extra_file = os.path.join(common.PHASE2, "declared_config.json")
        if os.path.exists(extra_file):
            extra = common.read_json(extra_file)
            for key in ("configNodes", "configAttrs", "configChanged"):
                declared.setdefault(key, [])
                declared[key] += [item for item in extra.get(key, []) if item not in declared[key]]
            # Scripts other deliveries added beside this chain (radio and the like): listed, never pinned here.
            self.extra_added = dict(extra.get("addedScripts", {}))
        manifest = common.classic_manifest()
        for path in sorted(scripts_after):
            data, klass, _, changed = scripts_after[path]
            pin = {"length": len(data), "djb2": common.djb2(data), "fnv1a32": common.fnv1a32(data)}
            if path in manifest:
                declared["scripts"][path] = pin
            elif changed == "source":
                # The verify pins one hash per added script. This install changes the script, so AUDIT must pass with
                # the old source (before APPLY, after ROLLBACK) and the new one: left unpinned here, pinned by the next
                # unit. The installer itself checks both fingerprints.
                declared["addedScripts"][path] = {"class": klass, "_unpinned": "changed by %s" % self.folder}
            else:
                declared["addedScripts"][path] = dict(pin, **{"class": klass})
        for path, klass in getattr(self, "extra_added", {}).items():
            declared["addedScripts"].setdefault(path, {"class": klass})
        return declared

    def test_manifest(self, scripts_after):
        def ref(file):
            return common.repo_relative(file) or os.path.abspath(file).replace(os.sep, "/")

        sources = []
        for path in sorted(scripts_after, key=source_rank):
            _, klass, unit_label, changed = scripts_after[path]
            if changed:
                file = os.path.join(self.out, "after", path + ".lua")
            else:
                file = self.chain["scripts"][path]["file"]
            sources.append({"path": path, "file": ref(file), "unit": unit_label, "class": klass,
                            "classic": path in common.classic_manifest()})
        tests = []
        merged = {path: (item["file"], item["unit"]) for path, item in self.chain["tests"].items()}
        for path in self.tests:
            merged[path] = (os.path.join(self.out, "tests", path + "_test.lua"), self.folder)
        for path in sorted(merged, key=source_rank):
            if path in scripts_after:
                tests.append({"path": path, "file": ref(merged[path][0]), "unit": merged[path][1]})
        words = set()
        for path, (data, _, _, _) in scripts_after.items():
            if path.startswith(common.UIP_DOT) or path not in common.classic_manifest():
                words.update(re.findall(rb"[A-Za-z_][A-Za-z0-9_]*", data))
        classic = []
        import lint_phase2
        wanted = lint_phase2.SHARED | lint_phase2.ACTIVITY_VIEWS | set(SHARED_WORDS)
        for path in sorted(common.classic_manifest()):
            leaf = path.split(".")[-1]
            is_core = path.startswith("ReplicatedStorage.Modules.Core.")
            if path in scripts_after or common.classic_manifest()[path]["class"] != "ModuleScript":
                continue
            if (leaf in wanted or is_core) and leaf.encode() in words:
                classic.append({"path": path, "file": ref(common.classic_source_file(path))})
        required = [path for path in sorted(set(self.creates) | set(self.sources))
                    if path == common.ROUTES_PATH or common.short(path).startswith("Kit.")
                    or path.endswith("Model") or path.endswith("View")]
        return {"_note": "GENERATED by phase2/tools/assemble.py. Read by tools/run_tests_phase2.lua through the bridge.",
                "unit": self.folder, "sources": sources, "tests": tests, "classic": classic, "requiredTests": required,
                "layersPath": common.UIP_DOT + "Kit.Layers", "tokensPath": common.UIP_DOT + "Kit.Tokens",
                "latchPath": common.LATCH_PATH, "scopePath": "ReplicatedStorage.Modules.Core.ConnectionScope"}

    def write(self):
        for name in ("after", "before", "tests"):
            folder = os.path.join(self.out, name)
            if os.path.isdir(folder):
                shutil.rmtree(folder)
        os.makedirs(self.out, exist_ok=True)
        for path, (data, _) in self.creates.items():
            common.write_bytes(os.path.join(self.out, "after", path + ".lua"), data)
        for path, (before, data, _, _) in self.sources.items():
            common.write_bytes(os.path.join(self.out, "after", path + ".lua"), data)
            common.write_bytes(os.path.join(self.out, "before", path + ".lua"), before)
        for path, data in self.tests.items():
            common.write_bytes(os.path.join(self.out, "tests", path + "_test.lua"), data)
        scripts_after = self.after_chain()
        verify_name = "out_verify_classic_%s.lua" % self.folder
        verify_file = os.path.join(self.out, verify_name)
        verify_ref = common.repo_relative(verify_file) or verify_file.replace(os.sep, "/")
        spec = self.spec(verify_ref)
        if self.problems:
            return None
        common.write_json(os.path.join(self.out, "spec.json"), spec)
        common.write_json(os.path.join(self.out, "declared.json"), self.declared(scripts_after))
        common.write_json(os.path.join(self.out, "test_manifest.json"), self.test_manifest(scripts_after))
        done = subprocess.run([sys.executable, os.path.join(common.CLASSIC, "build_verify.py"), "--declared",
                               os.path.join(self.out, "declared.json"), "--out", verify_file],
                              capture_output=True, text=True, cwd=common.CLASSIC)
        if done.returncode != 0:
            raise ToolError("classic/build_verify.py failed for %s" % self.folder,
                            (done.stdout + done.stderr).strip().splitlines()[-6:])
        self.notes.append("Classic verify: " + done.stdout.strip())
        return spec

    def record(self):
        state = load_state(self.layout)
        dropped = [common.unit_folder(later) for later in common.ORDER[common.ORDER.index(self.unit) + 1:]
                   if common.unit_folder(later) in state["units"]]
        for folder in dropped:
            del state["units"][folder]
        scripts = {}
        for path, (data, _) in self.creates.items():
            scripts[path] = {"file": "%s/after/%s.lua" % (self.folder, path), "fp": common.fingerprint(data),
                             "class": "ModuleScript", "kind": "create"}
        for path, (_, data, klass, _) in self.sources.items():
            scripts[path] = {"file": "%s/after/%s.lua" % (self.folder, path), "fp": common.fingerprint(data),
                             "class": klass, "kind": "source", "classic": path in common.classic_manifest()}
        state["_note"] = "GENERATED by phase2/tools/assemble.py: the install chain. Do not edit."
        state["units"][self.folder] = {
            "unit": self.unit, "scripts": scripts, "folders": list(self.folders),
            "tests": {path: "%s/tests/%s_test.lua" % (self.folder, path) for path in self.tests},
            "installable": self.installable, "provisional": self.provisional}
        common.write_json(self.layout.state_path(), state)
        return dropped


def same_value(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return set(a) == set(b) and all(same_value(a[k], b[k]) for k in a)
    if isinstance(a, bool) or isinstance(b, bool) or isinstance(a, str) or isinstance(b, str):
        return a == b and type(a) is type(b)
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) <= 1e-9
    return a == b


def run_engine(build):
    """Runs engine/build.py on the phase folder. A folder outside the repository (tests) is built with a stand-in base."""
    sys.path.insert(0, common.ENGINE)
    import build as engine
    base = None if common.repo_relative(build.out) else "scripts/ui_restyle/phase2/install/%s/" % build.folder
    try:
        out, ops, lines = engine.emit(build.out, base=base)
    except engine.SpecError as error:
        raise ToolError("engine/build.py refused %s/spec.json" % build.folder, [str(error)])
    return out, ops, lines


def assemble(layout, unit, options):
    if unit not in common.ORDER:
        raise ToolError("unknown unit %r" % unit, ["units: " + ", ".join(common.ORDER)])
    build = Build(layout, unit, options)
    if unit == "kit":
        build.build_kit()
    elif unit == "flip":
        build.build_flip()
    else:
        build.build_family()
    if not (build.creates or build.sources or build.attributes) and not build.problems:
        build.problems.append("nothing to install: the unit has no op")
    spec = None if build.problems else build.write()
    if build.problems:
        raise ToolError("%s cannot be assembled (%d problem(s))" % (build.folder, len(build.problems)),
                        build.problems + ["warning: " + w for w in build.warnings])
    result = {"build": build, "spec": spec, "engine": None, "dropped": []}
    if "--no-build" not in options:
        result["engine"] = run_engine(build)
    result["dropped"] = build.record()
    return result


def main(argv):
    layout, positional, options = common.parse_args(
        argv, flags=("--partial", "--no-build", "--noop-on-first-need", "--forks-win"))
    if len(positional) != 1:
        print(__doc__)
        return 2
    result = assemble(layout, positional[0], options)
    build, spec = result["build"], result["spec"]
    kinds = {}
    for op in spec["ops"]:
        label = "create Folder" if op.get("class") == "Folder" else op["kind"] + (" ModuleScript" if op["kind"] == "create" else "")
        kinds[label] = kinds.get(label, 0) + 1
    print("%s assembled in %s" % (build.folder, build.out))
    print("  ops: %d (%s)" % (len(spec["ops"]), ", ".join("%d %s" % (count, label) for label, count in sorted(kinds.items()))))
    for note in build.notes:
        print("  note: " + note)
    for warning in build.warnings:
        print("  WARNING: " + warning)
    if result["engine"]:
        out, ops, lines = result["engine"]
        print("  engine/build.py: %d ops; offline dry run APPLY, ROLLBACK, APPLY passed (%d steps); %s" % (
            len(ops), len(lines), ", ".join("%s %d chars" % (name, len(text)) for name, text in sorted(out.items()))))
    else:
        print("  engine/build.py was NOT run (--no-build)")
    for folder in result["dropped"]:
        print("  WARNING: %s was assembled against the old chain and has been dropped from state.json; assemble it again" % folder)
    if build.provisional:
        print("PROVISIONAL (spec.installable is false):")
        for line in build.provisional:
            print("  - " + line)
        return 3
    return 0


if __name__ == "__main__":
    common.run_main(main)
