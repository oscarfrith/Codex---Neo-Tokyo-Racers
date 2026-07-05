-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 1 Audit
-- Read-only Studio Command Bar audit for the next spawn/swap phase.
-- It does not change scripts, hierarchy, attributes, vehicles, or config.

local PHASE = "NTR Free Roam Vehicle Spawn Phase 1 Audit"

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function child(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function sourceContains(scriptObject, needle)
	if not scriptObject or not scriptObject:IsA("LuaSourceContainer") then
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	return ok and string.find(source, needle, 1, true) ~= nil
end

local function auditGarageServer()
	info("Garage server action audit")
	local garageRoot = child(ServerScriptService, "NeoTokyoRacers", "Services", "Garage")
	local serverScript = garageRoot and garageRoot:FindFirstChild("GarageActionController_Shadow_Disabled")
	if not (serverScript and serverScript:IsA("Script")) then
		warnLine("Missing ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled")
		return
	end

	info("  Server script found. Disabled=" .. tostring(serverScript.Disabled))
	local checks = {
		{ "SelectVehicleInstance action", 'action == "SelectVehicleInstance"' },
		{ "SpawnVehicle action", 'action == "SpawnVehicle"' },
		{ "ExitVehicle action", 'action == "ExitVehicle"' },
		{ "current vehicle selection helper", "V89_selectVehicleInstance" },
		{ "spawn CFrame helper", "V56_spawnCFrame" },
		{ "vehicle builder", "V56_buildVehicle" },
		{ "player vehicle clear/despawn", "V56_clearPlayerVehicle" },
		{ "auto seat helper", "V56_seatPlayer" },
	}
	for _, check in ipairs(checks) do
		info("  " .. check[1] .. ": " .. tostring(sourceContains(serverScript, check[2])))
	end
end

local function auditFreeRoamClient()
	info("Free-roam car menu client audit")
	local uiRoot = child(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient", "Controllers", "UI")
	local nav = uiRoot and uiRoot:FindFirstChild("FreeRoamNavController_Active")
	if not (nav and nav:IsA("LocalScript")) then
		warnLine("Missing StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active")
		return
	end

	info("  FreeRoamNavController_Active found. Disabled=" .. tostring(nav.Disabled))
	local checks = {
		{ "Phase 7 card-frame marker", "NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH" },
		{ "cockpit card renderer", "carPanelRenderCockpitCard" },
		{ "VehicleId card attribute", 'SetAttribute("VehicleId"' },
		{ "CockpitId card attribute", 'SetAttribute("CockpitId"' },
		{ "future click action hook", "CarPanelClickAction" },
		{ "current placeholder click text", "SPAWN / SELECT COMING NEXT" },
	}
	for _, check in ipairs(checks) do
		info("  " .. check[1] .. ": " .. tostring(sourceContains(nav, check[2])))
	end

	local config = child(ReplicatedStorage, "NeoTokyoRacers", "Config", "UI", "FreeRoamNav")
	if config then
		local names = {
			"CarPanelClickAction",
			"CarPanelDesktopColumns",
			"CarPanelMobileColumns",
			"CarPanelWidthDesktop",
			"CarPanelWidthTouch",
		}
		for _, name in ipairs(names) do
			local value = config:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				info("  Config " .. name .. "=" .. tostring(value.Value))
			else
				info("  Config " .. name .. "=<missing>")
			end
		end
	else
		warnLine("  Missing ReplicatedStorage.NeoTokyoRacers.Config.UI.FreeRoamNav")
	end
end

local function maybeRoadSurface(part)
	local lower = string.lower(part.Name)
	if lower == "road" or lower == "road asphalt" then
		return true
	end
	if string.find(lower, "road", 1, true) and not string.find(lower, "marking", 1, true) and not string.find(lower, "light", 1, true) then
		local size = part.Size
		return math.max(size.X, size.Z) >= 20 and math.min(size.X, size.Z) >= 8
	end
	return false
end

local function auditRoads()
	info("Road snap candidate audit")
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	if not world then
		warnLine("  Missing Workspace.NeoTokyoRacersWorld")
		return
	end

	local explicitFolder = world:FindFirstChild("RoadSpawnMarkers", true)
	local tagged = CollectionService:GetTagged("NTR_RoadSpawnPoint")
	info("  Explicit RoadSpawnMarkers folder: " .. tostring(explicitFolder ~= nil) .. (explicitFolder and (" at " .. explicitFolder:GetFullName()) or ""))
	info("  Tagged NTR_RoadSpawnPoint instances: " .. tostring(#tagged))

	local roadsFolders = 0
	local roadSurfaces = {}
	local roadModels = 0
	local roadMarkings = 0
	local city = world:FindFirstChild("City") or Workspace:FindFirstChild("GeneratedCityBlocks")
	if not city then
		warnLine("  Missing city root at Workspace.NeoTokyoRacersWorld.City and Workspace.GeneratedCityBlocks")
	else
		info("  City root used for audit: " .. city:GetFullName())
		for _, inst in ipairs(city:GetDescendants()) do
			local lower = string.lower(inst.Name)
			if inst:IsA("Folder") and lower == "roads" then
				roadsFolders += 1
			elseif inst:IsA("Model") and string.find(lower, "road", 1, true) then
				roadModels += 1
			elseif inst:IsA("BasePart") then
				if string.find(lower, "road marking", 1, true) then
					roadMarkings += 1
				elseif maybeRoadSurface(inst) then
					table.insert(roadSurfaces, inst)
				end
			end
		end
	end

	table.sort(roadSurfaces, function(a, b)
		local aa = math.max(a.Size.X, a.Size.Z) * math.min(a.Size.X, a.Size.Z)
		local bb = math.max(b.Size.X, b.Size.Z) * math.min(b.Size.X, b.Size.Z)
		return aa > bb
	end)

	info("  Roads folders: " .. tostring(roadsFolders))
	info("  Road-named models: " .. tostring(roadModels))
	info("  Road marking parts ignored: " .. tostring(roadMarkings))
	info("  Candidate road surface parts: " .. tostring(#roadSurfaces))
	for index = 1, math.min(12, #roadSurfaces) do
		local part = roadSurfaces[index]
		local size = part.Size
		local pos = part.Position
		info(string.format(
			"  Candidate %02d: %s | size=(%.1f, %.1f, %.1f) pos=(%.1f, %.1f, %.1f)",
			index,
			part:GetFullName(),
			size.X,
			size.Y,
			size.Z,
			pos.X,
			pos.Y,
			pos.Z
		))
	end

	if #tagged > 0 or explicitFolder then
		info("  Road snap recommendation: use explicit road spawn markers first, then fallback to road surfaces.")
	elseif #roadSurfaces > 0 then
		warnLine("  Road snap recommendation: road surfaces exist, but no explicit markers/tags were found. Use a marker-generation/setup phase before relying on nearest-road spawning.")
	else
		warnLine("  Road snap recommendation: no reliable road surfaces or markers found from this audit.")
	end
end

local function auditPlayState()
	info("Play-state speed/profile audit")
	if not RunService:IsRunning() then
		info("  Studio is not running Play mode; skipping live player/speed checks.")
		return
	end

	local player = Players.LocalPlayer or Players:GetPlayers()[1]
	if not player then
		warnLine("  No player available in this Play session.")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local speedMph = 0
	if seat and seat:IsA("VehicleSeat") then
		local vehicle = seat:FindFirstAncestorOfClass("Model")
		local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		if root and root:IsA("BasePart") then
			speedMph = root.AssemblyLinearVelocity.Magnitude * 0.625
		end
	end
	info("  Player=" .. player.Name .. " seated=" .. tostring(seat ~= nil) .. " approxSpeedMph=" .. tostring(math.floor(speedMph + 0.5)))

	local invoke = child(ReplicatedStorage, "NeoTokyoRacers", "Shared", "Remotes", "Garage", "GarageInvoke")
	if invoke and invoke:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return invoke:InvokeServer("GetInitial", {})
		end)
		if ok and typeof(result) == "table" then
			local profile = result.Profile or {}
			local vehicles = typeof(profile.Vehicles) == "table" and profile.Vehicles or {}
			local count = 0
			for _ in pairs(vehicles) do
				count += 1
			end
			info("  GetInitial OK. vehicles=" .. tostring(count) .. " currentVehicleId=" .. tostring(profile.CurrentVehicleId))
		else
			warnLine("  GetInitial failed: " .. tostring(result))
		end
	else
		warnLine("  GarageInvoke missing; cannot audit profile.")
	end
end

info("Starting read-only audit. No changes will be made.")
auditGarageServer()
auditFreeRoamClient()
auditRoads()
auditPlayState()
info("Audit complete. Paste the Output if any recommendation/warning is unclear.")
