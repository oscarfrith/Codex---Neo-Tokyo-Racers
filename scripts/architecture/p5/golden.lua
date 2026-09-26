-- Client-side golden reply recorder (Studio no-save sandbox only). Runs a fixed GarageInvoke sequence and
-- returns canonical JSON (sorted keys, generated ids/revisions normalised) for before/after comparison.
return function()
	local player = game.Players.LocalPlayer
	assert(player:GetAttribute("StudioVehicleSandboxActive") == true, "sandbox required")
	local G = game.ReplicatedStorage.Remotes.Garage.GarageInvoke
	local ids, nextId = {}, 0
	local function normalise(s)
		s = s:gsub("(%a+_)(%x%x%x%x%x%x%x%x%x%x%x%x)", function(prefix, hex)
			local key = prefix .. hex
			if not ids[key] then nextId += 1; ids[key] = prefix .. "#" .. nextId end
			return ids[key]
		end)
		return s
	end
	local function encode(v, depth)
		depth = depth or 0
		local t = typeof(v)
		if t == "table" then
			if depth > 12 then return '"<deep>"' end
			local keys = {}
			for k in pairs(v) do table.insert(keys, k) end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			local parts = {}
			for _, k in ipairs(keys) do
				local key = k
				if k == "CatalogRevision" or k == "KnownCatalogRevision" then
					table.insert(parts, '"' .. tostring(k) .. '":"<rev>"')
				else
					table.insert(parts, '"' .. normalise(tostring(key)) .. '":' .. encode(v[k], depth + 1))
				end
			end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif t == "string" then return '"' .. normalise(v):gsub('"', '\\"') .. '"'
		elseif t == "number" then return string.format("%.6g", v)
		elseif t == "boolean" or t == "nil" then return tostring(v)
		else return '"' .. t .. ":" .. tostring(v) .. '"' end
	end
	local steps = {}
	local function call(label, action, args)
		local ok, reply = pcall(G.InvokeServer, G, action, args)
		table.insert(steps, '"' .. label .. '":' .. (ok and encode(reply) or ('"THROW ' .. tostring(reply) .. '"')))
		task.wait(0.4)
		return reply
	end
	local init = call("01_GetInitial", "GetInitial", {})
	call("02_BuyCockpit", "BuyCockpitInstance", { CategoryId = "bruiser", CockpitId = "bruiser_01" })
	call("03_BuyModule", "BuyModuleInstance", { ModuleId = "MODULE_SIDEPODS_LVL1", SlotId = "SidePods" })
	call("04_BuyCosmetic", "BuyVehicleCosmetic", { CosmeticId = "Underglow" })
	call("05_CosmeticColour", "SetVehicleCosmeticColor", { CosmeticId = "Underglow", Color = Color3.new(0.2, 0.4, 0.9) })
	call("06_BuyNeon", "BuyNeon", { SlotId = "SidePods" })
	call("07_Upgrade", "UpgradeModule", { SlotId = "SidePods", ModuleId = "MODULE_SIDEPODS_LVL1", UpgradeId = "AirflowChannels" })
	call("08_CockpitColour", "SetCockpitColor", { Channel = "Primary", Color = Color3.new(0.9, 0.1, 0.1), ReturnProfile = true })
	call("09_Unaffordable", "BuyCockpitInstance", { CategoryId = "bruiser", CockpitId = "bruiser_06" })
	call("10_BadField", "GetInitial", { Evil = true })
	call("11_UnknownCockpit", "BuyCockpitInstance", { CategoryId = "bruiser", CockpitId = "nope" })
	local after = call("12_GetInitial", "GetInitial", {})
	local vid = after and after.Profile and after.Profile.CurrentVehicleId
	call("13_Select", "SelectVehicleInstance", { VehicleId = vid })
	call("14_Spawn", "SpawnVehicle", {})
	task.wait(1.5)
	call("15_Exit", "ExitVehicle", {})
	task.wait(1)
	call("16_ReEnter", "ReEnterVehicle", {})
	task.wait(1)
	call("17_Despawn", "DespawnVehicle", {})
	call("18_GetInitialKnownRev", "GetInitial", { KnownCatalogRevision = init and init.CatalogRevision or "" })
	return "{" .. table.concat(steps, ",") .. "}"
end
