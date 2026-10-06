local MODE = "AUDIT"
local DATA = game:GetService("HttpService"):JSONDecode([==[{"attributes": [{"key": "SteeringCoastAssumeForward", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": true}, {"key": "SteeringCoastAssumeForward_Description", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "True: with no throttle held the car steers as if going forwards, unless the player was reversing and is still rolling back, or it rolls back faster than SteeringCoastReverseMph. False: the earlier rule (any backward drift over SteeringCoastDirectionMph steers as reverse)."}, {"key": "SteeringCoastReverseMph", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": 8}, {"key": "SteeringCoastReverseMph_RaisingThisDoes", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "Requires a faster backward roll, with no throttle held and no reverse asked for, before steering switches to reverse."}, {"key": "SpeedDisplayCurveEnabled", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": true}, {"key": "SpeedDisplayCurveEnabled_Description", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "True: the HUD speed reads lower than the real speed at low speed and higher at high speed. Display only."}, {"key": "SpeedDisplayLowMultiplier", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": 0.86}, {"key": "SpeedDisplayLowMultiplier_RaisingThisDoes", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "Makes the HUD speed read closer to (or above) the real speed near a standstill. 1 shows the real speed."}, {"key": "SpeedDisplayHighMultiplier", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": 1.08}, {"key": "SpeedDisplayHighMultiplier_RaisingThisDoes", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "Makes the HUD speed read higher at SpeedDisplayFullMph and above. 1 shows the real speed."}, {"key": "SpeedDisplayFullMph", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": 160}, {"key": "SpeedDisplayFullMph_RaisingThisDoes", "path": ["ReplicatedStorage", "Config", "Vehicles", "Driving"], "value": "Moves the real speed at which the HUD reaches its full high-speed multiplier higher, so the HUD reads low over more of the range."}], "base": "scripts/driving_tune/", "instances": [{"attributes": {"BalanceAccelBrakeExtraNerf": 0.15, "BalanceAccelBrakeExtraNerf_RaisingThisDoes": "Extra nerf on top of the base nerf for acceleration, braking and boost push (each scaled by its ExtraShare).", "BalanceAccelerationBaseShare": 1, "BalanceAccelerationBaseShare_RaisingThisDoes": "Takes more of the base nerf off forward acceleration.", "BalanceAccelerationExtraShare": 1, "BalanceAccelerationExtraShare_RaisingThisDoes": "Takes more of BalanceAccelBrakeExtraNerf off forward acceleration.", "BalanceBoostBaseShare": 1, "BalanceBoostBaseShare_RaisingThisDoes": "Takes more of the base nerf off the held boost push.", "BalanceBoostExtraShare": 1, "BalanceBoostExtraShare_RaisingThisDoes": "Takes more of BalanceAccelBrakeExtraNerf off the held boost push. At 1 boosted top speed falls by the same share as normal top speed.", "BalanceBrakingBaseShare": 1, "BalanceBrakingBaseShare_RaisingThisDoes": "Takes more of the base nerf off braking.", "BalanceBrakingExtraShare": 1, "BalanceBrakingExtraShare_RaisingThisDoes": "Takes more of BalanceAccelBrakeExtraNerf off braking.", "BalanceCurveEase": 0.5, "BalanceCurveEase_RaisingThisDoes": "Bends the line between the low and high nerf into an S: 0 is a straight line, 1 is flat at both ends and steepest in the middle.", "BalanceDragCoupling": 1, "BalanceDragCoupling_RaisingThisDoes": "1 retunes air drag so real top speed falls by exactly the top speed nerf and no more. 0 leaves drag alone, so the acceleration nerf also lowers top speed further.", "BalanceDriftAlignmentBaseShare": 0.5, "BalanceDriftAlignmentBaseShare_RaisingThisDoes": "Takes more of the base nerf off the pull that swings momentum round to where the car points in a drift.", "BalanceDriftAlignmentExtraShare": 1, "BalanceDriftAlignmentExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off that momentum pull, so drifts carry wider.", "BalanceDriftChargeBaseShare": 0, "BalanceDriftChargeBaseShare_RaisingThisDoes": "Takes more of the base nerf off how fast a drift charges its mini-boost.", "BalanceDriftChargeExtraShare": 0.5, "BalanceDriftChargeExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off how fast a drift charges its mini-boost.", "BalanceDriftEngineAssistBaseShare": 0, "BalanceDriftEngineAssistBaseShare_RaisingThisDoes": "Takes more of the base nerf off the extra engine push while drifting.", "BalanceDriftEngineAssistExtraShare": 1, "BalanceDriftEngineAssistExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off the extra engine push while drifting, so drifts lose more speed.", "BalanceDriftExtraNerf": 0.2, "BalanceDriftExtraNerf_RaisingThisDoes": "Extra nerf on top of the base nerf for drifting (each drift value scaled by its ExtraShare).", "BalanceDriftSideForceBaseShare": 1, "BalanceDriftSideForceBaseShare_RaisingThisDoes": "Takes more of the base nerf off the drift slide-out push. At 1 the slide angle stays about the same as speeds drop.", "BalanceDriftSideForceExtraShare": 0, "BalanceDriftSideForceExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off the drift slide-out push. Raising it makes drifts slide out less (tidier, not weaker).", "BalanceDriftTurnBaseShare": 0, "BalanceDriftTurnBaseShare_RaisingThisDoes": "Takes more of the base nerf off the extra turning a drift gives (on top of the steering share).", "BalanceDriftTurnExtraShare": 1, "BalanceDriftTurnExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off the extra turning a drift gives, so drifts take corners wider.", "BalanceEnabled": 1, "BalanceEnabled_RaisingThisDoes": "1 turns the performance balance nerf on. 0 turns all of it off (every multiplier becomes 1).", "BalanceFallbackPerformanceIndex": 525, "BalanceFallbackPerformanceIndex_RaisingThisDoes": "PerformanceIndex assumed for a vehicle that has none. Raising it nerfs such vehicles more.", "BalanceGripBaseShare": 0.25, "BalanceGripBaseShare_RaisingThisDoes": "Takes more of the base nerf off normal (non-drift) sideways grip, so cars slide wider in fast corners.", "BalanceHighNerf": 0.25, "BalanceHighNerf_RaisingThisDoes": "Nerfs the fastest cars more. 0.25 = 25 percent base nerf at BalanceHighPerformanceIndex.", "BalanceHighPerformanceIndex": 900, "BalanceHighPerformanceIndex_RaisingThisDoes": "Moves the end of the curve up: cars at or above this PerformanceIndex get BalanceHighNerf, so cars below it are nerfed less.", "BalanceLowNerf": 0.1, "BalanceLowNerf_RaisingThisDoes": "Nerfs the slowest cars more. 0.10 = 10 percent base nerf at BalanceLowPerformanceIndex.", "BalanceLowPerformanceIndex": 200, "BalanceLowPerformanceIndex_RaisingThisDoes": "Moves the start of the curve up: cars at or below this PerformanceIndex get BalanceLowNerf.", "BalanceMiniBoostBaseShare": 1, "BalanceMiniBoostBaseShare_RaisingThisDoes": "Takes more of the base nerf off the drift mini-boost push.", "BalanceMiniBoostExtraShare": 1, "BalanceMiniBoostExtraShare_RaisingThisDoes": "Takes more of BalanceDriftExtraNerf off the drift mini-boost push.", "BalanceRefreshSeconds": 0.25, "BalanceRefreshSeconds_RaisingThisDoes": "Makes edits to this folder take longer to reach a car being driven (the multipliers are recomputed this often). No effect on feel.", "BalanceReverseBaseShare": 1, "BalanceReverseBaseShare_RaisingThisDoes": "Takes more of the base nerf off reverse acceleration.", "BalanceReverseExtraShare": 0, "BalanceReverseExtraShare_RaisingThisDoes": "Takes more of BalanceAccelBrakeExtraNerf off reverse acceleration.", "BalanceSteeringBaseShare": 0.4, "BalanceSteeringBaseShare_RaisingThisDoes": "Takes more of the base nerf off turn rate (all steering, drifting included).", "BalanceTopSpeedBaseShare": 1, "BalanceTopSpeedBaseShare_RaisingThisDoes": "Takes more of the base nerf off top speed."}, "class": "Folder", "name": "08_Balance", "parent": ["ReplicatedStorage", "Config", "Vehicles", "Dynamics"]}, {"attributes": {"BankLiftAmount": 0.7, "BankLiftAmount_RaisingThisDoes": "Share of the height the low side loses in a lean that is given back as lift. Raising it lifts the car more in turns and drifts (0 = only the minimum clearance).", "BankLiftEnabled": true, "BankLiftEnabled_Description": "On: the car rises as it leans so the low side stays out of the ground. Off: no lift and no minimum clearance.", "BankLiftFallHz": 1.4, "BankLiftFallHz_RaisingThisDoes": "How quickly the car comes back down after a lean. Raising it makes it drop back sooner; lowering it makes it float down.", "BankLiftLeadSeconds": 0.2, "BankLiftLeadSeconds_RaisingThisDoes": "How far ahead of the lean the lift looks. Raising it makes the car start rising earlier as you turn in.", "BankLiftMaxStuds": 2.4, "BankLiftMaxStuds_RaisingThisDoes": "Most the lean can raise the car. Raising it allows more lift on very wide cars.", "BankLiftRiseHz": 4.0, "BankLiftRiseHz_RaisingThisDoes": "How quickly the lift comes in. Raising it makes the rise snappier.", "DebugAttributes": false, "DebugAttributes_Description": "On: writes HoverPoseRideHeight, HoverPoseSettle and HoverPoseLift on the vehicle each frame for tuning. Leave off in normal play.", "LeanSpringCompensation": 1.0, "LeanSpringCompensation_RaisingThisDoes": "How much the four hover springs follow the lean instead of fighting it. 1 = springs hold the leaned pose; 0 = as before (low side pushed up, high side dropped).", "MinEdgeClearanceStuds": 0.25, "MinEdgeClearanceStuds_RaisingThisDoes": "Gap always kept under the lowest part of the body (measured on part boxes), including when lowered or pitched. Raising it lifts the car sooner near the ground. 0 = off.", "ParkedAnchoredPresentationEnabled": true, "ParkedAnchoredPresentationEnabled_Description": "On: the parked (anchored) car is posed locally at the lowered rest height with a calm sway and bob. Off: it is left exactly where the server placed it.", "ParkedExitDipStuds": 0.1, "ParkedExitDipStuds_RaisingThisDoes": "Size of the small dip when the driver gets out. Raising it makes the car bob down further on exit. 0 = none.", "SettleDamping": 0.3, "SettleDamping_RaisingThisDoes": "Damping of the sink and rise. Raising it removes the bounce (1 = none); lowering it adds more bounces.", "SettleEnabled": true, "SettleEnabled_Description": "On: the car sinks towards the ground at a standstill and rises with speed. Off: ride height stays at HoverHeightStuds.", "SettleFrequencyHz": 1.3, "SettleFrequencyHz_RaisingThisDoes": "Speed of the sink and rise. Raising it makes the car drop and bounce faster and tighter.", "SettleFullHeightMph": 22.0, "SettleFullHeightMph_RaisingThisDoes": "Speed at which the car is back at full height. Raising it makes the sink start earlier when slowing and the rise finish later.", "SettleRestScale": 0.7, "SettleRestScale_RaisingThisDoes": "Rest height as a fraction of HoverHeightStuds. Raising it makes the stopped car sit higher (1 = no lowering).", "SettleStartMph": 1.0, "SettleStartMph_RaisingThisDoes": "Speed below which the car is fully lowered. Raising it keeps the car down for longer as it pulls away.", "SettleThrottleDeadzone": 0.05, "SettleThrottleDeadzone_RaisingThisDoes": "Throttle needed before the throttle rise starts. Raising it ignores light trigger presses.", "SettleThrottleLift": 0.6, "SettleThrottleLift_RaisingThisDoes": "How far the car rises the moment the throttle is pressed, as a fraction of the full rise. 0 = rise from speed only."}, "class": "Folder", "name": "HoverPose", "parent": ["ReplicatedStorage", "Config", "Vehicles"]}, {"attributes": {"ParkedWobbleEnabled": true, "ParkedWobbleEnabled_Description": "On: the parked car keeps a calm sway and bob after the driver gets out. Off: parked cars hold still.", "ParkedWobbleScale": 0.7, "ParkedWobbleScale_RaisingThisDoes": "Size of the parked sway compared with idling in the seat. Raising it makes the parked car move more.", "ParkedWobbleSpeedScale": 0.85, "ParkedWobbleSpeedScale_RaisingThisDoes": "Speed of the parked sway compared with idling in the seat. Raising it makes the parked car move quicker.", "WobbleAmountDegrees": 1.5, "WobbleAmountDegrees_RaisingThisDoes": "Size of the idle pitch and roll sway. Raising it makes the car rock further.", "WobbleAtSpeedAmount": 0.15, "WobbleAtSpeedAmount_RaisingThisDoes": "Share of the sway kept at speed. Raising it keeps more movement while driving fast. 0 = fades out completely as before.", "WobbleAtSpeedSpeedBoost": 1.0, "WobbleAtSpeedSpeedBoost_RaisingThisDoes": "How much faster the wobble runs at speed. Raising it makes the at-speed trace quicker and finer.", "WobbleBobStuds": 0.06, "WobbleBobStuds_RaisingThisDoes": "Up and down float at idle. Raising it makes the car bob further. 0 = none.", "WobbleDetailAmount": 0.6, "WobbleDetailAmount_RaisingThisDoes": "Strength of a second, faster layer so the sway never looks repeated. 0 = the old single layer.", "WobbleEnabled": true, "WobbleEnabled_Description": "On: idle sway, bob and yaw drift. Off: the car holds still (driving and parked).", "WobbleFadeOutMph": 20.0, "WobbleFadeOutMph_RaisingThisDoes": "Speed at which the idle sway has faded to its at-speed trace. Raising it keeps the sway for longer as you pull away.", "WobblePitchMultiplier": 0.75, "WobblePitchMultiplier_RaisingThisDoes": "Nose up and down share of the sway. Raising it makes the car nod more.", "WobbleRandomiseAmount": 0.65, "WobbleRandomiseAmount_RaisingThisDoes": "Strength of the regular flutter layered on the slow drift. Raising it adds more quick movement.", "WobbleRestBoost": 0.3, "WobbleRestBoost_RaisingThisDoes": "Extra sway when fully stopped. Raising it makes a standing car look more alive. 0 = none.", "WobbleRestMph": 4.0, "WobbleRestMph_RaisingThisDoes": "Speed below which the standstill boost applies. Raising it keeps the boost while creeping.", "WobbleRollMultiplier": 1.0, "WobbleRollMultiplier_RaisingThisDoes": "Side to side share of the sway. Raising it makes the car rock more.", "WobbleSmoothing": 4.5, "WobbleSmoothing_RaisingThisDoes": "How closely the car follows the wobble pattern. Raising it makes the motion crisper; lowering it makes it lazier.", "WobbleSpeed": 1.15, "WobbleSpeed_RaisingThisDoes": "Speed of all wobble motion. Raising it makes the sway and bob quicker.", "WobbleYawDegrees": 0.35, "WobbleYawDegrees_RaisingThisDoes": "Slow nose left and right drift at idle (never at speed). Raising it makes the car wander more. 0 = none."}, "class": "Folder", "name": "HoverWobble", "parent": ["ReplicatedStorage", "Config", "Vehicles"]}], "placeId": 93959280828322, "scripts": {"DesktopFreeRoamHudUI": {"after": 2806148095, "before": 4005173224, "file": {"after": "after/DesktopFreeRoamHudUI.lua", "before": "before/DesktopFreeRoamHudUI.lua"}, "path": ["ReplicatedStorage", "Modules", "Game", "UI", "DesktopFreeRoamHudUI"], "prior": []}, "DrivingClient": {"after": 2591581746, "before": 3064704953, "file": {"after": "after/DrivingClient.lua", "before": "before/DrivingClient.lua"}, "path": ["ReplicatedStorage", "Modules", "Game", "Vehicles", "DrivingClient"], "prior": [4102932458]}, "FreeRoamParkedHoverClient": {"after": 2373235167, "before": 1580070304, "file": {"after": "after/FreeRoamParkedHoverClient.lua", "before": "before/FreeRoamParkedHoverClient.lua"}, "path": ["ReplicatedStorage", "Modules", "Game", "Vehicles", "FreeRoamParkedHoverClient"], "prior": [4085380363, 1079788412]}, "VehicleDynamics": {"after": 1003619947, "before": 877853823, "file": {"after": "after/VehicleDynamics.lua", "before": "before/VehicleDynamics.lua"}, "path": ["ReplicatedStorage", "Modules", "Game", "Vehicles", "VehicleDynamics"], "prior": []}}}]==])
-- Guarded installer body for the driving_tune delivery. build.py prepends MODE and DATA.
-- AUDIT writes nothing. APPLY writes the after-sources, the config attributes and the new config folders;
-- ROLLBACK restores the before-sources and the earlier attribute values and removes the instances it created.
-- Nothing is written unless every target resolves, every script is in a known state and every source compiles.
-- A script counts as known when its source is the before, the after, or an earlier after of this delivery
-- (DATA.scripts[name].prior), so a rebuilt delivery can be applied over its own previous build.
-- Sources are read from the repository over http://127.0.0.1:8796 (py -3 scripts/driving_tune/serve.py).
local Http = game:GetService("HttpService")
assert(game.PlaceId == DATA.placeId, DATA.base .. ": wrong place " .. tostring(game.PlaceId))
assert(not game:GetService("RunService"):IsRunning(), DATA.base .. ": stop Play first")
local BASE = "http://127.0.0.1:8796/" .. DATA.base
local function djb2(s)
	local x = 5381
	for i = 1, #s do x = (x * 33 + string.byte(s, i)) % 4294967296 end
	return x
