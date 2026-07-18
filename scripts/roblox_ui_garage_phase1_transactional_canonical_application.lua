-- Neo Tokyo Racers - Garage Phase 1 transactional canonical application
-- NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3
-- Run once in EDIT mode. V3 keeps V2 ownership and adds canonical preview/camera/module-card refinement.

local MODE = "INSTALL" -- INSTALL or AUDIT
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

assert(not game:GetService("RunService"):IsRunning(), "Run this installer in Edit mode, not Play mode")

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

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local intro = need(controllers, "Intro", "Folder")
local bootstrap = need(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LocalScript")
local browser = need(ui, "GarageBrowserController", "ModuleScript")
local workspaceController = need(ui, "GarageWorkspaceController", "ModuleScript")
local components = need(ui, "GarageReplacementComponents", "ModuleScript")
local applicationHost = need(ui, "ModuleShopUIController", "ModuleScript")
local previewFolder = need(controllers, "Preview", "Folder")
local previewCamera = need(previewFolder, "PreviewCameraController", "ModuleScript")
local previewVehicle = need(previewFolder, "PreviewVehicleController", "ModuleScript")

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = need(need(kit, "Config", "Folder"), "UI", "Folder")
local replacement = need(config, "GarageReplacement", "Folder")

local definitions = {
	{Name="All",DisplayName="All",TargetId="ALL",SortOrder=10,ShowInBuild=false,ShowInCustomise=true},
	{Name="Cockpit",DisplayName="Cockpit",TargetId="Cockpit",SortOrder=20,ShowInBuild=false,ShowInCustomise=true},
	{Name="ThrustColour",DisplayName="Thrust Colour",TargetId="THRUST_COLOR",SortOrder=30,ShowInBuild=false,ShowInCustomise=true},
	{Name="FrontEngine",DisplayName="Front Engine",TargetId="Engine1",SortOrder=40,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearEngine",DisplayName="Rear Engine",TargetId="Engine2",SortOrder=50,ShowInBuild=true,ShowInCustomise=true},
	{Name="Stabilisers",DisplayName="Stabilisers",TargetId="Stabilisers",SortOrder=60,ShowInBuild=true,ShowInCustomise=true},
	{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBumper",DisplayName="Front Bumper",TargetId="FrontBumper",SortOrder=80,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearBumper",DisplayName="Rear Bumper",TargetId="RearBumper",SortOrder=90,ShowInBuild=true,ShowInCustomise=true},
	{Name="SidePods",DisplayName="Side Pods",TargetId="SidePods",SortOrder=100,ShowInBuild=true,ShowInCustomise=true},
	{Name="Spoiler",DisplayName="Spoiler",TargetId="RearSpoiler",SortOrder=110,ShowInBuild=true,ShowInCustomise=true},
}

local previewVehicleSource = [==[
-- NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PreviewVehicleController={}
local controllersFolder=script.Parent.Parent
local PaintClient=require(controllersFolder:WaitForChild("Core"):WaitForChild("PaintClient"))
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local PathResolver=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("PathResolver"))
local cfg=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
PreviewVehicleController.PreviewFolderName="HOVER_RACING_V2_LOCAL_PREVIEW"
local previewPadReported=false
local function number(name,fallback) local value=cfg:GetAttribute(name); if typeof(value)=="number" then return value end; local child=cfg:FindFirstChild(name); return tonumber(child and child.Value) or fallback end
function PreviewVehicleController.FindTemplateByAttribute(root,attr,value) if not root or value==nil then return nil end; for _,item in ipairs(root:GetDescendants()) do if item:GetAttribute(attr)==value then return item end end end
function PreviewVehicleController.GetPreviewRoot(workspaceRef,previewState)
	workspaceRef=workspaceRef or workspace; previewState=previewState or {}; if previewState.Root and previewState.Root.Parent then return previewState.Root end
	local existing=workspaceRef:FindFirstChild(PreviewVehicleController.PreviewFolderName); if existing then previewState.Root=existing; return existing end
	local root=Instance.new("Folder"); root.Name=PreviewVehicleController.PreviewFolderName; root.Parent=workspaceRef; previewState.Root=root; return root
end
function PreviewVehicleController.ClearRoot(root) if root then root:ClearAllChildren() end end
function PreviewVehicleController.GetSlotMount(vehicle,slotId) local root=vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename",true); local slot=root and root:FindFirstChild("SLOT_"..tostring(slotId)); return slot and slot:FindFirstChild("Mount_DoNotRename") end
function PreviewVehicleController.PivotModuleToSlot(moduleClone,mount)
	local root=moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename",true); if root then moduleClone.PrimaryPart=root end
	local moduleAttachment=moduleClone:FindFirstChild("MountAttachment",true); local mountAttachment=mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then moduleClone:PivotTo(mountAttachment.WorldCFrame*moduleAttachment.CFrame:Inverse()) elseif mount then moduleClone:PivotTo(mount.CFrame) end
end
function PreviewVehicleController.ModuleColors(profile,slotId) profile=profile or {}; return PaintClient.ModuleColors(profile,slotId,profile.CockpitColors or {},profile.ModuleColors and profile.ModuleColors[slotId] or {}) end
function PreviewVehicleController.ClearPreviewModules(state) state.PreviewModules={}; state.SelectedModuleId=nil end
local function previewCFrame(state)
	local ok,pad=pcall(PathResolver.GaragePreviewPad)
	if ok and pad and pad:IsA("BasePart") then
		if not previewPadReported then print("[NTR Garage Preview] PAD PASS "..pad:GetFullName()); previewPadReported=true end
		return pad.CFrame*CFrame.new(0,number("PreviewPadYOffset",0),0),pad
	end
	local fallback=state.Catalog and state.Catalog.PreviewPosition or Vector3.new(860,104,-1749); warn("[NTR Garage Preview] PAD FALLBACK - GaragePreviewPad unavailable")
	return CFrame.new(fallback),nil
end
function PreviewVehicleController.Build(context)
	local state=context.State; if not state then return nil,"State missing" end; local categoriesRoot=context.CategoriesRoot; if not categoriesRoot then return nil,"Categories root missing" end
	local preview=context.Preview or {}; local root=PreviewVehicleController.GetPreviewRoot(context.Workspace,preview); PreviewVehicleController.ClearRoot(root)
	local cockpitId=state.SelectedCockpit or (state.Profile and state.Profile.CurrentCockpit) or "bruiser_01"; local template=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"CockpitId",cockpitId); if not template then return nil,"Cockpit template not found: "..tostring(cockpitId) end
	local vehicle=template:Clone(); vehicle.Name="LOCAL_PREVIEW_"..tostring(cockpitId); vehicle.Parent=root; preview.Vehicle=vehicle; local primary=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true); if primary then vehicle.PrimaryPart=primary end
	local placement,pad=previewCFrame(state); vehicle:PivotTo(placement); state.PreviewPadCFrame=placement; preview.Pad=pad
	local cockpitColors={}; for key,value in pairs((state.Profile and state.Profile.CockpitColors) or {}) do cockpitColors[key]=value end; cockpitColors.FrontLights=cockpitColors.FrontLights or Color3.fromRGB(252,250,255); cockpitColors.RearLights=cockpitColors.RearLights or Color3.fromRGB(255,116,116); PaintClient.ApplyColors(vehicle,cockpitColors,true,{Profile=state.Profile})
	local thrustColor=(state.Profile and state.Profile.ThrustColor) or Color3.new(1,1,1); root:SetAttribute("ThrustColor",thrustColor); root:SetAttribute("ForceThrustPreview",state.ThrustPreviewActive==true); vehicle:SetAttribute("ThrustColor",thrustColor)
	local installedRoot=vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder"); installedRoot.Name="INSTALLED_MODULES_Runtime"; installedRoot.Parent=vehicle; installedRoot:ClearAllChildren()
	local modulesToShow={}; for slotId,moduleId in pairs((state.Profile and state.Profile.InstalledModules) or {}) do modulesToShow[slotId]=moduleId end; for slotId,moduleId in pairs(state.PreviewModules or {}) do modulesToShow[slotId]=moduleId end
	for slotId,moduleId in pairs(modulesToShow) do local moduleTemplate=PreviewVehicleController.FindTemplateByAttribute(categoriesRoot,"ModuleId",moduleId); local mount=PreviewVehicleController.GetSlotMount(vehicle,slotId); if moduleTemplate and mount then local clone=moduleTemplate:Clone(); clone.Name="PREVIEW_"..tostring(slotId).."_"..moduleTemplate.Name; clone.Parent=installedRoot; PreviewVehicleController.PivotModuleToSlot(clone,mount); local neonOwned=(state.Profile and state.Profile.NeonOwned) or {}; PaintClient.ApplyColors(clone,PreviewVehicleController.ModuleColors(state.Profile,slotId),neonOwned[slotId]==true or state.PreviewNeonSlot==slotId,{Profile=state.Profile}) end end
	local boxCFrame=vehicle:GetBoundingBox(); state.TargetFocus=boxCFrame.Position; preview.Focus=boxCFrame.Position; return vehicle,nil
end
return PreviewVehicleController
]==]

