-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1
-- NTR_GARAGE_NAV_SCROLL_ECONOMY_V1
-- NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2
-- NTR_GARAGE_FLOW_REFINEMENT_V2_1
-- NTR_GARAGE_FLOW_REFINEMENT_V2
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1
-- NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3
-- NTR_PRESENTATION_AUDIO_TRANSACTION_OUTCOMES_V1
-- NTR_PRESENTATION_AUDIO_MODULE_PURCHASE_EQUIP_CUE_V1_1
-- NTR_PRESENTATION_AUDIO_VEHICLE_PURCHASE_CUE_V1_2
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer; local kit=RS:WaitForChild("NeoTokyoRacers"); local categoriesRoot=kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")
local uiFolder=script.Parent; local intro=uiFolder.Parent:WaitForChild("Intro"); local previewFolder=uiFolder.Parent:WaitForChild("Preview")
local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local ModuleCards=require(uiFolder:WaitForChild("GarageModuleCardViewModel")); local replacementConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local garageInvoke=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local sessionRequest=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("GarageSessionRequest")
local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1
local AudioBridge=require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge"))
local ACTION_AUDIO_KIND={BuyCockpitInstance="Purchase",BuyGarageProperty="Purchase",BuyModuleInstance="Purchase",BuyNeon="Purchase",BuyVehicleCosmetic="Purchase",EquipModuleInstance="ModuleEquip",UpgradeModule="Upgrade"}
local Adapter={}; Adapter.__index=Adapter
function Adapter.new(state) return setmetatable({State=state,Busy=false},Adapter) end
function Adapter:Call(actionName,payload)
	local audioKind=ACTION_AUDIO_KIND[actionName]
	if self.Busy then local result={Success=false,Message="Please wait."}; if audioKind then AudioBridge.Result(audioKind,result,{Action=actionName}) end; return result end
	self.Busy=true; local ok,result=pcall(function() return garageInvoke:InvokeServer(actionName,payload or {}) end); self.Busy=false
	if not ok or typeof(result)~="table" then result={Success=false,Message="Garage server did not respond."}; if audioKind then AudioBridge.Result(audioKind,result,{Action=actionName}) end; return result end
	if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end; self.State.Economy=Shared.ProjectEconomy(result,self.State.Economy)
	local outcomeAudioKind=audioKind
	if result.Success==true then
		if actionName=="BuyModuleInstance" then outcomeAudioKind="ModuleEquip"
		elseif actionName=="BuyCockpitInstance" then outcomeAudioKind="VehiclePurchase" end
	end
	if outcomeAudioKind then AudioBridge.Result(outcomeAudioKind,result,{Action=actionName}) end
	return result
end
function Adapter:Refresh() return self:Call("GetInitial",{}) end
function Adapter:Session(actionName,payload) local ok,result=pcall(function() return sessionRequest:InvokeServer(actionName,payload or {}) end); return ok and result or {Success=false,Message="Garage session did not respond."} end
function Adapter:NewModuleId(before,moduleId)
	local old={}; for id in pairs((before and before.OwnedModuleInstances) or {}) do old[id]=true end
	for id,item in pairs((self.State.Profile and self.State.Profile.OwnedModuleInstances) or {}) do if not old[id] and tostring(item.TemplateId)==tostring(moduleId) then return id end end
end

