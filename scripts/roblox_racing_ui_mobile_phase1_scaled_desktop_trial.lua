-- Neo Tokyo Racers - Mobile Racing UI Phase 1 Scaled Desktop Trial
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Run INSTALL, restart Play, verify Browser -> Entry -> Results, then run SMOKE.
--
-- This is a guarded source patch. It selects the already-approved PC composition
-- on touch devices and scales that fixed 1200x720 shell into a mobile safe area.
-- Exact source anchors are checked before any live source is changed.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Mobile Racing UI Phase 1"
local MARKER = "NTR_RACING_UI_MOBILE_PHASE1_SCALED_DESKTOP_TRIAL"
local MODULE_MARKER = "NTR_RACING_UI_MOBILE_SCALED_DESKTOP_LAYOUT_V1"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. (parent and parent:GetFullName() or "nil") .. "." .. name)
	end
	return item
end
local function ensure(parent, className, name)
	local item = parent:FindFirstChild(name)
	if item then
		if not item:IsA(className) then fail(item:GetFullName() .. " must be " .. className) end
		return item
	end
	item = Instance.new(className)
	item.Name = name
	item.Parent = parent
	return item
end
local function setDefaultAttribute(item, name, value)
	if item:GetAttribute(name) == nil then item:SetAttribute(name, value) end
