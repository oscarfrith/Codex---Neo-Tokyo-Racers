-- Neo Tokyo Racers - UI / garage performance hardening Phase 1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.
-- This is transactional: every candidate source is compiled before any live Source is changed.

local MODE = "INSTALL" -- INSTALL or AUDIT
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local function replaceRange(source, startText, endText, replacement, label, searchFrom)
	local first = string.find(source, startText, searchFrom or 1, true)
	assert(first, "Missing range start: " .. label)
	local finish = string.find(source, endText, first + #startText, true)
	assert(finish, "Missing range end: " .. label)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, finish)
end

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local preview = need(controllers, "Preview", "Folder")

local desktopHud = need(ui, "DesktopFreeRoamHudController_Active", "LocalScript")
local workspaceController = need(ui, "GarageWorkspaceController", "ModuleScript")
local applicationController = need(ui, "ModuleShopUIController", "ModuleScript")
local previewVehicle = need(preview, "PreviewVehicleController", "ModuleScript")
local thrustPreview = need(preview, "ThrustPreviewController_Active", "LocalScript")

local serverRoot = need(ServerScriptService, "NeoTokyoRacers", "Folder")
local services = need(serverRoot, "Services", "Folder")
local garageServices = need(services, "Garage", "Folder")
local garageServer = need(garageServices, "GarageActionController_Shadow_Disabled", "Script")

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")

local required = {
	{desktopHud, "NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT"},
	{workspaceController, "NTR_GARAGE_WORKSPACE"},
	{applicationController, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3"},
	{previewVehicle, "NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3"},
	{garageServer, "V56_CONSOLIDATED_ACTION_CONTROLLER"},
}

local function audit()
	local failures = {}
	local function expect(ok, text)
		if not ok then table.insert(failures, text) end
	end
	for _, item in ipairs(required) do
		expect(string.find(item[1].Source, item[2], 1, true) ~= nil, item[1].Name .. " baseline marker missing")
	end
	for _, object in ipairs({desktopHud, workspaceController, applicationController, previewVehicle, thrustPreview, garageServer}) do
		expect(string.find(object.Source, REVISION, 1, true) ~= nil, object.Name .. " performance revision missing")
	end
	expect(config:GetAttribute("PaintCommitOnRelease") == true, "PaintCommitOnRelease config missing")
	expect(tonumber(config:GetAttribute("ThrustTargetPollSeconds")) == 0.25, "ThrustTargetPollSeconds config missing")
	if #failures == 0 then
		print("[NTR UI Performance Phase 1] AUDIT PASS")
		return true
	end
	warn("[NTR UI Performance Phase 1] AUDIT FAIL: " .. table.concat(failures, " | "))
	return false
end

if MODE == "AUDIT" then
	audit()
	return
end

for _, item in ipairs(required) do
	assert(string.find(item[1].Source, item[2], 1, true), "Wrong mirror baseline for " .. item[1].Name .. ": " .. item[2] .. " missing")
end

if string.find(applicationController.Source, REVISION, 1, true) then
	print("[NTR UI Performance Phase 1] Already installed; running audit only.")
	audit()
	return
end

local candidates = {}
local function candidate(object, source)
	compile(object:GetFullName(), source)
	table.insert(candidates, {Object = object, Source = source, Before = object.Source})
end

-- Desktop HUD: remove the two-second full GetInitial poll. Cash is already replicated through leaderstats.
local desktopSource = desktopHud.Source
desktopSource = "-- " .. REVISION .. "\n" .. desktopSource
desktopSource = replaceOnce(desktopSource,
[[		if carPanel.Visible then renderCars() end]],
[[		if carPanel.Visible then
			readInitial(true)
			renderCars()
		else
			cachedInitial = nil
			cachedProfile = nil
			cachedCatalog = nil
		end]],
	"desktop vehicle panel on-demand refresh")
desktopSource = replaceOnce(desktopSource,
[[			carPanel.Visible = false
			leftCluster.Visible = true
			showToast("VEHICLE SPAWNED", true)]],
[[			carPanel.Visible = false
			leftCluster.Visible = true
			cachedInitial = nil
			cachedProfile = nil
			cachedCatalog = nil
			showToast("VEHICLE SPAWNED", true)]],
	"desktop vehicle cache release after spawn")
desktopSource = replaceOnce(desktopSource,
[[	if not (racingPresentationActive and readValue(racingPerformanceConfig, "PauseFreeRoamProfileDuringRace", true) == true) and not profileReadPending and os.clock() - lastProfileRead >= L("ProfileRefreshSeconds", 2) then
		profileReadPending = true
		lastProfileRead = os.clock()
		task.spawn(function()
			readInitial(true)
			if moneyLabel and moneyLabel.Parent then
				moneyLabel.Text = formatCash(cachedProfile and cachedProfile.Cash or 0)
				local balanceChip = modalPanels.Cash and modalPanels.Cash:FindFirstChild("BalanceChip")
				if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text = "BALANCE  " .. moneyLabel.Text end
			end
			profileReadPending = false
		end)
	end]],
[[	-- Cash is replicated by leaderstats. Full garage profiles are fetched only when the vehicle panel opens.]],
	"desktop full-profile polling loop")
desktopSource = replaceOnce(desktopSource,
[[ensureGui()
updateLayout()
readInitial(true)
moneyLabel.Text = formatCash(cachedProfile and cachedProfile.Cash or 0)]],
[[ensureGui()
updateLayout()

local cashConnection
local function bindReplicatedCash()
	if cashConnection then cashConnection:Disconnect(); cashConnection = nil end
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if not (cash and cash:IsA("IntValue")) then return false end
	local function updateCash()
		if not (moneyLabel and moneyLabel.Parent) then return end
		moneyLabel.Text = formatCash(cash.Value)
		local balanceChip = modalPanels.Cash and modalPanels.Cash:FindFirstChild("BalanceChip")
		if balanceChip and balanceChip:IsA("TextButton") then balanceChip.Text = "BALANCE  " .. moneyLabel.Text end
	end
	updateCash()
	cashConnection = cash:GetPropertyChangedSignal("Value"):Connect(updateCash)
	return true
end
if not bindReplicatedCash() then
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 15)
		if leaderstats then leaderstats:WaitForChild("Cash", 15) end
		bindReplicatedCash()
	end)
end]],
	"desktop leaderstats cash binding")