local previewCameraSource = [==[
-- NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3
-- NTR_GARAGE_PREVIEW_CAMERA_STATE_INIT_REPAIR_V3
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Players=game:GetService("Players")
local PreviewCameraController={}
local cfg=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
PreviewCameraController.DefaultFocus=Vector3.new(860,104,-1749); PreviewCameraController.DefaultYaw=math.rad(180); PreviewCameraController.DefaultPitch=math.rad(-12); PreviewCameraController.DefaultDistance=24.3; PreviewCameraController.SectionDistance=33
PreviewCameraController.YawBySlot={FrontBumper=math.rad(180),RearBumper=0,RearSpoiler=0,Boost=0,Engine1=math.rad(135),Engine2=math.rad(45),SidePods=math.rad(90),Stabilisers=math.rad(90)}
local connections={}
local fadeFrame=nil
local fadeTween=nil
local transitionSerial=0
local function number(name,fallback) local value=cfg:GetAttribute(name); if typeof(value)=="number" then return value end; local child=cfg:FindFirstChild(name); return tonumber(child and child.Value) or fallback end
local function boolean(name,fallback) local value=cfg:GetAttribute(name); if typeof(value)=="boolean" then return value end; local child=cfg:FindFirstChild(name); if child and child:IsA("BoolValue") then return child.Value end; return fallback end
function PreviewCameraController.WrapAngle(angle) return math.atan2(math.sin(angle),math.cos(angle)) end
function PreviewCameraController.LerpAngle(a,b,t) return a+PreviewCameraController.WrapAngle(b-a)*t end
function PreviewCameraController.EnsureState(state)
	state.CameraFocus=state.CameraFocus or state.TargetFocus or PreviewCameraController.DefaultFocus; state.TargetFocus=state.TargetFocus or state.CameraFocus; state.CameraYaw=state.CameraYaw or PreviewCameraController.DefaultYaw; state.TargetYaw=state.TargetYaw or state.CameraYaw; state.CameraPitch=state.CameraPitch or PreviewCameraController.DefaultPitch; state.TargetPitch=state.TargetPitch or state.CameraPitch; state.CameraDistance=state.CameraDistance or PreviewCameraController.DefaultDistance; state.TargetDistance=state.TargetDistance or state.CameraDistance; return state
end
local function ensureFade(parent)
	if not parent then return nil end; if fadeFrame and fadeFrame.Parent==parent then return fadeFrame end; if fadeFrame then fadeFrame:Destroy() end
	fadeFrame=Instance.new("Frame"); fadeFrame.Name="GarageCameraFade"; fadeFrame.BackgroundColor3=Color3.new(0,0,0); fadeFrame.BackgroundTransparency=1; fadeFrame.BorderSizePixel=0; fadeFrame.Size=UDim2.fromScale(1,1); fadeFrame.Visible=false; fadeFrame.Active=false; fadeFrame.ZIndex=90; fadeFrame.Parent=parent; return fadeFrame
end
local function tweenFade(frame,transparency,duration,serial,onComplete)
	if fadeTween then fadeTween:Cancel() end; fadeTween=TweenService:Create(frame,TweenInfo.new(math.max(.01,duration),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=transparency}); fadeTween:Play(); fadeTween.Completed:Once(function() if serial~=transitionSerial then return end; fadeTween=nil; if onComplete then onComplete() end end)
end
function PreviewCameraController.CancelTransition()
	transitionSerial+=1; if fadeTween then fadeTween:Cancel(); fadeTween=nil end; if fadeFrame then local frame=fadeFrame; frame.Visible=true; local serial=transitionSerial; tweenFade(frame,1,.12,serial,function() frame.Visible=false end) end
end
local function transition(state,targets,context)
	PreviewCameraController.EnsureState(state); state.TargetFocus=targets.Focus or state.TargetFocus; state.TargetYaw=targets.Yaw or state.TargetYaw; state.TargetPitch=targets.Pitch or state.TargetPitch; state.TargetDistance=targets.Distance or state.TargetDistance
	if not boolean("PreviewCameraFadeEnabled",true) then return end; local frame=ensureFade(context and context.FadeParent); if not frame then return end
	transitionSerial+=1; local serial=transitionSerial; if fadeTween then fadeTween:Cancel() end; frame.Visible=true; local opacity=math.clamp(number("PreviewCameraFadeOpacity",.68),0,1); tweenFade(frame,1-opacity,number("PreviewCameraFadeOutSeconds",.28),serial,function() task.delay(math.max(0,number("PreviewCameraFadeHoldSeconds",.05)),function() if serial~=transitionSerial then return end; tweenFade(frame,1,number("PreviewCameraFadeInSeconds",.46),serial,function() frame.Visible=false end) end) end)
end
function PreviewCameraController.SetPreviewFocus(state,focus) PreviewCameraController.EnsureState(state); state.TargetFocus=focus or state.TargetFocus end
function PreviewCameraController.SetCameraSection(state,slotId,context) transition(state,{Yaw=PreviewCameraController.YawBySlot[slotId] or PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.SectionDistance},context) end
function PreviewCameraController.Reset(state,focus,context) transition(state,{Focus=focus or state.TargetFocus or PreviewCameraController.DefaultFocus,Yaw=PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.DefaultDistance},context) end
local function pointerBlocked(position)
	for _,object in ipairs(playerGui:GetGuiObjectsAtPosition(position.X,position.Y)) do local current=object; while current and not current:IsA("ScreenGui") do if current~=fadeFrame and (current:IsA("GuiButton") or current:IsA("ScrollingFrame") or current.Active) then return true end; current=current.Parent end end; return false
end
function PreviewCameraController.UnbindInput() for _,connection in ipairs(connections) do connection:Disconnect() end; table.clear(connections) end
function PreviewCameraController.BindInput(context)
	PreviewCameraController.UnbindInput(); local state=context.State; local dragging=false; local dragInput,lastPointer; local pinchScale
	local function active() return state and state.GarageCameraActive~=false and (not context.IsActive or context.IsActive()) end
	table.insert(connections,UserInputService.InputBegan:Connect(function(input,processed) if processed or not active() then return end; local kind=input.UserInputType; if (kind==Enum.UserInputType.MouseButton2 or kind==Enum.UserInputType.Touch) and not pointerBlocked(input.Position) then dragging=true; dragInput=input; lastPointer=input.Position; PreviewCameraController.CancelTransition() end end))
	table.insert(connections,UserInputService.InputEnded:Connect(function(input) if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=false; dragInput=nil; lastPointer=nil end end))
	table.insert(connections,UserInputService.InputChanged:Connect(function(input,processed)
		if not active() then return end; if input.UserInputType==Enum.UserInputType.MouseWheel and not processed then PreviewCameraController.EnsureState(state); state.TargetDistance=math.clamp(state.TargetDistance-input.Position.Z*number("PreviewCameraWheelZoom",2.4),number("PreviewCameraMinDistance",16),number("PreviewCameraMaxDistance",46)); return end
		if not dragging or not lastPointer then return end; if input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput then local delta=input.Position-lastPointer; state.TargetYaw-=delta.X*number("PreviewCameraYawSensitivity",.006); state.TargetPitch=math.clamp(state.TargetPitch-delta.Y*number("PreviewCameraPitchSensitivity",.004),math.rad(number("PreviewCameraMinPitchDegrees",-45)),math.rad(number("PreviewCameraMaxPitchDegrees",10))); lastPointer=input.Position end
	end))
	table.insert(connections,UserInputService.TouchPinch:Connect(function(_,scale,_,inputState,processed) if processed or not active() then return end; if inputState==Enum.UserInputState.Begin then pinchScale=scale; PreviewCameraController.CancelTransition() elseif inputState==Enum.UserInputState.Change and pinchScale then PreviewCameraController.EnsureState(state); local delta=scale-pinchScale; state.TargetDistance=math.clamp(state.TargetDistance-delta*number("PreviewCameraPinchZoom",10),number("PreviewCameraMinDistance",16),number("PreviewCameraMaxDistance",46)); pinchScale=scale else pinchScale=nil end end))
end
function PreviewCameraController.Update(context,dt)
	local state=context.State; if not state or context.IsDriving==true or state.GarageCameraActive==false or (context.Gui and context.Gui.Enabled==false) then return false end; local workspaceRef=context.Workspace or workspace; local camera=context.Camera or workspaceRef.CurrentCamera; if not camera then return false end
	PreviewCameraController.EnsureState(state); camera.CameraType=Enum.CameraType.Scriptable; local t=math.clamp((dt or 0)*(context.LerpSpeed or number("PreviewCameraLerpSpeed",4.5)),0,1); state.CameraFocus=state.CameraFocus:Lerp(state.TargetFocus,t); state.CameraYaw=PreviewCameraController.LerpAngle(state.CameraYaw,state.TargetYaw,t); state.CameraPitch+=(state.TargetPitch-state.CameraPitch)*t; state.CameraDistance+=(state.TargetDistance-state.CameraDistance)*t; local offset=CFrame.Angles(0,state.CameraYaw,0)*CFrame.Angles(state.CameraPitch,0,0)*Vector3.new(0,0,state.CameraDistance); camera.CFrame=CFrame.lookAt(state.CameraFocus+offset,state.CameraFocus); return true
end
return PreviewCameraController
]==]

compile("PreviewVehicleController V3",previewVehicleSource)
compile("PreviewCameraController V3",previewCameraSource)

