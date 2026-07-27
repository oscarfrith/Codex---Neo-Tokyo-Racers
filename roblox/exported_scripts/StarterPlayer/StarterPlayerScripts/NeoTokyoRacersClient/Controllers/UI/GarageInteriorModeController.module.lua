-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER
-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V1
-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V1_1
-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2
-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2_1
-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2_2
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_HUD_V1
-- NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2
-- NTR_OWNED_GARAGE_ICON_CONFIG_V1
-- NTR_OWNED_GARAGE_MOBILE_ACCESS_WORLD_ENTRIES_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local HttpService=game:GetService("HttpService"); local UserInputService=game:GetService("UserInputService"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"); local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
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
	-- Native CameraModule can receive the same unprocessed touch as Dynamic
	-- Thumbstick. The physical-garage lifecycle owner classifies each touch
	-- once: movement and real management surfaces hold camera orientation,
	-- while genuinely empty management space retains normal native pan.
	local ManagementWorkspace=require(script.Parent:WaitForChild("OwnedGarageWorkspaceController"))
	local cameraGuardName="NTR_OwnedGarageTouchCameraGuard"
	local guardTouches={}
	local pendingMovementTouches={}
	local guardCamera,guardSubject,guardType,guardRoot,guardOffset,guardRotation,guardFocusOffset
	local cameraRecoveryGeneration=0
	local queueTouchFollowRecovery
	local function cameraGuardConfigured()
		return settings:GetAttribute("MobileWalkingCameraGuardEnabled")~=false
			and UserInputService.TouchEnabled
	end
	local function clearGuardTouches() table.clear(guardTouches) end
	local function clearPendingMovementTouches() table.clear(pendingMovementTouches) end
	local function characterParts()
		local character=player.Character
		return character,character and character:FindFirstChildOfClass("Humanoid"),character and character:FindFirstChild("HumanoidRootPart")
	end
	local function releaseCameraGuard(restore)
		if not guardCamera then clearGuardTouches(); return end
		RunService:UnbindFromRenderStep(cameraGuardName)
		local camera=guardCamera
		if restore~=false and camera and camera.Parent and camera==Workspace.CurrentCamera then
			camera.CameraType=guardType or Enum.CameraType.Custom
			local subject=guardSubject
			if not (subject and subject.Parent) then local _,humanoid=characterParts(); subject=humanoid end
			if subject and subject.Parent then camera.CameraSubject=subject end
		end
		guardCamera=nil; guardSubject=nil; guardType=nil; guardRoot=nil; guardOffset=nil; guardRotation=nil; guardFocusOffset=nil
		clearGuardTouches()
	end
	queueTouchFollowRecovery=function()
		cameraRecoveryGeneration+=1
		local token=cameraRecoveryGeneration
		if not UserInputService.TouchEnabled or settings:GetAttribute("MobileTouchCameraRecoveryEnabled")==false then return end
		task.defer(function()
			RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
			if token~=cameraRecoveryGeneration or playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true then return end
			if guardCamera then return end
			if player:GetAttribute("NTR_GarageSessionActive")==true or player:GetAttribute("NTR_RaceSessionActive")==true then return end
			local _,humanoid=characterParts()
			if not humanoid or humanoid.SeatPart then return end
			local camera=Workspace.CurrentCamera
			if not camera then return end
			camera.CameraSubject=humanoid
			camera.CameraType=Enum.CameraType.Custom
		end)
	end
	local function visibleGuiObject(object)
		if not (object and object:IsA("GuiObject") and object.AbsoluteSize.X>0 and object.AbsoluteSize.Y>0) then return false end
		local current=object
		while current do
			if current:IsA("GuiObject") and not current.Visible then return false end
			if current:IsA("ScreenGui") and not current.Enabled then return false end
			current=current.Parent
		end
		return true
	end
	local function pointInsidePosition(position,object)
		if not (position and visibleGuiObject(object)) then return false end
		local origin,size=object.AbsolutePosition,object.AbsoluteSize
		return position.X>=origin.X and position.X<=origin.X+size.X and position.Y>=origin.Y and position.Y<=origin.Y+size.Y
	end
	local function thumbstickObjects()
		local touchGui=playerGui:FindFirstChild("TouchGui")
		local controlsFrame=touchGui and touchGui:FindFirstChild("TouchControlFrame")
		local thumb=controlsFrame and controlsFrame:FindFirstChild("DynamicThumbstickFrame")
		return thumb,thumb and thumb:FindFirstChild("ThumbstickStart",true)
	end
	local function broadMovementCandidate(input)
		local thumb=thumbstickObjects()
		if pointInsidePosition(input.Position,thumb) then return true end
		local camera=Workspace.CurrentCamera
		local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
		return input.Position.X<=viewport.X*.5 and input.Position.Y>=viewport.Y*.2
	end
	local function thumbMarkerState()
		local _,marker=thumbstickObjects()
		if not visibleGuiObject(marker) then return nil,nil end
		local size=marker.AbsoluteSize
		return marker.AbsolutePosition+size*.5,size
	end
	local function moveMagnitude()
		local _,humanoid=characterParts()
		return humanoid and humanoid.MoveDirection.Magnitude or 0
	end
	local function captureCameraSnapshot()
		local camera=Workspace.CurrentCamera
		local _,humanoid,rootPart=characterParts()
		if not (camera and humanoid and rootPart) or camera.CameraType==Enum.CameraType.Scriptable then return nil end
		return {Camera=camera,Subject=camera.CameraSubject or humanoid,CameraType=camera.CameraType,CFrame=camera.CFrame,Focus=camera.Focus,Root=rootPart,RootPosition=rootPart.Position}
	end
	local function activeGuardTouches()
		for input in pairs(guardTouches) do
			local state=input.UserInputState
			if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then guardTouches[input]=nil end
		end
		return next(guardTouches)~=nil
	end
	local function finishGuardIfReleased()
		if guardCamera and not activeGuardTouches() then releaseCameraGuard(true); queueTouchFollowRecovery() end
	end
	local function beginProtectedTouch(input,reason,snapshot)
		if not cameraGuardConfigured() or player:GetAttribute("NTR_OwnedGarageInside")~=true then return false end
		guardTouches[input]=reason
		if guardCamera then return true end
		local camera=Workspace.CurrentCamera
		local _,humanoid,rootPart=characterParts()
		if not (camera and humanoid and rootPart) or camera.CameraType==Enum.CameraType.Scriptable then guardTouches[input]=nil; return false end
		local source=snapshot and snapshot.Camera==camera and snapshot.Root==rootPart and snapshot or nil
		local sourceCFrame=source and source.CFrame or camera.CFrame
		local sourceFocus=source and source.Focus or camera.Focus
		local sourceRootPosition=source and source.RootPosition or rootPart.Position
		guardCamera=camera; guardSubject=(source and source.Subject) or camera.CameraSubject or humanoid; guardType=(source and source.CameraType) or camera.CameraType
		guardRoot=rootPart; guardOffset=sourceCFrame.Position-sourceRootPosition; guardRotation=sourceCFrame.Rotation; guardFocusOffset=sourceFocus.Position-sourceRootPosition
		cameraRecoveryGeneration+=1
		camera.CameraType=Enum.CameraType.Scriptable
		camera.CFrame=CFrame.new(rootPart.Position+guardOffset)*guardRotation
		camera.Focus=CFrame.new(rootPart.Position+guardFocusOffset)
		RunService:BindToRenderStep(cameraGuardName,Enum.RenderPriority.Camera.Value+1,function()
			if guardCamera~=Workspace.CurrentCamera then clearPendingMovementTouches(); releaseCameraGuard(false); queueTouchFollowRecovery(); return end
			if not activeGuardTouches() then releaseCameraGuard(true); queueTouchFollowRecovery(); return end
			local _,humanoidNow=characterParts()
			if player:GetAttribute("NTR_GarageSessionActive")==true or player:GetAttribute("NTR_RaceSessionActive")==true or (humanoidNow and humanoidNow.SeatPart) then
				clearPendingMovementTouches()
				releaseCameraGuard(false)
				return
			end
			if guardRoot and guardRoot.Parent then
				guardCamera.CFrame=CFrame.new(guardRoot.Position+guardOffset)*guardRotation
				guardCamera.Focus=CFrame.new(guardRoot.Position+guardFocusOffset)
			end
		end)
		return true
	end
	local function pendingCount()
		local count=0
		for _ in pairs(pendingMovementTouches) do count+=1 end
		return count
	end
	local function markerOwnsPendingTouch(record)
		local center,size=thumbMarkerState()
		if not center then return false end
		local radius=math.max(24,math.max(size.X,size.Y)*.9)
		return (center-record.StartPosition).Magnitude<=radius
	end
	local function movementStartedForPendingTouch(input,record)
		if pendingCount()~=1 or not broadMovementCandidate(input) then return false end
		return record.InitialMoveMagnitude<=.04 and moveMagnitude()>=.08
	end
	local function tryConfirmMovementTouch(input)
		local record=pendingMovementTouches[input]
		if not record or record.Queued then return end
		local state=input.UserInputState
		if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then pendingMovementTouches[input]=nil; return end
		if playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")~=true or player:GetAttribute("NTR_OwnedGarageInside")~=true then pendingMovementTouches[input]=nil; return end
		local window=math.clamp(number("MobileThumbstickSemanticConfirmWindowSeconds",.35),.05,.75)
		if os.clock()-record.StartedAt>window then pendingMovementTouches[input]=nil; return end
		if not markerOwnsPendingTouch(record) and not movementStartedForPendingTouch(input,record) then return end
		pendingMovementTouches[input]=nil
		beginProtectedTouch(input,"Movement",record.Snapshot)
	end
	local function queueMovementConfirmation(input)
		local record=pendingMovementTouches[input]
		if not record or record.Queued then return end
		record.Queued=true
		task.defer(function()
			local current=pendingMovementTouches[input]
			if not current or current~=record then return end
			current.Queued=false
			tryConfirmMovementTouch(input)
		end)
	end
	local function beginPendingMovementTouch(input)
		if pendingMovementTouches[input] then return end
		local snapshot=captureCameraSnapshot()
		if not snapshot then return end
		local position=input.Position
		local record={Reason="PendingMovement",StartedAt=os.clock(),StartPosition=Vector2.new(position.X,position.Y),InitialMoveMagnitude=moveMagnitude(),Snapshot=snapshot,Queued=false}
		pendingMovementTouches[input]=record
		queueMovementConfirmation(input)
		task.spawn(function()
			RunService.Heartbeat:Wait(); tryConfirmMovementTouch(input)
		end)
		local window=math.clamp(number("MobileThumbstickSemanticConfirmWindowSeconds",.35),.05,.75)
		task.delay(window,function() if pendingMovementTouches[input]==record then pendingMovementTouches[input]=nil end end)
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.Touch or not cameraGuardConfigured() or player:GetAttribute("NTR_OwnedGarageInside")~=true then return end
		local managementOpen=playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true
		if managementOpen then
			if ManagementWorkspace.IsCameraTouchBlocked(input.Position) then beginProtectedTouch(input,"ManagementUI"); return end
			if broadMovementCandidate(input) then beginPendingMovementTouch(input) end
			return
		end
		if broadMovementCandidate(input) then beginProtectedTouch(input,"Movement") end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.Touch and pendingMovementTouches[input] then queueMovementConfirmation(input) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		pendingMovementTouches[input]=nil
		if guardTouches[input] then guardTouches[input]=nil; finishGuardIfReleased() end
	end)
	player.CharacterAdded:Connect(function() clearPendingMovementTouches(); releaseCameraGuard(false); queueTouchFollowRecovery() end)
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function()
		if player:GetAttribute("NTR_OwnedGarageInside")~=true then
			clearPendingMovementTouches()
			if not guardCamera then queueTouchFollowRecovery() end
		end
	end)
	playerGui:GetAttributeChangedSignal("NTR_OwnedGarageManagementOpen"):Connect(function()
		if playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")~=true then
			clearPendingMovementTouches()
			if not guardCamera then queueTouchFollowRecovery() end
		else
			cameraRecoveryGeneration+=1
		end
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() clearPendingMovementTouches(); releaseCameraGuard(false); queueTouchFollowRecovery() end)
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
