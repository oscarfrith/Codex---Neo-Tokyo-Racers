-- Neo Tokyo Racers - Vehicle Phase AK per-cockpit default colours
--
-- Run this in Roblox Studio Command Bar.
--
-- Adds editable colour attributes to each Bruiser cockpit model:
--   DefaultPrimaryColor
--   DefaultSecondaryColor
--   DefaultDetailColor
--   DefaultNeonColor
--   DefaultFrontLightsColor
--   DefaultRearLightsColor
--
-- The active garage server then reads those cockpit attributes when a cockpit is
-- selected/bought, so the paint step starts from that cockpit's defaults.
--
-- It also sets the cockpit paint camera to the same angle/distance as Engine1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Vehicle Phase AK Per-Cockpit Default Colours"

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

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local bruiser = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories"):WaitForChild("BRUISER")
local cockpitRoot = bruiser:FindFirstChild("COCKPITS_ReplaceAssetsHere") or bruiser:FindFirstChild("COCKPITS") or bruiser:FindFirstChild("Cockpits")
assert(cockpitRoot, "Could not find Bruiser cockpit root")

local palettes = {
	{
		Primary = Color3.fromRGB(0, 205, 230),
		Secondary = Color3.fromRGB(235, 247, 204),
		Detail = Color3.fromRGB(38, 44, 50),
	},
	{
		Primary = Color3.fromRGB(225, 56, 70),
		Secondary = Color3.fromRGB(38, 44, 50),
		Detail = Color3.fromRGB(235, 247, 204),
	},
	{
		Primary = Color3.fromRGB(172, 255, 197),
		Secondary = Color3.fromRGB(24, 35, 42),
		Detail = Color3.fromRGB(255, 187, 45),
	},
	{
		Primary = Color3.fromRGB(160, 90, 255),
		Secondary = Color3.fromRGB(252, 250, 255),
		Detail = Color3.fromRGB(38, 44, 50),
	},
	{
		Primary = Color3.fromRGB(255, 187, 45),
		Secondary = Color3.fromRGB(18, 27, 31),
		Detail = Color3.fromRGB(0, 205, 230),
	},
}

local cockpits = {}
for _, item in ipairs(cockpitRoot:GetDescendants()) do
	if item:IsA("Model") and item:GetAttribute("CockpitId") then
		table.insert(cockpits, item)
	end
end
table.sort(cockpits, function(a, b)
	return tostring(a:GetAttribute("CockpitId")) < tostring(b:GetAttribute("CockpitId"))
end)

