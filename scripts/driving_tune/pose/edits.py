"""Driving tune, pose part: dynamic ride height (settle, bank lift), wobble, parked hand-over. See NOTES.md.

Lua below uses real tab characters. Anchors are exact text against before/*.lua with the expected match count.
"""
import io
import os

_HERE = os.path.dirname(os.path.abspath(__file__))


def _before(name):
    return io.open(os.path.join(_HERE, "..", "before", name + ".lua"), encoding="utf-8", newline="").read()


def _between(text, first, last):
    start = text.index(first)
    end = text.index(last, start) + len(last)
    return text[start:end]


# ---------------------------------------------------------------------------------------------- DrivingClient

_STATE_OLD = "\tWobblePitch = 0,\n\tWobbleRoll = 0,\n"
_STATE_NEW = _STATE_OLD + """\tWobbleYaw = 0,
	WobbleBob = 0,
	WobbleSeedY = math.random() * 1000,
	PoseConfig = {},
	PoseConfigTimer = 0,
	PoseProfileX = {},
	PoseProfileY = {},
	PoseHalfLength = 6,
	PoseSettle = nil,
	PoseSettleVelocity = 0,
	PoseLift = 0,
	PoseLiftVelocity = 0,
	PoseLean = 0,
	PosePitch = 0,
	PoseRideHeight = HOVER_HEIGHT,
	PoseRollTerm = 0,
	PosePitchTerm = 0,
"""

_STOP_OLD = "\tstate.WobblePitch = 0\n\tstate.WobbleRoll = 0\nend\n"
_STOP_NEW = ("\tstate.WobblePitch = 0\n\tstate.WobbleRoll = 0\n\tstate.WobbleYaw = 0\n\tstate.WobbleBob = 0\n"
             "\tif state.Vehicle then\n"
             "\t\tstate.Vehicle:SetAttribute(\"HoverPoseRideHeight\", nil)\n"
             "\t\tstate.Vehicle:SetAttribute(\"HoverPoseSettle\", nil)\n"
             "\t\tstate.Vehicle:SetAttribute(\"HoverPoseLift\", nil)\n"
             "\tend\nend\n")

# the whole existing updateHoverWobble function, sliced from the before file so the bytes are exact
_WOBBLE_OLD = _between(_before("DrivingClient"),
                       "local function updateHoverWobble(dt, speedMph, grounded)\n",
                       "\tstate.WobbleRoll += (targetRoll - state.WobbleRoll) * alpha\n"
                       "\treturn state.WobblePitch, state.WobbleRoll\nend\n")

