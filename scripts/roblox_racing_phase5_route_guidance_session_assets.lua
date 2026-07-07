-- Neo Tokyo Racers - Racing Phase 5 Route Guidance And Session Visuals
-- Installs an isolated route-guide client for local-only checkpoint frames,
-- chevrons, authored ArrowMarkers, and a wrong-way prompt.
--
-- This does not patch the working Phase 4 race menu/results client, the
-- time-trial service, the main bootstrap, driving, VFX, garage, dealership,
-- or customisation systems.
--
-- Usage:
--   MODE = "INSTALL" installs the phase.
--   MODE = "AUDIT" checks expected objects without changing anything.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 0)
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		fail("Cannot create Folder " .. name .. " because " .. existing:GetFullName() .. " is " .. existing.ClassName)
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureScript(parent, className, name, source, disabled)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = parent
	end
	existing.Source = source
	if existing:IsA("Script") or existing:IsA("LocalScript") then
		existing.Disabled = disabled == true
	end
	return existing
end

local ROUTE_GUIDE_CLIENT_SOURCE = [==[
-- Neo Tokyo Racers - Racing Phase 5 Route Guide Client
-- NTR_RACING_PHASE5_ROUTE_GUIDE_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
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

local function makeBillboard(name, adornee, text, color)
	-- NTR_RACING_PHASE5E_WORLD_TEXT_ONLY_LABEL
	if not boolAttr("ShowWorldCheckpointLabel", true) then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = boolAttr("CheckpointWorldTextAlwaysOnTop", true)
	gui.Size = UDim2.fromOffset(190, 38)
	local yOffset = numberAttr("CheckpointWorldTextYOffset", 7)
	gui.StudsOffset = Vector3.new(0, math.max(yOffset, adornee and adornee.Size.Y * 0.5 + yOffset or yOffset), 0)
	gui.Parent = ensureRenderRoot()

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(4, 8, 12)
	label.TextStrokeTransparency = numberAttr("CheckpointWorldTextStrokeTransparency", 0.35)
	label.TextSize = numberAttr("CheckpointWorldTextSize", 15)
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui
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

local function drawGateFrame(gate)
	local gatePart = gate and gate.Part
	if not (gatePart and gatePart:IsA("BasePart")) then return end
	local color = colorForGate(gate)
	local label = gate.IsFinish and "FINISH" or ("CHECKPOINT " .. tostring(gate.Index or activeRun.NextGateIndex or "?"))
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

	-- NTR_RACING_PHASE5E_OPTIONAL_CORNER_TICK_FRAME
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
	if not boolAttr("ShowDynamicNextArrow", true) then return end
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
	if not boolAttr("ShowAuthoringArrows", true) then return end
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
local wrongCorner = Instance.new("UICorner")
wrongCorner.CornerRadius = UDim.new(0, 6)
wrongCorner.Parent = wrongWay
local wrongStroke = Instance.new("UIStroke")
wrongStroke.Color = wrongWay.TextColor3
wrongStroke.Thickness = 1.2
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
	activeRun.RunId = payload.RunId or activeRun.RunId
	activeRun.EventId = payload.EventId or activeRun.EventId
	activeRun.RouteId = payload.RouteId or activeRun.RouteId
	activeRun.DisplayName = payload.DisplayName or activeRun.DisplayName
	activeRun.NextGateIndex = payload.NextGateIndex or activeRun.NextGateIndex or 1
	activeRun.GateCount = payload.GateCount or activeRun.GateCount or 1
	renderGuide()
end

local function clearActive()
	activeRun = nil
	activeRoute = nil
	clearGuide()
	wrongWay.Visible = false
	wrongWaySustainedSeconds = 0
	wrongWayCheckAccumulator = 0
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local kind = payload.Type
	if kind == "TimeTrialStaged" or kind == "TimeTrialCountdown" or kind == "TimeTrialStarted" then
		setActive(payload)
	elseif kind == "TimeTrialCheckpoint" then
		setActive(payload)
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError" then
		clearActive()
	end
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
]==]

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local routeGuide = ensureFolder(racing, "RouteGuide")
	routeGuide:SetAttribute("Phase5RouteGuideReady", true)
	routeGuide:SetAttribute("EnableRouteGuide", true)
	routeGuide:SetAttribute("ShowCheckpointFrames", false)
	routeGuide:SetAttribute("ShowDynamicNextArrow", true)
	routeGuide:SetAttribute("ShowAuthoringArrows", true)
	routeGuide:SetAttribute("ShowWrongWayPrompt", true)
	routeGuide:SetAttribute("ShowCheckpointHudBadge", false)
	routeGuide:SetAttribute("ShowWorldCheckpointLabel", true)
	routeGuide:SetAttribute("CheckpointFrameStyle", "Off")
	routeGuide:SetAttribute("CheckpointFrameTransparency", 0.94)
	routeGuide:SetAttribute("CheckpointCornerTickLength", 5)
	routeGuide:SetAttribute("CheckpointCornerTickThickness", 0.16)
	routeGuide:SetAttribute("CheckpointWorldTextSize", 15)
	routeGuide:SetAttribute("CheckpointWorldTextYOffset", 7)
	routeGuide:SetAttribute("CheckpointWorldTextStrokeTransparency", 0.35)
	routeGuide:SetAttribute("CheckpointWorldTextAlwaysOnTop", true)
	routeGuide:SetAttribute("DynamicArrowBackStuds", 26)
	routeGuide:SetAttribute("DynamicArrowHeightStuds", 8)
	routeGuide:SetAttribute("DynamicArrowScale", 1.2)
	routeGuide:SetAttribute("WrongWayMinSpeed", 42)
	routeGuide:SetAttribute("WrongWayIgnoreNearGateStuds", 28)
	routeGuide:SetAttribute("WrongWayDotThreshold", -0.32)
	routeGuide:SetAttribute("WrongWayDelaySeconds", 3)
	routeGuide:SetAttribute("WrongWayCheckInterval", 0.12)
	routeGuide:SetAttribute("CheckpointColor", Color3.fromRGB(70, 255, 190))
	routeGuide:SetAttribute("FinishColor", Color3.fromRGB(255, 226, 80))
	routeGuide:SetAttribute("ArrowColor", Color3.fromRGB(255, 68, 196))
	routeGuide:SetAttribute("WarningColor", Color3.fromRGB(255, 74, 116))
