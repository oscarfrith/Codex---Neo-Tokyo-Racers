-- Neo Tokyo Racers - UI / garage performance hardening Phase 2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.
-- Transactional: every edited script is compiled before any live Source is assigned.

local MODE = "INSTALL" -- INSTALL or AUDIT
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1"

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
local preview = need(controllers, "Preview", "Folder")
local previewCamera = need(preview, "PreviewCameraController", "ModuleScript")
local application = need(ui, "ModuleShopUIController", "ModuleScript")
local browser = need(ui, "GarageBrowserController", "ModuleScript")
local workspaceController = need(ui, "GarageWorkspaceController", "ModuleScript")
local components = need(ui, "GarageReplacementComponents", "ModuleScript")

local serverRoot = need(ServerScriptService, "NeoTokyoRacers", "Folder")
local services = need(serverRoot, "Services", "Folder")
local playerServices = need(services, "Player", "Folder")
local profileService = need(playerServices, "ProfileService_Active", "Script")

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = need(kit, "Shared", "Folder")
local persistenceConfig = need(need(shared, "Config", "Folder"), "Persistence_EditAttributes", "Folder")
local garageConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")

local required = {
	{previewCamera, "NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3"},
	{application, "NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1"},
	{browser, "NTR_GARAGE_REPLACEMENT_BROWSER_CONTROLLER_V1"},
	{workspaceController, "NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1"},
	{components, "NTR_GARAGE_REPLACEMENT_SHARED_COMPONENTS_V1"},
	{profileService, "ProfileService foundation"},
}

local function audit()
	local failures = {}
	local function expect(ok, text) if not ok then table.insert(failures, text) end end
	for _, item in ipairs(required) do expect(string.find(item[1].Source, item[2], 1, true) ~= nil, item[1].Name .. " baseline marker missing") end
	for _, object in ipairs({previewCamera, application, browser, workspaceController, components, profileService}) do expect(string.find(object.Source, REVISION, 1, true) ~= nil, object.Name .. " Phase 2 marker missing") end
	expect(not string.find(previewCamera.Source, "GarageCameraFade", 1, true), "camera fade instance remains")
	expect(not string.find(previewCamera.Source, "TweenService", 1, true), "camera tween dependency remains")
	expect(string.find(application.Source, "PreviewCamera.Release()", 1, true) ~= nil, "camera release hook missing")
	expect(string.find(profileService.Source, "PROFILE ENCODE SLOW", 1, true) ~= nil, "profile timing diagnostic missing")
	expect(garageConfig:GetAttribute("PreviewCameraFadeEnabled") == false, "fade config is not disabled")
	if #failures == 0 then print("[NTR UI Performance Phase 2] AUDIT PASS"); return true end
	warn("[NTR UI Performance Phase 2] AUDIT FAIL: " .. table.concat(failures, " | "))
	return false
end

if MODE == "AUDIT" then audit(); return end

for _, item in ipairs(required) do assert(string.find(item[1].Source, item[2], 1, true), "Wrong mirror baseline for " .. item[1].Name) end
if string.find(application.Source, REVISION, 1, true) then print("[NTR UI Performance Phase 2] Already installed; running audit only."); audit(); return end

local candidates = {}
local function candidate(object, source)
	compile(object:GetFullName(), source)
	table.insert(candidates, {Object=object, Source=source, Before=object.Source})
end