_WOBBLE_NEW = """local function poseSmoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Hover pose tuning (Config.Vehicles.HoverPose and HoverWobble), re-read four times a second into one reused table.
local function refreshPoseConfig()
	local c = state.PoseConfig
	c.SettleEnabled = configBool("HoverPose", "SettleEnabled", true)
	c.SettleRestScale = configNumber("HoverPose", "SettleRestScale", 0.7, 0.3, 1)
	c.SettleStartMph = configNumber("HoverPose", "SettleStartMph", 1, 0, 40)
	c.SettleFullHeightMph = configNumber("HoverPose", "SettleFullHeightMph", 22, 2, 200)
	c.SettleFrequencyHz = configNumber("HoverPose", "SettleFrequencyHz", 1.3, 0.2, 4)
	c.SettleDamping = configNumber("HoverPose", "SettleDamping", 0.3, 0.1, 2)
	c.SettleThrottleLift = configNumber("HoverPose", "SettleThrottleLift", 0.6, 0, 1)
	c.SettleThrottleDeadzone = configNumber("HoverPose", "SettleThrottleDeadzone", 0.05, 0, 0.5)
	c.BankLiftEnabled = configBool("HoverPose", "BankLiftEnabled", true)
	c.BankLiftAmount = configNumber("HoverPose", "BankLiftAmount", 0.7, 0, 1.5)
	c.BankLiftMaxStuds = configNumber("HoverPose", "BankLiftMaxStuds", 2.4, 0, 6)
	c.BankLiftLeadSeconds = configNumber("HoverPose", "BankLiftLeadSeconds", 0.2, 0, 0.5)
	c.BankLiftRiseHz = configNumber("HoverPose", "BankLiftRiseHz", 4, 0.3, 6)
	c.BankLiftFallHz = configNumber("HoverPose", "BankLiftFallHz", 1.4, 0.3, 6)
	c.MinEdgeClearanceStuds = configNumber("HoverPose", "MinEdgeClearanceStuds", 0.25, 0, 2)
	c.LeanSpringCompensation = configNumber("HoverPose", "LeanSpringCompensation", 1, 0, 1)
	c.DebugAttributes = configBool("HoverPose", "DebugAttributes", false)
	c.WobbleFadeOutMph = configNumber("HoverWobble", "WobbleFadeOutMph", 20, 1, 80)
	c.WobbleAmountDegrees = configNumber("HoverWobble", "WobbleAmountDegrees", 1.5, 0, 8)
	c.WobbleSpeed = configNumber("HoverWobble", "WobbleSpeed", 1.15, 0.05, 8)
	c.WobbleRandomiseAmount = configNumber("HoverWobble", "WobbleRandomiseAmount", 0.65, 0, 2)
	c.WobblePitchMultiplier = configNumber("HoverWobble", "WobblePitchMultiplier", 0.75, 0, 3)
	c.WobbleRollMultiplier = configNumber("HoverWobble", "WobbleRollMultiplier", 1, 0, 3)
	c.WobbleSmoothing = configNumber("HoverWobble", "WobbleSmoothing", 4.5, 0.25, 18)
	c.WobbleDetailAmount = configNumber("HoverWobble", "WobbleDetailAmount", 0.6, 0, 2)
	c.WobbleBobStuds = configNumber("HoverWobble", "WobbleBobStuds", 0.06, 0, 0.4)
	c.WobbleYawDegrees = configNumber("HoverWobble", "WobbleYawDegrees", 0.35, 0, 4)
	c.WobbleRestBoost = configNumber("HoverWobble", "WobbleRestBoost", 0.3, 0, 2)
	c.WobbleRestMph = configNumber("HoverWobble", "WobbleRestMph", 4, 0.5, 40)
	c.WobbleAtSpeedAmount = configNumber("HoverWobble", "WobbleAtSpeedAmount", 0.15, 0, 1)
	c.WobbleAtSpeedSpeedBoost = configNumber("HoverWobble", "WobbleAtSpeedSpeedBoost", 1, 0, 4)
	return c
end

-- Runs once per Controller.Start: walks the visible parts and keeps the few box corners (|x|, y in root space)
-- that can be the lowest point of the body for some roll between 0 and 28 degrees. The bank lift reads only these.
local function measureHoverBody(vehicle)
	local xs, ys = state.PoseProfileX, state.PoseProfileY
	table.clear(xs)
	table.clear(ys)
	state.PoseHalfLength = 6
	local root = vehicle and vehicle.PrimaryPart
	if not root then return end
	local rootHalf = root.Size * 0.5
	local partX, partY = { rootHalf.X }, { -rootHalf.Y }
	local halfLength = rootHalf.Z
	local inverse = root.CFrame:Inverse()
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 0.99 then
			local rel = inverse * part.CFrame
			local half = part.Size * 0.5
			local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
			local extentX = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z
			local extentY = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z
			local extentZ = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
			local x = math.min(math.abs(rel.Position.X) + extentX, rootHalf.X + 6)
			local y = math.max(rel.Position.Y - extentY, -rootHalf.Y - 1.5)
			if x == x and y == y then
				partX[#partX + 1] = x
				partY[#partY + 1] = y
				if y < 0.5 then
					local z = math.min(math.abs(rel.Position.Z) + extentZ, rootHalf.Z + 12)
					if z == z then halfLength = math.max(halfLength, z) end
				end
			end
		end
	end
	for step = 0, 7 do
		local angle = math.rad(step * 4)
		local sinAngle, cosAngle = math.sin(angle), math.cos(angle)
		local best, bestDepth = 1, -math.huge
		for index = 1, #partX do
			local depth = partX[index] * sinAngle - partY[index] * cosAngle
			if depth > bestDepth then best, bestDepth = index, depth end
		end
		local seen = false
		for index = 1, #xs do
			if xs[index] == partX[best] and ys[index] == partY[best] then seen = true end
		end
		if not seen then
			xs[#xs + 1] = partX[best]
			ys[#ys + 1] = partY[best]
		end
	end
	state.PoseHalfLength = halfLength
	local text = ""
	for index = 1, #xs do
		text ..= string.format("%s%.2f,%.2f", index > 1 and ";" or "", xs[index], ys[index])
	end
	vehicle:SetAttribute("HoverPoseProfile", text)
	vehicle:SetAttribute("HoverPoseHalfLength", halfLength)
end

-- How far the lowest point of the body sits below the root centre at a given roll (positive studs).
local function poseBodyDepth(sinLean, cosLean)
	local xs, ys = state.PoseProfileX, state.PoseProfileY
	local count = #xs
	if count == 0 then return 4 * sinLean + 0.6 * cosLean end
	local best = -math.huge
	for index = 1, count do
		local depth = xs[index] * sinLean - ys[index] * cosLean
		if depth > best then best = depth end
	end
	return best
end

-- Ride height owner: rideHeight = HOVER_HEIGHT * settle + bankLift + bob. Writes state.PoseRideHeight and the
-- per-corner lean terms the hover loop adds to each corner target. Only the target moves; the corner springs
-- are unchanged, and nothing here reads the measured height after the first frame, so it cannot feed back.
local function updateHoverPose(dt, speedMph, forwardSpeed, throttle, hoverResults)
	dt = math.clamp(dt or 0, 1 / 240, 0.1)
	state.PoseConfigTimer -= dt
	if state.PoseConfigTimer <= 0 or state.PoseConfig.SettleRestScale == nil then
		state.PoseConfigTimer = 0.25
		refreshPoseConfig()
	end
	local c = state.PoseConfig
	if speedMph ~= speedMph then speedMph = 0 end
	local steps = math.clamp(math.ceil(dt * 60 - 0.001), 1, 6)
	local stepTime = dt / steps

	-- Settle: sink onto the cushion at a standstill, rise with speed or as soon as the throttle is pressed.
	local settle = 1
	if c.SettleEnabled then
		local curve = poseSmoothstep((speedMph - c.SettleStartMph) / math.max(c.SettleFullHeightMph - c.SettleStartMph, 1))
		local intent = 0
		if throttle > c.SettleThrottleDeadzone then
			intent = math.clamp(throttle, 0, 1)
		elseif throttle < -c.SettleThrottleDeadzone and forwardSpeed * MPH_PER_STUD < 4 then
			intent = math.clamp(-throttle, 0, 1)
		end
		local target = c.SettleRestScale + (1 - c.SettleRestScale) * math.max(curve, intent * c.SettleThrottleLift)
		if state.PoseSettle == nil then
			-- first frame after Start or after an anchored spell: begin from where the car actually is
			local sum, count = 0, 0
			for index = 1, 4 do
				local result = hoverResults[index]
				if result then
					sum += result.Distance - SENSOR_START_HEIGHT
					count += 1
				end
			end
			state.PoseSettle = count > 0 and math.clamp(sum / count / HOVER_HEIGHT, c.SettleRestScale, 1.3) or target
			state.PoseSettleVelocity = 0
		end
		local omega = c.SettleFrequencyHz * 2 * math.pi
		local position, velocity = state.PoseSettle, state.PoseSettleVelocity
		for _ = 1, steps do
			velocity += (omega * omega * (target - position) - 2 * c.SettleDamping * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = target, 0
		end
		state.PoseSettle = math.clamp(position, 0.3, 1.5)
		state.PoseSettleVelocity = math.clamp(velocity, -20, 20)
		settle = state.PoseSettle
	else
		state.PoseSettle = nil
		state.PoseSettleVelocity = 0
	end

	local bob = state.WobbleBob
	if bob ~= bob then bob = 0 end
	local base = HOVER_HEIGHT * settle + bob

	-- Bank lift: give back what the lowest point of the body loses to the lean (last frame's bank and wobble).
	local lean = state.CurrentBank + state.WobbleRoll
	local pitch = state.PosePitch
	if lean ~= lean then lean = 0 end
	if pitch ~= pitch then pitch = 0 end
	local leanRate = (lean - state.PoseLean) / dt
	state.PoseLean = lean
	local lift = 0
	if c.BankLiftEnabled then
		local ahead = math.abs(lean + leanRate * c.BankLiftLeadSeconds)
		local used = math.min(math.max(math.abs(lean), ahead), 0.6)
		local level = poseBodyDepth(0, 1)
		local loss = math.max(poseBodyDepth(math.sin(used), math.cos(used)) - level, 0)
		local want = loss * c.BankLiftAmount
		if c.MinEdgeClearanceStuds > 0 then
			local pitchDrop = state.PoseHalfLength * math.sin(math.min(math.abs(pitch), 0.5))
			want = math.max(want, c.MinEdgeClearanceStuds + level + loss + pitchDrop - base)
		end
		want = math.clamp(want, 0, c.BankLiftMaxStuds)
		local position, velocity = state.PoseLift, state.PoseLiftVelocity
		for _ = 1, steps do
			local omega = (want > position and c.BankLiftRiseHz or c.BankLiftFallHz) * 2 * math.pi
			velocity += (omega * omega * (want - position) - 2 * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = want, 0
		end
		state.PoseLift = math.clamp(position, 0, c.BankLiftMaxStuds)
		state.PoseLiftVelocity = math.clamp(velocity, -40, 40)
		lift = state.PoseLift
	else
		state.PoseLift = 0
		state.PoseLiftVelocity = 0
	end

	state.PoseRideHeight = math.clamp(base + lift, math.min(0.5, HOVER_HEIGHT), HOVER_HEIGHT * 2)
	-- Corner targets follow the commanded lean, so the four springs hold the same pose the AlignOrientation asks
	-- for instead of pushing the low side up and letting the high side fall.
	local compensation = c.LeanSpringCompensation
	state.PoseRollTerm = math.sin(lean) * math.cos(pitch) * compensation
	state.PosePitchTerm = math.sin(pitch) * compensation
	if c.DebugAttributes and state.Vehicle then
		state.Vehicle:SetAttribute("HoverPoseRideHeight", math.floor(state.PoseRideHeight * 100 + 0.5) / 100)
		state.Vehicle:SetAttribute("HoverPoseSettle", math.floor(settle * 100 + 0.5) / 100)
		state.Vehicle:SetAttribute("HoverPoseLift", math.floor(lift * 100 + 0.5) / 100)
	end
end

local function updateHoverWobble(dt, speedMph, grounded)
	dt = math.clamp(dt or 0, 0, 0.1)
	local c = state.PoseConfig
	if c.WobbleSpeed == nil then c = refreshPoseConfig() end
	local enabled = configBool("HoverWobble", "WobbleEnabled", true)
	if not enabled or not grounded then
		local decay = 1 - math.exp(-6 * dt)
		state.WobblePitch += (0 - state.WobblePitch) * decay
		state.WobbleRoll += (0 - state.WobbleRoll) * decay
		state.WobbleYaw += (0 - state.WobbleYaw) * decay
		state.WobbleBob += (0 - state.WobbleBob) * decay
		return state.WobblePitch, state.WobbleRoll
	end

	speedMph = speedMph or 0
	if speedMph ~= speedMph then speedMph = 0 end
	local speedFraction = math.clamp(speedMph / c.WobbleFadeOutMph, 0, 1)
	local idle = 1 - speedFraction
	local restBoost = 1 + c.WobbleRestBoost * (1 - poseSmoothstep(speedMph / c.WobbleRestMph))
	-- idle sway fades with speed as before; a small faster trace stays alive at speed
	local strength = math.max(idle, c.WobbleAtSpeedAmount) * restBoost
	local randomise = c.WobbleRandomiseAmount
	local detail = c.WobbleDetailAmount

	state.WobbleTime += dt * c.WobbleSpeed * (1 + c.WobbleAtSpeedSpeedBoost * speedFraction)
	local t = state.WobbleTime
	local seedX, seedY, seedZ = state.WobbleSeedX, state.WobbleSeedY, state.WobbleSeedZ
	local slowPitch = math.noise(seedX, t, 0) + math.noise(seedX + 17.3, t * 2.31, 0.5) * 0.45 * detail
	local slowRoll = math.noise(seedZ, 0, t * 1.13) + math.noise(seedZ + 41.9, 0.5, t * 2.57) * 0.45 * detail
	local flutterPitch = math.sin(t * 2.7 + seedX) * 0.22
	local flutterRoll = math.sin(t * 2.1 + seedZ) * 0.22
	local radians = math.rad(c.WobbleAmountDegrees) * strength
	local targetPitch = (slowPitch + flutterPitch * randomise) * radians * c.WobblePitchMultiplier
	local targetRoll = (slowRoll + flutterRoll * randomise) * radians * c.WobbleRollMultiplier
	local targetYaw = (math.noise(seedY, t * 0.71, 3.3) + math.sin(t * 0.83 + seedY) * 0.3 * randomise) * math.rad(c.WobbleYawDegrees) * idle * restBoost
	local targetBob = (math.sin(t * 1.57 + seedY) * 0.6 + math.noise(seedY + 9.1, t * 0.9, 7.7) * 0.9) * c.WobbleBobStuds * strength
	local alpha = 1 - math.exp(-c.WobbleSmoothing * dt)
	state.WobblePitch += (targetPitch - state.WobblePitch) * alpha
	state.WobbleRoll += (targetRoll - state.WobbleRoll) * alpha
	state.WobbleYaw += (targetYaw - state.WobbleYaw) * alpha
	state.WobbleBob += (targetBob - state.WobbleBob) * alpha
	if state.WobblePitch ~= state.WobblePitch or state.WobbleRoll ~= state.WobbleRoll or state.WobbleYaw ~= state.WobbleYaw or state.WobbleBob ~= state.WobbleBob then
		state.WobblePitch, state.WobbleRoll, state.WobbleYaw, state.WobbleBob = 0, 0, 0, 0
	end
	return state.WobblePitch, state.WobbleRoll
end
"""

