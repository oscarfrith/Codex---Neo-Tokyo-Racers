-- Neo Tokyo Racers - Garage Phase 1 persistence/runtime ownership audit
-- NTR_GARAGE_PHASE1_PERSISTENCE_RUNTIME_AUDIT_V1
-- Read only. Run once in Edit mode and once in Play > Client.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local prefix = "[NTR Garage Phase 1 Persistence Audit] "
local failures = 0

local function line(label, value)
	print(prefix .. label .. " = " .. tostring(value))
end

local function fail(message)
	failures += 1
	warn(prefix .. "FAIL " .. message)
end

local function findPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
		if not current then return nil end
	end
	return current
end

local function sourceHas(object, marker)
	if not object or not object:IsA("LuaSourceContainer") then return false end
	local ok, source = pcall(function() return object.Source end)
	return ok and string.find(source, marker, 1, true) ~= nil
end

local function enabledState(object)
	if not object or not object:IsA("BaseScript") then return "n/a" end
	local okEnabled, enabled = pcall(function() return object.Enabled end)
	if okEnabled then return enabled end
	local okDisabled, disabled = pcall(function() return object.Disabled end)
	return okDisabled and not disabled or "unreadable"
end

local context
local clientRoot
if RunService:IsRunning() then
	context = "PLAY_CLIENT"
	local player = Players.LocalPlayer
	if not player then error(prefix .. "Run the Play audit from the Client Command Bar.", 0) end
	clientRoot = player:WaitForChild("PlayerScripts", 10) and player.PlayerScripts:FindFirstChild("NeoTokyoRacersClient")
else
	context = "EDIT"
	clientRoot = StarterPlayer:FindFirstChild("StarterPlayerScripts") and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
end

line("CONTEXT", context)
if not clientRoot then error(prefix .. "NeoTokyoRacersClient root is missing.", 0) end
line("CLIENT_ROOT", clientRoot:GetFullName())

local ui = findPath(clientRoot, "Controllers.UI")
local bootstrap = clientRoot:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
local registry = ui and ui:FindFirstChild("GarageModuleArtworkRegistry")
local adapter = ui and ui:FindFirstChild("GarageActionAdapter")
local application = ui and ui:FindFirstChild("GarageApplicationController_Active")
local applicationHost = ui and ui:FindFirstChild("ModuleShopUIController")
local browser = ui and ui:FindFirstChild("GarageBrowserController")
local workspaceController = ui and ui:FindFirstChild("GarageWorkspaceController")
local components = ui and ui:FindFirstChild("GarageReplacementComponents")
local preview = findPath(clientRoot, "Controllers.Preview")
local previewVehicle = preview and preview:FindFirstChild("PreviewVehicleController")
local previewCamera = preview and preview:FindFirstChild("PreviewCameraController")
local previewPad = findPath(workspace, "NeoTokyoRacersWorld.Garages.GaragePreviewPad")

