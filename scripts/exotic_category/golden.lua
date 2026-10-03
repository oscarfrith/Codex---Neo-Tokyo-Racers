-- Client-side golden reply recorder for the Exotic category delivery (Studio no-save sandbox only).
-- Runs the 18-step GarageInvoke sequence from scripts/architecture/p5/golden.lua, then crafted calls.
-- Each reply is encoded canonically (generated ids normalised BEFORE sorting, numbers %.6g) and
-- reported as one line: label, length, FNV-1a hash, Success|Message. Paste into execute_luau (Client).
-- Steps 01-18 and X01-X06 must be identical before and after Stage A. Steps Z01-Z02 are expected to differ.
return function()
	local player = game.Players.LocalPlayer
	assert(player:GetAttribute("StudioVehicleSandboxActive") == true, "sandbox required")
	local G = game.ReplicatedStorage.Remotes.Garage.GarageInvoke
	local function normalise(s)
		return (s:gsub("(%a+_)%x%x%x%x%x%x%x%x%x%x%x%x", "%1<id>"))
	end
	local function encode(v, depth)
		depth = depth or 0
		local t = typeof(v)
		if t == "table" then
			if depth > 12 then return '"<deep>"' end
			local parts = {}
			for k, value in pairs(v) do
				local key = normalise(tostring(k))
				if k == "CatalogRevision" or k == "KnownCatalogRevision" then
					table.insert(parts, '"' .. key .. '":"<rev>"')
				elseif string.match(key, "AtUnix$") then
					-- os.time() stamps (AcquiredAtUnix): %.6g would step every 10,000 s and break day-to-day comparison.
					table.insert(parts, '"' .. key .. '":"<time>"')
				else
					table.insert(parts, '"' .. key .. '":' .. encode(value, depth + 1))
				end
			end
			table.sort(parts)
			return "{" .. table.concat(parts, ",") .. "}"
		elseif t == "string" then return '"' .. (normalise(v):gsub('"', '\\"')) .. '"'
		elseif t == "number" then return string.format("%.6g", v)
		elseif t == "boolean" or t == "nil" then return tostring(v)
		else return '"' .. t .. ":" .. tostring(v) .. '"' end
	end
	local function fnv(s)
		local h = 2166136261
		for i = 1, #s do
			h = bit32.bxor(h, string.byte(s, i))
			h = bit32.band(h * 16777619, 0xFFFFFFFF)
		end
		return string.format("%08x", h)
	end
	local lines = {}
	local function call(label, action, args)
		local ok, reply = pcall(G.InvokeServer, G, action, args)
		local text = ok and encode(reply) or ("THROW " .. tostring(reply))
		local head = (ok and typeof(reply) == "table") and (tostring(reply.Success) .. "|" .. tostring(reply.Message)) or "?"
		table.insert(lines, string.format("%s len=%d h=%s %s", label, #text, fnv(text), head))
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
	-- Crafted calls that must stay identical.
	call("X01_UnknownModule", "BuyModuleInstance", { ModuleId = "nope", VehicleId = vid, SlotId = "SidePods" })
	call("X02_WrongSlotType", "BuyModuleInstance", { ModuleId = "MODULE_SIDEPODS_LVL1", VehicleId = vid, SlotId = "Boost" })
	call("X03_UnknownSlot", "BuyModuleInstance", { ModuleId = "MODULE_SIDEPODS_LVL1", VehicleId = vid, SlotId = "Nope" })
	call("X04_BuyNoCategory", "BuyCockpitInstance", { CockpitId = "bruiser_02" })
	call("X05_GarageFull", "BuyCockpitInstance", { CategoryId = "bruiser", CockpitId = "bruiser_03" })
	call("X06_GetInitial", "GetInitial", {})
	-- Crafted calls expected to differ after Stage A (category is validated before the profile is changed).
	call("Z01_UnknownCategory", "BuyCockpitInstance", { CategoryId = "zzz", CockpitId = "bruiser_02" })
	call("Z02_GetInitialAfter", "GetInitial", {})
	return table.concat(lines, "\n")
end
