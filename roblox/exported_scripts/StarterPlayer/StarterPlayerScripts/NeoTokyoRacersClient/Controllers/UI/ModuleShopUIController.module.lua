-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1
-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2
-- NTR_GARAGE_FLOW_REFINEMENT_V2_1
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer; local kit=RS:WaitForChild("NeoTokyoRacers"); local categoriesRoot=kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local uiFolder=script.Parent; local intro=uiFolder.Parent:WaitForChild("Intro"); local previewFolder=uiFolder.Parent:WaitForChild("Preview")
local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local ModuleCards=require(uiFolder:WaitForChild("GarageModuleCardViewModel")); local replacementConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local garageInvoke=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local sessionRequest=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1
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

local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController")); local InstancePreview=require(previewFolder:WaitForChild("GarageModuleInstancePreviewAdapter")); local PreviewProfiles=require(previewFolder:WaitForChild("GarageVehiclePreviewProfile")) -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"); local PerformanceResolver=require(performance:WaitForChild("VehiclePerformanceResolver")); local Racing=require(kit.Shared.Modules.UI.RacingUIComponents) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
local State={Stage="Closed",ShopMode="Dealership",Catalog=nil,Profile=nil,CategoryId="bruiser",BrowseAll=true,SelectedCockpit=nil,SelectedVehicleId=nil,SelectedSlot="Engine1",SelectedModuleId=nil,SelectedModuleInstanceId=nil,ModuleMode="Slots",ModuleOptionMode=nil,CustomizeTarget="ALL",CustomizeMode="Colour",SelectedColorChannel="Primary",PreviewModules={},PreviewProfile=nil,GarageCameraActive=false}
local action=Adapter.new(State); local browser=Browser.new(); local workspaceUI=WorkspaceUI.new(); local preview={}; local active=false; local modal
local function loadingAction(actionName,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(actionName,payload or {}) end); if ok then return result end; warn("[NTR Canonical Garage] Loading transition "..tostring(actionName).." failed: "..tostring(result)); return nil end
local function entryLoading(mode,payload)
	payload=typeof(payload)=="table" and payload or {}
	if payload.LoadingGeneration then return payload.LoadingGeneration end
	local destination=mode=="Dealership" and "Dealership" or (mode=="DriveIn" and "DriveInCustomisation" or "Customisation")
	return loadingAction("Begin",{Destination=destination,Status=mode=="Dealership" and "ENTERING DEALERSHIP" or "ENTERING CUSTOMISATION"})
