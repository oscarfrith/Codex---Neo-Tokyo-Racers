local MODE = "AUDIT"
local DATA = game:GetService("HttpService"):JSONDecode([==[{"attributes": [["ModuleArtwork/FrontBody", "SortOrder", 32], ["ModuleArtwork/RearBody", "SortOrder", 34]], "base": "scripts/exotic_category/ui_shop_order/", "placeId": 93959280828322, "scripts": {"GarageModuleCardViewModel": {"after": 2841705015, "before": 2287884197, "path": ["ReplicatedStorage", "Modules", "Game", "UI", "GarageModuleCardViewModel"]}}}]==])
-- Guarded garage UI installer body, shared by ui_artwork and ui_dealership. build.py prepends MODE and DATA.
-- AUDIT writes nothing. APPLY writes the two after-sources and the config attributes; ROLLBACK restores the
-- before-sources and removes the attributes. A script is written only when its current source is exactly the
-- expected one (before for APPLY, after for ROLLBACK); a script already in the target state is left alone.
-- Sources are read from the repository over http://127.0.0.1:8793 (py -3 -m http.server 8793 at the repo root),
-- from the folder DATA.base names.
local Http = game:GetService("HttpService")
assert(game.PlaceId == DATA.placeId, DATA.base .. ": wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), DATA.base .. ": stop Play first")
local BASE = "http://127.0.0.1:8793/" .. DATA.base
local function djb2(s)
	local x = 5381
	for i = 1, #s do x = (x * 33 + string.byte(s, i)) % 4294967296 end
	return x
end
local function find(path)
	local node = game:GetService(path[1])
	for i = 2, #path do node = node and node:FindFirstChild(path[i]) end
	return node
end
local report, blockers = {}, 0
local plan = {}
local want = MODE == "ROLLBACK" and "before" or "after"
for name, info in pairs(DATA.scripts) do
	local script = find(info.path)
	local now = script and djb2(script.Source)
	local state = not script and "missing" or now == info.before and "before" or now == info.after and "after" or "unknown"
	if state == "missing" or state == "unknown" then blockers += 1 end
	table.insert(report, name .. ": " .. state)
	if MODE ~= "AUDIT" and (state == "before" or state == "after") and state ~= want then
		local text = Http:GetAsync(BASE .. want .. "/" .. name .. ".lua?t=" .. os.clock(), true)
		if djb2(text) ~= info[want] then
			blockers += 1
			table.insert(report, name .. ": the served " .. want .. " source does not match its hash")
		else
			local ok, err = loadstring(text, name)
			if not ok then
				blockers += 1
				table.insert(report, name .. ": does not compile: " .. tostring(err))
			else
				plan[name] = {script = script, text = text}
			end
		end
	end
end
-- Attribute rows: {path under Config.UI.GarageReplacement ("" for the folder itself, "/"-separated), key, value}.
local configRoot = game:GetService("ReplicatedStorage").Config.UI.GarageReplacement
local function target(path)
	local node = configRoot
	for part in string.gmatch(path, "[^/]+") do node = node and node:FindFirstChild(part) end
	return node
end
for _, row in ipairs(DATA.attributes) do
	if not target(row[1]) then
		blockers += 1
		table.insert(report, "GarageReplacement/" .. row[1] .. " missing")
	end
end
if blockers > 0 or MODE == "AUDIT" then
	return table.concat(report, "; ") .. " | blockers=" .. blockers .. " mode=" .. MODE .. " (nothing written)"
end
local wrote = 0
for _, item in pairs(plan) do
	item.script.Source = item.text
	wrote += 1
end
for _, row in ipairs(DATA.attributes) do
	if MODE == "APPLY" then
		target(row[1]):SetAttribute(row[2], row[3])
	else
		target(row[1]):SetAttribute(row[2], nil)
	end
end
return table.concat(report, "; ") .. " | mode=" .. MODE .. " scriptsWritten=" .. wrote .. " attributes=" .. #DATA.attributes
