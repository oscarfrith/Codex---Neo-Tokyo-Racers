-- Neo Tokyo Racers - Racing Phase 5D Minimal Route Guide + Wrong-Way Delay
-- Reworks the route guide so it no longer blocks the driving view:
--   * checkpoint text moves to a small top HUD badge by default;
--   * large world checkpoint labels are disabled by default;
--   * the old full frame is replaced with faint corner ticks;
--   * WRONG WAY appears only after sustained wrong-way driving.
--
-- This patches only the isolated Racing route guide client.
--
-- Usage:
--   MODE = "INSTALL" applies the repair.
--   MODE = "AUDIT" checks whether the repair is present.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5D"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

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

local function racingClientFolder()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local controllers = clientRoot:WaitForChild("Controllers")
	return controllers:WaitForChild("Racing")
end

local function routeGuideClient()
	local folder = racingClientFolder()
	local object = folder:FindFirstChild("RaceRouteGuideClient_Active")
	if not (object and object:IsA("LuaSourceContainer")) then
		fail("Missing RaceRouteGuideClient_Active. Run Racing Phase 5 first, or refresh the Studio mirror before repairing.")
	end
	return object
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local routeGuide = ensureFolder(racing, "RouteGuide")
	routeGuide:SetAttribute("ShowCheckpointHudBadge", true)
	routeGuide:SetAttribute("ShowWorldCheckpointLabel", false)
	routeGuide:SetAttribute("ShowCheckpointFrames", true)
	routeGuide:SetAttribute("CheckpointFrameStyle", "CornerTicks")
	routeGuide:SetAttribute("CheckpointFrameTransparency", 0.94)
	routeGuide:SetAttribute("CheckpointCornerTickLength", 5)
	routeGuide:SetAttribute("CheckpointCornerTickThickness", 0.16)
	routeGuide:SetAttribute("CheckpointHudBackgroundTransparency", 0.38)
	routeGuide:SetAttribute("CheckpointHudTextTransparency", 0)
	routeGuide:SetAttribute("WrongWayDelaySeconds", 3)
	routeGuide:SetAttribute("WrongWayCheckInterval", 0.12)
	return routeGuide
end

local function findRouteGuideConfig()
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local config = kit and kit:FindFirstChild("Config")
	local racing = config and config:FindFirstChild("Racing")
	return racing and racing:FindFirstChild("RouteGuide")
end

local function replacePlain(source, oldText, newText, label)
	local startIndex, endIndex = source:find(oldText, 1, true)
	if not startIndex then
		fail("Could not find " .. label .. ". Refresh the mirror/source before trying another repair.")
	end
	return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1)
end