end
local tierColours={E=Color3.fromRGB(132,142,145),D=Color3.fromRGB(105,190,129),C=Color3.fromRGB(74,204,211),B=Color3.fromRGB(82,137,235),A=Color3.fromRGB(244,188,65),S=Color3.fromRGB(236,92,168)}
local function tierColor(tier) return tierColours[tostring(tier)] or Color3.fromRGB(43,225,218) end
local function allCategories() return (State.Catalog and State.Catalog.Categories) or {} end
local function categoryById(id) for _,c in ipairs(allCategories()) do if tostring(c.CategoryId)==tostring(id) then return c end end end
local function currentCategory() return categoryById(State.CategoryId) or allCategories()[1] end
local function combinedCategory() local c={CategoryId="__ALL",DisplayName="ALL",Cockpits={},Slots={}}; for _,source in ipairs(allCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do local copy={}; for k,v in pairs(cockpit) do copy[k]=v end; copy.NTRCategoryId=source.CategoryId; table.insert(c.Cockpits,copy) end end; return c end
local function browserCategory() return State.BrowseAll and combinedCategory() or currentCategory() end
local function cockpit(id,category) for _,c in ipairs((category or currentCategory()).Cockpits or {}) do if tostring(c.CockpitId)==tostring(id) then return c end end end
local function moduleById(id,category) for _,list in pairs(((category or currentCategory()).Modules) or {}) do for _,m in ipairs(list) do if tostring(m.ModuleId)==tostring(id) then return m end end end end
local function slots() local result={}; for _,s in ipairs((currentCategory() and currentCategory().Slots) or {}) do table.insert(result,s) end; table.sort(result,function(a,b) return (tonumber(a.Order) or 99)<(tonumber(b.Order) or 99) end); return result end
local function slot(id) for _,s in ipairs(slots()) do if tostring(s.SlotId)==tostring(id) then return s end end end
local function enginePosition(m) local explicit=tostring(m and m.EnginePosition or ""); if explicit~="" then return explicit end; if m and (m.RearEngine==true or m.ModuleFolder=="Engines_B" or string.find(tostring(m.ModuleId),"MODULE_ENGINE_B_",1,true)) then return "Rear" end; return "Front" end
local function moduleFits(m,s) if not m or not s or tostring(m.ModuleType)~=tostring(s.ModuleType) then return false end; if s.SlotId=="Engine1" then return enginePosition(m)~="Rear" end; if s.SlotId=="Engine2" then return enginePosition(m)=="Rear" end; return not s.AllowedModuleFolder or s.AllowedModuleFolder=="" or tostring(m.ModuleFolder)==tostring(s.AllowedModuleFolder) end
local function modulesForSlot(id) local s=slot(id); local result={}; if not s then return result end; for _,m in ipairs(((currentCategory().Modules or {})[s.ModuleType]) or {}) do if moduleFits(m,s) then table.insert(result,m) end end; table.sort(result,function(a,b) return tostring(a.DisplayName or a.ModuleId)<tostring(b.DisplayName or b.ModuleId) end); return result end
local function ownedCockpitCount(id) local n=0; for _,item in pairs((State.Profile and State.Profile.OwnedCockpitInstances) or {}) do if tostring(item.TemplateId)==tostring(id) then n+=1 end end; return n end
local function capacity() local g=(State.Profile and State.Profile.Garage) or {}; return tonumber(g.OwnedVehicleCount) or 0,tonumber(g.Capacity) or 2 end
local function installedForSlot(id) local p=State.Profile or {}; local vehicle=p.CurrentVehicleId and p.Vehicles and p.Vehicles[p.CurrentVehicleId]; local instanceId=vehicle and vehicle.InstalledModules and vehicle.InstalledModules[id]; local instance=instanceId and p.OwnedModuleInstances and p.OwnedModuleInstances[instanceId]; return (instance and instance.TemplateId) or (p.InstalledModules and p.InstalledModules[id]),instanceId end
local function coreReady() local e1=installedForSlot("Engine1"); local e2=installedForSlot("Engine2"); local s=installedForSlot("Stabilisers"); local b=installedForSlot("Boost"); local function yes(v) return v~=nil and tostring(v)~="" end; return yes(e1) or yes(e2),yes(s),yes(b) end
local function performanceForCockpit(c) return PerformanceResolver.Factory(categoriesRoot,c) end
local function currentPerformance()
	local instanceNow,instanceBase=InstancePreview.Performance(State,categoriesRoot)
	if instanceNow then return instanceNow,instanceBase end
	if State.Stage=="Customise" and State.CustomizeMode=="Upgrades" and State.PreviewUpgradeId then
		local moduleId,instanceId=installedForSlot(State.CustomizeTarget); local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
		local after,before=PerformanceResolver.UpgradePreview(categoriesRoot,State.PreviewProfile or State.Profile,State.CustomizeTarget,{ModuleId=moduleId},instance,State.PreviewUpgradeId)
		if after then return after,before end
	end
	local base=PerformanceResolver.Profile(categoriesRoot,State.PreviewProfile or State.Profile)
	return base,base
end -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
local function moduleRating(module,instance) return PerformanceResolver.ModuleRating(categoriesRoot,module,instance) end
local function imageValue(value) local text=tostring(value or ""); if text=="" then return "" end; if tonumber(text) then return "rbxassetid://"..text end; return text end
local navigationIcons=replacementConfig:WaitForChild("NavigationIcons")
local function navIcon(name) return imageValue(navigationIcons:GetAttribute(name)) end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1
local function cockpitImage(c) for _,k in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local v=imageValue(c and c[k]); if v~="" then return v end end; local id=tostring(c and c.CockpitId or ""); for _,o in ipairs(categoriesRoot:GetDescendants()) do if o:IsA("Model") and tostring(o:GetAttribute("CockpitId") or o.Name)==id then for _,k in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local v=imageValue(o:GetAttribute(k)); if v~="" then return v end; local child=o:FindFirstChild(k); if child and child:IsA("StringValue") then v=imageValue(child.Value); if v~="" then return v end end end end end; return "" end
local function clearPreview() if preview.Root and preview.Root.Parent then preview.Root:Destroy() end; table.clear(preview); State.PreviewModules={}; State.GarageCameraActive=false end
local function clearTransientModulePreview() -- NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1
	State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil
end
local function buildPreview()
	local before=InstancePreview.ProfileFingerprint(State.Profile); State.GarageCameraActive=true
	local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace})
	if preview.Root then preview.Root:SetAttribute("PreviewVFXMode",State.PreviewVFXMode or "Idle") end
	if before~=InstancePreview.ProfileFingerprint(State.Profile) then error("[NTR Module Instance Preview] Read-only invariant failed: preview mutated the client profile") end
	if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end
