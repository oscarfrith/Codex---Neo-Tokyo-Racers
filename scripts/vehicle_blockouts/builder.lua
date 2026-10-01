-- Vehicle frame-class blockout builder (design exploration only, not game content).
-- Run through the Studio MCP in Edit mode. Reads one flattened showroom layout from the local server
-- (py -3 -m http.server 8778 --bind 127.0.0.1 --directory scripts/vehicle_blockouts), produced by
-- export_showroom.py, and builds one class block under Workspace.VehicleCategoryBlockouts.<ID>.
-- Only ever creates or destroys instances inside Workspace.VehicleCategoryBlockouts.
local SPEC_NAME = "__SPEC_NAME__" -- e.g. "rift"
local ORIGIN = Vector3.new(__ORIGIN__) -- block origin (floor level)

local HttpService = game:GetService("HttpService")
local data = HttpService:JSONDecode(HttpService:GetAsync("http://127.0.0.1:8778/showroom/" .. SPEC_NAME .. ".json", true))

local SLOT_COLOURS = {
	Cockpit = "#e8e8ea", Engine1 = "#ff6b35", Engine2 = "#f7c531", Stabilisers = "#35c2ff", Boost = "#ff3df0",
	FrontBody = "#c77b4a", RearBody = "#9aa53b", SidePods = "#ff9fb0", FrontBumper = "#7bd44a", RearBumper = "#2f9e62",
	RearSpoiler = "#9b6bff", Hood = "#c9a36b", Roof = "#7fd9d0", Accessory = "#b0b6c4",
}
local CHANNEL_NAME = { primary = "Primary", secondary = "Secondary", detail = "Detail", glass = "Glass", neon = "Neon", thrust = "Thrust", driver = "Driver" }

local root = workspace:FindFirstChild("VehicleCategoryBlockouts")
if not root then
	root = Instance.new("Folder")
	root.Name = "VehicleCategoryBlockouts"
	root:SetAttribute("Purpose", "Design blockouts for proposed vehicle frame classes. Not game content. Safe to delete.")
	root.Parent = workspace
end
local id = string.upper(data.id)
local old = root:FindFirstChild(id)
if old then old:Destroy() end
local classFolder = Instance.new("Folder")
classFolder.Name = id
classFolder:SetAttribute("CategoryId", data.id)
classFolder:SetAttribute("DisplayName", data.displayName)
classFolder:SetAttribute("Tagline", data.tagline)

local hover = data.hover
local partCount = 0

local function makePart(p, parent, base, slotId)
	local shape, size = p.s, p.z
	local part
	local fix = CFrame.new()
	if shape == "wedge" then
		part = Instance.new("WedgePart")
		part.Size = Vector3.new(size[1], size[2], size[3])
	else
		part = Instance.new("Part")
		if shape == "block" then
			part.Size = Vector3.new(size[1], size[2], size[3])
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
	local ch = p.c
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = (ch == "neon" or ch == "thrust") and Enum.Material.Neon or (ch == "glass" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
	part.Transparency = ch == "glass" and 0.35 or 0
	part.Color = Color3.fromHex(p.h)
	part.Name = shape .. "_" .. ch
	part:SetAttribute("PaintChannel", CHANNEL_NAME[ch] or ch)
	part:SetAttribute("SlotId", slotId)
	part.CFrame = base * CFrame.new(p.p[1], p.p[2], p.p[3]) * CFrame.fromOrientation(math.rad(p.r[1]), math.rad(p.r[2]), math.rad(p.r[3])) * fix
	part.Parent = parent
	partCount += 1
end

local function label(parent, pos, text, sub, width, height)
	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = pos
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 30, height or 4.4)
	gui.LightInfluence = 0
	gui.MaxDistance = 700
	gui.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, (sub and sub ~= "") and 0.6 or 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = gui
	if sub and sub ~= "" then
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

local fl = data.floor
local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(fl.x1 - fl.x0, 1, fl.z1 - fl.z0)
floor.Position = ORIGIN + Vector3.new((fl.x0 + fl.x1) / 2, -0.5, (fl.z0 + fl.z1) / 2)
floor.Color = Color3.fromRGB(38, 41, 48)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = classFolder

local function baseAt(x, z, lift)
	return CFrame.new(ORIGIN.X + x, ORIGIN.Y - hover + (lift or 0), ORIGIN.Z + z)
end

label(classFolder, ORIGIN + Vector3.new(fl.x0 + 12, 22, fl.z0 + 4), data.displayName, data.tagline, 44, 9)

do -- frame standard: the slot envelopes
	local m = Instance.new("Model")
	m.Name = "00_FrameStandard"
	local base = baseAt(0, 0, 0)
	for _, e in ipairs(data.envelopes) do
		local part = Instance.new("Part")
		part.Name = "Envelope_" .. e.slot
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 0.72
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromHex(SLOT_COLOURS[e.slot] or "#cccccc")
		part.Size = Vector3.new(e.hi[1] - e.lo[1], e.hi[2] - e.lo[2], e.hi[3] - e.lo[3])
		part.CFrame = base * CFrame.new((e.lo[1] + e.hi[1]) / 2, (e.lo[2] + e.hi[2]) / 2, (e.lo[3] + e.hi[3]) / 2)
		part:SetAttribute("SlotId", e.slot)
		part.Parent = m
		partCount += 1
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(8, 1.4)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 160
		gui.Parent = part
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = e.label
		t.Parent = gui
	end
	label(m, (base * CFrame.new(0, 14, 0)).Position, "Frame standard", "slot envelopes every part must stay inside")
	m.Parent = classFolder
end

for i, st in ipairs(data.stations) do
	local m = Instance.new("Model")
	m.Name = string.format("%02d_%s", i, st.name)
	if st.cockpit then m:SetAttribute("CockpitId", st.cockpit) end
	if st.kit then m:SetAttribute("KitId", st.kit) end
	local base = baseAt(st.x, st.z, st.lift)
	for _, g in ipairs(st.groups) do
		local gm = Instance.new("Model")
		gm.Name = g.slot == "Cockpit" and ("Cockpit - " .. g.name) or (g.slot .. " - " .. g.label .. " - " .. g.name)
		gm:SetAttribute("SlotId", g.slot)
		gm:SetAttribute(g.slot == "Cockpit" and "CockpitId" or "ModuleId", g.id)
		for _, p in ipairs(g.parts) do
			makePart(p, gm, base, g.slot)
		end
		gm.Parent = m
	end
	if st.figure then scaleFigure(m, baseAt(st.x - 13, st.z + 6, 0)) end
	label(m, (baseAt(st.x, st.z, 0) * CFrame.new(0, st.lift > 0 and 26 or 12.5, 0)).Position, st.name, st.sub, 26, 3.6)
	m.Parent = classFolder
end

for _, h in ipairs(data.headers) do
	label(classFolder, ORIGIN + Vector3.new(h.x, h.y + 6, h.z), h.text, h.sub, h.w, 5)
end

classFolder.Parent = root
game:GetService("ChangeHistoryService"):SetWaypoint("VehicleCategoryBlockouts " .. id)
return string.format("%s: %d vehicles, %d parts at %s", id, #data.stations, partCount, tostring(ORIGIN))