local PreviewVehicle=require(previewFolder:WaitForChild("PreviewVehicleController")); local PreviewCamera=require(previewFolder:WaitForChild("PreviewCameraController")); local InstancePreview=require(previewFolder:WaitForChild("GarageModuleInstancePreviewAdapter")); local PreviewProfiles=require(previewFolder:WaitForChild("GarageVehiclePreviewProfile")) -- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
local performance=kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Common"):WaitForChild("Performance"); local PerformanceResolver=require(performance:WaitForChild("VehiclePerformanceResolver")); local Racing=require(kit.Shared.Modules.UI.RacingUIComponents) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
local State={Stage="Closed",ShopMode="Dealership",Catalog=nil,Profile=nil,CategoryId="bruiser",BrowseAll=true,SelectedCockpit=nil,SelectedVehicleId=nil,SelectedSlot="Engine1",SelectedModuleId=nil,SelectedModuleInstanceId=nil,ModuleMode="Slots",ModuleOptionMode=nil,CustomizeTarget="ALL",CustomizeMode="Colour",SelectedColorChannel="Primary",PreviewModules={},PreviewProfile=nil,ReturnWorkshop=nil,GarageCameraActive=false}
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
	if target=="THRUST_COLOR" then result=action:Call("SetVehicleCosmeticColor",{CosmeticId="ThrustColour",Color=color,ReturnProfile=true})
	elseif target=="UNDERGLOW" then result=action:Call("SetVehicleCosmeticColor",{CosmeticId="Underglow",Color=color,ReturnProfile=true})
	elseif target=="WholeVehicle" then result=action:Call("SetCockpitColor",{Channel=channel,Color=color,Scope="WholeVehicle",ReturnProfile=true})
	elseif target=="ALL" then
		if channel=="Neon" then result=action:Call("SetAllNeonColor",{Color=color,ReturnProfile=true})
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
local renderBrowser,renderPaint,renderHub,renderBuild,renderUpgrade,renderPaintShop
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
	-- NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1
	-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_UI_V1
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Hub"
	browser:Hide()
	local c=common("Garage"); c.TutorialPageId="CustomisationHome" -- NTR_ONBOARDING_V1_3_MODULE_PAGE_SEMANTICS
	c.CarouselScrollKey="Hub|ThreeWorkshops"
	c.Subtitle="Choose a workshop, or drive your vehicle."
	c.ShowLeft=false
	c.BackVisible=false
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.Cards={
		{Id="AddModules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,DisplayName="Add Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="UpgradeModules",Image=navIcon("UpgradeModulesIcon"),ImageZoom=.5,DisplayName="Upgrade Modules",OnSelect=function() clearTransientModulePreview(); State.CustomizeMode="Upgrades"; local chosen=State.SelectedSlot; if not installedForSlot(chosen) then for _,candidate in ipairs(slots()) do if installedForSlot(candidate.SlotId) then chosen=candidate.SlotId; break end end end; State.CustomizeTarget=chosen or "Engine1"; renderUpgrade() end},
		{Id="PaintShop",Image=navIcon("PaintShopIcon"),ImageZoom=.5,DisplayName="Paint Shop",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; State.SelectedPaintAction=nil; State.SelectedColorChannel="Primary"; renderPaintShop() end},
	}
	c.OnNext=driveFromGarage
	workspaceUI:Show(c)
end

local function moduleLineage(m)
	local category=currentCategory() or {}
	local categoryDisplay=tostring(category.DisplayName or category.CategoryId or "Vehicle")
	local categoryName=string.upper(categoryDisplay)
	local function fullName(name)
		name=tostring(name or "")
		if name=="" then return categoryDisplay.." Vehicle" end
		if string.find(string.lower(name),string.lower(categoryDisplay),1,true)==1 then return name end
		return categoryDisplay.." "..name
	end
	local direct=tostring(m and m.SourceCockpitDisplayName or "")
	if direct~="" then return categoryName,fullName(direct) end
	local sourceId=tostring(m and m.SourceCockpitId or "")
	local source=sourceId~="" and cockpit(sourceId,category) or nil
	return categoryName,fullName(source and (source.DisplayName or source.CockpitId) or (sourceId~="" and sourceId or "Vehicle"))
end

local function ownedModuleCount(moduleId)
	local count=0
	for _,item in pairs(State.Profile.OwnedModuleInstances or {}) do
		if tostring(item.TemplateId)==tostring(moduleId) then count+=1 end
	end
	return count
end

local function vehicleDisplayName(vehicleId)
	local p=State.Profile or {}
	local vehicle=p.Vehicles and p.Vehicles[vehicleId]
	if not vehicle then return "ANOTHER VEHICLE" end
	local owned=p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	local category=categoryById(vehicle.CategoryId or State.CategoryId)
	local source=owned and cockpit(owned.TemplateId,category)
	return tostring(source and (source.DisplayName or source.CockpitId) or "ANOTHER VEHICLE")
end

local function sourceVehicleName(m)
	local _,name=moduleLineage(m)
	return tostring(name)
end

local function sourceVehicleRating(m)
	local category=currentCategory()
	local source=m and cockpit(m.SourceCockpitId,category)
	local value=source and performanceForCockpit(source)
	return math.floor(tonumber(value and value.Overall and value.Overall.PerformanceIndex) or 0)
end

local function compatibleOwnedRows(slotId)
	local s=slot(slotId); if not s then return {} end
	local _,installedInstance=installedForSlot(slotId)
	return ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
