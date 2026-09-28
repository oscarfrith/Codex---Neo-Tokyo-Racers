-- South Grid assembler (Edit mode, integrator only). Builds JSON specs served from scripts/south_grid over
-- http://127.0.0.1:8773 into LOD-structured city blocks under Workspace.World.City["Block S9"].
-- Re-running a spec replaces only the instances tagged with that spec id. Kit pieces use MeshParts from
-- ReplicatedStorage.Assets.World.SouthGridKit when present, otherwise box proxies tagged SGKitPiece for a later swap.
-- CONFIG is prepended by the caller: local CONFIG = { specs = {"buildings/A/P01.json", ...} }
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local Http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local BASE = "http://127.0.0.1:8773/"
local function get(path) return Http:JSONDecode(Http:GetAsync(BASE .. path:gsub(" ", "%%20"), true)) end
local catalog = get("common/kit_catalog.json").items
local props = get("common/props_catalog.json")
local parcels = get("common/parcels.json")
local kitFolder = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("World") and RS.Assets.World:FindFirstChild("SouthGridKit")
local city = workspace.World.City
local S9 = city:FindFirstChild("Block S9") or Instance.new("Folder")
S9.Name = "Block S9"; S9.Parent = city

local CATS = { "Buildings", "Props", "Paths", "Roads", "Foliage" }
local function ensureBlock(name, centre)
	local m = S9:FindFirstChild(name)
	if not m then
		m = Instance.new("Model"); m.Name = name
		local lod = Instance.new("Folder"); lod.Name = "LOD"; lod.Parent = m
		for i = 1, 4 do
			local f = Instance.new("Folder"); f.Name = "LOD" .. i; f.Parent = lod
			for _, c in ipairs(CATS) do local cf = Instance.new("Folder"); cf.Name = c; cf.Parent = f end
		end
		local meta = Instance.new("Folder"); meta.Name = "_Metadata"; meta.Parent = m
		for _, n in ipairs({ "CenterPart", "Root" }) do
			local p = Instance.new("Part"); p.Name = n; p.Size = Vector3.new(1, 1, 1); p.Anchored = true; p.CanCollide = false
			p.CanTouch = false; p.CanQuery = false; p.Transparency = 1; p.CastShadow = false; p.Position = centre
			p.Parent = n == "CenterPart" and meta or m
		end
		m.Parent = S9
	end
	return m
end
local blockOf, centreOf = {}, {}
for _, p in ipairs(parcels) do
	blockOf[p.id] = p.block
	centreOf[p.block] = Vector3.new((p.parcel.x0 + p.parcel.x1) / 2, p.groundY, (p.parcel.z0 + p.parcel.z1) / 2)
