-- Neo Tokyo Racers - Dealership / Customisation Split Phase 6 Register Limit Repair
--
-- Run in Roblox Studio Command Bar while in Edit mode.
--
-- Repairs:
--   Out of local registers when trying to allocate init: exceeded limit 200
--
-- Cause:
--   Phase 6 inserted several top-level local helper functions into the already
--   register-constrained active client bootstrap. This repair keeps the same UI
--   behaviour but changes those helpers into global function assignments, which
--   do not consume the bootstrap's top-level local register budget.

local PHASE = "NTR Dealership/Customisation Phase 6 Register Repair"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_SQUARE_COCKPIT_IMAGES"
local REPAIR_MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_REGISTER_LIMIT_REPAIR"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceBetween(source, startNeedle, endNeedle, replacement, label)
	local startIndex = string.find(source, startNeedle, 1, true)
	assert(startIndex, "Could not find start anchor for " .. label .. ". Refresh the Studio mirror before another repair.")
	local endIndex = string.find(source, endNeedle, startIndex, true)
	assert(endIndex, "Could not find end anchor for " .. label .. ". Refresh the Studio mirror before another repair.")
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex)
end

local StarterPlayer = game:GetService("StarterPlayer")

local function activeBootstrap()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local scriptObject = root:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	assert(scriptObject:IsA("LocalScript"), "Active bootstrap path is not a LocalScript.")
	return scriptObject
end

