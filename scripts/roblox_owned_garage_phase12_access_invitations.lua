-- Neo Tokyo Racers - Owned Garage Phase 12 canonical Access and Invitations
-- Run once in Roblox Studio Edit mode after confirmed Phase 11 Lighting V1.1 or Phase 12 V1.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 12 Access]"
local REVISION="NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1_2_FULL_WIDTH_ICON_DROPDOWNS"
local BASE="NTR_OWNED_GARAGE_PHASE11_LIGHTING_V1_1_HIERARCHY_RECOVERY"
local BASE_V1="NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1"
local BASE_V1_1="NTR_OWNED_GARAGE_PHASE12_ACCESS_INVITATIONS_V1_1_HUD_DROPDOWNS"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function replaceOnce(source,old,new,label) local a,b=string.find(source,old,1,true); assert(a,label.." anchor missing"); assert(not string.find(source,old,b+1,true),label.." anchor not unique"); return source:sub(1,a-1)..new..source:sub(b+1) end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
assert(config:GetAttribute("OwnedGarageRevision")==BASE or config:GetAttribute("OwnedGarageRevision")==BASE_V1 or config:GetAttribute("OwnedGarageRevision")==BASE_V1_1 or config:GetAttribute("OwnedGarageRevision")==REVISION,"Confirmed Phase 11/12 baseline is not current")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data modules missing")
local propertyCatalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"Property catalogue missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI missing")
local profile=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"Profile runtime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"Assignment runtime missing")
local commands=assert(garage:FindFirstChild("OwnedGarageAuthoritativeCommandRuntime"),"Command runtime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"Management runtime missing")
local controller=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"Workspace controller missing")
local interiorMode=assert(ui:FindFirstChild("GarageInteriorModeController"),"Interior mode controller missing")
local sharedComponents=assert(ui:FindFirstChild("GarageReplacementComponents"),"Shared garage components missing")

local projected={}; local expectedMarkers={}
local function project(object,marker,transform) local source=projected[object] or object.Source; if not source:find(marker,1,true) then source=transform(source) end; assert(source:find(marker,1,true),object.Name.." marker missing"); compile(object.Name,source); projected[object]=source; expectedMarkers[object]=marker end

project(propertyCatalog,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROPERTY_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V6_LIGHTING_SLOTS","-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V6_LIGHTING_SLOTS\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROPERTY_V1","property marker")
	source=replaceOnce(source,"local Catalog={DefinitionVersion=3,StateApiVersion=3}","local Catalog={DefinitionVersion=4,StateApiVersion=4}","property API version")
	return replaceOnce(source,"Invitations=false,Visitors=false","Invitations=true,Visitors=false","property invitation capability")
end)

