#!/usr/bin/env python3
"""Offline tests for the wave-2 integration tools, on a throw-away tree (never the agents' folders).

    py -3 test_tools.py

Builds, in a temporary directory, a tiny kit (one changed Phase 1 module, one new module) and a tiny fake family
"race_menu" (model, client, a fork of a small Classic script, fragments), then drives gen_routes, build_forks,
assemble (with the real engine/build.py and classic/build_verify.py), parity_check and status against it.
"""
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
import assemble  # noqa: E402
import build_forks  # noqa: E402
import gen_routes  # noqa: E402
import lint_phase2  # noqa: E402
import parity_check  # noqa: E402
import status  # noqa: E402

UIP = common.UIP_DOT
TOKENS = UIP + "Kit.Tokens"
SPRITES = UIP + "Kit.Sprites"
MODEL = UIP + "RaceMenu.RaceMenuModel"
CLIENT = UIP + "RaceMenu.RaceMenuClient"
FORK = UIP + "RaceMenu.ExitFork"
FORK_SOURCE = "ReplicatedStorage.Modules.Game.UI.FreeRoamVehicleExitButtonClient"


def header(path, phase="phase2"):
    return "-- Owns a test sample; nothing else.\n-- Pulse UI (%s). %s. Requires: none.\n" % (phase, path)


MODEL_SOURCE = header(MODEL) + """local Model = {}
local function call(remote, action, payload)
	return pcall(function()
		return remote:InvokeServer(action, payload)
	end)
end
function Model.new(deps)
	local self = {}
	function self.Teleport(eventId, mode)
		return call(deps.Remotes.Teleport, "TeleportToRaceStart", { EventId = eventId, Mode = mode })
	end
	function self.Opened()
		deps.Bindables.FreeRoamHudPresentationMode:Fire({ Owner = "RaceBrowser", Active = true, KeepTelemetry = false })
	end
	return self
end
return Model
"""
CLIENT_SOURCE = header(CLIENT) + """local Layers = require(script.Parent.Parent.Kit.Layers)
local Model = require(script.Parent.RaceMenuModel)
local Client = {}
function Client.start()
	Layers.Switch().Claim("RaceBrowser")
	Client.Layer = Layers.Create("RaceBrowser", { Frame = "Menu" })
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing")
	Client.Model = Model.new({ Remotes = { Teleport = remotes:WaitForChild("RaceBrowserTeleportInvoke") } })
	Client.Marks = { "CardContent", "TeleportToStart" }
end
return Client
"""
CONTRACT = [{
    "owner": CLIENT, "replaces": ["RaceBrowserClient"],
    "screenGuis": [{"name": "RaceBrowser", "displayOrder": 170}],
    "remotes": [{"remote": "Remotes.Racing.RaceBrowserTeleportInvoke", "kind": "invoke",
                 "action": "TeleportToRaceStart", "keys": ["EventId", "Mode"]}],
    "listens": [],
    "bindables": [{"name": "Runtime.UI.FreeRoamHudPresentationMode", "dir": "fire",
                   "keys": ["Owner", "Active", "KeepTelemetry"]}],
    "attributes": [], "names": ["CardContent", "TeleportToStart"], "contextActions": [], "renderSteps": [], "audio": [],
    "dropped": [], "added": [],
}]


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


