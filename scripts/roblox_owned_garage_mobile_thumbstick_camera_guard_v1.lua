-- NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2_2
-- Run once in the Roblox Studio Edit-mode Command Bar, then restart Play.

local MODE = "INSTALL" -- INSTALL or AUDIT
local V2_REVISION = "NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2"
local BASE_REVISION = "NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2_1"
local REVISION = "NTR_OWNED_GARAGE_MOBILE_THUMBSTICK_CAMERA_GUARD_V2_2"
local PREFIX = "[NTR Owned Garage Mobile Camera Guard V2.2]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object, parent:GetFullName() .. "." .. name .. " missing")
	if className then assert(object:IsA(className), object:GetFullName() .. " must be " .. className) end
	return object
end

local function countPlain(source, needle)
	local count, start = 0, 1
	while true do
		local first, last = string.find(source, needle, start, true)
		if not first then return count end
		count += 1
		start = last + 1
	end
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local function replaceBetweenOnce(source, firstAnchor, lastAnchor, replacement, label)
	local firstStart, firstEnd = string.find(source, firstAnchor, 1, true)
	assert(firstStart, "Missing first source anchor: " .. label)
	assert(not string.find(source, firstAnchor, firstEnd + 1, true), "Duplicate first source anchor: " .. label)
	local lastStart, lastEnd = string.find(source, lastAnchor, firstEnd + 1, true)
	assert(lastStart, "Missing last source anchor: " .. label)
	assert(not string.find(source, lastAnchor, lastEnd + 1, true), "Duplicate last source anchor: " .. label)
	return string.sub(source, 1, firstStart - 1) .. replacement .. string.sub(source, lastStart)
end

local function compile(name, source)
	local fn, problem = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(problem))
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local settings = need(need(need(kit, "Config", "Folder"), "Runtime", "Folder"), "OwnedGarage_EditAttributes", "Folder")
local controllers = need(
	need(
		need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"),
		"NeoTokyoRacersClient",
		"Folder"
	),
	"Controllers",
	"Folder"
)
local uiControllers = need(controllers, "UI", "Folder")
local workspaceController = need(uiControllers, "GarageWorkspaceController", "ModuleScript")
local management = need(uiControllers, "OwnedGarageWorkspaceController", "ModuleScript")
local interior = need(uiControllers, "GarageInteriorModeController", "ModuleScript")

local function audit()
	assert(countPlain(workspaceController.Source, "-- " .. BASE_REVISION .. "\n") == 1, "confirmed V2.1 visible-surface workspace marker missing or duplicated")
	assert(countPlain(management.Source, "-- " .. BASE_REVISION .. "\n") == 1, "confirmed V2.1 owned-workspace marker missing or duplicated")
	assert(countPlain(interior.Source, "-- " .. V2_REVISION .. "\n") == 1, "confirmed V2 camera history marker missing or duplicated")
	assert(countPlain(interior.Source, "-- " .. BASE_REVISION .. "\n") == 1, "installed V2.1 interior marker missing or duplicated")
	assert(countPlain(interior.Source, "-- " .. REVISION .. "\n") == 1, "interior V2.2 marker missing or duplicated")
	compile("GarageWorkspaceController", workspaceController.Source)
	compile("OwnedGarageWorkspaceController", management.Source)
	compile("GarageInteriorModeController", interior.Source)
	assert(settings:GetAttribute("MobileManagementVisibleSurfaceMapEnabled") == true, "V2.1 visible-surface map must remain enabled")
	assert(settings:GetAttribute("MobileManagementTouchArbitrationEnabled") == true, "V2 touch-lifetime arbitration must remain enabled")
	local window = settings:GetAttribute("MobileThumbstickSemanticConfirmWindowSeconds")
	assert(typeof(window) == "number" and window >= 0.05 and window <= 0.75, "semantic thumbstick confirmation window invalid")
	assert(string.find(workspaceController.Source, "function WorkspaceUI:RebuildTouchSurfaceMap()", 1, true), "V2.1 visible-surface map was altered or is missing")
	assert(string.find(management.Source, "workspace:IsTouchBlocked(position)", 1, true), "owned management no longer delegates to the visible-surface map")
	assert(string.find(interior.Source, "local pendingMovementTouches={}", 1, true), "semantic pending-touch state missing")
	assert(string.find(interior.Source, 'Reason="PendingMovement"', 1, true), "pending movement classification missing")
	assert(string.find(interior.Source, "markerOwnsPendingTouch", 1, true), "post-Roblox thumbstick marker confirmation missing")
	assert(string.find(interior.Source, "movementStartedForPendingTouch", 1, true), "public movement-transition fallback missing")
	assert(string.find(interior.Source, "record.Snapshot", 1, true), "pre-touch camera snapshot recovery missing")
	assert(string.find(interior.Source, 'beginProtectedTouch(input,"Movement",record.Snapshot)', 1, true), "semantic movement promotion missing")
	assert(string.find(interior.Source, "local function queueMovementConfirmation(input)", 1, true), "same-cycle post-input confirmation missing")
	assert(string.find(interior.Source, "record.Queued=true", 1, true), "candidate confirmation coalescing missing")
	assert(string.find(interior.Source, "RunService.Heartbeat:Wait(); tryConfirmMovementTouch(input)", 1, true), "bounded next-heartbeat confirmation missing")
	assert(not string.find(interior.Source, "if pointInside(input,thumbStart) then return true end", 1, true), "retired early ThumbstickStart test remains")
	print(PREFIX .. " AUDIT PASS | V2.1 visible surfaces preserved; movement ownership confirmed after Roblox touch processing; no idle scan")