local applicationSource = [==[
-- NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V1
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer; local kit=RS:WaitForChild("NeoTokyoRacers"); local categoriesRoot=kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local uiFolder=script.Parent; local intro=uiFolder.Parent:WaitForChild("Intro"); local previewFolder=uiFolder.Parent:WaitForChild("Preview")
local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local Artwork=require(uiFolder:WaitForChild("GarageModuleArtworkRegistry")); local Adapter=require(uiFolder:WaitForChild("GarageActionAdapter"))
local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController"))
local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"); local Calculator=require(performance:WaitForChild("VehiclePerformanceCalculator")); local Racing=require(kit.Shared.Modules.UI.RacingUIComponents)
local State={Stage="Closed",ShopMode="Dealership",Catalog=nil,Profile=nil,CategoryId="bruiser",BrowseAll=true,SelectedCockpit=nil,SelectedVehicleId=nil,SelectedSlot="Engine1",SelectedModuleId=nil,SelectedModuleInstanceId=nil,ModuleMode="Slots",ModuleOptionMode=nil,CustomizeTarget="ALL",CustomizeMode="Colour",SelectedColorChannel="Primary",PreviewModules={},GarageCameraActive=false}
local action=Adapter.new(State); local browser=Browser.new(); local workspaceUI=WorkspaceUI.new(); local preview={}; local active=false; local modal
local tierColours={E=Color3.fromRGB(132,142,145),D=Color3.fromRGB(105,190,129),C=Color3.fromRGB(74,204,211),B=Color3.fromRGB(82,137,235),A=Color3.fromRGB(244,188,65),S=Color3.fromRGB(236,92,168)}
local function tierColor(tier) return tierColours[tostring(tier)] or Color3.fromRGB(43,225,218) end
local function cloneNumbers(source) local out={}; for k,v in pairs(source or {}) do if typeof(v)=="number" then out[k]=v end end; return out end
local function allCategories() return (State.Catalog and State.Catalog.Categories) or {} end
local function categoryById(id) for _,c in ipairs(allCategories()) do if tostring(c.CategoryId)==tostring(id) then return c end end end
local function currentCategory() return categoryById(State.CategoryId) or allCategories()[1] end
local function combinedCategory() local c={CategoryId="__ALL",DisplayName="ALL",Cockpits={},Slots={}}; for _,source in ipairs(allCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do local copy={}; for k,v in pairs(cockpit) do copy[k]=v end; copy.NTRCategoryId=source.CategoryId; table.insert(c.Cockpits,copy) end end; return c end
local function browserCategory() return State.BrowseAll and combinedCategory() or currentCategory() end
local function cockpit(id,category) for _,c in ipairs((category or currentCategory()).Cockpits or {}) do if tostring(c.CockpitId)==tostring(id) then return c end end end
local function moduleById(id,category) for _,list in pairs(((category or currentCategory()).Modules) or {}) do for _,m in ipairs(list) do if tostring(m.ModuleId)==tostring(id) then return m end end end end
local function slots() local result={}; for _,s in ipairs((currentCategory() and currentCategory().Slots) or {}) do table.insert(result,s) end; table.sort(result,function(a,b) return (tonumber(a.Order) or 99)<(tonumber(b.Order) or 99) end); return result end
local function slot(id) for _,s in ipairs(slots()) do if tostring(s.SlotId)==tostring(id) then return s end end end
local function enginePosition(m) local explicit=tostring(m and m.EnginePosition or ""); if explicit~="" then return explicit end; if m and (m.RearEngine==true or m.ModuleFolder=="Engines_B" or string.find(tostring(m.ModuleId),"ENGINE_B",1,true)) then return "Rear" end; return "Front" end
local function moduleFits(m,s) if not m or not s or tostring(m.ModuleType)~=tostring(s.ModuleType) then return false end; if s.SlotId=="Engine1" then return enginePosition(m)~="Rear" end; if s.SlotId=="Engine2" then return enginePosition(m)=="Rear" end; return not s.AllowedModuleFolder or s.AllowedModuleFolder=="" or tostring(m.ModuleFolder)==tostring(s.AllowedModuleFolder) end
local function modulesForSlot(id) local s=slot(id); local result={}; if not s then return result end; for _,m in ipairs(((currentCategory().Modules or {})[s.ModuleType]) or {}) do if moduleFits(m,s) then table.insert(result,m) end end; table.sort(result,function(a,b) return tostring(a.DisplayName or a.ModuleId)<tostring(b.DisplayName or b.ModuleId) end); return result end
local function ownedCockpitCount(id) local n=0; for _,item in pairs((State.Profile and State.Profile.OwnedCockpitInstances) or {}) do if tostring(item.TemplateId)==tostring(id) then n+=1 end end; return n end
local function capacity() local g=(State.Profile and State.Profile.Garage) or {}; return tonumber(g.OwnedVehicleCount) or 0,tonumber(g.Capacity) or 2 end
local function installedForSlot(id) local p=State.Profile or {}; local vehicle=p.CurrentVehicleId and p.Vehicles and p.Vehicles[p.CurrentVehicleId]; local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[id]; local instance=instanceId and p.OwnedModuleInstances and p.OwnedModuleInstances[instanceId]; return (instance and instance.TemplateId) or (p.InstalledModules and p.InstalledModules[id]),instanceId end
local function coreReady() local e1=installedForSlot("Engine1"); local e2=installedForSlot("Engine2"); local s=installedForSlot("Stabilisers"); local b=installedForSlot("Boost"); local function yes(v) return v~=nil and tostring(v)~="" end; return yes(e1) or yes(e2),yes(s),yes(b) end
local function defaults(c) local raw=cloneNumbers(c); local cat=categoryById(c.NTRCategoryId or State.CategoryId); for _,id in ipairs({c.DefaultFrontEngineModuleId or c.DefaultEngineModuleId,c.DefaultRearEngineModuleId or c.DefaultEngineModuleId,c.DefaultStabilisersModuleId,c.DefaultBoostModuleId}) do local m=moduleById(id,cat); if m then for _,name in ipairs({"TopSpeed","Acceleration","Handling","Drift","Braking","Weight","Boost"}) do raw[name]=(raw[name] or 0)+(tonumber(m[name]) or 0) end end end; return raw end
local function performanceForCockpit(c) return Calculator.CalculateLegacy(defaults(c)) end
local function currentPerformance()
	local raw=cloneNumbers(State.Profile and State.Profile.TotalStats); local base=Calculator.CalculateLegacy(raw)
	if State.Stage=="Build" and State.ModuleMode=="Options" and State.SelectedModuleId then local installed=moduleById(installedForSlot(State.SelectedSlot)); local selected=moduleById(State.SelectedModuleId); for _,name in ipairs({"TopSpeed","Acceleration","Handling","Drift","Braking","Weight","Boost"}) do if installed then raw[name]=(raw[name] or 0)-(tonumber(installed[name]) or 0) end; if selected then raw[name]=(raw[name] or 0)+(tonumber(selected[name]) or 0) end end end
	return Calculator.CalculateLegacy(raw),base
end
local function imageValue(value) local text=tostring(value or ""); if text=="" then return "" end; if tonumber(text) then return "rbxassetid://"..text end; return text end
local function cockpitImage(c) for _,k in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local v=imageValue(c and c[k]); if v~="" then return v end end; local id=tostring(c and c.CockpitId or ""); for _,o in ipairs(categoriesRoot:GetDescendants()) do if o:IsA("Model") and tostring(o:GetAttribute("CockpitId") or o.Name)==id then for _,k in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local v=imageValue(o:GetAttribute(k)); if v~="" then return v end; local child=o:FindFirstChild(k); if child and child:IsA("StringValue") then v=imageValue(child.Value); if v~="" then return v end end end end end; return "" end
local function clearPreview() if preview.Root and preview.Root.Parent then preview.Root:Destroy() end; table.clear(preview); State.PreviewModules={}; State.GarageCameraActive=false end
local function buildPreview() State.GarageCameraActive=true; local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace}); if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end end
local function section(id) PreviewCamera.SetCameraSection(State,id) end
local function hideAll() browser:Hide(); workspaceUI:Hide(); if modal then modal:Destroy(); modal=nil end end
local function auditOwnership(label)
	task.defer(function()
		RunService.Heartbeat:Wait()
		local legacy=player.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
		local canonical=player.PlayerGui:FindFirstChild("CanonicalGarageGui")
		local visibleRoot=(browser.Root.Visible and browser.Root) or (workspaceUI.Root.Visible and workspaceUI.Root)
		if canonical and canonical.Enabled and visibleRoot and not (legacy and legacy.Enabled) then print("[NTR Garage Phase 1 Runtime] OWNERSHIP PASS "..tostring(label)) else warn("[NTR Garage Phase 1 Runtime] OWNERSHIP FAIL "..tostring(label).." canonical="..tostring(canonical and canonical.Enabled).." root="..tostring(visibleRoot and visibleRoot.Name).." legacy="..tostring(legacy and legacy.Enabled)) end
	end)
end
local function closeCamera() clearPreview(); local camera=Workspace.CurrentCamera; local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); if camera then camera.CameraType=Enum.CameraType.Custom; if h then camera.CameraSubject=h end end end
local function introEvent(name) local e=intro:FindFirstChild(name); if e and not e:IsA("BindableEvent") then e:Destroy(); e=nil end; if not e then e=Instance.new("BindableEvent"); e.Name=name; e.Parent=intro end; return e end
local function fire(name) local e=uiFolder:FindFirstChild(name); if e and e:IsA("BindableEvent") then e:Fire() end end
local function message(text) if workspaceUI.Root.Visible then workspaceUI:Message(text) elseif browser.Root.Visible then browser.Subtitle.Text=tostring(text) end end
local function modalBase(title)
	if modal then modal:Destroy() end; local host=Shared.CanonicalHost(); modal=Instance.new("Frame"); modal.Name="CanonicalGarageModal"; modal.BackgroundColor3=Color3.new(0,0,0); modal.BackgroundTransparency=.28; modal.Size=UDim2.fromOffset(1600,900); modal.ZIndex=100; modal.Parent=host.Canvas
	local panel=Shared.Panel(modal,"Panel",{StrokeColor=Racing.Colour("ElectricBlue"),NoGlow=true}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(620,420); panel.ZIndex=101
	Racing.Label(panel,{Text=title,Position=UDim2.fromOffset(18,12),Size=UDim2.new(1,-76,0,34),TextSize=18,Role="Heading"}).ZIndex=102; local x=Racing.Button(panel,{Text="X",Position=UDim2.new(1,-50,0,10),Size=UDim2.fromOffset(38,32),Color=Color3.fromRGB(166,61,70)}); x.ZIndex=103; x.Activated:Connect(function() modal:Destroy(); modal=nil end); return panel
end
local function showCash() local p=modalBase("GET MORE CASH"); local l=Racing.Label(p,{Text="Cash packs are not configured yet.",Position=UDim2.fromOffset(24,80),Size=UDim2.new(1,-48,0,80),TextSize=14,XAlignment=Enum.TextXAlignment.Center}); l.ZIndex=102 end
local function showProperties()
	local p=modalBase("GARAGE PROPERTIES"); local catalog=require(kit.Shared.Modules.Data:WaitForChild("GaragePropertyCatalog")); local list=Instance.new("ScrollingFrame"); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=4; list.Position=UDim2.fromOffset(18,58); list.Size=UDim2.new(1,-36,1,-76); list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.fromOffset(0,0); list.ZIndex=102; list.Parent=p; local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,8); layout.Parent=list
	for _,property in ipairs(catalog.List()) do local owned=(State.Profile.Garage.OwnedGarageProperties or {})[property.PropertyId]~=nil; local b=Racing.Button(list,{Text=(owned and "OWNED - " or ("BUY $"..tostring(property.Price or 0).." - "))..tostring(property.DisplayName),Size=UDim2.new(1,-8,0,48),Color=owned and Racing.Colour("PanelSoft") or Racing.Colour("PanelBlue")}); b.ZIndex=103; b.AutoButtonColor=not owned; if not owned then b.Activated:Connect(function() local r=action:Call("BuyGarageProperty",{PropertyId=property.PropertyId}); if not r.Success then message(r.Message) end; showProperties() end) end end