local function replaceFunctionWindow(source, startAnchor, nextAnchor, newText, label)
	local startIndex = source:find(startAnchor, 1, true)
	if not startIndex then
		fail("Could not find start of " .. label .. ". Refresh the mirror/source before trying another repair.")
	end
	local nextIndex = source:find(nextAnchor, startIndex + #startAnchor, true)
	if not nextIndex and nextAnchor:find("\n", 1, true) then
		local crlfAnchor = nextAnchor:gsub("\n", "\r\n")
		nextIndex = source:find(crlfAnchor, startIndex + #startAnchor, true)
	end
	if not nextIndex then
		fail("Could not find end anchor for " .. label .. ". Refresh the mirror/source before trying another repair.")
	end
	return source:sub(1, startIndex - 1) .. newText .. source:sub(nextIndex)
end

local OLD_MAKE_BILLBOARD = [==[
local function makeBillboard(name, adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(190, 48)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.Parent = ensureRenderRoot()

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	label.BackgroundTransparency = numberAttr("CheckpointLabelBackgroundTransparency", 0.2) -- NTR_RACING_PHASE5C_LABEL_TRANSPARENCY
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = numberAttr("CheckpointLabelTextTransparency", 0.2) -- NTR_RACING_PHASE5C_TEXT_TRANSPARENCY
	label.TextSize = 15
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.2
	stroke.Transparency = 0.25
	stroke.Parent = label
	return gui
end
]==]

local OLD_MAKE_BILLBOARD_PHASE5 = [==[
local function makeBillboard(name, adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(190, 48)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.Parent = ensureRenderRoot()

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 15
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.2
	stroke.Transparency = 0.25
	stroke.Parent = label
	return gui
end
]==]

local NEW_MINIMAL_LABEL = [==[
local checkpointHudLabel = nil

local function ensureCheckpointHud()
	if checkpointHudLabel and checkpointHudLabel.Parent then
		return checkpointHudLabel
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "NTR_RaceCheckpointBadge_Phase5D"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 77
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "CheckpointBadge"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 96)
	label.Size = UDim2.fromOffset(210, 28)
	label.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	label.BackgroundTransparency = numberAttr("CheckpointHudBackgroundTransparency", 0.38)
	label.BorderSizePixel = 0
	label.TextColor3 = colorAttr("CheckpointColor", Color3.fromRGB(70, 255, 190))
	label.TextTransparency = numberAttr("CheckpointHudTextTransparency", 0)
	label.TextSize = 13
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = label.TextColor3
	stroke.Thickness = 0.8
	stroke.Transparency = 0.45
	stroke.Parent = label
	checkpointHudLabel = label
	return label
end

local function setCheckpointHud(text, color)
	if not boolAttr("ShowCheckpointHudBadge", true) then
		if checkpointHudLabel then checkpointHudLabel.Visible = false end
		return
	end
	local label = ensureCheckpointHud()
	label.Text = tostring(text or "")
	label.TextColor3 = color
	label.TextTransparency = numberAttr("CheckpointHudTextTransparency", 0)
	label.BackgroundTransparency = numberAttr("CheckpointHudBackgroundTransparency", 0.38)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	label.Visible = text ~= nil and text ~= ""
end

local function makeBillboard(name, adornee, text, color)
	-- NTR_RACING_PHASE5D_MINIMAL_CHECKPOINT_LABEL
	setCheckpointHud(text, color)
	if not boolAttr("ShowWorldCheckpointLabel", false) then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = false
	gui.Size = UDim2.fromOffset(132, 28)
	gui.StudsOffset = Vector3.new(0, math.max(10, adornee and adornee.Size.Y * 0.5 + 8 or 10), 0)
	gui.Parent = ensureRenderRoot()

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	label.BackgroundTransparency = 0.65
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0.1
	label.TextSize = 11
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label
	return gui
end
]==]

local OLD_DRAW_GATE_FRAME = [==[
local function drawGateFrame(gate)
	if not boolAttr("ShowCheckpointFrames", true) then return end
	local gatePart = gate and gate.Part
	if not (gatePart and gatePart:IsA("BasePart")) then return end
	local color = colorForGate(gate)
	local lift = math.max(4, gatePart.Size.Y * 0.5 + 0.75)
	local cf = gatePart.CFrame * CFrame.new(0, lift, 0)
	local x = math.max(8, gatePart.Size.X + 6)
	local z = math.max(8, gatePart.Size.Z + 6)
	local frameTransparency = numberAttr("CheckpointFrameTransparency", 0.8)
	-- NTR_RACING_PHASE5B_FRAME_TRANSPARENCY
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, frameTransparency)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, frameTransparency)
	local label = gate.IsFinish and "FINISH" or ("CHECKPOINT " .. tostring(gate.Index or activeRun.NextGateIndex or "?"))
	makeBillboard("NextGateLabel", gatePart, label, color)
end
]==]

local OLD_DRAW_GATE_FRAME_PHASE5 = [==[
local function drawGateFrame(gate)
	if not boolAttr("ShowCheckpointFrames", true) then return end
	local gatePart = gate and gate.Part
	if not (gatePart and gatePart:IsA("BasePart")) then return end
	local color = colorForGate(gate)
	local lift = math.max(4, gatePart.Size.Y * 0.5 + 0.75)
	local cf = gatePart.CFrame * CFrame.new(0, lift, 0)
	local x = math.max(8, gatePart.Size.X + 6)
	local z = math.max(8, gatePart.Size.Z + 6)
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, 0.04)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, 0.04)
	local label = gate.IsFinish and "FINISH" or ("CHECKPOINT " .. tostring(gate.Index or activeRun.NextGateIndex or "?"))
	makeBillboard("NextGateLabel", gatePart, label, color)
end
]==]

