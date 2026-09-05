local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WORLD_NAME = "World"

local PathResolver = {}

local function root()
	return game:GetService("ReplicatedStorage")
end

local function world()
	return game:GetService("Workspace"):WaitForChild("World")
end

local function waitPath(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current:WaitForChild(name)
	end
	return current
end

function PathResolver.Root()
	return root()
end

function PathResolver.Assets()
	return waitPath(root(), "Assets")
end

function PathResolver.VehicleCategories()
	return waitPath(root(), "Assets", "Vehicles", "Categories")
end

function PathResolver.VehicleVFXTemplates()
	return waitPath(root(), "Assets", "VFX", "VehicleTemplates")
end

function PathResolver.WorldAssets()
	return waitPath(root(), "Assets", "World")
end

function PathResolver.GarageRemotes()
	return waitPath(root(), "Remotes", "Garage")
end

function PathResolver.RuntimeConfig()
	return waitPath(root(), "Config")
end

function PathResolver.EditableConfig()
	return waitPath(root(), "Config", "Vehicles", "Authoring")
end

function PathResolver.UITheme()
	return waitPath(root(), "Config", "UI", "Theme")
end

function PathResolver.PaintPresets()
	return waitPath(root(), "Config", "UI", "PaintPresets")
end

function PathResolver.World()
	return world()
end

function PathResolver.Runtime()
	return waitPath(world(), "Runtime")
end

function PathResolver.RuntimeVehicles()
	return waitPath(world(), "Runtime", "PlayerVehicles")
end

function PathResolver.GaragePreviewPad()
	return waitPath(world(), "Garages", "GaragePreviewPad")
end

function PathResolver.VehicleSpawnPoint()
	return waitPath(world(), "SpawnPoints", "VehicleSpawnPoint")
end

return PathResolver