class Tree:
    def __init__(self, root):
        self.root = root
        self.layout = common.Layout(kit=os.path.join(root, "kit"), families=os.path.join(root, "families"),
                                    install=os.path.join(root, "install"), integrator=os.path.join(root, "integrator"))
        shutil.copy(os.path.join(common.PHASE2, "integrator", "UIPulse.NoOp.lua"),
                    os.path.join(self.make(self.layout.integrator), "UIPulse.NoOp.lua"))
        tokens = common.read_text(os.path.join(common.PHASE1, "after", TOKENS + ".lua"))
        write(os.path.join(self.layout.kit, "k1", "after", TOKENS + ".lua"), tokens + "-- wave 2 test edit\n")
        write(os.path.join(self.layout.kit, "k1", "after", SPRITES + ".lua"), header(SPRITES) + "return {}\n")
        write(os.path.join(self.layout.kit, "k1", "tests", SPRITES + "_test.lua"),
              "return function(M, env)\n\treturn { { name = \"loads\", ok = type(M) == \"table\" } }\nend\n")
        for agent in ("k2", "k3", "k4"):
            self.make(os.path.join(self.layout.kit, agent, "after"))
        self.family = self.layout.family_dir("race_menu")
        write(os.path.join(self.family, "CONTRACT.md"), "# test\n")
        write(os.path.join(self.family, "NOTES.md"), "# test\n")
        write(os.path.join(self.family, "after", MODEL + ".lua"), MODEL_SOURCE)
        write(os.path.join(self.family, "after", CLIENT + ".lua"), CLIENT_SOURCE)
        write(os.path.join(self.family, "tests", MODEL + "_test.lua"), "return function(M, env)\n\treturn {}\nend\n")
        write(os.path.join(self.family, "forks", "ExitFork.header.lua"), header(FORK) + "-- new line\n")
        self.put_json("forks/ExitFork.json", {"source": FORK_SOURCE, "module": FORK,
                                              "replace": [{"lines": [1, 2], "with": "ExitFork.header.lua"}]})
        self.put_json("routes.json", {"family": "RaceMenu", "swap": {"RaceBrowserClient": CLIENT}, "add": []})
        self.put_json("contract.json", CONTRACT)
        self.ops = [
            {"id": "rm", "kind": "create", "class": "Folder", "path": (UIP + "RaceMenu").split(".")},
            {"id": "rm.model", "kind": "create", "class": "ModuleScript", "path": MODEL.split("."), "after": "after/%s.lua" % MODEL},
            {"id": "rm.client", "kind": "create", "class": "ModuleScript", "path": CLIENT.split("."), "after": "after/%s.lua" % CLIENT},
            {"id": "rm.fork", "kind": "create", "class": "ModuleScript", "path": FORK.split("."), "after": "after/%s.lua" % FORK},
        ]
        self.put_json("spec_ops.json", self.ops)

    @staticmethod
    def make(folder):
        os.makedirs(folder, exist_ok=True)
        return folder

    def put_json(self, name, value):
        write(os.path.join(self.family, *name.split("/")), json.dumps(value, indent=1) + "\n")


class ToolsTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.mkdtemp(prefix="pulse_tools_")
        self.tree = Tree(self.folder)
        self.layout = self.tree.layout

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)

    def spec(self, unit):
        return common.read_json(os.path.join(self.layout.unit_dir(unit), "spec.json"))

    # ------------------------------------------------------------------------------------------------ gen_routes
    def test_routes_phase1_is_the_installed_source(self):
        text, data = gen_routes.generate(self.layout, "phase1")
        self.assertEqual(text.encode("utf-8"), common.read_bytes(gen_routes.TEMPLATE))
        self.assertEqual(data["families"], ["Toasts"])

    def test_routes_with_one_family_changes_only_the_tables(self):
        text, data = gen_routes.generate(self.layout, "race_menu")
        installed = common.read_text(gen_routes.TEMPLATE).split("\n")
        made = text.split("\n")
        self.assertEqual(len(made), len(installed) + 1)                   # one swap row more
        changed = [line for line in made if line not in installed]
        self.assertEqual(changed, ['Routes.Families = { "Toasts", "RaceMenu" }',
                                   '\tRaceBrowserClient = { Family = "RaceMenu", Path = "%s" },' % CLIENT])
        start = installed.index("local composedPaths = nil -- entry name -> path, set by a successful Compose")
        self.assertEqual(made[made.index(installed[start]):], installed[start:])     # Compose, Resolve, StartWatch
        test = gen_routes.generate_test(self.layout, "race_menu")
        self.assertIn(common.read_text(gen_routes.PHASE1_TEST), test)
        self.assertNotIn("@@", test)

    def test_routes_problems_are_listed(self):
        self.tree.put_json("routes.json", {"family": "Garage", "swap": {"NoSuchEntry": "Workspace.X", "RaceBrowserClient": CLIENT},
                                           "add": [{"name": "PulseX", "path": UIP + "X.Y", "dependencies": ["Ghost"]}]})
        with self.assertRaises(common.ToolError) as caught:
            gen_routes.generate(self.layout, "race_menu")
        text = "\n".join(caught.exception.lines)
        for needle in ("family is 'Garage'", "not a ClientBase entry", "must be a dotted path under", "dependency Ghost"):
            self.assertIn(needle, text)
        with self.assertRaises(common.ToolError):
            gen_routes.generate(self.layout, "free_roam")                 # free_roam has no routes.json

    # ----------------------------------------------------------------------------------------------- build_forks
    def test_fork_build_and_hand_assembled_copy(self):
        records, problems = build_forks.build(self.layout, "race_menu")
        self.assertEqual(problems, [])
        record = records[0]
        self.assertEqual((record["path"], record["handAssembled"], record["newRanges"]), (FORK, "absent", [[1, 3]]))
        built = common.read_text(os.path.join(self.layout.forks_out("race_menu"), "after", FORK + ".lua"))
        classic = common.read_text(common.classic_source_file(FORK_SOURCE)).split("\n")
        self.assertEqual(built.split("\n")[3:], classic[2:])              # every kept line, byte for byte
        self.assertTrue(built.startswith(header(FORK) + "-- new line\n"))
        write(os.path.join(self.tree.family, "after", FORK + ".lua"), built)
        records, problems = build_forks.build(self.layout, "race_menu")
        self.assertEqual((records[0]["handAssembled"], problems), ("match", []))
        write(os.path.join(self.tree.family, "after", FORK + ".lua"), built.replace("-- new line", "-- other line"))
        records, problems = build_forks.build(self.layout, "race_menu")
        self.assertEqual(records[0]["handAssembled"], "differs")
        self.assertEqual(records[0]["firstDifference"]["line"], 3)
        self.assertEqual(len(problems), 1)

    def test_fork_problems(self):
        self.tree.put_json("forks/ExitFork.json", {"source": FORK_SOURCE, "module": FORK, "replace": [
            {"lines": [5, 9], "with": "ExitFork.header.lua"}, {"lines": [8, 9], "with": "missing.lua"}]})
        self.tree.put_json("forks/Bad.json", {"source": "Nope.Nope", "replace": []})
        records, problems = build_forks.build(self.layout, "race_menu", write=False)
        text = "\n".join(problems)
        self.assertEqual(records, [])
        self.assertIn("out of order", text)
        self.assertIn("not a script of classic/manifest.json", text)

    # -------------------------------------------------------------------------------------------------- assemble
    def test_assemble_kit_then_family_and_the_chain(self):
        result = assemble.assemble(self.layout, "kit", {"--partial": True})
        build = result["build"]
        self.assertFalse(build.installable)                               # no tokens file: provisional
        spec = self.spec("kit")
        kinds = [(op["id"], op["kind"]) for op in spec["ops"] if op["kind"] != "attribute"]
        self.assertEqual(kinds, [("NoOp", "create"), ("Kit.Sprites", "create"), ("Kit.Tokens", "source")])
        assets = [op for op in spec["ops"] if op["id"].startswith("asset.")]
        self.assertEqual(len(assets), 31)
        self.assertEqual(sum(1 for op in assets if op["before"] is None), 16)
        self.assertTrue(all(op["after"].startswith("rbxassetid://") for op in assets))
        kit_dir = self.layout.unit_dir("kit")
        self.assertEqual(common.read_bytes(os.path.join(kit_dir, "before", TOKENS + ".lua")),
                         common.read_bytes(os.path.join(common.PHASE1, "after", TOKENS + ".lua")))
        for name in ("out_audit.lua", "out_apply.lua", "out_rollback.lua", "out_verify_classic_00_kit.lua",
                     "declared.json", "test_manifest.json", "applied_hashes.json"):
            self.assertTrue(os.path.isfile(os.path.join(kit_dir, name)), name)
        declared = common.read_json(os.path.join(kit_dir, "declared.json"))
        self.assertNotIn("length", declared["addedScripts"][TOKENS])      # changed here: left unpinned
        self.assertIn("length", declared["addedScripts"][SPRITES])
        self.assertIn("length", declared["addedScripts"][UIP + "Kit.Metrics"])     # Phase 1, untouched: pinned
        self.assertIn(common.CLIENTBASE_PATH, declared["scripts"])
        manifest = common.read_json(os.path.join(kit_dir, "test_manifest.json"))
        paths = [row["path"] for row in manifest["sources"]]
        self.assertLess(paths.index(SPRITES), paths.index(TOKENS))        # dependency order
        self.assertIn(SPRITES, [row["path"] for row in manifest["tests"]])
        self.assertTrue(any(row["path"] == TOKENS and row["file"].endswith("00_kit/after/%s.lua" % TOKENS)
                            for row in manifest["sources"]))

        result = assemble.assemble(self.layout, "race_menu", {})
        spec = self.spec("race_menu")
        self.assertEqual([(op["id"], op["kind"], op.get("class")) for op in spec["ops"]], [
            ("rm", "create", "Folder"), ("rm.fork", "create", "ModuleScript"), ("rm.client", "create", "ModuleScript"),
            ("rm.model", "create", "ModuleScript"), ("Routes", "source", "ModuleScript")])
        family_dir = self.layout.unit_dir("race_menu")
        self.assertEqual(common.read_bytes(os.path.join(family_dir, "before", common.ROUTES_PATH + ".lua")),
                         common.read_bytes(gen_routes.TEMPLATE))
        self.assertTrue(os.path.isfile(os.path.join(family_dir, "tests", common.ROUTES_PATH + "_test.lua")))
        declared = common.read_json(os.path.join(family_dir, "declared.json"))
        self.assertIn("length", declared["addedScripts"][TOKENS])         # the kit's change is now pinned
        self.assertNotIn("length", declared["addedScripts"][common.ROUTES_PATH])
        self.assertIn(CLIENT, declared["addedScripts"])
        state = common.read_json(self.layout.state_path())
        self.assertEqual(sorted(state["units"]), ["00_kit", "01_race_menu"])
        # a later unit's before for Routes is this unit's after
        chain = assemble.load_chain(self.layout, "free_roam")
        self.assertTrue(chain["scripts"][common.ROUTES_PATH]["file"].endswith(
            os.path.join("01_race_menu", "after", common.ROUTES_PATH + ".lua")))
        # reassembling the kit drops the family from the chain
        result = assemble.assemble(self.layout, "kit", {"--partial": True})
        self.assertEqual(result["dropped"], ["01_race_menu"])
        with self.assertRaises(common.ToolError) as caught:
            assemble.load_chain(self.layout, "free_roam")
        self.assertIn("01_race_menu has not been assembled", "\n".join(caught.exception.lines))

    def test_assemble_needs_the_previous_unit(self):
        with self.assertRaises(common.ToolError) as caught:
            assemble.assemble(self.layout, "race_menu", {})
        self.assertIn("00_kit has not been assembled", "\n".join(caught.exception.lines))

    def test_assemble_lists_missing_files_and_collisions(self):
        with self.assertRaises(common.ToolError) as caught:
            assemble.assemble(self.layout, "kit", {})                     # not --partial: the kit is incomplete
        text = "\n".join(caught.exception.lines)
        self.assertIn("Kit.Gauge is not in any kit/k*/after folder", text)
        assemble.assemble(self.layout, "kit", {"--partial": True})
        os.remove(os.path.join(self.tree.family, "NOTES.md"))
        os.remove(os.path.join(self.tree.family, "after", MODEL + ".lua"))
        write(os.path.join(self.tree.family, "after", UIP + "RaceMenu.Stray.lua"), header(UIP + "RaceMenu.Stray") + "return {}\n")
        self.tree.put_json("spec_ops.json", self.tree.ops + [
            {"id": "clash", "kind": "create", "class": "ModuleScript", "path": TOKENS.split("."), "after": "after/%s.lua" % TOKENS},
            {"id": "cfg", "kind": "attribute", "path": ["ReplicatedStorage", "Config", "UI"], "key": "X", "before": None, "after": 1}])
        write(os.path.join(self.tree.family, "after", TOKENS + ".lua"), header(TOKENS) + "return {}\n")
        other = self.layout.family_dir("garage")
        write(os.path.join(other, "spec_ops.json"), json.dumps([
            {"id": "g", "kind": "create", "class": "ModuleScript", "path": CLIENT.split("."), "after": "after/x.lua"}]))
        with self.assertRaises(common.ToolError) as caught:
            assemble.assemble(self.layout, "race_menu", {})
        text = "\n".join(caught.exception.lines)
        for needle in ("NOTES.md is missing", "RaceMenuModel.lua does not exist", "Stray.lua has no op",
                       "COLLISION: %s already exists (00_kit)" % TOKENS, "a family installs no attribute op",
                       "COLLISION: families/garage also creates %s" % CLIENT):
            self.assertIn(needle, text)
        self.assertNotIn("01_race_menu", common.read_json(self.layout.state_path())["units"])

    def test_tokens_file_makes_the_kit_installable(self):
        old = common.read_json(os.path.join(common.PHASE1, "tokens_flat.json"))["tokens"]
        tokens = dict(old, SpaceNewThing=12, ScaleRegularDp=1.25)
        tokens["CapBody"] = old["CapBody"] + 1
        write(os.path.join(self.layout.integrator, "tokens_flat.json"), json.dumps({"provisional": False, "tokens": tokens}))
        result = assemble.assemble(self.layout, "kit", {"--partial": True})
        self.assertTrue(result["build"].installable)
        ops = {op["id"]: op for op in self.spec("kit")["ops"] if op["id"].startswith("token.")}
        self.assertEqual(sorted(ops), ["token.CapBody", "token.ScaleRegularDp", "token.SpaceNewThing"])
        self.assertEqual((ops["token.CapBody"]["before"], ops["token.CapBody"]["after"]), (old["CapBody"], old["CapBody"] + 1))
        self.assertIsNone(ops["token.SpaceNewThing"]["before"])

    # ------------------------------------------------------------------------------------------- parity and lint
    def test_parity_check(self):
        build_forks.build(self.layout, "race_menu")
        result = parity_check.check(self.layout, "race_menu")
        rows = {(r["category"], r["item"], r["status"]) for r in result["owners"][0]["rows"]}
        self.assertIn(("bindable", "OpenRaceBrowser", "missing"), rows)
        self.assertNotIn(("remote action", "TeleportToRaceStart", "missing"), rows)
        self.assertEqual(result["code"], [])                              # the declaration matches the code
        self.assertGreater(result["open"], 0)
        # covering a row needs the key word and a section reference
        contract = json.loads(json.dumps(CONTRACT))
        contract[0]["dropped"] = [{"item": "OpenRaceBrowser listener", "reason": "test, API2 5.2"}]
        self.tree.put_json("contract.json", contract)
        after = parity_check.check(self.layout, "race_menu")
        row = next(r for r in after["owners"][0]["rows"] if r["item"] == "OpenRaceBrowser")
        self.assertTrue(row["coveredBy"].startswith("dropped"))
        self.assertEqual(after["open"], result["open"] - 1)
        # a declaration that does not match the code is caught, both ways
        contract[0]["remotes"][0]["keys"] = ["EventId"]
        contract[0]["bindables"] = []
        contract[0]["attributes"] = [{"on": "Player", "name": "NeverWritten", "dir": "write"}]
        self.tree.put_json("contract.json", contract)
        code = {(r["category"], r["item"], r["status"]) for r in parity_check.check(self.layout, "race_menu")["code"]}
        self.assertIn(("payload key", "TeleportToRaceStart: Mode", "undeclared"), code)
        self.assertIn(("bindable fire", "FreeRoamHudPresentationMode", "undeclared"), code)
        self.assertIn(("attribute", "NeverWritten", "not in code"), code)

    def test_lint_unit_and_status(self):
        build_forks.build(self.layout, "race_menu")
        known, entries = lint_phase2.all_known(self.layout)
        self.assertIn("RaceMenu.RaceMenuClient", entries)
        result = lint_phase2.lint_unit(self.layout, "race_menu", known, entries)
        self.assertEqual(result["files"], 3)
        open_rules = sorted({f.rule for f in result["findings"] if lint_phase2.is_open(f)})
        self.assertNotIn("header", open_rules)                            # the fork's header span is new code
        self.assertNotIn("remote-action", open_rules)
        fork_findings = [f for f in result["findings"] if f.file.startswith(FORK)]
        self.assertTrue(all(f.line > 3 or not f.exempt for f in fork_findings))
        assemble.assemble(self.layout, "kit", {"--partial": True})
        state = common.read_json(self.layout.state_path())
        row = status.unit_row(self.layout, "race_menu", known, entries, state)
        self.assertEqual((row["sources"], row["missing"], row["assembled"]), (3, [], "no"))
        self.assertTrue(row["forks"].startswith("1 of 1 built"))
        self.assertEqual(status.unit_row(self.layout, "kit", known, entries, state)["assembled"], "provisional")


if __name__ == "__main__":
    import warnings
    unittest.main(warnings="ignore")       # engine/build.py leaves its output files to the garbage collector