end
local function returnFromModuleRoute()
	local route=State.ReturnWorkshop; State.ReturnWorkshop=nil
	if not route then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; renderBuild(); return end
	State.CustomizeTarget=route.Target
	if route.Workshop=="Upgrade" then State.CustomizeMode="Upgrades"; renderUpgrade() else State.CustomizeMode="Overview"; renderPaintShop() end
end
local function routeToAddModule(slotId,workshop)
	clearTransientModulePreview(); State.ReturnWorkshop={Target=slotId,Workshop=workshop}; State.SelectedSlot=slotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(slotId); renderBuild()
end
local function missingModuleCard(c,target,workshop)
	local owned=#compatibleOwnedRows(target)>0
	table.insert(c.Cards,{Id="__MODULE_UNLOCK",EmptyPlus=true,DisplayName=owned and "EQUIP TO UNLOCK" or "BUY TO UNLOCK",OnSelect=function() routeToAddModule(target,workshop) end})
end
local function equipInstance(row,allowReassign)
	local r=action:Call("EquipModuleInstance",{ModuleInstanceId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot,AllowReassign=allowReassign==true})
	if r.Success then
		State.ModuleMode="Slots"
		State.SelectedModuleId=nil
		State.SelectedModuleInstanceId=nil
		State.PreviewModules={}
		buildPreview()
		if State.ReturnWorkshop then returnFromModuleRoute() else renderBuild() end
	else
		message(r.Message)
	end
end

local function workshopRail(selected)
	return {
		{Id="AddModules",Text="Add Modules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,Selected=selected=="Add",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="UpgradeModules",Text="Upgrade Modules",Image=navIcon("UpgradeModulesIcon"),ImageZoom=.5,Selected=selected=="Upgrade",OnSelect=function() clearTransientModulePreview(); State.CustomizeMode="Upgrades"; local chosen=State.SelectedSlot; if not installedForSlot(chosen) then for _,candidate in ipairs(slots()) do if installedForSlot(candidate.SlotId) then chosen=candidate.SlotId; break end end end; State.CustomizeTarget=chosen or "Engine1"; renderUpgrade() end},
		{Id="PaintShop",Text="Paint Shop",Image=navIcon("PaintShopIcon"),ImageZoom=.5,Selected=selected=="Paint",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; State.SelectedPaintAction=nil; State.SelectedColorChannel="Primary"; renderPaintShop() end},
	}
end

renderBuild=function()
	if State.ModuleMode=="Slots" and State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Build"
	browser:Hide()
	local c=common("Add Modules"); c.TutorialPageId="AddModules"
	c.CarouselScrollKey="AddModules|"..tostring(State.ModuleMode).."|"..tostring(State.SelectedSlot).."|"..tostring(State.ModuleOptionMode)
	c.CategoryScrollKey="WorkshopModeRail"
	c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip.")
	c.ShowLeft=true
	c.LeftFloating=true
	c.LeftCardMode=true
	c.LeftSharedCardSize=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104
	c.LeftItems=workshopRail("Add")
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.Cards={}
	if State.ModuleMode=="Slots" then
		for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do
			local s=slot(art.TargetId)
			if s then
				local installed=installedForSlot(s.SlotId)
				table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() clearTransientModulePreview(); State.SelectedSlot=s.SlotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(s.SlotId); renderBuild() end})
			end
		end
	elseif State.ModuleMode=="Sources" then
		local ownedRows=compatibleOwnedRows(State.SelectedSlot)
		if #ownedRows==0 then table.insert(c.Cards,{Id="Owned",CardKind="Listing",DisplayName="Owned Modules",Footer="BUY MODULE",SemanticState="Locked",LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon"))})
		else table.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end}) end
		table.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})
	else
		local s=slot(State.SelectedSlot)
		local _,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then
			local rows=ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleInstanceId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and row.State~="Equipped" and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=row.Module.ModuleId; State.SelectedModuleInstanceId=row.Id; State.PreviewModules={[State.SelectedSlot]=row.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if row.State=="InUse" then confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId),function() equipInstance(row,true) end) else equipInstance(row,false) end end})
			end
		else
			local rows=ModuleCards.Shop({Modules=modulesForSlot(State.SelectedSlot),IsLocked=function(m) local source=tostring(m.SourceCockpitId or ""); return source~="" and ownedCockpitCount(source)==0 end,SourceVehicleName=sourceVehicleName,SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount,Rating=moduleRating})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Locked=row.Locked,LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon")),Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and not row.Locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=row.Id}; buildPreview(); renderBuild() end,OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if not buy.Success then message(buy.Message); return end; clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); if State.ReturnWorkshop then returnFromModuleRoute() else renderBuild() end; message("Module purchased and equipped.") end})
			end
		end
	end
	c.OnBack=function()
		clearTransientModulePreview()
		if State.ModuleMode=="Options" then
			State.ModuleMode="Sources"
			State.ModuleOptionMode=nil
			buildPreview()
			renderBuild()
		elseif State.ModuleMode=="Sources" then
			if State.ReturnWorkshop then returnFromModuleRoute() else State.ModuleMode="Slots"; buildPreview(); renderBuild() end
		else
			buildPreview()
			renderHub()
		end
	end
	c.OnNext=driveFromGarage
	workspaceUI:Show(c)
