-- drivetrain_feel Play probe (datamodel: Client). Read-only: it never writes game state, only a client-local
-- attribute on the LocalPlayer that holds its own result. Start it, drive with real key input, then read it back.
--   ARGS.mode = "start": samples every Heartbeat for ARGS.seconds into memory, then stores a JSON summary in
--                        LocalPlayer@DrivetrainFeelSample (client-local; not replicated).
--   ARGS.mode = "read":  returns that JSON.
-- Speed is the real forward speed of the driven vehicle's root (studs/s x 0.625 = mph), not the HUD number.
local ARGS = { mode = "start", seconds = 12, every = 0.1, label = "run" }

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local KEY = "DrivetrainFeelSample"

if ARGS.mode == "read" then
	return player:GetAttribute(KEY) or "{}"
end

local function vehicle()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	while model and model.Parent and model.Parent:IsA("Model") do model = model.Parent end
	return model
end

local car = vehicle()
if not car then return HttpService:JSONEncode({ ok = false, error = "not seated in a vehicle" }) end
local root = car.PrimaryPart or car:FindFirstChild("Root", true)
player:SetAttribute(KEY, nil)

task.spawn(function()
	local rows, events = {}, {}
	local t0 = os.clock()
	local nextRow = 0
	local lastGear, lastSpin = car:GetAttribute("FeelGear"), 0
	local maxSpeed, maxYaw, maxSpin, t60, t100 = 0, 0, 0, nil, nil
	local headingStart
	local maxHeadingTurn = 0
	while os.clock() - t0 < ARGS.seconds and car.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		local cf = root.CFrame
		local v = root.AssemblyLinearVelocity
		local fwd = v:Dot(cf.LookVector) * 0.625
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude * 0.625
		local yawRate = root.AssemblyAngularVelocity.Y
		local heading = math.deg(math.atan2(-cf.LookVector.X, -cf.LookVector.Z))
		headingStart = headingStart or heading
		local turn = math.abs(((heading - headingStart + 540) % 360) - 180)
		maxHeadingTurn = math.max(maxHeadingTurn, turn)
		maxSpeed = math.max(maxSpeed, speed)
		maxYaw = math.max(maxYaw, math.abs(yawRate))
		local spin = car:GetAttribute("FeelSpin") or 0
		maxSpin = math.max(maxSpin, spin)
		if not t60 and fwd >= 60 then t60 = t end
		if not t100 and fwd >= 100 then t100 = t end
		local gear = car:GetAttribute("FeelGear")
		if gear ~= lastGear then
			table.insert(events, { t = math.floor(t * 1000) / 1000, gear = gear, from = lastGear, mph = math.floor(fwd + 0.5), rpm = car:GetAttribute("FeelRpm") })
			lastGear = gear
		end
		if t >= nextRow then
			nextRow = t + ARGS.every
			local slip = 0
			if speed > 1 then slip = math.deg(math.acos(math.clamp(v.Unit:Dot(cf.LookVector), -1, 1))) end
			table.insert(rows, {
				math.floor(t * 100) / 100, math.floor(fwd * 10) / 10, math.floor(speed * 10) / 10,
				gear, car:GetAttribute("FeelRpm"), math.floor(spin * 100) / 100, math.floor(yawRate * 100) / 100,
				math.floor(slip), math.floor(turn), car:GetAttribute("FeelCut"), car:GetAttribute("FeelOverdrive"),
			})
		end
	end
	player:SetAttribute(KEY, HttpService:JSONEncode({
		ok = true, label = ARGS.label, cockpit = car:GetAttribute("CockpitId"), category = car:GetAttribute("CategoryId"),
		pi = car:GetAttribute("PerformanceIndex"), seconds = ARGS.seconds,
		t60 = t60, t100 = t100, maxSpeed = maxSpeed, maxYawRate = maxYaw, maxSpin = maxSpin, maxHeadingTurn = maxHeadingTurn,
		shifts = events,
		columns = { "t", "fwdMph", "speedMph", "gear", "rpm", "spin", "yawRate", "slipDeg", "turnDeg", "cut", "overdrive" },
		rows = rows,
	}))
end)
return HttpService:JSONEncode({ ok = true, started = ARGS.label, cockpit = car:GetAttribute("CockpitId"), category = car:GetAttribute("CategoryId") })
