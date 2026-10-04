-- Exotic flake paint: creates or updates MaterialService.ExoticFlakePaint in Space Racers v3.
-- Run in Studio Edit mode (Command Bar or execute_luau). Safe to run again: it updates the one instance.
-- The Stage B content installer only writes the name "ExoticFlakePaint" on primary paint parts
-- (stage_b/data/colours.json paintVariant); this script owns the material itself. If the material is
-- missing, those parts fall back to plain SmoothPlastic.
-- StudsPerTile is left as it is when the material already exists (Oscar tunes it in Studio).
-- Texture source: scripts/exotic_category/mesh/paint/make_flake_paint.py.

local PLACE_ID = 93959280828322
local NAME = "ExoticFlakePaint"
local MAPS = {
	ColorMap = "rbxassetid://70984984863269",
	NormalMap = "rbxassetid://127079744275435",
	RoughnessMap = "rbxassetid://118216519288575",
	MetalnessMap = "rbxassetid://80090143700771",
}

assert(game.PlaceId == PLACE_ID, "Exotic flake paint: wrong place " .. tostring(game.PlaceId))
local MaterialService = game:GetService("MaterialService")
local variant = MaterialService:FindFirstChild(NAME)
local created = false
if variant then
	assert(variant:IsA("MaterialVariant"), "Exotic flake paint: MaterialService." .. NAME .. " is not a MaterialVariant")
else
	variant = Instance.new("MaterialVariant")
	variant.Name = NAME
	variant.StudsPerTile = 1
	created = true
end
variant.BaseMaterial = Enum.Material.SmoothPlastic
for property, value in pairs(MAPS) do
	variant[property] = value
end
variant.Parent = MaterialService
return string.format("%s %s: StudsPerTile=%s", created and "created" or "updated", variant:GetFullName(), tostring(variant.StudsPerTile))