-- Camera: no fade objects/tweens. Input connections exist only during an active garage session.
local cameraSource = [==[
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3
-- NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V4_SESSION_SCOPED
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Players=game:GetService("Players")
local PreviewCameraController={}
local cfg=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
PreviewCameraController.DefaultFocus=Vector3.new(860,104,-1749); PreviewCameraController.DefaultYaw=math.rad(180); PreviewCameraController.DefaultPitch=math.rad(-12); PreviewCameraController.DefaultDistance=24.3; PreviewCameraController.SectionDistance=33
PreviewCameraController.YawBySlot={FrontBumper=math.rad(180),RearBumper=0,RearSpoiler=0,Boost=0,Engine1=math.rad(135),Engine2=math.rad(45),SidePods=math.rad(90),Stabilisers=math.rad(90)}
local connections={}
local function number(name,fallback) local value=cfg:GetAttribute(name); if typeof(value)=="number" then return value end; local child=cfg:FindFirstChild(name); return tonumber(child and child.Value) or fallback end
function PreviewCameraController.WrapAngle(angle) return math.atan2(math.sin(angle),math.cos(angle)) end
function PreviewCameraController.LerpAngle(a,b,t) return a+PreviewCameraController.WrapAngle(b-a)*t end
function PreviewCameraController.EnsureState(state)
	state.CameraFocus=state.CameraFocus or state.TargetFocus or PreviewCameraController.DefaultFocus; state.TargetFocus=state.TargetFocus or state.CameraFocus; state.CameraYaw=state.CameraYaw or PreviewCameraController.DefaultYaw; state.TargetYaw=state.TargetYaw or state.CameraYaw; state.CameraPitch=state.CameraPitch or PreviewCameraController.DefaultPitch; state.TargetPitch=state.TargetPitch or state.CameraPitch; state.CameraDistance=state.CameraDistance or PreviewCameraController.DefaultDistance; state.TargetDistance=state.TargetDistance or state.CameraDistance; return state
end
function PreviewCameraController.CancelTransition() end
local function transition(state,targets)
	PreviewCameraController.EnsureState(state); state.TargetFocus=targets.Focus or state.TargetFocus; state.TargetYaw=targets.Yaw or state.TargetYaw; state.TargetPitch=targets.Pitch or state.TargetPitch; state.TargetDistance=targets.Distance or state.TargetDistance
end
function PreviewCameraController.SetPreviewFocus(state,focus) PreviewCameraController.EnsureState(state); state.TargetFocus=focus or state.TargetFocus end
function PreviewCameraController.SetCameraSection(state,slotId) transition(state,{Yaw=PreviewCameraController.YawBySlot[slotId] or PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.SectionDistance}) end
function PreviewCameraController.Reset(state,focus) transition(state,{Focus=focus or state.TargetFocus or PreviewCameraController.DefaultFocus,Yaw=PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.DefaultDistance}) end
local function pointerBlocked(position)
	for _,object in ipairs(playerGui:GetGuiObjectsAtPosition(position.X,position.Y)) do local current=object; while current and not current:IsA("ScreenGui") do if current:IsA("GuiButton") or current:IsA("ScrollingFrame") or current.Active then return true end; current=current.Parent end end; return false
end
function PreviewCameraController.UnbindInput() for _,connection in ipairs(connections) do connection:Disconnect() end; table.clear(connections) end
function PreviewCameraController.Release() PreviewCameraController.UnbindInput() end
function PreviewCameraController.BindInput(context)
	PreviewCameraController.UnbindInput(); local state=context.State; local dragging=false; local dragInput,lastPointer; local pinchScale
	local function active() return state and state.GarageCameraActive~=false and (not context.IsActive or context.IsActive()) end
	table.insert(connections,UserInputService.InputBegan:Connect(function(input,processed) if processed or not active() then return end; local kind=input.UserInputType; if (kind==Enum.UserInputType.MouseButton2 or kind==Enum.UserInputType.Touch) and not pointerBlocked(input.Position) then dragging=true; dragInput=input; lastPointer=input.Position end end))
	table.insert(connections,UserInputService.InputEnded:Connect(function(input) if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=false; dragInput=nil; lastPointer=nil end end))
	table.insert(connections,UserInputService.InputChanged:Connect(function(input,processed)
		if not active() then return end; if input.UserInputType==Enum.UserInputType.MouseWheel and not processed then PreviewCameraController.EnsureState(state); state.TargetDistance=math.clamp(state.TargetDistance-input.Position.Z*number("PreviewCameraWheelZoom",2.4),number("PreviewCameraMinDistance",16),number("PreviewCameraMaxDistance",46)); return end
		if not dragging or not lastPointer then return end; if input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput then local delta=input.Position-lastPointer; state.TargetYaw-=delta.X*number("PreviewCameraYawSensitivity",.006); state.TargetPitch=math.clamp(state.TargetPitch-delta.Y*number("PreviewCameraPitchSensitivity",.004),math.rad(number("PreviewCameraMinPitchDegrees",-45)),math.rad(number("PreviewCameraMaxPitchDegrees",10))); lastPointer=input.Position end
	end))
	table.insert(connections,UserInputService.TouchPinch:Connect(function(_,scale,_,inputState,processed) if processed or not active() then return end; if inputState==Enum.UserInputState.Begin then pinchScale=scale elseif inputState==Enum.UserInputState.Change and pinchScale then PreviewCameraController.EnsureState(state); local delta=scale-pinchScale; state.TargetDistance=math.clamp(state.TargetDistance-delta*number("PreviewCameraPinchZoom",10),number("PreviewCameraMinDistance",16),number("PreviewCameraMaxDistance",46)); pinchScale=scale else pinchScale=nil end end))
end
function PreviewCameraController.Update(context,dt)
	local state=context.State; if not state or context.IsDriving==true or state.GarageCameraActive==false or (context.Gui and context.Gui.Enabled==false) then return false end; local workspaceRef=context.Workspace or workspace; local camera=context.Camera or workspaceRef.CurrentCamera; if not camera then return false end
	PreviewCameraController.EnsureState(state); camera.CameraType=Enum.CameraType.Scriptable; local t=math.clamp((dt or 0)*(context.LerpSpeed or number("PreviewCameraLerpSpeed",4.5)),0,1); state.CameraFocus=state.CameraFocus:Lerp(state.TargetFocus,t); state.CameraYaw=PreviewCameraController.LerpAngle(state.CameraYaw,state.TargetYaw,t); state.CameraPitch+=(state.TargetPitch-state.CameraPitch)*t; state.CameraDistance+=(state.TargetDistance-state.CameraDistance)*t; local offset=CFrame.Angles(0,state.CameraYaw,0)*CFrame.Angles(state.CameraPitch,0,0)*Vector3.new(0,0,state.CameraDistance); camera.CFrame=CFrame.lookAt(state.CameraFocus+offset,state.CameraFocus); return true
end
return PreviewCameraController
]==]
candidate(previewCamera, cameraSource)