end

local function installedModuleFor(target)
	local id,instanceId=installedForSlot(target)
	return id,moduleById(id),instanceId
end

local function addModuleLocationRail(c,selected,onSelect)
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do
		local s=slot(art.TargetId)
		if s then
			local installed=installedForSlot(s.SlotId)
			table.insert(c.LeftItems,{Id=s.SlotId,Text=art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=selected==s.SlotId,Muted=not installed,OnSelect=function() onSelect(s.SlotId) end})
		end
	end
end

local function addUpgradeCards(c,target)
	local moduleId,m,instanceId=installedModuleFor(target)
	if not moduleId then missingModuleCard(c,target,"Upgrade"); return end
	local upgrades=(m and m.Upgrades) or {}
	local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
	local allocation=(instance and instance.V2UpgradePoints) or ((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {})
	local template=PerformanceResolver.FindModule(categoriesRoot,{ModuleId=moduleId})
	local capacity=math.max(0,math.floor(tonumber(template and template:GetAttribute("UpgradePointCapacity")) or 0))
	local used=0
	for _,points in pairs(allocation) do used+=math.max(0,math.floor(tonumber(points) or 0)) end
	used=math.min(used,capacity)
	c.UpgradeBudget={Label="Upgrade Points",Used=used,Capacity=capacity}
	if #upgrades==0 then
		c.EmptyMessage="UPGRADE DATA UNAVAILABLE FOR THIS MODULE"
		warn("[NTR Garage Upgrades] Missing catalogue paths for "..tostring(moduleId))
		return
	end
	local levelColours={Color3.fromRGB(132,142,145),Color3.fromRGB(242,201,76),Color3.fromRGB(242,145,51),Color3.fromRGB(220,68,68)}
	local friendly={TopSpeed="TOP SPEED",EngineOutput="ENGINE OUTPUT",Weight="WEIGHT",LateralGrip="LATERAL GRIP",SteeringResponse="STEERING RESPONSE",HoverStability="HOVER STABILITY",DriftControl="DRIFT CONTROL",DriftGrip="DRIFT GRIP",DriftChargeRate="DRIFT CHARGE",BrakingForce="BRAKING",BoostForce="BOOST FORCE",BoostDuration="BOOST DURATION",BoostRecharge="BOOST RECHARGE",BoostRechargeDelay="RECHARGE DELAY",BoostEfficiency="BOOST EFFICIENCY",Drag="DRAG",Downforce="DOWNFORCE"}
	local function effectText(upgrade)
		local bestName,bestValue
		for name,value in pairs(upgrade.EffectsPerLevel or {}) do
			if typeof(value)=="number" and value~=0 and (not bestValue or math.abs(value)>math.abs(bestValue)) then bestName,bestValue=name,value end
		end
		if not bestName then return "PERFORMANCE UPGRADE" end
		local rounded=math.abs(bestValue)>=1 and tostring(math.floor(math.abs(bestValue)*10+.5)/10) or string.format("%.2f",math.abs(bestValue))
		return (bestValue>0 and "+" or "-")..rounded.." "..tostring(friendly[bestName] or string.upper(bestName))
	end
	for _,u in ipairs(upgrades) do
		local level=math.clamp(math.floor(tonumber(allocation[u.UpgradeId]) or 0),0,tonumber(u.MaxLevel) or 3)
		local max=tonumber(u.MaxLevel) or 3
		local selected=State.PreviewUpgradeId==u.UpgradeId
		local maxed=level>=max
		local budgetFull=used>=capacity
		local available=not maxed and not budgetFull
		local pointCost=PerformanceResolver.UpgradeCost(categoriesRoot,{ModuleId=moduleId},instance,u.UpgradeId)
		local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0)
		local footer=(maxed or budgetFull) and "" or effectText(u)
		local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade")
		local priceText=maxed and "MAX LEVEL" or (budgetFull and "LIMIT REACHED" or Shared.FormatMoney(price))
		local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145)
		local levelColor=levelColours[math.clamp(level,0,3)+1]
		table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=u.DisplayName or u.UpgradeId,TagText="LEVEL "..tostring(level),TagColor=levelColor,PriceText=priceText,PriceColor=priceColor,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Selected=selected,ActionText=selected and available and "UPGRADE" or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderUpgrade() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then renderUpgrade() else message(r.Message) end end})
	end
