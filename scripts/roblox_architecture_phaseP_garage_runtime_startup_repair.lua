-- Neo Tokyo Racers - Architecture Phase P: Garage Runtime Startup Repair
-- Run in Roblox Studio Command Bar, Edit mode, only if the post Phase N
-- garage controller reports a line 23 startup error.
--
-- Status:
--   Superseded by Phase Q when Phase P does not fully clear the line 23 error.
--
-- Purpose:
--   Applies a conservative nil-guard repair to the active garage server
--   controller after runtime world paths were migrated to:
--     Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles
--
-- Safe effects:
--   - Edits only exact source patterns in existing scripts/modules.
--   - Does not create backup folders/scripts.
--   - Does not move, rename, delete, enable, or disable gameplay objects.
--   - Does not touch Workspace.Test + WIP Assets.
--
-- If Play still errors in GarageActionController_Shadow_Disabled after this,
-- run:
--   scripts/roblox_architecture_phaseQ_garage_controller_header_repair.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_architecture_phaseP_garage_runtime_startup_repair"
local GARAGE_CONTROLLER_PATH = "ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"

local function log(message)
	print("[NTR Phase P] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function underTestWip(instance)
	return string.find(safeFullName(instance), "Test %+ WIP Assets") ~= nil
end

local function isSourceObject(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function sourceOf(instance)
	local ok, result = pcall(function()
		return instance.Source
	end)
	if ok and typeof(result) == "string" then
		return result
	end
	return nil
end

local function resolvePath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function replaceAllPlain(text, old, new)
	local count = 0
	local searchFrom = 1

	while true do
		local startIndex, endIndex = string.find(text, old, searchFrom, true)
		if not startIndex then
			break
		end

		text = string.sub(text, 1, startIndex - 1) .. new .. string.sub(text, endIndex + 1)
		count += 1
		searchFrom = startIndex + #new
	end

	return text, count
end

local function patchSource(source)
	local total = 0
	local function replace(old, new)
		local changed
		source, changed = replaceAllPlain(source, old, new)
		total += changed
	end

	for _, variableName in ipairs({ "world", "V56_world", "runtimeWorld", "worldRoot", "driveWorld", "hoverWorld" }) do
		replace(
			"(" .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(\"PlayerVehicles\"))",
			"(" .. variableName .. " and " .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(\"PlayerVehicles\"))"
		)
		replace(
			"(" .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(VEHICLES_NAME))",
			"(" .. variableName .. " and " .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(VEHICLES_NAME))"
		)
		replace(
			"(" .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(VEHICLE_ROOT_NAME))",
			"(" .. variableName .. " and " .. variableName .. ":FindFirstChild(\"Runtime\") and " .. variableName .. ":FindFirstChild(\"Runtime\"):FindFirstChild(VEHICLE_ROOT_NAME))"
		)
	end

	return source, total
end

local function collectSourceObjects()
	local roots = {
		ReplicatedStorage,
		ServerScriptService,
		ServerStorage,
		StarterGui,
		StarterPlayer,
		Workspace,
	}

	local results = {}
	for _, root in ipairs(roots) do
		for _, instance in ipairs(root:GetDescendants()) do
			if isSourceObject(instance) and not underTestWip(instance) then
				table.insert(results, instance)
			end
		end
	end
	return results
end

local controller = resolvePath(GARAGE_CONTROLLER_PATH)
if not controller or not controller:IsA("Script") then
	error(GARAGE_CONTROLLER_PATH .. " was not found as a Script. No changes applied.")
end

local patched = {}
local replacementCount = 0
for _, instance in ipairs(collectSourceObjects()) do
	local source = sourceOf(instance)
	if source then
		local newSource, changes = patchSource(source)
		if changes > 0 and newSource ~= source then
			instance.Source = newSource
			instance:SetAttribute("PhasePSourcePatchedBy", SCRIPT_ID)
			instance:SetAttribute("PhasePSourcePatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
			table.insert(patched, safeFullName(instance) .. " -- replacements: " .. tostring(changes))
			replacementCount += changes
		end
	end
end

table.sort(patched)

local output = {
	"# Neo Tokyo Racers Phase P Garage Runtime Startup Repair",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Source objects patched: " .. tostring(#patched),
	"- Text replacements applied: " .. tostring(replacementCount),
	"",
	"## Patched Sources",
	"",
}

if #patched == 0 then
	table.insert(output, "- None.")
else
	for _, item in ipairs(patched) do
		table.insert(output, "- " .. item)
	end
end

log("Garage runtime startup repair complete.")
log("Source patched: " .. tostring(#patched) .. "; replacements: " .. tostring(replacementCount))
print(table.concat(output, "\n"))
