-- Neo Tokyo Racers - Racing Phase 5B Marker Dedupe And Transparency Repair
-- Disables the older Phase 3/4 checkpoint marker and makes Phase 5 frames
-- use a configurable 80% transparency.
--
-- This patches only isolated Racing scripts:
--   StarterPlayer...Controllers.Racing.RaceEntryMenuClient_Active
--   StarterPlayer...Controllers.Racing.RaceRouteGuideClient_Active
--
-- Usage:
--   MODE = "INSTALL" applies the repair.
--   MODE = "AUDIT" checks whether the repair is present.

local MODE = "INSTALL" -- "INSTALL" or "AUDIT"
local PHASE = "NTR Racing Phase 5B"

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

local function sourceObject(name)
	local folder = racingClientFolder()
	local object = folder:FindFirstChild(name)
	if not (object and object:IsA("LuaSourceContainer")) then
		fail("Missing " .. name .. ". Run Racing Phase 3/5 first, or refresh the Studio mirror before repairing.")
	end
	return object
end

local OLD_MARKER_BLOCK = [==[
local function ensureMarker(part, isFinish)
	clearMarker()
	if not (part and part:IsA("BasePart")) then return end
	marker = Instance.new("SelectionBox")
	marker.Name = "RaceNextGateSelection"
	marker.Adornee = part
	marker.Color3 = isFinish and Color3.fromRGB(255, 226, 80) or theme.Accent
	marker.LineThickness = 0.08
	marker.SurfaceTransparency = 0.88
	marker.Parent = markerRoot

	markerGui = Instance.new("BillboardGui")
	markerGui.Name = "RaceNextGateBillboard"
	markerGui.Adornee = part
	markerGui.AlwaysOnTop = true
	markerGui.Size = UDim2.fromOffset(170, 44)
	markerGui.StudsOffset = Vector3.new(0, math.max(7, part.Size.Y * 0.5 + 5), 0)
	markerGui.Parent = markerRoot
	local l = label(markerGui, isFinish and "FINISH" or "CHECKPOINT", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 15, isFinish and Color3.fromRGB(255, 226, 80) or theme.Accent, true)
	l.BackgroundColor3 = theme.Panel
	l.BackgroundTransparency = 0.16
	l.TextXAlignment = Enum.TextXAlignment.Center
	corner(l, 6)
end
]==]

local NEW_MARKER_BLOCK = [==[
local function ensureMarker(part, isFinish)
	-- NTR_RACING_PHASE5B_OLD_MARKER_DISABLED
	-- Phase 5's RaceRouteGuideClient_Active now owns checkpoint visuals.
	-- Keep this function as a cleanup hook so any existing old marker is removed.
	clearMarker()
	return
end
]==]

local OLD_FRAME_BLOCK = [==[
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, 0.04)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, 0.04)
]==]

local NEW_FRAME_BLOCK = [==[
	local frameTransparency = numberAttr("CheckpointFrameTransparency", 0.8)
	-- NTR_RACING_PHASE5B_FRAME_TRANSPARENCY
	part("NextGateFrame_X", Vector3.new(x, 0.32, 0.32), cf, color, frameTransparency)
	part("NextGateFrame_Z", Vector3.new(0.32, 0.32, z), cf, color, frameTransparency)
]==]

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local routeGuide = ensureFolder(racing, "RouteGuide")
	routeGuide:SetAttribute("CheckpointFrameTransparency", 0.8)
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

local function patchOldEntryMarker()
	local client = sourceObject("RaceEntryMenuClient_Active")
	local source = client.Source
	if source:find("NTR_RACING_PHASE5B_OLD_MARKER_DISABLED", 1, true) then
		info("Old RaceEntryMenuClient marker is already disabled.")
		return false
	end
	client.Source = replacePlain(source, OLD_MARKER_BLOCK, NEW_MARKER_BLOCK, "old checkpoint marker block in RaceEntryMenuClient_Active")
	info("Disabled old RaceEntryMenuClient checkpoint SelectionBox/Billboard marker.")
	return true
end

local function patchRouteGuideTransparency()
	local guide = sourceObject("RaceRouteGuideClient_Active")
	local source = guide.Source
	if source:find("NTR_RACING_PHASE5B_FRAME_TRANSPARENCY", 1, true) then
		info("RaceRouteGuideClient frame transparency patch is already present.")
		return false
	end
	guide.Source = replacePlain(source, OLD_FRAME_BLOCK, NEW_FRAME_BLOCK, "Phase 5 frame transparency block in RaceRouteGuideClient_Active")
	info("Changed Phase 5 checkpoint/finish frame transparency to Config.Racing.RouteGuide.CheckpointFrameTransparency.")
	return true
end

local function audit()
	local routeGuide = findRouteGuideConfig()
	local entry = sourceObject("RaceEntryMenuClient_Active")
	local guide = sourceObject("RaceRouteGuideClient_Active")
	info("Audit:")
	info("  Old marker disabled=" .. tostring(entry.Source:find("NTR_RACING_PHASE5B_OLD_MARKER_DISABLED", 1, true) ~= nil))
	info("  Guide frame transparency attr=" .. tostring(routeGuide and routeGuide:GetAttribute("CheckpointFrameTransparency")))
	info("  Guide transparency source patch=" .. tostring(guide.Source:find("NTR_RACING_PHASE5B_FRAME_TRANSPARENCY", 1, true) ~= nil))
end

local function install()
	ensureConfig()
	patchOldEntryMarker()
	patchRouteGuideTransparency()
	audit()
	info("Installed. Restart Play before testing the deduped, lighter checkpoint guide.")
end

if MODE == "INSTALL" then
	install()
elseif MODE == "AUDIT" then
	audit()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
