local MobileDriveInputState = {
	Throttle = 0,
	Steer = 0,
	Drift = false,
	Boost = false,
	SpeedMph = 0,
	BoostPercent = 100,
	IsDriving = false,
	AnalogSteer = 0,
	AnalogDrift = false,
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

function MobileDriveInputState.Refresh()
	local state = MobileDriveInputState.State
	MobileDriveInputState.Throttle = math.clamp((state.Accelerate and 1 or 0) - (state.Brake and 1 or 0), -1, 1)
	local digitalSteer = math.clamp(
		((state.TurnRight or state.DriftRight) and 1 or 0)
			- ((state.TurnLeft or state.DriftLeft) and 1 or 0),
		-1,
		1
	)
	if math.abs(MobileDriveInputState.AnalogSteer) >= math.abs(digitalSteer) then
		MobileDriveInputState.Steer = MobileDriveInputState.AnalogSteer
	else
		MobileDriveInputState.Steer = digitalSteer
	end
	MobileDriveInputState.Drift = MobileDriveInputState.AnalogDrift
		or state.DriftLeft
		or state.DriftRight
	MobileDriveInputState.Boost = state.Boost
end

function MobileDriveInputState.SetSteering(steer, drift)
	MobileDriveInputState.AnalogSteer = math.clamp(tonumber(steer) or 0, -1, 1)
	MobileDriveInputState.AnalogDrift = drift == true
	MobileDriveInputState.Refresh()
end

function MobileDriveInputState.ReleaseSteering()
	MobileDriveInputState.AnalogSteer = 0
	MobileDriveInputState.AnalogDrift = false
	MobileDriveInputState.Refresh()
end

function MobileDriveInputState.Reset()
	for action in pairs(MobileDriveInputState.State) do
		MobileDriveInputState.State[action] = false
	end
	MobileDriveInputState.AnalogSteer = 0
	MobileDriveInputState.AnalogDrift = false
	MobileDriveInputState.Throttle = 0
	MobileDriveInputState.Steer = 0
	MobileDriveInputState.Drift = false
	MobileDriveInputState.Boost = false
end

return MobileDriveInputState
