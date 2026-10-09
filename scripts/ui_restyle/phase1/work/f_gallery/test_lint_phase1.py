#!/usr/bin/env python3
"""Tests for lint_phase1.py.   py -3 test_lint_phase1.py"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lint_phase1 as L  # noqa: E402

UIP = "ReplicatedStorage.Modules.Game.UIPulse."


def src(module, body, requires="none"):
    return f"-- Owns a sample; nothing else.\n-- Pulse UI (phase1). {UIP}{module}. Requires: {requires}.\n{body}"


def rules(module, body, requires="none"):
    return sorted({f.rule for f in L.lint_source(UIP + module + ".lua", src(module, body, requires))
                   if not f.accepted})


CLEAN_SURFACE = """
local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Surface = {}
-- UIStroke, TextScaled and Color3.fromRGB(1, 2, 3) in a comment are fine
local NOTE = "a string that says Instance.new and .Enabled = true"
function Surface.Hairline(parent, props, scope)
	local ctx = Metrics.Of(parent)
	local line = Instance.new("Frame")
	line.Name = props.Name or "Hairline"
	line.BackgroundColor3 = Tokens.Colour.White
	line.Size = UDim2.new(1, 0, 0, ctx.Hair(Tokens.Space.Hairline))
	line.Visible = if props.Visible == false then false else true
	if line:IsA("UIStroke") or line.ClassName == "UICorner" then warn("[Pulse.Surface] odd") end
	line.Parent = parent
	return {Instance = line, Set = function() end, Destroy = function() line:Destroy() end}
