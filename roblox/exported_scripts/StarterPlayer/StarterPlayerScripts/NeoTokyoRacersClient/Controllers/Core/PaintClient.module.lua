-- Neo Tokyo Racers paint/channel utility boundary.
-- Phase A module. Mirrors current client paint channel rules.

local PaintClient = {}

PaintClient.ChannelFolders = {
	PRIMARY_ReplaceWithPrimaryMeshes = "Primary",
	SECONDARY_ReplaceWithSecondaryMeshes = "Secondary",
	DETAIL_ReplaceWithDetailMeshes = "Detail",
	NEON_OptionalLights = "Neon",
	THRUST_COLOR_WhiteByDefault = "ThrustColor",
}

function PaintClient.ResolvePaintChannel(part)
	local current = part
	while current do
		local folderChannel = PaintClient.ChannelFolders[current.Name]
		if folderChannel then
			return folderChannel
		end
		current = current.Parent
	end

	current = part
	while current do
		local attr = current:GetAttribute("PaintChannel")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		current = current.Parent
	end

	current = part
	while current do
		local lower = string.lower(current.Name)
		if string.find(lower, "thrust_color", 1, true) then return "ThrustColor" end
		if string.find(lower, "primary", 1, true) then return "Primary" end
		if string.find(lower, "secondary", 1, true) then return "Secondary" end
		if string.find(lower, "detail", 1, true) then return "Detail" end
		if string.find(lower, "neon", 1, true) then return "Neon" end
		current = current.Parent
	end

	return nil
end

function PaintClient.IsChannelMatch(part, channel)
	return PaintClient.ResolvePaintChannel(part) == channel
end

function PaintClient.PathHas(object, text)
	text = string.lower(text)
	local current = object
	while current do
		if string.find(string.lower(current.Name), text, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

function PaintClient.ModuleColors(profile, slotId)
	profile = profile or {}
	local cockpitColors = profile.CockpitColors or {}
	local moduleSet = profile.ModuleColors and profile.ModuleColors[slotId] or {}
	return {
		Primary = moduleSet.Primary or cockpitColors.Primary or Color3.fromRGB(18, 202, 224),
		Secondary = moduleSet.Secondary or cockpitColors.Secondary or Color3.fromRGB(252, 250, 255),
		Detail = moduleSet.Detail or cockpitColors.Detail or Color3.fromRGB(38, 47, 55),
		Neon = moduleSet.Neon or Color3.fromRGB(255, 255, 255),
		ThrustColor = profile.ThrustColor or moduleSet.ThrustColor or Color3.fromRGB(255, 255, 255),
	}
end

function PaintClient.ApplyColors(model, colors, neonVisible, options)
	colors = colors or {}
	options = options or {}

	local profile = options.Profile or {}
	local frontLight = colors.FrontLights or Color3.fromRGB(252, 250, 255)
	local rearLight = colors.RearLights or Color3.fromRGB(255, 116, 116)
	local neonColor = colors.Neon or Color3.fromRGB(255, 255, 255)
	local thrustColor = colors.ThrustColor or profile.ThrustColor or Color3.fromRGB(255, 255, 255)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("TemplateRole") == "FixedSlotMount" then
				part.Transparency = 1
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			elseif PaintClient.IsChannelMatch(part, "ThrustColor") then
				part.Color = thrustColor
				part.Material = Enum.Material.Neon
				part.Transparency = 0
			elseif PaintClient.IsChannelMatch(part, "Neon") then
				local lightColor = neonColor
				if PaintClient.PathHas(part, "cockpit") then
					if PaintClient.PathHas(part, "front") then
						lightColor = frontLight
					elseif PaintClient.PathHas(part, "rear") or PaintClient.PathHas(part, "back") then
						lightColor = rearLight
					end
				end
				part.Color = lightColor
				part.Material = Enum.Material.Neon
				part.Transparency = neonVisible and 0 or 1
			elseif PaintClient.IsChannelMatch(part, "Primary") then
				part.Color = colors.Primary or part.Color
			elseif PaintClient.IsChannelMatch(part, "Secondary") then
				part.Color = colors.Secondary or part.Color
			elseif PaintClient.IsChannelMatch(part, "Detail") then
				part.Color = colors.Detail or part.Color
			end

			if part:GetAttribute("TemplateRole") ~= "CockpitSpotLightLens" then
				part.Anchored = true
			end
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	for _, light in ipairs(model:GetDescendants()) do
		if light:IsA("SpotLight") then
			local channel = light:GetAttribute("LightChannel")
			if light:GetAttribute("NTRCockpitLightSystem") == "PhaseAE_RootOnly" then
				if channel == "FrontLights" then
					light.Color = frontLight
				elseif channel == "RearLights" then
					light.Color = rearLight
				end
				light.Shadows = false
			end
		end
	end
end

return PaintClient
