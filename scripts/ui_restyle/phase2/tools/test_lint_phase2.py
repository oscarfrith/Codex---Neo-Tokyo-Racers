#!/usr/bin/env python3
"""Tests for lint_phase2.py.   py -3 test_lint_phase2.py"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lint_phase2 as L  # noqa: E402

UIP = "ReplicatedStorage.Modules.Game.UIPulse."
KNOWN = {"Kit.Tokens": "kit", "Kit.Layers": "kit", "Kit.Data": "kit", "Kit.Presence": "kit", "Kit.Text": "kit",
         "Kit.Perf": "kit", "Routes": "phase1", "RaceMenu.RaceMenuModel": "race_menu",
         "RaceMenu.RaceMenuView": "race_menu", "RaceMenu.RaceMenuClient": "race_menu",
         "WorldMap.FullMapClient": "world_map", "WorldMap.FullMapModel": "world_map"}
ENTRIES = {"RaceMenu.RaceMenuClient", "WorldMap.FullMapClient"}


def src(module, body, phase="phase2", requires="none"):
    return "-- Owns a sample; nothing else.\n-- Pulse UI (%s). %s%s. Requires: %s.\n%s" % (phase, UIP, module, requires, body)


def context(owners=("RaceBrowserClient",), forks=None):
    return L.Context(unit="race_menu", known=dict(KNOWN), entries=set(ENTRIES),
                     scope=L.remote_scope(list(owners)) if owners else None, forks=forks or {})


def lint(module, body, ctx=None, **kw):
    return L.lint_source(UIP + module + ".lua", src(module, body, **kw), None, ctx or context())


def rules(module, body, ctx=None, **kw):
    return sorted({f.rule for f in lint(module, body, ctx, **kw) if L.is_open(f)})


CLEAN_MODEL = """
local Presence = require(script.Parent.Parent.Kit.Presence)
local Model = {}
local function call(remote, action, payload)
	return pcall(function()
		return remote:InvokeServer(action, payload)
	end)
end
function Model.new(deps)
	local self = {}
	local changed = Instance.new("BindableEvent")
	self.Changed = changed.Event
	function self.Teleport(eventId, mode)
		local ok, reply = call(deps.Remotes.Teleport, "TeleportToRaceStart", { EventId = eventId, Mode = mode })
		if ok and type(reply) == "table" then
			changed:Fire("Teleport")
		end
	end
	function self.Open()
		Presence.Open("RaceBrowser")
	end
	return self
end
return Model
"""

CLEAN_CLIENT = """
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layers = require(script.Parent.Parent.Kit.Layers)
local Model = require(script.Parent.RaceMenuModel)
local View = require(script.Parent.RaceMenuView)
local Routes = require(script.Parent.Parent.Routes)
local RaceConfigReader = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceConfigReader"))
local Client = {}
function Client.start()
	Layers.Switch().Claim("RaceBrowser")
	local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Racing")
	local teleport = remotes:WaitForChild("RaceBrowserTeleportInvoke")
	local layer = Layers.Create("RaceBrowser", { Frame = "Menu" })
	local model = Model.new({ Remotes = { Teleport = teleport }, Reader = RaceConfigReader })
	View.Mount(layer, model)
	Routes.Resolve("FullMapUI")