end
local function setPreviewVFXMode(mode) State.PreviewVFXMode=mode; local root=preview.Root; if root and root.Parent then root:SetAttribute("PreviewVFXMode",mode) end end
-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
local function handlePaint(target,channel,color,commit)
	PreviewVehicle.ApplyPaint({State=State,Preview=preview,Target=target,Channel=channel,Color=color})
	if commit~=true then return end
	local result
	if target=="THRUST_COLOR" then result=action:Call("SetThrustColor",{Color=color,ReturnProfile=true})
	elseif target=="WholeVehicle" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true})
	elseif target=="ALL" then
		if channel=="Neon" then result=action:Call("SetModuleColor",{SlotId="ALL",Channel=channel,Color=color,ReturnProfile=true})
		else result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true}) end
	elseif target=="Cockpit" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="CockpitOnly",ReturnProfile=true})
	else result=action:Call("SetModuleColor",{SlotId=target,Channel=channel,Color=color,ReturnProfile=true}) end
	if not (result and result.Success) then local text=result and result.Message or "Colour could not be saved."; buildPreview(); if workspaceUI.Root.Visible then workspaceUI:Message(text) else warn("[NTR Canonical Garage] "..tostring(text)) end end
end
local cameraRenderConnection
local function cameraTransition() return {} end
local function section(id) State.CameraSection=id or "ALL"; PreviewCamera.SetCameraSection(State,id or "ALL") end
local function startCamera()
	PreviewCamera.BindInput({State=State,IsActive=function() return active and (browser.Root.Visible or workspaceUI.Root.Visible) end})
	if cameraRenderConnection then cameraRenderConnection:Disconnect() end
	cameraRenderConnection=RunService.RenderStepped:Connect(function(dt) if active and State.GarageCameraActive then PreviewCamera.Update({State=State,Workspace=Workspace,Camera=Workspace.CurrentCamera,Gui=Shared.CanonicalHost().Gui,IsDriving=false},dt) end end)
end
local function stopCamera()
	if cameraRenderConnection then cameraRenderConnection:Disconnect(); cameraRenderConnection=nil end
	PreviewCamera.Release()
end
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
local function closeCamera()
	stopCamera(); clearPreview(); local camera=Workspace.CurrentCamera; local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); if camera then camera.CameraType=Enum.CameraType.Custom; if h then camera.CameraSubject=h end end
	State.Catalog=nil; State.Profile=nil; State.PreviewProfile=nil; State.SelectedVehicleId=nil; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil; State.Stage="Closed"
end
local function introEvent(name) local e=intro:FindFirstChild(name); if e and not e:IsA("BindableEvent") then e:Destroy(); e=nil end; if not e then e=Instance.new("BindableEvent"); e.Name=name; e.Parent=intro end; return e end
local function fire(name) local e=uiFolder:FindFirstChild(name); if e and e:IsA("BindableEvent") then e:Fire() end end
local function message(text) if workspaceUI.Root.Visible then workspaceUI:Message(text) elseif browser.Root.Visible then browser.Subtitle.Text=tostring(text) end end
-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
local function modalBase(title)
	if modal then modal:Destroy() end
	local host=Shared.CanonicalHost(); modal=Instance.new("Frame"); modal.Name="CanonicalGarageModal"; modal.Active=true; modal.BackgroundColor3=Color3.new(0,0,0); modal.BackgroundTransparency=.22; modal.BorderSizePixel=0; modal.Position=UDim2.fromOffset(0,0); modal.Size=UDim2.fromScale(1,1); modal.ZIndex=100; modal.Parent=host.Canvas
	local panel=Shared.Panel(modal,"Panel",{StrokeColor=Racing.Colour("ElectricBlue"),NoGlow=true}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(620,420); panel.ZIndex=101
	Racing.Label(panel,{Text=title,Position=UDim2.fromOffset(18,12),Size=UDim2.new(1,-76,0,34),TextSize=18,Role="Heading"}).ZIndex=102
	local x=Racing.Button(panel,{Text="X",Position=UDim2.new(1,-50,0,10),Size=UDim2.fromOffset(38,32),Color=Color3.fromRGB(166,61,70)}); x.ZIndex=103; x.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end end)
	task.defer(function() RunService.Heartbeat:Wait(); if not (modal and modal.Parent and panel.Parent) then return end; local canvas=host.Canvas; local fills=math.abs(modal.AbsolutePosition.X-canvas.AbsolutePosition.X)<=2 and math.abs(modal.AbsolutePosition.Y-canvas.AbsolutePosition.Y)<=2 and math.abs(modal.AbsoluteSize.X-canvas.AbsoluteSize.X)<=2 and math.abs(modal.AbsoluteSize.Y-canvas.AbsoluteSize.Y)<=2; local centred=math.abs((panel.AbsolutePosition.X+panel.AbsoluteSize.X*.5)-(modal.AbsolutePosition.X+modal.AbsoluteSize.X*.5))<=2 and math.abs((panel.AbsolutePosition.Y+panel.AbsoluteSize.Y*.5)-(modal.AbsolutePosition.Y+modal.AbsoluteSize.Y*.5))<=2; if fills and centred then print("[NTR Garage Module Cards] MODAL GEOMETRY PASS") else warn("[NTR Garage Module Cards] MODAL GEOMETRY FAIL fills="..tostring(fills).." centred="..tostring(centred)) end end)
	return panel
