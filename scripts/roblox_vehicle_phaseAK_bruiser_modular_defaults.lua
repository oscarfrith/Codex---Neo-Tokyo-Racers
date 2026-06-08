-- Neo Tokyo Racers - Vehicle Phase AK
-- Bruiser modular defaults, module tiers, dealership stats preview, and customise gate.
--
-- IMPORTANT: this installer uses guarded source text replacement for the active
-- garage server controller and client bootstrap. If either script has been
-- regenerated since the current mirror, run the Studio snapshot export first
-- and review the failing preflight message before changing the patch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function warnf(message)
	warn("[NTR " .. PHASE .. "] " .. message)
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

local function slug(value)
	value = string.lower(tostring(value or ""))
	value = string.gsub(value, "%s+", "_")
	value = string.gsub(value, "[^%w_]", "")
	return value
end

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local category = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories"):WaitForChild("BRUISER")
local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("COCKPITS") or category:FindFirstChild("Cockpits")
assert(cockpitRoot, "Could not find Bruiser cockpit root")
local moduleRoot = ensureFolder(category, "MODULES_InterchangeableWithinCategory")

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

local slotByType = {
	Engine = "Engines",
	Stabilisers = "Stabilisers",
	Boost = "Boost",
	FrontBumper = "FrontBumpers",
	RearBumper = "RearBumpers",
	RearSpoiler = "RearSpoilers",
	SidePods = "SidePods",
}

local function findTemplate(folderName)
	local folder = moduleRoot:FindFirstChild(folderName)
	if not folder then return nil end
	for _, item in ipairs(folder:GetDescendants()) do
		if item:IsA("Model") and item:FindFirstChild("ModuleRoot_DoNotRename", true) then
			return item
		end
	end
end

local templates = {
	Engine = findTemplate("Engines"),
	Stabilisers = findTemplate("Stabilisers") or findTemplate("Stabilizers"),
	Boost = findTemplate("Boost"),
	FrontBumper = findTemplate("FrontBumpers") or findTemplate("FrontBumper"),
	RearBumper = findTemplate("RearBumpers") or findTemplate("RearBumper"),
	RearSpoiler = findTemplate("RearSpoilers") or findTemplate("Spoilers") or findTemplate("RearSpoiler"),
	SidePods = findTemplate("SidePods") or findTemplate("SidePod"),
}

for moduleType, template in pairs(templates) do
	if not template then
		warnf("No template found for " .. moduleType .. "; that tier folder will be skipped.")
	end
end

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
	model:SetAttribute("BalancePhase", "AK")
	model:SetAttribute("BalanceEditable", true)
	model:SetAttribute("BalanceNote", "Rough baseline. Tune these attributes in Studio after play-testing.")
end

