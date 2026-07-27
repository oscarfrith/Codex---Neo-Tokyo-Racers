-- NTR_RACING_PRESENTATION_LIFECYCLE_V1_2_MOBILE_CHECKPOINT_UI
-- NTR_RACING_PRESENTATION_LIFECYCLE_V1_GUIDE
-- NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1
-- Neo Tokyo Racers - Racing Phase 5 Route Guide Client
-- NTR_RACING_PHASE5_ROUTE_GUIDE_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local Foundation = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("ResponsiveUIFoundation"))
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")
local racingModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
local RouteDefinition = require(racingModules:WaitForChild("RaceRouteDefinition"))

local PHASE = "NTR Racing Phase 5 Guide"

local activeRun = nil
local activeRoute = nil
local renderedGateIndex = nil
local renderRoot = nil
local heartbeat = nil

local function configFolder()
	local config = kit:FindFirstChild("Config")
	local racing = config and config:FindFirstChild("Racing")
	return racing and racing:FindFirstChild("RouteGuide")
end

local function boolAttr(name, fallback)
	local folder = configFolder()
	local value = folder and folder:GetAttribute(name)
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function numberAttr(name, fallback)
	local folder = configFolder()
	local value = folder and folder:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function colorAttr(name, fallback)
	local folder = configFolder()
	local value = folder and folder:GetAttribute(name)
	if typeof(value) == "Color3" then
		return value
	end
	return fallback
end

local function checkpointUiScale()
	if not Foundation.IsMobile() then return 1 end
	return math.clamp(numberAttr("MobileCheckpointUIScale",0.6),0.25,1)
end

local function clientRoot()
	local root = Workspace:FindFirstChild("_NTR_ClientOnly")
	if not root then
		root = Instance.new("Folder")
		root.Name = "_NTR_ClientOnly"
		root.Parent = Workspace
	end
	local guide = root:FindFirstChild("RaceRouteGuide")
	if not guide then
		guide = Instance.new("Folder")
		guide.Name = "RaceRouteGuide"
		guide.Parent = root
	end
	return guide
end

local function clearGuide()
	if renderRoot then
		renderRoot:Destroy()
		renderRoot = nil
	end
	renderedGateIndex = nil
end

local function ensureRenderRoot()
	if renderRoot and renderRoot.Parent then
		return renderRoot
	end
	renderRoot = Instance.new("Folder")
	renderRoot.Name = "ActiveGuide"
	renderRoot.Parent = clientRoot()
	return renderRoot
end

local function safeUnit(vector, fallback)
	if vector.Magnitude > 0.001 then
		return vector.Unit
	end
	return fallback or Vector3.new(0, 0, -1)
end

