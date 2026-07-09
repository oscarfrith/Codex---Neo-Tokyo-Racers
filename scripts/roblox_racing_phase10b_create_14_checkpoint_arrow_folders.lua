-- NTR Racing Phase 10B helper - create 14-checkpoint arrow segment folders.
-- Paste into Roblox Studio Command Bar in Edit mode.
--
-- Creates:
--   ArrowMarkers.Checkpoint0-1
--   ArrowMarkers.Checkpoint1-2
--   ...
--   ArrowMarkers.Checkpoint13-14
--   ArrowMarkers.Checkpoint14-0
--
-- This does not move, delete, hide, or edit existing arrow assets.

local ROUTE_ID = "ShiftedCanalSprint"
local CHECKPOINT_COUNT = 14
local PHASE = "NTR Racing Phase 10B Folder Helper"

local Workspace = game:GetService("Workspace")

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
local routes = world and world:FindFirstChild("RaceRoutes")
local route = routes and routes:FindFirstChild(ROUTE_ID)
if not route then
	fail("Missing route Workspace.NeoTokyoRacersWorld.RaceRoutes." .. ROUTE_ID)
end

local arrowMarkers = route:FindFirstChild("ArrowMarkers")
if not arrowMarkers then
	arrowMarkers = Instance.new("Folder")
	arrowMarkers.Name = "ArrowMarkers"
	arrowMarkers.Parent = route
end

arrowMarkers:SetAttribute("NTR_Phase10B_FolderSegments", true)
arrowMarkers:SetAttribute("SegmentWindowBehind", tonumber(arrowMarkers:GetAttribute("SegmentWindowBehind")) or 1)
arrowMarkers:SetAttribute("SegmentWindowAhead", tonumber(arrowMarkers:GetAttribute("SegmentWindowAhead")) or 1)
arrowMarkers:SetAttribute("DefaultColliderThickness", tonumber(arrowMarkers:GetAttribute("DefaultColliderThickness")) or 3)

local created = 0
local existing = 0

local function ensureSegmentFolder(name, fromIndex, toValue)
	local folder = arrowMarkers:FindFirstChild(name)
	if folder and not folder:IsA("Folder") then
		fail("Expected " .. arrowMarkers:GetFullName() .. "." .. name .. " to be a Folder, got " .. folder.ClassName)
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = arrowMarkers
		created += 1
	else
		existing += 1
	end
	folder:SetAttribute("NTR_ArrowSegmentFolder", true)
	folder:SetAttribute("SegmentFrom", fromIndex)
	folder:SetAttribute("SegmentTo", toValue)
	folder:SetAttribute("SegmentKey", name)
	if folder:GetAttribute("Enabled") == nil then
		folder:SetAttribute("Enabled", true)
	end
	return folder
end

for index = 0, CHECKPOINT_COUNT - 1 do
	ensureSegmentFolder("Checkpoint" .. tostring(index) .. "-" .. tostring(index + 1), index, index + 1)
end

ensureSegmentFolder("Checkpoint" .. tostring(CHECKPOINT_COUNT) .. "-0", CHECKPOINT_COUNT, 0)

local unassigned = arrowMarkers:FindFirstChild("Unassigned_Arrows")
if not unassigned then
	unassigned = Instance.new("Folder")
	unassigned.Name = "Unassigned_Arrows"
	unassigned.Parent = arrowMarkers
	created += 1
end
unassigned:SetAttribute("NTR_ArrowUnassigned", true)

log("Created " .. tostring(created) .. " folders; " .. tostring(existing) .. " segment folders already existed.")
log("Ready. Drag arrow groups into CheckpointA-B folders. Final circuit segment is Checkpoint" .. tostring(CHECKPOINT_COUNT) .. "-0.")
