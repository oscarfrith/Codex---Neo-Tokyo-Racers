-- Exotic mesh pilot: assemble the uploaded model asset into two cars in the backup place (Edit mode).
-- Route (no manual steps):
--   1. Blender scene built by cars.build_all(), then export.to_json()            (export.py)
--   2. blender --background --factory-startup --python fbx_export.py             (headless)
--   3. py -3 upload_asset.py export/ExoticPilot.fbx "<name>" <user id>           (prints the asset id)
--   4. this script through execute_luau, with ASSET set to that id
-- The asset holds one MeshPart per module and paint channel, named like A_NOSE_STD__primary.
-- Observed 2026-10-03: the FBX arrives at 1:1 stud scale but turned 180 degrees about Y.
-- Output: Workspace["Test + WIP Assets"].ExoticMeshPilot_WIP. Not garage content.
local ASSET = 131339456333405
local Http = game:GetService("HttpService")
local wip = assert(workspace:FindFirstChild("Test + WIP Assets"), "WIP folder missing")
for _, name in { "ExoticMeshTest_WIP", "ExoticMeshPilot_WIP" } do
	local old = wip:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
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
local ORIGIN = { A = CFrame.new(7443, 2635.35, -158.5), B = CFrame.new(7461, 2635.35, -158.5) }
local FILE_OFFSET = { A = 0, B = 20 }
local TURN = CFrame.Angles(0, math.pi, 0)

local folder = Instance.new("Folder")
folder.Name = "ExoticMeshPilot_WIP"
folder:SetAttribute("SourceAssetId", ASSET)
folder:SetAttribute("Note", "Exotic pilot, Standard trim, uploaded meshes. Built by scripts/exotic_category/mesh. Not garage content yet.")
folder.Parent = wip
local cars, counts = {}, {}
local root = game:GetObjects("rbxassetid://" .. ASSET)[1]
for _, d in root:GetDescendants() do
	if d:IsA("MeshPart") then
		local key, ch = string.match(d.Name, "^(.-)__(.+)$")
		local car, slot = string.match(key, "^(%a)_(%a+)_STD$")
		assert(car and slot and LOOK[ch], "unexpected part name " .. d.Name)
		local carModel = cars[car]
		if not carModel then
			carModel = Instance.new("Model")
			carModel.Name = "Car_" .. car
			carModel.Parent = folder
			cars[car] = carModel
		end
		local mod = carModel:FindFirstChild(key)
		if not mod then
			mod = Instance.new("Model")
			mod.Name = key
			mod:SetAttribute("Slot", slot)
			mod.Parent = carModel
		end
		local part = d:Clone()
		local rel = TURN * d.CFrame -- file space to game root space
		rel = rel - Vector3.new(FILE_OFFSET[car], 0, 0) -- the round car sits 20 studs along X in the file
		local look = LOOK[ch]
		part.Name = ch
		part.Color = ch == "primary" and PRIMARY[car] or look[1]
		part.Material = look[2]
		part.Reflectance = look[3]
		part.Transparency = look[4]
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = ch ~= "glass"
		part.DoubleSided = true
		part:SetAttribute("PaintChannel", ch)
		part.CFrame = ORIGIN[car] * rel
		part.Parent = mod
		counts[car] = (counts[car] or 0) + 1
	end
end
root:Destroy()
return Http:JSONEncode({ parts = counts })