local NEW_DRAW_GATE_FRAME = [==[
local function drawGateFrame(gate)
	local gatePart = gate and gate.Part
	if not (gatePart and gatePart:IsA("BasePart")) then return end
	local color = colorForGate(gate)
	local label = gate.IsFinish and "FINISH" or ("CHECKPOINT " .. tostring(gate.Index or activeRun.NextGateIndex or "?"))
	makeBillboard("NextGateLabel", gatePart, label, color)
	if not boolAttr("ShowCheckpointFrames", true) then return end

	local style = tostring((configFolder() and configFolder():GetAttribute("CheckpointFrameStyle")) or "CornerTicks")
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

	-- NTR_RACING_PHASE5D_CORNER_TICK_FRAME
	part("NextGateCorner_FL_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(-x * 0.5 + tickLength * 0.5, 0, -z * 0.5), color, frameTransparency)
	part("NextGateCorner_FR_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(x * 0.5 - tickLength * 0.5, 0, -z * 0.5), color, frameTransparency)
	part("NextGateCorner_BL_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(-x * 0.5 + tickLength * 0.5, 0, z * 0.5), color, frameTransparency)
	part("NextGateCorner_BR_X", Vector3.new(tickLength, thickness, thickness), cf * CFrame.new(x * 0.5 - tickLength * 0.5, 0, z * 0.5), color, frameTransparency)
	part("NextGateCorner_FL_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(-x * 0.5, 0, -z * 0.5 + tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_FR_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(x * 0.5, 0, -z * 0.5 + tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_BL_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(-x * 0.5, 0, z * 0.5 - tickLength * 0.5), color, frameTransparency)
	part("NextGateCorner_BR_Z", Vector3.new(thickness, thickness, tickLength), cf * CFrame.new(x * 0.5, 0, z * 0.5 - tickLength * 0.5), color, frameTransparency)
end
]==]

local OLD_CLEAR_ACTIVE = [==[
local function clearActive()
	activeRun = nil
	activeRoute = nil
	clearGuide()
	wrongWay.Visible = false
end
]==]

local NEW_CLEAR_ACTIVE = [==[
local function clearActive()
	activeRun = nil
	activeRoute = nil
	clearGuide()
	wrongWay.Visible = false
	wrongWaySustainedSeconds = 0
	wrongWayCheckAccumulator = 0
	setCheckpointHud(nil, colorAttr("CheckpointColor", Color3.fromRGB(70, 255, 190)))
end
]==]

local OLD_UPDATE_WRONG_WAY = [==[
local function updateWrongWay()
	if not (activeRun and activeRoute and boolAttr("ShowWrongWayPrompt", true)) then
		wrongWay.Visible = false
		return
	end
	local root = findLocalVehicleRoot()
	local gate = RouteDefinition.GetGate(activeRoute, activeRun.NextGateIndex or 1)
	if not (root and gate and gate.Part) then
		wrongWay.Visible = false
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed < numberAttr("WrongWayMinSpeed", 42) then
		wrongWay.Visible = false
		return
	end
	local toGate = gate.Part.Position - root.Position
	if toGate.Magnitude < numberAttr("WrongWayIgnoreNearGateStuds", 28) then
		wrongWay.Visible = false
		return
	end
	local dot = safeUnit(velocity, root.CFrame.LookVector):Dot(safeUnit(toGate, root.CFrame.LookVector))
	wrongWay.Visible = dot < numberAttr("WrongWayDotThreshold", -0.32)
end
]==]

local NEW_UPDATE_WRONG_WAY = [==[
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
]==]

local OLD_HEARTBEAT = [==[
heartbeat = RunService.Heartbeat:Connect(function()
	updateWrongWay()
end)
]==]

local NEW_HEARTBEAT = [==[
heartbeat = RunService.Heartbeat:Connect(function(dt)
	updateWrongWay(dt)
end)
]==]

local function patchRouteGuide()
	local guide = routeGuideClient()
	local source = guide.Source
	local changed = false

	if source:find("NTR_RACING_PHASE5D_MINIMAL_CHECKPOINT_LABEL", 1, true) then
		info("Minimal checkpoint label patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function makeBillboard", "\n\nlocal function colorForGate", NEW_MINIMAL_LABEL, "makeBillboard function")
		changed = true
	end

	if source:find("NTR_RACING_PHASE5D_CORNER_TICK_FRAME", 1, true) then
		info("Corner tick frame patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function drawGateFrame", "\n\nlocal function chevronAt", NEW_DRAW_GATE_FRAME, "drawGateFrame function")
		changed = true
	end

	if source:find("NTR_RACING_PHASE5D_WRONG_WAY_DELAY", 1, true) then
		info("Wrong-way delay patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function updateWrongWay", "\n\nlocal function renderGuide", NEW_UPDATE_WRONG_WAY, "updateWrongWay function")
		if source:find(OLD_HEARTBEAT, 1, true) then
			source = replacePlain(source, OLD_HEARTBEAT, NEW_HEARTBEAT, "route guide heartbeat block")
		else
			source = source:gsub("RunService%.Heartbeat:Connect%(%s*function%(%s*%)", "RunService.Heartbeat:Connect(function(dt)", 1)
			source = source:gsub("updateWrongWay%(%s*%)", "updateWrongWay(dt)", 1)
		end
		changed = true
	end

	if source:find("wrongWaySustainedSeconds = 0", 1, true) and not source:find("setCheckpointHud(nil", 1, true) then
		source = replaceFunctionWindow(source, "local function clearActive", "\n\nraceEvent.OnClientEvent", NEW_CLEAR_ACTIVE, "clearActive function")
		changed = true
	end

	if changed then
		guide.Source = source
		info("Patched RaceRouteGuideClient_Active with minimal guide visuals and wrong-way delay.")
	end
	return changed
end

local function audit()
	local routeGuide = findRouteGuideConfig()
	local guide = routeGuideClient()
	local source = guide.Source
	info("Audit:")
	info("  ShowCheckpointHudBadge=" .. tostring(routeGuide and routeGuide:GetAttribute("ShowCheckpointHudBadge")))
	info("  ShowWorldCheckpointLabel=" .. tostring(routeGuide and routeGuide:GetAttribute("ShowWorldCheckpointLabel")))
	info("  CheckpointFrameStyle=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointFrameStyle")))
	info("  CheckpointFrameTransparency=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointFrameTransparency")))
	info("  WrongWayDelaySeconds=" .. tostring(routeGuide and routeGuide:GetAttribute("WrongWayDelaySeconds")))
	info("  Minimal label patch=" .. tostring(source:find("NTR_RACING_PHASE5D_MINIMAL_CHECKPOINT_LABEL", 1, true) ~= nil))
	info("  Corner tick frame patch=" .. tostring(source:find("NTR_RACING_PHASE5D_CORNER_TICK_FRAME", 1, true) ~= nil))
	info("  Wrong-way delay patch=" .. tostring(source:find("NTR_RACING_PHASE5D_WRONG_WAY_DELAY", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchRouteGuide()
	audit()
	info("Installed. Restart Play before testing the minimal route guide.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