end

renderUpgrade=function()
	State.Stage="Customise"
	State.CustomizeMode="Upgrades"
	local target=State.CustomizeTarget
	if not slot(target) then
		local candidates=slots()
		target=candidates[1] and candidates[1].SlotId or "Engine1"
		State.CustomizeTarget=target
	end
	if State.CameraSection~=target then section(target) end
	browser:Hide()
	local c=common("Upgrade Modules"); c.TutorialPageId="UpgradeModules"
	c.CarouselScrollKey="UpgradeModules|"..tostring(target)
	c.CategoryScrollKey="UpgradeModuleRail"
	c.Subtitle="Choose an installed module location, then invest its upgrade points."
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.LeftCardMode=true
	c.LeftFloating=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78
	c.LeftItems={}
	c.Cards={}
	addModuleLocationRail(c,target,function(id)
		clearTransientModulePreview()
		State.CustomizeTarget=id
		State.CustomizeMode="Upgrades"
		section(id)
		renderUpgrade()
	end)
	addUpgradeCards(c,target)
	c.OnBack=function() clearTransientModulePreview(); buildPreview(); renderHub() end
	c.OnNext=driveFromGarage
	buildPreview()
	workspaceUI:Show(c)
end

local function paintChannels(target)
	if target=="THRUST_COLOR" then return {"ThrustColor"} end
	if target=="UNDERGLOW" then return {"Underglow"} end
	if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end
	if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end
	local result={"Primary","Secondary","Detail"}
	if State.Profile.NeonOwned and State.Profile.NeonOwned[target]==true then table.insert(result,"Neon") end
	return result
end

local function hasOwnedNeon()
	for _,s in ipairs(slots()) do
		if installedForSlot(s.SlotId) and State.Profile.NeonOwned and State.Profile.NeonOwned[s.SlotId]==true then return true end
	end
	return false
end

local function firstBulkNeon()
	for _,s in ipairs(slots()) do
		if State.Profile.NeonOwned and State.Profile.NeonOwned[s.SlotId]==true then
			local value=((State.Profile.ModuleColors or {})[s.SlotId] or {}).Neon
			if typeof(value)=="Color3" then return value end
		end
	end
	return Color3.new(1,1,1)
end

local function paintColours(target,channels)
	local colours={}
	for _,channel in ipairs(channels) do
		local value
		if target=="THRUST_COLOR" then
			value=State.Profile.ThrustColor
		elseif target=="UNDERGLOW" then
			local vehicle=State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]; value=vehicle and vehicle.Cosmetics and vehicle.Cosmetics.Colours and vehicle.Cosmetics.Colours.Underglow
		elseif target=="Cockpit" or target=="ALL" then
			value=(State.Profile.CockpitColors or {})[channel]
		else
			value=((State.Profile.ModuleColors or {})[target] or {})[channel]
		end
		colours[channel]=typeof(value)=="Color3" and value or Color3.new(1,1,1)
	end
	return colours
end

local function currentCosmetics()
	local vehicle=State.Profile.CurrentVehicleId and State.Profile.Vehicles and State.Profile.Vehicles[State.Profile.CurrentVehicleId]
	return vehicle and vehicle.Cosmetics
