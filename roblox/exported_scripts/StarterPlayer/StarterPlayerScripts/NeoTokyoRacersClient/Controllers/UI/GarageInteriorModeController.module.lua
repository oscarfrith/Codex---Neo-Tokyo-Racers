-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_HUD_V1
-- NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2
-- NTR_OWNED_GARAGE_ICON_CONFIG_V1
-- NTR_OWNED_GARAGE_MOBILE_ACCESS_WORLD_ENTRIES_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local HttpService=game:GetService("HttpService"); local UserInputService=game:GetService("UserInputService"); local Workspace=game:GetService("Workspace"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"); local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
	local function number(name,fallback) local value=settings:GetAttribute(name); return typeof(value)=="number" and value or fallback end
	local function stringAttribute(name) local value=settings:GetAttribute(name); return typeof(value)=="string" and value or "" end
	local accessIconsConfig=kit.Config.UI:WaitForChild("GarageReplacement"):WaitForChild("OwnedGarageIcons"):WaitForChild("Access")
	local function accessIcon(name,legacyName) local value=accessIconsConfig:GetAttribute(name); if type(value)=="string" and value~="" then return UI.Asset(value) end; return stringAttribute(legacyName) end
	local function publish() playerGui:SetAttribute("NTR_OwnedGarageInteriorMode",player:GetAttribute("NTR_OwnedGarageInside")==true) end
	local gui=Instance.new("ScreenGui"); gui.Name="NTR_OwnedGarageInteriorHUD"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.DisplayOrder=58; gui.Parent=playerGui
	local root=Instance.new("Frame"); root.Name="AccessControls"; root.BackgroundTransparency=1; root.Position=UDim2.fromOffset(18,18); root.Size=UDim2.fromOffset(330,48); root.Parent=gui
	local hudScale=Instance.new("UIScale"); hudScale.Name="ResponsiveScale"; hudScale.Scale=1; hudScale.Parent=root
	local access=Shared.ActionButton(root,{Name="Access",Text="PRIVATE",Icon=accessIcon("Private","InteriorHudPrivateIcon"),IconText=utf8.char(128274),Size=UDim2.fromOffset(158,46),Color=UI.Colour("PanelSoft"),StrokeColor=UI.Colour("Outline")}); Shared.AttachDropdownChevron(access)
	local invite=Shared.ActionButton(root,{Name="Invite",Text="INVITE",Icon=accessIcon("Invite","InteriorHudInviteIcon"),IconText=utf8.char(9993),Size=UDim2.fromOffset(158,46),Color=UI.Colour("PanelBlue"),StrokeColor=UI.Colour("Telemetry")}); Shared.AttachDropdownChevron(invite)
	local toast=UI.Label(gui,{Name="GarageStatus",Text="",Position=UDim2.new(.5,-210,0,76),Size=UDim2.fromOffset(420,34),TextSize=12,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); toast.BackgroundColor3=UI.Colour("PanelDeep"); toast.BackgroundTransparency=.12; toast.Visible=false; UI.Corner(toast,6)
	local dropdown=Shared.AnchoredDropdown(root,{ZIndex=80,Scale=function() return hudScale.Scale end,OnOpenChanged=function(target,isOpen) Shared.SetDropdownOpen(access,target==access and isOpen); Shared.SetDropdownOpen(invite,target==invite and isOpen) end}); local state; local busy=false; local refreshing=false; local cameraConnection
	local function show(text,good) toast.Text=tostring(text or ""); toast.TextColor3=good and UI.Colour("Telemetry") or UI.Colour("Danger"); toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.4,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end
	local function call(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage access is unavailable."} end
	local function displayMode(mode) return string.upper((string.gsub(tostring(mode or ""),"Only"," Only"))) end
	local accessIcons={Private="InteriorHudPrivateIcon",FriendsOnly="InteriorHudFriendsIcon",InviteOnly="InteriorHudInviteOnlyIcon",Public="InteriorHudPublicIcon"}; local accessGlyphs={Private=utf8.char(128274),FriendsOnly=utf8.char(128101),InviteOnly=utf8.char(9993),Public=utf8.char(9678)}
	local function accessVisual(mode) return accessIcon(mode,accessIcons[mode] or ""),accessGlyphs[mode] or utf8.char(9679) end
	local function applyState(nextState)
		if type(nextState)~="table" or nextState.Success~=true then return false end; state=nextState; local icon,glyph=accessVisual(state.AccessMode or "Private"); Shared.SetActionButton(access,displayMode(state.AccessMode or "Private"),icon,glyph); local count=0; for _,row in ipairs(state.InvitationRows or {}) do if row.Invited then count+=1 end end; Shared.SetActionButton(invite,count>0 and ("INVITE "..count) or "INVITE",accessIcon("Invite","InteriorHudInviteIcon"),utf8.char(9993)); return true
	end
	local function refresh(reportFailure)
		if refreshing then return state~=nil end; refreshing=true; local result=call("GetManagementState",{}); refreshing=false; if applyState(result) then return true end; if reportFailure then show(result.Message or "GARAGE ACCESS UNAVAILABLE",false) end; return false
	end
	local function metrics() local touch=UserInputService.TouchEnabled; local scale=math.max(.01,hudScale.Scale); local rowHeight=access.AbsoluteSize.Y/scale; if rowHeight<1 then rowHeight=number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46) end; return {Gap=number("InteriorHudDropdownGap",5),RowGap=number("InteriorHudDropdownRowGap",5),RowHeight=rowHeight,MaxRows=number(touch and "InteriorHudTouchDropdownRows" or "InteriorHudDropdownRows",touch and 4 or 5),TextSize=touch and 11 or 10,DetailTextSize=touch and 9 or 8} end
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
		if not state and not refresh(true) then return end; local rows={}; for _,item in ipairs(state.InvitationRows or {}) do table.insert(rows,{Id=item.UserId,Text=item.DisplayName,Detail=item.Invited and "REVOKE" or "INVITE",Selected=item.Invited==true,Invited=item.Invited==true,Icon=accessIcon("Invite","InteriorHudInviteIcon"),IconText=utf8.char(9993)}) end; if #rows==0 then table.insert(rows,{Text="NO OTHER PLAYERS",Disabled=true,IconText=utf8.char(9993)}) end
		local method=force and dropdown.Show or dropdown.Toggle; method(dropdown,invite,rows,function(row) if mutate("SetInvitation",{Action=row.Invited and "Revoke" or "Invite",TargetUserId=row.Id},row.Invited and "INVITATION REVOKED" or "PLAYER INVITED") then openInvites(true) end end,metrics())
	end
	local function layout()
		local camera=Workspace.CurrentCamera; local viewport=camera and camera.ViewportSize or Vector2.new(1280,720); local touch=UserInputService.TouchEnabled; local scale=1; if touch and settings:GetAttribute("InteriorHudTouchResponsiveScale")~=false then local referenceWidth=math.max(320,number("InteriorHudTouchReferenceWidth",800)); local referenceHeight=math.max(320,number("InteriorHudTouchReferenceHeight",600)); local minimum=math.clamp(number("InteriorHudTouchMinimumScale",.72),.5,1); local maximum=math.clamp(number("InteriorHudTouchMaximumScale",1),minimum,1); scale=math.clamp(math.min(viewport.X/referenceWidth,viewport.Y/referenceHeight),minimum,maximum) end; hudScale.Scale=scale; local logicalViewport=viewport/scale; local tiny=logicalViewport.Y<500; local margin=math.max(8,number("InteriorHudMargin",tiny and 10 or 18)); local gap=math.max(4,number("InteriorHudGap",8)); local baseWidth=number(touch and "InteriorHudTouchButtonWidth" or "InteriorHudButtonWidth",touch and 150 or 158); local available=math.max(220,logicalViewport.X-margin*2-gap); local width=math.max(106,math.min(baseWidth,math.floor(available*.5))); local height=math.max(touch and 44 or 40,number(touch and "InteriorHudTouchButtonHeight" or "InteriorHudButtonHeight",touch and 48 or 46)); root.Position=UDim2.fromOffset(margin,margin); root.Size=UDim2.fromOffset(width*2+gap,height); access.Position=UDim2.fromOffset(0,0); access.Size=UDim2.fromOffset(width,height); invite.Position=UDim2.fromOffset(width+gap,0); invite.Size=UDim2.fromOffset(width,height); local toastWidth=math.min(420,math.max(220,logicalViewport.X-margin*2)); toast.Size=UDim2.fromOffset(toastWidth,34); toast.Position=UDim2.new(.5,-toastWidth*.5,0,margin+height+8); dropdown:Relayout()
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