end
-- NTR_GARAGE_MODULE_INSTANCE_ACTIONS_V1
local function confirmModuleMove(vehicleName,onConfirm)
	local p=modalBase("MOVE EQUIPPED MODULE"); p.Size=UDim2.fromOffset(560,238)
	local body=Racing.Label(p,{Text="Equipping this module will remove it from "..tostring(vehicleName)..". Would you like to continue?",Position=UDim2.fromOffset(34,67),Size=UDim2.new(1,-68,0,72),TextSize=15,XAlignment=Enum.TextXAlignment.Center}); body.TextWrapped=true; body.ZIndex=102
	local no=Racing.Button(p,{Text="NO",Position=UDim2.new(.5,-158,1,-66),Size=UDim2.fromOffset(142,40),Color=Color3.fromRGB(166,61,70)}); no.ZIndex=103
	local yes=Racing.Button(p,{Text="YES",Position=UDim2.new(.5,16,1,-66),Size=UDim2.fromOffset(142,40),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue")}); yes.ZIndex=103
	no.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end end)
	yes.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end; onConfirm() end)
end
local function showCash() local p=modalBase("GET MORE CASH"); local l=Racing.Label(p,{Text="Cash packs are not configured yet.",Position=UDim2.fromOffset(24,80),Size=UDim2.new(1,-48,0,80),TextSize=14,XAlignment=Enum.TextXAlignment.Center}); l.ZIndex=102 end
local function showProperties()
	local p=modalBase("GARAGE PROPERTIES"); local catalog=require(kit.Shared.Modules.Data:WaitForChild("GaragePropertyCatalog")); local list=Instance.new("ScrollingFrame"); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=4; list.Position=UDim2.fromOffset(18,58); list.Size=UDim2.new(1,-36,1,-76); list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.fromOffset(0,0); list.ZIndex=102; list.Parent=p; local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,8); layout.Parent=list
	for _,property in ipairs(catalog.List()) do local owned=(State.Profile.Garage.OwnedGarageProperties or {})[property.PropertyId]~=nil; local b=Racing.Button(list,{Text=(owned and "OWNED - " or ("BUY "..Shared.FormatMoney(property.Price or 0).." - "))..tostring(property.DisplayName),Size=UDim2.new(1,-8,0,48),Color=owned and Racing.Colour("PanelSoft") or Racing.Colour("PanelBlue")}); b.ZIndex=103; b.AutoButtonColor=not owned; if not owned then b.Activated:Connect(function() local r=action:Call("BuyGarageProperty",{PropertyId=property.PropertyId}); if not r.Success then message(r.Message) end; showProperties() end) end end
end
local function stats(parent) local now,base=currentPerformance(); workspaceUI:DrawPerformance(parent,now,base,tierColor) end
local renderBrowser,renderPaint,renderHub,renderBuild,renderCustomise
local function common(title) setPreviewVFXMode(State.Stage=="Customise" and State.CustomizeTarget=="THRUST_COLOR" and "ThrustColour" or "Idle"); local owned,cap=capacity(); return {Title=title,Cash=State.Profile and State.Profile.Cash or 0,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",RenderStats=stats,OnCash=showCash,OnCapacity=showProperties,ExitVisible=false,Legacy={}} end
local function driveFromGarage()
	local engine,stabilisers,boost=coreReady(); if not(engine and stabilisers and boost) then message("Equip one engine, stabilisers, and boost before driving."); return end
	local generation=loadingAction("Begin",{Destination="FreeRoamDrive",Status="PREPARING VEHICLE"})
	clearTransientModulePreview()
	local ended=action:Session("End",{ReturnToEntry=true})
	if not ended or ended.Success~=true then local reason=(ended and ended.Message) or "Could not leave customisation."; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); message(reason); return end
	local result=action:Call("SpawnVehicle",{})
	if not result.Success then local reason=result.Message or "Vehicle spawn failed"; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local failedEvent=intro:FindFirstChild("GarageClosedFromDealershipExit"); if failedEvent and failedEvent:IsA("BindableEvent") then failedEvent:Fire() end; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); warn("[NTR Canonical Garage] Drive exit failed safely: "..tostring(reason)); return end
	active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local event=intro:FindFirstChild("GarageClosedFromDealershipExit"); if event and event:IsA("BindableEvent") then event:Fire() end
	loadingAction("Complete",{Generation=generation,Status="READY TO DRIVE"})
