-- Guarded installer body for the hover_feel delivery. build.py prepends MODE and DATA.
-- AUDIT writes nothing. APPLY writes the after-sources, the config attributes and the new config instances;
-- ROLLBACK restores the before-sources and the earlier attribute values and removes the instances it created.
-- Nothing is written unless every target resolves, every script is in a known state and every source compiles.
-- A script counts as known when its source is the before, the after, or an earlier after of this delivery
-- (DATA.scripts[name].prior), so a rebuilt delivery can be applied over its own previous build.
-- Sources are read from the repository over http://127.0.0.1:8794 (py -3 scripts/hover_feel/serve.py).
local Http = game:GetService("HttpService")
assert(game.PlaceId == DATA.placeId, DATA.base .. ": wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), DATA.base .. ": stop Play first")
local BASE = "http://127.0.0.1:8794/" .. DATA.base
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

-- Builders: {file, parent, textures}. The file returns function(textures) -> { Instance, ... }: pure construction
-- of new instances (the Exotic V2 effect templates). They are built here, before anything is written, so a
-- builder that fails or collides with an instance this delivery did not create blocks the whole run.
local built = {}
for _, spec in ipairs(DATA.builders or {}) do
	local parent = find(spec.parent)
	if not parent then
		block(table.concat(spec.parent, ".") .. " missing for builder " .. spec.file)
	elseif MODE ~= "ROLLBACK" then
		local text = Http:GetAsync(BASE .. spec.file .. "?t=" .. os.clock(), true)
		local chunk, err = loadstring(text, spec.file)
		local ok, result = false, err
		if chunk then
			ok, result = pcall(function() return chunk()(spec.textures or {}) end)
		end
		if not ok or type(result) ~= "table" then
			block(spec.file .. " failed: " .. tostring(result))
		else
			for _, instance in ipairs(result) do
				local existing = parent:FindFirstChild(instance.Name)
				if existing and existing:GetAttribute("HoverFeelBuilder") ~= spec.file then
					block(instance.Name .. " already exists and was not made by " .. spec.file)
				end
			end
			built[spec.file] = { parent = parent, instances = result }
			table.insert(report, spec.file .. ": builds " .. #result)
		end
	end
end

if blockers > 0 or MODE == "AUDIT" then
	return table.concat(report, "; ") .. " | blockers=" .. blockers .. " mode=" .. MODE .. " (nothing written)"
end

local History = game:GetService("ChangeHistoryService")
History:SetWaypoint("hover_feel " .. MODE .. " before")
local function build(spec, parent)
	local node = Instance.new(spec.class)
	node.Name = spec.name
	for key, value in pairs(spec.attributes or {}) do node:SetAttribute(key, value) end
	if spec.value ~= nil then node.Value = spec.value end
	for _, child in ipairs(spec.children or {}) do build(child, node) end
	node:SetAttribute("HoverFeelInstalled", true)
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
	elseif MODE == "ROLLBACK" and existing and existing:GetAttribute("HoverFeelInstalled") == true then
		existing:Destroy()
		instances += 1
	end
end
-- Later-round changes to config this delivery created (DATA.updates), applied after the instances exist.
-- Each is {path, key, value}; a missing value removes the attribute. They only ever touch attributes that this
-- delivery introduced, so ROLLBACK needs nothing here: it removes those attributes and instances above.
-- DATA.lateInstances are new children under instances this delivery created; skipped when the parent is absent.
local updates = 0
if MODE == "APPLY" then
	for _, spec in ipairs(DATA.lateInstances or {}) do
		local parent = find(spec.parent)
		if parent and not parent:FindFirstChild(spec.name) then
			build(spec, parent)
			instances += 1
		end
	end
	for _, row in ipairs(DATA.updates or {}) do
		local node = find(row.path)
		if node and node:GetAttribute(row.key) ~= row.value then
			node:SetAttribute(row.key, row.value)
			updates += 1
		end
	end
end
-- Built instances replace this builder's earlier output; ROLLBACK removes it.
local builderChanges = 0
for _, spec in ipairs(DATA.builders or {}) do
	local parent = find(spec.parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:GetAttribute("HoverFeelBuilder") == spec.file then
			child:Destroy()
			builderChanges += 1
		end
	end
	if MODE == "APPLY" then
		for _, instance in ipairs(built[spec.file].instances) do
			instance:SetAttribute("HoverFeelBuilder", spec.file)
			instance.Parent = parent
			builderChanges += 1
		end
	end
end
table.insert(report, "updates=" .. updates .. " builderChanges=" .. builderChanges)
History:SetWaypoint("hover_feel " .. MODE .. " after")
return table.concat(report, "; ") .. " | mode=" .. MODE .. " scriptsWritten=" .. wrote .. " attributesWritten=" .. attributes .. " instancesChanged=" .. instances
