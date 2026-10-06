"""Integrator part: steering direction at a standstill and the shown speed (contract: ../CONTRACT.md)."""

DRIVING = ["ReplicatedStorage", "Config", "Vehicles", "Driving"]

EDITS = {
    "DrivingClient": [
        # Steering direction. Before: with no throttle, any backward drift over SteeringCoastDirectionMph (0.5 mph)
        # flipped the steering to reverse, so a car settling on its hover springs could steer the wrong way.
        # Now reverse steering while coasting needs the player to have asked for reverse, or a real backward roll.
        ("\t\t\tif (dynamicsStep.Enabled and dynamicsStep.Braking and forwardSpeed > 0) or steeringSignedMph > steeringCoastDirectionMph then\n"
         "\t\t\t\tstate.SteeringProfileIntent = 1\n"
         "\t\t\telse\n"
         "\t\t\t\tstate.SteeringProfileIntent = -1\n"
         "\t\t\tend\n"
         "\t\telseif steeringSignedMph < -steeringCoastDirectionMph then\n"
         "\t\t\tstate.SteeringProfileIntent = -1\n"
         "\t\telseif steeringSignedMph > steeringCoastDirectionMph then\n"
         "\t\t\tstate.SteeringProfileIntent = 1\n"
         "\t\tend\n",
         "\t\t\tif (dynamicsStep.Enabled and dynamicsStep.Braking and forwardSpeed > 0) or steeringSignedMph > steeringCoastDirectionMph then\n"
         "\t\t\t\tstate.SteeringProfileIntent = 1\n"
         "\t\t\telse\n"
         "\t\t\t\tstate.SteeringProfileIntent = -1\n"
         "\t\t\t\tstate.SteeringReverseAsked = true\n"
         "\t\t\tend\n"
         "\t\telseif configBool(\"Driving\", \"SteeringCoastAssumeForward\", true) then\n"
         "\t\t\t-- No throttle: forwards unless the player was reversing and is still rolling back, or the car is\n"
         "\t\t\t-- rolling back fast enough to be a real reverse (down a slope, after a hit).\n"
         "\t\t\tlocal reverseAt = state.SteeringReverseAsked and steeringCoastDirectionMph or configNumber(\"Driving\", \"SteeringCoastReverseMph\", 8, 0.05, 80)\n"
         "\t\t\tif steeringSignedMph < -reverseAt then\n"
         "\t\t\t\tstate.SteeringProfileIntent = -1\n"
         "\t\t\telse\n"
         "\t\t\t\tstate.SteeringProfileIntent = 1\n"
         "\t\t\t\tstate.SteeringReverseAsked = false\n"
         "\t\t\tend\n"
         "\t\telseif steeringSignedMph < -steeringCoastDirectionMph then\n"
         "\t\t\tstate.SteeringProfileIntent = -1\n"
         "\t\telseif steeringSignedMph > steeringCoastDirectionMph then\n"
         "\t\t\tstate.SteeringProfileIntent = 1\n"
         "\t\tend\n", 1),
        ("\t\t\tstate.SteeringProfileIntent = 1\n\t\telseif throttle < -steeringIntentDeadzone then\n",
         "\t\t\tstate.SteeringProfileIntent = 1\n\t\t\tstate.SteeringReverseAsked = false\n\t\telseif throttle < -steeringIntentDeadzone then\n", 1),
        # Shown speed: reads a little low at low speed and a little high at high speed. Display only; every
        # physics, camera, audio and VFX reader keeps the real speed (FeelSpeedMph is unchanged).
        ("local function updateExistingDriveUi(speedMph)\n\tlocal context = state.Context\n\tif not context then return end\n",
         "local function updateExistingDriveUi(speedMph)\n\tlocal context = state.Context\n\tif not context then return end\n"
         "\tif configBool(\"Driving\", \"SpeedDisplayCurveEnabled\", true) then\n"
         "\t\tlocal low = configNumber(\"Driving\", \"SpeedDisplayLowMultiplier\", 0.86, 0.5, 1.5)\n"
         "\t\tlocal high = math.max(low, configNumber(\"Driving\", \"SpeedDisplayHighMultiplier\", 1.08, 0.5, 1.5))\n"
         "\t\tlocal alpha = math.clamp(speedMph / configNumber(\"Driving\", \"SpeedDisplayFullMph\", 200, 10, 500), 0, 1)\n"
         "\t\talpha = alpha * alpha * (3 - 2 * alpha)\n"
         "\t\tspeedMph *= low + (high - low) * alpha\n"
         "\tend\n", 1),
        # Stop and R reset: forget a pending reverse, and tell the pose owner the lean was cut so the bank lift
        # does not read the reset as a fast roll (review findings 1 and 2).
        ("\tstate.IsDriving = false\n\tstate.SteeringProfileIntent = 1\n",
         "\tstate.IsDriving = false\n\tstate.SteeringProfileIntent = 1\n\tstate.SteeringReverseAsked = false\n", 1),
        ("\t\tstate.SteeringProfileIntent = 1\n\t\tstate.CurrentBank = 0\n",
         "\t\tstate.SteeringProfileIntent = 1\n\t\tstate.SteeringReverseAsked = false\n\t\tstate.CurrentBank = 0\n"
         "\t\tstate.PoseLean = state.WobbleRoll\n\t\tstate.PoseLiftVelocity = 0\n", 1),
    ],
    "DesktopFreeRoamHudUI": [
        ("\t\tlocal speed = rootPart and rootPart:IsA(\"BasePart\") and rootPart.AssemblyLinearVelocity.Magnitude * 0.625 or 0\n"
         "\t\tmphLabel.Text = tostring(math.floor(speed + 0.5))\n",
         "\t\tlocal speed = rootPart and rootPart:IsA(\"BasePart\") and rootPart.AssemblyLinearVelocity.Magnitude * 0.625 or 0\n"
         "\t\t-- While driving, show the speed the driving owner publishes (it applies the display curve).\n"
         "\t\tif mobileDriveInputState.IsDriving == true and tonumber(mobileDriveInputState.SpeedMph) then speed = math.max(0, mobileDriveInputState.SpeedMph) end\n"
         "\t\tmphLabel.Text = tostring(math.floor(speed + 0.5))\n", 1),
    ],
}