line("Bootstrap exists", bootstrap ~= nil)
line("Bootstrap activation attribute", bootstrap and bootstrap:GetAttribute("CanonicalGarageApplicationActive"))
line("Bootstrap gate marker", sourceHas(bootstrap, "NTR_GARAGE_CANONICAL_APPLICATION_GATE_V1"))
line("Bootstrap existing-instance gate", sourceHas(bootstrap, "NTR_GARAGE_EXISTING_INSTANCE_GATE_V1"))
line("Bootstrap existing-instance startup bridge", sourceHas(bootstrap, "NTR_GARAGE_EXISTING_INSTANCE_STARTUP_BRIDGE_V1"))
line("Registry exists", registry ~= nil)
line("Registry class", registry and registry.ClassName)
line("Registry source marker", sourceHas(registry, "NTR_GARAGE_MODULE_ARTWORK_REGISTRY_CANONICAL_V1"))
line("Action adapter exists", adapter ~= nil)
line("Action adapter source marker", sourceHas(adapter, "NTR_GARAGE_ACTION_ADAPTER_CANONICAL_V1"))
line("Application exists", application ~= nil)
line("Application enabled", enabledState(application))
line("Application source marker", sourceHas(application, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V1"))
line("Existing application host", applicationHost and applicationHost:GetFullName())
line("Existing application host source marker", sourceHas(applicationHost, "NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3"))
line("Browser exists", browser ~= nil)
line("Workspace exists", workspaceController ~= nil)
line("Preview pad vehicle marker", sourceHas(previewVehicle, "NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3"))
line("Orbit/fade camera marker", sourceHas(previewCamera, "NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3"))
line("Shared listing cards marker", sourceHas(components, "NTR_GARAGE_MODULE_CARD_VARIANTS_V3"))
line("Garage preview pad", previewPad and previewPad:GetFullName())

if not bootstrap then fail("bootstrap missing") end
if not sourceHas(bootstrap, "NTR_GARAGE_EXISTING_INSTANCE_GATE_V1") then fail("unconditional bootstrap garage gate missing") end
if not sourceHas(bootstrap, "NTR_GARAGE_EXISTING_INSTANCE_STARTUP_BRIDGE_V1") then fail("existing-instance startup bridge missing") end
if not sourceHas(applicationHost, "NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3") then fail("existing ModuleShopUIController V3 application host missing or wrong") end
if not sourceHas(workspaceController, "NTR_GARAGE_EMBEDDED_ARTWORK_FALLBACK_V1") then fail("Workspace embedded artwork fallback missing") end
if not sourceHas(workspaceController, "NTR_GARAGE_WORKSPACE_CATEGORY_LISTING_V3") then fail("Workspace artwork rail/listing renderer missing") end
if not sourceHas(previewVehicle, "NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3") then fail("canonical preview-pad vehicle controller missing") end
if not sourceHas(previewCamera, "NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3") then fail("canonical orbit/fade camera controller missing") end
if not sourceHas(components, "NTR_GARAGE_MODULE_CARD_VARIANTS_V3") then fail("shared module card variants missing") end
if not (previewPad and previewPad:IsA("BasePart")) then fail("GaragePreviewPad missing or not a BasePart") end

local replacement = findPath(ReplicatedStorage, "NeoTokyoRacers.Config.UI.GarageReplacement")
local artwork = replacement and replacement:FindFirstChild("ModuleArtwork")
local expected = {"All","Cockpit","ThrustColour","FrontEngine","RearEngine","Stabilisers","Boost","FrontBumper","RearBumper","SidePods","Spoiler"}
local categoryCount = 0
if artwork and artwork:IsA("Folder") then
	for _, child in ipairs(artwork:GetChildren()) do
		if child:IsA("Folder") then categoryCount += 1 end
	end
end
line("Artwork root exists", artwork ~= nil)
line("Artwork category folder count", categoryCount)
for _, name in ipairs(expected) do
	local folder = artwork and artwork:FindFirstChild(name)
	line("Artwork." .. name, folder and (folder.ClassName .. ", children=" .. tostring(#folder:GetChildren())) or "missing")
	if folder and (not folder:IsA("Folder") or #folder:GetChildren() ~= 0) then fail("artwork category invalid: " .. name) end
end

if RunService:IsRunning() then
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local legacy = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	local canonical = playerGui and playerGui:FindFirstChild("CanonicalGarageGui")
	line("Legacy GUI exists", legacy ~= nil)
	line("Legacy GUI enabled", legacy and legacy.Enabled)
	line("Canonical GUI exists", canonical ~= nil)
	line("Canonical GUI enabled", canonical and canonical.Enabled)
	line("Session active", Players.LocalPlayer:GetAttribute("NTR_GarageSessionActive"))
end

if failures == 0 then
	print(prefix .. "PASS " .. context)
else
	warn(prefix .. "SUMMARY FAIL context=" .. context .. " failures=" .. tostring(failures))
end
