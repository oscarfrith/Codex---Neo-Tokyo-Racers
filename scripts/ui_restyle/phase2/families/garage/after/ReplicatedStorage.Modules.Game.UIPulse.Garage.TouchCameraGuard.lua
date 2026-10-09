-- Owns the owned-garage touch camera guard (which touches hold the walking camera inside an owned garage); not the interior HUD, the desk or any ScreenGui.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.TouchCameraGuard. Requires: Garage.OwnedGarageWorkspaceUI. Logic-identical fork of UI.GarageInteriorModeUI 48-270 (API2 5.7); started by Garage.GarageInteriorHud.
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local UserInputService=game:GetService("UserInputService"); local RunService=game:GetService("RunService"); local Workspace=game:GetService("Workspace"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local settings=game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Garage"):WaitForChild("Interior")
	local function number(name,fallback) local value=settings:GetAttribute(name); return typeof(value)=="number" and value or fallback end
	-- Native CameraModule can receive the same unprocessed touch as Dynamic
	-- Thumbstick. The physical-garage lifecycle owner classifies each touch
	-- once: movement and real management surfaces hold camera orientation,
	-- while genuinely empty management space retains normal native pan.
	local ManagementWorkspace=require(script.Parent:WaitForChild("OwnedGarageWorkspaceUI"))
	local cameraGuardName="OwnedGarageTouchCameraGuard"
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
			if token~=cameraRecoveryGeneration or playerGui:GetAttribute("OwnedGarageManagementOpen")==true then return end
			if guardCamera then return end
			if player:GetAttribute("GarageSessionActive")==true or player:GetAttribute("RaceSessionActive")==true then return end
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
		if not cameraGuardConfigured() or player:GetAttribute("OwnedGarageInside")~=true then return false end
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
			if player:GetAttribute("GarageSessionActive")==true or player:GetAttribute("RaceSessionActive")==true or (humanoidNow and humanoidNow.SeatPart) then
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
		if playerGui:GetAttribute("OwnedGarageManagementOpen")~=true or player:GetAttribute("OwnedGarageInside")~=true then pendingMovementTouches[input]=nil; return end
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
		if input.UserInputType~=Enum.UserInputType.Touch or not cameraGuardConfigured() or player:GetAttribute("OwnedGarageInside")~=true then return end
		local managementOpen=playerGui:GetAttribute("OwnedGarageManagementOpen")==true
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
	player:GetAttributeChangedSignal("OwnedGarageInside"):Connect(function()
		if player:GetAttribute("OwnedGarageInside")~=true then
			clearPendingMovementTouches()
			if not guardCamera then queueTouchFollowRecovery() end
		end
	end)
	playerGui:GetAttributeChangedSignal("OwnedGarageManagementOpen"):Connect(function()
		if playerGui:GetAttribute("OwnedGarageManagementOpen")~=true then
			clearPendingMovementTouches()
			if not guardCamera then queueTouchFollowRecovery() end
		else
			cameraRecoveryGeneration+=1
		end
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() clearPendingMovementTouches(); releaseCameraGuard(false); queueTouchFollowRecovery() end)
	started=true; return true,"Started"
end
return Controller
