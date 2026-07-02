-- NTR Persistence Phase 26 Garage Customization Validation
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Preflights the Phase 24/25 runtime objects. It does not install new
--   gameplay code.
--
-- Play mode, CLIENT Command Bar:
--   Enters the owner's garage, verifies the Phase 25 panel is visible, applies
--   surface/decor choices through the Phase 24 backend, waits for the panel
--   summary to update, and returns to the city.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Persistence Phase 26 Garage Customization Validation]"

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
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed before Phase 26 validation.")
	info("Garage GetInitial OK before customization validation.")

	local setPublic = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Public" })
	assert(type(setPublic) == "table" and setPublic.Ok == true, "SetAccessMode Public failed: " .. tostring(setPublic and setPublic.Error))

	local visit = interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId })
	assert(type(visit) == "table" and visit.Ok == true, "VisitGarage failed: " .. tostring(visit and visit.Error))
	info("VisitGarage OK. interior=" .. tostring(visit.InteriorId) .. " displayOk=" .. tostring(visit.DisplayOk))

	local gui = player:WaitForChild("PlayerGui"):WaitForChild("NTR_GarageInteriorCustomizationUI", 8)
	assert(gui and gui:IsA("ScreenGui"), "Phase 25 UI ScreenGui did not appear.")
	local panel = gui:WaitForChild("Panel", 4)
	local visibleDeadline = os.clock() + 8
	while panel and panel.Visible ~= true and os.clock() < visibleDeadline do
		task.wait(0.15)
	end
	assert(panel and panel.Visible == true, "Phase 25 panel was not visible for owner validation.")
	local summary = panel:WaitForChild("Summary", 3)
	assert(summary and summary:IsA("TextLabel"), "Phase 25 panel summary label was missing.")
	info("UI panel visible before applying validation presets.")

	local floor = customizationInvoke:InvokeServer("SetSurfaceStyle", {
		SurfaceId = "Floor",
		Color = Color3.fromRGB(20, 44, 62),
		Material = "Metal",
	})
	assert(type(floor) == "table" and floor.Ok == true, "SetSurfaceStyle Floor failed: " .. tostring(floor and floor.Error))

	local walls = customizationInvoke:InvokeServer("SetSurfaceStyle", {
		SurfaceId = "Walls",
		Color = Color3.fromRGB(44, 48, 54),
		Material = "Concrete",
	})
	assert(type(walls) == "table" and walls.Ok == true, "SetSurfaceStyle Walls failed: " .. tostring(walls and walls.Error))

	local decor = customizationInvoke:InvokeServer("SetDecorationAnchor", {
		AnchorId = "LeftWallMid",
		DecorationId = "ToolRack",
	})
	assert(type(decor) == "table" and decor.Ok == true, "SetDecorationAnchor ToolRack failed: " .. tostring(decor and decor.Error))
	info("Applied validation presets. floor=" .. tostring(floor.Persisted) .. " walls=" .. tostring(walls.Persisted) .. " decor=" .. tostring(decor.Persisted))

	local state = customizationInvoke:InvokeServer("GetCustomization", {})
	assert(type(state) == "table" and state.Ok == true, "GetCustomization failed: " .. tostring(state and state.Error))
	assert((tonumber(state.SurfaceCount) or 0) >= 2, "Expected backend to report at least two surfaces after validation.")
	assert((tonumber(state.DecorationCount) or 0) >= 1, "Expected backend to report at least one decoration after validation.")

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
	assert(uiSurfaces >= 2 and uiDecor >= 1, "Expected Phase 25 UI summary to show at least two surfaces and one decor. summary=" .. tostring(summary.Text))
	info("UI summary reflected backend state. summary=" .. tostring(summary.Text) .. " persisted=" .. tostring(state.Persisted))

	local returned = interiorInvoke:InvokeServer("ReturnToCity", { Smoke = true, Phase26 = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))

	local setPrivate = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Private" })
	assert(type(setPrivate) == "table" and setPrivate.Ok == true, "SetAccessMode Private cleanup failed: " .. tostring(setPrivate and setPrivate.Error))
	info("Expected: Phase 24 backend and Phase 25 UI summary stay in sync after applying owner customization presets.")
	return
end

local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
assert(remotes:FindFirstChild("GarageInteriorInvoke"), "Missing GarageInteriorInvoke. Run Phase 21/23 first.")
assert(remotes:FindFirstChild("GarageInteriorCustomizationInvoke"), "Missing GarageInteriorCustomizationInvoke. Run Phase 24 first.")

local garageServices = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage")
assert(garageServices:FindFirstChild("GarageInteriorService_Active"), "Missing GarageInteriorService_Active. Run Phase 23 canonical repair first.")
assert(garageServices:FindFirstChild("GarageInteriorCustomizationService_Active"), "Missing GarageInteriorCustomizationService_Active. Run Phase 24 first.")

local worldControllers = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World")
local client = worldControllers:FindFirstChild("GarageInteriorCustomizationClient_Active")
assert(client and client:IsA("LocalScript"), "Missing GarageInteriorCustomizationClient_Active. Run Phase 25 first.")

client:SetAttribute("PersistencePhase26GarageCustomizationValidationReady", true)
info("PASS: Phase 24/25 runtime objects are present. Restart Play, then run this same script from the CLIENT Command Bar for validation.")