end
renderBrowser=function()
	State.Stage="Browser"; setPreviewVFXMode("Idle"); hideAll(); local owned,cap=capacity(); browser:Show({Mode=State.ShopMode,State=State,CarouselScrollKey="Browser|"..tostring(State.ShopMode).."|"..tostring(State.BrowseAll and "ALL" or State.CategoryId),Category=browserCategory(),Cash=State.Profile.Cash,CapacityText=tostring(owned).."/"..tostring(cap).." Spaces",AutoPreview=State.NoPreviewYet,Legacy={},ResolveImage=cockpitImage,ResolvePerformance=performanceForCockpit,TierColor=tierColor,OwnedCount=ownedCockpitCount,
	OnCategory=function(id,all) State.BrowseAll=all==true; if id then State.CategoryId=id end; State.SelectedVehicleId=nil; State.PreviewProfile=nil; State.NoPreviewYet=true; renderBrowser() end,
	OnSelect=function(row) State.SelectedCockpit=row.CockpitId; State.SelectedVehicleId=row.VehicleId; State.CategoryId=row.CategoryId or State.CategoryId; State.PreviewProfile=PreviewProfiles.ForBrowser(State,row); State.NoPreviewYet=false; buildPreview(); PreviewCamera.Reset(State,State.TargetFocus,cameraTransition()); renderBrowser() end,
	OnPrimary=function(row) local selectionMode=State.ShopMode; local selectingOwned=selectionMode=="Customisation"; local r;if selectingOwned then r=action:Call("SelectVehicleInstance",{VehicleId=row.VehicleId,CockpitId=row.CockpitId}) else r=action:Call("BuyCockpitInstance",{CockpitId=row.CockpitId,CategoryId=row.CategoryId}) end; if not r.Success then browser.Subtitle.Text=r.Message or "Could not select vehicle."; return end; State.PreviewProfile=nil; State.SelectedCockpit=State.Profile.CurrentCockpit or row.CockpitId; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.ModuleMode="Slots"; State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); print("[NTR Garage Route] selection="..selectionMode.." destination="..(selectingOwned and "Hub" or "Paint")); if selectingOwned then renderHub() else renderPaint() end end, -- NTR_GARAGE_FLOW_REFINEMENT_V2
	OnExit=function() local generation=loadingAction("Begin",{Destination="DealershipExterior",Status="LEAVING GARAGE"}); local ended=action:Session("End",{ReturnToEntry=true}); if not ended or ended.Success~=true then local reason=(ended and ended.Message) or "Could not leave garage."; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); message(reason); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end; loadingAction("Complete",{Generation=generation,Status="READY"}) end,OnCash=showCash,OnCapacity=showProperties})
end
renderPaint=function()
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Paint"; browser:Hide(); local c=common("Paint Vehicle"); c.Subtitle="Choose a whole-vehicle colour, then continue to your garage."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Customise"; c.NextIcon=navIcon("CustomiseIcon"); c.NextIconText="*"; c.ColorChannels={"Primary","Secondary","Detail"}; c.SelectedChannel=State.SelectedColorChannel; c.Colors=State.Profile.CockpitColors or {}; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderPaint() end; c.OnColor=function(ch,color,commit) handlePaint("WholeVehicle",ch,color,commit) end; c.OnNext=function() clearTransientModulePreview(); renderHub() end; workspaceUI:Show(c)
end
renderHub=function()
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Hub"; browser:Hide(); local c=common("Garage"); c.CarouselScrollKey="Hub"; c.Subtitle="Choose what to work on, or drive your vehicle."; c.ShowLeft=false; c.BackVisible=false; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.Cards={
		{Id="BuildModules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,DisplayName="Build Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="CustomiseModules",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,DisplayName="Edit & Upgrade",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); renderCustomise() end},
	}; c.OnNext=driveFromGarage; workspaceUI:Show(c)
end