end
local function stats(parent) local now,base=currentPerformance(); workspaceUI:DrawPerformance(parent,now,base,tierColor) end
local renderBrowser,renderPaint,renderBuild,renderCustomise
local function common(title) local owned,cap=capacity(); return {Title=title,Cash=State.Profile and State.Profile.Cash or 0,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",RenderStats=stats,OnCash=showCash,OnCapacity=showProperties,ExitVisible=false,Legacy={}} end
renderBrowser=function()
	State.Stage="Browser"; hideAll(); local owned,cap=capacity(); browser:Show({Mode=State.ShopMode,State=State,Category=browserCategory(),Cash=State.Profile.Cash,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",AutoPreview=State.NoPreviewYet,Legacy={},ResolveImage=cockpitImage,ResolvePerformance=performanceForCockpit,TierColor=tierColor,OwnedCount=ownedCockpitCount,
	OnCategory=function(id,all) State.BrowseAll=all==true; if id then State.CategoryId=id end; State.SelectedVehicleId=nil; State.NoPreviewYet=true; renderBrowser() end,
	OnSelect=function(row) State.SelectedCockpit=row.CockpitId; State.SelectedVehicleId=row.VehicleId; State.CategoryId=row.CategoryId or State.CategoryId; State.NoPreviewYet=false; buildPreview(); PreviewCamera.Reset(State,State.TargetFocus); renderBrowser() end,
	OnPrimary=function(row) local r;if State.ShopMode=="Customisation" then r=action:Call("SelectVehicleInstance",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}) else r=action:Call("BuyCockpitInstance",{CockpitId=row.CockpitId,CategoryId=row.CategoryId}) end; if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; buildPreview(); renderPaint() end,
	OnExit=function() action:Session("End",{ReturnToEntry=true}); active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end,OnCash=showCash,OnCapacity=showProperties})