end
local function find(path)
	local node = game:GetService(path[1])
	for i = 2, #path do node = node and node:FindFirstChild(path[i]) end
	return node
end
local report, blockers = {}, 0
local function block(text)
	blockers += 1
	table.insert(report, "BLOCKER " .. text)
end

-- Scripts
local plan = {}
local want = MODE == "ROLLBACK" and "before" or "after"
for name, info in pairs(DATA.scripts) do
	local script = find(info.path)
	local now = script and djb2(script.Source)
	local state = "unknown"
	if not script then
		state = "missing"
	elseif now == info.after then
		state = "after"
	elseif now == info.before then
		state = "before"
	else
		for _, hash in ipairs(info.prior or {}) do
			if now == hash then state = "prior" end
		end
	end
	table.insert(report, name .. ": " .. state)
	if state == "missing" or state == "unknown" then
		block(name .. " is " .. state)
	elseif MODE ~= "AUDIT" and state ~= want then
		local text = Http:GetAsync(BASE .. info.file[want] .. "?t=" .. os.clock(), true)
		if djb2(text) ~= info[want] then
			block(name .. ": the served " .. want .. " source does not match its hash")
		else
			local ok, err = loadstring(text, name)
			if not ok then
				block(name .. ": does not compile: " .. tostring(err))
			else
				plan[name] = { script = script, text = text }
			end
		end
	end
