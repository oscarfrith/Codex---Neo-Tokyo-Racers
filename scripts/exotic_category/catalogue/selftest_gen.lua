-- Exotic category, catalogue split: optional read-only self-test of catalogue_gen.lua against Python.
-- It runs the generator over a fake tree (plain tables, no Instances) built from the two-category data that
-- test_chunks.py --emit-synthetic DIR writes, and compares every source hash with Python's chunk_sources().
-- It also checks the text guards and the SHA-256. Nothing is created, written or required.
--
-- Usage (Studio, Edit; DIR served on loopback):
--   local selftest = loadstring(<this file>)()
--   local result = selftest(<catalogue_gen.lua text>, <synthetic_tree.json text>, <synthetic_expected.json text>)
-- result = { ok = bool, failures = { text, ... }, sources = n, revision = <hex> }

return function(generatorSource, treeJson, expectedJson)
	local HttpService = game:GetService("HttpService")
	local failures = {}
	local function expect(condition, what) if not condition then table.insert(failures, what) end end

	-- 1. Helpers: everything above the returned function, with the locals exposed.
	local cut = string.find(generatorSource, "\nreturn function()", 1, true)
	assert(cut, "generator layout changed")
	local helpers = assert(loadstring(string.sub(generatorSource, 1, cut) .. "return { jstr = jstr, num = num, lua = lua, canon = canon, sha256 = sha256, ARRAY = ARRAY }"))()
	expect(helpers.sha256("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "sha256 of empty text")
	expect(helpers.sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "sha256 of abc")
	expect(helpers.sha256(string.rep("a", 1000000)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0", "sha256 of a million a")
	expect(helpers.jstr('a"b\\c\nd\te\rf\bg\fh') == '"a\\"b\\\\c\\nd\\te\\rf\\bg\\fh"', "jstr escapes")
	for _, bad in { "caf\195\169", "x\1y", "x\127y", "x\0y", "x\11y" } do
		expect(not pcall(helpers.jstr, bad), "jstr accepted " .. string.format("%q", bad))
	end
	for _, good in { 0, 1, -1, 0.0001, -0.03, 350000, 12500000, 4.8999999999999995, 0.30000000000000004, 123456789.125, 9007199254740991, 1e15 } do
		expect(pcall(helpers.num, good), "num refused " .. tostring(good))
	end
	for _, bad in { -0, 0 / 0, 1 / 0, -1 / 0, 1e21, 1e100, 0.00001, 2 ^ 53, 1e16, -1e-7 } do
		expect(not pcall(helpers.num, bad), "num accepted " .. tostring(bad))
	end
	expect(helpers.lua({ B = { [helpers.ARRAY] = true, "x", 2 }, A = true, C = Color3.new(1, 0, 0), D = {} }) == '{["A"]=true,["B"]={"x",2},["C"]=Color3.new(1,0,0),["D"]={}}', "lua form")
	expect(not pcall(helpers.lua, { V = Vector3.new(1, 2, 3) }), "lua accepted a Vector3")

	-- 2. The generator over a fake tree.
	local tree = HttpService:JSONDecode(treeJson)
	local expected = HttpService:JSONDecode(expectedJson)
	local root
	local function build(node, parent)
		local inst = { Name = node.n, ClassName = node.c, Parent = parent, Value = node.v }
		local attributes, children = {}, {}
		for name, a in pairs(node.a or {}) do
			if a.type == "Color3" then
				attributes[name] = Color3.new(a.r, a.g, a.b)
				expect(tostring(attributes[name]) == a.text, "Color3 text differs at " .. node.n .. "." .. name)
			else
				attributes[name] = a.value
			end
		end
		function inst.GetAttributes() return attributes end
		function inst.GetChildren() return children end
		function inst.GetFullName()
			local parts, x = {}, inst
			while x do table.insert(parts, 1, x.Name); x = x.Parent end
			return table.concat(parts, ".")
		end
		for i, child in ipairs(node.k or {}) do children[i] = build(child, inst) end
		return inst
	end
	root = build(tree, nil)
	function root.GetDescendants()
		local out = {}
		local function walk(x) for _, c in ipairs(x.GetChildren()) do table.insert(out, c); walk(c) end end
		walk(root)
		return out
	end
	local needle = 'game:GetService("ServerStorage").Assets.Vehicles.Categories'
	local at, last = string.find(generatorSource, needle, 1, true)
	assert(at and not string.find(generatorSource, needle, last + 1, true), "generator root expression changed")
	local chunk = assert(loadstring(string.sub(generatorSource, 1, at - 1) .. "SELFTEST_ROOT" .. string.sub(generatorSource, last + 1)))
	setfenv(chunk, setmetatable({ SELFTEST_ROOT = root }, { __index = getfenv(chunk) }))
	local result = chunk()()
	expect(result.revision == expected.revision, "revision " .. tostring(result.revision) .. " expected " .. tostring(expected.revision))
	expect(result.cockpits == expected.cockpits and result.modules == expected.modules, "counts " .. result.cockpits .. "/" .. result.modules)
	local got = { { name = "VehicleCatalogData", source = result.index, sha256 = result.indexSha256 } }
	for _, c in ipairs(result.chunks) do table.insert(got, c) end
	expect(#got == #expected.sources, "source count " .. #got .. " expected " .. #expected.sources)
	for i, want in ipairs(expected.sources) do
		local have = got[i]
		if have then
			expect(have.name == want.name, "source " .. i .. " is " .. have.name .. " expected " .. want.name)
			expect(#have.source == want.chars, have.name .. " chars " .. #have.source .. " expected " .. want.chars)
			expect(have.sha256 == want.sha256, have.name .. " sha256 differs from Python")
			expect(loadstring(have.source) ~= nil, have.name .. " does not compile")
		end
	end
	return { ok = #failures == 0, failures = failures, sources = #got, revision = result.revision }
end