_START_OLD = "\tstate.WobbleSeedX = math.random() * 1000\n\tstate.WobbleSeedZ = math.random() * 1000\n"
_START_NEW = _START_OLD + """\tstate.WobbleSeedY = math.random() * 1000
	state.WobbleYaw = 0
	state.WobbleBob = 0
	state.PoseSettle = nil
	state.PoseSettleVelocity = 0
	state.PoseLift = 0
	state.PoseLiftVelocity = 0
	state.PoseLean = 0
	state.PosePitch = 0
	state.PoseRideHeight = HOVER_HEIGHT
	state.PoseRollTerm = 0
	state.PosePitchTerm = 0
	state.PoseConfigTimer = 0
	measureHoverBody(state.Vehicle)
"""

_ANCHORED_OLD = ("\t\t\tstate.Feel.Skip = true\n\t\t\tstate.Feel.PreviousVelocity = nil\n"
                 "\t\t\tif state.Vehicle:GetAttribute(\"FeelSpeedMph\") ~= nil then\n")
_ANCHORED_NEW = ("\t\t\tstate.Feel.Skip = true\n\t\t\tstate.Feel.PreviousVelocity = nil\n"
                 "\t\t\tstate.PoseSettle = nil\n\t\t\tstate.PoseSettleVelocity = 0\n\t\t\tstate.PoseLift = 0\n"
                 "\t\t\tstate.PoseLiftVelocity = 0\n\t\t\tstate.PoseLean = state.CurrentBank + state.WobbleRoll\n"
                 "\t\t\tif state.Vehicle:GetAttribute(\"FeelSpeedMph\") ~= nil then\n")

