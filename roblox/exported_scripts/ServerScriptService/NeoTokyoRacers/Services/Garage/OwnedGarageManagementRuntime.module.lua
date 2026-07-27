-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V1
-- NTR_SMALL_REFINEMENTS_LIFECYCLE_PHASE2_V1
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V2_NAMESPACED_RESET
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V4_VERTICAL_SLICE
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V5_AUTHORITATIVE_MUTATION_STATE
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY
-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS
-- NTR_OWNED_GARAGE_STRUCTURE_MANAGEMENT_V1
-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_RUNTIME_V1
-- NTR_OWNED_GARAGE_DECORATION_MANAGEMENT_V1
-- NTR_OWNED_GARAGE_LIGHTING_MANAGEMENT_V1
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_MANAGEMENT_V1
-- NTR_OWNED_GARAGE_SHARED_FINISH_MANAGEMENT_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_MANAGEMENT
-- NTR_OWNED_GARAGE_PHASE13_V1_2_STREAMING_HANDSHAKE
-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS
-- NTR_OWNED_GARAGE_PHASE14_V1_LIGHTING_STATE_FOUNDATION
-- NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local Workspace=game:GetService("Workspace")
local Runtime={}; local started=false
function Runtime.ChooseSlot(displaySpaces,requestedSlotId,orderedSlotIds)
	displaySpaces=type(displaySpaces)=="table" and displaySpaces or {}; requestedSlotId=tostring(requestedSlotId or ""); orderedSlotIds=type(orderedSlotIds)=="table" and orderedSlotIds or {"Space01","Space02"}
	if requestedSlotId~="" then if displaySpaces[requestedSlotId]~=nil then return requestedSlotId,"Requested" end; return nil,"Invalid" end
	for _,slotId in ipairs(orderedSlotIds) do if displaySpaces[slotId]==false or displaySpaces[slotId]==nil or tostring(displaySpaces[slotId])=="" then return slotId,"Empty" end end
	return nil,"Full"
