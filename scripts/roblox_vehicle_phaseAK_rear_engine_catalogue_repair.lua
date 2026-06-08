-- Neo Tokyo Racers - Vehicle Phase AK rear engine catalogue repair
--
-- Run this in Roblox Studio Command Bar after Phase AK if Engines_B still has
-- the old flat MODULE_ENGINE_B_01 style instead of matching the new Engines
-- Bruiser_01/Bruiser_02/... Standard/Lightweight/Power folder layout.
--
-- This creates rear-engine family folders under Engines_B, points Engine2 slots
-- at Engines_B, and patches Phase AK default ownership/stats so cockpit purchase
-- grants one standard front engine and one standard rear engine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK Rear Engine Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		error(parent:GetFullName() .. "." .. name .. " exists but is " .. folder.ClassName .. ", expected Folder")
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
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

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local bruiser = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories"):WaitForChild("BRUISER")
local cockpitRoot = bruiser:FindFirstChild("COCKPITS_ReplaceAssetsHere") or bruiser:FindFirstChild("COCKPITS") or bruiser:FindFirstChild("Cockpits")
assert(cockpitRoot, "Could not find Bruiser cockpit root")
local moduleRoot = ensureFolder(bruiser, "MODULES_InterchangeableWithinCategory")
local frontRoot = ensureFolder(moduleRoot, "Engines")
local rearRoot = ensureFolder(moduleRoot, "Engines_B")

