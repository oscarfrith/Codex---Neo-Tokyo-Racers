-- Neo Tokyo Racers - Racing Phase 5E World Text-Only Checkpoint Guide
-- Restores checkpoint text above the physical checkpoint, with no backing frame/panel.
--
-- Desired visual:
--   * CHECKPOINT / FINISH text floats above the actual checkpoint volume.
--   * No dark label background.
--   * No generated checkpoint frame/corner ticks by default.
--   * Dynamic route arrows and the Phase 5D wrong-way delay remain available.
--
-- This patches only the isolated Racing route guide client.
--
-- Usage:
--   MODE = "INSTALL" applies the repair.
--   MODE = "AUDIT" checks whether the repair is present.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5E"

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
	routeGuide:SetAttribute("ShowCheckpointHudBadge", false)
	routeGuide:SetAttribute("ShowWorldCheckpointLabel", true)
	routeGuide:SetAttribute("ShowCheckpointFrames", false)
	routeGuide:SetAttribute("CheckpointFrameStyle", "Off")
	routeGuide:SetAttribute("CheckpointWorldTextSize", 15)
	routeGuide:SetAttribute("CheckpointWorldTextYOffset", 7)
	routeGuide:SetAttribute("CheckpointWorldTextStrokeTransparency", 0.35)
	routeGuide:SetAttribute("CheckpointWorldTextAlwaysOnTop", true)
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

local function replaceFunctionWindow(source, startAnchor, nextAnchor, newText, label)
	local startIndex = source:find(startAnchor, 1, true)
	if not startIndex then
		fail("Could not find start of " .. label .. ". Refresh the mirror/source before trying another repair.")
	end
	local nextIndex = source:find(nextAnchor, startIndex + #startAnchor, true)
	if not nextIndex and nextAnchor:find("\n", 1, true) then
		nextIndex = source:find(nextAnchor:gsub("\n", "\r\n"), startIndex + #startAnchor, true)
	end
	if not nextIndex then
		fail("Could not find end anchor for " .. label .. ". Refresh the mirror/source before trying another repair.")
	end
	return source:sub(1, startIndex - 1) .. newText .. source:sub(nextIndex)
end

local NEW_WORLD_TEXT_BILLBOARD = [==[
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
]==]

local NEW_TEXT_ONLY_DRAW_GATE = [==[
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
]==]

local WRONG_WAY_DELAY_BLOCK = [==[
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

local function ensureWrongWayDelay(source)
	if source:find("NTR_RACING_PHASE5D_WRONG_WAY_DELAY", 1, true) then
		return source, false
	end
	source = replaceFunctionWindow(source, "local function updateWrongWay", "\n\nlocal function renderGuide", WRONG_WAY_DELAY_BLOCK, "updateWrongWay function")
	source = source:gsub("RunService%.Heartbeat:Connect%(%s*function%(%s*%)", "RunService.Heartbeat:Connect(function(dt)", 1)
	source = source:gsub("updateWrongWay%(%s*%)", "updateWrongWay(dt)", 1)
	return source, true
end

local function patchRouteGuide()
	local guide = routeGuideClient()
	local source = guide.Source
	local changed = false

	if source:find("NTR_RACING_PHASE5E_WORLD_TEXT_ONLY_LABEL", 1, true) then
		info("World text-only checkpoint label patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function makeBillboard", "\n\nlocal function colorForGate", NEW_WORLD_TEXT_BILLBOARD, "makeBillboard function")
		changed = true
	end

	if source:find("NTR_RACING_PHASE5E_OPTIONAL_CORNER_TICK_FRAME", 1, true) then
		info("Text-only drawGateFrame patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function drawGateFrame", "\n\nlocal function chevronAt", NEW_TEXT_ONLY_DRAW_GATE, "drawGateFrame function")
		changed = true
	end

	local patchedWrongWay
	source, patchedWrongWay = ensureWrongWayDelay(source)
	changed = changed or patchedWrongWay

	if changed then
		guide.Source = source
		info("Patched RaceRouteGuideClient_Active with world text-only checkpoint labels.")
	end
	return changed
end

local function audit()
	local routeGuide = findRouteGuideConfig()
	local guide = routeGuideClient()
	local source = guide.Source
	info("Audit:")
	info("  ShowWorldCheckpointLabel=" .. tostring(routeGuide and routeGuide:GetAttribute("ShowWorldCheckpointLabel")))
	info("  ShowCheckpointHudBadge=" .. tostring(routeGuide and routeGuide:GetAttribute("ShowCheckpointHudBadge")))
	info("  ShowCheckpointFrames=" .. tostring(routeGuide and routeGuide:GetAttribute("ShowCheckpointFrames")))
	info("  CheckpointFrameStyle=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointFrameStyle")))
	info("  World text patch=" .. tostring(source:find("NTR_RACING_PHASE5E_WORLD_TEXT_ONLY_LABEL", 1, true) ~= nil))
	info("  Text-only draw patch=" .. tostring(source:find("NTR_RACING_PHASE5E_OPTIONAL_CORNER_TICK_FRAME", 1, true) ~= nil))
	info("  Wrong-way delay patch=" .. tostring(source:find("NTR_RACING_PHASE5D_WRONG_WAY_DELAY", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchRouteGuide()
	audit()
	info("Installed. Restart Play before testing the world text-only checkpoint guide.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