local function part(name, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0.08
	p.Size = size
	p.CFrame = cf
	p.Parent = ensureRenderRoot()
	return p
end

local checkpointHudLabel = nil

local function setCheckpointHud(_text,_color)
	-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP: presentation owned by RaceSessionPresentationController_Active.
end
local function makeBillboard(name, adornee, text, color)
	-- NTR_RACING_PHASE5F_WORLD_PILL_LABEL
	if not boolAttr("ShowWorldCheckpointLabel", true) then
		return nil
	end
	local uiScale = checkpointUiScale()
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = boolAttr("CheckpointWorldTextAlwaysOnTop", true)
	gui.Size = UDim2.fromOffset(numberAttr("CheckpointPillWidth", 168) * uiScale, numberAttr("CheckpointPillHeight", 28) * uiScale)
	local yOffset = numberAttr("CheckpointPillYOffset", 7)
	gui.StudsOffset = Vector3.new(0, math.max(yOffset, adornee and adornee.Size.Y * 0.5 + yOffset or yOffset), 0)
	gui.Parent = ensureRenderRoot()

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = numberAttr("CheckpointPillBackgroundTransparency", 0.8)
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(4, 8, 12)
	label.TextStrokeTransparency = numberAttr("CheckpointWorldTextStrokeTransparency", 0.35)
	label.TextSize = math.max(8, numberAttr("CheckpointWorldTextSize", 15) * uiScale)
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui

	Foundation.Corner(label,numberAttr("CheckpointPillCornerRadius",8) * uiScale)

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = numberAttr("CheckpointPillStrokeThickness", 1) * uiScale
	stroke.Transparency = numberAttr("CheckpointPillStrokeTransparency", 0.7)
	stroke.Parent = label
	return gui
end


local function colorForGate(gate)
	if gate and gate.IsFinish then
		return colorAttr("FinishColor", Color3.fromRGB(255, 226, 80))
	end
	return colorAttr("CheckpointColor", Color3.fromRGB(70, 255, 190))
end

local function colorForArrow(marker)
	local role = tostring(marker and marker.ColorRole or "Accent")
	if role == "Warning" then
		return colorAttr("WarningColor", Color3.fromRGB(255, 74, 116))
	elseif role == "Checkpoint" then
		return colorAttr("CheckpointColor", Color3.fromRGB(70, 255, 190))
	end
	return colorAttr("ArrowColor", Color3.fromRGB(255, 68, 196))
end

local function finishGateText(run)
	local lapTarget = math.max(0, math.floor(tonumber(run and run.LapTarget) or 1))
	local currentLap = math.max(1, math.floor(tonumber(run and run.CurrentLap) or 1))
	if lapTarget == 1 then return "FINISH LINE" end
	if lapTarget > 1 and currentLap >= lapTarget then return "FINAL LAP" end
	return "LAP " .. tostring(currentLap)
end

local function drawGateFrame(gate)
	local gatePart = gate and gate.Part
	if not (gatePart and gatePart:IsA("BasePart")) then return end
	local color = colorForGate(gate)
	local label = gate.IsFinish and finishGateText(activeRun) or ("CHECKPOINT " .. tostring(gate.Index or activeRun.NextGateIndex or "?"))
	makeBillboard("NextGateLabel", gatePart, label, color)
	if not boolAttr("ShowCheckpointFrames", false) then return end

	local style = tostring((configFolder() and configFolder():GetAttribute("CheckpointFrameStyle")) or "Off")
	if style == "Off" or style == "None" then
		return
	end

	local frameTransparency = numberAttr("CheckpointFrameTransparency", 0.94)
	local thickness = math.max(0.08, numberAttr("CheckpointCornerTickThickness", 0.16))
	local tickLength = math.max(1.5, numberAttr("CheckpointCornerTickLength", 5))
	local lift = math.max(4.5, gatePart.Size.Y * 0.5 + 1.2)
	local x = math.max(7, gatePart.Size.X + 5)
	local z = math.max(7, gatePart.Size.Z + 5)
	local cf = gatePart.CFrame * CFrame.new(0, lift, 0)

	-- NTR_RACING_PHASE5F_OPTIONAL_CORNER_TICK_FRAME
	part("NextGateCorner_FL_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(-x * 0.5 + tickLength * 0.5, 0, -z * 0.5), color, frameTransparency)
	part("NextGateCorner_FR_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(x * 0.5 - tickLength * 0.5, 0, -z * 0.5), color, frameTransparency)
	part("NextGateCorner_BL_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(-x * 0.5 + tickLength * 0.5, 0, z * 0.5), color, frameTransparency)
	part("NextGateCorner_BR_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(x * 0.5 - tickLength * 0.5, 0, z * 0.5), color, frameTransparency)
	part("NextGateCorner_FL_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(-x * 0.5, 0, -z * 0.5 + tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_FR_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(x * 0.5, 0, -z * 0.5 + tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_BL_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(-x * 0.5, 0, z * 0.5 - tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_BR_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(x * 0.5, 0, z * 0.5 - tickLength * 0.5), color, frameTransparency)
end


local function chevronAt(cf, scale, color, prefix)
	scale = scale or 1
	local length = 8 * scale
	local thickness = math.max(0.35, 0.45 * scale)
	local spread = 2.2 * scale
	local forward = 1.2 * scale
	part(prefix .. "_Left", Vector3.new(thickness, thickness, length), cf * CFrame.new(-spread, 0, forward) * CFrame.Angles(0, math.rad(-35), 0), color, 0.02)
	part(prefix .. "_Right", Vector3.new(thickness, thickness, length), cf * CFrame.new(spread, 0, forward) * CFrame.Angles(0, math.rad(35), 0), color, 0.02)
	part(prefix .. "_Stem", Vector3.new(thickness, thickness, length * 0.85), cf * CFrame.new(0, 0, -length * 0.25), color, 0.08)
end

local function drawDynamicArrow(route, gateIndex)
	if not boolAttr("ShowCheckpointArrows", false) or not boolAttr("ShowDynamicNextArrow", true) then return end
	local gate = RouteDefinition.GetGate(route, gateIndex)
	if not (gate and gate.Part) then return end
	local previous = RouteDefinition.GetGate(route, math.max(1, gateIndex - 1))
	local gatePos = gate.Part.Position
	local fromPos = previous and previous.Part and previous.Part.Position or (gatePos - gate.Part.CFrame.LookVector * 40)
	local dir = safeUnit(gatePos - fromPos, gate.Part.CFrame.LookVector)
	local distance = numberAttr("DynamicArrowBackStuds", 26)
	local height = numberAttr("DynamicArrowHeightStuds", 8)
	local pos = gatePos - dir * distance + Vector3.new(0, height, 0)
	local cf = CFrame.lookAt(pos, gatePos + Vector3.new(0, height * 0.25, 0))
	chevronAt(cf, numberAttr("DynamicArrowScale", 1.2), colorForGate(gate), "DynamicArrow")
end

local function drawAuthoredArrows(route, gateIndex)
	if not boolAttr("ShowCheckpointArrows", false) or not boolAttr("ShowAuthoringArrows", true) then return end
	for _, marker in ipairs(route and route.ArrowMarkers or {}) do
		local mode = tostring(marker.DisplayMode or "WhenNext")
		local target = tonumber(marker.TargetCheckpointIndex) or tonumber(marker.ArrowIndex) or gateIndex
		local shouldShow = mode == "Always" or (mode == "WhenNext" and target == gateIndex) or (mode == "WrongWayAssist" and target == gateIndex)
		if shouldShow and marker.Part then
			local color = colorForArrow(marker)
			local scale = tonumber(marker.Scale) or 1
			chevronAt(marker.Part.CFrame, scale, color, "AuthoredArrow_" .. tostring(marker.ArrowIndex or target))
		end
	end
end

local guideGui = Instance.new("ScreenGui")
guideGui.Name = "NTR_RaceRouteGuide_Phase5"
guideGui.IgnoreGuiInset = true
guideGui.ResetOnSpawn = false
guideGui.DisplayOrder = 78
guideGui.Parent = playerGui

local wrongWay = Instance.new("TextLabel")
wrongWay.Name = "WrongWayPrompt"
wrongWay.AnchorPoint = Vector2.new(0.5, 0)
wrongWay.Position = UDim2.new(0.5, 0, 0, 178)
wrongWay.Size = UDim2.fromOffset(280, 38)
wrongWay.BackgroundColor3 = Color3.fromRGB(24, 8, 15)
wrongWay.BackgroundTransparency = 0.12
wrongWay.BorderSizePixel = 0
wrongWay.Text = "WRONG WAY"
wrongWay.TextColor3 = colorAttr("WarningColor", Color3.fromRGB(255, 74, 116))
wrongWay.TextSize = 18
wrongWay.Visible = false
wrongWay.Font = Enum.Font.GothamBold
pcall(function()
	wrongWay.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
end)
wrongWay.Parent = guideGui
Foundation.Corner(wrongWay,6)
local wrongStroke = Instance.new("UIStroke")
wrongStroke.Color = wrongWay.TextColor3
wrongStroke.Thickness = Foundation.StrokeWidth("Emphasis")
wrongStroke.Transparency = 0.18
wrongStroke.Parent = wrongWay

local function findLocalVehicleRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	for _, vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
		if tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
			local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
			if root and root:IsA("BasePart") then
				return root
			end
		end
	end
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local wrongWaySustainedSeconds = 0
local wrongWayCheckAccumulator = 0

local function resetWrongWay()
	wrongWaySustainedSeconds = 0
	wrongWay.Visible = false
end

local function isCurrentlyWrongWay()
	if not (activeRun and activeRoute and boolAttr("ShowWrongWayPrompt", true)) then
		return false
	end
	local root = findLocalVehicleRoot()
	local gate = RouteDefinition.GetGate(activeRoute, activeRun.NextGateIndex or 1)
	if not (root and gate and gate.Part) then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed < numberAttr("WrongWayMinSpeed", 42) then
		return false
	end
	local toGate = gate.Part.Position - root.Position
	if toGate.Magnitude < numberAttr("WrongWayIgnoreNearGateStuds", 28) then
		return false
	end
	local dot = safeUnit(velocity, root.CFrame.LookVector):Dot(safeUnit(toGate, root.CFrame.LookVector))
	return dot < numberAttr("WrongWayDotThreshold", -0.32)
end

local function updateWrongWay(dt)
	-- NTR_RACING_PHASE5D_WRONG_WAY_DELAY
	local interval = math.max(0.05, numberAttr("WrongWayCheckInterval", 0.12))
	wrongWayCheckAccumulator += dt or 0
	if wrongWayCheckAccumulator < interval then
		return
	end
	local elapsed = wrongWayCheckAccumulator
	wrongWayCheckAccumulator = 0
	if isCurrentlyWrongWay() then
		wrongWaySustainedSeconds += elapsed
		wrongWay.Visible = wrongWaySustainedSeconds >= numberAttr("WrongWayDelaySeconds", 3)
	else
		resetWrongWay()
	end
end


local function renderGuide()
	if not (activeRun and boolAttr("EnableRouteGuide", true)) then
		clearGuide()
		wrongWay.Visible = false
		return
	end
	local route, routeError = RouteDefinition.GetRouteDefinition(activeRun.RouteId)
	if not route then
		warn("[" .. PHASE .. "] " .. tostring(routeError))
		clearGuide()
		return
	end
	activeRoute = route
	local gateIndex = activeRun.NextGateIndex or 1
	if renderedGateIndex == gateIndex then
		return
	end
	clearGuide()
	renderedGateIndex = gateIndex
	drawGateFrame(route and RouteDefinition.GetGate(route, gateIndex))
	drawDynamicArrow(route, gateIndex)
	drawAuthoredArrows(route, gateIndex)
end

local function setActive(payload)
	activeRun = activeRun or {}
	local previousLap = activeRun.CurrentLap
	local previousTarget = activeRun.LapTarget
	activeRun.RunId = payload.RunId or activeRun.RunId
	activeRun.EventId = payload.EventId or activeRun.EventId
	activeRun.RouteId = payload.RouteId or activeRun.RouteId
	activeRun.DisplayName = payload.DisplayName or activeRun.DisplayName
	activeRun.NextGateIndex = payload.NextGateIndex or activeRun.NextGateIndex or 1
	activeRun.GateCount = payload.GateCount or activeRun.GateCount or 1
	activeRun.CurrentLap = payload.NextLap or payload.CurrentLap or activeRun.CurrentLap or 1
	activeRun.LapTarget = payload.LapTarget ~= nil and payload.LapTarget or activeRun.LapTarget or 1
	if activeRun.CurrentLap ~= previousLap or activeRun.LapTarget ~= previousTarget then
		renderedGateIndex = nil
	end
	renderGuide()
end

local function clearActive()
	activeRun = nil
	activeRoute = nil
	clearGuide()
	wrongWay.Visible = false
	wrongWaySustainedSeconds = 0
	wrongWayCheckAccumulator = 0
	setCheckpointHud(nil, colorAttr("CheckpointColor", Color3.fromRGB(70, 255, 190)))
end


raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "RaceStaged" or kind == "RaceCountdown" then
		clearActive() -- NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2: hide checkpoint guidance until GO.
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" or kind == "RaceCheckpoint" or kind == "TimeTrialLapCompleted" or kind == "RaceLapCompleted" then
		setActive(payload)
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceFinished" or kind == "RaceEnded" then
		clearActive()
	end
	-- NTR_RACING_PHASE8_ROUTE_GUIDE_RACE_EVENTS
end)

heartbeat = RunService.Heartbeat:Connect(function(dt)
	updateWrongWay(dt)
end)

script.Destroying:Connect(function()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	clearActive()
end)

print("[NTR Racing Phase 5 Guide] Route guide client active.")