local repairedHelperBlock = [=[
-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE6_REGISTER_LIMIT_REPAIR
function NTR_phase6CardConfig()
	local config = kit:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	return ui and ui:FindFirstChild("CockpitMenuCards") or nil
end

function NTR_phase6ConfigNumber(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

function NTR_phase6ConfigBool(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("BoolValue") and item.Value or fallback
end

function NTR_phase6ConfigString(name, fallback)
	local folder = NTR_phase6CardConfig()
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("StringValue") and item.Value or fallback
end

function NTR_phase6AssetImage(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

function NTR_phase5AssetImage(value)
	return NTR_phase6AssetImage(value)
end

function NTR_phase6ReadImageObject(object)
	if not object then return "" end
	for _, name in ipairs({ "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }) do
		local image = NTR_phase6AssetImage(object:GetAttribute(name))
		if image ~= "" then return image end
		local child = object:FindFirstChild(name)
		if child then
			if child:IsA("StringValue") then
				image = NTR_phase6AssetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = NTR_phase6AssetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = NTR_phase6AssetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	for _, child in ipairs(object:GetDescendants()) do
		local lower = string.lower(child.Name)
		if string.find(lower, "menuimage", 1, true) or string.find(lower, "cockpitimage", 1, true) or string.find(lower, "thumbnail", 1, true) then
			local image = ""
			if child:IsA("StringValue") then
				image = NTR_phase6AssetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = NTR_phase6AssetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = NTR_phase6AssetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	return ""
end

function NTR_phase6FindCockpitModel(cockpit)
	local cockpitId = cockpit and tostring(cockpit.CockpitId or cockpit.CockpitID or cockpit.Id or cockpit.Name or "")
	if cockpitId == "" then return nil end
	for _, category in ipairs(categoriesRoot:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, candidate in ipairs(root:GetDescendants()) do
				if candidate:IsA("Model") then
					local candidateId = tostring(candidate:GetAttribute("CockpitId") or candidate.Name)
					if candidateId == cockpitId or candidate.Name == cockpitId then
						return candidate
					end
				end
			end
		end
	end
	return nil
end

function NTR_phase6ReadModelOrAncestors(model)
	local image = NTR_phase6ReadImageObject(model)
	if image ~= "" then return image end
	local current = model and model.Parent
	while current and current ~= categoriesRoot do
		image = NTR_phase6ReadImageObject(current)
		if image ~= "" then return image end
		current = current.Parent
	end
	return ""
end

function NTR_phase5CockpitMenuImage(cockpit)
	local fromCatalog = NTR_phase6AssetImage(cockpit and (cockpit.MenuImage or cockpit.CockpitImage or cockpit.ThumbnailImage or cockpit.ImageId or cockpit.Image) or "")
	if fromCatalog ~= "" then return fromCatalog end
	return NTR_phase6ReadModelOrAncestors(NTR_phase6FindCockpitModel(cockpit))
end

function NTR_phase6CockpitCardSize()
	return UDim2.fromOffset(NTR_phase6ConfigNumber("CardWidth", 118), NTR_phase6ConfigNumber("CardHeight", 176))
end

function NTR_phase6GridCellSize(defaultWidth)
	local width = NTR_phase6ConfigBool("UseResponsiveGridWidth", false) and defaultWidth or NTR_phase6ConfigNumber("CardWidth", defaultWidth or 118)
	local ratio = NTR_phase6ConfigNumber("CardHeight", 176) / math.max(1, NTR_phase6ConfigNumber("CardWidth", 118))
	return UDim2.fromOffset(width, math.floor(width * ratio + 0.5))
end

function NTR_phase6ScaleType()
	local value = string.lower(NTR_phase6ConfigString("ImageScaleType", "Fit"))
	return value == "crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
end

function NTR_phase5RenderCockpitMenuImage(card, cockpit)
	local size = NTR_phase6ConfigNumber("ImageBoxSize", 100)
	local icon = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(18, 27, 31),
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(NTR_phase6ConfigNumber("ImageBoxX", 9), NTR_phase6ConfigNumber("ImageBoxY", 9)),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, card)
	icon:SetAttribute("PooledDynamic", true)
	corner(icon, NTR_phase6ConfigNumber("ImageCornerRadius", 4))
	stroke(icon, Theme.Accent, 0.75, 1)
	local imageId = NTR_phase5CockpitMenuImage(cockpit)
	if imageId ~= "" then
		local inset = NTR_phase6ConfigNumber("ImageInnerPadding", 4)
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = NTR_phase6ScaleType(),
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			Position = UDim2.fromOffset(inset, inset),
			BorderSizePixel = 0,
		}, icon)
		image:SetAttribute("PooledDynamic", true)
	else
		local carShape = new("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(NTR_phase6ConfigNumber("FallbackBarWidth", 72), NTR_phase6ConfigNumber("FallbackBarHeight", 18)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		}, icon)
		carShape:SetAttribute("PooledDynamic", true)
		corner(carShape, 3)
	end
end

]=]

local bootstrap = activeBootstrap()
local source = bootstrap.Source

assert(findPlain(source, MARKER) or findPlain(source, REPAIR_MARKER), "Phase 6 cockpit image helper marker was not found in the active bootstrap. Run Phase 6 first, or refresh the mirror if Studio has changed.")

if findPlain(source, REPAIR_MARKER) and not findPlain(source, MARKER) then
	info("Register repair already installed.")
else
	source = replaceBetween(
		source,
		findPlain(source, MARKER) and ("-- " .. MARKER) or ("-- " .. REPAIR_MARKER),
		[=[applyDealershipLayout = function()]=],
		repairedHelperBlock,
		"Phase 6 helper block register repair"
	)
	bootstrap.Source = source
	info("Moved Phase 6 cockpit image helpers off top-level locals.")
end

assert(not bootstrap.Source:find("local function NTR_phase6", 1, true), "A local Phase 6 helper remains in the bootstrap.")
assert(not bootstrap.Source:find("local function NTR_phase5RenderCockpitMenuImage", 1, true), "The local Phase 5 cockpit image render helper remains in the bootstrap.")
assert(not bootstrap.Source:find("local function NTR_phase5CockpitMenuImage", 1, true), "The local Phase 5 cockpit image lookup helper remains in the bootstrap.")
assert(bootstrap.Source:find("function NTR_phase6ConfigNumber", 1, true), "Repaired Phase 6 helper functions were not installed.")

info("PASS. Stop Play if it is running, then start a fresh Play session.")