candidate(desktopHud, desktopSource)

-- Paint UI: live preview while dragging, one persistence request when the pointer is released.
local workspaceSource = "-- " .. REVISION .. "\n" .. workspaceController.Source
workspaceSource = replaceOnce(workspaceSource,
[[	local function emit() if context.OnColor then context.OnColor(selected,Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3])) end end]],
[[	local function emit(commit) if context.OnColor then context.OnColor(selected,Color3.fromHSV(self.PaintHSV[1],self.PaintHSV[2],self.PaintHSV[3]),commit==true) end end]],
	"workspace paint emit contract")
workspaceSource = replaceOnce(workspaceSource,
[[		local function update(input) local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); self.PaintHSV[index]=x; knob.Position=UDim2.fromScale(x,.5); emit() end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,endConnection; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); endConnection=UserInputService.InputEnded:Connect(function(ended) if ended.UserInputType==input.UserInputType then move:Disconnect(); endConnection:Disconnect() end end) end))]],
[[		local function update(input) local x=math.clamp((input.Position.X-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1); self.PaintHSV[index]=x; knob.Position=UDim2.fromScale(x,.5); emit(false) end
		table.insert(self.Dynamic,track.InputBegan:Connect(function(input) if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; update(input); local move,endConnection; move=UserInputService.InputChanged:Connect(function(changed) if changed.UserInputType==Enum.UserInputType.MouseMovement or changed.UserInputType==Enum.UserInputType.Touch then update(changed) end end); endConnection=UserInputService.InputEnded:Connect(function(ended) if ended.UserInputType==input.UserInputType then move:Disconnect(); endConnection:Disconnect(); emit(true) end end) end))]],
	"workspace paint drag commit")
candidate(workspaceController, workspaceSource)