local function moduleLineage(m)
	local category=currentCategory() or {}; local categoryDisplay=tostring(category.DisplayName or category.CategoryId or "Vehicle"); local categoryName=string.upper(categoryDisplay)
	local function fullName(name) name=tostring(name or ""); if name=="" then return categoryDisplay.." Vehicle" end; if string.find(string.lower(name),string.lower(categoryDisplay),1,true)==1 then return name end; return categoryDisplay.." "..name end
	local direct=tostring(m and m.SourceCockpitDisplayName or ""); if direct~="" then return categoryName,fullName(direct) end
	local sourceId=tostring(m and m.SourceCockpitId or ""); local source=sourceId~="" and cockpit(sourceId,category) or nil
	return categoryName,fullName(source and (source.DisplayName or source.CockpitId) or (sourceId~="" and sourceId or "Vehicle"))
end
local function ownedModuleCount(moduleId) local count=0; for _,item in pairs(State.Profile.OwnedModuleInstances or {}) do if tostring(item.TemplateId)==tostring(moduleId) then count+=1 end end; return count end
local function vehicleDisplayName(vehicleId)
	local p=State.Profile or {}; local vehicle=p.Vehicles and p.Vehicles[vehicleId]; if not vehicle then return "ANOTHER VEHICLE" end
	local owned=p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local category=categoryById(vehicle.CategoryId or State.CategoryId); local source=owned and cockpit(owned.TemplateId,category); return tostring(source and (source.DisplayName or source.CockpitId) or "ANOTHER VEHICLE")
end
local function sourceVehicleName(m) local _,name=moduleLineage(m); return tostring(name) end
local function sourceVehicleRating(m) local category=currentCategory(); local source=m and cockpit(m.SourceCockpitId,category); local value=source and performanceForCockpit(source); return math.floor(tonumber(value and value.Overall and value.Overall.PerformanceIndex) or 0) end
local function equipInstance(row,allowReassign)
	local r=action:Call("EquipModuleInstance",{ModuleInstanceId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot,AllowReassign=allowReassign==true})
	if r.Success then State.ModuleMode="Slots"; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; buildPreview(); renderBuild() else message(r.Message) end
end
renderBuild=function()
	if State.ModuleMode=="Slots" and State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.CarouselScrollKey="Build|"..tostring(State.ModuleMode).."|"..tostring(State.SelectedSlot).."|"..tostring(State.ModuleOptionMode); c.CategoryScrollKey="BuildRail"; c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip."); c.ShowLeft=true; c.LeftFloating=true; c.LeftCardMode=true; c.LeftSharedCardSize=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104; c.LeftItems={{Id="BuildModules",Text="Build Modules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,Selected=true,OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},{Id="CustomiseModules",Text="Edit & Upgrade",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,Selected=false,OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; buildPreview(); renderCustomise() end}}; c.BackVisible=true; c.BackIcon=navIcon("BackIcon"); c.BackIconText="<"; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.Cards={}
	if State.ModuleMode=="Slots" then
		for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do local s=slot(art.TargetId); if s then local installed=installedForSlot(s.SlotId); table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() clearTransientModulePreview(); State.SelectedSlot=s.SlotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(s.SlotId); renderBuild() end}) end end
	elseif State.ModuleMode=="Sources" then
		table.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end})
		table.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})
	else
		local s=slot(State.SelectedSlot); local _,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then
			local rows=ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
			for _,row in ipairs(rows) do local selected=State.SelectedModuleInstanceId==row.Id; table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and row.State~="Equipped" and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=row.Module.ModuleId; State.SelectedModuleInstanceId=row.Id; State.PreviewModules={[State.SelectedSlot]=row.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if row.State=="InUse" then confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId),function() equipInstance(row,true) end) else equipInstance(row,false) end end}) end
		else
			local rows=ModuleCards.Shop({Modules=modulesForSlot(State.SelectedSlot),IsLocked=function(m) local source=tostring(m.SourceCockpitId or ""); return source~="" and ownedCockpitCount(source)==0 end,SourceVehicleName=sourceVehicleName,SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount,Rating=moduleRating})
			for _,row in ipairs(rows) do local selected=State.SelectedModuleId==row.Id; table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Locked=row.Locked,LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon")),Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and not row.Locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=row.Id}; buildPreview(); renderBuild() end,OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if not buy.Success then message(buy.Message); return end; clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild(); message("Module purchased and equipped.") end}) end
		end
	end
	c.OnBack=function() clearTransientModulePreview(); if State.ModuleMode=="Options" then State.ModuleMode="Sources"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() elseif State.ModuleMode=="Sources" then State.ModuleMode="Slots"; buildPreview(); renderBuild() else buildPreview(); renderHub() end end; c.OnNext=driveFromGarage; workspaceUI:Show(c)
end -- NTR_GARAGE_FLOW_NAVIGATION_COLOUR_V1

