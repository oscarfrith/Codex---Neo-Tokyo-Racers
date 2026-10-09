-- Command Bar / execute_luau (Edit). Adds the PulseSunset01 loading artwork (Grid3x2, uploaded 2026-10-09) to
-- ReplicatedStorage.Config.UI.LoadingSystem.Artworks, makes it the only enabled artwork and the default.
-- Idempotent. To go back: set NeoTokyoStreet01@Enabled = true, PulseSunset01@Enabled = false and
-- LoadingSystem@DefaultArtworkId = "NeoTokyoStreet01".
assert(game.PlaceId == 93959280828322, "wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local system = game.ReplicatedStorage.Config.UI.LoadingSystem
local artworks = system.Artworks
local old = artworks:FindFirstChild("NeoTokyoStreet01")
assert(old and old:GetAttribute("Layout") == "Grid3x2", "NeoTokyoStreet01 is not as expected")
local TILES = {
	R1C1 = "rbxassetid://98078115872444", R1C2 = "rbxassetid://107069420770225", R1C3 = "rbxassetid://86155062738808",
	R2C1 = "rbxassetid://84185869986030", R2C2 = "rbxassetid://135255712114951", R2C3 = "rbxassetid://137420408722691",
}
local art = artworks:FindFirstChild("PulseSunset01")
if not art then
	art = Instance.new("Folder")
	art.Name = "PulseSunset01"
end
for key, value in {
	ArtworkId = "PulseSunset01", AspectRatio = 16 / 9, Columns = 3, Rows = 2, CompositeResolution = "3072x1728",
	Destinations = "*", Enabled = true, FocalPointX = 0.5, FocalPointY = 0.5,
	ImageAssetId = "rbxassetid://134802359668816", Layout = "Grid3x2", MotionPreset = "SlowPanRight",
	StartScreenEligible = true, Weight = 1,
} do art:SetAttribute(key, value) end
local tiles = art:FindFirstChild("Tiles") or Instance.new("Folder")
tiles.Name = "Tiles"
tiles:SetAttribute("SchemaVersion", 1)
for name, id in TILES do
	local tile = tiles:FindFirstChild(name) or Instance.new("Folder")
	tile.Name = name
	tile:SetAttribute("Row", tonumber(name:sub(2, 2)))
	tile:SetAttribute("Column", tonumber(name:sub(4, 4)))
	tile:SetAttribute("ImageAssetId", id)
	tile.Parent = tiles
end
tiles.Parent = art
art.Parent = artworks
old:SetAttribute("Enabled", false)
system:SetAttribute("DefaultArtworkId", "PulseSunset01")
return "PulseSunset01 installed; tiles=" .. #tiles:GetChildren()