_LOOP_OLD = "\t\tfor index, corner in ipairs(state.Controls.Corners) do\n\t\t\tlocal result = hoverResults[index]\n"
_LOOP_NEW = "\t\tupdateHoverPose(dt, speedMph, forwardSpeed, throttle, hoverResults)\n" + _LOOP_OLD

_TARGET_OLD = "\t\t\t\tlocal targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT\n"
_TARGET_NEW = ("\t\t\t\tlocal targetDistance = state.PoseRideHeight + SENSOR_START_HEIGHT"
               " + corner.Offset.X * state.PoseRollTerm - corner.Offset.Z * state.PosePitchTerm\n")

_ALIGN_OLD = ("\t\tstate.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal)"
              " * CFrame.Angles(wobblePitch + accelBrakePitch, 0, state.CurrentBank + wobbleRoll)\n")
_ALIGN_NEW = ("\t\tstate.PosePitch = wobblePitch + accelBrakePitch\n"
              "\t\tstate.Controls.Align.CFrame = CFrame.lookAt(root.Position, root.Position + terrainForward, groundNormal)"
              " * CFrame.Angles(wobblePitch + accelBrakePitch, state.WobbleYaw, state.CurrentBank + wobbleRoll)\n")

# ------------------------------------------------------------------------------------ FreeRoamParkedHoverClient

