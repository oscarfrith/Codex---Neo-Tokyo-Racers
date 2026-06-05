-- Neo Tokyo Racers Live System Registry
-- Added by Phase 2 architecture setup.
--
-- This module describes the current live systems without moving them.
-- It is a bridge for future targeted migrations.

local Registry = {}

Registry.Version = "Phase2_2026_05_28"
Registry.Status = "Bridge registry. Live systems still run from legacy HOVER_RACING_V2 paths."

Registry.Systems = {
	VehicleGarageCustomisation = {
		status = "LiveLegacy",
		description = "Dealership, garage, customisation, spawn, economy/action handling.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT",
			"ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V2_Client",
			"Workspace.HOVER_RACING_V2_WORLD",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage",
			"ServerScriptService.NeoTokyoRacers.Services",
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
		},
		safetyNote = "Do not rewrite the whole server/client action layer in one pass.",
	},

	Driving = {
		status = "LiveLegacyWithConfirmedV47Controller",
		description = "Hover driving, mobile controls, camera assist, boost delay, low-speed wobble.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.DrivingControllerV47",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Controllers.MobileDriveInputState",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V67_MobileDriveControls",
			"StarterPlayer.StarterPlayerScripts.HOVER_RACING_V71_MobilePcHudSuppressor",
		},
		targetRoots = {
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Vehicle",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Input",
		},
		safetyNote = "Keep V47-style driving feel unless the user asks for a driving redesign.",
	},

	VFX = {
		status = "LiveLegacyWithCachedRuntime",
		description = "Engine, boost, stabiliser, hover dust, thrust colour, optional neon runtime.",
		livePaths = {
			"ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.VFX.VehicleVFXController",
			"ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES.Visuals.CachedThrustVisualRuntime",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Assets.VFX",
			"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.VFX",
		},
		safetyNote = "Past issues included neon/thrust flicker and unparented weld leaks. Migrate carefully.",
	},

	WorldLOD = {
		status = "LiveLegacy",
		description = "Generated city blocks, FarLOD5, and distance-based LOD client script.",
		livePaths = {
			"Workspace.GeneratedCityBlocks",
			"ReplicatedStorage.FarLOD5",
			"StarterPlayer.StarterPlayerScripts.LOD System",
		},
		targetRoots = {
			"Workspace.NeoTokyoRacersWorld.City",
			"ReplicatedStorage.NeoTokyoRacers.Assets.World",
			"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers",
		},
		safetyNote = "Do not move GeneratedCityBlocks or FarLOD5 until the LOD script reads through a resolver.",
	},

	Lighting = {
		status = "LiveLegacy",
		description = "Lighting presets, sky presets, lighting controller, and temporary preview script.",
		livePaths = {
			"ReplicatedStorage.Shared.LightingPresets",
			"ReplicatedStorage.Shared.SkyPresets",
			"ServerScriptService.Lighting.LightingController",
			"StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview",
		},
		targetRoots = {
			"ReplicatedStorage.NeoTokyoRacers.Shared.Config.World.Lighting",
			"ServerScriptService.NeoTokyoRacers.Services",
		},
		safetyNote = "Night sky handling was a known issue. Fix sky swapping separately from hierarchy migration.",
	},

	TrafficLights = {
		status = "LiveLegacy",
		description = "Central traffic light material cycle controller.",
		livePaths = {
			"ServerScriptService.Traffic Lights",
		},
		targetRoots = {
			"ServerScriptService.NeoTokyoRacers.Services",
		},
		safetyNote = "Keep one central controller; avoid per-light scripts.",
	},
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

function Registry.ResolvePath(path)
	local parts = splitPath(path)
	local current = services[parts[1]]
	if not current then
		return nil
	end

	for index = 2, #parts do
		current = current:FindFirstChild(parts[index])
		if not current then
			return nil
		end
	end

	return current
end

function Registry.GetSystem(systemName)
	return Registry.Systems[systemName]
end

function Registry.ListSystems()
	local names = {}
	for name in pairs(Registry.Systems) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Registry.ResolveSystem(systemName)
	local systemInfo = Registry.Systems[systemName]
	if not systemInfo then
		return nil
	end

	local resolved = {}
	for _, path in ipairs(systemInfo.livePaths or {}) do
		resolved[path] = Registry.ResolvePath(path)
	end

	return resolved
end

return Registry