-- Preview vehicle: recolour the existing clone instead of destroying and rebuilding the whole vehicle.
local previewSource = "-- " .. REVISION .. "\n" .. previewVehicle.Source
previewSource = replaceOnce(previewSource,
[[	local boxCFrame=vehicle:GetBoundingBox(); state.TargetFocus=boxCFrame.Position; preview.Focus=boxCFrame.Position; return vehicle,nil
end
return PreviewVehicleController]],
[[	local boxCFrame=vehicle:GetBoundingBox(); state.TargetFocus=boxCFrame.Position; preview.Focus=boxCFrame.Position; return vehicle,nil
end
function PreviewVehicleController.ApplyPaint(context)
	local state=context.State; local preview=context.Preview or {}; local profile=state and state.Profile; local vehicle=preview.Vehicle
	if not (profile and vehicle and vehicle.Parent) then return false end
	local target=tostring(context.Target or "Cockpit"); local channel=tostring(context.Channel or "Primary"); local color=context.Color
	if typeof(color)~="Color3" then return false end
	profile.CockpitColors=profile.CockpitColors or {}; profile.ModuleColors=profile.ModuleColors or {}
	if target=="THRUST_COLOR" then
		profile.ThrustColor=color; local root=preview.Root; if root then root:SetAttribute("ThrustColor",color); root:SetAttribute("ForceThrustPreview",true) end; vehicle:SetAttribute("ThrustColor",color); return true
	elseif target=="Cockpit" then
		profile.CockpitColors[channel]=color
		if channel=="Primary" or channel=="Secondary" or channel=="Detail" then for slotId in pairs(profile.InstalledModules or {}) do profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId][channel]=color end end
	elseif target=="ALL" then
		if channel~="Neon" then profile.CockpitColors[channel]=color end
		for slotId in pairs(profile.InstalledModules or {}) do profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId][channel]=color end
	else profile.ModuleColors[target]=profile.ModuleColors[target] or {}; profile.ModuleColors[target][channel]=color end
	local cockpitColors={}; for key,value in pairs(profile.CockpitColors) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116)
	PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=profile})
	local installed=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime")
	if installed then for slotId in pairs(profile.InstalledModules or {}) do local prefix="PREVIEW_"..tostring(slotId).."_"; for _,clone in ipairs(installed:GetChildren()) do if string.sub(clone.Name,1,#prefix)==prefix then PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(profile,slotId),(profile.NeonOwned or {})[slotId]==true,{Profile=profile}) end end end end
	return true
end
return PreviewVehicleController]],
	"preview in-place paint API")
candidate(previewVehicle, previewSource)

-- Application controller: use the in-place preview and persist only completed slider gestures.
local applicationSource = "-- " .. REVISION .. "\n" .. applicationController.Source
applicationSource = replaceOnce(applicationSource,
[[local function buildPreview() State.GarageCameraActive=true; local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace}); if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end end]],
[[local function buildPreview() State.GarageCameraActive=true; local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace}); if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end end
local function handlePaint(target,channel,color,commit)
	PreviewVehicle.ApplyPaint({State=State,Preview=preview,Target=target,Channel=channel,Color=color})
	if commit~=true then return end
	local result
	if target=="THRUST_COLOR" then result=action:Call("SetThrustColor",{Color=color})
	elseif target=="ALL" then result=action:Call("SetModuleColor",{SlotId="ALL",Channel=channel,Color=color}); if result.Success and channel~="Neon" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color}) end
	elseif target=="Cockpit" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color})
	else result=action:Call("SetModuleColor",{SlotId=target,Channel=channel,Color=color}) end
	if not (result and result.Success) then local text=result and result.Message or "Colour could not be saved."; if workspaceUI.Root.Visible then workspaceUI:Message(text) else warn("[NTR Canonical Garage] "..tostring(text)) end end
end]],
	"application in-place paint handler")
applicationSource = replaceRange(applicationSource,
	"c.OnColor=function(ch,color)",
	"; c.OnNext=function()",
	"c.OnColor=function(ch,color,commit) handlePaint(\"Cockpit\",ch,color,commit) end",
	"paint cockpit callback")
