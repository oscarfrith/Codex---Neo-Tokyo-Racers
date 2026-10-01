-- Vehicle frame-class blockout builder (design exploration only, not game content).
-- Run through the Studio MCP in Edit mode. Reads one spec JSON from the local spec server
-- (py -3 -m http.server 8777 --bind 127.0.0.1 --directory scripts/vehicle_blockouts/specs)
-- and builds one showroom row under Workspace.VehicleCategoryBlockouts.<ID>.
-- Only ever creates or destroys instances inside Workspace.VehicleCategoryBlockouts.
local SPEC_NAME = "__SPEC_NAME__" -- e.g. "rift"
local ROW = __ROW__ -- row index, 0-based
local ORIGIN = Vector3.new(__ORIGIN__)
local ROW_PITCH, STATION_PITCH = 80, 48

local HttpService = game:GetService("HttpService")
local spec = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8777/" .. SPEC_NAME .. ".json", true))

local SLOT_COLOURS = {
	Cockpit = "#e8e8ea", Engine1 = "#ff6b35", Engine2 = "#f7c531", Stabilisers = "#35c2ff", Boost = "#ff3df0",
	FrontBumper = "#7bd44a", RearBumper = "#2f9e62", RearSpoiler = "#9b6bff", SidePods = "#ff9fb0",
	Hood = "#c9a36b", Roof = "#7fd9d0", Accessory = "#b0b6c4",
}
local SLOT_ORDER = { "Engine1", "Engine2", "Stabilisers", "Boost", "FrontBumper", "RearBumper", "RearSpoiler", "SidePods", "Hood", "Roof", "Accessory" }
local FIXED = { detail = "#22252b", glass = "#3f6f8f", thrust = "#8ff6ff", driver = "#d9b38c" }
local DEFAULT_PAINT = { primary = "#c9302c", secondary = "#f2f2f2", neon = "#00e5ff" }
local CHANNEL_NAME = { primary = "Primary", secondary = "Secondary", detail = "Detail", glass = "Glass", neon = "Neon", thrust = "Thrust", driver = "Driver" }

local root = workspace:FindFirstChild("VehicleCategoryBlockouts")
if not root then
	root = Instance.new("Folder")
	root.Name = "VehicleCategoryBlockouts"
	root:SetAttribute("Purpose", "Design blockouts for proposed vehicle frame classes. Not game content. Safe to delete.")
	root.Parent = workspace
end
local id = string.upper(spec.id)
local old = root:FindFirstChild(id)
if old then old:Destroy() end
local classFolder = Instance.new("Folder")
classFolder.Name = id
classFolder:SetAttribute("CategoryId", spec.id)
classFolder:SetAttribute("DisplayName", spec.displayName)
classFolder:SetAttribute("Tagline", spec.tagline or "")

local hover = (spec.standard.datums and spec.standard.datums.hoverPlane) or -2
local rowOrigin = ORIGIN + Vector3.new(0, 0, ROW * ROW_PITCH)
local partCount = 0

local function v3(t) return Vector3.new(t[1], t[2], t[3]) end