end
return Client
"""


class Phase2Lint(unittest.TestCase):
    def test_clean_model_and_client(self):
        self.assertEqual(rules("RaceMenu.RaceMenuModel", CLEAN_MODEL), [])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", CLEAN_CLIENT), [])

    def test_header(self):
        self.assertIn("header", rules("RaceMenu.RaceMenuModel", "return {}", phase="phase1"))
        self.assertEqual(rules("Kit.Tokens", "return {}", phase="phase1"), [])      # an installed Phase 1 module
        self.assertEqual(rules("Kit.Tokens", "return {}", phase="phase2"), [])
        found = L.lint_source(UIP + "RaceMenu.X.lua", "local x = 1\nreturn x\n", None, context())
        self.assertEqual(sorted({f.rule for f in found}), ["header"])

    def test_kit_dependencies(self):
        self.assertEqual(rules("Kit.BigNumber", "local T = require(script.Parent.Text)\nreturn T"), ["dependency"])
        self.assertEqual(rules("Kit.BigNumber", "local T = require(script.Parent.Sprites)\nreturn T"), [])
        self.assertEqual(rules("Kit.Overlay", "local T = require(script.Parent.Gauge)\nreturn T"), ["dependency"])
        self.assertEqual(rules("Kit.Overlay", "local T = require(script.Parent.Data)\nreturn T"), [])
        self.assertIn("unknown-module", rules("Kit.Nope", "return {}"))

    def test_kit_data_may_require_the_foundation_only_there(self):
        body = ('local RS = game:GetService("ReplicatedStorage")\n'
                'local F = require(RS.Modules.Game.UI.ResponsiveUIFoundation)\nreturn F')
        self.assertEqual(rules("Kit.Data", body), [])
        self.assertIn("classic-require", rules("Kit.Text", body))
        self.assertIn("classic-require", rules("RaceMenu.RaceMenuClient", body))

    def test_shared_and_classic_requires(self):
        walk = 'local RS = game:GetService("ReplicatedStorage")\nlocal M = require(RS:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI"):WaitForChild("%s"))\nreturn M'
        self.assertEqual(rules("RaceMenu.RaceMenuClient", walk % "RouteGuide"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", walk % "GarageComponents"), ["classic-require"])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", walk % "MapIconLayer"), ["classic-require"])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", walk % "FullMapUI"), ["classic-require"])       # a Classic owner
        self.assertEqual(rules("Kit.Surface", walk % "RouteGuide"), ["classic-require"])                  # kit: never
        self.assertEqual(rules("RaceMenu.RaceMenuClient", walk % "NoSuchModule"), ["dependency"])

    def test_helper_require(self):
        body = ('local RS = game:GetService("ReplicatedStorage")\n'
                'local function shared(name)\n\tlocal ui = RS.Modules.Game:FindFirstChild("UI")\n\treturn require(ui:FindFirstChild(name))\nend\n'
                'local A = shared("%s")\nreturn A')
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body % "MapMath"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body % "UITheme"), ["classic-require"])

    def test_cross_entry_require(self):
        body = "local Other = require(script.Parent.Parent.WorldMap.FullMapClient)\nreturn Other"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body), ["cross-entry-require"])
        body = "local Other = require(script.Parent.Parent.WorldMap.FullMapModel)\nreturn Other"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body), [])

    def test_model_and_view_shape(self):
        self.assertEqual(rules("RaceMenu.RaceMenuModel", "local T = require(script.Parent.Parent.Kit.Text)\nreturn T"), ["dependency"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", 'local f = Instance.new("Frame")\nreturn f'), ["model-gui"])
        self.assertEqual(rules("RaceMenu.RaceMenuView", 'local V = {}\nfunction V.go(e) e:Fire(1) end\nreturn V'), ["view-side-effect"])
        self.assertEqual(rules("RaceMenu.RaceMenuView", 'local V = {}\nfunction V.go(p) p:SetAttribute("A", 1) end\nreturn V'),
                         ["view-side-effect"])

    def test_enabled_write_and_fork_kept_lines(self):
        body = "local M = {}\nfunction M.hide(gui)\n\tgui.Enabled = false\nend\nreturn M"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body), ["screengui-enabled"])
        path = UIP + "RaceMenu.RaceMenuClient"
        kept = context(forks={path: {1, 2}})                       # only the header lines are new code
        found = lint("RaceMenu.RaceMenuClient", body, kept)
        self.assertEqual([(f.rule, f.exempt) for f in found], [("screengui-enabled", True)])
        new = context(forks={path: {1, 2, 5}})                     # the write is on line 5: new code
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body, new), ["screengui-enabled"])

    def test_fork_kept_lines(self):
        body = ('local M = {}\nM.C = Color3.fromRGB(1, 2, 3)\n'
                'function M.go(r) r:FireServer("NoSuchAction") end\n'
                'local U = require(game.ReplicatedStorage.Modules.Game.UI.UITheme)\nreturn M')
        path = UIP + "RaceMenu.RaceMenuClient"
        found = lint("RaceMenu.RaceMenuClient", body, context(forks={path: {1, 2}}))
        state = {f.rule: ("exempt" if f.exempt else "kept" if f.kept else "open") for f in found}
        # rule 4 exempts the colour; a kept remote call is Classic text (listed for review); a kept Classic require is open
        self.assertEqual(state, {"colour-literal": "exempt", "remote-action": "kept", "classic-require": "open"})
        found = lint("RaceMenu.RaceMenuClient", body, context(forks={path: {1, 2, 3, 4, 5, 6, 7}}))
        self.assertEqual({f.rule for f in found if L.is_open(f)}, {"colour-literal", "remote-action", "classic-require"})
        # a fork that keeps Classic's first lines has no Pulse header: listed as kept, not open
        plain = "local M = {}\nreturn M\n"
        found = L.lint_source(path + ".lua", plain, None, context(forks={path: set()}))
        self.assertEqual([(f.rule, f.kept) for f in found], [("header", True), ("header", True)])
        # only the RouteGuideClient fork keeps its Classic require
        route = UIP + "RaceSession.RouteGuideClient"
        text = 'local F = require(game.ReplicatedStorage.Modules.Game.UI.ResponsiveUIFoundation)\nreturn F\n'
        found = L.lint_source(route + ".lua", text, None, context(forks={route: set()}))
        self.assertEqual([f.rule for f in found if L.is_open(f)], [])

    def test_remote_name_first_and_table_only_calls(self):
        body = ('local M = {}\nlocal function call(remote, action, payload) return M.remotes[remote]:InvokeServer(action, payload) end\n'
                'function M.go() return call("RaceBrowserTeleportInvoke", "%s", { EventId = 1, Mode = "Race" }) end\nreturn M')
        self.assertEqual(rules("RaceMenu.RaceMenuModel", body % "TeleportToRaceStart"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", body % "DeleteProfile"), ["remote-action"])
        push = 'local M = {}\nfunction M.go(remote) remote:FireServer({ Type = "X" }) end\nreturn M'
        self.assertEqual(rules("RaceMenu.RaceMenuModel", push), ["remote-action-owner"])      # RaceBrowserClient never does
        self.assertEqual(rules("RaceMenu.RaceMenuModel", push, context(owners=None)), [])     # some Classic client does

    def test_require_from_a_literal_list(self):
        body = ('local ORDER = { "RaceMenuModel", "%s" }\nlocal M = {}\nfunction M.start()\n'
                '\tfor _, name in ipairs(ORDER) do\n\t\trequire(script.Parent:WaitForChild(name))\n\tend\nend\nreturn M')
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body % "RaceMenuView"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body % "GarageComponents"), ["classic-require"])

    def test_remote_actions(self):
        model = "local M = {}\nfunction M.go(remote, id)\n\t%s\nend\nreturn M"
        good = 'remote:InvokeServer("TeleportToRaceStart", { EventId = id, Mode = "Race" })'
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % good), [])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % 'remote:InvokeServer("TeleportToRaceStart", { EventId = id, Cash = 5 })'),
                         ["remote-payload-key"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % 'remote:InvokeServer("GrantCash", { Amount = 5 })'), ["remote-action"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % 'remote:FireServer("Cancel")'), ["remote-action-owner"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % 'remote:InvokeServer("Cancel")', context(owners=None)), [])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % "remote:InvokeServer(id)"), [])        # id is a parameter
        self.assertEqual(rules("RaceMenu.RaceMenuModel", model % "local a = id .. 'x'\n\tremote:InvokeServer(a)"),
                         ["remote-dynamic-action"])
        self.assertEqual(rules("Kit.Data", model % good), ["remote-outside-model"])
        self.assertIn("view-side-effect", rules("RaceMenu.RaceMenuView", model % good))

    def test_wrapper_call_sites_are_checked(self):
        body = CLEAN_MODEL.replace('"TeleportToRaceStart", { EventId = eventId, Mode = mode }', '"BuyEverything", { Price = 0 }')
        self.assertEqual(rules("RaceMenu.RaceMenuModel", body), ["remote-action"])
        body = CLEAN_MODEL.replace("Mode = mode", "Mode = mode, Extra = 1")
        self.assertEqual(rules("RaceMenu.RaceMenuModel", body), ["remote-payload-key"])

    def test_new_remotes_and_bindables(self):
        self.assertEqual(rules("RaceMenu.RaceMenuModel", 'local r = Instance.new("RemoteEvent")\nreturn r'), ["remote-new"])
        signal = 'local e = Instance.new("BindableEvent")\nreturn e.Event'
        self.assertEqual(rules("RaceMenu.RaceMenuModel", signal), [])                    # a private signal
        made = 'local M = {}\nfunction M.make(folder)\n\tlocal e = Instance.new("BindableEvent")\n\te.Name = "%s"\n\te.Parent = folder\nend\nreturn M'
        self.assertEqual(rules("RaceMenu.RaceMenuModel", made % "ShowTopNotification"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", made % "BrandNewEvent"), ["bindable-new"])
        look = 'local M = {}\nfunction M.find(rs)\n\treturn rs:WaitForChild("Remotes"):WaitForChild("%s")\nend\nreturn M'
        self.assertEqual(rules("RaceMenu.RaceMenuModel", look % "Racing"), [])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", look % "BrandNewRemotes"), ["remote-name"])

    def test_banned_services(self):
        self.assertEqual(rules("RaceMenu.RaceMenuModel", 'local s = game:GetService("DataStoreService")\nreturn s'), ["banned-service"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", 'local s = game:GetService("MarketplaceService")\nreturn s'), ["banned-service"])
        self.assertEqual(rules("RaceMenu.RaceMenuModel", "local M = {}\nfunction M.buy(m, p) m:PromptProductPurchase(p, 1) end\nreturn M"),
                         ["banned-service"])

    def test_trap_names(self):
        self.assertEqual(rules("RaceMenu.RaceMenuClient", 'local M = {}\nfunction M.s(sw) sw.Claim("RaceEntry") end\nreturn M'), [])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", 'local M = {}\nfunction M.s(f) f.Name = "DriveHUD" end\nreturn M'), ["trap-name"])
        body = 'local Layers = require(script.Parent.Parent.Kit.Layers)\nlocal l = Layers.Create("RaceHud", {})\nreturn l'
        self.assertEqual(rules("RaceMenu.RaceMenuClient", body), ["trap-name"])

    def test_per_frame_lookups_and_polling(self):
        step = ('local Perf = require(script.Parent.Parent.Kit.Perf)\nlocal M = {}\n'
                'local function step(dt)\n\tlocal x = M.root:FindFirstChild("X")\nend\n'
                'function M.bind(root)\n\tPerf.Bind("X", root, step)\nend\nreturn M')
        self.assertEqual(rules("RaceMenu.RaceMenuClient", step), ["perf-step"])
        self.assertEqual(rules("RaceMenu.RaceMenuClient", "local RunService = game:GetService('RunService')\nlocal c = RunService.RenderStepped\nreturn c"),
                         ["frame-signal"])
        poll = "local M = {}\nfunction M.wait(p)\n\twhile not p:FindFirstChild('Gui') do\n\t\ttask.wait(0.1)\n\tend\nend\nreturn M"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", poll), ["poll-loop"])
        timer = "local M = {}\nfunction M.count(n)\n\twhile n > 0 do\n\t\ttask.wait(1)\n\t\tn -= 1\n\tend\nend\nreturn M"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", timer), [])
        repeat_poll = "local M = {}\nfunction M.wait(p)\n\trepeat task.wait() until p:GetAttribute('Ready')\nend\nreturn M"
        self.assertEqual(rules("RaceMenu.RaceMenuClient", repeat_poll), [])       # the read is in the condition, not the body

    def test_literals_and_asset_keys(self):
        self.assertEqual(rules("RaceMenu.RaceMenuView", "local c = Color3.fromRGB(1, 2, 3)\nreturn c"), ["colour-literal"])
        self.assertEqual(rules("RaceMenu.RaceMenuView", 'local a = "rbxassetid://123"\nreturn a'), ["asset-literal"])
        self.assertEqual(rules("RaceMenu.RaceMenuView", 'local a = string.find("x", "rbxassetid://", 1, true)\nreturn a'), [])
        self.assertEqual(rules("Kit.Sprites", 'local a = "rbxassetid://123"\nreturn a'), [])
        key = 'local Tokens = require(script.Parent.Parent.Kit.Tokens)\nlocal a = Tokens.Asset("GaugeArc")\nreturn a'
        self.assertEqual(rules("RaceMenu.RaceMenuView", key), ["asset-key"])
        self.assertEqual(rules("Kit.Gauge", 'local Tokens = require(script.Parent.Tokens)\nlocal a = Tokens.Asset("GaugeArc")\nreturn a'), [])
        self.assertEqual(rules("Kit.Gauge", 'local Tokens = require(script.Parent.Tokens)\nlocal a = Tokens.Assets.GaugeRing\nreturn a'), ["asset-key"])

    def test_exceptions_of_6_6_rule_2(self):
        self.assertEqual(rules("Kit.Minimap", 'local c = Instance.new("CanvasGroup")\nlocal u = Instance.new("UICorner")\nreturn c, u'), [])
        self.assertEqual(rules("Kit.Gauge", 'local c = Instance.new("CanvasGroup")\nreturn c'), ["banned-class"])
        self.assertEqual(rules("FreeRoam.ActivityHudClient", 'local s = Instance.new("UIScale")\nreturn s'), [])
        self.assertEqual(rules("FreeRoam.HudClient", 'local s = Instance.new("UIScale")\nreturn s'), ["uiscale"])

    def test_size_limit(self):
        self.assertIn("size", rules("RaceMenu.RaceMenuView", "local x = 1\n" + "-- pad\n" * 30000 + "return x"))

    def test_edited_classic_script_gets_size_and_line_ends_only(self):
        found = L.lint_source("ReplicatedStorage.Modules.Game.UI.RouteGuide.lua",
                              "local c = Color3.fromRGB(1,2,3)\r\nreturn c\n", None, context())
        self.assertEqual(sorted({f.rule for f in found}), ["line-ends"])

    def test_accept_file_and_inline(self):
        body = ("local M = {}\nM.c = Color3.fromRGB(1, 2, 3) -- lint-ok: colour-literal sample\n"
                "function M.hide(gui)\n\tgui.Enabled = false -- lint-ok: screengui-enabled sample\nend\nreturn M")
        found = lint("RaceMenu.RaceMenuClient", body)
        state = {f.rule: f.accepted for f in found}
        self.assertEqual(state, {"colour-literal": True, "screengui-enabled": False})     # a safety rule needs the file
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "accept.json")
            with open(path, "w", encoding="utf-8") as handle:
                json.dump({"accept": [{"file": "*RaceMenuClient.lua", "rule": "screengui-enabled", "line": 6,
                                       "reason": "reviewed sample", "reviewer": "test"},
                                      {"file": "*Nothing.lua", "rule": "size", "reason": "stale"}]}, handle)
            accept = L.load_accept(path)
            L.apply_accept(found, accept)
            self.assertTrue(all(f.accepted for f in found))
            self.assertEqual([row["_used"] for row in accept], [1, 0])
            with open(path, "w", encoding="utf-8") as handle:
                json.dump({"accept": [{"file": "x", "rule": "size"}]}, handle)
            with self.assertRaises(L.common.ToolError):
                L.load_accept(path)

    def test_noop_module_is_clean(self):
        noop = os.path.join(L.common.PHASE2, "integrator", "UIPulse.NoOp.lua")
        with open(noop, "rb") as handle:
            raw = handle.read()
        found = L.lint_source(UIP + "NoOp.lua", raw.decode("utf-8"), raw, context())
        self.assertEqual([str(f) for f in found], [])

    def test_phase1_sources_have_only_wave2_findings(self):
        files = L.common.phase1_sources()
        found = []
        for path, file in files.items():
            with open(file, "rb") as handle:
                raw = handle.read()
            found.extend(L.lint_source(path + ".lua", raw.decode("utf-8"), raw, L.Context(known=dict(KNOWN))))
        self.assertEqual(sorted({(f.rule, f.file.split(".")[-2]) for f in found if not f.accepted}),
                         [("asset-key", "Overlay")])       # TitleMark, removed by API2 1.1; kit v2 replaces the file


if __name__ == "__main__":
    unittest.main()
