-- Exotic mesh preview: builds the exported pilot cars as in-memory meshes in Studio (Edit mode).
-- Run through execute_luau or the Command Bar with the repo served on localhost:
--   py -3 -m http.server 8793 --bind 127.0.0.1      (from the repo root)
-- Input: scripts/exotic_category/mesh/export/<car>/<SLOT>.json (see export.py).
-- Output: Workspace["Test + WIP Assets"].ExoticMeshTest_WIP, one Model per car, one MeshPart per
-- module and paint channel. The meshes are EditableMesh content: they are NOT saved with the place.
-- AssetService:CreateAssetAsync was "not available yet" on 2026-10-03, so this cannot upload assets.
local Http = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local BASE = "http://127.0.0.1:8793/scripts/exotic_category/mesh/export/"
local SLOTS = { "COCKPIT", "NOSE", "TAIL", "FPOD", "RPOD", "STAB", "BOOST", "WING" }
local LOOK = {
	primary = { Color3.fromRGB(170, 20, 24), Enum.Material.SmoothPlastic, 0.12, 0 },
	secondary = { Color3.fromRGB(22, 22, 26), Enum.Material.SmoothPlastic, 0.08, 0 },
	detail = { Color3.fromRGB(12, 12, 14), Enum.Material.Plastic, 0, 0 },
	glass = { Color3.fromRGB(14, 18, 24), Enum.Material.Glass, 0.2, 0.15 },
	lights = { Color3.fromRGB(255, 250, 235), Enum.Material.Neon, 0, 0 },
	lights_red = { Color3.fromRGB(255, 30, 20), Enum.Material.Neon, 0, 0 },
	neon = { Color3.fromRGB(90, 210, 255), Enum.Material.Neon, 0, 0 },
	thrust = { Color3.fromRGB(255, 130, 30), Enum.Material.Neon, 0, 0 },
}
local PRIMARY = { A = Color3.fromRGB(170, 20, 24), B = Color3.fromRGB(225, 160, 20) }

local wip = assert(workspace:FindFirstChild("Test + WIP Assets"), "WIP folder missing")
local old = wip:FindFirstChild("ExoticMeshTest_WIP")
if old then
	old:Destroy()
end
local cam = workspace.CurrentCamera
local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
if flat.Magnitude < 0.1 then
	flat = Vector3.new(0, 0, -1)
end
local base = cam.CFrame.Position + flat.Unit * 45
local folder = Instance.new("Folder")
folder.Name = "ExoticMeshTest_WIP"
folder:SetAttribute("Note", "Temporary mesh preview. In-memory meshes: not saved with the place.")
folder.Parent = wip

local function build(car, ox)
	local model = Instance.new("Model")
	model.Name = "Car_" .. car
	model.Parent = folder
	local origin = CFrame.new(base + Vector3.new(ox, 3, 0))
	for _, slot in SLOTS do
		local data = Http:JSONDecode(Http:GetAsync(BASE .. car .. "/" .. slot .. ".json?t=" .. os.clock(), true))
		local sub = Instance.new("Model")
		sub.Name = data.module
		sub.Parent = model
		for ch, c in data.channels do
			local v, n, t = c.v, c.n, c.t
			local mn = Vector3.new(math.huge, math.huge, math.huge)
			local mx = -mn
			for i = 1, #v, 3 do
				local p = Vector3.new(v[i], v[i + 1], v[i + 2])
				mn = mn:Min(p)
				mx = mx:Max(p)
			end
			local centre = (mn + mx) / 2
			local em = AssetService:CreateEditableMesh()
			local vid, nid = table.create(#v / 3), table.create(#n / 3)
			for i = 1, #v, 3 do
				vid[(i + 2) / 3] = em:AddVertex(Vector3.new(v[i], v[i + 1], v[i + 2]) - centre)
			end
			for i = 1, #n, 3 do
				nid[(i + 2) / 3] = em:AddNormal(Vector3.new(n[i], n[i + 1], n[i + 2]))
			end
			for i = 1, #t, 6 do
				local f = em:AddTriangle(vid[t[i] + 1], vid[t[i + 1] + 1], vid[t[i + 2] + 1])
				em:SetFaceNormals(f, { nid[t[i + 3] + 1], nid[t[i + 4] + 1], nid[t[i + 5] + 1] })
			end
			local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.Box })
			local look = LOOK[ch]
			mp.Name = ch
			mp.Color = ch == "primary" and PRIMARY[car] or look[1]
			mp.Material = look[2]
			mp.Reflectance = look[3]
			mp.Transparency = look[4]
			mp.Anchored = true
			mp.CanCollide = false
			mp.CastShadow = ch ~= "glass"
			mp.DoubleSided = true
			mp:SetAttribute("PaintChannel", ch)
			mp.CFrame = origin * CFrame.new(centre)
			mp.Parent = sub
		end
	end
	return origin.Position
end

local a = build("A", -9)
local b = build("B", 9)
return Http:JSONEncode({ a = { a.X, a.Y, a.Z }, b = { b.X, b.Y, b.Z } })