local function installedModule() local id=installedForSlot(State.CustomizeTarget); return id,moduleById(id) end
local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end; return {"Primary","Secondary","Detail","Neon"} end -- NTR_GARAGE_FLOW_REFINEMENT_V2_1
renderCustomise=function()
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	State.Stage="Customise"; local target=State.CustomizeTarget; if State.CameraSection~=target then section(target) end; local actionIconScale=math.clamp(tonumber(replacementConfig:GetAttribute("CustomiseActionIconScale")) or .5,.1,1.5); local c=common("Customise"); c.CarouselScrollKey="Customise|"..tostring(target).."|"..tostring(State.CustomizeMode); c.CategoryScrollKey="CustomiseRail"; c.Subtitle="Tune installed modules, change colours, or unlock lights."; c.BackVisible=true; c.BackIcon=navIcon("BackIcon"); c.BackIconText="<"; c.NextText="Drive"; c.NextIcon=navIcon("DriveIcon"); c.NextIconText=">"; c.LeftCardMode=true; c.LeftFloating=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={}; c.Cards={} -- NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Customise")) do
		local id=art.TargetId
		if id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR" or installedForSlot(id) then
			table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=target==id,OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id; State.CustomizeMode=id=="THRUST_COLOR" and "Colour" or "Overview"; if id~="ALL" and id~="Cockpit" and id~="THRUST_COLOR" then section(id) end; renderCustomise() end})
		end
	end
	if target=="THRUST_COLOR" or State.CustomizeMode=="Colour" or State.CustomizeMode=="Underglow" then
		local channels=State.CustomizeMode=="Underglow" and {"Neon"} or colourChannels(target); local colours={}
		for _,ch in ipairs(channels) do if target=="THRUST_COLOR" then colours[ch]=State.Profile.ThrustColor elseif target=="Cockpit" or target=="ALL" then colours[ch]=(State.Profile.CockpitColors or {})[ch] else colours[ch]=((State.Profile.ModuleColors or {})[target] or {})[ch] end; colours[ch]=colours[ch] or Color3.new(1,1,1) end
		c.ColorChannels=channels; c.SelectedChannel=State.SelectedColorChannel or channels[1]; c.Colors=colours; c.OnChannel=function(ch) State.SelectedColorChannel=ch; renderCustomise() end; c.OnColor=function(ch,color,commit) handlePaint(target,ch,color,commit) end
	elseif State.CustomizeMode=="Cosmetics" then
		local id=installedForSlot(target); local owned=State.Profile.NeonOwned and State.Profile.NeonOwned[target]
		table.insert(c.Cards,{Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Neon Lights",Badge=owned and "OWNED" or Shared.FormatMoney(5000),BadgeColor=owned and tierColor("S") or tierColor("A"),Selected=State.PreviewNeonSlot==target,ActionText=not owned and State.PreviewNeonSlot==target and "BUY" or nil,OnSelect=function() State.PreviewNeonSlot=target; buildPreview(); renderCustomise() end,OnAction=function() local r=action:Call("BuyNeon",{SlotId=target}); State.PreviewNeonSlot=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
	elseif State.CustomizeMode=="Upgrades" then
		local moduleId,m=installedModule(); local upgrades=(m and m.Upgrades) or {}; local variant=ModuleCards.Variant(m)
		local _,instanceId=installedForSlot(target); local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
		local allocation=(instance and instance.V2UpgradePoints) or ((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {}); local template=PerformanceResolver.FindModule(categoriesRoot,{ModuleId=moduleId})
		local capacity=math.max(0,math.floor(tonumber(template and template:GetAttribute("UpgradePointCapacity")) or 0)); local used=0; for _,points in pairs(allocation) do used+=math.max(0,math.floor(tonumber(points) or 0)) end; used=math.min(used,capacity)
		c.UpgradeBudget={Label="Upgrade Points",Used=used,Capacity=capacity}
		if #upgrades==0 then c.EmptyMessage="UPGRADE DATA UNAVAILABLE FOR THIS MODULE"; warn("[NTR Garage Upgrades] Missing catalogue paths for "..tostring(moduleId)) end
		local levelColours={Color3.fromRGB(132,142,145),Color3.fromRGB(242,201,76),Color3.fromRGB(242,145,51),Color3.fromRGB(220,68,68)} -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1
		local friendly={TopSpeed="TOP SPEED",EngineOutput="ENGINE OUTPUT",Weight="WEIGHT",LateralGrip="LATERAL GRIP",SteeringResponse="STEERING RESPONSE",HoverStability="HOVER STABILITY",DriftControl="DRIFT CONTROL",DriftGrip="DRIFT GRIP",DriftChargeRate="DRIFT CHARGE",BrakingForce="BRAKING",BoostForce="BOOST FORCE",BoostDuration="BOOST DURATION",BoostRecharge="BOOST RECHARGE",BoostRechargeDelay="RECHARGE DELAY",BoostEfficiency="BOOST EFFICIENCY",Drag="DRAG",Downforce="DOWNFORCE"}
		local function effectText(upgrade) local bestName,bestValue; for name,value in pairs(upgrade.EffectsPerLevel or {}) do if typeof(value)=="number" and value~=0 and (not bestValue or math.abs(value)>math.abs(bestValue)) then bestName,bestValue=name,value end end; if not bestName then return "PERFORMANCE UPGRADE" end; local rounded=math.abs(bestValue)>=1 and tostring(math.floor(math.abs(bestValue)*10+.5)/10) or string.format("%.2f",math.abs(bestValue)); return (bestValue>0 and "+" or "-")..rounded.." "..tostring(friendly[bestName] or string.upper(bestName)) end
		for _,u in ipairs(upgrades) do
			local level=math.clamp(math.floor(tonumber(allocation[u.UpgradeId]) or 0),0,tonumber(u.MaxLevel) or 3); local max=tonumber(u.MaxLevel) or 3; local selected=State.PreviewUpgradeId==u.UpgradeId; local maxed=level>=max; local budgetFull=used>=capacity; local available=not maxed and not budgetFull
			local pointCost=PerformanceResolver.UpgradeCost(categoriesRoot,{ModuleId=moduleId},instance,u.UpgradeId); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "LIMIT REACHED" or Shared.FormatMoney(price)); local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1] -- NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1
			table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=u.DisplayName or u.UpgradeId,TagText="LEVEL "..tostring(level),TagColor=levelColor,PriceText=priceText,PriceColor=priceColor,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Selected=selected,ActionText=selected and available and "UPGRADE" or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
		end
	else
		if target=="ALL" then
			table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName="Change Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end})
			table.insert(c.Cards,{Id="Underglow",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Underglow",OnSelect=function() State.CustomizeMode="Underglow"; renderCustomise() end})
		else table.insert(c.Cards,{Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName=target=="Cockpit" and "Change Colour" or "Colour",OnSelect=function() State.CustomizeMode="Colour"; renderCustomise() end}) end
		if target~="Cockpit" and target~="ALL" then
			table.insert(c.Cards,{Id="Cosmetics",Image=imageValue(replacementConfig:GetAttribute("ModuleCosmeticsIcon")),ImageZoom=actionIconScale,DisplayName="Cosmetics",OnSelect=function() State.CustomizeMode="Cosmetics"; renderCustomise() end})
			table.insert(c.Cards,{Id="Performance",Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),ImageZoom=actionIconScale,DisplayName="Performance",OnSelect=function() State.CustomizeMode="Upgrades"; renderCustomise() end})
		end
	end
	c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" then State.CustomizeMode="Overview"; renderCustomise() else buildPreview(); renderHub() end end
	c.OnNext=driveFromGarage
	buildPreview(); workspaceUI:Show(c)
end
local function open(mode,payload)
	if active then if typeof(payload)=="table" and payload.LoadingGeneration then loadingAction("Complete",{Generation=payload.LoadingGeneration,Status="READY"}) end; return end
	local generation=entryLoading(mode,payload)
	local result=action:Refresh(); if not result.Success then local reason=tostring(result.Message or "Garage data unavailable"); warn("[NTR Canonical Garage] "..reason); action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil); loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); return end
	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true; startCamera()
	if mode=="DriveIn" then local vehicleId=State.Profile.CurrentVehicleId; action:Call("DespawnVehicle",{}); fire("FreeRoamVehicleExited"); if vehicleId then action:Call("SelectVehicleInstance",{VehicleId=vehicleId}) end; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderHub() else renderBrowser() end
	auditOwnership(mode)
	loadingAction("Complete",{Generation=generation,Status="READY"})
end
local function bindGarageOpen(name,mode) introEvent(name).Event:Connect(function(payload) print("[NTR Garage Route] event="..name.." mode="..mode); open(mode,payload) end) end
bindGarageOpen("OpenGarageFromIntro","Dealership"); bindGarageOpen("OpenOwnedCockpitCustomisation","Customisation"); bindGarageOpen("OpenDrivingVehicleCustomisation","DriveIn") -- NTR_GARAGE_FLOW_REFINEMENT_V2
-- Camera input and rendering are session-scoped by startCamera/stopCamera.
task.defer(function() print("[NTR Canonical Garage] DEPENDENCY PASS existing-instance application") end)
return {Active=true,Revision="NTR_GARAGE_PHASE1_EXISTING_INSTANCE_CANONICAL_APPLICATION_V3"}