end
local function cosmeticOwned(id) local state=currentCosmetics(); return state and state.Unlocks and state.Unlocks[id]==true end
local function cosmeticDefinition(id) for _,item in ipairs((State.Catalog and State.Catalog.VehicleCosmetics) or {}) do if item.CosmeticId==id then return item end end end
local function modeForPaintTarget(id)
	if id=="ALL" or id=="Cockpit" then return "Colour" end
	if id=="THRUST_COLOR" then return cosmeticOwned("ThrustColour") and "Colour" or "Overview" end
	if id=="UNDERGLOW" then return cosmeticOwned("Underglow") and "Colour" or "Overview" end
	return "Overview"
end
local function paintTargetRail(c,target)
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Customise")) do
		local id=art.TargetId
		local special=id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR"
		local physical=slot(id)~=nil
		if special or physical then
			table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=target==id,Muted=physical and not installedForSlot(id),OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id; State.CustomizeMode=modeForPaintTarget(id); State.SelectedPaintAction=nil; local channels=paintChannels(id); State.SelectedColorChannel=channels[1]; if physical then section(id) else section("ALL") end; renderPaintShop() end})
			if id=="THRUST_COLOR" then
				table.insert(c.LeftItems,{Id="UNDERGLOW",Text="Underglow",Image=navIcon("UnderglowIcon"),ImageZoom=1.04,Selected=target=="UNDERGLOW",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="UNDERGLOW"; State.CustomizeMode=modeForPaintTarget("UNDERGLOW"); State.SelectedPaintAction=nil; State.SelectedColorChannel="Underglow"; section("ALL"); renderPaintShop() end})
			end
		end
	end
end

local function addCosmeticPurchaseCard(c,target,id,actionIconScale)
	local definition=cosmeticDefinition(id); if not definition or definition.Available==false then c.EmptyMessage="NOT AVAILABLE FOR THIS VEHICLE"; return end
	local price=math.max(0,math.floor(tonumber(definition.Price) or 0)); local affordable=(tonumber(State.Profile.Cash) or 0)>=price; local selected=State.SelectedPaintAction==id
	table.insert(c.Cards,{Id=id,Image=imageValue(definition.Icon),ImageZoom=actionIconScale,DisplayName=definition.DisplayName,Badge=Shared.FormatMoney(price),BadgeColor=affordable and Color3.fromRGB(89,255,102) or Color3.fromRGB(225,56,70),Selected=selected,ActionText=selected and "BUY" or nil,OnSelect=function() State.SelectedPaintAction=id; renderPaintShop() end,OnAction=function()
		local result=action:Call("BuyVehicleCosmetic",{CosmeticId=id}); State.SelectedPaintAction=nil
		if result and result.Success then State.CustomizeMode="Colour"; local channels=paintChannels(target); State.SelectedColorChannel=channels[1]; buildPreview(); renderPaintShop() else renderPaintShop(); message(result and result.Message or "Purchase could not be completed.") end
	end})
end