end

-- Attributes: {path, key, value, before} where before is the value recorded at capture (absent = nil).
for _, row in ipairs(DATA.attributes) do
	local node = find(row.path)
	if not node then
		block(table.concat(row.path, ".") .. " missing for attribute " .. row.key)
	else
		local now = node:GetAttribute(row.key)
		if row.before == nil then
			-- A new attribute: any value already there is this delivery's, possibly tuned since. APPLY keeps it.
			if now ~= nil and now ~= row.value then table.insert(report, row.key .. ": tuned (" .. tostring(now) .. ")") end
		elseif now ~= row.value and now ~= row.before then
			block(table.concat(row.path, ".") .. " @" .. row.key .. " is " .. tostring(now) .. ", expected " .. tostring(row.before) .. " or " .. tostring(row.value))
		end
	end
end

-- Instances: created under an existing parent; a same-named child of the same class counts as installed.
for _, spec in ipairs(DATA.instances) do
	local parent = find(spec.parent)
	if not parent then
		block(table.concat(spec.parent, ".") .. " missing for new " .. spec.name)
	else
		local existing = parent:FindFirstChild(spec.name)
		if existing and existing.ClassName ~= spec.class then
			block(spec.name .. " exists as " .. existing.ClassName)
		end
		table.insert(report, spec.name .. ": " .. (existing and "present" or "absent"))
	end