project(profile,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROFILE_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_LIGHTING_PROFILE_V1","-- NTR_OWNED_GARAGE_LIGHTING_PROFILE_V1\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_PROFILE_V1","profile marker")
	local helper=[==[
local function normalizeInvites(value)
	local result={}; local seen={}; for _,raw in pairs(type(value)=="table" and value or {}) do local id=math.floor(tonumber(raw) or 0); if id>0 and not seen[id] then seen[id]=true; table.insert(result,id) end end; table.sort(result); return result
end
]==]
	source=replaceOnce(source,"local function defaultProperty(propertyId)",helper.."local function defaultProperty(propertyId)","invite normalizer")
	source=replaceOnce(source,'property.InvitedUserIds=type(property.InvitedUserIds)=="table" and property.InvitedUserIds or {}; property.Customisation=','property.InvitedUserIds=normalizeInvites(property.InvitedUserIds); property.Customisation=',"invite normalization")
	source=replaceOnce(source,'if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then return false,"Invalid access mode: "..tostring(property.AccessMode) end','if property.AccessMode~="Private" and property.AccessMode~="FriendsOnly" and property.AccessMode~="InviteOnly" and property.AccessMode~="Public" then return false,"Invalid access mode: "..tostring(property.AccessMode) end; local inviteSeen={}; for _,userId in ipairs(property.InvitedUserIds or {}) do if userId<=0 or inviteSeen[userId] then return false,"Invalid or duplicate garage invitation." end; inviteSeen[userId]=true end',"invite validation")
	local addition=[==[
function Runtime.SetInvitation(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local targetUserId=math.floor(tonumber(args.TargetUserId) or 0); local ownerUserId=math.floor(tonumber(args.OwnerUserId) or 0); local action=tostring(args.Action or "")
	if not (property and property.Owned) then return false,"Garage is not owned." end; if targetUserId<=0 or targetUserId==ownerUserId then return false,"Invitation target is invalid." end; property.InvitedUserIds=normalizeInvites(property.InvitedUserIds); local index; for i,userId in ipairs(property.InvitedUserIds) do if userId==targetUserId then index=i end end
	local limit=math.clamp(math.floor(tonumber(args.MaxInvites) or 20),1,100)
	if action=="Invite" then if index then return false,"Player is already invited." end; if #property.InvitedUserIds>=limit then return false,"Garage invitation limit reached." end; table.insert(property.InvitedUserIds,targetUserId); table.sort(property.InvitedUserIds)
	elseif action=="Revoke" then if not index then return false,"Player is not invited." end; table.remove(property.InvitedUserIds,index)
	else return false,"Unknown invitation action." end
	garage.Revision+=1; return true,action=="Invite" and "Player invited." or "Invitation revoked."
end
]==]
	return replaceOnce(source,"function Runtime.ConfigureStructure",addition.."function Runtime.ConfigureStructure","invitation command")
end)

project(assignment,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_TRANSACTION_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_LIGHTING_TRANSACTION_V1","-- NTR_OWNED_GARAGE_LIGHTING_TRANSACTION_V1\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_TRANSACTION_V1","assignment marker")
	source=replaceOnce(source,'tostring(args.Intensity or "")','tostring(args.Intensity or ""),tostring(args.TargetUserId or ""),tostring(args.MaxInvites or "")',"invitation fingerprint")
	return replaceOnce(source,'elseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)','elseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)\n\t\telseif operation=="SetInvitation" then success,message=Profile.SetInvitation(profile,args)',"invitation transaction route")
end)

project(commands,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_COMMAND_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_LIGHTING_COMMAND_V1","-- NTR_OWNED_GARAGE_LIGHTING_COMMAND_V1\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_COMMAND_V1","command marker")
	return replaceOnce(source,"ConfigureLighting=true}","ConfigureLighting=true,SetInvitation=true}","invitation allowlist")
end)

project(management,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_MANAGEMENT_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_LIGHTING_MANAGEMENT_V1","-- NTR_OWNED_GARAGE_LIGHTING_MANAGEMENT_V1\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_MANAGEMENT_V1","management marker")
	source=replaceOnce(source,'local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or ((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="ConfigureDecoration" and "Decorations" or (operation=="ConfigureLighting" and "Lighting" or (operation=="SetAccessMode" and "Access"))))','local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or ((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="ConfigureDecoration" and "Decorations" or (operation=="ConfigureLighting" and "Lighting" or (operation=="SetAccessMode" and "Access" or (operation=="SetInvitation" and "Invitations")))))',"access capability route")
	local helpers=[==[
	local function playerSignature()
		local ids={}; for _,candidate in ipairs(Players:GetPlayers()) do table.insert(ids,candidate.UserId) end; table.sort(ids); local parts={}; for _,id in ipairs(ids) do table.insert(parts,tostring(id)) end; return table.concat(parts,"|")
	end
	local function invitationRows(owner,property)
		local rows={}; local online={}; local invited={}; for _,id in ipairs(property and property.InvitedUserIds or {}) do invited[tonumber(id)]=true end
		for _,candidate in ipairs(Players:GetPlayers()) do if candidate~=owner then online[candidate.UserId]=true; table.insert(rows,{UserId=candidate.UserId,DisplayName=candidate.DisplayName,Username=candidate.Name,Online=true,Invited=invited[candidate.UserId]==true}) end end
		for userId in pairs(invited) do if not online[userId] then table.insert(rows,{UserId=userId,DisplayName="User "..userId,Username="OFFLINE",Online=false,Invited=true}) end end
		table.sort(rows,function(a,b) if a.Invited~=b.Invited then return a.Invited end; if a.Online~=b.Online then return a.Online end; return string.lower(a.DisplayName)<string.lower(b.DisplayName) end); return rows
	end
]==]
	source=replaceOnce(source,"\tstateFor=function(player,profile)",helpers.."\tstateFor=function(player,profile)","invitation state helpers")
	source=replaceOnce(source,'local signature=vehicleSignature(profile); local cached=stateCache[player]','local signature=vehicleSignature(profile); local playersSignature=playerSignature(); local cached=stateCache[player]',"player signature")
	source=replaceOnce(source,'cached.VehicleSignature==signature and cached.Cash==cash','cached.VehicleSignature==signature and cached.PlayerSignature==playersSignature and cached.Cash==cash',"player cache key")
	source=replaceOnce(source,'AccessMode=currentProperty and currentProperty.AccessMode or "Private",Cash=','AccessMode=currentProperty and currentProperty.AccessMode or "Private",InvitationRows=currentProperty and invitationRows(player,currentProperty) or {},InvitationsEnabled=session and capabilities(session.PropertyId).Invitations==true,VisitorsEnabled=false,Cash=',"invitation state")
	source=replaceOnce(source,'VehicleSignature=signature,Cash=cash','VehicleSignature=signature,PlayerSignature=playersSignature,Cash=cash',"player cache storage")
	return replaceOnce(source,'\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end','\t\t\telseif action=="SetInvitation" then return managedOperation(player,profile,"SetInvitation",{Action=tostring(args.Action or ""),TargetUserId=tonumber(args.TargetUserId),OwnerUserId=player.UserId,MaxInvites=settings:GetAttribute("MaxGarageInvitations"),RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end',"invitation request route")
end)

project(controller,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_UI_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_LIGHTING_UI_V1","-- NTR_OWNED_GARAGE_LIGHTING_UI_V1\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_UI_V1","UI marker")
	source=replaceOnce(source,'local selectedLightingPreset; local selectedLightingIntensity','local selectedLightingPreset; local selectedLightingIntensity; local selectedInviteUserId',"invite selection state")
	local branch=[==[
		elseif page=="Access" or page=="AccessInvites" then
			if page=="Access" then for _,mode in ipairs(state.AccessModes or {}) do local accessMode=mode; local current=state.AccessMode==accessMode; table.insert(cards,{Id=accessMode,CardKind="Listing",VehicleName="GARAGE ACCESS",DisplayName=(string.gsub(accessMode,"Only"," Only")),Footer=current and "CURRENT" or "SELECT ACCESS",SemanticState=current and "Equipped" or "Available",Selected=current,OnSelect=function() if not current then operate("SetAccessMode",{AccessMode=accessMode},"Access",nil,nil,"ACCESS MODE SAVED") end end}) end; table.insert(cards,{Id="InvitePlayers",DisplayName="Invitations",Footer=state.InvitationsEnabled and "MANAGE PLAYERS" or "COMING LATER",OnSelect=function() if state.InvitationsEnabled then page="AccessInvites"; selectedInviteUserId=nil; render(true) end end}); view=context("Choose who may access this garage.",cards); view.SelectedAction={RowId="InvitePlayers",Text="MANAGE INVITES",OnActivate=function() page="AccessInvites"; selectedInviteUserId=nil; render(true) end}
			else for _,item in ipairs(state.InvitationRows or {}) do local row=item; table.insert(cards,{Id=tostring(row.UserId),CardKind="Listing",VehicleName=row.Online and string.upper(row.Username or "ONLINE") or "OFFLINE INVITATION",DisplayName=row.DisplayName,Footer=row.Invited and "INVITED" or "AVAILABLE",SemanticState=row.Invited and "Equipped" or "Available",Selected=selectedInviteUserId==row.UserId,OnSelect=function() selectedInviteUserId=row.UserId; render(false) end}) end; view=context("Invite or revoke same-server players.",cards); view.EmptyMessage="NO OTHER PLAYERS IN THIS SERVER"; local chosen; for _,item in ipairs(state.InvitationRows or {}) do if item.UserId==selectedInviteUserId then chosen=item end end; if chosen then view.SelectedAction={RowId=tostring(chosen.UserId),Text=chosen.Invited and "REVOKE" or "INVITE",OnActivate=function() operate("SetInvitation",{Action=chosen.Invited and "Revoke" or "Invite",TargetUserId=chosen.UserId},"AccessInvites",nil,nil,chosen.Invited and "INVITATION REVOKED" or "PLAYER INVITED") end} end end
			view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() selectedInviteUserId=nil; if page=="AccessInvites" then page="Access" else page="DisplaySpaces" end; render(true) end
]==]
	return replaceOnce(source,"\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})",branch.."\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})","access pages")
end)

project(interiorMode,"NTR_OWNED_GARAGE_ACCESS_INVITATIONS_HUD_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER","-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER\n-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_HUD_V1","HUD marker")
	source=replaceOnce(source,'invite.Activated:Connect(function() show("INVITATIONS ACTIVATE WITH THE VISITOR PHASE",false) end)','invite.Activated:Connect(function() local event=script.Parent:FindFirstChild("OpenOwnedGarageWorkspace"); if event then event:Fire({Page="AccessInvites"}) else show("GARAGE INVITATIONS UNAVAILABLE",false) end end)',"invite HUD action")
	return source
end)