-- Browser/workspace: discard callback contexts and generated card trees when hidden.
local browserSource = "-- " .. REVISION .. "\n" .. browser.Source
browserSource = replaceOnce(browserSource,
[[function Browser:Hide() self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root) end]],
[[function Browser:Hide()
	self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); self.Context=nil
	for _,parent in ipairs({self.CategoryList,self.Scroller,self.Stats,self.Cash,self.Capacity}) do clear(parent) end
end]],
	"browser release retained context")
candidate(browser, browserSource)

local workspaceSource = "-- " .. REVISION .. "\n" .. workspaceController.Source
workspaceSource = replaceOnce(workspaceSource,
[[function WorkspaceUI:Hide() self:DisconnectDynamic(); self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root) end]],
[[function WorkspaceUI:Hide()
	self:DisconnectDynamic(); self.Root.Visible=false; self.Popup:Hide(); Shared.ReleasePresentation(self.Root); self.Context=nil
	for _,parent in ipairs({self.CategoryList,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity}) do clear(parent) end
end]],
	"workspace release retained context")
candidate(workspaceController, workspaceSource)

-- Shared shell: popup tracking and retired-surface suppression only run while actually needed.
local componentsSource = "-- " .. REVISION .. "\n" .. components.Source
local oldPopup = [=[function M.Popup(root)
	local shell=Instance.new("Frame"); shell.Name="CardActionPopup"; shell.BackgroundTransparency=1; shell.BorderSizePixel=0; shell.AnchorPoint=Vector2.new(.5,1); shell.Size=UDim2.fromOffset(194,38); shell.Visible=false; shell.ZIndex=100; shell.Parent=root
	local button=Racing.Button(shell,{Name="Action",Text="",Size=UDim2.fromScale(1,1),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=Racing.Colour("Telemetry"),ZIndex=102})
	local target,callback,scaleObject
	button.Activated:Connect(function() if callback then callback() end end)
	local connection=RunService.RenderStepped:Connect(function()
		if not (shell.Visible and target and target.Parent and root.Visible) then return end
		local scale=scaleObject and scaleObject.Scale or 1; local rootPos=root.AbsolutePosition
		shell.Position=UDim2.fromOffset((target.AbsolutePosition.X+target.AbsoluteSize.X*.5-rootPos.X)/math.max(scale,.01),(target.AbsolutePosition.Y-rootPos.Y)/math.max(scale,.01)-8)
	end)
	return {Shell=shell,Set=function(_,newTarget,text,fn,newScale) target=newTarget; callback=fn; scaleObject=newScale; button.Text=string.upper(text or ""); shell.Visible=target~=nil end,Hide=function() shell.Visible=false; target=nil; callback=nil end,Destroy=function() connection:Disconnect(); shell:Destroy() end}
end]=]
local newPopup = [=[function M.Popup(root)
	local shell=Instance.new("Frame"); shell.Name="CardActionPopup"; shell.BackgroundTransparency=1; shell.BorderSizePixel=0; shell.AnchorPoint=Vector2.new(.5,1); shell.Size=UDim2.fromOffset(194,38); shell.Visible=false; shell.ZIndex=100; shell.Parent=root
	local button=Racing.Button(shell,{Name="Action",Text="",Size=UDim2.fromScale(1,1),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),FocusColor=Racing.Colour("Telemetry"),ZIndex=102})
	local target,callback,scaleObject,connection
	local function stop() if connection then connection:Disconnect(); connection=nil end end
	local function update() if not (shell.Visible and target and target.Parent and root.Visible) then return end; local scale=scaleObject and scaleObject.Scale or 1; local rootPos=root.AbsolutePosition; shell.Position=UDim2.fromOffset((target.AbsolutePosition.X+target.AbsoluteSize.X*.5-rootPos.X)/math.max(scale,.01),(target.AbsolutePosition.Y-rootPos.Y)/math.max(scale,.01)-8) end
	button.Activated:Connect(function() if callback then callback() end end)
	return {Shell=shell,Set=function(_,newTarget,text,fn,newScale) stop(); target=newTarget; callback=fn; scaleObject=newScale; button.Text=string.upper(text or ""); shell.Visible=target~=nil; if target then update(); connection=RunService.RenderStepped:Connect(update) end end,Hide=function() stop(); shell.Visible=false; target=nil; callback=nil; scaleObject=nil end,Destroy=function() stop(); target=nil; callback=nil; scaleObject=nil; shell:Destroy() end}
end]=]
componentsSource = replaceOnce(componentsSource, oldPopup, newPopup, "session popup tracker")
componentsSource = replaceOnce(componentsSource,
[[function M.ReleasePresentation(owner)
	if presentationOwner == owner then presentationOwner = nil end
	-- Legacy garage surfaces are retired and intentionally never restored.
	for object in pairs(retiredSurfaces) do if object.Parent then object.Visible = false end end
end]],
[[function M.ReleasePresentation(owner)
	if presentationOwner == owner then presentationOwner = nil end
	for object in pairs(retiredSurfaces) do if object.Parent then object.Visible = false end end
	if not presentationOwner and ownerConnection then ownerConnection:Disconnect(); ownerConnection=nil; table.clear(retiredSurfaces) end
end]],
	"presentation tracker release")
