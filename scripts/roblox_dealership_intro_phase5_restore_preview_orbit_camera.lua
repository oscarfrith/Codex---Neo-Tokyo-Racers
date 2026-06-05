-- Neo Tokyo Racers - Dealership Intro Phase 5: Restore Preview Orbit Camera
-- Run in Roblox Studio Command Bar, Edit mode, after Phase 4.
--
-- Purpose:
--   Fixes Phase 4's fixed garage preview camera. The dealership camera marker
--   should initialize the orbit camera view once, then the existing garage
--   camera controls should behave as before:
--     - player can rotate around the vehicle
--     - module selection can rotate to the relevant vehicle area
--     - orbit focus stays around the preview vehicle centre
--
-- Safe design:
--   - Patches only:
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
--   - Does not touch server purchase/profile/cash validation.
--   - Does not touch final drivable vehicle spawn.
--   - Does not touch driving, VFX, LOD, lighting, traffic, or mobile controls.
--   - Does not create backup folders.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_intro_phase5_restore_preview_orbit_camera"
local BOOTSTRAP_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"

local OLD_APPLY_CAMERA = [==[local function NTR_phase4ApplyGaragePreviewCamera()
	if not State or State.NoPreviewYet == true then
		return false
	end

	local intro = NTR_phase4Intro()
	local cameraFolder = intro and intro:FindFirstChild("Camera")
	local cameraPoint = cameraFolder and cameraFolder:FindFirstChild("GaragePreviewCameraPoint")
	if not cameraPoint or not cameraPoint:IsA("BasePart") then
		return false
	end

	if not camera then
		camera = Workspace.CurrentCamera
	end
	if not camera then
		return false
	end

	local focus = State.TargetFocus or NTR_phase4PreviewPosition()
	State.CameraFocus = focus
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPoint.Position, focus)
	return true
end]==]

local NEW_APPLY_CAMERA = [==[local function NTR_phase4ApplyGaragePreviewCamera()
	if not State or State.NoPreviewYet == true or State.Phase5PreviewOrbitInitialized == true then
		return false
	end

	local focus = NTR_phase4PreviewPosition()
	local intro = NTR_phase4Intro()
	local cameraFolder = intro and intro:FindFirstChild("Camera")
	local cameraPoint = cameraFolder and cameraFolder:FindFirstChild("GaragePreviewCameraPoint")

	State.TargetFocus = focus
	State.CameraFocus = focus

	if cameraPoint and cameraPoint:IsA("BasePart") then
		local offset = cameraPoint.Position - focus
		local distance = math.max(offset.Magnitude, 8)
		State.TargetDistance = distance
		State.CameraDistance = distance
		State.TargetYaw = math.atan2(offset.X, offset.Z)
		State.CameraYaw = State.TargetYaw
		State.TargetPitch = math.clamp(math.asin(math.clamp(-offset.Y / distance, -1, 1)), math.rad(-45), math.rad(10))
		State.CameraPitch = State.TargetPitch
	end

	State.Phase5PreviewOrbitInitialized = true
	return false
end]==]

local OLD_UPDATE_CAMERA_GATE = [==[	if NTR_phase4ApplyGaragePreviewCamera() then return end
	camera.CameraType = Enum.CameraType.Scriptable]==]

local NEW_UPDATE_CAMERA_GATE = [==[	NTR_phase4ApplyGaragePreviewCamera()
	camera.CameraType = Enum.CameraType.Scriptable]==]

local SERVICES = {
	StarterPlayer = StarterPlayer,
}

local function log(message)
	print("[NTR Dealership Intro Phase 5] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
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

local bootstrap = resolvePath(BOOTSTRAP_PATH)
if not bootstrap or not bootstrap:IsA("LocalScript") then
	error("Active bootstrap was not found as a LocalScript at " .. BOOTSTRAP_PATH .. ". No changes applied.")
end

local source = sourceOf(bootstrap)
if not source then
	error("Could not read Source for " .. safeFullName(bootstrap) .. ". No changes applied.")
end

local changed = {}
local skipped = {}

if string.find(source, "Phase5PreviewOrbitInitialized", 1, true) then
	table.insert(skipped, safeFullName(bootstrap) .. " already contains Phase 5 orbit camera patch")
else
	if countPlain(source, OLD_APPLY_CAMERA) ~= 1 then
		error("Phase 5 preflight failed: expected exactly 1 Phase 4 fixed-camera helper. No changes applied. Paste this output back into Codex.")
	end
	if countPlain(source, OLD_UPDATE_CAMERA_GATE) ~= 1 then
		error("Phase 5 preflight failed: expected exactly 1 Phase 4 camera update gate. No changes applied. Paste this output back into Codex.")
	end

	local patched, count = replaceOncePlain(source, OLD_APPLY_CAMERA, NEW_APPLY_CAMERA)
	if count ~= 1 then
		error("Unexpected patch failure replacing fixed-camera helper. No changes applied.")
	end
	source = patched
	table.insert(changed, "Replaced fixed marker camera helper with one-time orbit initializer")

	patched, count = replaceOncePlain(source, OLD_UPDATE_CAMERA_GATE, NEW_UPDATE_CAMERA_GATE)
	if count ~= 1 then
		error("Unexpected patch failure replacing camera update gate. No changes applied.")
	end
	source = patched
	table.insert(changed, "Restored normal updateCamera orbit path after marker initialization")

	bootstrap.Source = source
	bootstrap:SetAttribute("DealershipIntroPhase5PatchedBy", SCRIPT_ID)
	bootstrap:SetAttribute("DealershipIntroPhase5PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 5 Restore Preview Orbit Camera")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Target: " .. BOOTSTRAP_PATH)
line("- Changes applied: " .. tostring(#changed))
line("- Skipped: " .. tostring(#skipped))
line("- Camera behavior: marker initializes orbit once; existing rotate/module-focus camera behavior continues")
line("- Server purchase/profile/cash logic touched: false")
line("- Final drivable vehicle spawn touched: false")
line("")

line("## Changes")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do
		line("- " .. item)
	end
end
line("")

line("## Skipped")
line("")
if #skipped == 0 then
	line("- None.")
else
	for _, item in ipairs(skipped) do
		line("- " .. item)
	end
end
line("")

line("## Play Test")
line("")
line("1. Start a fresh Play Solo session.")
line("2. Open garage from the desk and buy/select a cockpit.")
line("3. Preview should appear at VehiclePreviewPoint.")
line("4. Camera should start from GaragePreviewCameraPoint, then allow player rotation around the vehicle centre.")
line("5. Select module slots/options and confirm the camera can rotate to the relevant vehicle area as before.")
line("6. Continue final drivable vehicle spawn test.")

log("Phase 5 complete. Changes applied: " .. tostring(#changed) .. "; skipped: " .. tostring(#skipped))
print(table.concat(report, "\n"))
