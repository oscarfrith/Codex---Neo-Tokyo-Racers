-- Neo Tokyo Racers - Garage replacement Phase 0 ownership/dependency audit
-- NTR_GARAGE_PHASE0_OWNERSHIP_DEPENDENCY_AUDIT_V1
--
-- READ ONLY. This script never creates, reparents, enables, disables, or edits anything.
-- Run the same script in:
--   1. Edit mode, for the static source/dependency audit.
--   2. Play > Client Command Bar while the broken garage page is visible, for runtime ownership.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PREFIX = "[NTR Garage Phase 0 Audit]"
local counts = { pass = 0, warn = 0, blocker = 0, info = 0 }

local function line(kind, message)
	counts[kind] += 1
	local text = string.format("%s %-7s %s", PREFIX, string.upper(kind), tostring(message))
	if kind == "blocker" then
		warn(text)
	else
		print(text)
	end
end

local function pass(message) line("pass", message) end
local function warnLine(message) line("warn", message) end
local function blocker(message) line("blocker", message) end
local function info(message) line("info", message) end

local function pathOf(object)
	local ok, fullName = pcall(function() return object:GetFullName() end)
	return ok and fullName or tostring(object)
end

local function findPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function readSource(object)
	local ok, source = pcall(function() return object.Source end)
	if ok and type(source) == "string" then return source end
	return nil
end

local function countPlain(source, needle)
	local count = 0
	local from = 1
	while true do
		local first = string.find(source, needle, from, true)
		if not first then break end
		count += 1
		from = first + #needle
	end
	return count
end

local function sourceObjects()
	local roots = {
		game:GetService("StarterPlayer"),
		game:GetService("StarterGui"),
		game:GetService("ReplicatedStorage"),
		game:GetService("ServerScriptService"),
	}
	local result = {}
	for _, root in ipairs(roots) do
		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("LuaSourceContainer") then table.insert(result, object) end
		end
	end
	return result
end

local function enabledText(object)
	if object:IsA("BaseScript") then
		local ok, enabled = pcall(function() return object.Enabled end)
		if ok then return enabled and "enabled" or "disabled" end
	end
	return "module"
end