end
local function nearestBlock(pos)
	local best, bd = nil, math.huge
	for name, c in pairs(centreOf) do
		local d = (Vector3.new(c.X, 0, c.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bd then best, bd = name, d end
	end
	return best
end
local function cf(e) return CFrame.new(e.pos[1], e.pos[2], e.pos[3]) * CFrame.fromOrientation(math.rad(e.rot[1]), math.rad(e.rot[2]), math.rad(e.rot[3])) end
local function color(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local function style(p, mat, var, col, collide, shadow)
	p.Anchored = true; p.CanCollide = collide ~= false; p.CanTouch = false; p.CastShadow = shadow ~= false
	p.Material = Enum.Material[mat]; p.MaterialVariant = var or ""; p.Color = color(col)
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
end
local function container(root, path)
	local node = root
	for seg in string.gmatch(path, "[^/]+") do
		local nx = node:FindFirstChild(seg)
		if not nx then nx = Instance.new("Model"); nx.Name = seg; nx.Parent = node end
		node = nx
	end
	return node
end
local function makePart(e)
	local p
	if e.shape == "Wedge" then p = Instance.new("WedgePart")
	elseif e.shape == "CornerWedge" then p = Instance.new("CornerWedgePart")
	else p = Instance.new("Part"); p.Shape = Enum.PartType[e.shape] end
	p.Size = Vector3.new(e.size[1], e.size[2], e.size[3]); p.CFrame = cf(e); p.Name = e.name
	style(p, e.mat, e.var, e.color, e.collide, e.shadow); p.Transparency = e.transparency or 0
	return p
end
local function makeKit(e)
	local item = catalog[e.item]; local s = e.scale or 1
	local model = Instance.new("Model"); model.Name = e.name
	local base = cf(e)
	for k, pc in ipairs(item.pieces) do
		local src = kitFolder and kitFolder:FindFirstChild(pc.name)
		local p = src and src:Clone() or Instance.new("Part")
		p.Name = pc.name
		p.Size = Vector3.new(pc.size[1] * s, pc.size[2] * s, pc.size[3] * s)
		p.CFrame = base * CFrame.new(pc.offset[1] * s, pc.offset[2] * s, pc.offset[3] * s)
		local col = (k == 1 and e.color) or pc.color
		style(p, pc.mat, pc.var, col, e.collide == true, true)
		p.Transparency = pc.transparency or 0
		if not src then p:SetAttribute("SGKitPiece", pc.name) end
		p.Parent = model
	end
	return model
end
local function resolve(path)
	local node = game
	for seg in string.gmatch(path, "[^%.]+") do
		if node == game and seg == "Workspace" then node = workspace else node = node and node:FindFirstChild(seg) end
	end
	return node
end
local function makeClone(e)
	local src = resolve(props[e.key].path)
	if not src then warn("missing prop " .. e.key); return nil end
	local c = src:Clone(); c.Name = e.name
	if c:IsA("Model") then c:PivotTo(cf(e)) else c.CFrame = cf(e) end
	return c
end

local report = {}
for _, file in ipairs(CONFIG.specs) do
	local doc = get(file)
	-- remove previous build of this spec
	for _, d in ipairs(S9:GetDescendants()) do
		if d:GetAttribute("SGSpec") == doc.id then d:Destroy() end
	end
	local roots = {}
	local n = 0
	for _, e in ipairs(doc.elements) do
		local pos = Vector3.new(e.pos[1], e.pos[2], e.pos[3])
		local blockName = (doc.kind == "building" and blockOf[doc.id]) or e.block or nearestBlock(pos)
		local block = ensureBlock(blockName, centreOf[blockName])
		local cat = e.cat or (doc.kind == "building" and "Buildings")
			or (e.t == "clone" and (e.key:lower():find("tree") or e.key:lower():find("bush") or e.key:lower():find("bamboo")) and "Foliage")
			or (e.layer == "LOD3" and "Paths") or "Props"
		local key = blockName .. "|" .. e.layer .. "|" .. cat
		local root = roots[key]
		if not root then
			root = Instance.new("Model"); root.Name = (doc.title ~= "" and doc.title or doc.id)
			root:SetAttribute("SGSpec", doc.id); root.Parent = block.LOD[e.layer][cat]; roots[key] = root
		end
		-- Graffiti bands tile every 40 studs: on tall upright faces keep one band at the bottom, weathered concrete above.
		if e.t == "part" and e.shape == "Block" and string.sub(e.var or "", 1, 11) == "SG Graffiti" and e.size[2] > 44
			and math.abs(e.rot[1]) < 1 and math.abs(e.rot[3]) < 1 then
			local lowH = 40
			local upper = table.clone(e); upper.size = { e.size[1], e.size[2] - lowH, e.size[3] }
			upper.pos = { e.pos[1], e.pos[2] + lowH / 2, e.pos[3] }; upper.var = "SG Weathered Concrete"
			local lower = table.clone(e); lower.size = { e.size[1], lowH, e.size[3] }
			lower.pos = { e.pos[1], e.pos[2] - e.size[2] / 2 + lowH / 2, e.pos[3] }
			local parent = (e.group ~= "" and container(root, e.group)) or root
			makePart(upper).Parent = parent
			e = lower
		end
		local inst = (e.t == "part" and makePart(e)) or (e.t == "kit" and makeKit(e)) or (e.t == "clone" and makeClone(e))
		if inst then inst.Parent = (e.group ~= "" and container(root, e.group)) or root; n += 1 end
		if n % 400 == 0 then task.wait() end
	end
	table.insert(report, doc.id .. ": " .. n .. " elements")
end
return table.concat(report, "\n") .. (kitFolder and "" or "\n(kit proxies: SouthGridKit not imported yet)")
