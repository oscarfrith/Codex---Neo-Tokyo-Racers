-- NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1
-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1
-- NTR_UI_PERFORMANCE_HARDENING_PHASE2_V1
-- NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V3
-- NTR_GARAGE_PREVIEW_CAMERA_CANONICAL_V4_SESSION_SCOPED
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Players=game:GetService("Players")
local PreviewCameraController={}
local cfg=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
PreviewCameraController.DefaultFocus=Vector3.new(860,104,-1749); PreviewCameraController.DefaultYaw=math.rad(135); PreviewCameraController.DefaultPitch=math.rad(-12); PreviewCameraController.DefaultDistance=24.3; PreviewCameraController.SectionDistance=33
PreviewCameraController.ViewBySection={ALL="Front45",Cockpit="Front45",THRUST_COLOR="Front45",Engine1="Front45",Stabilisers="Side",SidePods="Side",Engine2="Rear45",RearSpoiler="Rear45",Boost="Rear",RearBumper="Rear",FrontBumper="Front"}
PreviewCameraController.YawAttributeByView={Front45="PreviewCameraFront45YawDegrees",Side="PreviewCameraSideYawDegrees",Rear45="PreviewCameraRear45YawDegrees",Rear="PreviewCameraRearYawDegrees",Front="PreviewCameraFrontYawDegrees"}
PreviewCameraController.YawFallbackByView={Front45=135,Side=90,Rear45=45,Rear=0,Front=180}
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
local function sectionYaw(slotId)
	local view=PreviewCameraController.ViewBySection[slotId] or "Front45"; local attribute=PreviewCameraController.YawAttributeByView[view]; local fallback=PreviewCameraController.YawFallbackByView[view] or 135
	return math.rad(number(attribute,fallback)+number("PreviewCameraYawOffsetDegrees",45))
end
function PreviewCameraController.SetCameraSection(state,slotId) state.CameraSection=slotId or "ALL"; transition(state,{Yaw=sectionYaw(slotId),Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.SectionDistance}) end
function PreviewCameraController.Reset(state,focus) state.CameraSection="ALL"; transition(state,{Focus=focus or state.TargetFocus or PreviewCameraController.DefaultFocus,Yaw=sectionYaw("ALL"),Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.DefaultDistance}) end
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
