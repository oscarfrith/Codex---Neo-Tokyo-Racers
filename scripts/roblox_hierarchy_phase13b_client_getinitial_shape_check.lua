-- Neo Tokyo Racers - Phase 13B Client GetInitial Shape Check
-- Run in Roblox Studio Command Bar, Play mode, Client context.
--
-- Purpose:
--   Calls only the non-mutating GarageInvoke:GetInitial action from the client
--   to verify that the live server response shape still matches expectations.
--
-- Safe effects:
--   - Calls GarageInvoke:InvokeServer("GetInitial", {}).
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Call buy, colour, upgrade, spawn, exit, or re-enter actions.
--   - Change cash, vehicle ownership, UI, driving, VFX, mobile controls, LOD,
--     lighting, traffic, assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SCRIPT_ID = "roblox_hierarchy_phase13b_client_getinitial_shape_check"

local function log(message)
	print("[NTR Phase13B Client Shape] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function responseHasInitialShape(response)
	if typeof(response) ~= "table" then return false, "response is not a table" end
	if response.Success ~= true then return false, "response.Success is not true" end
	if typeof(response.Catalog) ~= "table" then return false, "response.Catalog is missing/not a table" end
	if typeof(response.Profile) ~= "table" then return false, "response.Profile is missing/not a table" end
	if typeof(response.Profile.Cash) ~= "number" then return false, "response.Profile.Cash is missing/not a number" end
	if typeof(response.Profile.TotalStats) ~= "table" then return false, "response.Profile.TotalStats is missing/not a table" end
	return true, "ok"
end

local kit = ReplicatedStorage:WaitForChild("HOVER_RACING_V2_KIT")
local remotes = kit:WaitForChild("REMOTES_DoNotRename")
local garageInvoke = remotes:WaitForChild("GarageInvoke")
if not garageInvoke:IsA("RemoteFunction") then
	error("GarageInvoke is not a RemoteFunction. No changes applied.")
end

local ok, response = pcall(function()
	return garageInvoke:InvokeServer("GetInitial", {})
end)

local shapeOk = false
local detail = ""
if ok then
	shapeOk, detail = responseHasInitialShape(response)
else
	detail = tostring(response)
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 13B Client GetInitial Shape Check")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Client-side non-mutating GetInitial response-shape check.")
line("")
line("## Summary")
line("")
line("- InvokeServer call succeeded: " .. tostring(ok))
line("- Response shape passed: " .. tostring(shapeOk))
line("- Detail: " .. tostring(detail))
if ok and typeof(response) == "table" then
	line("- Success field: " .. tostring(response.Success))
	line("- Cash field type: " .. typeof(response.Profile and response.Profile.Cash))
	line("- Catalog field type: " .. typeof(response.Catalog))
	line("- TotalStats field type: " .. typeof(response.Profile and response.Profile.TotalStats))
end
line("")
line("## Result")
line("")
if ok and shapeOk then
	line("Status: GetInitial response shape passed. This is safe to use as the live response parity baseline.")
else
	line("Status: Stop before server extraction. Resolve GetInitial response-shape issue first.")
end

local reportValue = reportsFolder:FindFirstChild("Phase13B_ClientGetInitialShapeReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase13B_ClientGetInitialShapeReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase13B_ClientGetInitialShapeReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("InvokeSucceeded", ok)
reportValue:SetAttribute("ShapePassed", shapeOk)

log("Report saved to " .. reportValue:GetFullName())
log("Invoke succeeded: " .. tostring(ok) .. "; shape passed: " .. tostring(shapeOk))
print(reportValue.Value)
