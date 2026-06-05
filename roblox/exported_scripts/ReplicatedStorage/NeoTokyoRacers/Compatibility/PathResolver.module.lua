-- Neo Tokyo Racers Compatibility Path Resolver
-- Added by Phase 1 architecture setup.
--
-- The current game still runs from the legacy HOVER_RACING_V2 paths.
-- New code can ask for logical names here, then later the mappings can
-- be changed one system at a time without mass-rewriting every script.

local PathResolver = {}

PathResolver.Version = "Phase1_2026_05_28"
PathResolver.LiveSystemsStillUseLegacyPaths = true

PathResolver.PathStrings = {
	NTRRoot = "ReplicatedStorage.NeoTokyoRacers",
	NTRShared = "ReplicatedStorage.NeoTokyoRacers.Shared",
	NTRConfig = "ReplicatedStorage.NeoTokyoRacers.Shared.Config",
	NTRRemotes = "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes",
	NTRModules = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules",
	NTRAssets = "ReplicatedStorage.NeoTokyoRacers.Assets",
	NTRWorld = "Workspace.NeoTokyoRacersWorld",

	LegacyKit = "ReplicatedStorage.HOVER_RACING_V2_KIT",
	LegacyWorld = "Workspace.HOVER_RACING_V2_WORLD",
	VehicleCategories = "ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES",
	GarageRemotes = "ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename",
	ClientModules = "ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES",
	SharedModules = "ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES",
	VFXTemplates = "ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES",
	EditableConfig = "ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG",
	GameBalance = "ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST",
	UITheme = "ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename",
	PaintPresets = "ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere",

	VehicleRuntime = "Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime",
	GaragePreviewPad = "Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad",
	VehicleSpawnPoint = "Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint",

	GeneratedCityBlocks = "Workspace.GeneratedCityBlocks",
	FarLOD5 = "ReplicatedStorage.FarLOD5",
	LightingPresets = "ReplicatedStorage.Shared.LightingPresets",
	SkyPresets = "ReplicatedStorage.Shared.SkyPresets",
}

local services = {
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = game:GetService("StarterPlayer"),
	StarterGui = game:GetService("StarterGui"),
	Workspace = game:GetService("Workspace"),
	Lighting = game:GetService("Lighting"),
}

local function splitPath(path)
	local parts = {}
	for part in string.gmatch(path, "[^%.]+") do
		table.insert(parts, part)
	end
	return parts
end

local function resolvePath(path, shouldWait, timeout)
	if typeof(path) ~= "string" or path == "" then
		return nil
	end

	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		local name = parts[index]
		if shouldWait then
			current = current:WaitForChild(name, timeout or 5)
		else
			current = current:FindFirstChild(name)
		end

		if not current then
			return nil
		end
	end

	return current
end

function PathResolver.GetPath(name)
	return PathResolver.PathStrings[name]
end

function PathResolver.SetPath(name, path)
	assert(typeof(name) == "string", "PathResolver.SetPath name must be a string")
	assert(typeof(path) == "string", "PathResolver.SetPath path must be a string")
	PathResolver.PathStrings[name] = path
end

function PathResolver.Resolve(name)
	return resolvePath(PathResolver.PathStrings[name], false)
end

function PathResolver.WaitFor(name, timeout)
	return resolvePath(PathResolver.PathStrings[name], true, timeout)
end

function PathResolver.ResolveRequired(name)
	local instance = PathResolver.Resolve(name)
	if not instance then
		error(("PathResolver could not resolve '%s' at '%s'"):format(tostring(name), tostring(PathResolver.PathStrings[name])), 2)
	end
	return instance
end

function PathResolver.List()
	local copy = {}
	for name, path in pairs(PathResolver.PathStrings) do
		copy[name] = path
	end
	return copy
end

return PathResolver