for index, cockpit in ipairs(cockpits) do
	local palette = palettes[((index - 1) % #palettes) + 1]
	if cockpit:GetAttribute("DefaultPrimaryColor") == nil then
		cockpit:SetAttribute("DefaultPrimaryColor", palette.Primary)
	end
	if cockpit:GetAttribute("DefaultSecondaryColor") == nil then
		cockpit:SetAttribute("DefaultSecondaryColor", palette.Secondary)
	end
	if cockpit:GetAttribute("DefaultDetailColor") == nil then
		cockpit:SetAttribute("DefaultDetailColor", palette.Detail)
	end
	if cockpit:GetAttribute("DefaultNeonColor") == nil then
		cockpit:SetAttribute("DefaultNeonColor", Color3.fromRGB(255, 255, 255))
	end
	if cockpit:GetAttribute("DefaultFrontLightsColor") == nil then
		cockpit:SetAttribute("DefaultFrontLightsColor", Color3.fromRGB(252, 250, 255))
	end
	if cockpit:GetAttribute("DefaultRearLightsColor") == nil then
		cockpit:SetAttribute("DefaultRearLightsColor", Color3.fromRGB(255, 116, 116))
	end
	cockpit:SetAttribute("DefaultColoursEditable", true)
	cockpit:SetAttribute("DefaultColoursNote", "Edit these Default*Color attributes to change this cockpit's starting paint colours.")
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

local serverSource = serverScript.Source
if not string.find(serverSource, "NTR_VEHICLE_PHASE_AK_PER_COCKPIT_COLOURS", 1, true) then
	serverSource = replaceOnce(serverSource,
[[	local function V56_setLeaderstats(player, profile)]],
[[	-- NTR_VEHICLE_PHASE_AK_PER_COCKPIT_COLOURS
	local function V76_findCockpitForDefaultColours(categoryId, cockpitId)
		for _, category in ipairs(V56_categoriesRoot:GetChildren()) do
			local categoryMatches = category:GetAttribute("CategoryId") == categoryId
				or category.Name == categoryId
				or string.lower(category.Name) == string.lower(tostring(categoryId))
			if categoryMatches then
				local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
				for _, item in ipairs((root or category):GetDescendants()) do
					if item:IsA("Model") and item:GetAttribute("CockpitId") == cockpitId then
						return item
					end
				end
			end
		end
	end

	local function V76_colorAttribute(item, name, fallback)
		local value = item and item:GetAttribute(name)
		if typeof(value) == "Color3" then
			return value
		end
		return fallback
	end

	local function V76_defaultCockpitColorsFor(profile)
		local cockpit = V76_findCockpitForDefaultColours(profile.CurrentCategory or "bruiser", profile.CurrentCockpit or "bruiser_01")
		return {
			Primary = V76_colorAttribute(cockpit, "DefaultPrimaryColor", Color3.fromRGB(0, 205, 230)),
			Secondary = V76_colorAttribute(cockpit, "DefaultSecondaryColor", Color3.fromRGB(235, 247, 204)),
			Detail = V76_colorAttribute(cockpit, "DefaultDetailColor", Color3.fromRGB(38, 44, 50)),
			Neon = V76_colorAttribute(cockpit, "DefaultNeonColor", Color3.fromRGB(255, 255, 255)),
			FrontLights = V76_colorAttribute(cockpit, "DefaultFrontLightsColor", Color3.fromRGB(252, 250, 255)),
			RearLights = V76_colorAttribute(cockpit, "DefaultRearLightsColor", Color3.fromRGB(255, 116, 116)),
		}
	end

	local function V76_applyDefaultCockpitColors(profile)
		profile.CockpitColors = V76_defaultCockpitColorsFor(profile)
	end

	local function V56_setLeaderstats(player, profile)]],
		"server per-cockpit colour helper insertion")

	serverSource = replaceOnce(serverSource,
[[					if ok then
						profile.CurrentCockpit = cockpitId
						V76_grantDefaultModulesForCurrentCockpit(profile)
					end]],
[[					if ok then
						profile.CurrentCockpit = cockpitId
						V76_applyDefaultCockpitColors(profile)
						V76_grantDefaultModulesForCurrentCockpit(profile)
					end]],
		"server cockpit select applies default colours")

	serverScript.Source = serverSource
	info("Patched server to apply per-cockpit default colours on cockpit select/buy.")
else
	info("Server per-cockpit colour patch already installed.")
end

local clientScript = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

local clientSource = clientScript.Source
if not string.find(clientSource, "NTR_VEHICLE_PHASE_AK_COCKPIT_PAINT_CAMERA_REPAIR", 1, true) then
	clientSource = replaceOnce(clientSource,
[[		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			showStage("CockpitPaint")
			renderCockpitPaint()]],
[[		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			-- NTR_VEHICLE_PHASE_AK_COCKPIT_PAINT_CAMERA_REPAIR
			setCameraSection("Engine1")
			showStage("CockpitPaint")
			renderCockpitPaint()]],
		"client cockpit paint camera transition")
	clientScript.Source = clientSource
	info("Patched cockpit paint entry camera to match Front Engine view.")
else
	info("Cockpit paint entry camera repair already installed.")
end

info("Complete. Edit default cockpit colours directly on each COCKPIT_BRUISER_* model.")
