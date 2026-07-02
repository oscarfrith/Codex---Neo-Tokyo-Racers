-- NTR Persistence Phase 28 Garage MVP Final Audit
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Audits that the Phase 21-27 garage MVP runtime objects are installed.
--
-- Play mode, CLIENT Command Bar:
--   Runs one final end-to-end owner path: access UI present, enter garage,
--   display exists, customization applies and is reflected in UI, access state
--   reads, return-to-city works, and access mode is cleaned back to Private.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 28 Garage MVP Final Audit]"

local function info(message)
	print(TAG .. " " .. tostring(message))
end

local function waitForPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function parseSummaryCounts(text)
	text = tostring(text or "")
	local surfaces = tonumber(string.match(text, "SURFACES%s+(%d+)")) or 0
	local decor = tonumber(string.match(text, "DECOR%s+(%d+)")) or 0
	return surfaces, decor
end

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local interiorInvoke = remotes:WaitForChild("GarageInteriorInvoke")
	local customizationInvoke = remotes:WaitForChild("GarageInteriorCustomizationInvoke")

	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed before final audit.")
	info("Garage GetInitial OK before final audit.")

	local playerGui = player:WaitForChild("PlayerGui")
	local accessGui = playerGui:WaitForChild("NTR_GarageAccessUI", 8)
	assert(accessGui and accessGui:IsA("ScreenGui"), "Phase 27 access UI missing from PlayerGui.")
	assert(accessGui:FindFirstChild("GarageToggle"), "Phase 27 access toggle missing.")
	assert(accessGui:FindFirstChild("AccessPanel"), "Phase 27 access panel missing.")
	info("Access UI present.")

	local setPublic = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Public" })
	assert(type(setPublic) == "table" and setPublic.Ok == true, "SetAccessMode Public failed: " .. tostring(setPublic and setPublic.Error))

	local visit = interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId })
	assert(type(visit) == "table" and visit.Ok == true, "VisitGarage failed: " .. tostring(visit and visit.Error))
	assert(visit.DisplayOk == true, "Display refresh was not OK during final audit.")
	info("VisitGarage OK. interior=" .. tostring(visit.InteriorId) .. " displayOk=" .. tostring(visit.DisplayOk))

	local customGui = playerGui:WaitForChild("NTR_GarageInteriorCustomizationUI", 8)
	assert(customGui and customGui:IsA("ScreenGui"), "Phase 25 customization UI missing from PlayerGui.")
	local customPanel = customGui:WaitForChild("Panel", 4)
	local visibleDeadline = os.clock() + 8
	while customPanel and customPanel.Visible ~= true and os.clock() < visibleDeadline do
		task.wait(0.15)
	end
	assert(customPanel and customPanel.Visible == true, "Phase 25 customization panel was not visible for final audit.")
	local summary = customPanel:WaitForChild("Summary", 3)
	assert(summary and summary:IsA("TextLabel"), "Phase 25 summary label missing for final audit.")
	info("Customization UI visible.")

	local floor = customizationInvoke:InvokeServer("SetSurfaceStyle", {
		SurfaceId = "Floor",
		Color = Color3.fromRGB(21, 28, 36),
		Material = "Metal",
	})
	assert(type(floor) == "table" and floor.Ok == true and floor.Persisted == true, "Final floor customization failed or did not mark persisted.")

	local walls = customizationInvoke:InvokeServer("SetSurfaceStyle", {
		SurfaceId = "Walls",
		Color = Color3.fromRGB(30, 38, 52),
		Material = "Metal",
	})
	assert(type(walls) == "table" and walls.Ok == true and walls.Persisted == true, "Final wall customization failed or did not mark persisted.")

	local decor = customizationInvoke:InvokeServer("SetDecorationAnchor", {
		AnchorId = "BackWallCenter",
		DecorationId = "NeonSign",
	})
	assert(type(decor) == "table" and decor.Ok == true and decor.Persisted == true, "Final decor customization failed or did not mark persisted.")

	local customizationState = customizationInvoke:InvokeServer("GetCustomization", {})
	assert(type(customizationState) == "table" and customizationState.Ok == true, "GetCustomization failed during final audit.")
	assert((tonumber(customizationState.SurfaceCount) or 0) >= 2, "Expected at least two surfaces in final audit.")
	assert((tonumber(customizationState.DecorationCount) or 0) >= 1, "Expected at least one decoration in final audit.")

	local summaryDeadline = os.clock() + 6
	local uiSurfaces = 0
	local uiDecor = 0
	while os.clock() < summaryDeadline do
		uiSurfaces, uiDecor = parseSummaryCounts(summary.Text)
		if uiSurfaces >= 2 and uiDecor >= 1 then
			break
		end
		task.wait(0.25)
	end
	assert(uiSurfaces >= 2 and uiDecor >= 1, "Customization UI summary did not reflect final audit state. summary=" .. tostring(summary.Text))
	info("Customization persisted and UI reflected state. summary=" .. tostring(summary.Text))

	local state = interiorInvoke:InvokeServer("GetState", {})
	assert(type(state) == "table" and state.Ok == true, "GetState failed during final audit.")
	assert(state.InGarage == true, "Expected InGarage=true during final audit.")
	assert(state.VisitingOwnerUserId == player.UserId, "Expected final audit owner to match local player.")
	assert(state.DisplayExists == true, "Expected display vehicle to exist during final audit.")
	info("Interior state OK. accessMode=" .. tostring(state.AccessMode) .. " displayExists=" .. tostring(state.DisplayExists))

	local returned = interiorInvoke:InvokeServer("ReturnToCity", { Smoke = true, Phase28 = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))

	local setPrivate = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Private" })
	assert(type(setPrivate) == "table" and setPrivate.Ok == true, "SetAccessMode Private cleanup failed: " .. tostring(setPrivate and setPrivate.Error))
	info("Expected: garage MVP stack is healthy. Next manual step: save/rejoin if DataStore is enabled, then refresh the Studio mirror.")
	return
end

local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
local requiredRemotes = {
	"GarageInvoke",
	"GarageInteriorInvoke",
	"GarageInteriorTransition",
	"GarageInteriorCustomizationInvoke",
}
for _, name in ipairs(requiredRemotes) do
	assert(remotes:FindFirstChild(name), "Missing garage remote: " .. name)
end

local garageServices = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage")
local requiredGarageServices = {
	"GarageActionController_Shadow_Disabled",
	"GarageProfileRuntime",
	"GarageDisplayRuntime",
	"GarageInteriorService_Active",
	"GarageInteriorCustomizationService_Active",
}
for _, name in ipairs(requiredGarageServices) do
	assert(garageServices:FindFirstChild(name), "Missing garage service/module: " .. name)
end

local worldControllers = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World")
local requiredClients = {
	"GarageInteriorClient_Active",
	"GarageInteriorCustomizationClient_Active",
	"GarageAccessClient_Active",
}
for _, name in ipairs(requiredClients) do
	assert(worldControllers:FindFirstChild(name), "Missing world client: " .. name)
end

local garageRoot = findPath(Workspace, { "NeoTokyoRacersWorld", "Interiors", "GarageInstances" })
assert(garageRoot, "Missing Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances.")

info("PASS: Phase 21-27 garage MVP objects are present. Restart Play, then run this same script from the CLIENT Command Bar for the final audit.")
