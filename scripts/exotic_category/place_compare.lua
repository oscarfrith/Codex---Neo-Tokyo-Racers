-- Read-only place fingerprint for comparing Space Racers v2 with Backup v2. Writes nothing.
-- Run in Studio Edit mode (execute_luau) in each place and compare the two results.
-- Returns one line per script under the two Modules trees (path, source hash), one line per Config
-- subfolder (instance count, structure-and-attribute hash) and the attributes of ServerStorage.Config.
local function h(s, seed)
	local x = seed or 5381
	for i = 1, #s do x = (x * 33 + string.byte(s, i)) % 4294967296 end
	return x
end
local function attrs(inst)
	local keys = {}
	for k, v in pairs(inst:GetAttributes()) do table.insert(keys, k .. "=" .. tostring(v)) end
	table.sort(keys)
	return table.concat(keys, ";")
end
local lines = {"place " .. game.PlaceId}
for _, root in ipairs({game:GetService("ServerStorage").Modules, game:GetService("ReplicatedStorage").Modules}) do
	local prefix = #root:GetFullName() + 2
	local rows = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			table.insert(rows, string.sub(d:GetFullName(), prefix) .. " " .. string.format("%06x", h(d.Source) % 16777216))
		end
	end
	table.sort(rows)
	table.insert(lines, "== " .. root:GetFullName())
	for _, r in ipairs(rows) do table.insert(lines, r) end
end
local function folderHash(folder)
	local rows = {}
	for _, d in ipairs(folder:GetDescendants()) do
		local value = d:IsA("ValueBase") and tostring(d.Value) or ""
		table.insert(rows, d:GetFullName() .. "|" .. d.ClassName .. "|" .. attrs(d) .. "|" .. value)
	end
	table.sort(rows)
	local x = h(attrs(folder))
	for _, r in ipairs(rows) do x = h(r, x) end
	return string.format("n=%d %08x", #rows, x)
end
for _, cfg in ipairs({game:GetService("ReplicatedStorage").Config, game:GetService("ServerStorage").Config}) do
	table.insert(lines, "== " .. cfg:GetFullName() .. " attrs: " .. attrs(cfg))
	for _, child in ipairs(cfg:GetChildren()) do
		table.insert(lines, child.Name .. " " .. folderHash(child))
		if child.Name == "World" or child.Name == "Vehicles" or child.Name == "Garage" then
			for _, sub in ipairs(child:GetChildren()) do table.insert(lines, "  " .. child.Name .. "." .. sub.Name .. " " .. folderHash(sub)) end
		end
	end
end
return table.concat(lines, "\n")
