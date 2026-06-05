-- Neo Tokyo Racers - Dealership Intro Phase 4: Preview After Purchase
-- Run in Roblox Studio Command Bar, Edit mode, after Phases 1-3.
--
-- Purpose:
--   Patches the active client bootstrap so the garage UI can open at the
--   dealership desk without immediately creating a preview vehicle. The local
--   preview appears only after BuyCockpit succeeds.
--
-- Important:
--   This is a guarded but fragile source-text patch. It expects the current
--   active bootstrap to still contain the known preview/camera/purchase source
--   shapes. If those shapes changed, the script aborts before patching and
--   prints the missing shape.
--
-- Safe design:
--   - Patches only:
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled
--   - Does not touch server purchase/profile/cash validation.
--   - Does not server-spawn preview vehicles.
--   - Does not touch driving, VFX, LOD, lighting, traffic, or mobile controls.
--   - Does not create backup folders.

local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_dealership_intro_phase4_preview_after_purchase"
local BOOTSTRAP_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"

local PHASE4_HELPERS = [==[
-- NTR_DEALERSHIP_INTRO_PHASE4_PREVIEW_AFTER_PURCHASE_BEGIN
local buildPreview
local NTR_PHASE4_CLIENT_ROOT_NAME = "_NTR_ClientOnly"
local NTR_PHASE4_PREVIEW_ROOT_NAME = "VehiclePreview"

local function NTR_phase4ClientRoot()
	local root = Workspace:FindFirstChild(NTR_PHASE4_CLIENT_ROOT_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = NTR_PHASE4_CLIENT_ROOT_NAME
		root.Parent = Workspace
	end
	return root
end

local function NTR_phase4PreviewRoot()
	local clientRoot = NTR_phase4ClientRoot()
	local legacy = Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
	if legacy then
		legacy:Destroy()
	end

	local existing = clientRoot:FindFirstChild(NTR_PHASE4_PREVIEW_ROOT_NAME)
	if existing and not existing:IsA("Folder") then
		existing:Destroy()
		existing = nil
	end

	if not existing then
		existing = Instance.new("Folder")
		existing.Name = NTR_PHASE4_PREVIEW_ROOT_NAME
		existing.Parent = clientRoot
	end

	Preview.Root = existing
	return existing
end

local function NTR_phase4ClearPreview()
	local clientRoot = Workspace:FindFirstChild(NTR_PHASE4_CLIENT_ROOT_NAME)
	local existing = clientRoot and clientRoot:FindFirstChild(NTR_PHASE4_PREVIEW_ROOT_NAME)
	if existing then
		existing:ClearAllChildren()
	end
	if Preview then
		Preview.Root = existing
		Preview.Vehicle = nil
	end
end

local function NTR_phase4Intro()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	return dealership and dealership:FindFirstChild("Intro")
end

local function NTR_phase4PreviewCFrame()
	local intro = NTR_phase4Intro()
	local previewFolder = intro and intro:FindFirstChild("Preview")
	local previewPoint = previewFolder and previewFolder:FindFirstChild("VehiclePreviewPoint")
	if previewPoint and previewPoint:IsA("BasePart") then
		return previewPoint.CFrame
	end
	return CFrame.new(State.Catalog and State.Catalog.PreviewPosition or Vector3.new(860, 104, -1749))
end

local function NTR_phase4PreviewPosition()
	return NTR_phase4PreviewCFrame().Position
end

local function NTR_phase4ApplyGaragePreviewCamera()
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
end

local function NTR_phase4UnlockPreviewAfterPurchase()
	State.NoPreviewYet = false
	State.GarageCameraActive = true
	State.TargetFocus = NTR_phase4PreviewPosition()
	State.CameraFocus = State.TargetFocus
	buildPreview()
	NTR_phase4ApplyGaragePreviewCamera()
end
-- NTR_DEALERSHIP_INTRO_PHASE4_PREVIEW_AFTER_PURCHASE_END

]==]

local replacements = {
	{
		name = "Insert Phase 4 helpers before previewRoot",
		old = "local function previewRoot()\n",
		new = PHASE4_HELPERS .. "local function previewRoot()\n",
	},
	{
		name = "Use local-only Workspace._NTR_ClientOnly.VehiclePreview root",
		old = [==[local function previewRoot()
	if Preview.Root and Preview.Root.Parent then return Preview.Root end
	local existing = Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
	if existing then existing:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "HOVER_RACING_V2_LOCAL_PREVIEW"
	root.Parent = Workspace
	Preview.Root = root
	return root
end]==],
		new = [==[local function previewRoot()
	return NTR_phase4PreviewRoot()
end]==],
	},
	{
		name = "Skip preview build while NoPreviewYet is active",
		old = [==[local function buildPreview()
	local root = previewRoot()
	root:ClearAllChildren()]==],
		new = [==[local function buildPreview()
	if State.NoPreviewYet == true then
		NTR_phase4ClearPreview()
		return
	end

	local root = previewRoot()
	root:ClearAllChildren()]==],
	},
	{
		name = "Convert buildPreview to predeclared assignment",
		old = "local function buildPreview()\n",
		new = "buildPreview = function()\n",
	},
	{
		name = "Place preview vehicle at dealership marker",
		old = [==[	local previewPosition = State.Catalog and State.Catalog.PreviewPosition or Vector3.new(860, 104, -1749)
	vehicle:PivotTo(CFrame.new(previewPosition))]==],
		new = [==[	local previewCFrame = NTR_phase4PreviewCFrame()
	local previewPosition = previewCFrame.Position
	vehicle:PivotTo(previewCFrame)]==],
	},
	{
		name = "Use dealership preview camera marker",
		old = [==[	if not camera then camera = Workspace.CurrentCamera end
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable]==],
		new = [==[	if not camera then camera = Workspace.CurrentCamera end
	if not camera then return end
	if NTR_phase4ApplyGaragePreviewCamera() then return end
	camera.CameraType = Enum.CameraType.Scriptable]==],
	},
	{
		name = "Initialize garage with NoPreviewYet",
		old = [==[	State.SelectedCockpit = State.Profile.CurrentCockpit or "bruiser_01"
	local firstSlot = sortedSlots()[1]]==],
		new = [==[	State.SelectedCockpit = State.Profile.CurrentCockpit or "bruiser_01"
	State.NoPreviewYet = true
	State.GarageCameraActive = false
	NTR_phase4ClearPreview()
	local firstSlot = sortedSlots()[1]]==],
	},
	{
		name = "Do not build preview at garage open/init",
		old = [==[	renderCockpitShop()
	buildPreview()
end]==],
		new = [==[	renderCockpitShop()
	-- Phase 4: preview stays hidden until cockpit purchase succeeds.
end]==],
	},
	{
		name = "Unlock preview after successful cockpit purchase",
		old = [==[		if result.Success then
			showStage("CockpitPaint")
			renderCockpitPaint()
		else]==],
		new = [==[		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			showStage("CockpitPaint")
			renderCockpitPaint()
		else]==],
	},
}

local SERVICES = {
	StarterPlayer = StarterPlayer,
}

local function log(message)
	print("[NTR Dealership Intro Phase 4] " .. message)
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

if string.find(source, "NTR_DEALERSHIP_INTRO_PHASE4_PREVIEW_AFTER_PURCHASE_BEGIN", 1, true) then
	table.insert(skipped, safeFullName(bootstrap) .. " already contains Phase 4 patch")
else
	for _, replacement in ipairs(replacements) do
		local foundCount = countPlain(source, replacement.old)
		if foundCount ~= 1 then
			error(("Phase 4 preflight failed for `%s`: expected exactly 1 match, found %d. No changes applied. This is a fragile source-text patch; paste this output back into Codex."):format(replacement.name, foundCount))
		end
	end

	for _, replacement in ipairs(replacements) do
		local patched, count = replaceOncePlain(source, replacement.old, replacement.new)
		if count ~= 1 then
			error("Unexpected patch failure for `" .. replacement.name .. "`. No changes applied.")
		end
		source = patched
		table.insert(changed, replacement.name)
	end

	bootstrap.Source = source
	bootstrap:SetAttribute("DealershipIntroPhase4PatchedBy", SCRIPT_ID)
	bootstrap:SetAttribute("DealershipIntroPhase4PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	bootstrap:SetAttribute("DealershipIntroPhase4FragilePatch", true)
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 4 Preview After Purchase")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Target: " .. BOOTSTRAP_PATH)
line("- Fragile source-text patch: true")
line("- Changes applied: " .. tostring(#changed))
line("- Skipped: " .. tostring(#skipped))
line("- Server purchase/profile/cash logic touched: false")
line("- Server preview spawn touched: false")
line("- Preview root: Workspace._NTR_ClientOnly.VehiclePreview")
line("- Preview marker: Workspace.NeoTokyoRacersWorld.Dealership.Intro.Preview.VehiclePreviewPoint")
line("- Camera marker: Workspace.NeoTokyoRacersWorld.Dealership.Intro.Camera.GaragePreviewCameraPoint")
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
line("2. Walk to the dealership desk; garage UI should open with no preview vehicle yet.")
line("3. Select/buy a cockpit.")
line("4. After BuyCockpit succeeds, `Workspace._NTR_ClientOnly.VehiclePreview` should contain the local preview vehicle.")
line("5. Camera should look from `GaragePreviewCameraPoint` toward `VehiclePreviewPoint`.")
line("6. Continue cockpit paint/customisation and final drivable spawn checks.")
line("7. In a two-player local server test, confirm each client sees only their own `_NTR_ClientOnly.VehiclePreview`.")

log("Phase 4 complete. Changes applied: " .. tostring(#changed) .. "; skipped: " .. tostring(#skipped))
print(table.concat(report, "\n"))