candidate(components, componentsSource)

-- Application host: camera render/input connections are created on open and released on close.
local appSource = "-- " .. REVISION .. "\n" .. application.Source
appSource = replaceOnce(appSource,
[[local function cameraTransition() return {FadeParent=Shared.CanonicalHost().Canvas} end
local function section(id) PreviewCamera.SetCameraSection(State,id,cameraTransition()) end]],
[[local cameraRenderConnection
local function cameraTransition() return {} end
local function section(id) PreviewCamera.SetCameraSection(State,id) end
local function startCamera()
	PreviewCamera.BindInput({State=State,IsActive=function() return active and (browser.Root.Visible or workspaceUI.Root.Visible) end})
	if cameraRenderConnection then cameraRenderConnection:Disconnect() end
	cameraRenderConnection=RunService.RenderStepped:Connect(function(dt) if active and State.GarageCameraActive then PreviewCamera.Update({State=State,Workspace=Workspace,Camera=Workspace.CurrentCamera,Gui=Shared.CanonicalHost().Gui,IsDriving=false},dt) end end)
end
local function stopCamera()
	if cameraRenderConnection then cameraRenderConnection:Disconnect(); cameraRenderConnection=nil end
	PreviewCamera.Release()
end]],
	"session camera lifecycle")
appSource = replaceOnce(appSource,
[[local function closeCamera() clearPreview(); local camera=Workspace.CurrentCamera; local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); if camera then camera.CameraType=Enum.CameraType.Custom; if h then camera.CameraSubject=h end end end]],
[[local function closeCamera()
	stopCamera(); clearPreview(); local camera=Workspace.CurrentCamera; local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); if camera then camera.CameraType=Enum.CameraType.Custom; if h then camera.CameraSubject=h end end
	State.Catalog=nil; State.Profile=nil; State.SelectedVehicleId=nil; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil; State.Stage="Closed"
end]],
	"camera and state release")
appSource = replaceOnce(appSource,
[[	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true]],
[[	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true; startCamera()]],
	"camera start on garage open")