local function makePart(p, colourHex, parent, base, offset, slotId)
	local shape, size = p.shape, p.size
	local rot = p.rot or { 0, 0, 0 }
	local function one(px, ry, rz)
		local part
		local fix = CFrame.new()
		if shape == "wedge" then
			part = Instance.new("WedgePart")
			part.Size = v3(size)
		else
			part = Instance.new("Part")
			if shape == "block" then
				part.Size = v3(size)
			elseif shape == "ball" then
				local d = math.min(size[1], size[2], size[3])
				part.Shape = Enum.PartType.Ball
				part.Size = Vector3.new(d, d, d)
			elseif shape == "cyl_x" then
				part.Shape = Enum.PartType.Cylinder
				local d = math.min(size[2], size[3])
				part.Size = Vector3.new(size[1], d, d)
			elseif shape == "cyl_y" then
				part.Shape = Enum.PartType.Cylinder
				local d = math.min(size[1], size[3])
				part.Size = Vector3.new(size[2], d, d)
				fix = CFrame.Angles(0, 0, math.rad(90))
			elseif shape == "cyl_z" then
				part.Shape = Enum.PartType.Cylinder
				local d = math.min(size[1], size[2])
				part.Size = Vector3.new(size[3], d, d)
				fix = CFrame.Angles(0, math.rad(90), 0)
			end
		end
		local ch = p.ch or "primary"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = (ch == "neon" or ch == "thrust") and Enum.Material.Neon or (ch == "glass" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
		part.Transparency = ch == "glass" and 0.35 or 0
		part.Color = Color3.fromHex(colourHex)
		part.Name = (p.note and p.note ~= "" and string.sub(p.note, 1, 40)) or (shape .. "_" .. ch)
		part:SetAttribute("PaintChannel", CHANNEL_NAME[ch] or ch)
		part:SetAttribute("SlotId", slotId)
		part.CFrame = base * CFrame.new(px + offset.X, p.pos[2] + offset.Y, p.pos[3] + offset.Z)
			* CFrame.fromOrientation(math.rad(rot[1]), math.rad(ry), math.rad(rz)) * fix
		part.Parent = parent
		partCount += 1
	end
	one(p.pos[1], rot[2], rot[3])
	if p.mirror then one(-p.pos[1], -rot[2], -rot[3]) end
end

local function colourFor(p, paint, slotId, bySlot)
	local ch = p.ch or "primary"
	if bySlot then
		if ch == "glass" or ch == "driver" then return FIXED[ch] end
		return SLOT_COLOURS[slotId] or "#cccccc"
	end
	return FIXED[ch] or (paint and paint[ch]) or DEFAULT_PAINT[ch] or "#cccccc"
end

local function label(parent, pos, text, sub, height)
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = pos
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(34, height or 5)
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.6 or 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = gui
	if sub then
		local s = t:Clone()
		s.Font = Enum.Font.Gotham
		s.Position = UDim2.fromScale(0, 0.6)
		s.Size = UDim2.fromScale(1, 0.4)
		s.TextColor3 = Color3.fromRGB(190, 230, 255)
		s.Text = sub
		s.Parent = gui
	end
	anchor.Parent = parent
end

local function scaleFigure(parent, base)
	local m = Instance.new("Model")
	m.Name = "ScaleFigure_5studs"
	local function b(size, pos)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.Color = Color3.fromRGB(150, 155, 165)
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = base * CFrame.new(pos)
		part.Parent = m
		partCount += 1
	end
	b(Vector3.new(2, 2, 1), Vector3.new(0, hover + 1, 0))
	b(Vector3.new(2, 2, 1), Vector3.new(0, hover + 3, 0))
	b(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, hover + 4.6, 0))
	m.Parent = parent
end

local function slotModel(parent, slotId)
	local m = Instance.new("Model")
	local def = spec.standard.slots[slotId]
	m.Name = slotId == "Cockpit" and "Cockpit" or (slotId .. " - " .. (def and def.label or slotId))
	m:SetAttribute("SlotId", slotId)
	m.Parent = parent
	return m
end

local function buildVehicle(parent, base, build, exploded, bySlot)
	local cockpit = spec.cockpits[build.cockpit]
	local cm = slotModel(parent, "Cockpit")
	cm:SetAttribute("CockpitId", build.cockpit)
	for _, p in ipairs(cockpit.parts) do
		makePart(p, colourFor(p, build.paint, "Cockpit", bySlot), cm, base, Vector3.zero, "Cockpit")
	end
	for _, slotId in ipairs(SLOT_ORDER) do
		local mid = build.modules[slotId]
		if mid then
			local def = spec.standard.slots[slotId]
			local off = (exploded and def.explode) and v3(def.explode) or Vector3.zero
			local mm = slotModel(parent, slotId)
			mm:SetAttribute("ModuleId", mid)
			mm:SetAttribute("DisplayName", spec.modules[slotId][mid].name)
			for _, p in ipairs(spec.modules[slotId][mid].parts) do
				makePart(p, colourFor(p, build.paint, slotId, bySlot), mm, base, off, slotId)
			end
		end
	end
