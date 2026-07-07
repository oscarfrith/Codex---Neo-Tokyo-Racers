-- Neo Tokyo Racers - Racing Phase 5C Checkpoint Label/Frame Opacity Repair
-- Separates the checkpoint text label panel opacity from the world frame opacity.
--
-- Desired visual:
--   Label text/panel: 20% transparent, readable.
--   World checkpoint/finish frame: 80% transparent, subtle.
--
-- Usage:
--   MODE = "INSTALL" applies the repair.
--   MODE = "AUDIT" checks whether the repair is present.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5C"

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
	routeGuide:SetAttribute("CheckpointFrameTransparency", 0.8)
	routeGuide:SetAttribute("CheckpointLabelBackgroundTransparency", 0.2)
	routeGuide:SetAttribute("CheckpointLabelTextTransparency", 0.2)
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

local OLD_LABEL_LINE = [[	label.BackgroundTransparency = 0.18]]
local OLD_LABEL_LINE_ALT = [[	label.BackgroundTransparency = 0.2]]
local NEW_LABEL_LINE = [[	label.BackgroundTransparency = numberAttr("CheckpointLabelBackgroundTransparency", 0.2) -- NTR_RACING_PHASE5C_LABEL_TRANSPARENCY]]
local TEXT_COLOR_LINE = [[	label.TextColor3 = color]]
local NEW_TEXT_COLOR_BLOCK = [==[
	label.TextColor3 = color
	label.TextTransparency = numberAttr("CheckpointLabelTextTransparency", 0.2) -- NTR_RACING_PHASE5C_TEXT_TRANSPARENCY
]==]

local OLD_FRAME_LINES = [==[
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, 0.04)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, 0.04)
]==]

local NEW_FRAME_LINES = [==[
	local frameTransparency = numberAttr("CheckpointFrameTransparency", 0.8)
	-- NTR_RACING_PHASE5B_FRAME_TRANSPARENCY
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, frameTransparency)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, frameTransparency)
]==]

local function patchGuideSource()
	local guide = routeGuideClient()
	local source = guide.Source
	local changed = false

	if source:find("NTR_RACING_PHASE5C_LABEL_TRANSPARENCY", 1, true) then
		info("Checkpoint label transparency source patch is already present.")
	else
		if source:find(OLD_LABEL_LINE, 1, true) then
			source = replacePlain(source, OLD_LABEL_LINE, NEW_LABEL_LINE, "checkpoint label transparency line")
		elseif source:find(OLD_LABEL_LINE_ALT, 1, true) then
			source = replacePlain(source, OLD_LABEL_LINE_ALT, NEW_LABEL_LINE, "checkpoint label transparency line")
		else
			fail("Could not find checkpoint label transparency line. Refresh the mirror/source before trying another repair.")
		end
		changed = true
	end

	if source:find("NTR_RACING_PHASE5C_TEXT_TRANSPARENCY", 1, true) then
		info("Checkpoint text transparency source patch is already present.")
	else
		source = replacePlain(source, TEXT_COLOR_LINE, NEW_TEXT_COLOR_BLOCK, "checkpoint text color line")
		changed = true
	end

	if source:find("NTR_RACING_PHASE5B_FRAME_TRANSPARENCY", 1, true) then
		info("Checkpoint frame transparency source patch is already present.")
	else
		source = replacePlain(source, OLD_FRAME_LINES, NEW_FRAME_LINES, "checkpoint frame transparency lines")
		changed = true
	end

	if changed then
		guide.Source = source
		info("Patched RaceRouteGuideClient_Active label/frame transparency split.")
	end
	return changed
end

local function audit()
	local routeGuide = findRouteGuideConfig()
	local guide = routeGuideClient()
	info("Audit:")
	info("  CheckpointFrameTransparency=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointFrameTransparency")))
	info("  CheckpointLabelBackgroundTransparency=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointLabelBackgroundTransparency")))
	info("  CheckpointLabelTextTransparency=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointLabelTextTransparency")))
	info("  Label source patch=" .. tostring(guide.Source:find("NTR_RACING_PHASE5C_LABEL_TRANSPARENCY", 1, true) ~= nil))
	info("  Text source patch=" .. tostring(guide.Source:find("NTR_RACING_PHASE5C_TEXT_TRANSPARENCY", 1, true) ~= nil))
	info("  Frame source patch=" .. tostring(guide.Source:find("NTR_RACING_PHASE5B_FRAME_TRANSPARENCY", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchGuideSource()
	audit()
	info("Installed. Restart Play before testing checkpoint label/frame opacity.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
