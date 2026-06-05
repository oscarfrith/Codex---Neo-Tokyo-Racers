-- Neo Tokyo Racers preview camera controller.
-- Phase B module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local PreviewCameraController = {}

PreviewCameraController.DefaultFocus = Vector3.new(860, 104, -1749)
PreviewCameraController.DefaultYaw = math.rad(180)
PreviewCameraController.DefaultPitch = math.rad(-12)
PreviewCameraController.DefaultDistance = 24.3
PreviewCameraController.SectionDistance = 33

PreviewCameraController.YawBySlot = {
	FrontBumper = math.rad(180),
	RearBumper = math.rad(0),
	RearSpoiler = math.rad(0),
	Boost = math.rad(0),
	Engine1 = math.rad(135),
	Engine2 = math.rad(45),
	SidePods = math.rad(90),
	Stabilisers = math.rad(90),
}

function PreviewCameraController.WrapAngle(angle)
	return math.atan2(math.sin(angle), math.cos(angle))
end

function PreviewCameraController.LerpAngle(a, b, t)
	return a + PreviewCameraController.WrapAngle(b - a) * t
end

function PreviewCameraController.EnsureState(state)
	state.CameraFocus = state.CameraFocus or PreviewCameraController.DefaultFocus
	state.TargetFocus = state.TargetFocus or state.CameraFocus
	state.CameraYaw = state.CameraYaw or PreviewCameraController.DefaultYaw
	state.TargetYaw = state.TargetYaw or state.CameraYaw
	state.CameraPitch = state.CameraPitch or PreviewCameraController.DefaultPitch
	state.TargetPitch = state.TargetPitch or state.CameraPitch
	state.CameraDistance = state.CameraDistance or PreviewCameraController.DefaultDistance
	state.TargetDistance = state.TargetDistance or state.CameraDistance
	return state
end

function PreviewCameraController.SetPreviewFocus(state, focus)
	PreviewCameraController.EnsureState(state)
	state.TargetFocus = focus or state.TargetFocus
end

function PreviewCameraController.SetCameraSection(state, slotId)
	PreviewCameraController.EnsureState(state)
	state.TargetYaw = PreviewCameraController.YawBySlot[slotId] or PreviewCameraController.DefaultYaw
	state.TargetPitch = PreviewCameraController.DefaultPitch
	state.TargetDistance = PreviewCameraController.SectionDistance
end

function PreviewCameraController.Reset(state, focus)
	PreviewCameraController.EnsureState(state)
	state.TargetFocus = focus or state.TargetFocus or PreviewCameraController.DefaultFocus
	state.TargetYaw = PreviewCameraController.DefaultYaw
	state.TargetPitch = PreviewCameraController.DefaultPitch
	state.TargetDistance = PreviewCameraController.DefaultDistance
end

function PreviewCameraController.Update(context, dt)
	local state = context.State
	if not state or context.IsDriving == true or state.GarageCameraActive == false then
		return false
	end
	if context.Gui and context.Gui.Enabled == false then
		return false
	end

	local workspaceRef = context.Workspace or workspace
	local camera = context.Camera or workspaceRef.CurrentCamera
	if not camera then
		return false
	end

	PreviewCameraController.EnsureState(state)
	camera.CameraType = Enum.CameraType.Scriptable

	local t = math.clamp((dt or 0) * (context.LerpSpeed or 7), 0, 1)
	state.CameraFocus = state.CameraFocus:Lerp(state.TargetFocus, t)
	state.CameraYaw = PreviewCameraController.LerpAngle(state.CameraYaw, state.TargetYaw, t)
	state.CameraPitch += (state.TargetPitch - state.CameraPitch) * t
	state.CameraDistance += (state.TargetDistance - state.CameraDistance) * t

	local offset = CFrame.Angles(0, state.CameraYaw, 0)
		* CFrame.Angles(state.CameraPitch, 0, 0)
		* Vector3.new(0, 0, state.CameraDistance)

	camera.CFrame = CFrame.lookAt(state.CameraFocus + offset, state.CameraFocus)
	return true
end

return PreviewCameraController
