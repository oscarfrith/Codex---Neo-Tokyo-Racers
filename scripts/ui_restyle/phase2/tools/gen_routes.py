"""Generates the UIPulse.Routes source for "Phase 1 + families up to X" (API2 section 4).

    py -3 gen_routes.py phase1                 prints whether the output equals the installed Routes byte for byte
    py -3 gen_routes.py <family> [--out file] [--test-out file]

The installed file phase1/after/...UIPulse.Routes.lua is the template: only the three data tables (Families, Swap,
Add) are rewritten; every other byte, Compose and Resolve included, is copied. Rows come from each family's
routes.json (and routes_a.json / routes_b.json), in the delivery order of API2 section 4.

--test-out writes the matching pure test: the Phase 1 Routes test run unchanged against the Phase 1 data (same
Compose/Resolve code), then data and prefix checks for the generated tables. assemble.py calls both.
Nothing here talks to Studio.
"""
import os
import re

import common
from common import ToolError

TEMPLATE = os.path.join(common.PHASE1, "after", common.ROUTES_PATH + ".lua")
PHASE1_TEST = os.path.join(common.PHASE1, "tests", common.ROUTES_PATH + "_test.lua")
PATH_RE = re.compile(r"[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+")
NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
FAMILIES_RE = re.compile(r"^Routes\.Families = \{([^\n]*)\}\n", re.M)
SWAP_RE = re.compile(r"^Routes\.Swap = \{\n(.*?)^\}\n", re.M | re.S)
ADD_RE = re.compile(r"^Routes\.Add = \{\n(.*?)^\}\n", re.M | re.S)
SWAP_ROW_RE = re.compile(r'\t(\w+) = \{ Family = "(\w+)", Path = "([\w.]+)" \},')
ADD_ROW_RE = re.compile(r'\t\{ name = "(\w+)", path = "([\w.]+)", dependencies = \{(.*?)\}'
                        r'(?:, tool = "(\w+)")?(?:, Family = "(\w+)")? \},')


def parse_template(text):
    """-> {"families": [...], "swap": [(name, family, path)], "add": [row]} read from the installed Routes source."""
    families = FAMILIES_RE.search(text)
    swap = SWAP_RE.search(text)
    add = ADD_RE.search(text)
    if not (families and swap and add) or not (families.start() < swap.start() < add.start()):
        raise ToolError("the installed Routes source no longer has the three data tables in the Phase 1 layout",
                        [TEMPLATE])
    data = {"families": re.findall(r'"(\w+)"', families.group(1)), "swap": [], "add": []}
    for line in swap.group(1).splitlines():
        row = SWAP_ROW_RE.fullmatch(line)
        if not row:
            raise ToolError("cannot read a Routes.Swap row of the installed source", [line])
        data["swap"].append((row.group(1), row.group(2), row.group(3)))
    for line in add.group(1).splitlines():
        row = ADD_ROW_RE.fullmatch(line)
        if not row:
            raise ToolError("cannot read a Routes.Add row of the installed source", [line])
        data["add"].append({"name": row.group(1), "path": row.group(2),
                            "dependencies": re.findall(r'"(\w+)"', row.group(3)),
                            "tool": row.group(4), "family": row.group(5)})
    return data


def render_tables(data):
    def quoted(names):
        return "{ " + ", ".join('"%s"' % name for name in names) + " }" if names else "{}"

    families = "Routes.Families = %s\n" % quoted(data["families"])
    swap = "Routes.Swap = {\n" + "".join(
        '\t%s = { Family = "%s", Path = "%s" },\n' % row for row in data["swap"]) + "}\n"
    rows = []
    for row in data["add"]:
        text = '\t{ name = "%s", path = "%s", dependencies = %s' % (row["name"], row["path"], quoted(row["dependencies"]))
        if row.get("tool"):
            text += ', tool = "%s"' % row["tool"]
        if row.get("family"):
            text += ', Family = "%s"' % row["family"]
        rows.append(text + " },\n")
    return families, swap, "Routes.Add = {\n" + "".join(rows) + "}\n"


