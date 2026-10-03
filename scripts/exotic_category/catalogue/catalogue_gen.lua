-- Exotic category, catalogue split: read-only generator for VehicleCatalogData (index) and its chunk children.
-- Luau port of scripts/performance_phase3/catalogue.py project() and chunk_sources(). Keep the two in step:
-- the same whitelist, the same packing, byte-identical sources for the same authoring data.
--
-- Usage (Studio, Edit):  local generate = loadstring(<this file>)()   local result = generate()
-- result = {
--   index = <VehicleCatalogData source>, indexSha256 = <hex>,
--   chunks = { { name = "PIERCER_1", source = <source>, sha256 = <hex> }, ... },   -- in require order
--   revision = <hex>, cockpits = n, modules = n,
-- }
-- It reads ServerStorage.Assets.Vehicles.Categories and never writes. The installer writes the sources.
-- It refuses data that would not be the same text from Python, or would not compile: non-ASCII or control
-- characters in strings, and numbers that print as e, inf, nan or -0 (or lie outside 0.0001 .. 2^53).

local RAW = string.split("TopSpeed EngineOutput Weight LateralGrip SteeringResponse HoverStability DriftControl DriftGrip DriftChargeRate BrakingForce BoostForce BoostDuration BoostRecharge BoostRechargeDelay BoostEfficiency Drag Downforce", " ")
local PUBLIC, PATH_KEYS = {}, {}
for _, x in RAW do PUBLIC[x] = true; PUBLIC["PerformanceDelta_" .. x] = true; PATH_KEYS["DeltaFraction_" .. x] = true; PATH_KEYS["DeltaFlat_" .. x] = true end
for _, x in string.split("CockpitId ModuleId CategoryId DisplayName MenuImage CockpitImage ThumbnailImage ImageId Image PreviewImage ModuleSlot ModuleType ModuleFolder EnginePosition RearEngine UpgradePointCapacity MaxPointsPerPath RetiredFromCatalog CatalogVisible HiddenFromCatalog CatalogPublishReady Price PurchasePrice NeonPrice OwnedByDefault Upgradable VariantName VariantOrder SourceCockpitId SourceCockpitDisplayName StandardAudioProfileId DefaultFrontEngineModuleId DefaultEngineModuleId DefaultRearEngineModuleId DefaultEngineBModuleId DefaultStabilisersModuleId DefaultStabiliserModuleId DefaultBoostModuleId DefaultPrimaryColor DefaultSecondaryColor DefaultDetailColor DefaultNeonColor DefaultFrontLightsColor DefaultRearLightsColor", " ") do PUBLIC[x] = true end
-- Opt-in names (catalogue.py OPT_IN).
for _, x in string.split("DefaultFrontBodyModuleId DefaultRearBodyModuleId DefaultSidePodsModuleId DefaultFrontBumperModuleId DefaultRearBumperModuleId DefaultRearSpoilerModuleId RatingReferenceCockpitId", " ") do assert(not PUBLIC[x], x); PUBLIC[x] = true end
for i = 1, 6 do PUBLIC["Point" .. i .. "CostGuide"] = true; PATH_KEYS["Point" .. i .. "CostGuide"] = true end
for _, x in { "PathId", "DisplayName", "MaxPoints" } do PATH_KEYS[x] = true end

local CHUNK_FILL, SOURCE_LIMIT = 150000, 190000
local INDEX_HEADER = "-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.\n"
local CHUNK_HEADER = "-- GENERATED public catalogue chunk; edit canonical model attributes, regenerate, then restart Play.\n"
local MERGE = '\tlocal chunk=require(script:WaitForChild(name))\n\tfor _,kind in {"Cockpits","Modules"} do\n\t\tfor id,record in pairs(chunk[kind]) do\n\t\t\tassert(data[kind][id]==nil,"Duplicate catalogue id "..tostring(id).." in "..name)\n\t\t\tdata[kind][id]=record\n\t\tend\n\tend\nend\n'
local FREEZE = 'local function freeze(t) for _,v in pairs(t) do if type(v)=="table" then freeze(v) end end return table.freeze(t) end\nreturn freeze(data)\n'
local IMAGES = { "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }
local NAMED = { VehiclePerformanceV2UpgradePaths = true, UpgradePaths = true }
for _, x in IMAGES do NAMED[x] = true end

-- Python json.dumps(str, ensure_ascii=True) for the text Luau can also read back. Python writes every other
-- control character, and DEL, in a form Luau does not read, so those are refused here.
local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }
local function jstr(s)
	assert(not string.find(s, "[\128-\255]"), "Non-ASCII text in public catalogue data: " .. s)
	local text = string.gsub(s, '[%c"\\]', function(c)
		return ESCAPES[c] or error("Control character in public catalogue data: " .. string.format("%q", s))
	end)
	return '"' .. text .. '"'