end
local function replaceOnce(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		fail("Could not find " .. label .. " anchor. Refresh the Studio mirror before another source repair.")
	end
	if string.find(source, oldText, last + 1, true) then
		fail("Found duplicate " .. label .. " anchors; no source was changed.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = must(kit, "Shared", "Folder")
local modules = must(shared, "Modules", "Folder")
local uiModules = must(modules, "UI", "Folder")
local configRoot = must(kit, "Config", "Folder")
local uiConfig = must(configRoot, "UI", "Folder")
local racingUIConfig = must(uiConfig, "Racing", "Folder")

local playerScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(playerScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local racingControllers = must(controllers, "Racing", "Folder")
local browserOwner = must(racingControllers, "RaceBrowserClient_Active", "LocalScript")
local entryOwner = must(racingControllers, "RaceEntryPresentationController_Active", "LocalScript")
local resultOwner = must(racingControllers, "RaceTimeTrialResultCoachClient_Active", "LocalScript")

local owners = { browserOwner, entryOwner, resultOwner }
for _, owner in ipairs(owners) do
	if not string.find(owner.Source, "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP", 1, true) then
		fail(owner:GetFullName() .. " is not the confirmed Phase 16E presentation owner.")
	end
end

local MODULE_SOURCE = [====[
-- NTR_RACING_UI_MOBILE_SCALED_DESKTOP_LAYOUT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Racing"):WaitForChild("MobileScaledDesktop")

local Layout = {}
local records = setmetatable({}, { __mode = "k" })

local function numberAttribute(name, fallback)
	local value = tonumber(config:GetAttribute(name))
	return value ~= nil and value or fallback
end

function Layout.IsEnabled(touchDevice)
	return touchDevice == true and config:GetAttribute("Enabled") ~= false
end

function Layout.Attach(shell)
	assert(shell and shell:IsA("GuiObject"), "Mobile scaled desktop layout requires a GuiObject shell")

	local previous = records[shell]
	if previous and previous.Cleanup then previous.Cleanup() end

	local scale = shell:FindFirstChild("MobileScaledDesktopScale")
	if scale and not scale:IsA("UIScale") then scale:Destroy() scale = nil end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MobileScaledDesktopScale"
		scale.Parent = shell
	end

	local record = { ConfigConnections = {} }
	records[shell] = record
	local cleaned = false

	local function update()
		if cleaned or not shell.Parent then return end
		local camera = Workspace.CurrentCamera
		if not camera then return end

		local viewport = camera.ViewportSize
		local referenceWidth = math.max(1, numberAttribute("ReferenceWidth", 1200))
		local referenceHeight = math.max(1, numberAttribute("ReferenceHeight", 720))
		local safeTop = math.max(0, numberAttribute("SafeTop", 72))
		local safeBottom = math.max(0, numberAttribute("SafeBottom", 10))
		local safeSide = math.max(0, numberAttribute("SafeSide", 10))
		local availableWidth = math.max(1, viewport.X - safeSide * 2)
		local availableHeight = math.max(1, viewport.Y - safeTop - safeBottom)
		local minimumScale = math.max(0.1, numberAttribute("ScaleMin", 0.25))
		local maximumScale = math.max(minimumScale, numberAttribute("ScaleMax", 1))
		local fittedScale = math.min(availableWidth / referenceWidth, availableHeight / referenceHeight)

		shell.AnchorPoint = Vector2.new(0.5, 0.5)
		shell.Size = UDim2.fromOffset(referenceWidth, referenceHeight)
		shell.Position = UDim2.fromOffset(safeSide + availableWidth * 0.5, safeTop + availableHeight * 0.5)
		scale.Scale = math.clamp(fittedScale, minimumScale, maximumScale)
	end

	local function bindCamera()
		if record.CameraConnection then record.CameraConnection:Disconnect() end
		local camera = Workspace.CurrentCamera
		if camera then record.CameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) end
		update()
	end

	function record.Cleanup()
		if cleaned then return end
		cleaned = true
		if record.CameraConnection then record.CameraConnection:Disconnect() end
		if record.CameraChangedConnection then record.CameraChangedConnection:Disconnect() end
		if record.AncestryConnection then record.AncestryConnection:Disconnect() end
		for _, connection in ipairs(record.ConfigConnections) do connection:Disconnect() end
		if records[shell] == record then records[shell] = nil end
	end

	record.CameraChangedConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	for _, name in ipairs({ "ReferenceWidth", "ReferenceHeight", "SafeTop", "SafeBottom", "SafeSide", "ScaleMin", "ScaleMax" }) do
		table.insert(record.ConfigConnections, config:GetAttributeChangedSignal(name):Connect(update))
	end
	record.AncestryConnection = shell.AncestryChanged:Connect(function()
		if not shell:IsDescendantOf(game) then record.Cleanup() end
	end)
	bindCamera()
	return scale
end

return Layout
]====]

local function configure()
	local config = ensure(racingUIConfig, "Folder", "MobileScaledDesktop")
	setDefaultAttribute(config, "Enabled", true)
	setDefaultAttribute(config, "ReferenceWidth", 1200)
	setDefaultAttribute(config, "ReferenceHeight", 720)
	setDefaultAttribute(config, "SafeTop", 72)
	setDefaultAttribute(config, "SafeBottom", 10)
	setDefaultAttribute(config, "SafeSide", 10)
	setDefaultAttribute(config, "ScaleMin", 0.25)
	setDefaultAttribute(config, "ScaleMax", 1)
	config:SetAttribute("InstalledBy", MARKER)

	local module = ensure(uiModules, "ModuleScript", "RacingMobileScaledDesktopLayout")
	module.Source = MODULE_SOURCE
	return config, module
end

local function patchBrowser(source)
	source = replaceOnce(source,
		'local touch = UserInputService.TouchEnabled',
		'local touchDevice = UserInputService.TouchEnabled',
		'browser touch-device declaration')
	source = replaceOnce(source,
		'local UI = require(uiModules:WaitForChild("RacingUIComponents"))',
		'local UI = require(uiModules:WaitForChild("RacingUIComponents"))\nlocal MobileScaledDesktop = require(uiModules:WaitForChild("RacingMobileScaledDesktopLayout"))\nlocal scaledDesktop = MobileScaledDesktop.IsEnabled(touchDevice)\nlocal touch = touchDevice and not scaledDesktop',
		'browser shared UI require')
	source = replaceOnce(source,
		'if touch then\n\t\tshell.Size = UDim2.new(1, -16, 1, -16)\n\telse\n\t\tshell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))\n\t\tUI.AttachResponsiveScale(shell)\n\tend',
		'if scaledDesktop then\n\t\tMobileScaledDesktop.Attach(shell)\n\telseif touch then\n\t\tshell.Size = UDim2.new(1, -16, 1, -16)\n\telse\n\t\tshell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))\n\t\tUI.AttachResponsiveScale(shell)\n\tend',
		'browser shell layout')
	return "-- " .. MARKER .. "\n" .. source
end

local function patchEntry(source)
	source = replaceOnce(source,
		'local touch = UserInputService.TouchEnabled',
		'local touchDevice = UserInputService.TouchEnabled',
		'entry touch-device declaration')
	source = replaceOnce(source,
		'local UI = require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))',
		'local entryUIModules = shared:WaitForChild("Modules"):WaitForChild("UI")\nlocal UI = require(entryUIModules:WaitForChild("RacingUIComponents"))\nlocal MobileScaledDesktop = require(entryUIModules:WaitForChild("RacingMobileScaledDesktopLayout"))\nlocal scaledDesktop = MobileScaledDesktop.IsEnabled(touchDevice)\nlocal touch = touchDevice and not scaledDesktop',
		'entry shared UI require')
	source = replaceOnce(source,
		'shell.Size = touch and UDim2.new(1, -16, 1, -16) or UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))\n\tif not touch then\n\t\tUI.AttachResponsiveScale(shell)\n\tend',
		'if scaledDesktop then\n\t\tMobileScaledDesktop.Attach(shell)\n\telseif touch then\n\t\tshell.Size = UDim2.new(1, -16, 1, -16)\n\telse\n\t\tshell.Size = UDim2.fromOffset(L("ShellWidth", 1200), L("ShellHeight", 720))\n\t\tUI.AttachResponsiveScale(shell)\n\tend',
		'entry shell layout')
	return "-- " .. MARKER .. "\n" .. source
end

local function patchResult(source)
	source = replaceOnce(source,
		'local touch = UserInputService.TouchEnabled',
		'local touchDevice = UserInputService.TouchEnabled',
		'result touch-device declaration')
	source = replaceOnce(source,
		'local UI = require(shared:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))',
		'local resultUIModules = shared:WaitForChild("Modules"):WaitForChild("UI")\nlocal UI = require(resultUIModules:WaitForChild("RacingUIComponents"))\nlocal MobileScaledDesktop = require(resultUIModules:WaitForChild("RacingMobileScaledDesktopLayout"))\nlocal scaledDesktop = MobileScaledDesktop.IsEnabled(touchDevice)\nlocal touch = touchDevice and not scaledDesktop',
		'result shared UI require')
	source = replaceOnce(source,
		'shell=UI.Panel(overlay,{Color=C("PanelDeep"),Transparency=L("PanelTransparency",.08),StrokeColor=C("Outline"),StrokeWidth=L("ShellStrokeWidth",2),StrokeTransparency=.02,Clips=true}) shell.AnchorPoint=Vector2.new(.5,.5) shell.Position=UDim2.fromScale(.5,.5) shell.Size=touch and UDim2.new(1,-16,1,-16) or UDim2.fromOffset(L("ShellWidth",1200),L("ShellHeight",720)) if not touch then UI.AttachResponsiveScale(shell) end',
		'shell=UI.Panel(overlay,{Color=C("PanelDeep"),Transparency=L("PanelTransparency",.08),StrokeColor=C("Outline"),StrokeWidth=L("ShellStrokeWidth",2),StrokeTransparency=.02,Clips=true}) shell.AnchorPoint=Vector2.new(.5,.5) shell.Position=UDim2.fromScale(.5,.5)\n\tif scaledDesktop then MobileScaledDesktop.Attach(shell) elseif touch then shell.Size=UDim2.new(1,-16,1,-16) else shell.Size=UDim2.fromOffset(L("ShellWidth",1200),L("ShellHeight",720)) UI.AttachResponsiveScale(shell) end',
		'result shell layout')
	return "-- " .. MARKER .. "\n" .. source
end

local function install()
	local installed = 0
	for _, owner in ipairs(owners) do
		if string.find(owner.Source, MARKER, 1, true) then installed += 1 end
	end
	if installed ~= 0 and installed ~= #owners then
		fail("Partial Phase 1 install detected; no source was changed. Refresh the mirror and inspect the three owners.")
	end

	if installed == #owners then
		configure()
		log("Already installed; refreshed config defaults and shared layout module.")
		return
	end

	-- Stage every exact source edit before creating config/module or mutating Studio.
	local browserSource = patchBrowser(browserOwner.Source)
	local entrySource = patchEntry(entryOwner.Source)
	local resultSource = patchResult(resultOwner.Source)

	configure()
	browserOwner.Source = browserSource
	entryOwner.Source = entrySource
	resultOwner.Source = resultSource
	log("Installed scaled approved-PC composition for Browser, Entry submenus, and unified Results on touch devices.")
	log("Restart Play before testing. Set Config.UI.Racing.MobileScaledDesktop.Enabled=false and restart Play for layout rollback.")
end

local function smoke()
	local config = must(racingUIConfig, "MobileScaledDesktop", "Folder")
	local module = must(uiModules, "RacingMobileScaledDesktopLayout", "ModuleScript")
	if not string.find(module.Source, MODULE_MARKER, 1, true) then fail("Shared mobile layout module marker is missing.") end
	for _, owner in ipairs(owners) do
		for _, expected in ipairs({ MARKER, "scaledDesktop", "MobileScaledDesktop.Attach(shell)" }) do
			if not string.find(owner.Source, expected, 1, true) then fail(owner.Name .. " is missing " .. expected) end
		end
	end
	for _, attribute in ipairs({ "Enabled", "ReferenceWidth", "ReferenceHeight", "SafeTop", "SafeBottom", "SafeSide", "ScaleMin", "ScaleMax" }) do
		if config:GetAttribute(attribute) == nil then fail("Config attribute missing: " .. attribute) end
	end
	log("SMOKE PASS: three isolated presentation owners share the config-driven scaled desktop mobile shell.")
end

if MODE == "INSTALL" then install()
elseif MODE == "SMOKE" then smoke()
else fail("Unknown MODE " .. tostring(MODE)) end