INSTANCES = []

ATTRIBUTES = [
    (DRIVING, "SteeringCoastAssumeForward", True),
    (DRIVING, "SteeringCoastAssumeForward_Description", "True: with no throttle held the car steers as if going forwards, unless the player was reversing and is still rolling back, or it rolls back faster than SteeringCoastReverseMph. False: the earlier rule (any backward drift over SteeringCoastDirectionMph steers as reverse)."),
    (DRIVING, "SteeringCoastReverseMph", 8),
    (DRIVING, "SteeringCoastReverseMph_RaisingThisDoes", "Requires a faster backward roll, with no throttle held and no reverse asked for, before steering switches to reverse."),
    (DRIVING, "SpeedDisplayCurveEnabled", True),
    (DRIVING, "SpeedDisplayCurveEnabled_Description", "True: the HUD speed reads lower than the real speed at low speed and higher at high speed. Display only."),
    (DRIVING, "SpeedDisplayLowMultiplier", 0.86),
    (DRIVING, "SpeedDisplayLowMultiplier_RaisingThisDoes", "Makes the HUD speed read closer to (or above) the real speed near a standstill. 1 shows the real speed."),
    (DRIVING, "SpeedDisplayHighMultiplier", 1.08),
    (DRIVING, "SpeedDisplayHighMultiplier_RaisingThisDoes", "Makes the HUD speed read higher at SpeedDisplayFullMph and above. 1 shows the real speed."),
    (DRIVING, "SpeedDisplayFullMph", 160),
    (DRIVING, "SpeedDisplayFullMph_RaisingThisDoes", "Moves the real speed at which the HUD reaches its full high-speed multiplier higher, so the HUD reads low over more of the range."),
]