end
function Runtime.Start()
	if started then return true,"AlreadyStarted" end
	local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local DisplayNames=require(kit.Shared.Modules.Common:WaitForChild("VehicleDisplayNames")); local categoriesRoot=kit.Assets.Vehicles:WaitForChild("Categories"); local remotes=kit.Shared.Remotes.Garage; local invoke=remotes:WaitForChild("OwnedGarageInvoke"); local push=remotes:WaitForChild("OwnedGarageEvent"); local catalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGaragePropertyCatalog")); local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")); local decorationCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog")); local lightingCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageLightingCatalog"))
	local services=ServerScriptService.NeoTokyoRacers.Services; local garage=services.Garage; local Profile=require(garage:WaitForChild("OwnedGarageProfileRuntime")); local finishRuntime=require(garage:WaitForChild("OwnedGarageFinishRuntime")); local Assignment=require(garage:WaitForChild("OwnedGarageDisplayAssignmentRuntime")); local Interior=require(garage:WaitForChild("OwnedGarageInteriorRuntime")); local Display=require(garage:WaitForChild("OwnedGarageDisplayRuntime")); local lifecycle=garage:WaitForChild("OwnedGarageVehicleLifecycleBridge")
	local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local executeOwnedGarageCommand=bindings:WaitForChild("ExecuteOwnedGarageCommand"); local saveNow=bindings:WaitForChild("SaveNow"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local world=Workspace:WaitForChild("NeoTokyoRacersWorld"); local exteriorRoot=world:WaitForChild("OwnedGarageExteriors"); local interiors=world:FindFirstChild("Interiors") or Instance.new("Folder"); interiors.Name="Interiors"; interiors.Parent=world; local pool=interiors:FindFirstChild("OwnedGarageInstances") or Instance.new("Folder"); pool.Name="OwnedGarageInstances"; pool:SetAttribute("OwnedGarageRuntimePool",true); pool.Parent=interiors
	local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode="k"}); local requestWindows=setmetatable({},{__mode="k"}); local streamRequests=setmetatable({},{__mode="k"}); local stateFor; local driveOut,exitOnFoot
	local function clearStreamRequest(player)
		streamRequests[player]=nil
	end
	local function streamDestination(player,position,details)
		if typeof(position)~="Vector3" then return false,"Streaming destination is missing." end
		details=type(details)=="table" and details or {}
		local token=HttpService:GenerateGUID(false); local timeout=math.clamp(tonumber(settings:GetAttribute("GarageStreamTimeoutSeconds")) or 8,3,15); local request={Token=token,Done=false,Success=false,StartedAt=os.clock()}; streamRequests[player]=request
		player:SetAttribute("NTR_OwnedGarageStreamState","REQUESTED"); player:SetAttribute("NTR_OwnedGarageStreamToken",token); player:SetAttribute("NTR_OwnedGarageLastStreamError",nil)
		push:FireClient(player,{Type="OwnedGarageStreamRequest",Token=token,Position=position,TimeoutSeconds=timeout,DestinationType=details.DestinationType,InteriorName=details.InteriorName,ExteriorId=details.ExteriorId,MarkerName=details.MarkerName})
		local deadline=os.clock()+timeout
		while streamRequests[player]==request and not request.Done and os.clock()<deadline and player.Parent do task.wait(.05) end
		local elapsed=os.clock()-request.StartedAt; local success=request.Done and request.Success==true; local message=success and nil or tostring(request.Message or (request.Done and "Destination streaming failed." or "Destination streaming timed out."))
		if streamRequests[player]==request then streamRequests[player]=nil end
		player:SetAttribute("NTR_OwnedGarageStreamToken",nil); player:SetAttribute("NTR_OwnedGarageLastStreamSeconds",elapsed); player:SetAttribute("NTR_OwnedGarageStreamState",success and "READY" or "FAILED"); player:SetAttribute("NTR_OwnedGarageLastStreamError",message)
		return success,message
	end
	push.OnServerEvent:Connect(function(player,message)
		if type(message)~="table" or message.Type~="OwnedGarageStreamReady" then return end
		local request=streamRequests[player]; if not request or request.Done or tostring(message.Token or "")~=request.Token then return end
		request.Done=true; request.Success=message.Success==true; request.Message=tostring(message.Message or "")
	end)
	local function profileFor(player)
		local initial=getProfile:Invoke(player); if type(initial)~="table" then return nil,"Profile is not loaded." end
		local resetToken=tostring(settings:GetAttribute("TesterResetToken") or ""); local resetUserId=math.floor(tonumber(settings:GetAttribute("TesterResetUserId")) or 0); local existing=type(initial.OwnedGarage)=="table" and initial.OwnedGarage or nil; local shouldReset=player.UserId==resetUserId and resetToken~="" and tostring(existing and existing.TesterResetToken or "")~=resetToken
		local ensured=executeOwnedGarageCommand:Invoke(player,{Operation="Ensure",Reset=shouldReset,ResetToken=resetToken}); if type(ensured)~="table" or not ensured.Success then return nil,tostring(ensured and ensured.Message or "Owned garage state is unavailable.") end
		if ensured.ResetApplied then local saved,saveMessage=saveNow:Invoke(player); if not saved then warn("[NTR Owned Garage] Tester reset save deferred: "..tostring(saveMessage)) end end
		local profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end; return profile
	end
	local function command(player,operation,args,reason,requestId,baseRevision)
		return executeOwnedGarageCommand:Invoke(player,{Operation=operation,Args=args,Reason=reason,RequestId=requestId or Profile.NewRequestId(),BaseRevision=baseRevision})
	end
	local function compensate(player,snapshot,baseRevision,reason)
		local result=executeOwnedGarageCommand:Invoke(player,{Operation="Restore",State=snapshot,Reason=reason,RequestId=Profile.NewRequestId(),BaseRevision=baseRevision}); if type(result)~="table" or not result.Success then warn("[NTR Owned Garage] compensation failed: "..tostring(result and result.Message or "unavailable")); return false end; return true
	end
	local function lifecycleCall(action,player,payload)
		payload=type(payload)=="table" and payload or {}; payload.Player=player; local ok,result=pcall(function() return lifecycle:Invoke(action,payload) end)
		if not ok then return {Success=false,Message="Vehicle lifecycle unavailable: "..tostring(result)} end; return type(result)=="table" and result or {Success=false,Message="Invalid vehicle lifecycle response."}
	end
	local function characterRoot(player)
		local character=player.Character; return character and character:FindFirstChild("HumanoidRootPart")
	end
	local function teleportCharacter(player,cframe)
		if typeof(cframe)~="CFrame" then return false,"Destination missing." end
		local attempts=math.clamp(math.floor(tonumber(settings:GetAttribute("GarageTeleportAttempts")) or 2),1,4); local tolerance=math.max(4,tonumber(settings:GetAttribute("GarageTeleportVerifyDistanceStuds")) or 12)
		for _=1,attempts do local character=player.Character; local root=characterRoot(player); if not (character and root) then return false,"Character is not ready." end; character:PivotTo(cframe); root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero; task.wait(); root=characterRoot(player); if root and (root.Position-cframe.Position).Magnitude<=tolerance then return true end end
		return false,"Character teleport could not be verified."
	end
	local function exteriorCFrame(propertyId,markerName)
		local definition=catalog.ById(propertyId); local exteriorId=definition and tostring(definition.ExteriorSpawnId or "") or ""; local folder=exteriorId~="" and exteriorRoot:FindFirstChild(exteriorId); local marker=folder and folder:FindFirstChild(markerName)
		if not (marker and marker:IsA("BasePart")) then return nil,"Exterior spawn missing for "..tostring(propertyId).."/"..tostring(markerName) end; return marker.CFrame
	end
	local function slotIndex(player)
		if slotByUserId[player.UserId] then return slotByUserId[player.UserId] end; local used={}; for _,index in pairs(slotByUserId) do used[index]=true end; local index=1; while used[index] do index+=1 end; slotByUserId[player.UserId]=index; return index
	end
	local function disconnectPrompts(interior)
		for _,connection in pairs(promptConnections[interior] or {}) do
			if typeof(connection)=="RBXScriptConnection" then connection:Disconnect() end
		end
		promptConnections[interior]=nil
	end
	local function bindPrompt(interior,prompt,callback)
		if not (interior and prompt and prompt:IsA("ProximityPrompt") and type(callback)=="function") then return false end
		local registry=promptConnections[interior]
		if not registry then registry={}; promptConnections[interior]=registry end
		local previous=registry[prompt]
		if typeof(previous)=="RBXScriptConnection" then previous:Disconnect() end
		registry[prompt]=prompt.Triggered:Connect(callback)
		return true
	end
	local function scheduleUnload(interior,player)
		task.delay(math.max(0,tonumber(settings:GetAttribute("InteriorUnloadDelaySeconds")) or 20),function() if interior and interior.Parent and not sessions[player] then disconnectPrompts(interior); interior:Destroy() end end)
	end
	local function setInside(player,session)
		player:SetAttribute("NTR_OwnedGarageInside",session~=nil); player:SetAttribute("NTR_OwnedGaragePropertyId",session and session.PropertyId or nil); player:SetAttribute("NTR_OwnedGarageOwnerUserId",session and player.UserId or nil)
	end
	local function featureEnabled(name,default) local value=settings:GetAttribute("Enable"..name); if value==nil then return default end; return value==true end
	local function capabilities(propertyId) local result=catalog.Capabilities(propertyId); for name,value in pairs(result) do result[name]=value==true and featureEnabled(name,name=="DisplayCars") end; return result end
	local function applyPromptPolicy(session)
		if not (session and session.Interior) then return end; local blocked=session.ManagementOpen==true or session.Transition~=nil
		for _,prompt in ipairs(session.Interior:GetDescendants()) do if prompt:IsA("ProximityPrompt") and (prompt.Name=="DriveOutPrompt" or prompt.Name=="FootExitPrompt" or prompt.Name=="ManageGaragePrompt") then prompt.HoldDuration=0; prompt.Enabled=not blocked and prompt:GetAttribute("OwnedGarageAvailable")~=false end end
	end
	local function allowRequest(player,action)
		local now=os.clock(); local window=requestWindows[player]; if not window or now-window.Start>=1 then window={Start=now,Count=0}; requestWindows[player]=window end; window.Count+=1; local maximum=(action=="GetState" or action=="GetManagementState") and (tonumber(settings:GetAttribute("ReadRequestsPerSecond")) or 20) or (tonumber(settings:GetAttribute("MutationRequestsPerSecond")) or 12); return window.Count<=maximum
	end
	local function vehicleName(profile,vehicleId)
		return DisplayNames.FullVehicleName(profile,vehicleId,categoriesRoot)
	end
	local function swapRuntimeModel(runtime,key,model)
		local old=runtime:FindFirstChild(key); local stale=runtime:FindFirstChild(key.."__Next"); if stale then stale:Destroy() end; model.Name=key.."__Next"; model:SetAttribute("RuntimeGeneration",HttpService:GenerateGUID(false)); model.Parent=runtime; if old then old:Destroy() end; model.Name=key; return model
	end
	local function structurePreview(session,section) return (session.StructurePreviewAll and session.StructurePreviewAll[section]) or (session.StructurePreview and session.StructurePreview.SectionId==section and session.StructurePreview) or nil end
	local function decorationPreview(session,slotId) return (session.DecorationPreviewAll and session.DecorationPreviewAll[slotId]) or (session.DecorationPreview and session.DecorationPreview.SlotId==slotId and session.DecorationPreview) or nil end
	local function applyInteriorStyles(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local sections=definition and definition.StructureSections or {}; local structureState=styleCatalog.NormalizeStructure(property and property.Customisation and property.Customisation.Structure,sections); local slots=session.Interior:FindFirstChild("StructureSlots"); if not slots then return false,"Structure asset contract is missing." end
		local runtime=session.Interior:FindFirstChild("StructureRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="StructureRuntime"; runtime.Parent=session.Interior end
		for _,base in ipairs(session.Interior:GetDescendants()) do if base:IsA("BasePart") and base:GetAttribute("StructureSection") and not base:IsDescendantOf(runtime) and not base:IsDescendantOf(slots) then base.Transparency=1; base.CanCollide=false; base.CanTouch=false; base.CanQuery=false end end
		for _,section in ipairs(sections) do local preview=structurePreview(session,section); local selected=preview or structureState.Sections[section]; local style=selected and styleCatalog.ById(section,selected.StyleId); local slot=slots:FindFirstChild(section); local asset=style and finishRuntime.StructureAsset(definition.TemplateId,section,style.AssetOption); if not (style and slot and slot:IsA("BasePart") and asset) then return false,"Structure asset missing: "..tostring(section).."/"..tostring(style and style.AssetOption or "") end; local current=runtime:FindFirstChild(section); if current and current:GetAttribute("StructureStyleId")==style.StyleId then finishRuntime.Apply(current,"Structure",selected); current:SetAttribute("StructurePreview",preview~=nil) else local origin=session.Interior:FindFirstChild("TemplateOrigin",true); local placementAnchor=asset:GetAttribute("GaragePlacementMode")=="TemplateOrigin" and origin or slot; local model,message=finishRuntime.CloneAt(asset,placementAnchor,"Structure",selected,section); if not model then return false,message end; model:SetAttribute("StructureSection",section); model:SetAttribute("StructureStyleId",style.StyleId); model:SetAttribute("StructurePreview",preview~=nil); swapRuntimeModel(runtime,section,model) end end; return true
	end
	local function applyDecorations(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local slotDefinitions=definition and definition.DecorationSlots or {}; local decorationsState=decorationCatalog.Normalize(property and property.Customisation and property.Customisation.Decorations,slotDefinitions); for _,slot in ipairs(slotDefinitions) do local group=tostring(slot.HideSurfaceGroup or ""); if group~="" then for _,object in ipairs(session.Interior:GetDescendants()) do if object:IsA("BasePart") and object:GetAttribute("SurfaceGroup")==group then local original=object:GetAttribute("NTRGarageOriginalTransparency"); if original==nil then object:SetAttribute("NTRGarageOriginalTransparency",object.Transparency); object:SetAttribute("NTRGarageOriginalCanCollide",object.CanCollide); object:SetAttribute("NTRGarageOriginalCanTouch",object.CanTouch); object:SetAttribute("NTRGarageOriginalCanQuery",object.CanQuery); original=object.Transparency end; object.Transparency=original; object.CanCollide=object:GetAttribute("NTRGarageOriginalCanCollide")==true; object.CanTouch=object:GetAttribute("NTRGarageOriginalCanTouch")==true; object.CanQuery=object:GetAttribute("NTRGarageOriginalCanQuery")==true end end end end; local slotRoot=session.Interior:FindFirstChild("DecorationSlots"); if not slotRoot then return false,"Decoration slots are missing." end
		for _,slot in ipairs(slotDefinitions) do local activePlacement=decorationPreview(session,slot.SlotId) or decorationsState.Placements[slot.SlotId]; local hideSurface=tostring(slot.HideSurfaceGroup or ""); if activePlacement and hideSurface~="" then for _,object in ipairs(session.Interior:GetDescendants()) do if object:IsA("BasePart") and object:GetAttribute("SurfaceGroup")==hideSurface and not object:IsDescendantOf(session.Interior:FindFirstChild("DecorationRuntime") or slotRoot) then object.Transparency=1; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false end end end; local rootName=tostring(slot.HideTemplateModel or ""); local rootModel=rootName~="" and session.Interior:FindFirstChild(rootName); if rootModel then local promptAnchor=rootModel:FindFirstChild("DeskPromptAnchor"); for _,object in ipairs(rootModel:GetDescendants()) do if object:IsA("BasePart") and object~=promptAnchor and not (promptAnchor and object:IsDescendantOf(promptAnchor)) then object.Transparency=1; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false elseif object:IsA("Light") or object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then object.Enabled=false end end end end
		local runtime=session.Interior:FindFirstChild("DecorationRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="DecorationRuntime"; runtime.Parent=session.Interior end
		for _,slot in ipairs(slotDefinitions) do local slotId=slot.SlotId; local preview=decorationPreview(session,slotId); local placement=preview or decorationsState.Placements[slotId]; local current=runtime:FindFirstChild(slotId); if not placement then if current then current:Destroy() end else local item=decorationCatalog.ById(placement.ItemId); local anchorName=tostring(slot.AnchorId or slotId); local anchor=slotRoot:FindFirstChild(anchorName) or session.Interior:FindFirstChild(anchorName,true); local asset=item and finishRuntime.DecorationAsset(definition.TemplateId,slotId,item.AssetName,item.AssetGroupId or slot.AssetGroupId); local placementAnchor=asset and asset:GetAttribute("GaragePlacementMode")=="TemplateOrigin" and session.Interior:FindFirstChild("TemplateOrigin",true) or anchor; if not (item and placementAnchor and placementAnchor:IsA("BasePart") and asset and finishRuntime.IsDecorationAvailable(definition.TemplateId,item)) then return false,"Decoration asset missing or unavailable: "..tostring(placement.ItemId).."/"..tostring(slotId) end; if current and current:GetAttribute("DecorationItemId")==item.ItemId then finishRuntime.Apply(current,"Decoration",placement); current:SetAttribute("DecorationPreview",preview~=nil) else local model,message=finishRuntime.CloneAt(asset,placementAnchor,"Decoration",placement,slotId); if not model then return false,message end; model:SetAttribute("DecorationSlotId",slotId); model:SetAttribute("DecorationItemId",item.ItemId); model:SetAttribute("DecorationPreview",preview~=nil); swapRuntimeModel(runtime,slotId,model) end end end; return true
	end
	local function configureLightingModel(model,preset,lighting,enabled)
		for _,object in ipairs(model:GetDescendants()) do if object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Brightness=math.max(0,tonumber(preset.Brightness) or object.Brightness)*math.clamp(tonumber(lighting.Intensity) or 1,.5,1.5); if object:IsA("PointLight") or object:IsA("SpotLight") then object.Range=math.min(36,math.max(8,tonumber(preset.Range) or object.Range)) end; object.Shadows=false; object.Enabled=enabled==true end end
	end
	local function applyLighting(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local lighting=lightingCatalog.Normalize(property and property.Customisation and property.Customisation.Lighting); if session.LightingPreview then lighting=session.LightingPreview end; local preset=lightingCatalog.ById(lighting.PresetId); local asset=preset and finishRuntime.LightingAsset(definition and definition.TemplateId,preset.AssetName); local origin=session.Interior:FindFirstChild("TemplateOrigin",true); if not (preset and asset and origin and origin:IsA("BasePart")) then return false,"Garage lighting contract is missing." end
		local runtime=session.Interior:FindFirstChild("LightingRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="LightingRuntime"; runtime.Parent=session.Interior end; local appearance=lightingCatalog.Finish(lighting,preset.PresetId); local current=runtime:FindFirstChild("WholeGarageLighting"); if current and current:GetAttribute("LightingPresetId")==preset.PresetId then finishRuntime.Apply(current,"Lighting",appearance); configureLightingModel(current,preset,lighting,true); current:SetAttribute("LightingPreview",session.LightingPreview~=nil); return true end
		local model,message=finishRuntime.CloneAt(asset,origin,"Lighting",appearance,"WholeGarageLighting"); if not model then return false,message end; configureLightingModel(model,preset,lighting,true); model:SetAttribute("LightingPresetId",preset.PresetId); model:SetAttribute("LightingPreview",session.LightingPreview~=nil); swapRuntimeModel(runtime,"WholeGarageLighting",model); return true
	end
	local function renderDisplays(player,profile,session)
		-- NTR_OWNED_GARAGE_PROMPT_REGISTRY_V1
		local property=profile.OwnedGarage.Properties[session.PropertyId]
		local markers=session.Interior:FindFirstChild("DisplaySpaceMarkers")
		if not markers then return false,"Display markers missing." end
		local definition=catalog.ById(session.PropertyId)
		for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do
			local boundSlotId=tostring(slotId)
			Display.Clear(session.Interior,boundSlotId)
			local marker=markers:FindFirstChild(boundSlotId)
			if not marker then return false,"Display marker missing: "..boundSlotId end
			local prompt=marker:FindFirstChild("DriveOutPrompt")
			if not prompt then
				prompt=Instance.new("ProximityPrompt")
				prompt.Name="DriveOutPrompt"
				prompt.Parent=marker
			end
			if not prompt:IsA("ProximityPrompt") then return false,"Drive-out prompt contract invalid: "..boundSlotId end
			prompt.ActionText="Drive Out"
			prompt.KeyboardKeyCode=Enum.KeyCode.E
			prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
			prompt.HoldDuration=0
			prompt.MaxActivationDistance=12
			prompt.RequiresLineOfSight=false
			prompt.ClickablePrompt=true
			bindPrompt(session.Interior,prompt,function(triggeringPlayer)
				if triggeringPlayer==player then
					local result=driveOut(player,boundSlotId)
					push:FireClient(player,{Type="DriveOutResult",Success=result.Success==true,Message=result.Message})
				end
			end)
			local vehicleId=property.DisplaySpaces[boundSlotId]
			local available=vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~=""
			prompt:SetAttribute("OwnedGarageAvailable",available)
			prompt.ObjectText=available and vehicleName(profile,vehicleId) or "Empty Display Space"
			if available then
				local model,message=Display.Build(profile,tostring(vehicleId),marker,session.Interior)
				if not model then return false,message end
			end
		end
		applyPromptPolicy(session)
		return true
	end
	local function configurePrompts(player,profile,session)
		-- NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_FOOT_EXIT_RESULT_V1
		local foot=session.Interior:FindFirstChild("FootExitPrompt",true)
		if foot then
			foot.HoldDuration=0
			foot:SetAttribute("OwnedGarageAvailable",true)
			bindPrompt(session.Interior,foot,function(triggeringPlayer)
				if triggeringPlayer==player then
					local result=exitOnFoot(player)
					push:FireClient(player,{Type="FootExitResult",Success=result.Success==true,Message=result.Message})
				end
			end)
		end
		local desk=session.Interior:FindFirstChild("ManageGaragePrompt",true)
		if desk then
			desk.HoldDuration=0
			desk:SetAttribute("OwnedGarageAvailable",true)
			bindPrompt(session.Interior,desk,function(triggeringPlayer)
				if triggeringPlayer==player then
					push:FireClient(player,{Type="OpenManagement",PropertyId=session.PropertyId})
				end
			end)
		end
		return renderDisplays(player,profile,session)
	end
	local function ensureSession(player,profile,propertyId)
		if sessions[player] then return sessions[player] end; local definition=catalog.ById(propertyId); local property=profile.OwnedGarage.Properties[propertyId]; if not (definition and property and property.Owned) then return nil,"Garage is not owned." end
		if #pool:GetChildren()>=(tonumber(settings:GetAttribute("MaxActiveInteriorsPerServer")) or 24) then return nil,"Garage interiors are currently at capacity." end; local interior,message=Interior.Create(pool,player.UserId,propertyId,definition.TemplateId,slotIndex(player)); if not interior then return nil,message end; if tonumber(interior:GetAttribute("OwnedGarageTemplateVersion"))~=tonumber(definition.TemplateContractVersion) then interior:Destroy(); return nil,"Garage template version is incompatible." end; disconnectPrompts(interior)
		local session={Interior=interior,PropertyId=propertyId}; sessions[player]=session
		local styled,styleMessage=applyInteriorStyles(profile,session); if not styled then sessions[player]=nil; scheduleUnload(interior,player); return nil,styleMessage end; local decorated,decorationMessage=applyDecorations(profile,session); if not decorated then sessions[player]=nil; scheduleUnload(interior,player); return nil,decorationMessage end; local lit,lightingMessage=applyLighting(profile,session); if not lit then sessions[player]=nil; scheduleUnload(interior,player); return nil,lightingMessage end; local configured,configureMessage=configurePrompts(player,profile,session); if not configured then sessions[player]=nil; setInside(player,nil); scheduleUnload(interior,player); return nil,configureMessage end
		return session
	end
	local function abandonSession(player,session)
		clearStreamRequest(player); if sessions[player]==session then sessions[player]=nil end; setInside(player,nil); if session and session.Interior then scheduleUnload(session.Interior,player) end
	end
	exitOnFoot=function(player)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; session.Transition="FootExit"; applyPromptPolicy(session)
		local destination,destinationMessage=exteriorCFrame(session.PropertyId,"FootExitSpawn"); if not destination then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=destinationMessage} end
		local streamed,streamMessage=streamDestination(player,destination.Position,{DestinationType="Exterior",ExteriorId=tostring((catalog.ById(session.PropertyId) or {}).ExteriorSpawnId or ""),MarkerName="FootExitSpawn"}); if not streamed then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=streamMessage} end; local ok,message=teleportCharacter(player,destination); if not ok then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=message} end; sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); return {Success=true,Message="Returned to the city."}
	end
	local function enterOnFoot(player,profile,propertyId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if driven.Success then return {Success=false,Message="Use Drive In while seated in your vehicle."} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local streamed,streamMessage=streamDestination(player,spawn and spawn.Position,{DestinationType="Interior",InteriorName=session.Interior.Name,MarkerName="CharacterSpawn"}); if not streamed then abandonSession(player,session); return {Success=false,Message=streamMessage} end; local ok,teleportMessage=teleportCharacter(player,spawn and spawn.CFrame); if not ok then abandonSession(player,session); return {Success=false,Message=teleportMessage} end
		setInside(player,session); return {Success=true,Message="Entered garage.",PropertyId=propertyId}
	end
	local function replacementSlots(profile,propertyId)
		local result={}; local display=profile.OwnedGarage.Properties[propertyId].DisplaySpaces; local definition=catalog.ById(propertyId); for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do local vehicleId=display[slotId]; table.insert(result,{SlotId=slotId,VehicleId=vehicleId,DisplayName=vehicleName(profile,vehicleId)}) end; return result
	end
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if settings:GetAttribute("DriveInSpeedGateEnabled")==true and tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local existingSlot; for candidate,assigned in pairs(property.DisplaySpaces or {}) do if tostring(assigned or "")==tostring(driven.VehicleId) then existingSlot=tostring(candidate); break end end
		local definition=catalog.ById(propertyId); local slotId,reason=existingSlot,"Existing"; if not slotId then slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId,definition and definition.DisplaySpaceIds) end; if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; if not characterRoot(player) then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end; session.Transition="DriveIn"; applyPromptPolicy(session)
		local entrySpawn=session.Interior:FindFirstChild("CharacterSpawn",true); local streamed,streamMessage=streamDestination(player,entrySpawn and entrySpawn.Position,{DestinationType="Interior",InteriorName=session.Interior.Name,MarkerName="CharacterSpawn"}); if not streamed then abandonSession(player,session); return {Success=false,Message=streamMessage} end
		local before=Profile.Snapshot(profile); local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId,PreserveCharacterPosition=true,WaitForDetach=true,DetachTimeoutSeconds=settings:GetAttribute("GarageSeatDetachTimeoutSeconds")}); if not despawn.Success then if despawn.VehicleRemoved then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}) end; abandonSession(player,session); return {Success=false,Message=despawn.Message or "Vehicle could not enter the garage."} end
		local result={Success=true,Revision=profile.OwnedGarage.Revision}; local changed=existingSlot==nil
		if changed then result=command(player,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},"OwnedGarageDriveIn",tostring(driven.RequestId or Profile.NewRequestId()),profile.OwnedGarage.Revision) end
		if type(result)~="table" or not result.Success then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}); abandonSession(player,session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawn=entrySpawn; local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame); if not moved then local restored=not changed or compensate(player,before,result.Revision,"OwnedGarageDriveInTeleportRollback"); if restored then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame}) end; abandonSession(player,session); return {Success=false,Message=restored and moveMessage or (moveMessage.." Saved assignment recovery also failed; vehicle remains stored.")} end
		session.Transition=nil; setInside(player,session); local committed=getProfile:Invoke(player); local rendered,renderMessage=false,"Committed profile unavailable."; if type(committed)=="table" then rendered,renderMessage=renderDisplays(player,committed,session) end; return {Success=true,Message=existingSlot and "Vehicle returned to its display space." or (reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage."),PropertyId=propertyId,SlotId=slotId,Revision=result.Revision,PresentationWarning=rendered and nil or renderMessage}
	end
	local function verifyDriveOutVehicle(player,vehicle,spawnCFrame)
		if not (typeof(vehicle)=="Instance" and vehicle:IsA("Model")) then return false,"Spawned vehicle reference is missing." end
		local timeout=math.clamp(tonumber(settings:GetAttribute("GarageDriveOutVerifySeconds")) or 2.5,.5,6)
		local tolerance=math.max(12,tonumber(settings:GetAttribute("GarageDriveOutVerifyDistanceStuds")) or 40)
		local deadline=os.clock()+timeout
		repeat
			local character=player.Character
			local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			local root=characterRoot(player)
			local seat=humanoid and humanoid.SeatPart
			local vehiclePosition
			if vehicle.Parent then
				local ok,pivot=pcall(function() return vehicle:GetPivot() end)
				if ok then vehiclePosition=pivot.Position end
			end
			local seated=seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
			local characterNear=root and (root.Position-spawnCFrame.Position).Magnitude<=tolerance
			local vehicleNear=vehiclePosition and (vehiclePosition-spawnCFrame.Position).Magnitude<=tolerance
			if vehicle.Parent and seated and characterNear and vehicleNear then return true end
			task.wait(.05)
		until os.clock()>=deadline or not player.Parent
		return false,"Vehicle was created, but the exterior seat/position handoff could not be verified."
	end
	local function recoverDriveOut(player,session,before,result,vehicleId,vehicle,message)
		local hasVehicle=typeof(vehicle)=="Instance"
		local cleanup=hasVehicle and lifecycleCall("DespawnForGarage",player,{VehicleId=tostring(vehicleId),PreserveCharacterPosition=true,WaitForDetach=true,DetachTimeoutSeconds=settings:GetAttribute("GarageSeatDetachTimeoutSeconds")}) or {Success=true}
		if hasVehicle and vehicle.Parent then pcall(function() vehicle:Destroy() end) end
		local restored=compensate(player,before,result.Revision,"OwnedGarageDriveOutVerifiedRollback")
		task.wait()
		local interiorSpawn=session.Interior and session.Interior:FindFirstChild("CharacterSpawn",true)
		local returned,returnMessage=teleportCharacter(player,interiorSpawn and interiorSpawn.CFrame)
		session.Transition=nil
		setInside(player,session)
		applyPromptPolicy(session)
		local committed=getProfile:Invoke(player)
		if type(committed)=="table" then renderDisplays(player,committed,session) end
		local details=tostring(message or "Vehicle could not leave the garage.")
		if not cleanup.Success and hasVehicle then details=details.." Runtime cleanup used the verified fallback." end
		if not restored then details=details.." Display assignment recovery failed; retry after the profile refreshes." end
		if not returned then details=details.." Interior return also failed: "..tostring(returnMessage) end
		return {Success=false,Message=details,Recovered=restored and returned}
	end
	driveOut=function(player,slotId)
		-- NTR_OWNED_GARAGE_DRIVE_OUT_VERIFIED_COMPLETION_V1
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message="Display space is empty."} end
		local spawnCFrame,spawnMessage=exteriorCFrame(session.PropertyId,"VehicleExitSpawn"); if not spawnCFrame then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=spawnMessage} end
		local streamed,streamMessage=streamDestination(player,spawnCFrame.Position,{DestinationType="Exterior",ExteriorId=tostring((catalog.ById(session.PropertyId) or {}).ExteriorSpawnId or ""),MarkerName="VehicleExitSpawn"}); if not streamed then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message=streamMessage} end
		local before=Profile.Snapshot(profile); local result=command(player,"Clear",{GarageId=session.PropertyId,SlotId=slotId},"OwnedGarageDriveOut",Profile.NewRequestId(),profile.OwnedGarage.Revision); if type(result)~="table" or not result.Success then session.Transition=nil; applyPromptPolicy(session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame})
		if not spawned.Success then return recoverDriveOut(player,session,before,result,vehicleId,spawned.Vehicle,spawned.Message) end
		local verified,verifyMessage=verifyDriveOutVehicle(player,spawned.Vehicle,spawnCFrame)
		if not verified then return recoverDriveOut(player,session,before,result,vehicleId,spawned.Vehicle,verifyMessage) end
		sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}); return {Success=true,Message="Vehicle spawned from garage.",VehicleId=tostring(vehicleId),Revision=result.Revision}
	end
	local function managedOperation(player,profile,operation,args)
		local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId; local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or ((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="ConfigureDecoration" and "Decorations" or (operation=="ConfigureLighting" and "Lighting" or (operation=="SetAccessMode" and "Access" or (operation=="SetInvitation" and "Invitations"))))); if required and capabilities(session.PropertyId)[required]~=true then return {Success=false,Message=required.." is not enabled for this garage."} end
		local result=command(player,operation,args,"OwnedGarageManagement:"..operation,tostring(args.RequestId or Profile.NewRequestId()),args.BaseRevision); local committed=getProfile:Invoke(player); if type(committed)~="table" then return {Success=false,Message="Committed profile could not be read."} end
		if type(result)~="table" then return {Success=false,Message="Owned garage command unavailable."} elseif not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,committed,session) elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then applyInteriorStyles(committed,session) elseif operation=="ConfigureDecoration" then applyDecorations(committed,session) elseif operation=="ConfigureLighting" then applyLighting(committed,session) end; return result end
		local presented,presentationMessage=true,nil; if operation=="Assign" or operation=="Clear" then presented,presentationMessage=renderDisplays(player,committed,session) elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then session.StructurePreview=nil; session.StructurePreviewAll=nil; presented=applyInteriorStyles(committed,session) elseif operation=="ConfigureDecoration" then session.DecorationPreview=nil; session.DecorationPreviewAll=nil; presented=applyDecorations(committed,session) elseif operation=="ConfigureLighting" then session.LightingPreview=nil; presented=applyLighting(committed,session) end; if not presented then result.PresentationWarning=presentationMessage or "Saved state committed; physical presentation will retry." end
		stateCache[player]=nil; result.ManagementState=stateFor(player,committed); push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}); return result
	end
	local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
	local function vehicleSignature(profile)
		local parts={}; for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpit=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; table.insert(parts,tostring(vehicleId)..":"..tostring((cockpit and cockpit.TemplateId) or vehicle.CockpitId or "")..":"..tostring(vehicle.DisplayName or "")) end end; table.sort(parts); return table.concat(parts,"|")
	end
	local function playerSignature()
		local ids={}; for _,candidate in ipairs(Players:GetPlayers()) do table.insert(ids,candidate.UserId) end; table.sort(ids); local parts={}; for _,id in ipairs(ids) do table.insert(parts,tostring(id)) end; return table.concat(parts,"|")
	end
	local function invitationRows(owner,property)
		local rows={}; local online={}; local invited={}; for _,id in ipairs(property and property.InvitedUserIds or {}) do invited[tonumber(id)]=true end
		for _,candidate in ipairs(Players:GetPlayers()) do if candidate~=owner then online[candidate.UserId]=true; table.insert(rows,{UserId=candidate.UserId,DisplayName=candidate.DisplayName,Username=candidate.Name,Online=true,Invited=invited[candidate.UserId]==true}) end end
		for userId in pairs(invited) do if not online[userId] then table.insert(rows,{UserId=userId,DisplayName="User "..userId,Username="OFFLINE",Online=false,Invited=true}) end end
		table.sort(rows,function(a,b) if a.Invited~=b.Invited then return a.Invited end; if a.Online~=b.Online then return a.Online end; return string.lower(a.DisplayName)<string.lower(b.DisplayName) end); return rows
	end
	stateFor=function(player,profile)
		local session=sessions[player]; local sessionPropertyId=session and session.PropertyId or ""; local revision=math.max(0,math.floor(tonumber(profile.OwnedGarage.Revision) or 0)); local cash=tonumber(profile.Cash or profile.Money or profile.Credits) or 0; local signature=vehicleSignature(profile); local playersSignature=playerSignature(); local cached=stateCache[player]
		if cached and cached.Revision==revision and cached.SessionPropertyId==sessionPropertyId and cached.VehicleSignature==signature and cached.PlayerSignature==playersSignature and cached.Cash==cash then local result=clone(cached.State); result.CacheHit=true; return result end
		local properties={}; for _,definition in ipairs(catalog.List()) do local property=profile.OwnedGarage.Properties[definition.PropertyId]; if property and property.Owned then local filled=0; for _,vehicleId in pairs(property.DisplaySpaces) do if vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~="" then filled+=1 end end; table.insert(properties,{PropertyId=definition.PropertyId,DisplayName=definition.DisplayName,District=definition.District,Description=definition.Description,Image=definition.Image,TemplateId=definition.TemplateId,Capacity=#definition.DisplaySpaceIds,Filled=filled,Capabilities=definition.Capabilities,UI=definition.UI,Definition=catalog.ClientDefinition(definition.PropertyId)}) end end
		local currentProperty=session and profile.OwnedGarage.Properties[session.PropertyId]; local slots={}; local vehicles={}; local surfaceStyles={}
		if currentProperty then local definition=catalog.ById(session.PropertyId); for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do local vehicleId=currentProperty.DisplaySpaces[slotId]; table.insert(slots,{SlotId=slotId,VehicleId=vehicleId,DisplayName=(vehicleId and vehicleId~=false) and vehicleName(profile,vehicleId) or "Empty Display Space"}) end; for surfaceGroup,styleId in pairs(currentProperty.Customisation.SurfaceStyles or {}) do surfaceStyles[surfaceGroup]=styleId end end
		local presentation=lifecycleCall("GetOwnedGarageVehicleCards",player,{}); if presentation.Success then vehicles=presentation.Vehicles or {} else for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=tostring(vehicle.CockpitId or ""),CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or ""),Tier="E",Rating=0,Image=""}) end end end; local propertyNames={}; for _,definition in ipairs(catalog.List()) do propertyNames[definition.PropertyId]=definition.DisplayName end; for _,vehicle in ipairs(vehicles) do vehicle.UsedInOtherGarage=vehicle.DisplayedGarageId~=nil and vehicle.DisplayedGarageId~=sessionPropertyId; vehicle.DisplayedGarageName=vehicle.DisplayedGarageId and propertyNames[vehicle.DisplayedGarageId] or nil end
		table.sort(vehicles,function(a,b) if a.UsedInOtherGarage~=b.UsedInOtherGarage then return not a.UsedInOtherGarage end; if a.Rating~=b.Rating then return a.Rating>b.Rating end; return a.DisplayName<b.DisplayName end)
		local state={Success=true,ApiVersion=catalog.StateApiVersion,DefinitionVersion=catalog.DefinitionVersion,Revision=revision,Properties=properties,ActiveGarageId=profile.OwnedGarage.ActiveGarageId,InGarage=session~=nil,CurrentPropertyId=session and session.PropertyId or nil,Slots=slots,Vehicles=vehicles,SurfaceStyles=surfaceStyles,InteriorStyles=styleCatalog.List(),AccessModes=catalog.AccessModes(),DecorationCategories=catalog.DecorationCategories(),Decorations=currentProperty and decorationCatalog.ClientState(currentProperty.Customisation.Decorations,(catalog.ById(session.PropertyId) or {}).DecorationSlots or {},finishRuntime.DecorationCapabilities((catalog.ById(session.PropertyId) or {}).TemplateId,decorationCatalog)) or nil,Lighting=currentProperty and lightingCatalog.ClientState(currentProperty.Customisation.Lighting,finishRuntime.LightingCapabilities((catalog.ById(session.PropertyId) or {}).TemplateId,lightingCatalog)) or nil,Structure= currentProperty and styleCatalog.ClientState(currentProperty.Customisation.Structure,(catalog.ById(session.PropertyId) or {}).StructureSections or {},finishRuntime.StructureCapabilities((catalog.ById(session.PropertyId) or {}).TemplateId,styleCatalog,(catalog.ById(session.PropertyId) or {}).StructureSections or {})) or nil,Capabilities=session and capabilities(session.PropertyId) or {},AccessMode=currentProperty and currentProperty.AccessMode or "Private",InvitationRows=currentProperty and invitationRows(player,currentProperty) or {},InvitationsEnabled=session and capabilities(session.PropertyId).Invitations==true,VisitorsEnabled=false,Cash=cash,CacheHit=false}
		stateCache[player]={Revision=revision,SessionPropertyId=sessionPropertyId,VehicleSignature=signature,PlayerSignature=playersSignature,Cash=cash,State=clone(state)}; return state
	end
	invoke.OnServerInvoke=function(player,action,args)
		args=type(args)=="table" and args or {}; if not allowRequest(player,action) then return {Success=false,Message="Garage requests are arriving too quickly.",RateLimited=true} end; if locks[player] then return {Success=false,Message="Garage transition already in progress."} end; local now=os.clock(); local controlAction=action=="GetState" or action=="GetManagementState" or action=="SetManagementOpen" or action=="PreviewDisplay" or action=="CancelDisplayPreview" or action=="PreviewStructure" or action=="PreviewStructureFinish" or action=="PreviewStructureFinishAll" or action=="CancelStructurePreview" or action=="PreviewDecoration" or action=="PreviewDecorationFinish" or action=="PreviewDecorationFinishAll" or action=="CancelDecorationPreview" or action=="CancelAllPreviews" or action=="PreviewLighting" or action=="CancelLightingPreview"; if not controlAction and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1) then return {Success=false,Message="Garage transition is cooling down."} end
		locks[player]=true; local ok,result=pcall(function()
			local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local propertyId=tostring(args.PropertyId or profile.OwnedGarage.ActiveGarageId or "STARTER_TWO_BAY")
			if action=="GetState" or action=="GetManagementState" then return stateFor(player,profile)
			elseif action=="SetManagementOpen" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.ManagementOpen=args.Open==true; applyPromptPolicy(session); if session.ManagementOpen then local progress=services.Player:FindFirstChild("OnboardingProgress"); if progress and progress:IsA("BindableEvent") then progress:Fire(player,"GarageManagementEntered") end end; --[[NTR_OWNED_GARAGE_ONBOARDING_MANAGEMENT_V1]] return {Success=true,Message="Management prompt policy updated."}
			elseif action=="PreviewDisplay" then local session=sessions[player]; if not session or capabilities(session.PropertyId).DisplayCars~=true then return {Success=false,Message="Display preview is unavailable."} end; local slotId=tostring(args.SlotId or ""); local vehicleId=tostring(args.VehicleId or ""); if not catalog.IsSpace(session.PropertyId,slotId) or not (profile.Vehicles and profile.Vehicles[vehicleId]) then return {Success=false,Message="Display preview is invalid."} end; local marker=session.Interior:FindFirstChild("DisplaySpaceMarkers") and session.Interior.DisplaySpaceMarkers:FindFirstChild(slotId); if not marker then return {Success=false,Message="Display marker missing."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; for otherSlot,displayedId in pairs(property and property.DisplaySpaces or {}) do if tostring(displayedId or "")==vehicleId and tostring(otherSlot)~=slotId then Display.Clear(session.Interior,tostring(otherSlot)) end end; Display.Clear(session.Interior,slotId); local model,previewMessage=Display.Build(profile,vehicleId,marker,session.Interior); if not model then renderDisplays(player,profile,session); return {Success=false,Message=previewMessage} end; session.PreviewSlotId=slotId; return {Success=true,Message="Preview ready."}
			elseif action=="CancelDisplayPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.PreviewSlotId=nil; local rendered,renderMessage=renderDisplays(player,profile,session); return {Success=rendered==true,Message=renderMessage or "Display preview cleared."}
			elseif action=="PreviewStructure" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local section=tostring(args.SectionId or ""); local style=definition and styleCatalog.ById(section,args.StyleId); if not (session and style) then return {Success=false,Message="Structure preview is invalid."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; local structureState=styleCatalog.NormalizeStructure(property.Customisation.Structure,definition.StructureSections); local finish=structureState.Finishes[style.StyleId] or {Colors={},Materials={}}; session.StructurePreviewAll=nil; session.StructurePreview={SectionId=section,StyleId=style.StyleId,Colors=clone(finish.Colors or {}),Materials=clone(finish.Materials or {})}; local rendered,message=applyInteriorStyles(profile,session); return {Success=rendered==true,Message=message or "Structure preview ready."}
			elseif action=="PreviewStructureFinish" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local section=tostring(args.SectionId or ""); local property=definition and profile.OwnedGarage.Properties[session.PropertyId]; local structureState=property and styleCatalog.NormalizeStructure(property.Customisation.Structure,definition.StructureSections); local committed=structureState and clone(structureState.Sections[section]); local selected=(session and session.StructurePreview and session.StructurePreview.SectionId==section and committed and session.StructurePreview.StyleId==committed.StyleId) and clone(session.StructurePreview) or committed; local style=selected and styleCatalog.ById(section,selected.StyleId); if not (session and selected and style) then return {Success=false,Message="Structure finish preview is invalid."} end; local colors=type(args.Colors)=="table" and args.Colors or {}; local materials=type(args.Materials)=="table" and args.Materials or {}; local valid,message=finishRuntime.ValidateStructureFinish(definition.TemplateId,section,style.AssetOption,colors,materials); if not valid then return {Success=false,Message=message} end; for channel,value in pairs(colors) do selected.Colors[channel]=value end; for channel,value in pairs(materials) do selected.Materials[channel]=value end; selected.SectionId=section; session.StructurePreviewAll=nil; session.StructurePreview=selected; local rendered,renderMessage=applyInteriorStyles(profile,session); return {Success=rendered==true,Message=renderMessage or "Structure finish preview ready."}
			elseif action=="PreviewStructureFinishAll" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local property=definition and profile.OwnedGarage.Properties[session.PropertyId]; local structureState=property and styleCatalog.NormalizeStructure(property.Customisation.Structure,definition.StructureSections); local colors=type(args.Colors)=="table" and args.Colors or {}; local materials=type(args.Materials)=="table" and args.Materials or {}; if not (session and structureState) then return {Success=false,Message="Structure finish preview is invalid."} end; local previews={}; for _,section in ipairs(definition.StructureSections or {}) do local selected=clone(structureState.Sections[section]); local style=selected and styleCatalog.ById(section,selected.StyleId); local asset=style and finishRuntime.StructureAsset(definition.TemplateId,section,style.AssetOption); local capability=asset and finishRuntime.Inspect(asset,"Structure"); if capability then local targetColors={}; local targetMaterials={}; for channel,value in pairs(colors) do if table.find(capability.ColourChannels or {},channel) then targetColors[channel]=value end end; for channel,value in pairs(materials) do if table.find(capability.MaterialChannels or {},channel) then targetMaterials[channel]=value end end; if next(targetColors) or next(targetMaterials) then local valid,message=finishRuntime.ValidateStructureFinish(definition.TemplateId,section,style.AssetOption,targetColors,targetMaterials); if not valid then return {Success=false,Message=message} end; for channel,value in pairs(targetColors) do selected.Colors[channel]=value end; for channel,value in pairs(targetMaterials) do selected.Materials[channel]=value end; selected.SectionId=section; previews[section]=selected end end end; if next(previews)==nil then return {Success=false,Message="No equipped structure supports this finish."} end; session.StructurePreview=nil; session.StructurePreviewAll=previews; local rendered,renderMessage=applyInteriorStyles(profile,session); return {Success=rendered==true,Message=renderMessage or "All-structure preview ready."}
			elseif action=="CancelStructurePreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; if not session.StructurePreview and not session.StructurePreviewAll then return {Success=true,NoChange=true,Message="No structure preview was active."} end; session.StructurePreview=nil; session.StructurePreviewAll=nil; local rendered,message=applyInteriorStyles(profile,session); return {Success=rendered==true,Message=message or "Structure preview cleared."}
			elseif action=="PreviewDecoration" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local slotId=tostring(args.SlotId or args.AnchorId or ""); local item=decorationCatalog.ById(args.ItemId); local slot=definition and decorationCatalog.ZoneById(slotId,definition.DecorationSlots); if not (session and item and slot and item.ZoneId==slotId) then return {Success=false,Message="Decoration preview is invalid."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; local decorationsState=decorationCatalog.Normalize(property.Customisation.Decorations,definition.DecorationSlots); local current=decorationsState.Placements[slotId]; session.DecorationPreviewAll=nil; session.DecorationPreview={SlotId=slotId,ItemId=item.ItemId,Colors=(current and current.ItemId==item.ItemId) and clone(current.Colors) or {}}; local rendered,message=applyDecorations(profile,session); return {Success=rendered==true,Message=message or "Decoration preview ready."}
			elseif action=="PreviewDecorationFinish" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local slotId=tostring(args.SlotId or ""); local property=definition and profile.OwnedGarage.Properties[session.PropertyId]; local decorationsState=property and decorationCatalog.Normalize(property.Customisation.Decorations,definition.DecorationSlots); local placement=decorationsState and decorationsState.Placements[slotId]; local item=placement and decorationCatalog.ById(placement.ItemId); local colors=type(args.Colors)=="table" and args.Colors or {}; local valid,message=finishRuntime.ValidateDecorationFinish(definition and definition.TemplateId,item,colors); if not (session and placement and valid) then return {Success=false,Message=message or "Decoration finish preview is invalid."} end; local preview=(session.DecorationPreview and session.DecorationPreview.SlotId==slotId and session.DecorationPreview.ItemId==item.ItemId) and clone(session.DecorationPreview) or {SlotId=slotId,ItemId=item.ItemId,Colors=clone(placement.Colors)}; for channel,value in pairs(colors) do preview.Colors[channel]=value end; session.DecorationPreviewAll=nil; session.DecorationPreview=preview; local rendered,renderMessage=applyDecorations(profile,session); return {Success=rendered==true,Message=renderMessage or "Decoration finish preview ready."}
			elseif action=="PreviewDecorationFinishAll" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local property=definition and profile.OwnedGarage.Properties[session.PropertyId]; local decorationsState=property and decorationCatalog.Normalize(property.Customisation.Decorations,definition.DecorationSlots); local colors=type(args.Colors)=="table" and args.Colors or {}; if not (session and decorationsState) then return {Success=false,Message="Decoration finish preview is invalid."} end; local previews={}; for _,slot in ipairs(definition.DecorationSlots or {}) do local slotId=tostring(slot.SlotId or ""); local placement=decorationsState.Placements[slotId]; local item=placement and decorationCatalog.ById(placement.ItemId); local asset=item and finishRuntime.DecorationAsset(definition.TemplateId,slotId,item.AssetName,item.AssetGroupId or slot.AssetGroupId); local capability=asset and finishRuntime.Inspect(asset,"Decoration"); if capability then local targetColors={}; for channel,value in pairs(colors) do if table.find(capability.ColourChannels or {},channel) then targetColors[channel]=value end end; if next(targetColors) then local valid,message=finishRuntime.ValidateDecorationFinish(definition.TemplateId,item,targetColors); if not valid then return {Success=false,Message=message} end; local preview={SlotId=slotId,ItemId=item.ItemId,Colors=clone(placement.Colors)}; for channel,value in pairs(targetColors) do preview.Colors[channel]=value end; previews[slotId]=preview end end end; if next(previews)==nil then return {Success=false,Message="No installed decoration supports this colour."} end; session.DecorationPreview=nil; session.DecorationPreviewAll=previews; local rendered,renderMessage=applyDecorations(profile,session); return {Success=rendered==true,Message=renderMessage or "All-decoration preview ready."}
			elseif action=="CancelDecorationPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; if not session.DecorationPreview and not session.DecorationPreviewAll then return {Success=true,NoChange=true,Message="No decoration preview was active."} end; session.DecorationPreview=nil; session.DecorationPreviewAll=nil; local rendered,message=applyDecorations(profile,session); return {Success=rendered==true,Message=message or "Decoration preview cleared."}
			elseif action=="PreviewLighting" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; local committed=lightingCatalog.Normalize(property.Customisation.Lighting); local preset=lightingCatalog.ById(args.PresetId or (session.LightingPreview and session.LightingPreview.PresetId) or committed.PresetId); local definition=catalog.ById(session.PropertyId); if not (preset and finishRuntime.IsLightingAvailable(definition and definition.TemplateId,preset)) then return {Success=false,Message="Lighting preview is invalid."} end; local preview=(session.LightingPreview and session.LightingPreview.PresetId==preset.PresetId) and clone(session.LightingPreview) or clone(committed); preview.PresetId=preset.PresetId; preview.Intensity=lightingCatalog.Level(args.Intensity or preview.Intensity).Value; local colors=type(args.Colors)=="table" and args.Colors or {}; local valid,validateMessage=finishRuntime.ValidateLightingFinish(definition.TemplateId,preset,colors); if not valid then return {Success=false,Message=validateMessage} end; local previewFinish=lightingCatalog.Finish(preview,preset.PresetId); for channel,color in pairs(colors) do previewFinish.Colors[channel]=lightingCatalog.EncodeColor(color) end; session.LightingPreview=preview; local rendered,message=applyLighting(profile,session); return {Success=rendered==true,Message=message or "Lighting preview ready."}
			elseif action=="CancelLightingPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; if not session.LightingPreview then return {Success=true,NoChange=true,Message="No lighting preview was active."} end; session.LightingPreview=nil; local rendered,message=applyLighting(profile,session); return {Success=rendered==true,Message=message or "Lighting preview cleared."}
			elseif action=="CancelAllPreviews" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; local display=session.PreviewSlotId~=nil; local structure=session.StructurePreview~=nil or session.StructurePreviewAll~=nil; local decoration=session.DecorationPreview~=nil or session.DecorationPreviewAll~=nil; local lighting=session.LightingPreview~=nil; session.PreviewSlotId=nil; session.StructurePreview=nil; session.StructurePreviewAll=nil; session.DecorationPreview=nil; session.DecorationPreviewAll=nil; session.LightingPreview=nil; if display then renderDisplays(player,profile,session) end; if structure then applyInteriorStyles(profile,session) end; if decoration then applyDecorations(profile,session) end; if lighting then applyLighting(profile,session) end; return {Success=true,NoChange=not (display or structure or decoration or lighting),Message="Garage previews cleared."}
			elseif action=="EnterSelectedGarage" then local driven=lifecycleCall("GetDrivenVehicle",player,{}); if driven.Success then return enterWithVehicle(player,profile,propertyId,args.ReplacementSlotId) end; return enterOnFoot(player,profile,propertyId)
			elseif action=="EnterOnFoot" then return enterOnFoot(player,profile,propertyId)
			elseif action=="EnterWithVehicle" then return enterWithVehicle(player,profile,propertyId,args.ReplacementSlotId)
			elseif action=="ExitOnFoot" then return exitOnFoot(player)
			elseif action=="DriveOut" then return driveOut(player,tostring(args.SlotId or ""))
			elseif action=="AssignDisplay" then return managedOperation(player,profile,"Assign",{SlotId=tostring(args.SlotId or ""),VehicleId=tostring(args.VehicleId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="ClearDisplay" then return managedOperation(player,profile,"Clear",{SlotId=tostring(args.SlotId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="SetInteriorStyle" then return managedOperation(player,profile,"SetSurfaceStyle",{SurfaceGroup=tostring(args.SurfaceGroup or ""),StyleId=tostring(args.StyleId or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="ConfigureStructure" then return managedOperation(player,profile,"ConfigureStructure",{SectionId=tostring(args.SectionId or ""),Action=tostring(args.Action or ""),StyleId=tostring(args.StyleId or ""),Channel=tostring(args.Channel or ""),Material=tostring(args.Material or ""),Color=args.Color,Colors=args.Colors,Materials=args.Materials,RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="ConfigureDecoration" then return managedOperation(player,profile,"ConfigureDecoration",{SlotId=tostring(args.SlotId or args.AnchorId or ""),ItemId=tostring(args.ItemId or ""),Action=tostring(args.Action or ""),Colors=args.Colors,RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="ConfigureLighting" then return managedOperation(player,profile,"ConfigureLighting",{Action=tostring(args.Action or ""),PresetId=tostring(args.PresetId or ""),Intensity=args.Intensity,Colors=args.Colors,RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="SetInvitation" then return managedOperation(player,profile,"SetInvitation",{Action=tostring(args.Action or ""),TargetUserId=tonumber(args.TargetUserId),OwnerUserId=player.UserId,MaxInvites=settings:GetAttribute("MaxGarageInvitations"),RequestId=args.RequestId,BaseRevision=args.BaseRevision})
			elseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end
			return {Success=false,Message="Unknown owned garage action."}
		end)
		locks[player]=nil; if not controlAction then lastRequest[player]=now end; if ok and type(result)=="table" then return result end; warn("[NTR Owned Garage] "..tostring(result)); return {Success=false,Message="Owned garage request failed."}
	end
	-- NTR_OWNED_GARAGE_PHASE6_CHARACTER_CLEANUP_V1
	local function watchCharacter(player,character) local humanoid=character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid",10); if humanoid then humanoid.Died:Connect(function() local session=sessions[player]; if session then abandonSession(player,session) end end) end end
	Players.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end); for _,player in ipairs(Players:GetPlayers()) do player.CharacterAdded:Connect(function(character) watchCharacter(player,character) end); if player.Character then task.spawn(watchCharacter,player,player.Character) end end
	Players.PlayerRemoving:Connect(function(player) local session=sessions[player]; clearStreamRequest(player); sessions[player]=nil; locks[player]=nil; lastRequest[player]=nil; stateCache[player]=nil; requestWindows[player]=nil; Assignment.ForgetPlayer(player); slotByUserId[player.UserId]=nil; setInside(player,nil); if session and session.Interior then disconnectPrompts(session.Interior); session.Interior:Destroy() end end)
	started=true; print("[NTR Owned Garage] Management runtime active."); return true,"Started"
end
return Runtime
