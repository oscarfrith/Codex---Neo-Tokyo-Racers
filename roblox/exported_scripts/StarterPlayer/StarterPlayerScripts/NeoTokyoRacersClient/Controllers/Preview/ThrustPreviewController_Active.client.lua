-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1
-- NTR_GARAGE_SCROLL_EDGE_SAFETY_V1
-- NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1
-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_THRUST_PREVIEW_STALE_LIVE_CALL_REMOVED_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local VehicleCosmetics=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("VehicleCosmeticCatalog")) -- NTR_CUSTOMISATION_PROTECTED_VEHICLE_LIGHTS_V1
local templates=kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates")
local cfg=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local controllerModule
pcall(function() controllerModule=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("VehicleVFXController")) end)
local previewController,previewVehicle,controls
local controlsDisabled=false
local lastTargetPoll=0
local cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce,cachedPreviewMode
local cachedPlayerVehicle,cachedPlayerColor
local function number(name,fallback) local value=cfg:GetAttribute(name); return typeof(value)=="number" and value or fallback end
task.defer(function() local scripts=player:WaitForChild("PlayerScripts",10); local module=scripts and scripts:FindFirstChild("PlayerModule"); if not module then return end; local ok,result=pcall(require,module); if ok and result and result.GetControls then controls=result:GetControls() end end)
local function garageOpen() return player:GetAttribute("NTR_GarageSessionActive")==true end
local function driveOpen() local hud=playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD"); return hud and hud.Enabled end
local function setRobloxTouchControls(enabled) local touch=playerGui:FindFirstChild("TouchGui"); if touch and touch:IsA("ScreenGui") then touch.Enabled=enabled end; if controls then if enabled and controlsDisabled then controlsDisabled=false; pcall(function() controls:Enable() end) elseif not enabled and not controlsDisabled then controlsDisabled=true; pcall(function() controls:Disable() end) end end end
local function getPlayerVehicle() local world=Workspace:FindFirstChild("NeoTokyoRacersWorld"); local runtime=world and world:FindFirstChild("Runtime"); local root=runtime and runtime:FindFirstChild("PlayerVehicles"); if not root then return nil end; for _,vehicle in ipairs(root:GetChildren()) do if vehicle:GetAttribute("OwnerUserId")==player.UserId then return vehicle end end end
local function getPreviewRoot() local client=Workspace:FindFirstChild("_NTR_ClientOnly"); return (client and client:FindFirstChild("VehiclePreview")) or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW") end
local function getPreviewVehicle(root) if not root then return nil end; for _,child in ipairs(root:GetChildren()) do if child:IsA("Model") then return child end end end
local function hasChannel(object,channel) local current=object; while current do if current:GetAttribute("PaintChannel")==channel then return true end; if channel=="ThrustColor" and string.find(string.lower(current.Name),"thrust_color",1,true) then return true end; current=current.Parent end; return false end
local function applyFireColour(object,color) if object:IsA("ParticleEmitter") then object.Color=ColorSequence.new(color) elseif object:IsA("Fire") then object.Color=color; object.SecondaryColor=color elseif object:IsA("Smoke") then object.Color=color elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Color=color end end
local function isPreviewToggle(object) return object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") end
local function insideRuntimeHost(object,root) local current=object; while current and current~=root do if current:GetAttribute("NTR_VFXRuntimeHost")==true then return true end; current=current.Parent end; return false end
local function previewEffectKind(object,root)
	local current=object
	while current and current~=root.Parent do
		local lower=string.lower(current.Name)
		if string.find(lower,"engineoff",1,true) or string.find(lower,"engineidle",1,true) then return "Idle" end
		if string.find(lower,"engineon",1,true) or string.find(lower,"enginethrust",1,true) then return "Acceleration" end
		if string.find(lower,"booston",1,true) or string.find(lower,"boostjet",1,true) then return "Boost" end
		if string.find(lower,"stabiliseron",1,true) or string.find(lower,"stabilizeron",1,true) or string.find(lower,"stabiliserjet",1,true) or string.find(lower,"stabilizerjet",1,true) then return "Stabiliser" end
		if string.find(lower,"hover",1,true) or string.find(lower,"dust",1,true) then return "Hover" end
		if current==root then break end; current=current.Parent
	end
	return nil
end
local function applyPreviewEffects(root,color,mode)
	if not root then return end; local full=mode=="ThrustColour"
	for _,object in ipairs(root:GetDescendants()) do
		if object:IsA("BasePart") and hasChannel(object,"ThrustColor") then object.Color=color; object.Material=Enum.Material.Neon; object.Transparency=0
		elseif isPreviewToggle(object) and not VehicleCosmetics.IsProtectedVehicleLight(object) and not insideRuntimeHost(object,root) then local kind=previewEffectKind(object,root); if kind then applyFireColour(object,color); do end end end
	end
end

local function refreshTargets()
	local root=getPreviewRoot(); local vehicle=getPreviewVehicle(root); local color=root and (root:GetAttribute("ThrustColor") or Color3.new(1,1,1)); local force=root and root:GetAttribute("ForceThrustPreview")==true; local mode=root and tostring(root:GetAttribute("PreviewVFXMode") or "Idle") or "Idle"
	if root~=cachedPreviewRoot or vehicle~=cachedPreviewVehicle or color~=cachedPreviewColor or force~=cachedPreviewForce or mode~=cachedPreviewMode then cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce,cachedPreviewMode=root,vehicle,color,force,mode; applyPreviewEffects(root,color or Color3.new(1,1,1),mode) end
	-- CachedThrustVisualRuntime is the single template-VFX owner. This bridge
	-- deliberately never attaches a second VehicleVFXController.
	if previewController then previewController:Destroy(); previewController=nil end
	previewVehicle=vehicle
	local playerVehicle=getPlayerVehicle(); local playerColor=playerVehicle and (playerVehicle:GetAttribute("ThrustColor") or Color3.new(1,1,1)); if playerVehicle~=cachedPlayerVehicle or playerColor~=cachedPlayerColor then cachedPlayerVehicle,cachedPlayerColor=playerVehicle,playerColor end
end
local function forceDriveCamera() if not driveOpen() then return end; local camera=Workspace.CurrentCamera; if camera and camera:GetAttribute("NTRDrivingCameraManaged")==true then return end; local vehicle=cachedPlayerVehicle or getPlayerVehicle(); local seat=vehicle and vehicle:FindFirstChild("DriverSeat",true); if camera and seat and seat:IsA("VehicleSeat") then camera.CameraType=Enum.CameraType.Custom; camera.CameraSubject=seat end end
refreshTargets()
RunService.RenderStepped:Connect(function(dt)
	if UserInputService.TouchEnabled then setRobloxTouchControls(not garageOpen() and not driveOpen()) end
	forceDriveCamera()
	local now=os.clock(); if now-lastTargetPoll>=number("ThrustTargetPollSeconds",.25) then lastTargetPoll=now; refreshTargets() end
	-- Template VFX state is updated only by CachedThrustVisualRuntime.
end)
