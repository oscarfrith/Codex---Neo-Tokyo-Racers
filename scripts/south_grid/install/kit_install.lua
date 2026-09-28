-- After Oscar imports kit/out/SouthGridKit.fbx into Workspace: finds the imported MeshParts by catalog piece name
-- (tolerating importer suffixes like ".001"), moves them into ReplicatedStorage.Assets.World.SouthGridKit and sets
-- storage-safe properties. Then re-run assemble.lua to swap every box proxy for the real mesh.
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local Http = game:GetService("HttpService")
local catalog = Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8773/common/kit_catalog.json", true)).items
local wanted = {}
for _, item in pairs(catalog) do for _, pc in ipairs(item.pieces) do wanted[pc.name] = true end end
local worldAssets = game.ReplicatedStorage.Assets.World
local kit = worldAssets:FindFirstChild("SouthGridKit") or Instance.new("Folder")
kit.Name = "SouthGridKit"; kit.Parent = worldAssets
local moved, wrappers = {}, {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("MeshPart") then
		local base = d.Name:gsub("%.%d+$", "")
		if wanted[base] and not kit:FindFirstChild(base) and not d:FindFirstAncestor("World") then
			local wrapper = d:FindFirstAncestorWhichIsA("Model")
			if wrapper then wrappers[wrapper] = true end
			d.Name = base; d.Anchored = true; d.CanCollide = false; d.CanTouch = false; d.CastShadow = true
			pcall(function() d.CollisionFidelity = Enum.CollisionFidelity.Box end)
			pcall(function() d.RenderFidelity = Enum.RenderFidelity.Automatic end)
			d.Parent = kit; table.insert(moved, base)
		end
	end
end
for w in pairs(wrappers) do if #w:GetDescendants() == 0 or not w:FindFirstChildWhichIsA("BasePart", true) then w:Destroy() end end
local missing = {}
for name in pairs(wanted) do if not kit:FindFirstChild(name) then table.insert(missing, name) end end
return ("moved %d pieces; kit now %d/%d; missing: %s"):format(#moved, #kit:GetChildren(), (function() local n = 0 for _ in pairs(wanted) do n += 1 end return n end)(), table.concat(missing, ", "))
