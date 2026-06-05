-- Neo Tokyo Racers - Dealership Intro Phase 6: Vehicle Exit Spawn Marker
-- Run in Roblox Studio Command Bar, Edit mode, after Phase 5.
--
-- Purpose:
--   Creates an editable dealership vehicle exit spawn marker and patches the
--   active garage server controller so final drivable vehicles spawn from it.
--
-- Marker:
--   Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint
--
-- Fallbacks:
--   1. Dealership.Spawn.VehicleExitSpawnPoint
--   2. Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint
--   3. Old V56 coordinate fallback
--
-- Safe design:
--   - Safe to rerun.
--   - Reuses existing marker parts and preserves their position.
--   - Patches only:
--       ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
--   - Does not touch preview, client UI, driving, VFX, LOD, lighting, traffic,
--     mobile controls, or purchase/profile/cash validation.
--   - Does not create backup folders.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_dealership_intro_phase6_vehicle_exit_spawn_marker"
local GARAGE_CONTROLLER_PATH = "ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"

local OLD_SPAWN_CONST = [==[	local V56_SPAWN_POS = Vector3.new(V56_kit:GetAttribute("SpawnX") or 860, V56_kit:GetAttribute("SpawnY") or 105, V56_kit:GetAttribute("SpawnZ") or -1713)]==]

local NEW_SPAWN_HELPER = [==[	local V56_FALLBACK_SPAWN_POS = Vector3.new(V56_kit:GetAttribute("SpawnX") or 860, V56_kit:GetAttribute("SpawnY") or 105, V56_kit:GetAttribute("SpawnZ") or -1713)

	local function V56_spawnCFrame()
		local dealership = V56_world:FindFirstChild("Dealership")
		local dealershipSpawn = dealership and dealership:FindFirstChild("Spawn")
		local exitSpawn = dealershipSpawn and dealershipSpawn:FindFirstChild("VehicleExitSpawnPoint")
		if exitSpawn and exitSpawn:IsA("BasePart") then
			return exitSpawn.CFrame
		end

		local spawnPoints = V56_world:FindFirstChild("SpawnPoints")
		local fallbackSpawn = spawnPoints and spawnPoints:FindFirstChild("VehicleSpawnPoint")
		if fallbackSpawn and fallbackSpawn:IsA("BasePart") then
			return fallbackSpawn.CFrame
		end

		return CFrame.lookAt(V56_FALLBACK_SPAWN_POS, V56_FALLBACK_SPAWN_POS + Vector3.new(0, 0, 1))
	end]==]

local OLD_PIVOT = [==[		vehicle:PivotTo(CFrame.lookAt(V56_SPAWN_POS, V56_SPAWN_POS + Vector3.new(0, 0, 1)))]==]
local NEW_PIVOT = [==[		vehicle:PivotTo(V56_spawnCFrame())]==]

local SERVICES = {
	ServerScriptService = ServerScriptService,
}

local created = {}
local reused = {}
local changed = {}
local skipped = {}

