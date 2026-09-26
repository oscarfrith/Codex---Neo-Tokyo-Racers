-- Guarded removal / restore of the retired Courier hub pads (Workspace.World.Jobs).
-- Data is the exact captured state (roblox/captures/mapui-after/capture.json). Edit mode only.
-- Usage: set MODE to "AUDIT", "DELETE" or "RESTORE". RESTORE pairs with installer ROLLBACK of world_jobs
-- (the old CourierJob/CourierClientView need the CourierHub-tagged pads).
local MODE = (...) or "AUDIT"
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local CollectionService = game:GetService("CollectionService")

local PADS = {
	{ Name = "Hub_Dealership", HubId = "Dealership", DisplayName = "Dealership Depot", Position = Vector3.new(598.9000244140625, 100.5999984741211, -1755.4000244140625) },
	{ Name = "Hub_Kanda", HubId = "Kanda", DisplayName = "Kanda Garage Depot", Position = Vector3.new(1548.9000244140625, 100.5999984741211, -1893.0999755859375) },
	{ Name = "Hub_ShowroomLoop", HubId = "ShowroomLoop", DisplayName = "Showroom Loop Depot", Position = Vector3.new(1314.9000244140625, 100.5999984741211, -1321.699951171875) },
}
local COLOR = Color3.new(0.16470588743686676, 0.8823529481887817, 0.8509804010391235)

local world = workspace:WaitForChild("World")

local function matches(jobs)
	local hubs = jobs and jobs:FindFirstChild("CourierHubs")
	if not (jobs and hubs and #jobs:GetChildren() == 1 and #hubs:GetChildren() == #PADS) then return false end
	for _, pad in ipairs(PADS) do
		local part = hubs:FindFirstChild(pad.Name)
		if not (part and part:IsA("Part") and part:GetAttribute("HubId") == pad.HubId and CollectionService:HasTag(part, "CourierHub")
			and (part.Position - pad.Position).Magnitude < 0.01) then return false end
	end
	return true
end

local jobs = world:FindFirstChild("Jobs")
local state = jobs == nil and "deleted" or (matches(jobs) and "present" or "unexpected")
if MODE == "AUDIT" then return "state=" .. state end
assert(state ~= "unexpected", "World.Jobs differs from the captured pads; refusing")

if MODE == "DELETE" then
	if state == "deleted" then return "state=deleted (no change)" end
	jobs:Destroy()
	return "state=deleted (removed World.Jobs with 3 pads)"
elseif MODE == "RESTORE" then
	if state == "present" then return "state=present (no change)" end
	local folder = Instance.new("Folder")
	folder.Name = "Jobs"
	local hubs = Instance.new("Folder")
	hubs.Name = "CourierHubs"
	hubs.Parent = folder
	for _, pad in ipairs(PADS) do
		local part = Instance.new("Part")
		part.Name = pad.Name
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Size = Vector3.new(36, 0.4000000059604645, 36)
		part.CFrame = CFrame.new(pad.Position)
		part.Material = Enum.Material.Neon
		part.Color = COLOR
		part.Transparency = 0.75
		part:SetAttribute("HubId", pad.HubId)
		part:SetAttribute("DisplayName", pad.DisplayName)
		CollectionService:AddTag(part, "CourierHub")
		part.Parent = hubs
	end
	folder.Parent = world
	return "state=present (restored 3 pads)"
end
error("MODE must be AUDIT, DELETE or RESTORE")
