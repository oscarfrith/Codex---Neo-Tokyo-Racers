-- Guarded installer body for the driving_tune delivery. build.py prepends MODE and DATA.
-- AUDIT writes nothing. APPLY writes the after-sources, the config attributes and the new config folders;
-- ROLLBACK restores the before-sources and the earlier attribute values and removes the instances it created.
-- Nothing is written unless every target resolves, every script is in a known state and every source compiles.
-- A script counts as known when its source is the before, the after, or an earlier after of this delivery
-- (DATA.scripts[name].prior), so a rebuilt delivery can be applied over its own previous build.
-- Sources are read from the repository over http://127.0.0.1:8796 (py -3 scripts/driving_tune/serve.py).
local Http = game:GetService("HttpService")
assert(game.PlaceId == DATA.placeId, DATA.base .. ": wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), DATA.base .. ": stop Play first")
local BASE = "http://127.0.0.1:8796/" .. DATA.base
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
local function block(text)
	blockers += 1
	table.insert(report, "BLOCKER " .. text)
end

-- Scripts
local plan = {}
local want = MODE == "ROLLBACK" and "before" or "after"
for name, info in pairs(DATA.scripts) do
	local script = find(info.path)
	local now = script and djb2(script.Source)
	local state = "unknown"
	if not script then
		state = "missing"
	elseif now == info.after then
		state = "after"
	elseif now == info.before then
		state = "before"
	else
		for _, hash in ipairs(info.prior or {}) do
			if now == hash then state = "prior" end
		end
	end
	table.insert(report, name .. ": " .. state)
	if state == "missing" or state == "unknown" then
		block(name .. " is " .. state)
	elseif MODE ~= "AUDIT" and state ~= want then
		local text = Http:GetAsync(BASE .. info.file[want] .. "?t=" .. os.clock(), true)
		if djb2(text) ~= info[want] then
			block(name .. ": the served " .. want .. " source does not match its hash")
		else
			local ok, err = loadstring(text, name)
			if not ok then
				block(name .. ": does not compile: " .. tostring(err))
			else
				plan[name] = { script = script, text = text }
			end
		end
	end
end

-- Attributes: {path, key, value, before} where before is the value recorded at capture (absent = nil).
for _, row in ipairs(DATA.attributes) do
	local node = find(row.path)
	if not node then
		block(table.concat(row.path, ".") .. " missing for attribute " .. row.key)
	else
		local now = node:GetAttribute(row.key)
		if row.before == nil then
			-- A new attribute: any value already there is this delivery's, possibly tuned since. APPLY keeps it.
			if now ~= nil and now ~= row.value then table.insert(report, row.key .. ": tuned (" .. tostring(now) .. ")") end
		elseif now ~= row.value and now ~= row.before then
			block(table.concat(row.path, ".") .. " @" .. row.key .. " is " .. tostring(now) .. ", expected " .. tostring(row.before) .. " or " .. tostring(row.value))
		end
	end
end

-- Instances: created under an existing parent; a same-named child of the same class counts as installed.
for _, spec in ipairs(DATA.instances) do
	local parent = find(spec.parent)
	if not parent then
		block(table.concat(spec.parent, ".") .. " missing for new " .. spec.name)
	else
		local existing = parent:FindFirstChild(spec.name)
		if existing and existing.ClassName ~= spec.class then
			block(spec.name .. " exists as " .. existing.ClassName)
		end
		table.insert(report, spec.name .. ": " .. (existing and "present" or "absent"))
	end
end

if blockers > 0 or MODE == "AUDIT" then
	return table.concat(report, "; ") .. " | blockers=" .. blockers .. " mode=" .. MODE .. " (nothing written)"
end

local History = game:GetService("ChangeHistoryService")
History:SetWaypoint("driving_tune " .. MODE .. " before")
local function build(spec, parent)
	local node = Instance.new(spec.class)
	node.Name = spec.name
	for key, value in pairs(spec.attributes or {}) do node:SetAttribute(key, value) end
	if spec.value ~= nil then node.Value = spec.value end
	for _, child in ipairs(spec.children or {}) do build(child, node) end
	node:SetAttribute("DrivingTuneInstalled", true)
	node.Parent = parent
	return node
end
local wrote, attributes, instances = 0, 0, 0
local restore = {}
local ok, err = pcall(function()
	for _, item in pairs(plan) do
		table.insert(restore, { script = item.script, text = item.script.Source })
		item.script.Source = item.text
		wrote += 1
	end
end)
if not ok then
	for _, item in ipairs(restore) do pcall(function() item.script.Source = item.text end) end
	return "FAILED writing sources, restored " .. #restore .. ": " .. tostring(err)
end
for _, row in ipairs(DATA.attributes) do
	local node = find(row.path)
	local value = row.before
	if MODE == "APPLY" then value = row.value end
	local current = node:GetAttribute(row.key)
	local superseded = false
	for _, old in ipairs(row.was or {}) do
		if current == old then superseded = true end
	end
	if MODE == "APPLY" and row.before == nil and current ~= nil and not superseded then
		-- keep a tuned value; an earlier default of this delivery (row.was) is replaced
	elseif node:GetAttribute(row.key) ~= value then
		node:SetAttribute(row.key, value)
		attributes += 1
	end
end
for _, spec in ipairs(DATA.instances) do
	local parent = find(spec.parent)
	local existing = parent:FindFirstChild(spec.name)
	if MODE == "APPLY" and not existing then
		build(spec, parent)
		instances += 1
	elseif MODE == "APPLY" and existing:GetAttribute("DrivingTuneInstalled") == true then
		-- A later build of this delivery: add attributes the folder does not have yet, keep tuned values.
		for key, value in pairs(spec.attributes or {}) do
			if existing:GetAttribute(key) == nil then
				existing:SetAttribute(key, value)
				attributes += 1
			end
		end
	elseif MODE == "ROLLBACK" and existing and existing:GetAttribute("DrivingTuneInstalled") == true then
		existing:Destroy()
		instances += 1
	end
end
History:SetWaypoint("driving_tune " .. MODE .. " after")
return table.concat(report, "; ") .. " | mode=" .. MODE .. " scriptsWritten=" .. wrote .. " attributesWritten=" .. attributes .. " instancesChanged=" .. instances
