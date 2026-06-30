-- Neo Tokyo Racers - Vehicle Phase AK spawned module colour sync
--
-- Run this in Roblox Studio Command Bar if modules look correct in preview but
-- spawn in default grey/old colours when starting to drive.
--
-- Fix:
-- - When cockpit paint changes Primary/Secondary/Detail, copy that colour onto
--   installed module colour records too, so server-spawned vehicles match the
--   preview.
-- - When per-cockpit defaults are applied after selecting/buying a cockpit,
--   reset existing installed module colours to those cockpit defaults.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK Spawn Module Colour Sync"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function replaceOnce(source, needle, replacement, label)
	local firstStart, firstEnd = string.find(source, needle, 1, true)
	if not firstStart then
		error(label .. " expected exactly 1 match, found 0")
	end
	local secondStart = string.find(source, needle, firstEnd + 1, true)
	if secondStart then
		error(label .. " expected exactly 1 match, found more than 1")
	end
	return string.sub(source, 1, firstStart - 1) .. replacement .. string.sub(source, firstEnd + 1)
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local serverSource = serverScript.Source
if not string.find(serverSource, "NTR_VEHICLE_PHASE_AK_SPAWN_MODULE_COLOUR_SYNC", 1, true) then
	serverSource = replaceOnce(serverSource,
[[	local function V76_applyDefaultCockpitColors(profile)
		profile.CockpitColors = V76_defaultCockpitColorsFor(profile)
	end]],
[[	local function V76_syncInstalledModulePaintFromCockpit(profile, channel)
		if not profile then return end
		profile.ModuleColors = profile.ModuleColors or {}
		local cockpitColors = profile.CockpitColors or {}
		for slotId in pairs(profile.InstalledModules or {}) do
			profile.ModuleColors[slotId] = profile.ModuleColors[slotId] or {}
			local moduleColors = profile.ModuleColors[slotId]
			if channel then
				moduleColors[channel] = cockpitColors[channel]
			else
				moduleColors.Primary = cockpitColors.Primary
				moduleColors.Secondary = cockpitColors.Secondary
				moduleColors.Detail = cockpitColors.Detail
			end
			moduleColors.Neon = moduleColors.Neon or Color3.fromRGB(255, 255, 255)
			moduleColors.ThrustColor = profile.ThrustColor
		end
	end

	local function V76_applyDefaultCockpitColors(profile)
		profile.CockpitColors = V76_defaultCockpitColorsFor(profile)
		-- NTR_VEHICLE_PHASE_AK_SPAWN_MODULE_COLOUR_SYNC
		V76_syncInstalledModulePaintFromCockpit(profile)
	end]],
		"server colour sync helper insertion")

	serverSource = replaceOnce(serverSource,
[[				else profile.CockpitColors[channel] = color; ok, message = true, "Colour updated." end]],
[[				else
					profile.CockpitColors[channel] = color
					if channel == "Primary" or channel == "Secondary" or channel == "Detail" then
						V76_syncInstalledModulePaintFromCockpit(profile, channel)
					end
					ok, message = true, "Colour updated."
				end]],
		"server SetCockpitColor module colour sync")

	serverScript.Source = serverSource
	info("Patched server cockpit paint to sync installed module colours for spawned vehicles.")
else
	info("Server spawned module colour sync already installed.")
end

local clientScript = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local clientSource = clientScript.Source
if not string.find(clientSource, "NTR_VEHICLE_PHASE_AK_PREVIEW_MODULE_COLOUR_SYNC", 1, true) then
	clientSource = replaceOnce(clientSource,
[[		callServer("SetCockpitColor", { Channel = channel, Color = color })
		if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end
		buildPreview()]],
[[		callServer("SetCockpitColor", { Channel = channel, Color = color })
		if State.Profile and State.Profile.CockpitColors then State.Profile.CockpitColors[channel] = color end
		-- NTR_VEHICLE_PHASE_AK_PREVIEW_MODULE_COLOUR_SYNC
		if State.Profile and State.Profile.InstalledModules and State.Profile.ModuleColors and (channel == "Primary" or channel == "Secondary" or channel == "Detail") then
			for slotId in pairs(State.Profile.InstalledModules) do
				State.Profile.ModuleColors[slotId] = State.Profile.ModuleColors[slotId] or {}
				State.Profile.ModuleColors[slotId][channel] = color
	 		end
		end
		buildPreview()]],
		"client cockpit paint preview module colour sync")

	clientScript.Source = clientSource
	info("Patched client cockpit paint preview state to keep module colours in sync.")
else
	info("Client preview module colour sync already installed.")
end

info("Complete. Stop Play and start Play again, then repaint cockpit and spawn the vehicle.")