appSource = replaceOnce(appSource,
[[PreviewCamera.BindInput({State=State,IsActive=function() return active and (browser.Root.Visible or workspaceUI.Root.Visible) end})
RunService.RenderStepped:Connect(function(dt) if active and State.GarageCameraActive then PreviewCamera.Update({State=State,Workspace=Workspace,Camera=Workspace.CurrentCamera,Gui=Shared.CanonicalHost().Gui,IsDriving=false},dt) end end)]],
[[-- Camera input and rendering are session-scoped by startCamera/stopCamera.]],
	"remove permanent camera listeners")
candidate(application, appSource)

-- Profile saving: convert once, validate that same encoded table, then reuse it for UpdateAsync.
local profileSource = "-- " .. REVISION .. "\n" .. profileService.Source
profileSource = replaceOnce(profileSource,
[[local DataStoreService = game:GetService("DataStoreService")]],
[[local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")]],
	"profile HttpService dependency")
profileSource = replaceOnce(profileSource,
[[	local safe, encodedOrError = schema.AssertDataStoreSafe(session.Profile)
	if not safe then
		session.LastError = tostring(encodedOrError)
		updateRuntimeMarker(player, session)
		return false, "Profile is not DataStore-safe: " .. tostring(encodedOrError)
	end]],
[[	local encodeStarted = os.clock()
	local converted, encodedOrError = pcall(schema.ToDataStore, session.Profile)
	local encoded = converted and encodedOrError or nil
	local safe, jsonOrError = false, encodedOrError
	if converted then safe, jsonOrError = pcall(function() return HttpService:JSONEncode(encoded) end) end
	local encodeMilliseconds = (os.clock() - encodeStarted) * 1000
	if encodeMilliseconds >= math.max(1, tonumber(getAttr("ProfileEncodeWarnMilliseconds", 16)) or 16) then warnLine("PROFILE ENCODE SLOW " .. string.format("%.1f", encodeMilliseconds) .. "ms player=" .. player.Name .. " reason=" .. tostring(session.LastDirtyReason or "unknown")) end
	if not safe then
		session.LastError = tostring(jsonOrError)
		updateRuntimeMarker(player, session)
		return false, "Profile is not DataStore-safe: " .. tostring(jsonOrError)
	end]],
	"single profile conversion and timing")
profileSource = replaceOnce(profileSource,
[[	local encoded = schema.ToDataStore(session.Profile)
	local ok, result = pcall(function()]],
[[	local ok, result = pcall(function()]],
	"remove duplicate profile conversion")
profileSource = replaceOnce(profileSource,
[[log("ProfileService foundation active. DataStoreEnabled=" .. tostring(dataStoreEnabled()))]],
[[log("ProfileService foundation active. DataStoreEnabled=" .. tostring(dataStoreEnabled()) .. " AutosaveSeconds=" .. tostring(autosaveSeconds()) .. " EncodeWarnMs=" .. tostring(getAttr("ProfileEncodeWarnMilliseconds",16))) ]],
	"profile runtime configuration log")
candidate(profileService, profileSource)

local applied = {}
local previousFadeEnabled = garageConfig:GetAttribute("PreviewCameraFadeEnabled")
local previousSessionScoped = garageConfig:GetAttribute("PreviewCameraSessionScoped")
local previousEncodeWarning = persistenceConfig:GetAttribute("ProfileEncodeWarnMilliseconds")
local ok, err = pcall(function()
	for _, item in ipairs(candidates) do item.Object.Source=item.Source; table.insert(applied,item) end
	garageConfig:SetAttribute("PreviewCameraFadeEnabled", false)
	garageConfig:SetAttribute("PreviewCameraSessionScoped", true)
	if persistenceConfig:GetAttribute("ProfileEncodeWarnMilliseconds") == nil then persistenceConfig:SetAttribute("ProfileEncodeWarnMilliseconds", 16) end
	assert(audit(), "Post-install audit failed")
end)
if not ok then
	for index=#applied,1,-1 do pcall(function() applied[index].Object.Source=applied[index].Before end) end
	pcall(function() garageConfig:SetAttribute("PreviewCameraFadeEnabled", previousFadeEnabled) end)
	pcall(function() garageConfig:SetAttribute("PreviewCameraSessionScoped", previousSessionScoped) end)
	pcall(function() persistenceConfig:SetAttribute("ProfileEncodeWarnMilliseconds", previousEncodeWarning) end)
	error("Performance Phase 2 rolled back after assignment failure: " .. tostring(err))
end

print("[NTR UI Performance Phase 2] INSTALL PASS - fade removed, camera/UI lifetime bounded, profile conversion deduplicated")
