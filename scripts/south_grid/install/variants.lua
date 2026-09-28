-- Creates/updates the SG MaterialVariants in MaterialService from textures/variants.json plus uploaded asset ids.
-- CONFIG is prepended by the caller: local CONFIG = { ids = { ["sg_windows_blocks_color.png"] = "rbxassetid://..", ... } }
assert(not game:GetService("RunService"):IsRunning(), "Run in Edit mode")
local Http = game:GetService("HttpService")
local MS = game:GetService("MaterialService")
local list = Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8773/textures/variants.json", true))
local out = {}
CONFIG = CONFIG or { ids = Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8773/textures/asset_ids.json", true)) }
for _, v in ipairs(list) do
	local slug = string.lower(v.name):gsub("%s+", "_")
	local mv = MS:FindFirstChild(v.name) or Instance.new("MaterialVariant")
	mv.Name = v.name
	mv.BaseMaterial = Enum.Material[v.base]
	mv.StudsPerTile = v.studsPerTile
	mv.ColorMap = CONFIG.ids[slug .. "_color.png"] or ""
	mv.NormalMap = CONFIG.ids[slug .. "_normal.png"] or ""
	mv.RoughnessMap = CONFIG.ids[slug .. "_roughness.png"] or ""
	mv.MetalnessMap = CONFIG.ids[slug .. "_metalness.png"] or ""
	mv.Parent = MS
	table.insert(out, v.name .. (mv.ColorMap ~= "" and " ok" or " (no colour map)"))
end
return table.concat(out, "\n")
