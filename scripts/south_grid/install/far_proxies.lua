-- Builds far LOD5 proxies for Block S9 (shown by LODRuntime at 2450-5000 studs). For each block, keeps the
-- largest building masses (LOD4 Buildings parts by volume) as plain anchored, non-colliding boxes.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local far = game.ReplicatedStorage.Assets.World.FarLOD5Proxies
local S9 = workspace.World.City["Block S9"]
local MAX_PARTS = 24
local report = {}
for _, block in ipairs(S9:GetChildren()) do
	local list = {}
	for _, d in ipairs(block.LOD.LOD4.Buildings:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > 20000 then table.insert(list, { d, v }) end
		end
	end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	local name = block.Name .. "_LOD5"
	local old = far:FindFirstChild(name); if old then old:Destroy() end
	local folder = Instance.new("Folder"); folder.Name = name
	for i = 1, math.min(MAX_PARTS, #list) do
		local src = list[i][1]
		local p = Instance.new("Part"); p.Name = "far"; p.Size = src.Size; p.CFrame = src.CFrame
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
		p.Material = src.Material; p.MaterialVariant = src.MaterialVariant; p.Color = src.Color
		if src:IsA("Part") then p.Shape = src.Shape end
		p.Parent = folder
	end
	folder.Parent = far
	table.insert(report, name .. ": " .. #folder:GetChildren())
end
return table.concat(report, "\n")