end
-- Python repr(float) / str(int) for the numbers both sides print the same way.
local function num(v)
	local text, size = tostring(v), math.abs(v)
	assert(v == v and size ~= math.huge and text ~= "-0" and not string.find(text, "e", 1, true) and (v == 0 or (size >= 0.0001 and size < 2 ^ 53)), "Number is not safe in the public catalogue: " .. text)
	return text
end
local ARRAY = {}
local function sortedKeys(v)
	local keys = {}
	for k in pairs(v) do if k ~= ARRAY then table.insert(keys, k) end end
	table.sort(keys)
	return keys
end
-- Lua source form (catalogue.py lua()).
local function lua(v)
	local t = typeof(v)
	if t == "Color3" then return "Color3.new(" .. num(v.R) .. "," .. num(v.G) .. "," .. num(v.B) .. ")" end
	if t == "table" then
		local parts = {}
		if v[ARRAY] then
			for _, x in ipairs(v) do table.insert(parts, lua(x)) end
		else
			for _, k in ipairs(sortedKeys(v)) do table.insert(parts, "[" .. jstr(k) .. "]=" .. lua(v[k])) end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if t == "boolean" then return v and "true" or "false" end
	if t == "string" then return jstr(v) end
	if t == "number" then return num(v) end
	error("Unsupported public attribute type " .. t)
end
-- Canonical JSON used for Revision: json.dumps(out, sort_keys=True, separators=(',',':')).
-- Color3 is the capture record {b,g,r,text,type} (scripts/studio_export_snapshot.lua).
local function canon(v)
	local t = typeof(v)
	if t == "Color3" then
		return '{"b":' .. num(v.B) .. ',"g":' .. num(v.G) .. ',"r":' .. num(v.R) .. ',"text":' .. jstr(tostring(v)) .. ',"type":"Color3"}'
	end
	if t == "table" then
		local parts = {}
		if v[ARRAY] then
			for _, x in ipairs(v) do table.insert(parts, canon(x)) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for _, k in ipairs(sortedKeys(v)) do table.insert(parts, jstr(k) .. ":" .. canon(v[k])) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if t == "boolean" then return v and "true" or "false" end
	if t == "string" then return jstr(v) end
	if t == "number" then return num(v) end
	error("Unsupported public attribute type " .. t)
