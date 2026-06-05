-- Neo Tokyo Racers client state boundary.
-- Phase A module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local ClientState = {}

ClientState.DefaultState = {
	Stage = "CockpitShop",
	ModuleMode = "Slots",
	CustomizeMode = "Overview",
	Catalog = nil,
	Profile = nil,
	CategoryId = "bruiser",
	SelectedCockpit = "bruiser_01",
	SelectedSlot = nil,
	SelectedModuleId = nil,
	CustomizeTarget = "ALL",
	ColorChannel = "Primary",
	Hue = 0.52,
	Saturation = 0.9,
	Brightness = 0.9,
	PreviewModules = {},
	GarageCameraActive = true,
	CameraFocus = Vector3.new(860, 104, -1749),
	TargetFocus = Vector3.new(860, 104, -1749),
	CameraYaw = math.rad(180),
	TargetYaw = math.rad(180),
	CameraPitch = math.rad(-12),
	TargetPitch = math.rad(-12),
	CameraDistance = 24.3,
	TargetDistance = 24.3,
	Dragging = false,
	LastPointer = nil,
}

local function cloneValue(value)
	if typeof(value) == "table" then
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = cloneValue(child)
		end
		return copy
	end
	return value
end

function ClientState.CloneArray(list)
	local copy = {}
	for i, value in ipairs(list or {}) do
		copy[i] = value
	end
	return copy
end

function ClientState.Create(initial)
	local state = cloneValue(ClientState.DefaultState)
	for key, value in pairs(initial or {}) do
		state[key] = value
	end
	return state
end

function ClientState.ResetPreviewSelection(state)
	state.PreviewModules = {}
	state.SelectedModuleId = nil
end

function ClientState.ApplyProfile(state, profile)
	if profile ~= nil then
		state.Profile = profile
	end
	return state
end

return ClientState