local function addPaintOverviewCards(c,target,actionIconScale)
	local physical=slot(target)~=nil
	if physical and not installedForSlot(target) then missingModuleCard(c,target,"Paint"); return end
	if target=="THRUST_COLOR" then addCosmeticPurchaseCard(c,target,"ThrustColour",actionIconScale); return end
	if target=="UNDERGLOW" then addCosmeticPurchaseCard(c,target,"Underglow",actionIconScale); return end
	table.insert(c.Cards,{Id="Paint",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName="Paint",OnSelect=function() State.SelectedPaintAction=nil; State.PreviewNeonSlot=nil; State.CustomizeMode="Colour"; local channels=paintChannels(target); State.SelectedColorChannel=channels[1]; renderPaintShop() end})
	if not physical then return end
	local _,module=installedModuleFor(target)
	local available=module and module.NeonAvailable==true
	local owned=State.Profile.NeonOwned and State.Profile.NeonOwned[target]==true
	local price=math.max(0,math.floor(tonumber(module and module.NeonPrice) or 5000))
	local selected=State.SelectedPaintAction=="Neon"
	if not available then
		table.insert(c.Cards,{Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Neon Lights",Footer="NOT AVAILABLE FOR THIS MODULE",SemanticState="Unavailable"})
		return
	end
	local affordable=(tonumber(State.Profile.Cash) or 0)>=price
	table.insert(c.Cards,{
		Id="Neon",
		Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),
		ImageZoom=actionIconScale,
		DisplayName="Neon Lights",
		Badge=owned and "OWNED" or Shared.FormatMoney(price),
		BadgeColor=owned and tierColor("S") or (affordable and Color3.fromRGB(89,255,102) or Color3.fromRGB(225,56,70)),
		Selected=selected,
		ActionText=selected and (owned and "CUSTOMISE" or "BUY") or nil,
		OnSelect=function()
			State.SelectedPaintAction="Neon"
			State.PreviewNeonSlot=not owned and target or nil
			renderPaintShop()
		end,
		OnAction=function()
			if owned then
				State.PreviewNeonSlot=nil
				State.SelectedPaintAction=nil
				State.CustomizeMode="Colour"
				State.SelectedColorChannel="Neon"
				renderPaintShop()
				return
			end
			local r=action:Call("BuyNeon",{SlotId=target})
			State.PreviewNeonSlot=nil
			State.SelectedPaintAction=nil
			if r.Success then
				State.CustomizeMode="Colour"
				State.SelectedColorChannel="Neon"
				renderPaintShop()
			else
				renderPaintShop()
				message(r.Message)
			end
		end,
	})
end

renderPaintShop=function()
	State.Stage="Customise"
	local target=State.CustomizeTarget or "ALL"
	if target~="ALL" and target~="Cockpit" and target~="THRUST_COLOR" and target~="UNDERGLOW" and not slot(target) then target="ALL"; State.CustomizeTarget=target end
	if slot(target) and State.CameraSection~=target then section(target) elseif not slot(target) and State.CameraSection~="ALL" then section("ALL") end
	browser:Hide()
	setPreviewVFXMode(target=="THRUST_COLOR" and "ThrustColour" or "Idle")
	local actionIconScale=math.clamp(tonumber(replacementConfig:GetAttribute("CustomiseActionIconScale")) or .5,.1,1.5)
	local c=common("Paint Shop"); c.TutorialPageId="PaintShop"
	c.CarouselScrollKey="PaintShop|"..tostring(target).."|"..tostring(State.CustomizeMode)
	c.CategoryScrollKey="PaintShopTargetRail"
	c.Subtitle=State.CustomizeMode=="Colour" and "Choose a paint channel and colour." or "Choose a vehicle area to paint or light."
	c.ShowStats=false
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.LeftCardMode=true
	c.LeftFloating=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78
	c.LeftItems={}
	c.Cards={}
	paintTargetRail(c,target)
	if State.CustomizeMode=="Colour" then
		local channels=paintChannels(target)
		local selected=State.SelectedColorChannel
		local valid=false
		for _,channel in ipairs(channels) do if channel==selected then valid=true; break end end
		if not valid then selected=channels[1]; State.SelectedColorChannel=selected end
		c.ColorChannels=channels
		c.SelectedChannel=selected
		c.Colors=paintColours(target,channels)
		c.OnChannel=function(channel) State.SelectedColorChannel=channel; renderPaintShop() end
		c.OnColor=function(channel,color,commit) handlePaint(target,channel,color,commit) end
	else
		addPaintOverviewCards(c,target,actionIconScale)
	end
	c.OnBack=function()
		clearTransientModulePreview()
		State.SelectedPaintAction=nil
		if State.CustomizeMode=="Colour" then
			if target=="ALL" or target=="Cockpit" or target=="THRUST_COLOR" or target=="UNDERGLOW" then buildPreview(); renderHub() else State.CustomizeMode="Overview"; renderPaintShop() end
		else
			buildPreview()
			renderHub()
		end
	end
	c.OnNext=driveFromGarage
	buildPreview()
	workspaceUI:Show(c)
end
local function open(mode,payload)
	if active then if typeof(payload)=="table" and payload.LoadingGeneration then loadingAction("Complete",{Generation=payload.LoadingGeneration,Status="READY"}) end; return end
	local generation
	if mode~="Dealership" then
		local access=action:Call("EnsureCustomisationAccess",{})
		if not access.Success then
			local reason=tostring(access.Message or "Customisation access is unavailable.")
			local notification=uiFolder:FindFirstChild("ShowTopNotification")
			if notification and notification:IsA("BindableEvent") then notification:Fire(reason) end
			if reason=="OWN A VEHICLE TO CUSTOMISE" then AudioBridge.Emit("UI.PurchaseRejected",{Reason="VehicleRequired",Route="CustomisationShortcut"}) end
			action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil)
			return
		end
	end
	generation=entryLoading(mode,payload)
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