project(sharedComponents,"NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V2",function(source)
	local addition=[==[

-- NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V2
function M.AttachDropdownChevron(button)
	local chevron=button:FindFirstChild("DropdownChevron")
	if not chevron then chevron=Racing.Label(button,{Name="DropdownChevron",Text=utf8.char(9662),Position=UDim2.new(1,-30,0,0),Size=UDim2.new(0,22,1,0),TextSize=14,Role="Button",XAlignment=Enum.TextXAlignment.Center}); chevron.AnchorPoint=Vector2.new(0,.5); chevron.Position=UDim2.new(1,-30,.5,0); chevron.ZIndex=button.ZIndex+3 end
	return chevron
end
function M.SetDropdownOpen(button,isOpen)
	local chevron=M.AttachDropdownChevron(button); chevron.Rotation=isOpen and 180 or 0
end
function M.AnchoredDropdown(parent,options)
	options=options or {}; local panel; local anchor; local outsideConnection; local rows={}; local callback; local metrics={}
	local function notify(target,isOpen) if type(options.OnOpenChanged)=="function" then options.OnOpenChanged(target,isOpen) end end
	local function inside(object,point)
		if not (object and object.Parent and object.Visible) then return false end; local position=object.AbsolutePosition; local size=object.AbsoluteSize; return point.X>=position.X and point.X<=position.X+size.X and point.Y>=position.Y and point.Y<=position.Y+size.Y
	end
	local function hide()
		local closedAnchor=anchor; if outsideConnection then outsideConnection:Disconnect(); outsideConnection=nil end; if panel then panel:Destroy(); panel=nil end; anchor=nil; rows={}; callback=nil; if closedAnchor then notify(closedAnchor,false) end
	end
	local function place()
		if not (panel and anchor and anchor.Parent) then return end; local scale=math.max(.01,tonumber(options.Scale and options.Scale() or 1) or 1); local logical=(anchor.AbsolutePosition-parent.AbsolutePosition)/scale; local width=parent.AbsoluteSize.X/scale; panel.Position=UDim2.fromOffset(0,logical.Y+anchor.AbsoluteSize.Y/scale+(tonumber(metrics.Gap) or 5)); panel.Size=UDim2.fromOffset(width,panel.Size.Y.Offset)
	end
	local function show(target,newRows,onPick,newMetrics)
		hide(); anchor=target; rows=type(newRows)=="table" and newRows or {}; callback=onPick; metrics=type(newMetrics)=="table" and newMetrics or {}; local rowHeight=math.max(40,tonumber(metrics.RowHeight) or 46); local rowGap=math.max(0,tonumber(metrics.RowGap) or 5); local maximum=math.max(1,math.floor(tonumber(metrics.MaxRows) or 5)); local visibleCount=math.max(1,math.min(#rows,maximum)); local panelHeight=visibleCount*rowHeight+math.max(0,visibleCount-1)*rowGap
		panel=Instance.new("Frame"); panel.Name="AnchoredDropdown"; panel.BackgroundTransparency=1; panel.BorderSizePixel=0; panel.ClipsDescendants=true; panel.ZIndex=tonumber(options.ZIndex) or 80; panel.Size=UDim2.fromOffset(100,panelHeight); panel.Parent=parent
		local scroll=Instance.new("ScrollingFrame"); scroll.Name="Choices"; scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.Size=UDim2.fromScale(1,1); scroll.CanvasSize=UDim2.fromOffset(0,math.max(1,#rows)*rowHeight+math.max(0,#rows-1)*rowGap); scroll.ScrollBarThickness=#rows>maximum and 3 or 0; scroll.ScrollBarImageColor3=Racing.Colour("Telemetry"); scroll.ZIndex=panel.ZIndex+1; scroll.Parent=panel
		local renderRows=#rows>0 and rows or {{Text="NO OPTIONS AVAILABLE",Disabled=true}}
		for index,row in ipairs(renderRows) do
			local selected=row.Selected==true; local button=Instance.new("TextButton"); button.Name="Choice"..index; button.AutoButtonColor=false; button.BorderSizePixel=0; button.BackgroundColor3=selected and Racing.Colour("PanelBlue") or Racing.Colour("PanelSoft"); button.BackgroundTransparency=.04; button.Position=UDim2.fromOffset(0,(index-1)*(rowHeight+rowGap)); button.Size=UDim2.new(1,-(#rows>maximum and 7 or 0),0,rowHeight); button.Text=""; button.ZIndex=panel.ZIndex+2; button.Active=row.Disabled~=true; button.Selectable=row.Disabled~=true; button.Parent=scroll; Racing.Corner(button,6)
			local fill=Instance.new("UIGradient"); fill.Name="ChoiceGradient"; fill.Rotation=12; fill.Color=selected and ColorSequence.new(Racing.Colour("PanelBlue"),Racing.Colour("PanelSoft")) or ColorSequence.new(Racing.Colour("PanelSoft"),Racing.Colour("PanelDeep")); fill.Parent=button
			local imageText=tostring(row.Icon or ""); local glyphText=tostring(row.IconText or ""); local image=Instance.new("ImageLabel"); image.Name="ChoiceIcon"; image.BackgroundTransparency=1; image.BorderSizePixel=0; image.Position=UDim2.fromOffset(12,math.floor((rowHeight-22)*.5)); image.Size=UDim2.fromOffset(22,22); image.Image=imageText; image.ImageColor3=Racing.Colour("Text"); image.Visible=imageText~=""; image.ZIndex=button.ZIndex+1; image.Parent=button
			local glyph=Racing.Label(button,{Name="ChoiceGlyph",Text=glyphText,Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(22,rowHeight),TextSize=18,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); glyph.Visible=imageText=="" and glyphText~=""; glyph.ZIndex=button.ZIndex+1
			local text=Racing.Label(button,{Name="ChoiceText",Text=string.upper(tostring(row.Text or row.Id or "")),Position=UDim2.fromOffset(44,0),Size=UDim2.new(1,-142,1,0),TextSize=tonumber(metrics.TextSize) or 11,Role="Button",XAlignment=Enum.TextXAlignment.Left}); text.ZIndex=button.ZIndex+1
			local detail=Racing.Label(button,{Name="Detail",Text=string.upper(tostring(row.Detail or "")),Position=UDim2.new(1,-92,0,0),Size=UDim2.fromOffset(78,rowHeight),TextSize=tonumber(metrics.DetailTextSize) or 9,Color=selected and Racing.Colour("Telemetry") or Racing.Colour("Muted"),Role="Metric",XAlignment=Enum.TextXAlignment.Right}); detail.ZIndex=button.ZIndex+1
			button.MouseEnter:Connect(function() if button.Active then button.BackgroundTransparency=0 end end); button.MouseLeave:Connect(function() button.BackgroundTransparency=.04 end)
			if row.Disabled~=true then button.Activated:Connect(function() if callback then callback(row) end end) end
		end
		place(); notify(anchor,true); outsideConnection=UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end; local point=Vector2.new(input.Position.X,input.Position.Y); if not inside(panel,point) and not inside(anchor,point) then hide() end
		end)
	end
	return {Show=function(_,target,newRows,onPick,newMetrics) show(target,newRows,onPick,newMetrics) end,Toggle=function(_,target,newRows,onPick,newMetrics) if panel and anchor==target then hide() else show(target,newRows,onPick,newMetrics) end end,Hide=function() hide() end,Relayout=function() place() end,IsOpenFor=function(_,target) return panel~=nil and anchor==target end,Destroy=function() hide() end}
end
]==]
	local oldMarker="-- NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V1"; local start=string.find(source,oldMarker,1,true)
	if start then local finish=string.find(source,"\nreturn M",start,true); assert(finish,"shared dropdown return anchor missing"); assert(not string.find(source,oldMarker,start+#oldMarker,true),"shared dropdown V1 marker not unique"); return source:sub(1,start-1)..addition..source:sub(finish) end
	return replaceOnce(source,"\nreturn M",addition.."\nreturn M","shared dropdown export")
end)

project(interiorMode,"NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2",function(_)
	return [==[
-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_HUD_V1
-- NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local HttpService=game:GetService("HttpService"); local UserInputService=game:GetService("UserInputService"); local Workspace=game:GetService("Workspace"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"); local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local function number(name,fallback) local value=settings:GetAttribute(name); return typeof(value)=="number" and value or fallback end
	local function stringAttribute(name) local value=settings:GetAttribute(name); return typeof(value)=="string" and value or "" end
	local function publish() playerGui:SetAttribute("NTR_OwnedGarageInteriorMode",player:GetAttribute("NTR_OwnedGarageInside")==true) end
	local gui=Instance.new("ScreenGui"); gui.Name="NTR_OwnedGarageInteriorHUD"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=58; gui.Parent=playerGui
	local root=Instance.new("Frame"); root.Name="AccessControls"; root.BackgroundTransparency=1; root.Position=UDim2.fromOffset(18,18); root.Size=UDim2.fromOffset(330,48); root.Parent=gui
	local access=Shared.ActionButton(root,{Name="Access",Text="PRIVATE",IconText=utf8.char(128274),Size=UDim2.fromOffset(158,46),Color=UI.Colour("PanelSoft"),StrokeColor=UI.Colour("Outline")}); Shared.AttachDropdownChevron(access)
	local invite=Shared.ActionButton(root,{Name="Invite",Text="INVITE",Icon=stringAttribute("InteriorHudInviteIcon"),IconText=utf8.char(9993),Size=UDim2.fromOffset(158,46),Color=UI.Colour("PanelBlue"),StrokeColor=UI.Colour("Telemetry")}); Shared.AttachDropdownChevron(invite)
	local toast=UI.Label(gui,{Name="GarageStatus",Text="",Position=UDim2.new(.5,-210,0,76),Size=UDim2.fromOffset(420,34),TextSize=12,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); toast.BackgroundColor3=UI.Colour("PanelDeep"); toast.BackgroundTransparency=.12; toast.Visible=false; UI.Corner(toast,6)
	local dropdown=Shared.AnchoredDropdown(root,{ZIndex=80,OnOpenChanged=function(target,isOpen) Shared.SetDropdownOpen(access,target==access and isOpen); Shared.SetDropdownOpen(invite,target==invite and isOpen) end}); local state; local busy=false; local refreshing=false; local cameraConnection
	local function show(text,good) toast.Text=tostring(text or ""); toast.TextColor3=good and UI.Colour("Telemetry") or UI.Colour("Danger"); toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.4,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end
	local function call(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage access is unavailable."} end
	local function displayMode(mode) return string.upper((string.gsub(tostring(mode or ""),"Only"," Only"))) end
	local accessIcons={Private="InteriorHudPrivateIcon",FriendsOnly="InteriorHudFriendsIcon",InviteOnly="InteriorHudInviteOnlyIcon",Public="InteriorHudPublicIcon"}; local accessGlyphs={Private=utf8.char(128274),FriendsOnly=utf8.char(128101),InviteOnly=utf8.char(9993),Public=utf8.char(9678)}
	local function accessVisual(mode) return stringAttribute(accessIcons[mode] or ""),accessGlyphs[mode] or utf8.char(9679) end
	local function applyState(nextState)
		if type(nextState)~="table" or nextState.Success~=true then return false end; state=nextState; local icon,glyph=accessVisual(state.AccessMode or "Private"); Shared.SetActionButton(access,displayMode(state.AccessMode or "Private"),icon,glyph); local count=0; for _,row in ipairs(state.InvitationRows or {}) do if row.Invited then count+=1 end end; Shared.SetActionButton(invite,count>0 and ("INVITE "..count) or "INVITE",stringAttribute("InteriorHudInviteIcon"),utf8.char(9993)); return true
	end
	local function refresh(reportFailure)
		if refreshing then return state~=nil end; refreshing=true; local result=call("GetManagementState",{}); refreshing=false; if applyState(result) then return true end; if reportFailure then show(result.Message or "GARAGE ACCESS UNAVAILABLE",false) end; return false
	end
	local function metrics() local touch=UserInputService.TouchEnabled; local rowHeight=access.AbsoluteSize.Y; if rowHeight<1 then rowHeight=number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46) end; return {Gap=number("InteriorHudDropdownGap",5),RowGap=number("InteriorHudDropdownRowGap",5),RowHeight=rowHeight,MaxRows=number(touch and "InteriorHudTouchDropdownRows" or "InteriorHudDropdownRows",touch and 4 or 5),TextSize=touch and 11 or 10,DetailTextSize=touch and 9 or 8} end
	local function mutate(action,args,successText)
		if busy or not state then return false end; busy=true; args=type(args)=="table" and args or {}; args.BaseRevision=state.Revision; args.RequestId=HttpService:GenerateGUID(false); local result=call(action,args); busy=false
		if result.Success then if not applyState(result.ManagementState) then refresh(false) end; show(successText,true); return true end
		if result.Conflict then refresh(false) end; show(result.Message or "GARAGE ACCESS UPDATE FAILED",false); return false
	end
	local openInvites
	local function openAccess(force)
		if not state and not refresh(true) then return end; local rows={}; for _,mode in ipairs(state.AccessModes or {}) do local icon,glyph=accessVisual(mode); table.insert(rows,{Id=mode,Text=displayMode(mode),Detail=state.AccessMode==mode and "CURRENT" or "",Selected=state.AccessMode==mode,Icon=icon,IconText=glyph}) end
		local method=force and dropdown.Show or dropdown.Toggle; method(dropdown,access,rows,function(row) if row.Id==state.AccessMode then dropdown:Hide(); return end; if mutate("SetAccessMode",{AccessMode=row.Id},"ACCESS MODE SAVED") then dropdown:Hide() end end,metrics())
	end
	openInvites=function(force)
		if not state and not refresh(true) then return end; local rows={}; for _,item in ipairs(state.InvitationRows or {}) do table.insert(rows,{Id=item.UserId,Text=item.DisplayName,Detail=item.Invited and "REVOKE" or "INVITE",Selected=item.Invited==true,Invited=item.Invited==true,Icon=stringAttribute("InteriorHudInviteIcon"),IconText=utf8.char(9993)}) end; if #rows==0 then table.insert(rows,{Text="NO OTHER PLAYERS",Disabled=true,IconText=utf8.char(9993)}) end
		local method=force and dropdown.Show or dropdown.Toggle; method(dropdown,invite,rows,function(row) if mutate("SetInvitation",{Action=row.Invited and "Revoke" or "Invite",TargetUserId=row.Id},row.Invited and "INVITATION REVOKED" or "PLAYER INVITED") then openInvites(true) end end,metrics())
	end
	local function layout()
		local camera=Workspace.CurrentCamera; local viewport=camera and camera.ViewportSize or Vector2.new(1280,720); local touch=UserInputService.TouchEnabled; local tiny=viewport.Y<500; local margin=math.max(8,number("InteriorHudMargin",tiny and 10 or 18)); local gap=math.max(4,number("InteriorHudGap",8)); local baseWidth=number(touch and "InteriorHudTouchButtonWidth" or "InteriorHudButtonWidth",touch and 150 or 158); local available=math.max(220,viewport.X-margin*2-gap); local width=math.max(106,math.min(baseWidth,math.floor(available*.5))); local height=math.max(touch and 44 or 40,number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46)); root.Position=UDim2.fromOffset(margin,margin); root.Size=UDim2.fromOffset(width*2+gap,height); access.Position=UDim2.fromOffset(0,0); access.Size=UDim2.fromOffset(width,height); invite.Position=UDim2.fromOffset(width+gap,0); invite.Size=UDim2.fromOffset(width,height); local toastWidth=math.min(420,math.max(220,viewport.X-margin*2)); toast.Size=UDim2.fromOffset(toastWidth,34); toast.Position=UDim2.new(.5,-toastWidth*.5,0,margin+height+8); dropdown:Relayout()
	end
	local function bindCamera() if cameraConnection then cameraConnection:Disconnect(); cameraConnection=nil end; local camera=Workspace.CurrentCamera; if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end; layout() end
	local wasVisible=false
	local function update()
		local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; local management=playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true; local mobileMenu=player:GetAttribute("NTRMobileMajorMenuOpen")==true; root.Visible=inside and not management and not mobileMenu; if not root.Visible then dropdown:Hide() elseif not wasVisible then task.spawn(function() refresh(false) end) end; wasVisible=root.Visible
	end
	access.Activated:Connect(function() if busy then return end; openAccess(false) end); invite.Activated:Connect(function() if busy then return end; if dropdown:IsOpenFor(invite) then dropdown:Hide(); return end; if state then openInvites(true); task.spawn(function() if refresh(false) and root.Visible and dropdown:IsOpenFor(invite) then openInvites(true) end end) else task.spawn(function() if refresh(true) and root.Visible then openInvites(true) end end) end end)
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() publish(); update() end); player:GetAttributeChangedSignal("NTRMobileMajorMenuOpen"):Connect(update); playerGui:GetAttributeChangedSignal("NTR_OwnedGarageManagementOpen"):Connect(update); Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="DriveOutResult" then show(message.Message,message.Success==true) elseif type(message)=="table" and message.Type=="ManagementUpdated" and root.Visible and not busy then task.spawn(function() if refresh(false) then if dropdown:IsOpenFor(invite) then openInvites(true) elseif dropdown:IsOpenFor(access) then openAccess(true) end end end) end end)
	publish(); bindCamera(); update(); started=true; print("[NTR Owned Garage] Interior access dropdown HUD active."); return true,"Started"
end
return Controller
]==]
end)

local sourceSnapshots={}; for object in pairs(projected) do sourceSnapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")} end
local configSnapshot={Revision=config:GetAttribute("OwnedGarageRevision"),RunId=config:GetAttribute("OwnedGarageInstallRunId"),Access=config:GetAttribute("EnableAccess"),Invitations=config:GetAttribute("EnableInvitations"),Visitors=config:GetAttribute("EnableVisitors"),Maximum=config:GetAttribute("MaxGarageInvitations")}
local tuning={InteriorHudMargin=18,InteriorHudGap=8,InteriorHudButtonWidth=158,InteriorHudTouchButtonWidth=150,InteriorHudButtonHeight=46,InteriorHudTouchButtonHeight=48,InteriorHudDropdownGap=5,InteriorHudDropdownRowGap=5,InteriorHudDropdownRowHeight=38,InteriorHudTouchDropdownRowHeight=44,InteriorHudDropdownRows=5,InteriorHudTouchDropdownRows=4,InteriorHudPrivateIcon="",InteriorHudFriendsIcon="",InteriorHudInviteOnlyIcon="",InteriorHudPublicIcon="",InteriorHudInviteIcon=""}; local tuningSnapshot={}; for name in pairs(tuning) do tuningSnapshot[name]=config:GetAttribute(name) end
local ok,problem=pcall(function()
	for object,source in pairs(projected) do object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("EnableAccess",true); config:SetAttribute("EnableInvitations",true); config:SetAttribute("EnableVisitors",false); config:SetAttribute("MaxGarageInvitations",20)
	for name,value in pairs(tuning) do if config:GetAttribute(name)==nil then config:SetAttribute(name,value) end end
	for object,marker in pairs(expectedMarkers) do assert(object.Source:find(marker,1,true),"Exact access marker missing: "..object.Name.." / "..marker) end
	assert(propertyCatalog.Source:find("local Catalog={DefinitionVersion=4,StateApiVersion=4}",1,true),"Property API version 4 did not persist")
	assert(propertyCatalog.Source:find("Invitations=true,Visitors=false",1,true),"Property invitation/visitor capability split did not persist")
	assert(profile.Source:find("function Runtime.SetInvitation",1,true) and commands.Source:find("SetInvitation=true",1,true),"Authoritative invitation command route did not persist")
	assert(sharedComponents.Source:find("NTR_OWNED_GARAGE_ANCHORED_DROPDOWN_V2",1,true) and sharedComponents.Source:find("function M.AttachDropdownChevron",1,true) and interiorMode.Source:find("NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2",1,true),"Shared V1.2 access dropdown UI did not persist")
	assert(sharedComponents.Source:find("local width=parent.AbsoluteSize.X/scale",1,true) and sharedComponents.Source:find("panel.BackgroundTransparency=1",1,true),"Full-width borderless dropdown contract did not persist")
	assert(interiorMode.Source:find("RowHeight=rowHeight",1,true) and interiorMode.Source:find("InteriorHudPrivateIcon",1,true) and interiorMode.Source:find("InteriorHudPublicIcon",1,true),"Responsive icon-row contract did not persist")
	assert(not interiorMode.Source:find("OpenOwnedGarageWorkspace",1,true),"Interior access HUD still opens the management workspace")
	assert(config:GetAttribute("InteriorHudTouchButtonHeight")>=44 and config:GetAttribute("InteriorHudTouchDropdownRows")>=1,"Responsive touch contract failed")
	assert(config:GetAttribute("EnableAccess")==true and config:GetAttribute("EnableInvitations")==true and config:GetAttribute("EnableVisitors")==false,"Access capability gate failed")
end)
if not ok then
	for object,snapshot in pairs(sourceSnapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	config:SetAttribute("OwnedGarageRevision",configSnapshot.Revision); config:SetAttribute("OwnedGarageInstallRunId",configSnapshot.RunId); config:SetAttribute("EnableAccess",configSnapshot.Access); config:SetAttribute("EnableInvitations",configSnapshot.Invitations); config:SetAttribute("EnableVisitors",configSnapshot.Visitors); config:SetAttribute("MaxGarageInvitations",configSnapshot.Maximum)
	for name,value in pairs(tuningSnapshot) do config:SetAttribute(name,value) end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end
print(TAG.." PASS sources=8 api=4 accessModes=4 invitationLimit=20 hudDropdowns=2 fullWidth=true borderless=true responsive=true invitationsEnabled=true visitorsEnabled=false revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: access and invitations use full-width icon dropdowns with matched row heights; management workspace is not opened and visitor teleport remains gated.")