local function staticAudit()
	print(PREFIX .. " MODE Edit/static (read only)")
	local starterPlayer = game:GetService("StarterPlayer")
	local scriptsRoot = starterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientRoot = scriptsRoot and scriptsRoot:FindFirstChild("NeoTokyoRacersClient")
	local bootstrap = clientRoot and clientRoot:FindFirstChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	if not bootstrap or not bootstrap:IsA("LuaSourceContainer") then
		blocker("Active NeoTokyoRacers client bootstrap was not found at the expected path.")
		return
	end

	local bootstrapSource = readSource(bootstrap)
	if not bootstrapSource then
		blocker("Studio would not expose bootstrap Source; static ownership cannot be proved.")
		return
	end
	info(string.format("Bootstrap: %s (%s, %d chars)", pathOf(bootstrap), enabledText(bootstrap), #bootstrapSource))

	local controllers = clientRoot and findPath(clientRoot, "Controllers.UI")
	local requiredModules = {
		"GarageBrowserController",
		"GarageWorkspaceController",
		"GarageReplacementComponents",
	}
	for _, name in ipairs(requiredModules) do
		local module = controllers and controllers:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			pass("Canonical module exists: " .. pathOf(module))
		else
			blocker("Canonical module missing: Controllers.UI." .. name)
		end
	end

	local legacyGuiCreates = countPlain(bootstrapSource, 'Name = "HOVER_RACING_V2_GarageUI"')
	if legacyGuiCreates > 0 then
		blocker(string.format("Bootstrap still constructs the legacy ScreenGui (%d constructor marker%s).", legacyGuiCreates, legacyGuiCreates == 1 and "" or "s"))
	else
		pass("Bootstrap does not construct HOVER_RACING_V2_GarageUI.")
	end

	local setupUICount = countPlain(bootstrapSource, "local function setupUI()")
	if setupUICount > 0 then
		blocker("Bootstrap still owns setupUI and the legacy garage object tree.")
	else
		pass("No bootstrap-owned legacy setupUI constructor remains.")
	end

	local renderNames = { "renderCockpitShop", "renderCockpitPaint", "renderModuleShop", "renderCustomise" }
	local ownedRenderers = {}
	for _, name in ipairs(renderNames) do
		if countPlain(bootstrapSource, name .. " = function") > 0 then table.insert(ownedRenderers, name) end
	end
	if #ownedRenderers > 0 then
		blocker("Bootstrap still owns canonical page assembly/state callbacks: " .. table.concat(ownedRenderers, ", "))
	else
		pass("Garage page assembly has been extracted from the bootstrap.")
	end

	local bootstrapActionCalls = countPlain(bootstrapSource, "callServer(")
	if bootstrapActionCalls > 0 then
		blocker(string.format("Bootstrap still contains %d callServer action call%s; canonical UI is not yet connected through an isolated action adapter.", bootstrapActionCalls, bootstrapActionCalls == 1 and "" or "s"))
	else
		pass("No garage server-action calls remain in the bootstrap.")
	end

	local sources = sourceObjects()
	local legacyReferences = {}
	local canonicalReferences = {}
	local presentationConstructors = {}
	for _, object in ipairs(sources) do
		local source = readSource(object)
		if source then
			if string.find(source, "HOVER_RACING_V2_GarageUI", 1, true) then table.insert(legacyReferences, object) end
			if string.find(source, "CanonicalGarageGui", 1, true) then table.insert(canonicalReferences, object) end
			if string.find(source, 'Instance.new("ScreenGui")', 1, true)
				and (string.find(source, "Garage", 1, true) or string.find(source, "garage", 1, true)) then
				table.insert(presentationConstructors, object)
			end
		end
	end

	table.sort(legacyReferences, function(a, b) return pathOf(a) < pathOf(b) end)
	if #legacyReferences > 0 then
		blocker(string.format("Zero-reference gate failed: %d source object%s still reference HOVER_RACING_V2_GarageUI.", #legacyReferences, #legacyReferences == 1 and "" or "s"))
		for _, object in ipairs(legacyReferences) do info("LEGACY REF  " .. pathOf(object) .. " [" .. enabledText(object) .. "]") end
	else
		pass("Zero-reference gate: no source references HOVER_RACING_V2_GarageUI.")
	end

	info(string.format("CanonicalGarageGui is referenced by %d source object%s.", #canonicalReferences, #canonicalReferences == 1 and "" or "s"))
	for _, object in ipairs(canonicalReferences) do info("CANONICAL REF " .. pathOf(object) .. " [" .. enabledText(object) .. "]") end
	if #presentationConstructors > 1 then
		warnLine(string.format("Found %d garage-related ScreenGui constructors; review for competing presentation owners.", #presentationConstructors))
		for _, object in ipairs(presentationConstructors) do info("GUI CONSTRUCTOR " .. pathOf(object) .. " [" .. enabledText(object) .. "]") end
	end

	local experience = controllers and controllers:FindFirstChild("GarageExperienceController_Active")
	if experience and experience:IsA("BaseScript") then
		if experience.Enabled then
			blocker("GarageExperienceController_Active is enabled and can compete with canonical geometry.")
		else
			pass("GarageExperienceController_Active is disabled.")
		end
	else
		warnLine("GarageExperienceController_Active was not found; confirm whether it was intentionally removed.")
	end

	local replicatedStorage = game:GetService("ReplicatedStorage")
	local kit = replicatedStorage:FindFirstChild("NeoTokyoRacers")
	local artwork = kit and findPath(kit, "Config.UI.GarageReplacement.ModuleArtwork")
	local expectedArtwork = {
		"All", "Cockpit", "ThrustColour", "FrontEngine", "RearEngine", "Stabilisers",
		"Boost", "FrontBumper", "RearBumper", "SidePods", "Spoiler",
	}
	if not artwork then
		blocker("Config.UI.GarageReplacement.ModuleArtwork is missing.")
	else
		local artworkFailures = {}
		for _, name in ipairs(expectedArtwork) do
			local folder = artwork:FindFirstChild(name)
			if not folder or not folder:IsA("Folder") then
				table.insert(artworkFailures, name .. " missing/not Folder")
			elseif #folder:GetChildren() > 0 then
				table.insert(artworkFailures, name .. " has child instances")
			elseif folder:GetAttribute("TargetId") == nil or folder:GetAttribute("SortOrder") == nil then
				table.insert(artworkFailures, name .. " missing required attributes")
			end
		end
		for _, child in ipairs(artwork:GetChildren()) do
			if not table.find(expectedArtwork, child.Name) then table.insert(artworkFailures, "unexpected " .. child.Name) end
		end
		if #artworkFailures == 0 then
			pass("ModuleArtwork contains exactly eleven attribute-only category folders.")
		else
			blocker("ModuleArtwork schema failed: " .. table.concat(artworkFailures, " | "))
		end
	end

	local garageServices = findPath(game:GetService("ServerScriptService"), "NeoTokyoRacers.Services.Garage")
	local actionService = garageServices and garageServices:FindFirstChild("GarageActionController_Shadow_Disabled")
	local actionSource = actionService and readSource(actionService)
	local requiredActions = {
		"BuyCockpitInstance", "BuyModuleInstance", "EquipModuleInstance", "BuyGarageProperty", "SpawnVehicle",
	}
	if not actionSource then
		blocker("Garage action service Source was not available.")
	else
		local missing = {}
		for _, action in ipairs(requiredActions) do
			if not string.find(actionSource, action, 1, true) then table.insert(missing, action) end
		end
		if #missing == 0 then pass("Server action boundary exposes the required canonical flow actions.")
		else blocker("Server action boundary is missing: " .. table.concat(missing, ", ")) end
	end

	local sessionService = garageServices and garageServices:FindFirstChild("GarageSessionService_Active")
	if sessionService and sessionService:IsA("BaseScript") and sessionService.Enabled then
		pass("GarageSessionService_Active exists and is enabled.")
	else
		blocker("GarageSessionService_Active is missing or disabled.")
	end

	print(string.format("%s STATIC SUMMARY pass=%d warn=%d blocker=%d info=%d", PREFIX, counts.pass, counts.warn, counts.blocker, counts.info))
	if counts.blocker == 0 then
		print(PREFIX .. " RETIREMENT GATE PASS - legacy presentation can be removed in the next implementation phase.")
	else
		warn(PREFIX .. " RETIREMENT GATE BLOCKED - do not delete legacy UI yet; use this evidence to build the isolated adapter/controller replacement.")
	end
end

local function isEffectivelyVisible(object)
	local current = object
	while current do
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		if current:IsA("GuiObject") and not current.Visible then return false end
		current = current.Parent
	end
	return object.Parent ~= nil
end

local function runtimeAudit(player)
	print(PREFIX .. " MODE Play/client runtime (read only)")
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then blocker("Local PlayerGui was not found."); return end

	local legacyGui = playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	local canonicalGui = playerGui:FindFirstChild("CanonicalGarageGui")
	local legacyEnabled = legacyGui and legacyGui:IsA("ScreenGui") and legacyGui.Enabled
	local canonicalEnabled = canonicalGui and canonicalGui:IsA("ScreenGui") and canonicalGui.Enabled

	info("Legacy ScreenGui: " .. (legacyGui and (pathOf(legacyGui) .. ", enabled=" .. tostring(legacyEnabled)) or "absent"))
	info("Canonical ScreenGui: " .. (canonicalGui and (pathOf(canonicalGui) .. ", enabled=" .. tostring(canonicalEnabled)) or "absent"))

	local visibleCanonical = {}
	if canonicalGui then
		for _, name in ipairs({ "CanonicalGarageBrowser", "CanonicalGarageWorkspace" }) do
			local root = canonicalGui:FindFirstChild(name, true)
			if root and root:IsA("GuiObject") and isEffectivelyVisible(root) then table.insert(visibleCanonical, root) end
		end
	end

	local visibleLegacy = {}
	if legacyGui and legacyEnabled then
		for _, child in ipairs(legacyGui:GetChildren()) do
			if child:IsA("GuiObject") and isEffectivelyVisible(child) then table.insert(visibleLegacy, child) end
		end
	end
	table.sort(visibleLegacy, function(a, b) return a.Name < b.Name end)

	if #visibleCanonical > 1 then blocker("Both canonical Browser and Workspace are effectively visible.") end
	if #visibleCanonical == 1 and #visibleLegacy == 0 then
		pass("Exclusive runtime ownership: one canonical root visible and no legacy top-level surface visible.")
	elseif #visibleCanonical == 1 and #visibleLegacy > 0 then
		blocker("Competing runtime owners: canonical and legacy surfaces are visible together.")
	elseif #visibleCanonical == 0 and #visibleLegacy > 0 then
		blocker("Legacy runtime owner won: legacy surfaces are visible and no canonical root is visible.")
	else
		warnLine("No garage presentation root is visibly active. Rerun this client audit while the broken garage page is open.")
	end

	for _, root in ipairs(visibleCanonical) do
		info(string.format("VISIBLE CANONICAL %s pos=%s size=%s", pathOf(root), tostring(root.AbsolutePosition), tostring(root.AbsoluteSize)))
	end
	for index, root in ipairs(visibleLegacy) do
		if index <= 30 then
			info(string.format("VISIBLE LEGACY %s pos=%s size=%s", pathOf(root), tostring(root.AbsolutePosition), tostring(root.AbsoluteSize)))
		end
	end
	if #visibleLegacy > 30 then info(string.format("... %d additional visible legacy top-level surfaces", #visibleLegacy - 30)) end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local runtimeClient = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local uiControllers = runtimeClient and findPath(runtimeClient, "Controllers.UI")
	for _, name in ipairs({ "GarageExperienceController_Active", "GarageBrowserController", "GarageWorkspaceController", "GarageReplacementComponents" }) do
		local object = uiControllers and uiControllers:FindFirstChild(name)
		if object then info("RUNTIME OWNER " .. pathOf(object) .. " [" .. enabledText(object) .. "]")
		else warnLine("Runtime controller missing: " .. name) end
	end

	print(string.format("%s RUNTIME SUMMARY pass=%d warn=%d blocker=%d info=%d", PREFIX, counts.pass, counts.warn, counts.blocker, counts.info))
	if counts.blocker == 0 then
		print(PREFIX .. " RUNTIME OWNERSHIP PASS")
	else
		warn(PREFIX .. " RUNTIME OWNERSHIP FAIL - copy this complete audit output before any replacement implementation.")
	end
end

if not RunService:IsRunning() then
	staticAudit()
else
	local player = Players.LocalPlayer
	if player then
		runtimeAudit(player)
	else
		print(PREFIX .. " Play/server context detected. Use the Client Command Bar while the garage page is visible for runtime ownership evidence.")
	end
end