_P_HEAD_OLD = "local ALIGN_RESPONSIVENESS = 10\n"
_P_HEAD_NEW = _P_HEAD_OLD + """
-- Parked pose: same rest height, settle and wobble family as DrivingClient (Config.Vehicles.HoverPose / HoverWobble).
local VEHICLE_CONFIG = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Vehicles")
local MPH_PER_STUD = 0.625
local poseConfig = {}
local poseConfigClock = -1
local function poseNumber(folderName, name, fallback, minimum, maximum)
	local folder = VEHICLE_CONFIG:FindFirstChild(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value then value = fallback end
	return math.clamp(value, minimum, maximum)
end
local function poseBool(folderName, name, fallback)
	local folder = VEHICLE_CONFIG:FindFirstChild(folderName)
	local value = folder and folder:GetAttribute(name)
	if typeof(value) ~= "boolean" then return fallback end
	return value
end
local function refreshPoseConfig()
	local c = poseConfig
	c.SettleEnabled = poseBool("HoverPose", "SettleEnabled", true)
	c.SettleRestScale = poseNumber("HoverPose", "SettleRestScale", 0.7, 0.3, 1)
	c.SettleStartMph = poseNumber("HoverPose", "SettleStartMph", 1, 0, 40)
	c.SettleFullHeightMph = poseNumber("HoverPose", "SettleFullHeightMph", 22, 2, 200)
	c.SettleFrequencyHz = poseNumber("HoverPose", "SettleFrequencyHz", 1.3, 0.2, 4)
	c.SettleDamping = poseNumber("HoverPose", "SettleDamping", 0.3, 0.1, 2)
	c.BankLiftEnabled = poseBool("HoverPose", "BankLiftEnabled", true)
	c.BankLiftMaxStuds = poseNumber("HoverPose", "BankLiftMaxStuds", 2.4, 0, 6)
	c.BankLiftRiseHz = poseNumber("HoverPose", "BankLiftRiseHz", 4, 0.3, 6)
	c.BankLiftFallHz = poseNumber("HoverPose", "BankLiftFallHz", 1.4, 0.3, 6)
	c.MinEdgeClearanceStuds = poseNumber("HoverPose", "MinEdgeClearanceStuds", 0.25, 0, 2)
	c.LeanSpringCompensation = poseNumber("HoverPose", "LeanSpringCompensation", 1, 0, 1)
	c.ParkedExitDipStuds = poseNumber("HoverPose", "ParkedExitDipStuds", 0.1, 0, 0.6)
	c.ParkedAnchoredPresentationEnabled = poseBool("HoverPose", "ParkedAnchoredPresentationEnabled", true)
	c.WobbleEnabled = poseBool("HoverWobble", "WobbleEnabled", true) and poseBool("HoverWobble", "ParkedWobbleEnabled", true)
	c.WobbleFadeOutMph = poseNumber("HoverWobble", "WobbleFadeOutMph", 20, 1, 80)
	c.WobbleAmountDegrees = poseNumber("HoverWobble", "WobbleAmountDegrees", 1.5, 0, 8)
	c.WobbleSpeed = poseNumber("HoverWobble", "WobbleSpeed", 1.15, 0.05, 8)
	c.WobbleRandomiseAmount = poseNumber("HoverWobble", "WobbleRandomiseAmount", 0.65, 0, 2)
	c.WobblePitchMultiplier = poseNumber("HoverWobble", "WobblePitchMultiplier", 0.75, 0, 3)
	c.WobbleRollMultiplier = poseNumber("HoverWobble", "WobbleRollMultiplier", 1, 0, 3)
	c.WobbleSmoothing = poseNumber("HoverWobble", "WobbleSmoothing", 4.5, 0.25, 18)
	c.WobbleDetailAmount = poseNumber("HoverWobble", "WobbleDetailAmount", 0.6, 0, 2)
	c.WobbleBobStuds = poseNumber("HoverWobble", "WobbleBobStuds", 0.06, 0, 0.4)
	c.WobbleYawDegrees = poseNumber("HoverWobble", "WobbleYawDegrees", 0.35, 0, 4)
	c.WobbleRestBoost = poseNumber("HoverWobble", "WobbleRestBoost", 0.3, 0, 2)
	c.WobbleRestMph = poseNumber("HoverWobble", "WobbleRestMph", 4, 0.5, 40)
	c.ParkedWobbleScale = poseNumber("HoverWobble", "ParkedWobbleScale", 0.7, 0, 2)
	c.ParkedWobbleSpeedScale = poseNumber("HoverWobble", "ParkedWobbleSpeedScale", 0.85, 0.1, 3)
end
local function currentPoseConfig()
	if os.clock() - poseConfigClock > 0.25 or poseConfig.SettleRestScale == nil then
		poseConfigClock = os.clock()
		refreshPoseConfig()
	end
	return poseConfig
end
local function poseSmoothstep(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function newPose(root)
	return {
		Time = 0, Pitch = 0, Roll = 0, Yaw = 0, Bob = 0, RollTerm = 0, PitchTerm = 0,
		SeedX = math.random() * 1000, SeedY = math.random() * 1000, SeedZ = math.random() * 1000,
		Settle = nil, SettleVelocity = 0, SeedScale = nil, Lift = 0, LiftVelocity = 0, Normal = Vector3.yAxis,
		Underside = root.Size.Y * 0.5, HalfWidth = root.Size.X * 0.5, HalfLength = root.Size.Z * 0.5,
	}
end
-- Once per parked start: lowest point, and the half-width and half-length of the low parts, in root space.
local function measureBody(vehicle, root)
	local rootHalf = root.Size * 0.5
	local underside, halfWidth, halfLength = rootHalf.Y, rootHalf.X, rootHalf.Z
	local inverse = root.CFrame:Inverse()
	for _, part in ipairs(vehicle:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part.Transparency < 0.99 then
			local rel = inverse * part.CFrame
			local half = part.Size * 0.5
			local r, u, l = rel.RightVector, rel.UpVector, rel.LookVector
			local extentX = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z
			local extentY = math.abs(r.Y) * half.X + math.abs(u.Y) * half.Y + math.abs(l.Y) * half.Z
			local extentZ = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
			local y = rel.Position.Y - extentY
			if y == y and y < 0.5 then
				underside = math.max(underside, math.min(-y, rootHalf.Y + 1.5))
				local x = math.min(math.abs(rel.Position.X) + extentX, rootHalf.X + 6)
				local z = math.min(math.abs(rel.Position.Z) + extentZ, rootHalf.Z + 12)
				if x == x then halfWidth = math.max(halfWidth, x) end
				if z == z then halfLength = math.max(halfLength, z) end
			end
		end
	end
	return underside, halfWidth, halfLength
end
-- Per frame for the one parked car: wobble angles into pose.Pitch/Yaw/Roll, returns the ride height.
local function updatePose(pose, root, dt)
	local c = currentPoseConfig()
	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD
	if speedMph ~= speedMph then speedMph = 0 end
	local steps = math.clamp(math.ceil(dt * 60 - 0.001), 1, 6)
	local stepTime = dt / steps

	local strength = 0
	if c.WobbleEnabled then
		local restBoost = 1 + c.WobbleRestBoost * (1 - poseSmoothstep(speedMph / c.WobbleRestMph))
		strength = (1 - math.clamp(speedMph / c.WobbleFadeOutMph, 0, 1)) * restBoost * c.ParkedWobbleScale
	end
	pose.Time += dt * c.WobbleSpeed * c.ParkedWobbleSpeedScale
	local t = pose.Time
	local seedX, seedY, seedZ = pose.SeedX, pose.SeedY, pose.SeedZ
	local randomise = c.WobbleRandomiseAmount
	local detail = c.WobbleDetailAmount
	local slowPitch = math.noise(seedX, t, 0) + math.noise(seedX + 17.3, t * 2.31, 0.5) * 0.45 * detail
	local slowRoll = math.noise(seedZ, 0, t * 1.13) + math.noise(seedZ + 41.9, 0.5, t * 2.57) * 0.45 * detail
	local radians = math.rad(c.WobbleAmountDegrees) * strength
	local targetPitch = (slowPitch + math.sin(t * 2.7 + seedX) * 0.22 * randomise) * radians * c.WobblePitchMultiplier
	local targetRoll = (slowRoll + math.sin(t * 2.1 + seedZ) * 0.22 * randomise) * radians * c.WobbleRollMultiplier
	local targetYaw = (math.noise(seedY, t * 0.71, 3.3) + math.sin(t * 0.83 + seedY) * 0.3 * randomise) * math.rad(c.WobbleYawDegrees) * strength
	local targetBob = (math.sin(t * 1.57 + seedY) * 0.6 + math.noise(seedY + 9.1, t * 0.9, 7.7) * 0.9) * c.WobbleBobStuds * strength
	local alpha = 1 - math.exp(-c.WobbleSmoothing * dt)
	pose.Pitch += (targetPitch - pose.Pitch) * alpha
	pose.Roll += (targetRoll - pose.Roll) * alpha
	pose.Yaw += (targetYaw - pose.Yaw) * alpha
	pose.Bob += (targetBob - pose.Bob) * alpha
	if pose.Pitch ~= pose.Pitch or pose.Roll ~= pose.Roll or pose.Yaw ~= pose.Yaw or pose.Bob ~= pose.Bob then
		pose.Pitch, pose.Roll, pose.Yaw, pose.Bob = 0, 0, 0, 0
	end

	local settle = 1
	if c.SettleEnabled then
		local curve = poseSmoothstep((speedMph - c.SettleStartMph) / math.max(c.SettleFullHeightMph - c.SettleStartMph, 1))
		local target = c.SettleRestScale + (1 - c.SettleRestScale) * curve
		local omega = c.SettleFrequencyHz * 2 * math.pi
		if pose.Settle == nil then
			-- continue from the height the driving controller left the car at, with a small power-down dip
			pose.Settle = math.clamp(pose.SeedScale or target, c.SettleRestScale, 1.3)
			pose.SettleVelocity = -(c.ParkedExitDipStuds / HOVER_HEIGHT) * omega / 0.65
		end
		local position, velocity = pose.Settle, pose.SettleVelocity
		for _ = 1, steps do
			velocity += (omega * omega * (target - position) - 2 * c.SettleDamping * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = target, 0
		end
		pose.Settle = math.clamp(position, 0.3, 1.5)
		pose.SettleVelocity = math.clamp(velocity, -20, 20)
		settle = pose.Settle
	else
		pose.Settle = nil
		pose.SettleVelocity = 0
	end

	local base = HOVER_HEIGHT * settle + pose.Bob
	local lift = 0
	if c.BankLiftEnabled and c.MinEdgeClearanceStuds > 0 then
		-- no bank when parked: only keep the lowest point clear at the rest height. Same sum as the driving
		-- controller (commanded wobble roll and pitch), so both rest at the same height on flat ground; the
		-- car's real tilt against the ground only counts beyond 2 degrees (the driving bank just after an
		-- exit while steering, or a base the server left tilted)
		local normal = pose.Normal
		local frame = root.CFrame
		local rollAngle = math.abs(pose.Roll)
		local pitchAngle = math.abs(pose.Pitch)
		local realRoll = math.asin(math.clamp(math.abs(frame.RightVector:Dot(normal)), 0, 1))
		local realPitch = math.asin(math.clamp(math.abs(frame.LookVector:Dot(normal)), 0, 1))
		if realRoll == realRoll then rollAngle += math.max(realRoll - rollAngle - 0.035, 0) end
		if realPitch == realPitch then pitchAngle += math.max(realPitch - pitchAngle - 0.035, 0) end
		local drop = pose.HalfWidth * math.sin(math.min(rollAngle, 0.6)) + pose.HalfLength * math.sin(math.min(pitchAngle, 0.5))
		local want = math.clamp(c.MinEdgeClearanceStuds + pose.Underside + drop - base, 0, c.BankLiftMaxStuds)
		local position, velocity = pose.Lift, pose.LiftVelocity
		for _ = 1, steps do
			local omega = (want > position and c.BankLiftRiseHz or c.BankLiftFallHz) * 2 * math.pi
			velocity += (omega * omega * (want - position) - 2 * omega * velocity) * stepTime
			position += velocity * stepTime
		end
		if position ~= position or velocity ~= velocity then
			position, velocity = want, 0
		end
		pose.Lift = math.clamp(position, 0, c.BankLiftMaxStuds)
		pose.LiftVelocity = math.clamp(velocity, -40, 40)
		lift = pose.Lift
	else
		pose.Lift = 0
		pose.LiftVelocity = 0
	end
	pose.RollTerm = math.sin(pose.Roll) * math.cos(pose.Pitch) * c.LeanSpringCompensation
	pose.PitchTerm = math.sin(pose.Pitch) * c.LeanSpringCompensation
	return math.clamp(base + lift, math.min(0.5, HOVER_HEIGHT), math.min(HOVER_HEIGHT * 2, SENSOR_LENGTH - SENSOR_START_HEIGHT - 1))
end
"""

