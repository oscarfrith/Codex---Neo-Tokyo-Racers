local MODE = "APPLY"
local DATA = game:GetService("HttpService"):JSONDecode([==[{"attributes": [["All", "Image_exotic", "rbxassetid://128118074135601"], ["Cockpit", "Image_exotic", "rbxassetid://81262312162264"], ["FrontBody", "Image_exotic", "rbxassetid://83836476075409"], ["FrontEngine", "Image_exotic", "rbxassetid://131895203472955"], ["Stabilisers", "Image_exotic", "rbxassetid://105948755652652"], ["RearEngine", "Image_exotic", "rbxassetid://87580925930089"], ["RearBody", "Image_exotic", "rbxassetid://94927048868347"], ["Boost", "Image_exotic", "rbxassetid://125156887089093"], ["Spoiler", "Image_exotic", "rbxassetid://99681362447707"], ["SidePods", "Hidden_exotic", true], ["FrontBumper", "Hidden_exotic", true], ["RearBumper", "Hidden_exotic", true]], "placeId": 93959280828322, "scripts": {"GarageUI": {"after": 3759046153, "before": 2532968798, "path": ["ReplicatedStorage", "Modules", "Game", "Garage", "GarageUI"]}, "GarageWorkspaceUI": {"after": 273635997, "before": 4159466399, "path": ["ReplicatedStorage", "Modules", "Game", "UI", "GarageWorkspaceUI"]}}}]==])
-- Category-aware slot artwork: guarded installer body. build.py prepends MODE and DATA.
-- AUDIT writes nothing. APPLY writes the two after-sources and the config attributes; ROLLBACK restores the
-- before-sources and removes the attributes. A script is written only when its current source is exactly the
-- expected one (before for APPLY, after for ROLLBACK); a script already in the target state is left alone.
-- Sources are read from the repository over http://127.0.0.1:8793 (py -3 -m http.server 8793 at the repo root).
local Http = game:GetService("HttpService")
assert(game.PlaceId == DATA.placeId, "ui_artwork: wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), "ui_artwork: stop Play first")
local BASE = "http://127.0.0.1:8793/scripts/exotic_category/ui_artwork/"
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
local artwork = game:GetService("ReplicatedStorage").Config.UI.GarageReplacement:FindFirstChild("ModuleArtwork")
if not artwork then
	blockers += 1
	table.insert(report, "ModuleArtwork folder missing")
end
for _, row in ipairs(DATA.attributes) do
	if artwork and not artwork:FindFirstChild(row[1]) then
		blockers += 1
		table.insert(report, "ModuleArtwork." .. row[1] .. " missing")
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
		artwork[row[1]]:SetAttribute(row[2], row[3])
	else
		artwork[row[1]]:SetAttribute(row[2], nil)
	end
end
return table.concat(report, "; ") .. " | mode=" .. MODE .. " scriptsWritten=" .. wrote .. " attributes=" .. #DATA.attributes