def render(template, data):
    families, swap, add = render_tables(data)
    spans = [(FAMILIES_RE.search(template), families), (SWAP_RE.search(template), swap), (ADD_RE.search(template), add)]
    out, position = [], 0
    for match, text in spans:
        out.append(template[position:match.start()])
        out.append(text)
        position = match.end()
    out.append(template[position:])
    return "".join(out)


def family_fragment(layout, family):
    """-> ({"family", "swap": [(name, path)], "add": [row]}, [problems]) merged from routes.json and its variants."""
    folder = layout.family_dir(family)
    found = common.fragments(folder, "routes")
    expected = common.FAMILY_NAMES[family]
    problems, swap, add = [], [], []
    if not found:
        return None, ["%s: routes.json is missing (also looked for routes_a.json, routes_b.json)" % folder]
    for name, data in found:
        if not isinstance(data, dict):
            problems.append("%s: must be an object {family, swap, add}" % name)
            continue
        if data.get("family") != expected:
            problems.append("%s: family is %r, expected %r (API2 section 4)" % (name, data.get("family"), expected))
        rows = data.get("swap") or {}
        if not isinstance(rows, dict):
            problems.append("%s: swap must be an object {entry name: Pulse path}" % name)
            rows = {}
        for entry, path in rows.items():
            if isinstance(path, dict):          # tolerated: {"Path": ...} or {"path": ...}
                path = path.get("Path") or path.get("path")
            known = dict(swap)
            if entry in known and known[entry] != path:
                problems.append("%s: swap %s is given two paths (%s, %s)" % (name, entry, known[entry], path))
            elif entry not in known:
                swap.append((entry, path))
        for row in data.get("add") or []:
            if not isinstance(row, dict):
                problems.append("%s: an add row must be an object {name, path, dependencies, tool?}" % name)
                continue
            lowered = {key.lower(): value for key, value in row.items()}
            unknown = set(lowered) - {"name", "path", "dependencies", "tool", "family"}
            if unknown:
                problems.append("%s: add row %r has unknown keys %s" % (name, lowered.get("name"), sorted(unknown)))
            made = {"name": lowered.get("name"), "path": lowered.get("path"),
                    "dependencies": list(lowered.get("dependencies") or []), "tool": lowered.get("tool") or None,
                    "family": lowered.get("family") or expected}
            same = [other for other in add if other["name"] == made["name"]]
            if same and same[0] != made:
                problems.append("%s: add row %s is given twice with different values" % (name, made["name"]))
            elif not same:
                add.append(made)
    return {"family": expected, "swap": swap, "add": add}, problems