end
renderPaint=function() State.Stage="Paint"; browser:Hide(); local c=common("Paint Cockpit"); c.Subtitle="Choose primary, secondary, and detail colours."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Build Modules"; c.ColorChannels={"Primary","Secondary","Detail"}; c.SelectedChannel=State.SelectedColorChannel; c.Colors=State.Profile.CockpitColors or {}; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderPaint() end; c.OnColor=function(ch,color) local r=action:Call("SetCockpitColor",{Channel=ch,Color=color}); if r.Success then buildPreview() else message(r.Message) end end; c.OnNext=function() State.ModuleMode="Slots"; State.ModuleOptionMode=nil; section("Engine1"); renderBuild() end; workspaceUI:Show(c) end
local function ownedRecords(s) local result={}; for id,item in pairs(State.Profile.OwnedModuleInstances or {}) do local m=moduleById(item.TemplateId); if moduleFits(m,s) then table.insert(result,{Id=id,Item=item,Module=m}) end end; table.sort(result,function(a,b) return tostring(a.Module.DisplayName)<tostring(b.Module.DisplayName) end); return result end
renderBuild=function()
	State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or "Preview, then buy or equip."; c.NextText="Customise"; c.ShowLeft=State.ModuleMode~="Slots"; c.LeftItems={}; c.Cards={}
	if State.ModuleMode=="Slots" then for _,art in ipairs(Artwork.ForPage("Build")) do local s=slot(art.TargetId); if s then local installed=installedForSlot(s.SlotId); table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() State.SelectedSlot=s.SlotId; State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; State.SelectedModuleId=nil; section(s.SlotId); renderBuild() end}) end end
	else
		for _,mode in ipairs({"Owned","Buy"}) do table.insert(c.LeftItems,{Id=mode,Text=mode.." Modules",Selected=State.ModuleOptionMode==mode,OnSelect=function() State.ModuleOptionMode=mode; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; buildPreview(); renderBuild() end}) end
		local s=slot(State.SelectedSlot); local installed,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then for _,record in ipairs(ownedRecords(s)) do local selected=State.SelectedModuleInstanceId==record.Id; local equipped=installedInstance==record.Id; local inUse=record.Item.EquippedVehicleId and record.Item.EquippedVehicleId~="" and record.Item.EquippedVehicleId~=State.Profile.CurrentVehicleId; table.insert(c.Cards,{Id=record.Id,ImageKey=State.SelectedSlot,DisplayName=record.Module.DisplayName or record.Module.ModuleId,Badge=equipped and "EQUIPPED" or (inUse and "IN USE" or "OWNED"),BadgeColor=equipped and tierColor("S") or tierColor("C"),Selected=selected,ActionText=selected and not equipped and not inUse and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=record.Module.ModuleId; State.SelectedModuleInstanceId=record.Id; State.PreviewModules={[State.SelectedSlot]=record.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() local r=action:Call("EquipModuleInstance",{ModuleInstanceId=record.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if r.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(r.Message) end end}) end
		else for _,m in ipairs(modulesForSlot(State.SelectedSlot)) do local sourceCockpit=tostring(m.SourceCockpitId or ""); local locked=sourceCockpit~="" and ownedCockpitCount(sourceCockpit)==0; local selected=State.SelectedModuleId==m.ModuleId; table.insert(c.Cards,{Id=m.ModuleId,ImageKey=State.SelectedSlot,DisplayName=m.DisplayName or m.ModuleId,Badge=locked and "LOCKED" or ("$"..tostring(m.Price or 0)),BadgeColor=locked and Color3.fromRGB(90,90,90) or tierColor("A"),Selected=selected,ActionText=selected and not locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=m.ModuleId; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=m.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() local before=State.Profile; local buy=action:Call("BuyModuleInstance",{ModuleId=m.ModuleId}); if not buy.Success then message(buy.Message); return end; local newId=action:NewModuleId(before,m.ModuleId); if not newId then message("Bought module, but its new copy was not found."); return end; local equip=action:Call("EquipModuleInstance",{ModuleInstanceId=newId,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if equip.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(equip.Message) end end}) end end
	end
	c.OnBack=function() if State.ModuleMode=="Options" then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; State.PreviewModules={}; buildPreview(); renderBuild() else renderPaint() end end; c.OnNext=function() local e,s,b=coreReady(); if not(e and s and b) then message("Equip one engine, stabilisers, and boost first."); return end; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; renderCustomise() end; workspaceUI:Show(c)
end
local function installedModule() local id=installedForSlot(State.CustomizeTarget); return id,moduleById(id) end
local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end; return {"Primary","Secondary","Detail","Neon"} end
renderCustomise=function()
	State.Stage="Customise"; local target=State.CustomizeTarget; local c=common("Customise"); c.Subtitle="Tune installed modules, change colours, or unlock lights."; c.NextText="Start Driving"; c.LeftItems={}; c.Cards={}
	for _,art in ipairs(Artwork.ForPage("Customise")) do local id=art.TargetId; if id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR" or installedForSlot(id) then table.insert(c.LeftItems,{Id=id,Text=art.DisplayName,Selected=target==id,OnSelect=function() State.CustomizeTarget=id; State.CustomizeMode=(id=="ALL" or id=="THRUST_COLOR") and "Colour" or "Overview"; if id~="ALL" and id~="Cockpit" and id~="THRUST_COLOR" then section(id) end; renderCustomise() end}) end end
	if target=="ALL" or target=="THRUST_COLOR" or State.CustomizeMode=="Colour" then local channels=colourChannels(target); local colours={}; for _,ch in ipairs(channels) do if target=="THRUST_COLOR" then colours[ch]=State.Profile.ThrustColor elseif target=="Cockpit" or target=="ALL" then colours[ch]=(State.Profile.CockpitColors or {})[ch] else colours[ch]=((State.Profile.ModuleColors or {})[target] or {})[ch] end; colours[ch]=colours[ch] or Color3.new(1,1,1) end; c.ColorChannels=channels; c.SelectedChannel=State.SelectedColorChannel or channels[1]; c.Colors=colours; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderCustomise() end; c.OnColor=function(ch,color) local r;if target=="THRUST_COLOR" then r=action:Call("SetThrustColor",{Color=color}) elseif target=="ALL" then r=action:Call("SetModuleColor",{SlotId="ALL",Channel=ch,Color=color}); if ch~="Neon" then action:Call("SetCockpitColor",{Channel=ch,Color=color}) end elseif target=="Cockpit" then r=action:Call("SetCockpitColor",{Channel=ch,Color=color}) else r=action:Call("SetModuleColor",{SlotId=target,Channel=ch,Color=color}) end; if r and r.Success then buildPreview() else message(r and r.Message) end end
	elseif State.CustomizeMode=="Cosmetics" then local id=installedForSlot(target); local owned=State.Profile.NeonOwned and State.Profile.NeonOwned[target]; table.insert(c.Cards,{Id="Neon",ImageKey=target,DisplayName="Neon Lights",Badge=owned and "OWNED" or "$5000",BadgeColor=owned and tierColor("S") or tierColor("A"),Selected=State.PreviewNeonSlot==target,ActionText=not owned and State.PreviewNeonSlot==target and "BUY" or nil,OnSelect=function() State.PreviewNeonSlot=target; buildPreview(); renderCustomise() end,OnAction=function() local r=action:Call("BuyNeon",{SlotId=target}); State.PreviewNeonSlot=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
	elseif State.CustomizeMode=="Upgrades" then local moduleId,m=installedModule(); for _,u in ipairs((m and m.Upgrades) or {}) do local level=math.floor(tonumber(((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {})[u.UpgradeId]) or 0); local max=tonumber(u.MaxLevel) or 3; local price=math.floor((tonumber(u.BasePrice) or 0)*((tonumber(u.PriceMultiplier) or 1)^level)); local selected=State.PreviewUpgradeId==u.UpgradeId; table.insert(c.Cards,{Id=u.UpgradeId,ImageKey=target,DisplayName=u.DisplayName or u.UpgradeId,Badge="LVL "..level.."/"..max,BadgeColor=level>=max and tierColor("S") or tierColor("A"),Selected=selected,ActionText=selected and level<max and ("BUY $"..price) or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end}) end
	else table.insert(c.Cards,{Id="Colour",ImageKey=target,DisplayName=target=="Cockpit" and "Change Colour" or "Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end}); if target~="Cockpit" then table.insert(c.Cards,{Id="Cosmetics",ImageKey=target,DisplayName="Cosmetics",OnSelect=function() State.CustomizeMode="Cosmetics"; renderCustomise() end}); table.insert(c.Cards,{Id="Performance",ImageKey=target,DisplayName="Performance",OnSelect=function() State.CustomizeMode="Upgrades"; renderCustomise() end}) end end
	c.OnBack=function() if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else State.ModuleMode="Slots"; renderBuild() end end
	c.OnNext=function() action:Session("End",{ReturnToEntry=false}); local r=action:Call("SpawnVehicle",{}); if not r.Success then message(r.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end; buildPreview(); workspaceUI:Show(c)
end
local function open(mode)
	if active then return end; local result=action:Refresh(); if not result.Success then warn("[NTR Canonical Garage] "..tostring(result.Message)); action:Session("End",{ReturnToEntry=true}); return end
	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true
	if mode=="DriveIn" then local vehicleId=State.Profile.CurrentVehicleId; action:Call("DespawnVehicle",{}); fire("FreeRoamVehicleExited"); if vehicleId then action:Call("SelectVehicleInstance",{VehicleId=vehicleId}) end; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderPaint() else renderBrowser() end
	auditOwnership(mode)
end
for name,mode in pairs({OpenGarageFromIntro="Dealership",OpenOwnedCockpitCustomisation="Customisation",OpenDrivingVehicleCustomisation="DriveIn"}) do introEvent(name).Event:Connect(function() open(mode) end) end
RunService.RenderStepped:Connect(function(dt) if active and State.GarageCameraActive then PreviewCamera.Update({State=State,Workspace=Workspace,Camera=Workspace.CurrentCamera,Gui=Shared.CanonicalHost().Gui,IsDriving=false},dt) end end)
task.defer(function() local ok,failures=Artwork.Audit(); if not ok then warn("[NTR Canonical Garage] ARTWORK FAIL "..table.concat(failures," | ")) else print("[NTR Canonical Garage] DEPENDENCY PASS") end end)
]==]

local embeddedAdapter = [==[
local garageInvoke=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local sessionRequest=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local Adapter={}; Adapter.__index=Adapter
function Adapter.new(state) return setmetatable({State=state,Busy=false},Adapter) end
function Adapter:Call(actionName,payload)
	if self.Busy then return {Success=false,Message="Please wait."} end
	self.Busy=true; local ok,result=pcall(function() return garageInvoke:InvokeServer(actionName,payload or {}) end); self.Busy=false
	if not ok or typeof(result)~="table" then return {Success=false,Message="Garage server did not respond."} end
	if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end; return result
end
function Adapter:Refresh() return self:Call("GetInitial",{}) end
function Adapter:Session(actionName,payload) local ok,result=pcall(function() return sessionRequest:InvokeServer(actionName,payload or {}) end); return ok and result or {Success=false,Message="Garage session did not respond."} end
function Adapter:NewModuleId(before,moduleId)
	local old={}; for id in pairs((before and before.OwnedModuleInstances) or {}) do old[id]=true end
	for id,item in pairs((self.State.Profile and self.State.Profile.OwnedModuleInstances) or {}) do if not old[id] and tostring(item.TemplateId)==tostring(moduleId) then return id end end
end
]==]

local moduleApplicationSource = replaceOnce(applicationSource,
	[[local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local Artwork=require(uiFolder:WaitForChild("GarageModuleArtworkRegistry")); local Adapter=require(uiFolder:WaitForChild("GarageActionAdapter"))]],
	[[local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents"))
]] .. embeddedAdapter, "application embedded adapter")
moduleApplicationSource = replaceOnce(moduleApplicationSource, [[Artwork.ForPage("Build")]], [[workspaceUI:ArtworkDefinitions("Build")]], "application build artwork")
moduleApplicationSource = replaceOnce(moduleApplicationSource, [[Artwork.ForPage("Customise")]], [[workspaceUI:ArtworkDefinitions("Customise")]], "application customise artwork")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[task.defer(function() local ok,failures=Artwork.Audit(); if not ok then warn("[NTR Canonical Garage] ARTWORK FAIL "..table.concat(failures," | ")) else print("[NTR Canonical Garage] DEPENDENCY PASS") end end)]],
	[[task.defer(function() print("[NTR Canonical Garage] DEPENDENCY PASS existing-instance application") end)]], "application dependency audit")
moduleApplicationSource = replaceOnce(moduleApplicationSource,"NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V1","NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3","application V3 marker")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[local function section(id) PreviewCamera.SetCameraSection(State,id) end]],
	[[local function cameraTransition() return {FadeParent=Shared.CanonicalHost().Canvas} end
local function section(id) PreviewCamera.SetCameraSection(State,id,cameraTransition()) end]], "application camera section transition")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[buildPreview(); PreviewCamera.Reset(State,State.TargetFocus); renderBrowser()]],
	[[buildPreview(); PreviewCamera.Reset(State,State.TargetFocus,cameraTransition()); renderBrowser()]], "application cockpit transition")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[==[local function ownedRecords(s) local result={}; for id,item in pairs(State.Profile.OwnedModuleInstances or {}) do local m=moduleById(item.TemplateId); if moduleFits(m,s) then table.insert(result,{Id=id,Item=item,Module=m}) end end; table.sort(result,function(a,b) return tostring(a.Module.DisplayName)<tostring(b.Module.DisplayName) end); return result end]==],
	[==[local function moduleLineage(m)
	local category=currentCategory() or {}; local source=m and cockpit(m.SourceCockpitId,category); return string.upper(tostring(category.DisplayName or category.CategoryId or "VEHICLE")),tostring(source and (source.DisplayName or source.CockpitId) or "UNIVERSAL")
end
local function ownedModuleCount(moduleId) local count=0; for _,item in pairs(State.Profile.OwnedModuleInstances or {}) do if tostring(item.TemplateId)==tostring(moduleId) then count+=1 end end; return count end
local function ownedGroups(s)
	local keyed={}; for id,item in pairs(State.Profile.OwnedModuleInstances or {}) do local m=moduleById(item.TemplateId); if moduleFits(m,s) then local key=tostring(item.TemplateId); keyed[key]=keyed[key] or {Module=m,Records={}}; table.insert(keyed[key].Records,{Id=id,Item=item}) end end
	local result={}; for _,group in pairs(keyed) do table.insert(result,group) end; table.sort(result,function(a,b) return tostring(a.Module.DisplayName or a.Module.ModuleId)<tostring(b.Module.DisplayName or b.Module.ModuleId) end); return result
end]==], "application grouped owned modules")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[==[if State.ModuleOptionMode=="Owned" then for _,record in ipairs(ownedRecords(s)) do local selected=State.SelectedModuleInstanceId==record.Id; local equipped=installedInstance==record.Id; local inUse=record.Item.EquippedVehicleId and record.Item.EquippedVehicleId~="" and record.Item.EquippedVehicleId~=State.Profile.CurrentVehicleId; table.insert(c.Cards,{Id=record.Id,ImageKey=State.SelectedSlot,DisplayName=record.Module.DisplayName or record.Module.ModuleId,Badge=equipped and "EQUIPPED" or (inUse and "IN USE" or "OWNED"),BadgeColor=equipped and tierColor("S") or tierColor("C"),Selected=selected,ActionText=selected and not equipped and not inUse and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=record.Module.ModuleId; State.SelectedModuleInstanceId=record.Id; State.PreviewModules={[State.SelectedSlot]=record.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() local r=action:Call("EquipModuleInstance",{ModuleInstanceId=record.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if r.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(r.Message) end end}) end]==],
	[==[if State.ModuleOptionMode=="Owned" then for _,group in ipairs(ownedGroups(s)) do
			local equippedRecord,availableRecord,availableCount=nil,nil,0; for _,record in ipairs(group.Records) do local owner=tostring(record.Item.EquippedVehicleId or ""); if installedInstance==record.Id then equippedRecord=record elseif owner=="" or owner==tostring(State.Profile.CurrentVehicleId or "") then availableRecord=availableRecord or record; availableCount+=1 end end
			local actionRecord=equippedRecord or availableRecord; local selected=State.SelectedModuleId==group.Module.ModuleId; local count=#group.Records; local footer=equippedRecord and ("EQUIPPED  |  OWNED x"..count) or (availableCount>0 and ("AVAILABLE x"..availableCount.."  |  OWNED x"..count) or ("IN USE  |  OWNED x"..count)); local categoryName,vehicleName=moduleLineage(group.Module)
			table.insert(c.Cards,{Id=group.Module.ModuleId,CardKind="Listing",Eyebrow=categoryName.."  |  "..string.upper(vehicleName),Meta=s and (s.DisplayName or s.SlotId) or State.SelectedSlot,Footer=footer,DisplayName=group.Module.DisplayName or group.Module.ModuleId,Selected=selected,ActionText=selected and not equippedRecord and availableRecord and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=group.Module.ModuleId; State.SelectedModuleInstanceId=actionRecord and actionRecord.Id; State.PreviewModules={[State.SelectedSlot]=group.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if not availableRecord then return end; local r=action:Call("EquipModuleInstance",{ModuleInstanceId=availableRecord.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if r.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(r.Message) end end})
		end]==], "application owned listing cards")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[==[else for _,m in ipairs(modulesForSlot(State.SelectedSlot)) do local sourceCockpit=tostring(m.SourceCockpitId or ""); local locked=sourceCockpit~="" and ownedCockpitCount(sourceCockpit)==0; local selected=State.SelectedModuleId==m.ModuleId; table.insert(c.Cards,{Id=m.ModuleId,ImageKey=State.SelectedSlot,DisplayName=m.DisplayName or m.ModuleId,Badge=locked and "LOCKED" or ("$"..tostring(m.Price or 0)),BadgeColor=locked and Color3.fromRGB(90,90,90) or tierColor("A"),Selected=selected,ActionText=selected and not locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=m.ModuleId; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=m.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() local before=State.Profile; local buy=action:Call("BuyModuleInstance",{ModuleId=m.ModuleId}); if not buy.Success then message(buy.Message); return end; local newId=action:NewModuleId(before,m.ModuleId); if not newId then message("Bought module, but its new copy was not found."); return end; local equip=action:Call("EquipModuleInstance",{ModuleInstanceId=newId,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if equip.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(equip.Message) end end}) end end]==],
	[==[else for _,m in ipairs(modulesForSlot(State.SelectedSlot)) do local sourceCockpit=tostring(m.SourceCockpitId or ""); local locked=sourceCockpit~="" and ownedCockpitCount(sourceCockpit)==0; local selected=State.SelectedModuleId==m.ModuleId; local categoryName,vehicleName=moduleLineage(m); local owned=ownedModuleCount(m.ModuleId); local footer=(locked and "LOCKED" or ((owned>0 and ("OWNED x"..owned.."  |  ") or "").."$"..tostring(m.Price or 0))); table.insert(c.Cards,{Id=m.ModuleId,CardKind="Listing",Eyebrow=categoryName.."  |  "..string.upper(vehicleName),Meta=s and (s.DisplayName or s.SlotId) or State.SelectedSlot,Footer=footer,DisplayName=m.DisplayName or m.ModuleId,Selected=selected,ActionText=selected and not locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=m.ModuleId; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=m.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() local before=State.Profile; local buy=action:Call("BuyModuleInstance",{ModuleId=m.ModuleId}); if not buy.Success then message(buy.Message); return end; local newId=action:NewModuleId(before,m.ModuleId); if not newId then message("Bought module, but its new copy was not found."); return end; local equip=action:Call("EquipModuleInstance",{ModuleInstanceId=newId,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if equip.Success then State.ModuleMode="Slots"; State.PreviewModules={}; buildPreview(); renderBuild() else message(equip.Message) end end}) end end]==], "application shop listing cards")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[State.Stage="Customise"; local target=State.CustomizeTarget; local c=common("Customise"); c.Subtitle="Tune installed modules, change colours, or unlock lights."; c.NextText="Start Driving"; c.LeftItems={}; c.Cards={}]],
	[[State.Stage="Customise"; local target=State.CustomizeTarget; local c=common("Customise"); c.Subtitle="Tune installed modules, change colours, or unlock lights."; c.NextText="Start Driving"; c.LeftCardMode=true; c.LeftItems={}; c.Cards={}]], "application customise artwork rail")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[table.insert(c.LeftItems,{Id=id,Text=art.DisplayName,Selected=target==id]],
	[[table.insert(c.LeftItems,{Id=id,Text=art.DisplayName,ImageKey=art.TargetId,Image=art.Image,Selected=target==id]], "application customise artwork data")
moduleApplicationSource = replaceOnce(moduleApplicationSource,
	[[for name,mode in pairs({OpenGarageFromIntro="Dealership",OpenOwnedCockpitCustomisation="Customisation",OpenDrivingVehicleCustomisation="DriveIn"}) do introEvent(name).Event:Connect(function() open(mode) end) end
RunService.RenderStepped:Connect]],
	[[for name,mode in pairs({OpenGarageFromIntro="Dealership",OpenOwnedCockpitCustomisation="Customisation",OpenDrivingVehicleCustomisation="DriveIn"}) do introEvent(name).Event:Connect(function() open(mode) end) end
PreviewCamera.BindInput({State=State,IsActive=function() return active and (browser.Root.Visible or workspaceUI.Root.Visible) end})
RunService.RenderStepped:Connect]], "application camera input")
moduleApplicationSource = moduleApplicationSource .. [[
return {Active=true,Revision="NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3"}
]]
compile("ModuleShopUIController canonical application", moduleApplicationSource)

local embeddedArtwork = [==[
-- NTR_GARAGE_EMBEDDED_ARTWORK_FALLBACK_V1
local artworkRoot=cfg:FindFirstChild("ModuleArtwork")
local artworkDefinitions={
	{Name="All",DisplayName="All",TargetId="ALL",SortOrder=10,ShowInBuild=false,ShowInCustomise=true},
	{Name="Cockpit",DisplayName="Cockpit",TargetId="Cockpit",SortOrder=20,ShowInBuild=false,ShowInCustomise=true},
	{Name="ThrustColour",DisplayName="Thrust Colour",TargetId="THRUST_COLOR",SortOrder=30,ShowInBuild=false,ShowInCustomise=true},
	{Name="FrontEngine",DisplayName="Front Engine",TargetId="Engine1",SortOrder=40,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearEngine",DisplayName="Rear Engine",TargetId="Engine2",SortOrder=50,ShowInBuild=true,ShowInCustomise=true},
	{Name="Stabilisers",DisplayName="Stabilisers",TargetId="Stabilisers",SortOrder=60,ShowInBuild=true,ShowInCustomise=true},
	{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBumper",DisplayName="Front Bumper",TargetId="FrontBumper",SortOrder=80,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearBumper",DisplayName="Rear Bumper",TargetId="RearBumper",SortOrder=90,ShowInBuild=true,ShowInCustomise=true},
	{Name="SidePods",DisplayName="Side Pods",TargetId="SidePods",SortOrder=100,ShowInBuild=true,ShowInCustomise=true},
	{Name="Spoiler",DisplayName="Spoiler",TargetId="RearSpoiler",SortOrder=110,ShowInBuild=true,ShowInCustomise=true},
}
local Artwork={}; local artworkAuditPrinted=false
local function artworkBool(folder,name,fallback) if not folder then return fallback end; local value=folder:GetAttribute(name); if value==nil then return fallback end; return value==true end
local function artworkRow(definition)
	local folder=artworkRoot and artworkRoot:FindFirstChild(definition.Name)
	return {Name=definition.Name,DisplayName=tostring(folder and folder:GetAttribute("DisplayName") or definition.DisplayName),TargetId=tostring(folder and folder:GetAttribute("TargetId") or definition.TargetId),SortOrder=tonumber(folder and folder:GetAttribute("SortOrder")) or definition.SortOrder,ShowInBuild=artworkBool(folder,"ShowInBuild",definition.ShowInBuild),ShowInCustomise=artworkBool(folder,"ShowInCustomise",definition.ShowInCustomise),Image=tostring(folder and folder:GetAttribute("Image") or ""),Folder=folder}
end
function Artwork.ForPage(page) local result={}; for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition); if (page=="Build" and item.ShowInBuild) or (page=="Customise" and item.ShowInCustomise) then table.insert(result,item) end end; table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Artwork.ResolveImage(key) for _,definition in ipairs(artworkDefinitions) do local item=artworkRow(definition); if item.Name==key or item.TargetId==key then return item.Image end end; return "" end
function Artwork.Audit()
	if not artworkAuditPrinted then local available=0; for _,definition in ipairs(artworkDefinitions) do local folder=artworkRoot and artworkRoot:FindFirstChild(definition.Name); if folder and folder:IsA("Folder") then available+=1 end end; if available==#artworkDefinitions then print("[NTR Garage Artwork] ATTRIBUTE FOLDERS PASS") else warn("[NTR Garage Artwork] FALLBACK ACTIVE folders="..tostring(available).."/"..tostring(#artworkDefinitions).."; cards remain functional with blank optional images") end; artworkAuditPrinted=true end
	return true,{}
end
]==]

local workspaceSource = workspaceController.Source
if not string.find(workspaceSource, "NTR_GARAGE_EMBEDDED_ARTWORK_FALLBACK_V1", 1, true) then
	workspaceSource = replaceOnce(workspaceSource,
		[[local Artwork=require(script.Parent:WaitForChild("GarageModuleArtworkRegistry"))
local cfg=kit.Config.UI:WaitForChild("GarageReplacement")]],
		[[local cfg=kit.Config.UI:WaitForChild("GarageReplacement")
]] .. embeddedArtwork, "workspace embedded artwork")
end
if not string.find(workspaceSource,"NTR_GARAGE_WORKSPACE_CATEGORY_LISTING_V3",1,true) then
	workspaceSource=replaceOnce(workspaceSource,"NTR_GARAGE_WORKSPACE_CONTROLLER_V3","NTR_GARAGE_WORKSPACE_CONTROLLER_V3\n-- NTR_GARAGE_WORKSPACE_CATEGORY_LISTING_V3","workspace V3 refinement marker")
	workspaceSource=replaceOnce(workspaceSource,
		[[local function N(name,fallback) local v=cfg:FindFirstChild(name); return tonumber(v and v.Value) or fallback end]],
		[[local function N(name,fallback) local attribute=cfg:GetAttribute(name); if typeof(attribute)=="number" then return attribute end; local v=cfg:FindFirstChild(name); return tonumber(v and v.Value) or fallback end]], "workspace attribute-aware config")
	workspaceSource=replaceOnce(workspaceSource,
		[==[function WorkspaceUI:RenderLeft(context)
	clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	if not self.Categories.Visible then return end
	for order,item in ipairs(context.LeftItems or {}) do local b=generated(Racing.Button(self.CategoryList,{Text=string.upper(item.Text or item.Id or ""),Size=UDim2.new(1,0,0,N("CategoryButtonHeight",46)),Color=item.Selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})); b.LayoutOrder=order; b.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end) end
end]==],
		[==[function WorkspaceUI:RenderLeft(context)
	clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	if not self.Categories.Visible then return end
	for order,item in ipairs(context.LeftItems or {}) do
		local button
		if context.LeftCardMode then button=generated(Shared.ModuleCategoryCard(self.CategoryList,{DisplayName=item.Text or item.Id or "",Image=self:ResolveImage(item.ImageKey or item.Id,item.Image),Selected=item.Selected==true,Size=UDim2.new(1,0,0,N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=item.ImageZoom or 1.04}))
		else button=generated(Racing.Button(self.CategoryList,{Text=string.upper(item.Text or item.Id or ""),Size=UDim2.new(1,0,0,N("CategoryButtonHeight",46)),Color=item.Selected and Color3.fromRGB(94,32,75) or Racing.Colour("PanelSoft")})) end
		button.LayoutOrder=order; button.Activated:Connect(function() if item.OnSelect then item.OnSelect() end end)
	end
end]==], "workspace artwork category rail")
	workspaceSource=replaceOnce(workspaceSource,
		[==[function WorkspaceUI:RenderCards(context)
	self.Paint.Visible=false; self.Scroller.Visible=true; clear(self.Scroller); self.Popup:Hide(); local selectedCard
	for order,row in ipairs(context.Cards or {}) do local selected=row.Selected==true; local card=generated(Shared.ModuleCard(self.Scroller,{DisplayName=row.DisplayName or row.Id or "",Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Selected=selected,Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04})); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end end
	if context.EmptyMessage and #(context.Cards or {})==0 then local empty=generated(Racing.Label(self.Scroller,{Text=context.EmptyMessage,Size=UDim2.fromOffset(420,80),TextSize=13,XAlignment=Enum.TextXAlignment.Center})); empty:SetAttribute("CanonicalGarageCard",true) end
	self:QueueCarouselUpdate(); return selectedCard
end]==],
		[==[function WorkspaceUI:RenderCards(context)
	self.Paint.Visible=false; self.Scroller.Visible=true; clear(self.Scroller); self.Popup:Hide(); local selectedCard
	for order,row in ipairs(context.Cards or {}) do
		local selected=row.Selected==true; local props={DisplayName=row.DisplayName or row.Id or "",Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Selected=selected,Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04}
		local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props)); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end
	end
	if context.EmptyMessage and #(context.Cards or {})==0 then local empty=generated(Racing.Label(self.Scroller,{Text=context.EmptyMessage,Size=UDim2.fromOffset(420,80),TextSize=13,XAlignment=Enum.TextXAlignment.Center})); empty:SetAttribute("CanonicalGarageCard",true) end
	self:QueueCarouselUpdate(); return selectedCard
end]==], "workspace listing card renderer")
end
compile("GarageWorkspaceController embedded artwork", workspaceSource)

local componentsSource=components.Source
if not string.find(componentsSource,"NTR_GARAGE_MODULE_CARD_VARIANTS_V3",1,true) then
	componentsSource=replaceOnce(componentsSource,
		[[function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.NameTextSize=props.NameTextSize or 15; props.NameRole=props.NameRole or "Heading"; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end]],
		[==[function M.ModuleCard(parent,props) props=props or {}; props.ImageHeight=props.ImageHeight or 104; props.ImageZoom=props.ImageZoom or 1; props.NameOverlay=false; props.NameTextSize=props.NameTextSize or 15; props.NameRole=props.NameRole or "Heading"; props.ImageScaleType=props.ImageScaleType or Enum.ScaleType.Fit; return M.Card(parent,props) end
-- NTR_GARAGE_MODULE_CARD_VARIANTS_V3
function M.ModuleCategoryCard(parent,props) return M.ModuleCard(parent,props) end
function M.ModuleListingCard(parent,props)
	props=props or {}; local selected=props.Selected==true; local accent=selected and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175))
	local card=Racing.Button(parent,{Name=props.Name or "ModuleListingCard",Text="",Size=props.Size or UDim2.fromOffset(210,146),Color=Racing.Colour("Panel",Color3.fromRGB(15,19,24)),StrokeColor=accent,FocusColor=Racing.Colour("Telemetry"),StrokeWidth=selected and 2 or 1.2}); card:SetAttribute("CanonicalGarageCard",true); card.ClipsDescendants=false
	local surface=gradient(card,Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); surface.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(1,.28)})
	local eyebrow=Racing.Label(card,{Name="Lineage",Text=string.upper(props.Eyebrow or "VEHICLE MODULE"),Position=UDim2.fromOffset(12,9),Size=UDim2.new(1,-24,0,16),TextSize=8,Color=Racing.Colour("Muted",Color3.fromRGB(175,183,194)),Role="Metric"}); eyebrow.ZIndex=card.ZIndex+2
	local title=Racing.Label(card,{Name="ItemName",Text=props.DisplayName or "MODULE",Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-24,0,47),TextSize=16,Role="Heading"}); title.TextWrapped=true; title.TextYAlignment=Enum.TextYAlignment.Center; title.ZIndex=card.ZIndex+2
	local meta=Racing.Label(card,{Name="ModuleType",Text=string.upper(props.Meta or ""),Position=UDim2.fromOffset(12,79),Size=UDim2.new(1,-24,0,17),TextSize=9,Color=Racing.Colour("Muted",Color3.fromRGB(175,183,194)),Role="Metric"}); meta.ZIndex=card.ZIndex+2
	local divider=Instance.new("Frame"); divider.BackgroundColor3=accent; divider.BackgroundTransparency=.48; divider.BorderSizePixel=0; divider.Position=UDim2.new(0,12,1,-39); divider.Size=UDim2.new(1,-24,0,1); divider.ZIndex=card.ZIndex+2; divider.Parent=card
	local footer=Racing.Label(card,{Name="Status",Text=string.upper(props.Footer or ""),Position=UDim2.new(0,12,1,-34),Size=UDim2.new(1,-24,0,25),TextSize=11,XAlignment=Enum.TextXAlignment.Right,Role="Metric"}); footer.ZIndex=card.ZIndex+2
	return card
end]==], "shared module card variants")
	componentsSource=replaceOnce(componentsSource,
		[[ui.Categories.Position=UDim2.fromOffset(margin,72); ui.Categories.Size=UDim2.fromOffset(N("CategoryWidth",214),math.max(170,carouselTop-72-N("CategoryCarouselClearance",82)))]],
		[[local categoryWidth=ui.Context and ui.Context.LeftCardMode and N("ModuleCategoryRailWidth",238) or N("CategoryWidth",214); ui.Categories.Position=UDim2.fromOffset(margin,72); ui.Categories.Size=UDim2.fromOffset(categoryWidth,math.max(170,carouselTop-72-N("CategoryCarouselClearance",82)))]], "shared dynamic artwork rail width")
end
compile("GarageReplacementComponents V3",componentsSource)
for name,source in pairs({PreviewVehicle=previewVehicleSource,PreviewCamera=previewCameraSource,Components=componentsSource,Workspace=workspaceSource,Application=moduleApplicationSource}) do assert(#source<195000,name.." is too close to Studio Source limit: "..#source) end

local bootstrapSource = bootstrap.Source
if not string.find(bootstrapSource, "NTR_GARAGE_EXISTING_INSTANCE_GATE_V1", 1, true) then
	if not string.find(bootstrapSource, "NTR_GARAGE_CANONICAL_APPLICATION_GATE_V1", 1, true) then
		bootstrapSource = replaceOnce(bootstrapSource,
			[[local function NTR_openGarageWithMode(mode)
	State.ShopMode = mode or "Dealership"]],
			[[local function NTR_openGarageWithMode(mode)
	-- NTR_GARAGE_CANONICAL_APPLICATION_GATE_V1
	if script:GetAttribute("CanonicalGarageApplicationActive") == true then return end
	State.ShopMode = mode or "Dealership"]], "bootstrap open gate")
	end
	bootstrapSource = replaceOnce(bootstrapSource,
		[[local function NTR_openGarageWithMode(mode)
	-- NTR_GARAGE_CANONICAL_APPLICATION_GATE_V1
	if script:GetAttribute("CanonicalGarageApplicationActive") == true then return end
	State.ShopMode = mode or "Dealership"]],
		[[local function NTR_openGarageWithMode(mode)
	-- NTR_GARAGE_EXISTING_INSTANCE_GATE_V1
	if true then return end
	State.ShopMode = mode or "Dealership"]], "bootstrap unconditional garage gate")
end
if not string.find(bootstrapSource, "NTR_GARAGE_EXISTING_INSTANCE_DRIVE_IN_GATE_V1", 1, true) then
	local conditionalDrive = [[function _G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	if script:GetAttribute("CanonicalGarageApplicationActive") == true then return end
	local selectedVehicleId]]
	if not string.find(bootstrapSource, conditionalDrive, 1, true) then
		bootstrapSource = replaceOnce(bootstrapSource,
			[[function _G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	local selectedVehicleId]], conditionalDrive, "bootstrap drive-in gate")
	end
	bootstrapSource = replaceOnce(bootstrapSource, conditionalDrive,
		[[function _G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	-- NTR_GARAGE_EXISTING_INSTANCE_DRIVE_IN_GATE_V1
	if true then return end
	local selectedVehicleId]], "bootstrap unconditional drive-in gate")
end
if not string.find(bootstrapSource, "NTR_GARAGE_EXISTING_INSTANCE_STARTUP_BRIDGE_V1", 1, true) then
	bootstrapSource ..= [==[

-- NTR_GARAGE_EXISTING_INSTANCE_STARTUP_BRIDGE_V1
task.defer(function()
	local ok,result=pcall(function() return require(script.Parent:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("ModuleShopUIController")) end)
	if not ok then warn("[NTR Canonical Garage] STARTUP FAIL "..tostring(result)) elseif typeof(result)~="table" or result.Active~=true then warn("[NTR Canonical Garage] STARTUP FAIL application host returned an invalid contract") else print("[NTR Canonical Garage] STARTUP PASS existing ModuleShopUIController host") end
end)
]==]
end
compile("PatchedBootstrap", bootstrapSource)
assert(#bootstrapSource < 195000, "Bootstrap is too close to Studio Source limit: " .. #bootstrapSource)

local patches = {}
local function replaceLiteral(path, before, after, label)
	local object=clientRoot; for segment in string.gmatch(path,"[^.]+") do object=assert(object:FindFirstChild(segment),"Missing "..path) end
	local changed=object.Source
	if string.find(changed,before,1,true) then changed=replaceOnce(changed,before,after,label) else assert(string.find(changed,after,1,true),"Missing old and installed source anchor: "..label) end
	compile(path,changed); table.insert(patches,{Object=object,Original=object.Source,Changed=changed})
end

replaceLiteral("Controllers.Preview.ThrustPreviewController_Active", [[local function garageOpen()
	local gui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui.Enabled
end]], [[local function garageOpen()
	return player:GetAttribute("NTR_GarageSessionActive") == true
end]], "thrust preview session observer")
replaceLiteral("Controllers.Runtime.CharacterSprintController_Active", [[local function garageMenuOpen()
	local playerGui = PLAYER:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui:IsA("ScreenGui") and gui.Enabled == true
end]], [[local function garageMenuOpen()
	return PLAYER:GetAttribute("NTR_GarageSessionActive") == true
end]], "sprint session observer")
replaceLiteral("Controllers.UI.MobileFreeRoamHudController_Active", [[local function majorMenu() local g=playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI"); return g and g.Enabled end]], [[local function majorMenu() return player:GetAttribute("NTR_GarageSessionActive")==true end]], "mobile HUD session observer")
replaceLiteral("Controllers.UI.DesktopFreeRoamHudController_Active", [[			if screen.Name == "HOVER_RACING_V2_GarageUI" then
				return true
			end]], [[			if player:GetAttribute("NTR_GarageSessionActive") == true then return true end]], "desktop HUD session observer")
replaceLiteral("Controllers.Intro.DealershipIntroClient_Active", [[	local playerGui = player:FindFirstChild("PlayerGui")
	local garageGui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	if garageGui and garageGui.Enabled then
		warnOnce("garage-already-visible", "Garage UI is already visible. This likely means current startup still auto-opens/builds garage before the intro desk gate.")
	end]], [[	-- Canonical garage ownership is tracked by NTR_GarageSessionActive, not a GUI name.]], "dealership legacy GUI diagnostic")

local cached = need(need(need(need(need(kit,"Shared","Folder"),"Modules","Folder"),"Client","Folder"),"Visuals","Folder"),"CachedThrustVisualRuntime","ModuleScript")
local cachedOriginal=cached.Source; local cachedChanged=cachedOriginal
if string.find(cachedChanged,"HOVER_RACING_V2_GarageUI",1,true) then cachedChanged=replaceOnce(cachedChanged,[[local function garageOpen()
	local gui = LOCAL_PLAYER:FindFirstChild("PlayerGui") and LOCAL_PLAYER.PlayerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	return gui and gui.Enabled == true
end]],[[local function garageOpen()
	return LOCAL_PLAYER:GetAttribute("NTR_GarageSessionActive") == true
end]],"cached thrust session observer") end
compile("CachedThrustVisualRuntime",cachedChanged); table.insert(patches,{Object=cached,Original=cachedOriginal,Changed=cachedChanged})

if MODE=="AUDIT" then
	print("[NTR Garage Phase 1 V3] PREFLIGHT PASS; no changes made")
	return
end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local originals={}
local configOriginals={}
local ok,err=xpcall(function()
	local defaults={PreviewPadYOffset=0,PreviewCameraFadeEnabled=true,PreviewCameraFadeOpacity=.68,PreviewCameraFadeOutSeconds=.28,PreviewCameraFadeHoldSeconds=.05,PreviewCameraFadeInSeconds=.46,PreviewCameraLerpSpeed=4.5,PreviewCameraYawSensitivity=.006,PreviewCameraPitchSensitivity=.004,PreviewCameraMinPitchDegrees=-45,PreviewCameraMaxPitchDegrees=10,PreviewCameraMinDistance=16,PreviewCameraMaxDistance=46,PreviewCameraWheelZoom=2.4,PreviewCameraPinchZoom=10,ModuleCategoryRailWidth=238}
	for name,value in pairs(defaults) do table.insert(configOriginals,{name,replacement:GetAttribute(name)}); if replacement:GetAttribute(name)==nil then replacement:SetAttribute(name,value) end end
	local artwork=replacement:FindFirstChild("ModuleArtwork")
	if artwork and artwork:IsA("Folder") then for _,definition in ipairs(definitions) do local folder=artwork:FindFirstChild(definition.Name); if not folder then folder=Instance.new("Folder"); folder.Name=definition.Name; folder.Parent=artwork end; if folder:IsA("Folder") then for _,child in ipairs(folder:GetChildren()) do child:Destroy() end; if folder:GetAttribute("Image")==nil then folder:SetAttribute("Image","") end; folder:SetAttribute("DisplayName",definition.DisplayName); folder:SetAttribute("TargetId",definition.TargetId); folder:SetAttribute("SortOrder",definition.SortOrder); folder:SetAttribute("ShowInBuild",definition.ShowInBuild); folder:SetAttribute("ShowInCustomise",definition.ShowInCustomise) end end end
	assert(ui:FindFirstChild("GarageBrowserController")==browser and ui:FindFirstChild("GarageWorkspaceController")==workspaceController and ui:FindFirstChild("GarageReplacementComponents")==components,"Canonical render dependency changed")
	table.insert(originals,{previewVehicle,previewVehicle.Source}); previewVehicle.Source=previewVehicleSource; assert(previewVehicle.Source==previewVehicleSource,"Preview vehicle source readback failed")
	table.insert(originals,{previewCamera,previewCamera.Source}); previewCamera.Source=previewCameraSource; assert(previewCamera.Source==previewCameraSource,"Preview camera source readback failed")
	table.insert(originals,{components,components.Source}); components.Source=componentsSource; assert(components.Source==componentsSource,"Shared components source readback failed")
	table.insert(originals,{workspaceController,workspaceController.Source}); workspaceController.Source=workspaceSource; assert(workspaceController.Source==workspaceSource,"Workspace source readback failed")
	table.insert(originals,{applicationHost,applicationHost.Source}); applicationHost.Source=moduleApplicationSource; assert(applicationHost.Source==moduleApplicationSource,"Application host source readback failed")
	for _,patch in ipairs(patches) do table.insert(originals,{patch.Object,patch.Object.Source}); patch.Object.Source=patch.Changed; assert(patch.Object.Source==patch.Changed,"Source readback failed: "..patch.Object:GetFullName()) end
	table.insert(originals,{bootstrap,bootstrap.Source}); bootstrap.Source=bootstrapSource; bootstrap:SetAttribute("CanonicalGarageApplicationActive",nil); assert(string.find(bootstrap.Source,"NTR_GARAGE_EXISTING_INSTANCE_STARTUP_BRIDGE_V1",1,true),"Bootstrap startup bridge readback failed")
	print("[NTR Garage Phase 1 V3] INSTALL PASS - preview pad, orbit/fade camera, camera state init repair and shared module cards installed")
	print("[NTR Garage Phase 1 V3] Restart Play. Expected: STARTUP PASS, PAD PASS, DEPENDENCY PASS, geometry PASS and only CanonicalGarageGui visible.")
end,debug.traceback)
if not ok then
	for i=#originals,1,-1 do pcall(function() originals[i][1].Source=originals[i][2] end) end
	for i=#configOriginals,1,-1 do pcall(function() replacement:SetAttribute(configOriginals[i][1],configOriginals[i][2]) end) end
	error("[NTR Garage Phase 1 V3] INSTALL ABORTED; existing sources and config attributes rolled back. "..tostring(err),0)
end