end

if MODE == "AUDIT" then
	audit()
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local revisionCount = countPlain(interior.Source, "-- " .. REVISION .. "\n")
if revisionCount == 1 then
	audit()
	print(PREFIX .. " already installed; no changes made.")
	return
end

assert(revisionCount == 0, "duplicate or partial V2.2 install detected; restore the pre-install Studio version before retrying")
assert(countPlain(workspaceController.Source, "-- " .. BASE_REVISION .. "\n") == 1, "installed V2.1 visible-surface workspace baseline required")
assert(countPlain(management.Source, "-- " .. BASE_REVISION .. "\n") == 1, "installed V2.1 owned-workspace baseline required")
assert(countPlain(interior.Source, "-- " .. BASE_REVISION .. "\n") == 1, "installed V2.1 interior baseline required")

local projectedInterior = replaceOnce(
	interior.Source,
	"-- " .. BASE_REVISION,
	"-- " .. BASE_REVISION .. "\n-- " .. REVISION,
	"interior V2.2 marker"
)

projectedInterior = replaceBetweenOnce(
	projectedInterior,
	'\tlocal cameraGuardName="NTR_OwnedGarageTouchCameraGuard"',
	"\tlocal wasVisible=false",
	[=[	local cameraGuardName="NTR_OwnedGarageTouchCameraGuard"
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
]=],
	"canonical semantic touch-owner camera arbiter"
)

assert(countPlain(projectedInterior, "-- " .. REVISION .. "\n") == 1, "projected V2.2 marker missing or duplicated")
compile("GarageInteriorModeController", projectedInterior)

local oldInteriorSource = interior.Source
local oldConfirmWindow = settings:GetAttribute("MobileThumbstickSemanticConfirmWindowSeconds")

local ok, problem = pcall(function()
	interior.Source = projectedInterior
	settings:SetAttribute("MobileThumbstickSemanticConfirmWindowSeconds", 0.35)
	audit()
end)

if not ok then
	interior.Source = oldInteriorSource
	settings:SetAttribute("MobileThumbstickSemanticConfirmWindowSeconds", oldConfirmWindow)
	error(PREFIX .. " INSTALL ROLLBACK: " .. tostring(problem))
end

print(PREFIX .. " INSTALL PASS | restart Play; verify movement without pan, every empty management region, visible UI, simultaneous touches, close/exit/re-entry, landscape phone/tablet and PC.")