end
local function sha256(msg)
	local band, bxor, bnot, rrotate, rshift = bit32.band, bit32.bxor, bit32.bnot, bit32.rrotate, bit32.rshift
	local k = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	}
	local h = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }
	local bits = #msg * 8
	msg = msg .. "\128" .. string.rep("\0", (55 - #msg) % 64) .. string.pack(">I8", bits)
	assert(#msg % 64 == 0)
	local w = table.create(64, 0)
	for chunk = 1, #msg, 64 do
		for i = 0, 15 do w[i + 1] = string.unpack(">I4", msg, chunk + i * 4) end
		for i = 17, 64 do
			local a, b = w[i - 15], w[i - 2]
			local s0 = bxor(rrotate(a, 7), rrotate(a, 18), rshift(a, 3))
			local s1 = bxor(rrotate(b, 17), rrotate(b, 19), rshift(b, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % 4294967296
		end
		local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
		for i = 1, 64 do
			local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local t1 = (hh + s1 + ch + k[i] + w[i]) % 4294967296
			local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local t2 = (s0 + maj) % 4294967296
			hh, g, f, e, d, c, b, a = g, f, e, (d + t1) % 4294967296, c, b, a, (t1 + t2) % 4294967296
		end
		h[1] = (h[1] + a) % 4294967296; h[2] = (h[2] + b) % 4294967296; h[3] = (h[3] + c) % 4294967296; h[4] = (h[4] + d) % 4294967296
		h[5] = (h[5] + e) % 4294967296; h[6] = (h[6] + f) % 4294967296; h[7] = (h[7] + g) % 4294967296; h[8] = (h[8] + hh) % 4294967296
	end
	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8])
end
local function attrs(inst, keys)
	local a = {}
	for k, v in pairs(inst:GetAttributes()) do if keys[k] then a[k] = v end end
	return a
end

return function()
	local ROOT = game:GetService("ServerStorage").Assets.Vehicles.Categories
	local function relPath(inst)
		local parts = { [ARRAY] = true }
		local x = inst
		while x ~= ROOT do table.insert(parts, 1, x.Name); x = x.Parent end
		return parts
	end
	-- project()
	local out = { SchemaVersion = 1, Cockpits = {}, Modules = {} }
	local nC, nM = 0, 0
	for _, node in ipairs(ROOT:GetDescendants()) do
		if node.ClassName == "Model" then
			local a = attrs(node, PUBLIC)
			assert(not (a.CockpitId ~= nil and a.ModuleId ~= nil), "Both ids on " .. node:GetFullName())
			local field = a.CockpitId ~= nil and "CockpitId" or (a.ModuleId ~= nil and "ModuleId" or nil)
			if field then
				local key = a[field]
				local index = field == "CockpitId" and out.Cockpits or out.Modules
				assert(type(key) == "string" and key ~= "", field .. " must be a non-empty string at " .. node:GetFullName())
				assert(not index[key], "duplicate id " .. key .. " at " .. node:GetFullName())
				a.Name = node.Name; a.IsVehicleDefinition = true; a.TemplatePath = relPath(node)
				-- Python keeps one child per name; two children with a name read here would be ambiguous.
				local children = {}
				for _, c in ipairs(node:GetChildren()) do
					if NAMED[c.Name] then
						assert(not children[c.Name], "Two children named " .. c.Name .. " under " .. node:GetFullName())
						children[c.Name] = c
					end
				end
				for _, image in IMAGES do
					local c = children[image]
					if c and c.ClassName == "StringValue" then a[image .. "ChildValue"] = c.Value end
				end
				local root = children.VehiclePerformanceV2UpgradePaths or children.UpgradePaths
				local paths, names, ids = { [ARRAY] = true }, {}, {}
				if root then
					for _, p in ipairs(root:GetChildren()) do
						if p.ClassName == "Folder" then
							local v = attrs(p, PATH_KEYS); v.Name = p.Name
							local pid = v.PathId
							if pid == nil then pid = p.Name end
							assert(type(pid) == "string", "PathId must be a string on " .. p:GetFullName())
							assert(not names[p.Name] and not ids[pid], "duplicate upgrade path on " .. node:GetFullName())
							names[p.Name] = true; ids[pid] = true
							table.insert(paths, v)
						end
					end
				end
				table.sort(paths, function(x, y) return (x.PathId or x.Name) < (y.PathId or y.Name) end)
				a.UpgradePaths = paths
				index[key] = a
				if field == "CockpitId" then nC += 1 else nM += 1 end
			end
		end
	end
	assert(nC > 0 and nM > 0, "No cockpits or no modules under " .. ROOT:GetFullName())
	for _, c in pairs(out.Cockpits) do
		for key, value in pairs(c) do
			if type(key) == "string" and string.sub(key, 1, 7) == "Default" and string.sub(key, -8) == "ModuleId" then
				assert(out.Modules[tostring(value)], "missing default " .. c.Name .. " " .. key .. " " .. tostring(value))
			end
		end
	end
	local revision = sha256(canon(out))
	-- chunk_sources()
	for _, m in pairs(out.Modules) do
		if m.RatingReferenceCockpitId ~= nil then
			assert(out.Cockpits[tostring(m.RatingReferenceCockpitId)], "missing rating reference " .. m.Name .. " " .. tostring(m.RatingReferenceCockpitId))
		end
	end
	local groups, folders = {}, {}
	for _, kind in { "Cockpits", "Modules" } do
		for _, key in ipairs(sortedKeys(out[kind])) do
			local record = out[kind][key]
			local folder = record.TemplatePath[1]
			if not groups[folder] then groups[folder] = {}; table.insert(folders, folder) end
			table.insert(groups[folder], { kind = kind, text = "[" .. jstr(key) .. "]=" .. lua(record) })
		end
	end
	table.sort(folders)
	local chunks, used, quoted = {}, {}, {}
	for _, folder in ipairs(folders) do
		local packs, size = {}, 0
		for _, entry in ipairs(groups[folder]) do
			if #packs == 0 or size + #entry.text + 1 > CHUNK_FILL then table.insert(packs, { Cockpits = {}, Modules = {} }); size = 0 end
			table.insert(packs[#packs][entry.kind], entry.text); size += #entry.text + 1
		end
		for i, pack in ipairs(packs) do
			local name = folder .. "_" .. tostring(i)
			assert(not used[name], "duplicate chunk name " .. name)
			used[name] = true
			local source = CHUNK_HEADER .. 'return {["Cockpits"]={' .. table.concat(pack.Cockpits, ",") .. '},["Modules"]={' .. table.concat(pack.Modules, ",") .. "}}\n"
			assert(#source < SOURCE_LIMIT, "source too long " .. name .. " " .. #source)
			table.insert(chunks, { name = name, source = source, sha256 = sha256(source) })
			table.insert(quoted, jstr(name))
		end
	end
	local index = INDEX_HEADER .. "local data=" .. lua({ Cockpits = {}, Modules = {}, Revision = revision, SchemaVersion = out.SchemaVersion }) .. "\nfor _,name in {" .. table.concat(quoted, ",") .. "} do\n" .. MERGE .. FREEZE
	assert(#index < SOURCE_LIMIT, "source too long VehicleCatalogData " .. #index)
	return { index = index, indexSha256 = sha256(index), chunks = chunks, revision = revision, cockpits = nC, modules = nM }
end