def compose_data(layout, upto):
    """-> (data, [problems]). upto is "phase1" or a family folder name; families after it are left out."""
    template = common.read_text(TEMPLATE)
    data = parse_template(template)
    problems = []
    if upto == "phase1":
        return data, problems
    if upto not in common.FAMILIES:
        raise ToolError("gen_routes: %r is not phase1 or a family" % upto, ["families: " + ", ".join(common.FAMILIES)])
    entries = {entry["name"]: entry for entry in common.clientbase_entries()}
    swap_names = {row[0] for row in data["swap"]}
    for family in common.FAMILIES[:common.FAMILIES.index(upto) + 1]:
        fragment, found = family_fragment(layout, family)
        problems.extend(found)
        if fragment is None:
            continue
        data["families"].append(fragment["family"])
        for entry, path in fragment["swap"]:
            where = "%s swap %s" % (family, entry)
            if entry not in entries:
                problems.append("%s: not a ClientBase entry name (classic/contracts/_clientbase_entries.json)" % where)
            if entry in swap_names:
                problems.append("%s: already swapped by an earlier family" % where)
            if not isinstance(path, str) or not PATH_RE.fullmatch(path) or not path.startswith(common.UIP_DOT):
                problems.append("%s: path %r must be a dotted path under %s" % (where, path, common.UIP))
                continue
            swap_names.add(entry)
            data["swap"].append((entry, fragment["family"], path))
        for row in fragment["add"]:
            where = "%s add %s" % (family, row["name"])
            if not isinstance(row["name"], str) or not NAME_RE.fullmatch(row["name"]):
                problems.append("%s: bad name" % where)
                continue
            if row["name"] in entries or any(other["name"] == row["name"] for other in data["add"]):
                problems.append("%s: the name is already a ClientBase entry or an added entry" % where)
            if not isinstance(row["path"], str) or not PATH_RE.fullmatch(row["path"]) \
                    or not row["path"].startswith(common.UIP_DOT):
                problems.append("%s: path %r must be a dotted path under %s" % (where, row["path"], common.UIP))
                continue
            if row["family"] not in data["families"]:
                problems.append("%s: Family %r is not delivered yet (families so far: %s)" % (
                    where, row["family"], ", ".join(data["families"])))
            if row["tool"] is not None and (not isinstance(row["tool"], str) or not NAME_RE.fullmatch(row["tool"])):
                problems.append("%s: bad tool flag %r" % (where, row["tool"]))
            data["add"].append(row)
    names = set(entries) | {row["name"] for row in data["add"]}
    for row in data["add"]:
        for dependency in row["dependencies"]:
            if dependency not in names:
                problems.append("add %s: dependency %s is neither a ClientBase entry nor an added entry" % (
                    row["name"], dependency))
    expected = ["Toasts"] + [common.FAMILY_NAMES[f] for f in common.FAMILIES[:common.FAMILIES.index(upto) + 1]]
    if not problems and data["families"] != expected:
        problems.append("Routes.Families would be %s, expected %s" % (data["families"], expected))
    return data, problems


def generate(layout, upto):
    """-> (source text, data). Raises ToolError listing every problem."""
    data, problems = compose_data(layout, upto)
    if problems:
        raise ToolError("Routes for %r cannot be generated" % upto, problems)
    template = common.read_text(TEMPLATE)
    text = render(template, data)
    check = parse_template(text)
    if check != data:
        raise ToolError("internal: the generated Routes does not read back as the data it was made from")
    return text, data


def lua_list(names):
    return "{ " + ", ".join('"%s"' % name for name in names) + " }" if names else "{}"


def generate_test(layout, upto):
    """The pure test that goes with generate(layout, upto)."""
    _, data = generate(layout, upto)
    base = parse_template(common.read_text(TEMPLATE))
    phase1_test = common.read_text(PHASE1_TEST)
    if not phase1_test.endswith("\n"):
        phase1_test += "\n"

    def swap_table(rows):
        return "{\n" + "".join('\t%s = { Family = "%s", Path = "%s" },\n' % row for row in rows) + "}"

    def add_table(rows, family_key):
        lines = []
        for row in rows:
            text = '\t{ name = "%s", path = "%s", dependencies = %s' % (row["name"], row["path"], lua_list(row["dependencies"]))
            if row.get("tool"):
                text += ', tool = "%s"' % row["tool"]
            if row.get("family"):
                text += ', %s = "%s"' % (family_key, row["family"])
            lines.append(text + " },\n")
        return "{\n" + "".join(lines) + "}"

    entries = []
    for entry in common.clientbase_entries():
        text = '\t{ name = "%s", path = "%s", dependencies = %s' % (entry["name"], entry["path"], lua_list(entry["dependencies"]))
        if entry.get("tool"):
            text += ', tool = "%s"' % entry["tool"]
        entries.append(text + " },\n")
    return TEST_TEMPLATE.replace("@@UPTO@@", upto).replace("@@PHASE1_TEST@@", phase1_test) \
        .replace("@@P1_FAMILIES@@", lua_list(base["families"])).replace("@@P1_SWAP@@", swap_table(base["swap"])) \
        .replace("@@P1_ADD@@", add_table(base["add"], "Family")) \
        .replace("@@FAMILIES@@", lua_list(data["families"])).replace("@@SWAP@@", swap_table(data["swap"])) \
        .replace("@@ADD@@", add_table(data["add"], "Family")).replace("@@ENTRIES@@", "{\n" + "".join(entries) + "}")