local customiseStart = assert(string.find(applicationSource, "renderCustomise=function()", 1, true))
applicationSource = replaceRange(applicationSource,
	"c.OnColor=function(ch,color)",
	"\n\telseif State.CustomizeMode==\"Cosmetics\"",
	"c.OnColor=function(ch,color,commit) handlePaint(target,ch,color,commit) end",
	"customise paint callback",
	customiseStart)
candidate(applicationController, applicationSource)

-- Colour actions no longer rebuild every vehicle summary just to acknowledge a saved colour.
local serverSource = "-- " .. REVISION .. "\n" .. garageServer.Source
serverSource = replaceOnce(serverSource,
[[			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }]],
[[			if action == "SetCockpitColor" or action == "SetModuleColor" or action == "SetThrustColor" then
				return { Success = ok == true, Message = message, ColorOnly = true }
			end
			return { Success = ok == true, Message = message, Profile = V56_profileForClient(profile) }]],
	"server lightweight colour acknowledgement")
candidate(garageServer, serverSource)

-- Thrust preview: preserve animated preview VFX, but scan/recolour descendants only when the target or colour changes.
local thrustSource = [==[
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local templates=kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates")
local cfg=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local controllerModule
pcall(function() controllerModule=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("VFX"):WaitForChild("VehicleVFXController")) end)
local previewController,previewVehicle,controls
local controlsDisabled=false
local lastTargetPoll=0
local cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce
local cachedPlayerVehicle,cachedPlayerColor
local function number(name,fallback) local value=cfg:GetAttribute(name); return typeof(value)=="number" and value or fallback end
task.defer(function() local scripts=player:WaitForChild("PlayerScripts",10); local module=scripts and scripts:FindFirstChild("PlayerModule"); if not module then return end; local ok,result=pcall(require,module); if ok and result and result.GetControls then controls=result:GetControls() end end)
local function requestLandscape() if not UserInputService.TouchEnabled then return end; pcall(function() StarterGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end); pcall(function() playerGui.ScreenOrientation=Enum.ScreenOrientation.LandscapeSensor end) end
local function garageOpen() return player:GetAttribute("NTR_GarageSessionActive")==true end
local function driveOpen() local hud=playerGui:FindFirstChild("HOVER_RACING_V2_DriveHUD"); return hud and hud.Enabled end
local function setRobloxTouchControls(enabled) local touch=playerGui:FindFirstChild("TouchGui"); if touch and touch:IsA("ScreenGui") then touch.Enabled=enabled end; if controls then if enabled and controlsDisabled then controlsDisabled=false; pcall(function() controls:Enable() end) elseif not enabled and not controlsDisabled then controlsDisabled=true; pcall(function() controls:Disable() end) end end end
local function getPlayerVehicle() local world=Workspace:FindFirstChild("NeoTokyoRacersWorld"); local runtime=world and world:FindFirstChild("Runtime"); local root=runtime and runtime:FindFirstChild("PlayerVehicles"); if not root then return nil end; for _,vehicle in ipairs(root:GetChildren()) do if vehicle:GetAttribute("OwnerUserId")==player.UserId then return vehicle end end end
local function getPreviewRoot() local client=Workspace:FindFirstChild("_NTR_ClientOnly"); return (client and client:FindFirstChild("VehiclePreview")) or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW") end
local function getPreviewVehicle(root) if not root then return nil end; for _,child in ipairs(root:GetChildren()) do if child:IsA("Model") then return child end end end
local function hasChannel(object,channel) local current=object; while current do if current:GetAttribute("PaintChannel")==channel then return true end; if channel=="ThrustColor" and string.find(string.lower(current.Name),"thrust_color",1,true) then return true end; current=current.Parent end; return false end
local function isThrustFire(object) local lower=string.lower(object.Name); return string.find(lower,"booston_fire",1,true) or string.find(lower,"engineoff_fire",1,true) or string.find(lower,"engineon_fire",1,true) or string.find(lower,"stabiliseron_fire",1,true) or string.find(lower,"stabilizeron_fire",1,true) end
local function applyFireColour(object,color) if object:IsA("ParticleEmitter") then object.Color=ColorSequence.new(color) elseif object:IsA("Fire") then object.Color=color; object.SecondaryColor=color elseif object:IsA("Smoke") then object.Color=color elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Color=color end end
local function applyThrustOnly(root,color,forceEnabled) if not root then return end; for _,object in ipairs(root:GetDescendants()) do if object:IsA("BasePart") and hasChannel(object,"ThrustColor") then object.Color=color; object.Material=Enum.Material.Neon; object.Transparency=0 elseif isThrustFire(object) then applyFireColour(object,color); if forceEnabled~=nil then pcall(function() object.Enabled=forceEnabled end) end end end end
local function refreshTargets()
	local root=getPreviewRoot(); local vehicle=getPreviewVehicle(root); local color=root and (root:GetAttribute("ThrustColor") or Color3.new(1,1,1)); local force=root and root:GetAttribute("ForceThrustPreview")==true
	if root~=cachedPreviewRoot or vehicle~=cachedPreviewVehicle or color~=cachedPreviewColor or force~=cachedPreviewForce then cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce=root,vehicle,color,force; applyThrustOnly(root,color or Color3.new(1,1,1),force and true or nil) end
	if previewVehicle~=vehicle then if previewController then previewController:Destroy() end; previewController=nil; previewVehicle=vehicle end; if force and vehicle and not previewController and controllerModule then previewController=controllerModule.Attach(vehicle,templates,UserInputService.TouchEnabled) elseif not force and previewController then previewController:Destroy(); previewController=nil end
	local playerVehicle=getPlayerVehicle(); local playerColor=playerVehicle and (playerVehicle:GetAttribute("ThrustColor") or Color3.new(1,1,1)); if playerVehicle~=cachedPlayerVehicle or playerColor~=cachedPlayerColor then cachedPlayerVehicle,cachedPlayerColor=playerVehicle,playerColor; applyThrustOnly(playerVehicle,playerColor or Color3.new(1,1,1),nil) end
end
local function forceDriveCamera() if not driveOpen() then return end; local camera=Workspace.CurrentCamera; if camera and camera:GetAttribute("NTRDrivingCameraManaged")==true then return end; local vehicle=cachedPlayerVehicle or getPlayerVehicle(); local seat=vehicle and vehicle:FindFirstChild("DriverSeat",true); if camera and seat and seat:IsA("VehicleSeat") then camera.CameraType=Enum.CameraType.Custom; camera.CameraSubject=seat end end
requestLandscape(); refreshTargets()
RunService.RenderStepped:Connect(function(dt)
	if UserInputService.TouchEnabled then setRobloxTouchControls(not garageOpen() and not driveOpen()) end
	forceDriveCamera()
	local now=os.clock(); if now-lastTargetPoll>=number("ThrustTargetPollSeconds",.25) then lastTargetPoll=now; refreshTargets() end
	if previewController and cachedPreviewForce then previewController:Update(dt,{Throttle=1,Boost=1,Drift=1,DriftLeft=1,DriftRight=1,HoverDust=0,Brake=0}) end
end)
]==]
candidate(thrustPreview, thrustSource)

-- All candidates compiled. Only now alter the live place.
local applied = {}
local ok, err = pcall(function()
	for _, item in ipairs(candidates) do
		item.Object.Source = item.Source
		table.insert(applied, item)
	end
	config:SetAttribute("PaintCommitOnRelease", true)
	config:SetAttribute("ThrustTargetPollSeconds", 0.25)
	config:SetAttribute("DesktopFullProfilePollingEnabled", false)
end)
if not ok then
	for index = #applied, 1, -1 do pcall(function() applied[index].Object.Source = applied[index].Before end) end
	error("Performance installer rolled back after assignment failure: " .. tostring(err))
end

assert(audit(), "Post-install audit failed")
print("[NTR UI Performance Phase 1] INSTALL PASS - full HUD polling removed, paint commits coalesced, thrust scans cached")