end
return Surface
"""


class Clean(unittest.TestCase):
    def test_clean_kit_module(self):
        self.assertEqual(rules("Kit.Surface", CLEAN_SURFACE, "Tokens, Metrics"), [])

    def test_tokens_may_hold_literals(self):
        body = 'local T = {Colour = {Pink = Color3.fromRGB(255, 45, 149)}, Family = "rbxassetid://12187372847"}\nreturn T\n'
        self.assertEqual(rules("Kit.Tokens", body), [])

    def test_layers_may_create_screengui(self):
        body = ('local Tokens = require(script.Parent.Tokens)\nlocal gui = Instance.new("ScreenGui")\n'
                'gui.Name = "X"\nreturn {}\n')
        self.assertEqual(rules("Kit.Layers", body, "Tokens"), [])

    def test_gallery_exceptions(self):
        body = ('local Kit = script.Parent.Parent.Kit\nlocal Tokens = require(Kit.Tokens)\n'
                'local Scope = require(game:GetService("ReplicatedStorage").Modules.Core.ConnectionScope)\n'
                'local s = Instance.new("UIScale")\nfor _, child in ipairs({}) do local ok = pcall(require, child); '
                'local m = require(child) end\nreturn {}\n')
        self.assertEqual(rules("Dev.Gallery", body, "Tokens"), [])

    def test_perf_enabled_field(self):
        self.assertEqual(rules("Kit.Perf", "local Perf = {}\nPerf.Enabled = false\nreturn Perf\n"), [])

    def test_non_pulse_source_only_size(self):
        text = 'local x = Instance.new("ScreenGui"); x.Enabled = false\n'
        self.assertEqual(L.lint_source("StarterPlayer.StarterPlayerScripts.ClientBase.lua", text), [])

    def test_accepted_finding(self):
        found = L.lint_source(UIP + "Kit.Surface.lua",
                              src("Kit.Surface", "local g = nil\ng.Enabled = false -- lint-ok: screengui-enabled UIGradient\n"))
        self.assertEqual([(f.rule, f.accepted) for f in found], [("screengui-enabled", True)])


class Findings(unittest.TestCase):
    def check(self, module, body, rule, requires="none"):
        self.assertIn(rule, rules(module, body, requires))

    def test_header(self):
        found = L.lint_source(UIP + "Kit.Perf.lua", "local Perf = {}\nreturn Perf\n")
        self.assertEqual([f.rule for f in found], ["header", "header"])
        wrong = "-- Owns x; not y.\n-- Pulse UI (phase1). " + UIP + "Kit.Other. Requires: none.\nreturn {}\n"
        self.assertEqual([f.rule for f in L.lint_source(UIP + "Kit.Perf.lua", wrong)], ["header"])

    def test_nocheck(self):
        self.check("Kit.Perf", "--!nocheck\nreturn {}\n", "nocheck")

    def test_enabled_write(self):
        self.check("Kit.Overlay", "local gui = nil\ngui.Enabled = false\n", "screengui-enabled")
        self.assertEqual(rules("Kit.Perf", "local t = {Enabled = true}\nif t.Enabled == true then end\n"), [])

    def test_screengui_outside_layers(self):
        self.check("Kit.Overlay", 'local gui = Instance.new("ScreenGui")\n', "screengui-new")
        self.check("Kit.Overlay", 'local gui = make("ScreenGui", {})\n', "screengui-new")

    def test_banned_classes(self):
        for name in ("UIStroke", "UICorner", "CanvasGroup"):
            self.check("Kit.Controls", f'local x = Instance.new("{name}")\n', "banned-class")
        self.check("Kit.Controls", 'local x = Instance.new("UIScale")\n', "uiscale")
        self.assertEqual(rules("Kit.Text", 'local x = Instance.new("UIScale")\n'), [])

    def test_textscaled(self):
        self.check("Kit.Text", "local label = nil\nlabel.TextScaled = true\n", "textscaled")

    def test_tween_size(self):
        self.check("Kit.Controls", "local T = nil\nT:Create(label, info, {TextSize = 20}):Play()\n", "tween-size")

    def test_classic_requires(self):
        self.check("Kit.Controls", "local F = require(game.ReplicatedStorage.Modules.Game.UI.ResponsiveUIFoundation)\n",
                   "classic-path")
        self.check("Kit.Controls", "local F = require(script.Parent.RacingUIComponents)\n", "classic-require")
        self.check("Kit.Controls", 'local p = "ReplicatedStorage.Modules.Game.Garage.GarageUI"\n', "classic-path")
        self.check("Kit.Controls", 'local m = rs:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("UI")\n',
                   "classic-path")
        self.assertEqual(rules("Routes", 'local p = "ReplicatedStorage.Modules.Game.UIPulse.Toasts.ToastClient"\n'), [])

    def test_dependency_edges(self):
        self.check("Kit.Metrics", "local Text = require(script.Parent.Text)\n", "dependency")
        self.check("Kit.Tokens", "local M = require(script.Parent.Metrics)\n", "dependency")
        self.check("Kit.Surface", "local T = require(script.Parent.Parent.Kit.Tokens)\n", "require-form")
        self.check("Kit.Surface", "local S = require(game.ReplicatedStorage.Modules.Core.ConnectionScope)\n", "dependency")
        self.check("Toasts.ToastClient", "local N = require(game.ReplicatedStorage.Modules.Core.Net)\n", "core-require")
        self.check("Kit.Surface", "local m = nil\nlocal X = require(m)\n", "dependency")
        self.check("Dev.Fixtures.Text", "local G = require(script.Parent.Parent.Gallery)\n", "dependency")
        self.check("Kit.Wrong", "return {}\n", "unknown-module")
        ok = ("local Layers = require(script.Parent.Parent.Kit.Layers)\nlocal Routes = require(script.Parent.Parent.Routes)\n"
              "local Scope = require(game.ReplicatedStorage.Modules.Core.ConnectionScope)\n")
        self.assertEqual(rules("Toasts.ToastClient", ok), [])
        latch = 'local S = nil\nfunction L.Switch() S = S or require(game:GetService("ReplicatedFirst"):WaitForChild("UIStyleSwitch")) return S end\n'
        self.assertEqual(rules("Kit.Layers", "local L = {}\n" + latch), [])

    def test_colour_font_asset_literals(self):
        self.check("Kit.Surface", "local c = Color3.fromRGB(1, 2, 3)\n", "colour-literal")
        self.check("Kit.Surface", "local c = Color3.new(0.5, 0, 1)\n", "colour-literal")
        self.assertEqual(rules("Kit.Surface", "local c = Color3.new(1, 1, 1)\nlocal d = Color3.new()\n"), [])
        self.check("Kit.Surface", "local f = Font.fromEnum(Enum.Font.Gotham)\n", "font-literal")
        self.check("Kit.Surface", 'local id = "rbxassetid://1"\n', "asset-literal")

    def test_perf_step(self):
        inline = "Perf.Bind('x', root, function(dt)\n\tlocal a, b = 1, 2\n\tlocal c = root:FindFirstChild('y')\nend)\n"
        self.check("Kit.Overlay", inline, "perf-step")
        named = ("local function helper(root)\n\treturn Instance.new('Frame')\nend\n"
                 "local function step(dt)\n\thelper(nil)\nend\nPerf.Bind('x', root, step)\n")
        self.check("Kit.Overlay", named, "perf-step")
        clean = ("local function step(dt)\n\tlocal v = if dt > 0 then 1 else 0\n\tlabel.Text = tostring(v)\nend\n"
                 "Perf.Bind('x', root, step)\nlocal after = root:FindFirstChild('y')\n")
        self.assertEqual(rules("Kit.Overlay", clean), [])
        self.check("Kit.Overlay", "Perf.Bind('x', root, self.step)\n", "perf-step")
        definition = "local Perf = {}\nfunction Perf.Bind(name, layerRoot, step)\n\treturn {Disconnect = function() end}\nend\n"
        self.assertEqual(rules("Kit.Perf", definition), [])

    def test_require_through_locals(self):
        latch = ('local RF = game:GetService("ReplicatedFirst")\nlocal latch = RF:FindFirstChild("UIStyleSwitch")\n'
                 "local switch = require(latch)\n")
        self.assertEqual(rules("Kit.Layers", latch), [])
        self.check("Kit.Surface", latch, "dependency")
        core = ('local modules = game.ReplicatedStorage:FindFirstChild("Modules")\n'
                'local core = modules and modules:FindFirstChild("Core")\n'
                'local scopeModule = core and core:FindFirstChild("ConnectionScope")\n'
                "local kit = script.Parent.Parent.Kit\nlocal Text = require(kit.Text)\n"
                "local scope = require(scopeModule).new()\n")
        self.assertEqual(rules("Toasts.ToastClient", core), [])
        self.check("Kit.Controls", core, "dependency")

    def test_frame_signals(self):
        self.check("Kit.Overlay", "RunService.RenderStepped:Connect(function() end)\n", "frame-signal")
        self.check("Kit.Overlay", "RunService:BindToRenderStep('a', 1, f)\n", "frame-signal")
        self.assertEqual(rules("Kit.Perf", "RunService.RenderStepped:Connect(function() end)\n"), [])
        self.check("Kit.Input", 'UIS:GetPropertyChangedSignal("PreferredInput"):Connect(f)\n', "metrics-listener")

    def test_trap_and_locked_names(self):
        self.check("Kit.Overlay", 'frame.Name = "GarageRoot"\n', "trap-name")
        self.check("Kit.Controls", 'button.Name = "Race"\n', "locked-name")
        self.assertEqual(rules("Kit.Contracts", 'return {Trap = {["DriveHUD"] = true}}\n'), [])

    def test_warn_prefix(self):
        self.check("Kit.Text", 'warn("font failed")\n', "warn-prefix")
        self.assertEqual(rules("Kit.Text", 'warn("[Pulse.Text] font failed")\n'), [])

    def test_size_and_line_ends(self):
        big = src("Kit.Perf", "-- " + "x" * 150_001 + "\n")
        self.assertIn("size", [f.rule for f in L.lint_source(UIP + "Kit.Perf.lua", big)])
        crlf = src("Kit.Perf", "return {}\r\n")
        self.assertIn("line-ends", [f.rule for f in L.lint_source(UIP + "Kit.Perf.lua", crlf)])

    def test_locals(self):
        many = "local function big()\n" + "".join(f"\tlocal v{i} = {i}\n" for i in range(190)) + "end\n"
        self.check("Kit.Perf", many, "locals")
        split = "".join(f"local function f{i}()\n\tlocal a, b: {{[string]: number}}, c = 1, {{}}, 3\nend\n" for i in range(100))
        self.assertEqual(rules("Kit.Perf", split), [])


class Parser(unittest.TestCase):
    def test_if_expression_does_not_break_blocks(self):
        text = ("local function a()\n\tlocal x = if p then 1 else if q then 2 else 3\n\tif x then\n\t\ty()\n"
                "\telse if z then w() end end\n\trepeat local k = 1 until k\nend\nlocal function b() end\n")
        toks, _ = L.tokenize(text)
        _, func_end = L.structure(toks)
        names = L.function_names(toks, func_end)
        self.assertEqual(sorted(names), ["a", "b"])
        self.assertEqual(toks[func_end[names["a"]] + 1].value, "local")

    def test_local_count(self):
        toks, _ = L.tokenize("local a, b: (number, string) -> (), c = 1, 2, 3\nlocal function f() end\nlocal d\nfoo()\n")
        self.assertEqual([L.count_local_names(toks, i) for i, t in enumerate(toks) if t.value == "local"], [3, 1, 1])

    def test_strings_and_comments(self):
        toks, comments = L.tokenize('local a = [[UIStroke]] --[[ block\nTextScaled ]] local b = "x" -- tail\n')
        self.assertEqual([t.value for t in toks if t.type == "str"], ["UIStroke", "x"])
        self.assertEqual(len(comments), 2)
        self.assertEqual(toks[-1].line, 2)


if __name__ == "__main__":
    unittest.main()