_P_STATE_OLD = "\tlocal state = { Root = root, Align = align, Corners = corners, CoastDrag = coastDrag }\n"
_P_STATE_NEW = """	local pose = newPose(root)
	pose.Underside, pose.HalfWidth, pose.HalfLength = measureBody(vehicle, root)
	do
		-- one reading at start (not per frame): the height the car is at now, so the hand-over has no jump
		local sum, count = 0, 0
		for _, corner in ipairs(corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), rayParams)
			if result then
				sum += result.Distance - SENSOR_START_HEIGHT
				count += 1
			end
		end
		if count > 0 then pose.SeedScale = sum / count / HOVER_HEIGHT end
	end
	local state = { Root = root, Align = align, Corners = corners, CoastDrag = coastDrag, Pose = pose }
"""

_P_CONNECT_OLD = "\tstate.Connection = RunService.Heartbeat:Connect(function()\n"
_P_CONNECT_NEW = "\tstate.Connection = RunService.Heartbeat:Connect(function(dt)\n"

_P_LIFT_OLD = "\t\tlocal liftPerCorner = mass * Workspace.Gravity / math.max(#corners, 1)\n"
_P_LIFT_NEW = "\t\tlocal rideHeight = updatePose(pose, root, math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 0.1))\n" + _P_LIFT_OLD

_P_TARGET_OLD = "\t\t\t\tlocal targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT\n"
_P_TARGET_NEW = ("\t\t\t\tlocal targetDistance = rideHeight + SENSOR_START_HEIGHT"
                 " + corner.Offset.X * pose.RollTerm - corner.Offset.Z * pose.PitchTerm\n")

_P_ALIGN_OLD = "\t\talign.CFrame = CFrame.lookAt(root.Position, root.Position + forward, normal)\n"
_P_ALIGN_NEW = ("\t\tpose.Normal = normal\n"
                "\t\talign.CFrame = CFrame.lookAt(root.Position, root.Position + forward, normal)"
                " * CFrame.Angles(pose.Pitch, pose.Yaw, pose.Roll)\n")

