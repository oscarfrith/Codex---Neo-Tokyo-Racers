-- Neo Tokyo Racers - Vehicle Phase AK server core gate repair
--
-- Fixes:
-- 1. Server error when driving/customising after Phase AK:
--    "attempt to call a nil value" inside GarageActionController.
--    Cause: the Phase AK helper block referenced a later local function.
-- 2. Ensures Engine1 and Engine2 slots both use the shared Engines catalogue.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Vehicle Phase AK Server Gate Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function replaceOnce(source, needle, replacement, label)
	local firstStart, firstEnd = string.find(source, needle, 1, true)
	if not firstStart then
		error(label .. " expected exactly 1 match, found 0")
	end
	local secondStart = string.find(source, needle, firstEnd + 1, true)
	if secondStart then
		error(label .. " expected exactly 1 match, found more than 1")
	end
	return string.sub(source, 1, firstStart - 1) .. replacement .. string.sub(source, firstEnd + 1)
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local source = serverScript.Source

if not string.find(source, "NTR_VEHICLE_PHASE_AK_SERVER_BEGIN", 1, true) then
	error("Phase AK server block was not found. Run the main Phase AK installer first, or refresh the Studio mirror before patching.")
end

if not string.find(source, "NTR_VEHICLE_PHASE_AK_CORE_GATE_REPAIR", 1, true) then
	local oldFunction = [[	local function V76_coreModulesEquipped(profile)
		local hasEngine, hasStabilisers, hasBoost = false, false, false
		for _, moduleId in pairs((profile and profile.InstalledModules) or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			local moduleType = V56_moduleTypeForModel(module)
			if moduleType == "Engine" then hasEngine = true end
			if moduleType == "Stabilisers" or moduleType == "Stabiliser" then hasStabilisers = true end
			if moduleType == "Boost" then hasBoost = true end
		end
		return hasEngine and hasStabilisers and hasBoost
	end]]

	local newFunction = [[	-- NTR_VEHICLE_PHASE_AK_CORE_GATE_REPAIR
	local function V76_coreModulesEquipped(profile)
		local hasEngine, hasStabilisers, hasBoost = false, false, false
		for _, moduleId in pairs((profile and profile.InstalledModules) or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			local moduleType = module and module:GetAttribute("ModuleType")
			if moduleType == nil or moduleType == "" then
				local text = string.lower(tostring(moduleId or "") .. " " .. tostring(module and module.Name or ""))
				if string.find(text, "engine", 1, true) then
					moduleType = "Engine"
				elseif string.find(text, "stabiliser", 1, true) or string.find(text, "stabilizer", 1, true) then
					moduleType = "Stabilisers"
				elseif string.find(text, "boost", 1, true) then
					moduleType = "Boost"
				end
			end
			if moduleType == "Engine" then hasEngine = true end
			if moduleType == "Stabilisers" or moduleType == "Stabiliser" then hasStabilisers = true end
			if moduleType == "Boost" then hasBoost = true end
		end
		return hasEngine and hasStabilisers and hasBoost
	end]]

	source = replaceOnce(source, oldFunction, newFunction, "server core module gate function")
	serverScript.Source = source
	info("Patched server core module gate.")
else
	info("Server core module gate repair already installed.")
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local bruiser = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories"):WaitForChild("BRUISER")
local cockpitRoot = bruiser:FindFirstChild("COCKPITS_ReplaceAssetsHere") or bruiser:FindFirstChild("COCKPITS") or bruiser:FindFirstChild("Cockpits")
if cockpitRoot then
	for _, cockpit in ipairs(cockpitRoot:GetDescendants()) do
		if cockpit:IsA("Model") and cockpit:GetAttribute("CockpitId") then
			local slots = cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
			if slots then
				for _, slotName in ipairs({ "SLOT_Engine1", "SLOT_Engine2" }) do
					local slot = slots:FindFirstChild(slotName)
					if slot then
						slot:SetAttribute("ModuleType", "Engine")
						slot:SetAttribute("AllowedModuleFolder", "Engines")
					end
				end
			end
		end
	end
end

info("Engine1 and Engine2 slots now point at the shared Engines catalogue. Stop Play and start Play again.")