local function log(message)
	print("[NTR Dealership Intro Phase 6] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(("Existing %s is %s, expected Folder. No changes applied."):format(safeFullName(existing), existing.ClassName))
		end
		table.insert(reused, safeFullName(existing) .. " -> Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	table.insert(created, safeFullName(folder) .. " -> Folder")
	return folder
end

local function defaultSpawnCFrame(world)
	local spawnPoints = world:FindFirstChild("SpawnPoints")
	local vehicleSpawn = spawnPoints and spawnPoints:FindFirstChild("VehicleSpawnPoint")
	if vehicleSpawn and vehicleSpawn:IsA("BasePart") then
		return vehicleSpawn.CFrame * CFrame.new(0, 0, -14), "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint"
	end

	return CFrame.lookAt(Vector3.new(860, 105, -1713), Vector3.new(860, 105, -1712)), "old V56 coordinate fallback"
end

local function ensureExitSpawnMarker()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	if not world or not world:IsA("Folder") then
		error("Workspace.NeoTokyoRacersWorld was not found. Run earlier world migration phases before Phase 6.")
	end

	local dealership = ensureFolder(world, "Dealership")
	local spawnFolder = ensureFolder(dealership, "Spawn")
	local existing = spawnFolder:FindFirstChild("VehicleExitSpawnPoint")
	local marker

	if existing then
		if not existing:IsA("BasePart") then
			error(("Existing %s is %s, expected BasePart. No changes applied."):format(safeFullName(existing), existing.ClassName))
		end
		marker = existing
		table.insert(reused, safeFullName(marker) .. " -> " .. marker.ClassName)
	else
		local baseCFrame, source = defaultSpawnCFrame(world)
		marker = Instance.new("Part")
		marker.Name = "VehicleExitSpawnPoint"
		marker.Size = Vector3.new(10, 1, 10)
		marker.CFrame = baseCFrame
		marker.Parent = spawnFolder
		marker:SetAttribute("CreatedFromBase", source)
		marker:SetAttribute("NeedsManualPositionReview", true)
		table.insert(created, safeFullName(marker) .. " -> Part at " .. source)
	end

	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = true
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 160, 80)
	marker.Transparency = 0.35
	marker.TopSurface = Enum.SurfaceType.Smooth
	marker.BottomSurface = Enum.SurfaceType.Smooth

	if marker:GetAttribute("CreatedBy") == nil then marker:SetAttribute("CreatedBy", SCRIPT_ID) end
	if marker:GetAttribute("MarkerType") == nil then marker:SetAttribute("MarkerType", "VehicleExitSpawn") end
	if marker:GetAttribute("Purpose") == nil then marker:SetAttribute("Purpose", "Final drivable vehicle spawn after dealership customisation.") end

	return marker
end

local function resolvePath(path)
	local firstToken = string.match(path, "^[^%.]+")
	local current = SERVICES[firstToken]
	if not current then
		return nil
	end

	local skipFirst = true
	for token in string.gmatch(path, "[^%.]+") do
		if skipFirst then
			skipFirst = false
		else
			current = current:FindFirstChild(token)
			if not current then
				return nil
			end
		end
	end
	return current
end

local function sourceOf(instance)
	local ok, source = pcall(function()
		return instance.Source
	end)
	if ok and typeof(source) == "string" then
		return source
	end
	return nil
end

local function countPlain(text, pattern)
	local count = 0
	local startAt = 1
	while true do
		local startIndex, endIndex = string.find(text, pattern, startAt, true)
		if not startIndex then
			break
		end
		count += 1
		startAt = endIndex + 1
	end
	return count
end

local function replaceOncePlain(text, old, new)
	local startIndex, endIndex = string.find(text, old, 1, true)
	if not startIndex then
		return text, 0
	end
	return string.sub(text, 1, startIndex - 1) .. new .. string.sub(text, endIndex + 1), 1
end

local controller = resolvePath(GARAGE_CONTROLLER_PATH)
if not controller or not controller:IsA("Script") then
	error("Active garage controller was not found as a Script at " .. GARAGE_CONTROLLER_PATH .. ". No changes applied.")
end

local source = sourceOf(controller)
if not source then
	error("Could not read Source for " .. safeFullName(controller) .. ". No changes applied.")
end

local sourceAlreadyPatched = string.find(source, "local function V56_spawnCFrame()", 1, true) ~= nil
if not sourceAlreadyPatched then
	if countPlain(source, OLD_SPAWN_CONST) ~= 1 then
		error("Phase 6 preflight failed: expected exactly 1 V56_SPAWN_POS constant. No changes applied. Paste this output back into Codex.")
	end
	if countPlain(source, OLD_PIVOT) ~= 1 then
		error("Phase 6 preflight failed: expected exactly 1 final vehicle PivotTo spawn line. No changes applied. Paste this output back into Codex.")
	end
end

local marker = ensureExitSpawnMarker()

if sourceAlreadyPatched then
	table.insert(skipped, safeFullName(controller) .. " already contains V56_spawnCFrame")
else

	local patched, count = replaceOncePlain(source, OLD_SPAWN_CONST, NEW_SPAWN_HELPER)
	if count ~= 1 then error("Unexpected patch failure replacing V56_SPAWN_POS. No source changes applied.") end
	source = patched
	table.insert(changed, "Replaced V56_SPAWN_POS with V56_spawnCFrame marker resolver")

	patched, count = replaceOncePlain(source, OLD_PIVOT, NEW_PIVOT)
	if count ~= 1 then error("Unexpected patch failure replacing final vehicle PivotTo spawn line. No source changes applied.") end
	source = patched
	table.insert(changed, "Final drivable vehicle spawn now uses V56_spawnCFrame()")

	controller.Source = source
	controller:SetAttribute("DealershipIntroPhase6PatchedBy", SCRIPT_ID)
	controller:SetAttribute("DealershipIntroPhase6PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 6 Vehicle Exit Spawn Marker")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Marker: " .. safeFullName(marker))
line("- Marker CFrame: " .. tostring(marker.CFrame))
line("- Server controller: " .. safeFullName(controller))
line("- Changes applied: " .. tostring(#changed))
line("- Skipped: " .. tostring(#skipped))
line("- Purchase/profile/cash logic touched: false")
line("- Client preview/UI/driving/VFX/LOD/lighting/mobile touched: false")
line("")

line("## Changes")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do line("- " .. item) end
end
line("")

line("## Skipped")
line("")
if #skipped == 0 then
	line("- None.")
else
	for _, item in ipairs(skipped) do line("- " .. item) end
end
line("")

line("## Next Steps")
line("")
line("1. Move `Workspace.NeoTokyoRacersWorld.Dealership.Spawn.VehicleExitSpawnPoint` to the desired exit location.")
line("2. Rotate the part so its LookVector points the direction the final vehicle should face.")
line("3. Play test: complete customisation and press Start Driving.")
line("4. The final drivable vehicle should spawn at the marker.")
line("5. If the marker is missing, the server falls back to `Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint`.")

log("Phase 6 complete. Marker: " .. safeFullName(marker) .. "; changes: " .. tostring(#changed) .. "; skipped: " .. tostring(#skipped))
print(table.concat(report, "\n"))
