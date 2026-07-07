-- Neo Tokyo Racers - Racing Phase 5F Checkpoint Pill Label
-- Adds a small configurable transparent pill behind world-space checkpoint text.
--
-- Desired visual:
--   * CHECKPOINT / FINISH text remains above the physical checkpoint.
--   * A small black rounded pill sits only around the text.
--   * Generated checkpoint frames remain off by default.
--   * Phase 5D's 3-second wrong-way delay remains available.
--
-- This patches only the isolated Racing route guide client.
--
-- Usage:
--   MODE = "INSTALL" applies the repair.
--   MODE = "AUDIT" checks whether the repair is present.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5F"

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
	routeGuide:SetAttribute("ShowWorldCheckpointLabel", true)
	routeGuide:SetAttribute("ShowCheckpointHudBadge", false)
	routeGuide:SetAttribute("ShowCheckpointFrames", false)
	routeGuide:SetAttribute("CheckpointFrameStyle", "Off")
	routeGuide:SetAttribute("CheckpointPillWidth", 168)
	routeGuide:SetAttribute("CheckpointPillHeight", 28)
	routeGuide:SetAttribute("CheckpointPillYOffset", 7)
	routeGuide:SetAttribute("CheckpointPillBackgroundTransparency", 0.8)
	routeGuide:SetAttribute("CheckpointPillCornerRadius", 8)
	routeGuide:SetAttribute("CheckpointPillStrokeTransparency", 0.7)
	routeGuide:SetAttribute("CheckpointPillStrokeThickness", 1)
	routeGuide:SetAttribute("CheckpointWorldTextSize", 15)
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

local NEW_PILL_BILLBOARD = [==[
local function makeBillboard(name, adornee, text, color)
	-- NTR_RACING_PHASE5F_WORLD_PILL_LABEL
	if not boolAttr("ShowWorldCheckpointLabel", true) then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = boolAttr("CheckpointWorldTextAlwaysOnTop", true)
	gui.Size = UDim2.fromOffset(numberAttr("CheckpointPillWidth", 168), numberAttr("CheckpointPillHeight", 28))
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
	label.TextSize = numberAttr("CheckpointWorldTextSize", 15)
	label.TextWrapped = false
	label.Font = Enum.Font.GothamBold
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	end)
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, numberAttr("CheckpointPillCornerRadius", 8))
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = numberAttr("CheckpointPillStrokeThickness", 1)
	stroke.Transparency = numberAttr("CheckpointPillStrokeTransparency", 0.7)
	stroke.Parent = label
	return gui
end
]==]

local TEXT_ONLY_DRAW_GATE = [==[
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
]==]

local function patchRouteGuide()
	local guide = routeGuideClient()
	local source = guide.Source
	local changed = false

	if source:find("NTR_RACING_PHASE5F_WORLD_PILL_LABEL", 1, true) then
		info("World pill checkpoint label patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function makeBillboard", "\n\nlocal function colorForGate", NEW_PILL_BILLBOARD, "makeBillboard function")
		changed = true
	end

	if source:find("NTR_RACING_PHASE5F_OPTIONAL_CORNER_TICK_FRAME", 1, true) then
		info("Text-only drawGateFrame patch is already present.")
	else
		source = replaceFunctionWindow(source, "local function drawGateFrame", "\n\nlocal function chevronAt", TEXT_ONLY_DRAW_GATE, "drawGateFrame function")
		changed = true
	end

	if changed then
		guide.Source = source
		info("Patched RaceRouteGuideClient_Active with configurable checkpoint pill labels.")
	end
	return changed
end

local function audit()
	local routeGuide = findRouteGuideConfig()
	local guide = routeGuideClient()
	local source = guide.Source
	info("Audit:")
	info("  CheckpointPillWidth=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointPillWidth")))
	info("  CheckpointPillHeight=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointPillHeight")))
	info("  CheckpointPillYOffset=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointPillYOffset")))
	info("  CheckpointPillBackgroundTransparency=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointPillBackgroundTransparency")))
	info("  CheckpointWorldTextSize=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointWorldTextSize")))
	info("  World pill patch=" .. tostring(source:find("NTR_RACING_PHASE5F_WORLD_PILL_LABEL", 1, true) ~= nil))
	info("  Draw patch=" .. tostring(source:find("NTR_RACING_PHASE5F_OPTIONAL_CORNER_TICK_FRAME", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchRouteGuide()
	audit()
	info("Installed. Restart Play before testing the checkpoint pill label.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