local cockpits = {}
for _, item in ipairs(cockpitRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("CockpitId") then
		table.insert(cockpits, item)
	end
end
table.sort(cockpits, function(a, b)
	return tostring(a:GetAttribute("CockpitId")) < tostring(b:GetAttribute("CockpitId"))
end)
assert(#cockpits > 0, "No Bruiser cockpit models with CockpitId were found")

local function findRearTemplate()
	for _, item in ipairs(rearRoot:GetDescendants()) do
		if item:IsA("Model") and item:FindFirstChild("ModuleRoot_DoNotRename", true) then
			return item
		end
	end
	for _, item in ipairs(frontRoot:GetDescendants()) do
		if item:IsA("Model") and item.Name == "MODULE_ENGINE_B" and item:FindFirstChild("ModuleRoot_DoNotRename", true) then
			return item
		end
	end
	for _, item in ipairs(frontRoot:GetDescendants()) do
		if item:IsA("Model") and item:FindFirstChild("ModuleRoot_DoNotRename", true) then
			return item
		end
	end
end

local rearTemplate = findRearTemplate()
assert(rearTemplate, "Could not find a rear engine template to clone")

local statNames = {
	"Price",
	"Power",
	"TopSpeed",
	"Acceleration",
	"Handling",
	"Drift",
	"Braking",
	"Weight",
	"Boost",
	"BoostDuration",
	"BoostRecharge",
	"BoostRechargeDelay",
	"NeonPrice",
}

local function applyStats(model, stats)
	for _, name in ipairs(statNames) do
		if stats[name] ~= nil then
			model:SetAttribute(name, stats[name])
		end
	end
	model:SetAttribute("BalancePhase", "AK_RearEngineRepair")
	model:SetAttribute("BalanceEditable", true)
	model:SetAttribute("BalanceNote", "Rear engine rough baseline. Tune these attributes in Studio after play-testing.")
end

local function findModuleById(moduleId)
	for _, item in ipairs(moduleRoot:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") == moduleId then
			return item
		end
	end
end

local function ensureRearEngine(parent, moduleId, displayName, tier, stats)
	local model = findModuleById(moduleId)
	if not model then
		model = rearTemplate:Clone()
	end
	model.Name = moduleId
	model.Parent = parent
	model:SetAttribute("ModuleId", moduleId)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("ModuleName", displayName)
	model:SetAttribute("ModuleType", "Engine")
	model:SetAttribute("ModuleSlot", "Engine")
	model:SetAttribute("ModuleFolder", "Engines_B")
	model:SetAttribute("Tier", tier)
	model:SetAttribute("RearEngine", true)
	model:SetAttribute("RetiredFromCatalog", false)
	applyStats(model, stats)
	return model
end

local desiredRear = {}
for index, cockpit in ipairs(cockpits) do
	local short = string.format("%02d", index)
	local cockpitName = cockpit:GetAttribute("DisplayName") or cockpit.Name
	local family = ensureFolder(rearRoot, "Bruiser_" .. short)
	local basePrice = math.max(0, (cockpit:GetAttribute("Price") or 0) * 0.18)
	local familyTopSpeed = 7 + index
	local familyAccel = 4 + math.floor(index / 2)

	local standard = ensureRearEngine(family, "MODULE_ENGINE_B_BRUISER_" .. short .. "_STANDARD", cockpitName .. " Standard Rear Engine", "Standard", {
		Price = 0, Power = 13 + index, TopSpeed = familyTopSpeed, Acceleration = familyAccel, Handling = 0, Drift = 1, Braking = 0, Weight = 8, Boost = 0, NeonPrice = 5000,
	})
	local lightweight = ensureRearEngine(family, "MODULE_ENGINE_B_BRUISER_" .. short .. "_LIGHTWEIGHT", cockpitName .. " Lightweight Rear Engine", "Lightweight", {
		Price = math.floor(basePrice + 9000), Power = 11 + index, TopSpeed = familyTopSpeed - 2, Acceleration = familyAccel + 5, Handling = 3, Drift = 3, Braking = 1, Weight = -8, Boost = 0, NeonPrice = 6500,
	})
	local power = ensureRearEngine(family, "MODULE_ENGINE_B_BRUISER_" .. short .. "_POWER", cockpitName .. " Power Rear Engine", "Power", {
		Price = math.floor(basePrice + 14000), Power = 17 + index, TopSpeed = familyTopSpeed + 7, Acceleration = familyAccel + 2, Handling = -2, Drift = 0, Braking = -1, Weight = 16, Boost = 0, NeonPrice = 8000,
	})

	desiredRear[standard:GetAttribute("ModuleId")] = true
	desiredRear[lightweight:GetAttribute("ModuleId")] = true
	desiredRear[power:GetAttribute("ModuleId")] = true

	cockpit:SetAttribute("DefaultFrontEngineModuleId", cockpit:GetAttribute("DefaultEngineModuleId"))
	cockpit:SetAttribute("DefaultRearEngineModuleId", standard:GetAttribute("ModuleId"))
end

for _, item in ipairs(rearRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("ModuleId") and desiredRear[item:GetAttribute("ModuleId")] ~= true then
		item:SetAttribute("RetiredFromCatalog", true)
	end
end

for _, cockpit in ipairs(cockpits) do
	local slots = cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
	if slots then
		local front = slots:FindFirstChild("SLOT_Engine1")
		if front then
			front:SetAttribute("ModuleType", "Engine")
			front:SetAttribute("AllowedModuleFolder", "Engines")
		end
		local rear = slots:FindFirstChild("SLOT_Engine2")
		if rear then
			rear:SetAttribute("ModuleType", "Engine")
			rear:SetAttribute("AllowedModuleFolder", "Engines_B")
		end
	end
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local serverSource = serverScript.Source
if not string.find(serverSource, "NTR_VEHICLE_PHASE_AK_REAR_ENGINE_SERVER_REPAIR", 1, true) then
	serverSource = replaceOnce(serverSource,
[[		return {
			Engine = V56_string(cockpit, "DefaultEngineModuleId", nil),
			Stabilisers = V56_string(cockpit, "DefaultStabilisersModuleId", nil),
			Boost = V56_string(cockpit, "DefaultBoostModuleId", nil),
		}]],
[[		-- NTR_VEHICLE_PHASE_AK_REAR_ENGINE_SERVER_REPAIR
		return {
			Engine = V56_string(cockpit, "DefaultFrontEngineModuleId", V56_string(cockpit, "DefaultEngineModuleId", nil)),
			RearEngine = V56_string(cockpit, "DefaultRearEngineModuleId", V56_string(cockpit, "DefaultEngineModuleId", nil)),
			Stabilisers = V56_string(cockpit, "DefaultStabilisersModuleId", nil),
			Boost = V56_string(cockpit, "DefaultBoostModuleId", nil),
		}]],
		"server default module table")

	serverSource = replaceOnce(serverSource,
[[		if defaults.Engine then
			profile.InstalledModules.Engine1 = profile.InstalledModules.Engine1 or defaults.Engine
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.Engine
		end]],
[[		if defaults.Engine then
			profile.InstalledModules.Engine1 = profile.InstalledModules.Engine1 or defaults.Engine
		end
		if defaults.RearEngine then
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.RearEngine
		end]],
		"server default engine install")

	serverScript.Source = serverSource
	info("Patched server default front/rear engine grants.")
else
	info("Server front/rear engine grant repair already installed.")
end

local clientScript = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local clientSource = clientScript.Source
if not string.find(clientSource, "NTR_VEHICLE_PHASE_AK_REAR_ENGINE_CLIENT_REPAIR", 1, true) then
	clientSource = replaceOnce(clientSource,
[[	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and cockpit.DefaultEngineModuleId, 2)]],
[[	-- NTR_VEHICLE_PHASE_AK_REAR_ENGINE_CLIENT_REPAIR
	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and (cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId), 1)
	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and (cockpit.DefaultRearEngineModuleId or cockpit.DefaultEngineModuleId), 1)]],
		"client dealership front/rear default stats")
	clientScript.Source = clientSource
	info("Patched client dealership stats for separate front/rear engines.")
else
	info("Client front/rear dealership stats repair already installed.")
end

info("Complete. Engines_B now mirrors the Engines family-folder layout. Stop Play and start Play again.")