end

if blockers > 0 or MODE == "AUDIT" then
	return table.concat(report, "; ") .. " | blockers=" .. blockers .. " mode=" .. MODE .. " (nothing written)"
end

local History = game:GetService("ChangeHistoryService")
History:SetWaypoint("driving_tune " .. MODE .. " before")
local function build(spec, parent)
	local node = Instance.new(spec.class)
	node.Name = spec.name
	for key, value in pairs(spec.attributes or {}) do node:SetAttribute(key, value) end
	if spec.value ~= nil then node.Value = spec.value end
	for _, child in ipairs(spec.children or {}) do build(child, node) end
	node:SetAttribute("DrivingTuneInstalled", true)
	node.Parent = parent
	return node
end
local wrote, attributes, instances = 0, 0, 0
local restore = {}
local ok, err = pcall(function()
	for _, item in pairs(plan) do
		table.insert(restore, { script = item.script, text = item.script.Source })
		item.script.Source = item.text
		wrote += 1
	end
end)
if not ok then
	for _, item in ipairs(restore) do pcall(function() item.script.Source = item.text end) end
	return "FAILED writing sources, restored " .. #restore .. ": " .. tostring(err)
end
for _, row in ipairs(DATA.attributes) do
	local node = find(row.path)
	local value = row.before
	if MODE == "APPLY" then value = row.value end
	local current = node:GetAttribute(row.key)
	local superseded = false
	for _, old in ipairs(row.was or {}) do
		if current == old then superseded = true end
	end
	if MODE == "APPLY" and row.before == nil and current ~= nil and not superseded then
		-- keep a tuned value; an earlier default of this delivery (row.was) is replaced
	elseif node:GetAttribute(row.key) ~= value then
		node:SetAttribute(row.key, value)
		attributes += 1
	end
end
for _, spec in ipairs(DATA.instances) do
	local parent = find(spec.parent)
	local existing = parent:FindFirstChild(spec.name)
	if MODE == "APPLY" and not existing then
		build(spec, parent)
		instances += 1
	elseif MODE == "APPLY" and existing:GetAttribute("DrivingTuneInstalled") == true then
		-- A later build of this delivery: add attributes the folder does not have yet, keep tuned values.
		for key, value in pairs(spec.attributes or {}) do
			if existing:GetAttribute(key) == nil then
				existing:SetAttribute(key, value)
				attributes += 1
			end
		end
	elseif MODE == "ROLLBACK" and existing and existing:GetAttribute("DrivingTuneInstalled") == true then
		existing:Destroy()
		instances += 1
	end
end
History:SetWaypoint("driving_tune " .. MODE .. " after")
return table.concat(report, "; ") .. " | mode=" .. MODE .. " scriptsWritten=" .. wrote .. " attributesWritten=" .. attributes .. " instancesChanged=" .. instances