end

local stationCount = 2 + #spec.builds
local floorY = rowOrigin.Y
local floor = Instance.new("Part")
floor.Name = "RowFloor"
floor.Anchored = true
floor.Size = Vector3.new(stationCount * STATION_PITCH + 40, 1, 64)
floor.Position = Vector3.new(rowOrigin.X + (stationCount - 1) * STATION_PITCH / 2, floorY - 0.5, rowOrigin.Z)
floor.Color = Color3.fromRGB(38, 41, 48)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = classFolder

local function stationBase(i)
	return CFrame.new(rowOrigin.X + i * STATION_PITCH, floorY - hover, rowOrigin.Z)
end

label(classFolder, Vector3.new(rowOrigin.X - 34, floorY + 16, rowOrigin.Z), spec.displayName, spec.tagline, 9)

-- Station 0: frame standard (envelopes)
do
	local m = Instance.new("Model")
	m.Name = "00_FrameStandard"
	local base = stationBase(0)
	local function box(slotId, env, text)
		local list = env[1] and env or { env }
		for _, b in ipairs(list) do
			local function one(lo, hi)
				local part = Instance.new("Part")
				part.Name = "Envelope_" .. slotId
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.Transparency = 0.72
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.fromHex(SLOT_COLOURS[slotId] or "#cccccc")
				part.Size = Vector3.new(hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3])
				part.CFrame = base * CFrame.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
				part:SetAttribute("SlotId", slotId)
				part.Parent = m
				partCount += 1
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromScale(9, 1.6)
				gui.AlwaysOnTop = true
				gui.MaxDistance = 220
				gui.Parent = part
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Font = Enum.Font.GothamBold
				t.TextScaled = true
				t.TextColor3 = Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0
				t.Text = text
				t.Parent = gui
			end
			one(b.min, b.max)
			if b.mirror then one({ -b.max[1], b.min[2], b.min[3] }, { -b.min[1], b.max[2], b.max[3] }) end
		end
	end
	box("Cockpit", spec.standard.cockpitEnvelope, "COCKPIT")
	for _, slotId in ipairs(SLOT_ORDER) do
		local def = spec.standard.slots[slotId]
		if def then box(slotId, def.envelope, def.label) end
	end
	label(m, (base * CFrame.new(0, 14, 0)).Position, "Frame standard", "slot envelopes every part must stay inside")
	m.Parent = classFolder
end

-- Station 1: exploded first build in slot colours
do
	local m = Instance.new("Model")
	m.Name = "01_Exploded"
	local base = stationBase(1) * CFrame.new(0, 6, 0)
	buildVehicle(m, base, spec.builds[1], true, true)
	label(m, (stationBase(1) * CFrame.new(0, 24, 0)).Position, "Exploded: " .. spec.builds[1].name, "one colour per module slot")
	m.Parent = classFolder
end

for i, build in ipairs(spec.builds) do
	local m = Instance.new("Model")
	m.Name = string.format("B%d_%s", i, build.name)
	m:SetAttribute("CockpitId", build.cockpit)
	local base = stationBase(1 + i)
	buildVehicle(m, base, build, false, false)
	scaleFigure(m, base * CFrame.new(-14, 0, 6))
	local c = spec.cockpits[build.cockpit]
	label(m, (base * CFrame.new(0, 13, 0)).Position, build.name, c.name .. " cockpit" .. (build.note and (" | " .. build.note) or ""))
	m.Parent = classFolder
end

classFolder.Parent = root
game:GetService("ChangeHistoryService"):SetWaypoint("VehicleCategoryBlockouts " .. id)
return string.format("%s: %d builds, %d parts, row origin %s", id, #spec.builds, partCount, tostring(rowOrigin))