end

local function ensureRouteFolders()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local routes = world and world:FindFirstChild("RaceRoutes")
	if not routes then
		return
	end
	for _, route in ipairs(routes:GetChildren()) do
		if route:IsA("Folder") then
			local arrows = ensureFolder(route, "ArrowMarkers")
			arrows:SetAttribute("AuthoringNote", "Optional route arrow hint parts. Phase 5 renders them locally for active racers only.")
			local templates = ensureFolder(route, "SessionAssetTemplates")
			templates:SetAttribute("AuthoringNote", "Future whitelisted route-only ramps, gates, boost strips, and signs. Phase 5 does not spawn collidable assets yet.")
		end
	end
end

local function install()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local remotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
	if not remotes:FindFirstChild("RaceEvent") then
		fail("Missing Shared.Remotes.Racing.RaceEvent. Run Racing Phase 3 first.")
	end
	local modules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Racing")
	if not modules:FindFirstChild("RaceRouteDefinition") then
		fail("Missing Shared.Modules.Racing.RaceRouteDefinition. Run Racing Phase 3 first.")
	end

	ensureConfig()
	ensureRouteFolders()

	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local clientRoot = ensureFolder(playerScripts, "NeoTokyoRacersClient")
	local controllers = ensureFolder(clientRoot, "Controllers")
	local racingClients = ensureFolder(controllers, "Racing")
	ensureScript(racingClients, "LocalScript", "RaceRouteGuideClient_Active", ROUTE_GUIDE_CLIENT_SOURCE, false)

	info("Installed isolated RaceRouteGuideClient_Active. Restart Play before testing.")
end

local function audit()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local racing = kit and kit:FindFirstChild("Config") and kit.Config:FindFirstChild("Racing")
	local routeGuide = racing and racing:FindFirstChild("RouteGuide")
	local remotes = kit and kit:FindFirstChild("Shared") and kit.Shared:FindFirstChild("Remotes") and kit.Shared.Remotes:FindFirstChild("Racing")
	local modules = kit and kit:FindFirstChild("Shared") and kit.Shared:FindFirstChild("Modules") and kit.Shared.Modules:FindFirstChild("Racing")
	local clientRoot = StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("Racing")
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local routes = world and world:FindFirstChild("RaceRoutes")
	info("Audit:")
	info("  RaceEvent=" .. tostring(remotes and remotes:FindFirstChild("RaceEvent") ~= nil))
	info("  RaceRouteDefinition=" .. tostring(modules and modules:FindFirstChild("RaceRouteDefinition") ~= nil))
	info("  RouteGuide config=" .. tostring(routeGuide ~= nil))
	info("  RaceRouteGuideClient_Active=" .. tostring(clientRoot and clientRoot:FindFirstChild("RaceRouteGuideClient_Active") ~= nil))
	if routes then
		for _, route in ipairs(routes:GetChildren()) do
			if route:IsA("Folder") then
				info("  Route " .. route.Name .. " ArrowMarkers=" .. tostring(route:FindFirstChild("ArrowMarkers") ~= nil) .. " SessionAssetTemplates=" .. tostring(route:FindFirstChild("SessionAssetTemplates") ~= nil))
			end
		end
	end
end

if MODE == "INSTALL" then
	install()
	audit()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