local function ensureModule(parent, template, moduleId, displayName, moduleType, moduleFolder, tier, stats)
	local existing
	for _, item in ipairs(moduleRoot:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") == moduleId then
			existing = item
			break
		end
	end
	local model = existing or template:Clone()
	model.Name = moduleId
	model.Parent = parent
	model:SetAttribute("ModuleId", moduleId)
	model:SetAttribute("DisplayName", displayName)
	model:SetAttribute("ModuleName", displayName)
	model:SetAttribute("ModuleType", moduleType)
	model:SetAttribute("ModuleSlot", moduleType)
	model:SetAttribute("ModuleFolder", moduleFolder)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("RetiredFromCatalog", false)
	applyStats(model, stats)
	return model
end

local function twoDigit(index)
	return string.format("%02d", index)
end

local desiredIds = {}
local function remember(model)
	desiredIds[model:GetAttribute("ModuleId")] = true
end

local enginesFolder = ensureFolder(moduleRoot, "Engines")
local stabilisersFolder = ensureFolder(moduleRoot, "Stabilisers")
local boostFolder = ensureFolder(moduleRoot, "Boost")

for index, cockpit in ipairs(cockpits) do
	local cockpitId = tostring(cockpit:GetAttribute("CockpitId"))
	local short = twoDigit(index)
	local cockpitName = cockpit:GetAttribute("DisplayName") or cockpit.Name
	local engineGroup = ensureFolder(enginesFolder, "Bruiser_" .. short)
	local stabiliserGroup = ensureFolder(stabilisersFolder, "Bruiser_" .. short)
	local boostGroup = ensureFolder(boostFolder, "Bruiser_" .. short)

	local basePrice = math.max(0, (cockpit:GetAttribute("Price") or 0) * 0.18)
	local familyTopSpeed = 8 + index
	local familyAccel = 5 + math.floor(index / 2)
	local familyHandling = 3 + math.floor(index / 2)

	if templates.Engine then
		local standard = ensureModule(engineGroup, templates.Engine, "MODULE_ENGINE_BRUISER_" .. short .. "_STANDARD", cockpitName .. " Standard Engine", "Engine", "Engines", "Standard", {
			Price = 0, Power = 14 + index, TopSpeed = familyTopSpeed, Acceleration = familyAccel, Handling = 0, Drift = 0, Braking = 0, Weight = 8, Boost = 0, NeonPrice = 5000,
		})
		local lightweight = ensureModule(engineGroup, templates.Engine, "MODULE_ENGINE_BRUISER_" .. short .. "_LIGHTWEIGHT", cockpitName .. " Lightweight Engine", "Engine", "Engines", "Lightweight", {
			Price = math.floor(basePrice + 9000), Power = 12 + index, TopSpeed = familyTopSpeed - 2, Acceleration = familyAccel + 5, Handling = 3, Drift = 2, Braking = 1, Weight = -8, Boost = 0, NeonPrice = 6500,
		})
		local power = ensureModule(engineGroup, templates.Engine, "MODULE_ENGINE_BRUISER_" .. short .. "_POWER", cockpitName .. " Power Engine", "Engine", "Engines", "Power", {
			Price = math.floor(basePrice + 14000), Power = 18 + index, TopSpeed = familyTopSpeed + 7, Acceleration = familyAccel + 2, Handling = -2, Drift = -1, Braking = -1, Weight = 16, Boost = 0, NeonPrice = 8000,
		})
		remember(standard); remember(lightweight); remember(power)
		cockpit:SetAttribute("DefaultEngineModuleId", standard:GetAttribute("ModuleId"))
	end

	if templates.Stabilisers then
		local standard = ensureModule(stabiliserGroup, templates.Stabilisers, "MODULE_STABILISER_BRUISER_" .. short .. "_STANDARD", cockpitName .. " Standard Stabilisers", "Stabilisers", "Stabilisers", "Standard", {
			Price = 0, Handling = familyHandling + 8, Drift = 6, Braking = 2, Weight = 6, TopSpeed = 0, Acceleration = 0, Boost = 0, NeonPrice = 5000,
		})
		local lightweight = ensureModule(stabiliserGroup, templates.Stabilisers, "MODULE_STABILISER_BRUISER_" .. short .. "_LIGHTWEIGHT", cockpitName .. " Lightweight Stabilisers", "Stabilisers", "Stabilisers", "Lightweight", {
			Price = math.floor(basePrice + 8000), Handling = familyHandling + 10, Drift = 8, Braking = 1, Weight = -6, TopSpeed = -1, Acceleration = 2, Boost = 0, NeonPrice = 6500,
		})
		local power = ensureModule(stabiliserGroup, templates.Stabilisers, "MODULE_STABILISER_BRUISER_" .. short .. "_POWER", cockpitName .. " Power Stabilisers", "Stabilisers", "Stabilisers", "Power", {
			Price = math.floor(basePrice + 12000), Handling = familyHandling + 14, Drift = 12, Braking = 4, Weight = 12, TopSpeed = 1, Acceleration = -1, Boost = 0, NeonPrice = 8000,
		})
		remember(standard); remember(lightweight); remember(power)
		cockpit:SetAttribute("DefaultStabilisersModuleId", standard:GetAttribute("ModuleId"))
	end

	if templates.Boost then
		local standard = ensureModule(boostGroup, templates.Boost, "MODULE_BOOST_BRUISER_" .. short .. "_STANDARD", cockpitName .. " Standard Boost", "Boost", "Boost", "Standard", {
			Price = 0, Boost = 24 + index, BoostDuration = 2.2, BoostRecharge = 9.0, BoostRechargeDelay = 0.5, TopSpeed = 1, Acceleration = 1, Handling = 0, Drift = 0, Braking = 0, Weight = 7, NeonPrice = 5000,
		})
		local lightweight = ensureModule(boostGroup, templates.Boost, "MODULE_BOOST_BRUISER_" .. short .. "_LIGHTWEIGHT", cockpitName .. " Lightweight Boost", "Boost", "Boost", "Lightweight", {
			Price = math.floor(basePrice + 9000), Boost = 20 + index, BoostDuration = 1.9, BoostRecharge = 7.2, BoostRechargeDelay = 0.35, TopSpeed = 0, Acceleration = 2, Handling = 1, Drift = 1, Braking = 0, Weight = -5, NeonPrice = 6500,
		})
		local power = ensureModule(boostGroup, templates.Boost, "MODULE_BOOST_BRUISER_" .. short .. "_POWER", cockpitName .. " Power Boost", "Boost", "Boost", "Power", {
			Price = math.floor(basePrice + 15000), Boost = 34 + index, BoostDuration = 2.7, BoostRecharge = 10.8, BoostRechargeDelay = 0.75, TopSpeed = 3, Acceleration = 0, Handling = -1, Drift = -1, Braking = 0, Weight = 13, NeonPrice = 8000,
		})
		remember(standard); remember(lightweight); remember(power)
		cockpit:SetAttribute("DefaultBoostModuleId", standard:GetAttribute("ModuleId"))
	end
	cockpit:SetAttribute("DefaultModulesPhase", "AK")
	cockpit:SetAttribute("DefaultModulesNote", "Buying/selecting this cockpit grants the standard engine, stabilisers, and boost modules.")
end

local bodyLevels = {
	FrontBumper = { folder = "FrontBumpers", display = "Front Bumper", stat = "Braking" },
	RearBumper = { folder = "RearBumpers", display = "Rear Bumper", stat = "Weight" },
	RearSpoiler = { folder = "RearSpoilers", display = "Rear Spoiler", stat = "Handling" },
	SidePods = { folder = "SidePods", display = "Side Pods", stat = "Drift" },
}

for moduleType, spec in pairs(bodyLevels) do
	local template = templates[moduleType]
	if template then
		local folder = ensureFolder(moduleRoot, spec.folder)
		for level = 1, 3 do
			local moduleId = "MODULE_" .. string.upper(moduleType) .. "_LVL" .. tostring(level)
			local stats = {
				Price = level == 1 and 6500 or (level == 2 and 12000 or 19000),
				TopSpeed = moduleType == "RearSpoiler" and level or 0,
				Acceleration = moduleType == "SidePods" and level or 0,
				Handling = (moduleType == "RearSpoiler" or moduleType == "SidePods") and (level * 2) or 0,
				Drift = (moduleType == "SidePods") and (level * 2) or 0,
				Braking = (moduleType == "FrontBumper" or moduleType == "RearBumper") and (level * 2) or 0,
				Weight = level * 2,
				Boost = 0,
				NeonPrice = 5000 + level * 1500,
			}
			local model = ensureModule(folder, template, moduleId, spec.display .. " Lvl " .. tostring(level), moduleType, spec.folder, "Level " .. tostring(level), stats)
			model:SetAttribute("Level", level)
			remember(model)
		end
	end
end

for _, item in ipairs(moduleRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("ModuleId") and desiredIds[item:GetAttribute("ModuleId")] ~= true then
		item:SetAttribute("RetiredFromCatalog", true)
	end
end

local function setSlotDefaults()
	for _, cockpit in ipairs(cockpits) do
		local slots = cockpit:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
		if slots then
			for _, slot in ipairs(slots:GetChildren()) do
				local slotId = string.gsub(slot.Name, "^SLOT_", "")
				local moduleType
				local moduleFolder = ""
				if slotId == "Engine1" or slotId == "Engine2" then
					moduleType = "Engine"; moduleFolder = "Engines"
				elseif slotId == "Stabilisers" then
					moduleType = "Stabilisers"; moduleFolder = "Stabilisers"
				elseif slotId == "Boost" then
					moduleType = "Boost"; moduleFolder = "Boost"
				elseif slotId == "FrontBumper" then
					moduleType = "FrontBumper"; moduleFolder = "FrontBumpers"
				elseif slotId == "RearBumper" then
					moduleType = "RearBumper"; moduleFolder = "RearBumpers"
				elseif slotId == "RearSpoiler" then
					moduleType = "RearSpoiler"; moduleFolder = "RearSpoilers"
				elseif slotId == "SidePods" then
					moduleType = "SidePods"; moduleFolder = "SidePods"
				end
				if moduleType then
					slot:SetAttribute("SlotId", slotId)
					slot:SetAttribute("ModuleType", moduleType)
					slot:SetAttribute("AllowedModuleFolder", moduleFolder)
				end
			end
		end
	end
end
setSlotDefaults()

local serverScript = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
local clientScript = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

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

local serverSource = serverScript.Source
if not string.find(serverSource, "NTR_VEHICLE_PHASE_AK_SERVER_BEGIN", 1, true) then
	serverSource = replaceOnce(serverSource,
[[	local function V56_findModule(categoryId, moduleId)
		local category = V56_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
		return V56_findByAttribute(root, "ModuleId", moduleId)
	end]],
[[	local function V56_findModule(categoryId, moduleId)
		local category = V56_categoryFolder(categoryId)
		local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
		return V56_findByAttribute(root, "ModuleId", moduleId)
	end

	-- NTR_VEHICLE_PHASE_AK_SERVER_BEGIN
	local function V76_moduleIsCatalogVisible(module)
		return module and module:GetAttribute("RetiredFromCatalog") ~= true
	end

	local function V76_defaultModuleIdsForCockpit(cockpit)
		if not cockpit then return {} end
		return {
			Engine = V56_string(cockpit, "DefaultEngineModuleId", nil),
			Stabilisers = V56_string(cockpit, "DefaultStabilisersModuleId", nil),
			Boost = V56_string(cockpit, "DefaultBoostModuleId", nil),
		}
	end

	local function V76_grantDefaultModulesForCurrentCockpit(profile)
		if not profile then return end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local defaults = V76_defaultModuleIdsForCockpit(cockpit)
		profile.OwnedModules = profile.OwnedModules or {}
		profile.InstalledModules = profile.InstalledModules or {}
		for _, moduleId in pairs(defaults) do
			if moduleId and V56_findModule(profile.CurrentCategory, moduleId) then
				profile.OwnedModules[moduleId] = true
			end
		end
		if defaults.Engine then
			profile.InstalledModules.Engine1 = profile.InstalledModules.Engine1 or defaults.Engine
			profile.InstalledModules.Engine2 = profile.InstalledModules.Engine2 or defaults.Engine
		end
		if defaults.Stabilisers then
			profile.InstalledModules.Stabilisers = profile.InstalledModules.Stabilisers or defaults.Stabilisers
		end
		if defaults.Boost then
			profile.InstalledModules.Boost = profile.InstalledModules.Boost or defaults.Boost
		end
	end

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
	end
	-- NTR_VEHICLE_PHASE_AK_SERVER_END]],
		"server helper insertion")

	serverSource = replaceOnce(serverSource,
[[					if module:IsA("Model") and module:GetAttribute("ModuleId") then]],
[[					if module:IsA("Model") and module:GetAttribute("ModuleId") and V76_moduleIsCatalogVisible(module) then]],
		"server catalog retired-module filter")

	serverSource = replaceOnce(serverSource,
[[			local profile = V56_getProfile(player)
			local ok, message]],
[[			local profile = V56_getProfile(player)
			V76_grantDefaultModulesForCurrentCockpit(profile)
			local ok, message]],
		"server action default grant")

	serverSource = replaceOnce(serverSource,
[[					if ok then profile.CurrentCockpit = cockpitId end]],
[[					if ok then
						profile.CurrentCockpit = cockpitId
						V76_grantDefaultModulesForCurrentCockpit(profile)
					end]],
		"server cockpit purchase default grant")

	serverSource = replaceOnce(serverSource,
[[			elseif action == "SpawnVehicle" then
				local vehicle, err = V56_buildVehicle(player, profile)
				ok, message = vehicle ~= nil, err or "Vehicle spawned."]],
[[			elseif action == "SpawnVehicle" then
				if not V76_coreModulesEquipped(profile) then
					ok, message = false, "Equip at least one engine, stabilisers, and boost before customising or driving."
				else
					local vehicle, err = V56_buildVehicle(player, profile)
					ok, message = vehicle ~= nil, err or "Vehicle spawned."
				end]],
		"server spawn core gate")

	serverScript.Source = serverSource
	info("Patched garage server controller.")
else
	info("Garage server controller already contains Phase AK patch.")
end

local clientSource = clientScript.Source
if not string.find(clientSource, "NTR_VEHICLE_PHASE_AK_CLIENT_BEGIN", 1, true) then
	clientSource = replaceOnce(clientSource,
[[local function setNextText(text)
	UI.Next.Text = string.upper(text or "NEXT")
end]],
[[local function setNextText(text)
	UI.Next.Text = string.upper(text or "NEXT")
end

-- NTR_VEHICLE_PHASE_AK_CLIENT_BEGIN
local function statsCopy(stats)
	local copy = {}
	for key, value in pairs(stats or {}) do
		if typeof(value) == "number" then copy[key] = value end
	end
	return copy
end

local function addModuleStats(total, moduleId, times)
	local module = moduleId and getModule(moduleId)
	if not module then return end
	for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }) do
		total[stat] = (total[stat] or 0) + ((module[stat] or 0) * (times or 1))
	end
end

local function dealershipStatsWithIncludedDefaults(cockpit)
	local stats = statsCopy(cockpit)
	addModuleStats(stats, cockpit and cockpit.DefaultEngineModuleId, 2)
	addModuleStats(stats, cockpit and cockpit.DefaultStabilisersModuleId, 1)
	addModuleStats(stats, cockpit and cockpit.DefaultBoostModuleId, 1)
	return stats
end

local function coreModuleEquipState()
	local installed = (State.Profile and State.Profile.InstalledModules) or {}
	local hasEngine, hasStabilisers, hasBoost = false, false, false
	for _, moduleId in pairs(installed) do
		local module = getModule(moduleId)
		local moduleType = module and module.ModuleType
		if moduleType == "Engine" then hasEngine = true end
		if moduleType == "Stabilisers" or moduleType == "Stabiliser" then hasStabilisers = true end
		if moduleType == "Boost" then hasBoost = true end
	end
	return hasEngine, hasStabilisers, hasBoost
end

local function showCoreModuleRequiredPopup()
	if not UI.Gui then return end
	if UI.RequireModulesPopup and UI.RequireModulesPopup.Parent then
		UI.RequireModulesPopup:Destroy()
	end
	local width = UserInputService.TouchEnabled and 310 or 430
	local height = UserInputService.TouchEnabled and 126 or 132
	local popup = panel(UI.Gui, "RequireCoreModulesPopup", UDim2.fromOffset(width, height), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	popup.ZIndex = 80
	pad(popup, 14)
	UI.RequireModulesPopup = popup
	local title = label(popup, "Modules Required", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 4), UserInputService.TouchEnabled and 13 or 15, Enum.TextXAlignment.Center)
	title.ZIndex = 81
	local body = label(popup, "Equip at least one engine, stabilisers, and boost before customising.", UDim2.new(1, -18, 0, 44), UDim2.fromOffset(9, 38), UserInputService.TouchEnabled and 10 or 12, Enum.TextXAlignment.Center)
	body.ZIndex = 81
	local ok = button(popup, "OK", UDim2.new(1, -90, 0, UserInputService.TouchEnabled and 38 or 34), UDim2.new(0, 45, 1, UserInputService.TouchEnabled and -42 or -38), Theme.CardHot)
	ok.ZIndex = 81
	ok.MouseButton1Click:Connect(function()
		if UI.RequireModulesPopup then
			UI.RequireModulesPopup:Destroy()
			UI.RequireModulesPopup = nil
		end
	end)
	task.delay(3.2, function()
		if UI.RequireModulesPopup == popup then
			popup:Destroy()
			UI.RequireModulesPopup = nil
		end
	end)
end
-- NTR_VEHICLE_PHASE_AK_CLIENT_END]],
		"client helpers insertion")

	clientSource = replaceOnce(clientSource,
[[	if State.Stage == "CockpitShop" then
		return getCockpit(State.SelectedCockpit) or {}
	end]],
[[	if State.Stage == "CockpitShop" then
		return dealershipStatsWithIncludedDefaults(getCockpit(State.SelectedCockpit) or {})
	end]],
		"client cockpit current stats defaults")

	clientSource = replaceOnce(clientSource,
[[	local cockpit = getCockpit(State.SelectedCockpit) or {}
	renderStatsOnly(UI.StatsPanel, cockpit)]],
[[	local cockpit = getCockpit(State.SelectedCockpit) or {}
	renderStatsOnly(UI.StatsPanel, dealershipStatsWithIncludedDefaults(cockpit))]],
		"client dealership panel stats defaults")

	clientSource = replaceOnce(clientSource,
[[		elseif State.Stage == "ModuleShop" then
			clearPreviewModules()
			State.CustomizeTarget = "ALL"
			State.CustomizeMode = "Colour"
			showStage("Customise")
			renderCustomise()]],
[[		elseif State.Stage == "ModuleShop" then
			local hasEngine, hasStabilisers, hasBoost = coreModuleEquipState()
			if not (hasEngine and hasStabilisers and hasBoost) then
				showCoreModuleRequiredPopup()
				UI.Subtitle.Text = "Equip one engine, stabilisers, and boost first."
				return
			end
			clearPreviewModules()
			State.CustomizeTarget = "ALL"
			State.CustomizeMode = "Colour"
			showStage("Customise")
			renderCustomise()]],
		"client customise next gate")

	clientScript.Source = clientSource
	info("Patched active client bootstrap.")
else
	info("Active client bootstrap already contains Phase AK patch.")
end

info("Complete. Desired module IDs: " .. tostring((function()
	local count = 0
	for _ in pairs(desiredIds) do count += 1 end
	return count
end)()))
