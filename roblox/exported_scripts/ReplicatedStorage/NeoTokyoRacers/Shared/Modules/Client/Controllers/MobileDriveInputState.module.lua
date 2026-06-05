local MobileDriveInputState = {
	Throttle = 0,
	Steer = 0,
	Drift = false,
	Boost = false,
	SpeedMph = 0,
	BoostPercent = 100,
	IsDriving = false,
	State = {
		Accelerate = false,
		Brake = false,
		TurnLeft = false,
		TurnRight = false,
		DriftLeft = false,
		DriftRight = false,
		Boost = false,
	},
}

function MobileDriveInputState.Reset()
	for action in pairs(MobileDriveInputState.State) do
		MobileDriveInputState.State[action] = false
	end
	MobileDriveInputState.Throttle = 0
	MobileDriveInputState.Steer = 0
	MobileDriveInputState.Drift = false
	MobileDriveInputState.Boost = false
end

function MobileDriveInputState.Refresh()
	local state = MobileDriveInputState.State
	MobileDriveInputState.Throttle = math.clamp((state.Accelerate and 1 or 0) - (state.Brake and 1 or 0), -1, 1)
	MobileDriveInputState.Steer = math.clamp(((state.TurnRight or state.DriftRight) and 1 or 0) - ((state.TurnLeft or state.DriftLeft) and 1 or 0), -1, 1)
	MobileDriveInputState.Drift = state.DriftLeft or state.DriftRight
	MobileDriveInputState.Boost = state.Boost
end

return MobileDriveInputState