_P_TOP_OLD = "RunService.Heartbeat:Connect(function()\n\twatchPromptReentry()\n"
_P_TOP_NEW = """-- Anchored parked car (the server anchors the car on exit: ParkedFixed). Nothing simulates it, so the local
-- player's own car is posed here by writing root.CFrame: same rest height, settle and wobble as the keeper above.
-- Local only (a client write to a server-anchored part does not replicate). No forces, no constraints.
local present = { Vehicle = nil, Root = nil, Seat = nil, Base = nil, Last = nil, Pose = nil, GroundY = 0, Normal = Vector3.yAxis, RayClock = 0, RetryClock = 0, RayParams = nil }
local lastFreeVehicle, lastFreeY, lastFreeClock = nil, 0, -10

local function presentationWanted(vehicle)
	if not vehicle or not vehicle.Parent then return false end
	local root = vehicle.PrimaryPart
	if not root or not root.Anchored then return false end
	if vehicle:GetAttribute("ParkedShowcase") ~= true then return false end
	if vehicle:GetAttribute("DriverUserId") ~= nil then return false end
	return true
end

local function stopPresentation(restore)
	local root = present.Root
	if restore and root and root.Parent and root.Anchored and present.Base and present.Last then
		-- put the car back exactly where the server placed it, unless the server has moved it since
		if (root.CFrame.Position - present.Last.Position).Magnitude < 0.02 then
			root.CFrame = present.Base
		end
	end
	present.Vehicle = nil
	present.Root = nil
	present.Seat = nil
	present.Base = nil
	present.Last = nil
	present.Pose = nil
end

local function presentationGround(vehicle, position)
	local params = present.RayParams
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		present.RayParams = params
	end
	params.FilterDescendantsInstances = { vehicle, player.Character }
	return Workspace:Raycast(position + Vector3.new(0, SENSOR_START_HEIGHT, 0), Vector3.new(0, -SENSOR_LENGTH, 0), params)
end

local function updateAnchoredPresentation(vehicle, dt)
	local now = os.clock()
	if present.Vehicle then
		local seat = present.Seat
		if present.Vehicle ~= vehicle or present.Root ~= vehicle.PrimaryPart or not presentationWanted(vehicle) or (seat and seat.Occupant ~= nil) then
			stopPresentation(false)
		elseif not currentPoseConfig().ParkedAnchoredPresentationEnabled then
			stopPresentation(true)
		end
	end
	local root = vehicle and vehicle.PrimaryPart
	if not root then return end

	if not present.Vehicle then
		if not presentationWanted(vehicle) then
			-- remember where the car really is while it is driven or coasting: the anchor arrives with the
			-- server's older height, and the presentation starts from this one instead
			local y = root.Position.Y
			if y == y then
				lastFreeVehicle, lastFreeY, lastFreeClock = vehicle, y, now
			end
			return
		end
		if now < present.RetryClock then return end
		if not currentPoseConfig().ParkedAnchoredPresentationEnabled then return end
		present.RetryClock = now + 0.5
		if seatOccupied(vehicle) then return end
		local base = root.CFrame
		local basePosition = base.Position
		if basePosition.X ~= basePosition.X or basePosition.Y ~= basePosition.Y or basePosition.Z ~= basePosition.Z then return end
		local hit = presentationGround(vehicle, basePosition)
		if not hit then return end
		local baseHeight = basePosition.Y - hit.Position.Y
		if baseHeight < 0.3 or baseHeight > HOVER_HEIGHT * 2 then return end
		local keeper = active[vehicle]
		local pose = keeper and keeper.Pose
		if not pose then
			pose = newPose(root)
			pose.Underside, pose.HalfWidth, pose.HalfLength = measureBody(vehicle, root)
			pose.SeedScale = baseHeight / HOVER_HEIGHT
		end
		if lastFreeVehicle == vehicle and now - lastFreeClock < 0.5 and math.abs(lastFreeY - basePosition.Y) < 4 then
			-- continue from the height the car was last seen at on this client
			local scale = (lastFreeY - hit.Position.Y) / HOVER_HEIGHT
			if pose.Settle ~= nil then
				pose.Settle = math.clamp(scale, 0.3, 1.5)
			else
				pose.SeedScale = scale
			end
		end
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		present.Vehicle = vehicle
		present.Root = root
		present.Seat = (seat and seat:IsA("VehicleSeat")) and seat or nil
		present.Base = base
		present.Last = base
		present.Pose = pose
		present.GroundY = hit.Position.Y
		present.Normal = hit.Normal
		present.RayClock = now + 1
		present.RetryClock = 0
	end

	local pose = present.Pose
	local current = root.CFrame
	local last = present.Last
	if (current.Position - last.Position).Magnitude > 0.02 or current.LookVector:Dot(last.LookVector) < 0.99999 or current.UpVector:Dot(last.UpVector) < 0.99999 then
		-- the server moved the anchored car: its new placement is the base from now on
		present.Base = current
		present.RayClock = 0
	end
	local base = present.Base
	local basePosition = base.Position
	if now >= present.RayClock then
		present.RayClock = now + 1
		local hit = presentationGround(vehicle, basePosition)
		if hit and hit.Position.Y == hit.Position.Y then
			present.GroundY = hit.Position.Y
			present.Normal = hit.Normal
		end
	end
	local baseHeight = basePosition.Y - present.GroundY
	if baseHeight < 0.3 or baseHeight > HOVER_HEIGHT * 2 then
		-- not sitting over the ground we measured (moved, or placed in the air): leave it as the server has it
		present.Last = current
		stopPresentation(true)
		present.RetryClock = now + 1
		return
	end
	pose.Normal = present.Normal
	local rideHeight = updatePose(pose, root, dt)
	local y = math.clamp(present.GroundY + rideHeight, basePosition.Y - 2, basePosition.Y + 1.5)
	local pitch = math.clamp(pose.Pitch, -0.05, 0.05)
	local yaw = math.clamp(pose.Yaw, -0.03, 0.03)
	local roll = math.clamp(pose.Roll, -0.05, 0.05)
	if y ~= y or pitch ~= pitch or yaw ~= yaw or roll ~= roll then return end
	root.CFrame = CFrame.new(basePosition.X, y, basePosition.Z) * base.Rotation * CFrame.Angles(pitch, yaw, roll)
	present.Last = root.CFrame
end

-- Keeps the remembered height current after physics (Heartbeat); the presentation itself runs before render.
local function trackFreeHeight(vehicle)
	if present.Vehicle or not vehicle then return end
	local root = vehicle.PrimaryPart
	if not root or presentationWanted(vehicle) then return end
	local y = root.Position.Y
	if y == y then
		lastFreeVehicle, lastFreeY, lastFreeClock = vehicle, y, os.clock()
	end
end

-- One connection for the module. The anchor (with the server's older CFrame) arrives through replication after
-- Heartbeat, so the pose is written here, before the frame is drawn. The springs advance once per rendered frame.
local ownVehicle = nil
RunService.PreRender:Connect(function(dt)
	local vehicle = ownVehicle
	if not vehicle and not present.Vehicle then return end
	if vehicle and not vehicle.Parent then
		vehicle = nil
		ownVehicle = nil
	end
	if not vehicle then
		if present.Vehicle then stopPresentation(false) end
		return
	end
	updateAnchoredPresentation(vehicle, math.clamp(tonumber(dt) or 1 / 60, 1 / 240, 0.1))
end)

RunService.Heartbeat:Connect(function()
	watchPromptReentry()
"""

_P_CALL_OLD = "\tlocal vehicle = playerVehicle()\n\tif vehicle and shouldHover(vehicle) then\n\t\tstart(vehicle)\n\tend\n"
_P_CALL_NEW = _P_CALL_OLD + "\townVehicle = vehicle\n\ttrackFreeHeight(vehicle)\n"

EDITS = {
    "DrivingClient": [
        (_STATE_OLD, _STATE_NEW, 1),
        (_STOP_OLD, _STOP_NEW, 1),
        (_WOBBLE_OLD, _WOBBLE_NEW, 1),
        (_START_OLD, _START_NEW, 1),
        (_ANCHORED_OLD, _ANCHORED_NEW, 1),
        (_LOOP_OLD, _LOOP_NEW, 1),
        (_TARGET_OLD, _TARGET_NEW, 1),
        (_ALIGN_OLD, _ALIGN_NEW, 1),
    ],
    "FreeRoamParkedHoverClient": [
        (_P_HEAD_OLD, _P_HEAD_NEW, 1),
        (_P_STATE_OLD, _P_STATE_NEW, 1),
        (_P_CONNECT_OLD, _P_CONNECT_NEW, 1),
        (_P_LIFT_OLD, _P_LIFT_NEW, 1),
        (_P_TARGET_OLD, _P_TARGET_NEW, 1),
        (_P_ALIGN_OLD, _P_ALIGN_NEW, 1),
        (_P_TOP_OLD, _P_TOP_NEW, 1),
        (_P_CALL_OLD, _P_CALL_NEW, 1),
    ],
}

