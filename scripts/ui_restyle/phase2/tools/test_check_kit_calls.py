#!/usr/bin/env python3
"""Tests for check_kit_calls.py.   py -3 scripts/ui_restyle/phase2/tools/test_check_kit_calls.py

Small synthetic kit modules and screen sources; nothing here reads the real kit except the last test class,
which only asserts that the real kit still parses (no module left without a key set)."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_kit_calls as C  # noqa: E402

UIP = "ReplicatedStorage.Modules.Game.UIPulse."

TOKENS = r'''
local Tokens = {}
Tokens.Colour = {
	White = Color3.new(1, 1, 1),
	Pink = Color3.new(1, 0, 1),
}
Tokens.Space = { Pad = 22, Gap = 8 }
Tokens.Assets = { IconSheet = "rbxassetid://1" }
function Tokens.Asset(key)
	local value = Tokens.Assets[key]
	if value == nil then
		warn("unknown asset key " .. tostring(key))
		return nil
	end
	return value
end
return Tokens
'''

# Pattern A: keySet + readProps / mergePatch, a variant resolved in a pure helper, a list of entries.
CONTROLS = r'''
local Tokens = require(script.Parent.Tokens)
local Controls = {}

local COMMON_KEYS = { "Name", "Visible" }
local function keySet(list)
	local set = {}
	for _, key in ipairs(COMMON_KEYS) do
		set[key] = true
	end
	for _, key in ipairs(list) do
		set[key] = true
	end
	return set
end

local function readProps(kind, keys, defaults, props)
	local state = {}
	for key, value in pairs(defaults) do
		state[key] = value
	end
	if props ~= nil then
		for key, value in pairs(props) do
			if not keys[key] then
				error(string.format("%s: unknown key %s", kind, tostring(key)), 3)
			end
			state[key] = value
		end
	end
	return state
end

local function mergePatch(kind, keys, state, patch)
	for key in pairs(patch) do
		if not keys[key] then
			error(string.format("%s: unknown key %s", kind, tostring(key)), 3)
		end
	end
	return true
end

local function colourOf(role)
	local value = Tokens.Colour[role]
	if value == nil then
		error("unknown colour role " .. tostring(role), 3)
	end
	return value
end

local BUTTON_KEYS = keySet({ "Text", "Variant", "Size", "Colour", "OnActivated" })
local BUTTON_DEFAULTS = { Variant = "Default", Size = "Menu" }

function Controls._resolve(variant)
	if variant == "Main" then
		return 1
	elseif variant ~= "Default" and variant ~= "Danger" then
		error("Button: unknown Variant " .. tostring(variant), 2)
	end
	return 0
end

local function sizeOf(size)
	if size == "Menu" then
		return 1
	elseif size == "Hud" then
		return 2
	end
	error("Button: unknown Size " .. tostring(size), 3)
end

function Controls.Button(parent, props, scope)
	local state = readProps("Button", BUTTON_KEYS, BUTTON_DEFAULTS, props)
	local root = Instance.new("TextButton")
	local function render()
		local look = Controls._resolve(state.Variant)
		local height = sizeOf(state.Size)
		if state.Colour then
			root.BackgroundColor3 = colourOf(state.Colour)
		end
	end
	render()
	local self = { Instance = root }
	function self.Set(patch)
		if not mergePatch("Button", BUTTON_KEYS, state, patch) then
			return
		end
		render()
	end
	function self.Destroy()
		root:Destroy()
	end
	return self
end

local ROW_KEYS = keySet({ "Buttons" })
local ROW_BUTTON_KEYS = { Id = true, Text = true, Variant = true }

function Controls._rowPatch(spec)
	if type(spec) ~= "table" or type(spec.Id) ~= "string" then
		error("ButtonRow: every button needs a string Id", 3)
	end
	for key in pairs(spec) do
		if not ROW_BUTTON_KEYS[key] then
			error("ButtonRow: unknown button key " .. tostring(key), 3)
		end
	end
	return { Text = spec.Text }
end

function Controls.ButtonRow(parent, props, scope)
	local state = readProps("ButtonRow", ROW_KEYS, {}, props)
	local byId = {}
	local function sync()
		for _, spec in ipairs(state.Buttons or {}) do
			local patch = Controls._rowPatch(spec)
			local button = Controls.Button(parent, patch, scope)
			byId[spec.Id] = button
		end
	end
	sync()
	local self = { Instance = parent }
	function self.Button(id)
		return byId[id]
	end
	function self.Set(patch)
		mergePatch("ButtonRow", ROW_KEYS, state, patch)
		sync()
	end
	function self.Destroy() end
	return self
end

return Controls
'''

# Pattern B: one shared shell, a definition table per component (Keys / Validate), a required choice.
SURFACE = r'''
local Tokens = require(script.Parent.Tokens)
local Colour = Tokens.Colour
local Surface = {}
local EDGES = { Top = true, Bottom = true }

local function keySet(names)
	local keys = { Name = true, Visible = true }
	for _, name in names do
		keys[name] = true
	end
	return keys
end
local HAIRLINE_KEYS = keySet({ "Edge", "Colour" })

local function checkKeys(values, keys, name)
	for key in values do
		if not keys[key] then
			error(name .. ": unknown key " .. tostring(key), 3)
		end
	end
end
local function checkChoice(name, key, value, choices, required)
	if value == nil then
		if required then
			error(name .. ": " .. key .. " is required", 4)
		end
	elseif type(value) ~= "string" or choices[value] == nil then
		error(name .. ": unknown " .. key .. " " .. tostring(value), 4)
	end
end
local function make(parent, props, scope, def)
	props = props or {}
	checkKeys(props, def.Keys, def.Name)
	def.Validate(props, true)
	local component = { Instance = Instance.new("Frame") }
	function component.Set(patch)
		checkKeys(patch, def.Keys, def.Name)
		def.Validate(patch, false)
	end
	function component.Destroy() end
	return component
end
local HAIRLINE = {
	Name = "Surface.Hairline",
	Keys = HAIRLINE_KEYS,
	Validate = function(values, initial)
		checkChoice("Surface.Hairline", "Edge", values.Edge, EDGES, initial)
		if values.Colour ~= nil and Colour[values.Colour] == nil then
			error("Surface.Hairline: unknown colour role " .. tostring(values.Colour), 3)
		end
	end,
}
function Surface.Hairline(parent, props, scope)
	return make(parent, props, scope, HAIRLINE)
end
return Surface
'''

# Pattern C: one KEYS table and checkKeys(values) / checkValues(values), typed Luau, a slot method.
LAYERS = r'''
local Layers = {}
local KEYS = { Name = true, Unit = true, Size = true }
local UNITS = { MPH = true, ["KM/H"] = true }
local FRAMES = { Hud = true, Menu = true }
local SLOT_NAMES = { "TopLeft", "Centre" }
Layers.Order = { RaceBrowser = 170, Onboarding = 990 }

local function checkKeys(patch)
	if type(patch) ~= "table" then error("Gauge expects a table of props", 3) end
	for key in pairs(patch) do
		if not KEYS[key] then error(string.format("Gauge: unknown key '%s'", tostring(key)), 3) end
	end
end
local function checkValues(values)
	if values.Size ~= nil and type(values.Size) ~= "number" then
		error("Gauge: Size must be a design number", 3)
	end
	if values.Unit ~= nil and not UNITS[values.Unit] then
		error("Gauge: unknown Unit " .. tostring(values.Unit), 3)
	end
end
function Layers.Gauge(parent: GuiObject, props: { Unit: string? }?, scope: any): any
	assert(type(scope) == "table", "Gauge requires a scope")
	props = props or {}
	checkKeys(props)
	checkValues(props)
	local self = {}
	self.Instance = Instance.new("Frame")
	local function set(patch)
		checkKeys(patch)
		checkValues(patch)
	end
	self.Set = set
	function self.Destroy() end
	return self
end

function Layers.Check(name: string): (boolean, string?)
	if Layers.Order[name] == nil then
		return false, "'" .. name .. "' is not in Layers.Order"
	end
	return true, nil
end

local function frameOf(value: any): string
	local frame = value or "Hud"
	if FRAMES[frame] ~= true then
		error("unknown frame '" .. tostring(frame) .. "'", 3)
	end
	return frame
end

function Layers.Create(name: string, opts: { Frame: string? }?): any
	local options = opts or {}
	local ok, reason = Layers.Check(name)
	if not ok then
		error("[Layers] " .. tostring(reason), 2)
	end
	local frame = frameOf(options.Frame)
	local slots = {}
	for _, slotName in ipairs(SLOT_NAMES) do
		slots[slotName] = Instance.new("Frame")
	end
	local layer = {}
	layer.Root = Instance.new("Frame")
	function layer.Slot(slot: string): Frame
		local found = slots[slot]
		if not found then
			error("no slot '" .. tostring(slot) .. "'", 2)
		end
		return found
	end
	function layer.Destroy() end
	return layer
end
return Layers
'''

# A module whose props check cannot be read: it must be reported, not guessed.
OPAQUE = r'''
local Opaque = {}
function Opaque.Thing(parent, props, scope)
	local allowed = getAllowed()
	for key in pairs(props) do
		if not allowed[key] then
			error("unknown key " .. key)
		end
	end
	return { Instance = parent, Destroy = function() end }
end
return Opaque
'''

KIT = {"Tokens": TOKENS, "Controls": CONTROLS, "Surface": SURFACE, "Layers": LAYERS}
HEAD = '''local kit = script.Parent.Parent.Kit
local Tokens = require(kit.Tokens)
local Controls = require(kit.Controls)
local Surface = require(kit.Surface)
local Layers = require(kit.Layers)
'''


def make_kit(extra=None):
    mods = dict(KIT)
    mods.update(extra or {})
    return C.Kit({name: ("kit/" + name, text) for name, text in mods.items()})


def check(body, kit=None, head=HEAD):
    findings, _stats = C.check_text(kit or make_kit(), head + body, "sample", "Sample.lua")
    return findings


def errors(findings):
    return [f for f in findings if f.level == "ERROR"]


def notes(findings, kind=None):
    return [f for f in findings if f.level == "NOTE" and (kind is None or f.kind == kind)]


class KitModel(unittest.TestCase):
    def setUp(self):
        self.kit = make_kit()

    def keys(self, mod, fn, method=None):
        info = self.kit.model[mod]["functions"][fn]
        sites = info["methods"][method]["sites"] if method else info["sites"]
        idx = 0 if method else info["params"].index("props")
        got = [c.values for c in sites.get((idx, ()), {}).values() if c.kind == "keys"]
        self.assertEqual(len(got), 1, (mod, fn, method, got))
        return set(got[0])

    def values(self, mod, fn, prop):
        info = self.kit.model[mod]["functions"][fn]
        idx = info["params"].index("props")
        got = [c.values for c in info["sites"].get((idx, (prop,)), {}).values() if c.kind == "value"]
        self.assertTrue(got, (mod, fn, prop))
        return set(got[0])

    def test_keyset_helper_and_read_props(self):
        want = {"Name", "Visible", "Text", "Variant", "Size", "Colour", "OnActivated"}
        self.assertEqual(self.keys("Controls", "Button"), want)
        self.assertEqual(self.keys("Controls", "Button", "Set"), want)

    def test_definition_table_shell(self):
        want = {"Name", "Visible", "Edge", "Colour"}
        self.assertEqual(self.keys("Surface", "Hairline"), want)
        self.assertEqual(self.keys("Surface", "Hairline", "Set"), want)

    def test_single_keys_table_and_typed_params(self):
        self.assertEqual(self.keys("Layers", "Gauge"), {"Name", "Unit", "Size"})
        self.assertEqual(self.keys("Layers", "Gauge", "Set"), {"Name", "Unit", "Size"})
        self.assertEqual(self.kit.model["Layers"]["functions"]["Gauge"]["params"], ["parent", "props", "scope"])

    def test_enumerations(self):
        self.assertEqual(self.values("Controls", "Button", "Variant"), {"Main", "Default", "Danger"})
        self.assertEqual(self.values("Controls", "Button", "Size"), {"Menu", "Hud"})
        self.assertEqual(self.values("Controls", "Button", "Colour"), {"White", "Pink"})
        self.assertEqual(self.values("Surface", "Hairline", "Edge"), {"Top", "Bottom"})
        self.assertEqual(self.values("Layers", "Gauge", "Unit"), {"MPH", "KM/H"})

    def test_nested_list_entries(self):
        info = self.kit.model["Controls"]["functions"]["ButtonRow"]
        got = [c.values for c in info["sites"][(1, ("Buttons", "*"))].values() if c.kind == "keys"]
        self.assertEqual(set(got[0]), {"Id", "Text", "Variant"})
        self.assertTrue(any(c.kind == "req" for c in info["sites"][(1, ("Buttons", "*", "Id"))].values()))

    def test_handle_methods_and_typed_return(self):
        info = self.kit.model["Controls"]["functions"]["ButtonRow"]
        self.assertTrue(info["handle"])
        self.assertEqual(sorted(info["methods"]), ["Button", "Destroy", "Set"])
        self.assertEqual(info["methods"]["Button"]["returns"], ("Controls", "Button"))
        layer = self.kit.model["Layers"]["functions"]["Create"]
        self.assertIn("Root", layer["fields"])
        slot = [c.values for c in layer["methods"]["Slot"]["sites"][(0, ())].values() if c.kind == "value"]
        self.assertEqual(set(slot[0]), {"TopLeft", "Centre"})

    def test_validator_that_returns_false(self):
        info = self.kit.model["Layers"]["functions"]["Create"]
        got = [c.values for c in info["sites"][(0, ())].values() if c.kind == "value"]
        self.assertEqual(set(got[0]), {"RaceBrowser", "Onboarding"})

    def test_exports_and_constant_tables(self):
        self.assertIn("_resolve", self.kit.model["Controls"]["functions"])
        self.assertEqual(self.kit.model["Tokens"]["values"]["Colour"].keys(), {"White", "Pink"})
        self.assertEqual(self.kit.unparsed, {})

    def test_module_that_cannot_be_read_is_reported(self):
        kit = make_kit({"Opaque": OPAQUE})
        self.assertIn("Opaque", kit.unparsed)
        self.assertIn("Thing", kit.unparsed["Opaque"][0])
        # and nothing is reported against it
        self.assertEqual(errors(check('local Opaque = require(kit.Opaque)\nOpaque.Thing(p, { Anything = 1 }, s)\n', kit)), [])


class ScreenChecks(unittest.TestCase):
    def test_correct_calls_are_not_flagged(self):
        fs = check('''
local layer = Layers.Create("RaceBrowser", { Frame = "Menu" })
local slot = layer.Slot("TopLeft")
local button = Controls.Button(slot, { Name = "Go", Text = "GO", Variant = "Main", Size = "Hud", Colour = "Pink" }, scope)
button.Set({ Text = "STOP", Variant = compact and "Danger" or "Default" })
button.Instance.Visible = true
local line = Surface.Hairline(slot, { Edge = "Top" }, scope)
line.Set({ Colour = "White" })
local row = Controls.ButtonRow(slot, { Buttons = { { Id = "a", Text = "A" }, { Id = "b", Variant = "Main" } } }, scope)
row.Button("a").Set({ Text = "B" })
local pad = Tokens.Space.Pad + Tokens.Colour.White.R
local gauge = Layers.Gauge(slot, { Unit = "KM/H", Size = 120 }, scope)
button.Destroy()
''')
        self.assertEqual([(f.level, f.what) for f in fs], [])

    def test_unknown_prop_is_caught(self):
        fs = errors(check('local b = Controls.Button(parent, { Text = "x", Varient = "Main" }, scope)\n'))
        self.assertEqual(len(fs), 1)
        self.assertIn("unknown key Varient", fs[0].what)
        self.assertEqual(fs[0].line, 6)
        self.assertIn("Variant", fs[0].accepted)
        self.assertIn("Controls.Button(parent", fs[0].call)

    def test_alias_through_a_module_cache_table(self):
        fs = errors(check('''
local cache
local function mods()
	if not cache then
		local folder = script.Parent.Parent.Kit
		cache = { Controls = require(folder.Controls), Surface = require(folder.Surface) }
	end
	return cache
end
local function build(parent, scope)
	local m = mods()
	m.Controls.Button(parent, { Label = "x" }, scope)
	mods().Surface.Hairline(parent, { Edge = "Left" }, scope)
end
''', head=""))
        self.assertEqual(sorted(f.what.split(": ", 1)[1] for f in fs),
                         ['props has unknown key Label', 'props.Edge = "Left" is not an accepted value'])

    def test_alias_through_a_table_field_and_self(self):
        fs = errors(check('''
local View = {}
View.__index = View
function View.new(parent, scope)
	local self = setmetatable({}, View)
	self._kit = { Controls = Controls, Surface = Surface }
	self._button = self:_track(self._kit.Controls.Button(parent, { Text = "x" }, scope))
	return self
end
function View:_track(item)
	table.insert(self._items, item)
	return item
end
function View:refresh()
	self._button.Set({ Txt = "y" })
end
'''))
        self.assertEqual(len(fs), 1)
        self.assertIn("Controls.Button handle .Set: patch has unknown key Txt", fs[0].what)

    def test_set_on_a_component_variable(self):
        fs = errors(check('''
local line = Surface.Hairline(parent, { Edge = "Top" }, scope)
line.Set({ Edge = "Bottom", Thickness = 2 })
line:Set({ Edge = "Top" })
line.Update({})
'''))
        whats = sorted(f.what for f in fs)
        self.assertEqual(len(whats), 3, whats)
        self.assertTrue(any("unknown key Thickness" in w for w in whats))
        self.assertTrue(any("called with ':'" in w for w in whats))
        self.assertTrue(any("no field Update" in w for w in whats))

    def test_enumerated_values_and_required(self):
        fs = errors(check('''
Controls.Button(parent, { Variant = "Primary" }, scope)
Controls.Button(parent, { Size = big and "Hud" or "Huge" }, scope)
Surface.Hairline(parent, { Colour = "White" }, scope)
Layers.Create("RaceBrowsr", { Frame = "Hud" })
Layers.Create("Onboarding", { Frame = "Scene" }).Slot("Middle")
Controls.ButtonRow(parent, { Buttons = { { Text = "no id" }, { Id = "x", Icon = "car" } } }, scope)
Layers.Gauge(parent, { Size = "wide" }, scope)
Layers.Gauge(parent, { Unit = "MPH" })
'''))
        whats = [f.what for f in fs]
        for needle in ('props.Variant = "Primary"', 'props.Size = "Huge"', "props.Edge is required",
                       'name = "RaceBrowsr"', 'opts.Frame = "Scene"', 'slot = "Middle"',
                       "props.Buttons[1].Id is required", "props.Buttons[2] has unknown key Icon",
                       "props.Size is a string but the kit requires number", "scope is required"):
            self.assertTrue(any(needle in w for w in whats), (needle, whats))
        self.assertEqual(len(whats), 10, whats)

    def test_exports_and_tokens(self):
        fs = check('''
Controls.Buton(parent, {}, scope)
Controls:Button(parent, {}, scope)
local c = Tokens.Colour.Pinkk
local g = Tokens.Space.Gutter or 4
local ok = Tokens.Colour.White
Tokens.Asset("Missing")
''')
        whats = [f.what for f in errors(fs)]
        self.assertEqual(len(whats), 3, whats)
        self.assertTrue(any("has no member Buton" in w for w in whats))
        self.assertTrue(any("is called with ':'" in w for w in whats))
        self.assertTrue(any("Tokens.Colour has no key Pinkk" in w for w in whats))
        soft = [f.what for f in notes(fs, "suspect")]
        self.assertTrue(any("Tokens.Space has no key Gutter" in w for w in soft), soft)
        self.assertTrue(any('key = "Missing"' in w and "warns" in w for w in soft), soft)

    def test_uncertain_cases_are_notes_with_a_reason(self):
        fs = check('''
local props = { Text = "x", Colr = "Pink" }
Controls.Button(parent, props, scope)
Controls.Button(parent, makeProps(), scope)
Controls.Button(parent, { [key] = true }, scope)
local function update(thing)
	thing.Set({ Thickness = 1 })
	thing.Set({ Text = "fits a button" })
end
local items = {}
for i = 1, 3 do
	table.insert(items, { Id = "b" .. i, Tooltip = "x" })
end
Controls.ButtonRow(parent, { Buttons = items }, scope)
''')
        self.assertEqual(errors(fs), [])
        whats = [(f.kind, f.what) for f in notes(fs)]
        self.assertTrue(any(k == "suspect" and "unknown key Colr" in w and "not certain" in w for k, w in whats), whats)
        self.assertTrue(any(k == "unchecked" and "makeProps()" in w for k, w in whats), whats)
        self.assertTrue(any(k == "unchecked" and "computed key" in w for k, w in whats), whats)
        self.assertTrue(any(k == "suspect" and "no kit component's Set accepts" in w for k, w in whats), whats)
        self.assertTrue(any(k == "unchecked" and "valid for: Controls.Button" in w for k, w in whats), whats)
        self.assertTrue(any(k == "suspect" and "unknown key Tooltip" in w for k, w in whats), whats)

    def test_parameter_of_a_local_function_takes_its_callers(self):
        fs = errors(check('''
local a = Controls.Button(parent, { Text = "a" }, scope)
local b = Controls.Button(parent, { Text = "b" }, scope)
local function dim(component)
	component.Set({ Disabled = true })
end
dim(a)
dim(b)
'''))
        self.assertEqual(len(fs), 1)
        self.assertIn("unknown key Disabled", fs[0].what)

    def test_comments_and_strings_are_not_code(self):
        fs = check('''
-- Controls.Button(parent, { Bogus = 1 }, scope)
--[[ Controls.Buton(parent)
     Surface.Hairline(parent, { Edge = "Left" }, scope) ]]
local text = "Controls.Button(parent, { Bogus = 1 }, scope)"
local long = [[Layers.Create("Nope")]]
local also = `Controls.Button(parent, \\{ Bogus = 1 }, scope)`
''')
        self.assertEqual([(f.level, f.what) for f in fs], [])

    def test_if_expressions_do_not_break_block_matching(self):
        fs = errors(check('''
local function pick(compact)
	local variant = if compact then "Main" else "Default"
	local size = if compact then "Hud" elseif wide then "Menu" else "Menu"
	return Controls.Button(parent, { Variant = variant, Size = size }, scope)
end
local after = Controls.Button(parent, { Wrong = true }, scope)
'''))
        self.assertEqual(len(fs), 1)
        self.assertEqual(fs[0].line, 12)


class CommandLine(unittest.TestCase):
    def tree(self, tmp, good_only=False):
        phase2 = Path(tmp) / "ui_restyle" / "phase2"
        kit = phase2 / "install" / "00_kit" / "after"
        kit.mkdir(parents=True)
        for name, text in KIT.items():
            (kit / (UIP + "Kit." + name + ".lua")).write_text(text, encoding="utf-8")
        (kit / (UIP + "Dev.Fixtures.Controls.lua")).write_text(
            HEAD + 'Controls.Button(parent, { Text = "fixture" }, scope)\n', encoding="utf-8")
        work = phase2 / "kit" / "k2" / "after"
        work.mkdir(parents=True)
        (work / (UIP + "Kit.Controls.lua")).write_text(CONTROLS.replace('"OnActivated" })', '"OnActivated", "Glow" })'),
                                                         encoding="utf-8")
        for family, body in (("race_menu", 'Controls.Button(parent, { Text = "ok", Glow = true }, scope)\n'),
                             ("garage", 'Controls.Button(parent, { Texxt = "bad" }, scope)\n')):
            folder = phase2 / "families" / family / "after"
            folder.mkdir(parents=True)
            if good_only and family == "garage":
                body = 'Controls.Button(parent, { Text = "fine" }, scope)\n'
            (folder / (UIP + "X.View.lua")).write_text(HEAD + body, encoding="utf-8")
        return phase2

    def run_main(self, argv, phase2):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = C.main(argv, phase2)
        return code, out.getvalue(), err.getvalue()

    def test_exit_code_unit_filter_json_and_working_copy(self):
        with tempfile.TemporaryDirectory() as tmp:
            phase2 = self.tree(tmp)
            code, out, _ = self.run_main(["--json"], phase2)
            self.assertEqual(code, 1)
            data = json.loads(out)
            self.assertEqual(data["units"], ["race_menu", "garage", "kit_fixtures"])
            self.assertEqual(data["counts"]["garage"]["ERROR"], 1)
            self.assertEqual(data["counts"]["race_menu"]["ERROR"], 0)       # Glow exists in the working copy
            self.assertEqual(data["kit_sources"]["Controls"], "phase2/kit/k2/after/" + UIP + "Kit.Controls.lua")
            self.assertEqual(data["stats"]["kit_fixtures"]["kit_calls"], 1)
            finding = [f for f in data["findings"] if f["level"] == "ERROR"][0]
            self.assertEqual((finding["family"], finding["line"]), ("garage", 6))
            self.assertTrue(finding["file"].endswith("X.View.lua"))
            self.assertIn("Text", finding["accepted"])

            code, out, _ = self.run_main(["--unit", "race_menu", "--json"], phase2)
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(out)["units"], ["race_menu"])

            code, out, _ = self.run_main(["--unit=race_menu", "--kit", "assembled", "--json"], phase2)
            self.assertEqual(code, 1)                                         # Glow is not in the assembled copy
            self.assertIn("unknown key Glow", json.loads(out)["findings"][0]["what"])

            code, _, err = self.run_main(["--unit", "nope"], phase2)
            self.assertEqual(code, 2)
            self.assertIn("unknown unit", err)

    def test_clean_tree_exits_zero_and_writes_the_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            phase2 = self.tree(tmp, good_only=True)
            code, out, _ = self.run_main(["--write"], phase2)
            self.assertEqual(code, 0)
            report = (phase2 / "results" / "kit_call_report.md").read_text(encoding="utf-8")
            self.assertIn("## race_menu", report)
            self.assertIn("only against the assembled copy: ERROR", report)
            data = json.loads((phase2 / "results" / "kit_call_report.json").read_text(encoding="utf-8"))
            self.assertEqual(len(data["assembled_copy_findings"]), 1)


class RealKit(unittest.TestCase):
    def test_the_real_kit_still_parses(self):
        sources = C.kit_sources()
        if not sources:
            self.skipTest("kit sources not present")
        kit = C.Kit(sources)
        self.assertEqual(kit.unparsed, {})
        button = kit.model["Controls"]["functions"]["Button"]
        self.assertIn("Set", button["methods"])
        self.assertTrue(any(c.kind == "keys" for c in button["sites"][(1, ())].values()))


if __name__ == "__main__":
    unittest.main()