TEST_TEMPLATE = '''-- GENERATED by scripts/ui_restyle/phase2/tools/gen_routes.py for "@@UPTO@@". Do not edit.
-- Part 1: the Phase 1 Routes test, unchanged, run against the Phase 1 data (Compose and Resolve are the same code).
-- Part 2: the generated data tables against the ClientBase entry list, for every prefix of Routes.Families.
local phase1Test = (function()
@@PHASE1_TEST@@end)()

local P1_FAMILIES = @@P1_FAMILIES@@
local P1_SWAP = @@P1_SWAP@@
local P1_ADD = @@P1_ADD@@
local EXPECT_FAMILIES = @@FAMILIES@@
local EXPECT_SWAP = @@SWAP@@
local EXPECT_ADD = @@ADD@@
local CLASSIC_ENTRIES = @@ENTRIES@@

return function(M, env)
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		results[#results + 1] = { name = name, ok = ok, detail = if ok then nil else tostring(detail) }
	end
	local function expect(condition, message)
		if not condition then
			error(message, 0)
		end
	end
	local function classicEntries()
		local list = {}
		for index, entry in ipairs(CLASSIC_ENTRIES) do
			list[index] = { name = entry.name, path = entry.path, dependencies = table.clone(entry.dependencies), tool = entry.tool }
		end
		return list
	end

	-- Part 1 ------------------------------------------------------------------------------------------------------
	local savedFamilies, savedSwap, savedAdd = M.Families, M.Swap, M.Add
	M.Families, M.Swap, M.Add = P1_FAMILIES, P1_SWAP, P1_ADD
	local okPhase1, phase1Cases = pcall(phase1Test, M, env)
	M.Families, M.Swap, M.Add = savedFamilies, savedSwap, savedAdd
	M._reset()
	if okPhase1 and type(phase1Cases) == "table" then
		for position, row in ipairs(phase1Cases) do
			results[#results + 1] = { name = "phase1: " .. tostring(row.name or position), ok = row.ok == true, detail = row.detail }
		end
		results[#results + 1] = { name = "phase1: the test returned cases", ok = #phase1Cases > 0 }
	else
		results[#results + 1] = { name = "phase1: test run", ok = false, detail = tostring(phase1Cases) }
	end

	-- Part 2 ------------------------------------------------------------------------------------------------------
	case("data: Families, Swap and Add equal the generated tables", function()
		expect(#M.Families == #EXPECT_FAMILIES, "Families has " .. #M.Families .. " names")
		for index, family in ipairs(EXPECT_FAMILIES) do
			expect(M.Families[index] == family, "Families[" .. index .. "] is " .. tostring(M.Families[index]))
		end
		local count = 0
		for name, swap in pairs(M.Swap) do
			count += 1
			local want = EXPECT_SWAP[name]
			expect(want ~= nil, "unexpected swap " .. tostring(name))
			expect(swap.Family == want.Family and swap.Path == want.Path, "swap " .. name .. " differs")
		end
		for name in pairs(EXPECT_SWAP) do
			expect(M.Swap[name] ~= nil, "swap " .. name .. " is missing")
		end
		expect(count > 0, "Swap is empty")
		expect(#M.Add == #EXPECT_ADD, "Add has " .. #M.Add .. " rows")
		for index, want in ipairs(EXPECT_ADD) do
			local row = M.Add[index]
			expect(row.name == want.name and row.path == want.path and row.tool == want.tool and row.Family == want.Family, "Add row " .. index .. " differs")
			expect(table.concat(row.dependencies or {}, ",") == table.concat(want.dependencies, ","), "Add row " .. index .. " dependencies differ")
		end
	end)
	case("every swap names a ClientBase entry and every added dependency exists", function()
		local names = {}
		for _, entry in ipairs(CLASSIC_ENTRIES) do
			names[entry.name] = true
		end
		for name in pairs(M.Swap) do
			expect(names[name], "swap " .. name .. " is not a ClientBase entry")
		end
		for _, row in ipairs(M.Add) do
			expect(not names[row.name], "added entry " .. row.name .. " shadows a ClientBase entry")
			names[row.name] = true
		end
		for _, row in ipairs(M.Add) do
			for _, dependency in ipairs(row.dependencies or {}) do
				expect(names[dependency], "added entry " .. row.name .. " depends on unknown " .. dependency)
			end
		end
	end)
	for count = 1, #EXPECT_FAMILIES do
		case("prefix of " .. count .. " families composes: only its swaps and adds, same names, order, dependencies, tools", function()
			M._reset()
			local prefix, active = {}, {}
			for index = 1, count do
				prefix[index] = EXPECT_FAMILIES[index]
				active[EXPECT_FAMILIES[index]] = true
			end
			local switch = env.FakeSwitch("Pulse")
			if count < #EXPECT_FAMILIES then
				switch.DevFamilies = prefix
			end
			local entries = classicEntries()
			local composed = M.Compose(entries, switch)
			expect(type(composed) == "table" and composed ~= entries, "a new list is required")
			for index, entry in ipairs(entries) do
				local made = composed[index]
				expect(made ~= nil and made ~= entry, "entry " .. entry.name .. " was not copied")
				expect(made.name == entry.name, "name or order changed at " .. index)
				expect(made.tool == entry.tool, "tool changed for " .. entry.name)
				expect(table.concat(made.dependencies, ",") == table.concat(entry.dependencies, ","), "dependencies changed for " .. entry.name)
				local swap = EXPECT_SWAP[entry.name]
				local wanted = if swap and active[swap.Family] then swap.Path else entry.path
				expect(made.path == wanted, entry.name .. " path is " .. tostring(made.path) .. ", expected " .. wanted)
			end
			local position = #entries
			for _, want in ipairs(EXPECT_ADD) do
				if want.Family == nil or active[want.Family] then
					position += 1
					local made = composed[position]
					expect(made ~= nil and made.name == want.name and made.path == want.path and made.tool == want.tool, "added entry " .. want.name .. " is missing or out of order")
					expect(made.Family == nil, "Family left on the composed entry " .. want.name)
				end
			end
			expect(#composed == position, "composed list has " .. #composed .. " entries, expected " .. position)
			local committed = switch.Report().Families
			expect(#committed == count, "committed " .. #committed .. " families")
			for index = 1, count do
				expect(committed[index] == prefix[index], "committed family " .. index .. " is " .. tostring(committed[index]))
			end
			M._reset()
		end)
	end
	return results
end
'''


