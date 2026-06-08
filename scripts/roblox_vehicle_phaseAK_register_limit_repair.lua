-- Neo Tokyo Racers - Vehicle Phase AK register-limit repair
--
-- Run this in Roblox Studio Command Bar after Phase AK if the active client
-- bootstrap errors with:
-- "Out of local registers when trying to allocate V75OriginalStopDriving"
--
-- This patches only the Phase AK client helper block and its call sites. It
-- moves helper functions onto one global phase table so the already large
-- bootstrap uses fewer top-level local registers.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK Register Repair"

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

local clientScript = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local source = clientScript.Source

if string.find(source, "NTR_VEHICLE_PHASE_AK_CLIENT_REGISTER_REPAIR", 1, true) then
	info("Client bootstrap already contains the register-limit repair.")
	return
end

local oldBlock = [[-- NTR_VEHICLE_PHASE_AK_CLIENT_BEGIN
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
-- NTR_VEHICLE_PHASE_AK_CLIENT_END]]

local newBlock = [[-- NTR_VEHICLE_PHASE_AK_CLIENT_BEGIN
-- NTR_VEHICLE_PHASE_AK_CLIENT_REGISTER_REPAIR
NTRVehiclePhaseAK = NTRVehiclePhaseAK or {}

function NTRVehiclePhaseAK.statsCopy(stats)
	local copy = {}
	for key, value in pairs(stats or {}) do
		if typeof(value) == "number" then copy[key] = value end
	end
	return copy
end

function NTRVehiclePhaseAK.addModuleStats(total, moduleId, times)
	local module = moduleId and getModule(moduleId)
	if not module then return end
	for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }) do
		total[stat] = (total[stat] or 0) + ((module[stat] or 0) * (times or 1))
	end
end

function NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit)
	local stats = NTRVehiclePhaseAK.statsCopy(cockpit)
	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and cockpit.DefaultEngineModuleId, 2)
	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and cockpit.DefaultStabilisersModuleId, 1)
	NTRVehiclePhaseAK.addModuleStats(stats, cockpit and cockpit.DefaultBoostModuleId, 1)
	return stats
end

function NTRVehiclePhaseAK.coreModuleEquipState()
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

function NTRVehiclePhaseAK.showCoreModuleRequiredPopup()
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
-- NTR_VEHICLE_PHASE_AK_CLIENT_END]]

source = replaceOnce(source, oldBlock, newBlock, "Phase AK client helper block")
source = replaceOnce(source, "return dealershipStatsWithIncludedDefaults(getCockpit(State.SelectedCockpit) or {})", "return NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(getCockpit(State.SelectedCockpit) or {})", "currentStats dealership default call")
source = replaceOnce(source, "renderStatsOnly(UI.StatsPanel, dealershipStatsWithIncludedDefaults(cockpit))", "renderStatsOnly(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))", "dealership panel default call")
source = replaceOnce(source, "local hasEngine, hasStabilisers, hasBoost = coreModuleEquipState()", "local hasEngine, hasStabilisers, hasBoost = NTRVehiclePhaseAK.coreModuleEquipState()", "core module gate call")
source = replaceOnce(source, "				showCoreModuleRequiredPopup()", "				NTRVehiclePhaseAK.showCoreModuleRequiredPopup()", "core module popup call")

clientScript.Source = source
info("Patched the active client bootstrap to reduce top-level local register use. Stop Play and run Play again.")