_VEHICLES = ["ReplicatedStorage", "Config", "Vehicles"]


def _folder(name, rows):
    attributes = {}
    for key, value, text in rows:
        attributes[key] = value
        attributes[key + ("_Description" if isinstance(value, bool) else "_RaisingThisDoes")] = text
    return {"parent": _VEHICLES, "name": name, "class": "Folder", "attributes": attributes}


INSTANCES = [
    _folder("HoverPose", [
        ("SettleEnabled", True, "On: the car sinks towards the ground at a standstill and rises with speed. Off: ride height stays at HoverHeightStuds."),
        ("SettleRestScale", 0.7, "Rest height as a fraction of HoverHeightStuds. Raising it makes the stopped car sit higher (1 = no lowering)."),
        ("SettleStartMph", 1.0, "Speed below which the car is fully lowered. Raising it keeps the car down for longer as it pulls away."),
        ("SettleFullHeightMph", 22.0, "Speed at which the car is back at full height. Raising it makes the sink start earlier when slowing and the rise finish later."),
        ("SettleFrequencyHz", 1.3, "Speed of the sink and rise. Raising it makes the car drop and bounce faster and tighter."),
        ("SettleDamping", 0.3, "Damping of the sink and rise. Raising it removes the bounce (1 = none); lowering it adds more bounces."),
        ("SettleThrottleLift", 0.6, "How far the car rises the moment the throttle is pressed, as a fraction of the full rise. 0 = rise from speed only."),
        ("SettleThrottleDeadzone", 0.05, "Throttle needed before the throttle rise starts. Raising it ignores light trigger presses."),
        ("BankLiftEnabled", True, "On: the car rises as it leans so the low side stays out of the ground. Off: no lift and no minimum clearance."),
        ("BankLiftAmount", 0.7, "Share of the height the low side loses in a lean that is given back as lift. Raising it lifts the car more in turns and drifts (0 = only the minimum clearance)."),
        ("BankLiftMaxStuds", 2.4, "Most the lean can raise the car. Raising it allows more lift on very wide cars."),
        ("BankLiftLeadSeconds", 0.2, "How far ahead of the lean the lift looks. Raising it makes the car start rising earlier as you turn in."),
        ("BankLiftRiseHz", 4.0, "How quickly the lift comes in. Raising it makes the rise snappier."),
        ("BankLiftFallHz", 1.4, "How quickly the car comes back down after a lean. Raising it makes it drop back sooner; lowering it makes it float down."),
        ("MinEdgeClearanceStuds", 0.25, "Gap always kept under the lowest part of the body (measured on part boxes), including when lowered or pitched. Raising it lifts the car sooner near the ground. 0 = off."),
        ("LeanSpringCompensation", 1.0, "How much the four hover springs follow the lean instead of fighting it. 1 = springs hold the leaned pose; 0 = as before (low side pushed up, high side dropped)."),
        ("ParkedExitDipStuds", 0.1, "Size of the small dip when the driver gets out. Raising it makes the car bob down further on exit. 0 = none."),
        ("ParkedAnchoredPresentationEnabled", True, "On: the parked (anchored) car is posed locally at the lowered rest height with a calm sway and bob. Off: it is left exactly where the server placed it."),
        ("DebugAttributes", False, "On: writes HoverPoseRideHeight, HoverPoseSettle and HoverPoseLift on the vehicle each frame for tuning. Leave off in normal play."),
    ]),
    _folder("HoverWobble", [
        ("WobbleEnabled", True, "On: idle sway, bob and yaw drift. Off: the car holds still (driving and parked)."),
        ("WobbleAmountDegrees", 1.5, "Size of the idle pitch and roll sway. Raising it makes the car rock further."),
        ("WobbleSpeed", 1.15, "Speed of all wobble motion. Raising it makes the sway and bob quicker."),
        ("WobbleFadeOutMph", 20.0, "Speed at which the idle sway has faded to its at-speed trace. Raising it keeps the sway for longer as you pull away."),
        ("WobbleRandomiseAmount", 0.65, "Strength of the regular flutter layered on the slow drift. Raising it adds more quick movement."),
        ("WobblePitchMultiplier", 0.75, "Nose up and down share of the sway. Raising it makes the car nod more."),
        ("WobbleRollMultiplier", 1.0, "Side to side share of the sway. Raising it makes the car rock more."),
        ("WobbleSmoothing", 4.5, "How closely the car follows the wobble pattern. Raising it makes the motion crisper; lowering it makes it lazier."),
        ("WobbleDetailAmount", 0.6, "Strength of a second, faster layer so the sway never looks repeated. 0 = the old single layer."),
        ("WobbleBobStuds", 0.06, "Up and down float at idle. Raising it makes the car bob further. 0 = none."),
        ("WobbleYawDegrees", 0.35, "Slow nose left and right drift at idle (never at speed). Raising it makes the car wander more. 0 = none."),
        ("WobbleRestBoost", 0.3, "Extra sway when fully stopped. Raising it makes a standing car look more alive. 0 = none."),
        ("WobbleRestMph", 4.0, "Speed below which the standstill boost applies. Raising it keeps the boost while creeping."),
        ("WobbleAtSpeedAmount", 0.15, "Share of the sway kept at speed. Raising it keeps more movement while driving fast. 0 = fades out completely as before."),
        ("WobbleAtSpeedSpeedBoost", 1.0, "How much faster the wobble runs at speed. Raising it makes the at-speed trace quicker and finer."),
        ("ParkedWobbleEnabled", True, "On: the parked car keeps a calm sway and bob after the driver gets out. Off: parked cars hold still."),
        ("ParkedWobbleScale", 0.7, "Size of the parked sway compared with idling in the seat. Raising it makes the parked car move more."),
        ("ParkedWobbleSpeedScale", 0.85, "Speed of the parked sway compared with idling in the seat. Raising it makes the parked car move quicker."),
    ]),
]

ATTRIBUTES = []