def main(argv):
    layout, positional, options = common.parse_args(argv, flags=(), values=("--out", "--test-out"))
    if len(positional) != 1:
        print(__doc__)
        return 2
    upto = positional[0]
    text, data = generate(layout, upto)
    installed = common.read_text(TEMPLATE)
    print("Routes for %s: families %s, %d swaps, %d added entries, %d characters" % (
        upto, ", ".join(data["families"]), len(data["swap"]), len(data["add"]), len(text)))
    if upto == "phase1":
        same = text.encode("utf-8") == common.read_bytes(TEMPLATE)
        print("byte for byte equal to the installed Routes: %s" % ("yes" if same else "NO"))
        if not same:
            return 1
    else:
        kept = len(installed) - sum(m.end() - m.start() for m in (
            FAMILIES_RE.search(installed), SWAP_RE.search(installed), ADD_RE.search(installed)))
        print("copied unchanged from the installed Routes: %d of %d characters (the three data tables are rewritten)" % (
            kept, len(installed)))
    if "--out" in options:
        common.write_text(options["--out"], text)
        print("wrote " + options["--out"])
    if "--test-out" in options:
        common.write_text(options["--test-out"], generate_test(layout, upto))
        print("wrote " + options["--test-out"])
    return 0


if __name__ == "__main__":
    common.run_main(main)
