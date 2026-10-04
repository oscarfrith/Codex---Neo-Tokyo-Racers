-- Read-only state probe for the Modern Muscle delivery. Run in Studio Edit before and after the install and
-- compare the two results. It writes nothing. The scoped capture tool does not accept the v3 place, so this
-- probe is the before and after record for the affected scope: the vehicle category roots, the VFX templates,
-- the catalogue chunks, and the garage and flag config attributes.
local function djb2(s)
	local x = 5381
	for i = 1, #s do x = (x * 33 + string.byte(s, i)) % 4294967296 end
	return string.format("%08x", x)
end
local function attributes(instance)
	local rows = {}
	for key, value in pairs(instance:GetAttributes()) do table.insert(rows, key .. "=" .. tostring(value)) end
	table.sort(rows)
	return table.concat(rows, ";")
end
-- Class, name and attributes of every descendant, order-independent.
local function fingerprint(root)
	local rows = {}
	for _, item in ipairs(root:GetDescendants()) do
		table.insert(rows, item.ClassName .. "|" .. item.Name .. "|" .. attributes(item))
	end
	table.sort(rows)
	return #rows .. ":" .. djb2(table.concat(rows, "\n"))
end
local out = { "place=" .. game.PlaceId }
local RS, SS = game:GetService("ReplicatedStorage"), game:GetService("ServerStorage")
for _, pair in ipairs({ { "server", SS.Assets.Vehicles.Categories }, { "preview", RS.Assets.VehiclePreviews.Categories } }) do
	local names = {}
	for _, child in ipairs(pair[2]:GetChildren()) do
		table.insert(names, child.Name)
		table.insert(out, pair[1] .. "." .. child.Name .. " " .. fingerprint(child) .. " hash=" .. tostring(child:GetAttribute("InstalledContentHash")))
	end
	table.insert(out, pair[1] .. ".order=" .. table.concat(names, ","))
end
for _, child in ipairs(RS.Assets.VFX.VehicleTemplates:GetChildren()) do
	table.insert(out, "vfx." .. child.Name .. " " .. fingerprint(child))
end
local index = RS.Modules.Game.Vehicles.VehicleCatalogData
table.insert(out, "catalogue.index " .. #index.Source .. ":" .. djb2(index.Source) .. " revision=" .. tostring(string.match(index.Source, "Revision%s*=%s*\"(%x+)\"")))
local chunks = index:GetChildren()
table.sort(chunks, function(a, b) return a.Name < b.Name end)
for _, chunk in ipairs(chunks) do
	table.insert(out, "catalogue." .. chunk.Name .. " " .. #chunk.Source .. ":" .. djb2(chunk.Source))
end
local replacement = RS.Config.UI.GarageReplacement
table.insert(out, "config.GarageReplacement " .. djb2(attributes(replacement)) .. " hidden=" .. tostring(replacement:GetAttribute("DealershipHiddenCategories")))
table.insert(out, "config.GarageReplacement.tree " .. fingerprint(replacement))
table.insert(out, "config.ReplicatedStorage " .. fingerprint(RS.Config))
table.insert(out, "config.ServerStorage " .. fingerprint(SS.Config) .. " own=" .. djb2(attributes(SS.Config)))
local sources = {}
for _, root in ipairs({ SS, RS, game:GetService("ServerScriptService"), game:GetService("StarterPlayer"), game:GetService("ReplicatedFirst"), game:GetService("StarterGui") }) do
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("LuaSourceContainer") and not item:IsDescendantOf(index) and item ~= index then
			table.insert(sources, item:GetFullName() .. ":" .. djb2(item.Source))
		end
	end
end
table.sort(sources)
table.insert(out, "scripts.other " .. #sources .. ":" .. djb2(table.concat(sources, "\n")))
return table.concat(out, "\n")
