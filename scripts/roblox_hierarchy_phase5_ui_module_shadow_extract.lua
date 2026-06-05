-- Neo Tokyo Racers - Phase 5A UI Module Shadow Extraction
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Stages the future UI architecture by copying current live UI helper
--   modules into ReplicatedStorage.NeoTokyoRacers as shadow modules.
--
-- Safe effects:
--   - Creates clean future UI folders.
--   - Copies current helper ModuleScript source into new shadow ModuleScripts.
--   - Adds ObjectValue references and migration notes.
--
-- Does NOT:
--   - Change HOVER_RACING_V2_Client.
--   - Change any live UI behaviour.
--   - Require or run the shadow modules.
--   - Disable, move, rename, delete, or replace any live script.
--   - Touch driving, VFX, LOD, traffic, lighting, or Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local function log(message)
	print("[NTR Phase5A UI Shadow] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No further changes applied.")
		end
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
end

local function stringValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("StringValue") then
		if item then
			item.Name = name .. "_OldNonStringValue"
		end
		item = Instance.new("StringValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function objectValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item or not item:IsA("ObjectValue") then
		if item then
			item.Name = name .. "_OldNonObjectValue"
		end
		item = Instance.new("ObjectValue")
		item.Name = name
		item.Parent = parent
	end
	item.Value = value
	return item
end

local function findPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function requireModuleSource(name, module)
	if not module or not module:IsA("ModuleScript") then
		error("Missing source ModuleScript for " .. name .. ". No live changes were made.")
	end
	return module
end

local kit = ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT")
if not kit then
	error("Missing ReplicatedStorage.HOVER_RACING_V2_KIT. No changes applied.")
end

local sourceUITheme = requireModuleSource("UITheme", findPath(kit, { "SHARED_MODULES", "UITheme" }))
local sourceUIPool = requireModuleSource("UIPool", findPath(kit, { "CLIENT_MODULES", "UI", "UIPool" }))
local sourceUIFactory = requireModuleSource("UIFactory", findPath(kit, { "CLIENT_MODULES", "UI", "UIFactory" }))

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local rsRoot = folder(ReplicatedStorage, "NeoTokyoRacers")
local shared = folder(rsRoot, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedUI = folder(sharedModules, "UI")
local sharedConfig = folder(shared, "Config")
local uiConfig = folder(sharedConfig, "UI")
local references = folder(rsRoot, "LiveReferences")
local migration = folder(rsRoot, "MigrationNotes")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local uiControllers = folder(controllers, "UI")

local uiRoot = child(StarterGui, "ScreenGui", "NeoTokyoRacersUI")
uiRoot.ResetOnSpawn = false
uiRoot.IgnoreGuiInset = true
uiRoot.Enabled = false
local screens = folder(uiRoot, "Screens")
local components = folder(uiRoot, "Components")
local templates = folder(uiRoot, "Templates")

folder(components, "Buttons")
folder(components, "Panels")
folder(components, "Lists")
folder(components, "StatBars")
folder(components, "ColourPicker")
folder(components, "Dealership")
folder(components, "Customisation")
folder(components, "HUD")
folder(components, "Mobile")

folder(screens, "Garage")
folder(screens, "Dealership")
folder(screens, "Customisation")
folder(screens, "DrivingHUD")
folder(screens, "CashShop")

folder(templates, "Buttons")
folder(templates, "Cards")
folder(templates, "Panels")

local function copyShadowModule(source, targetName)
	local target = sharedUI:FindFirstChild(targetName)
	if target and not target:IsA("ModuleScript") then
		error("Existing " .. target:GetFullName() .. " is not a ModuleScript. No shadow module overwritten.")
	end
	if not target then
		target = Instance.new("ModuleScript")
		target.Name = targetName
		target.Parent = sharedUI
	end
	target.Source = source.Source
	target:SetAttribute("MigrationStatus", "ShadowCopyOnly")
	target:SetAttribute("CopiedFrom", source:GetFullName())
	target:SetAttribute("DoNotRequireUntilSwitched", true)
	target:SetAttribute("CreatedBy", "roblox_hierarchy_phase5_ui_module_shadow_extract")
	return target
end

local shadowUITheme = copyShadowModule(sourceUITheme, "UITheme_Shadow")
local shadowUIPool = copyShadowModule(sourceUIPool, "UIPool_Shadow")
local shadowUIFactory = copyShadowModule(sourceUIFactory, "UIFactory_Shadow")

objectValue(references, "LiveUIThemeModule", sourceUITheme)
objectValue(references, "LiveUIPoolModule", sourceUIPool)
objectValue(references, "LiveUIFactoryModule", sourceUIFactory)
objectValue(references, "LiveUIThemeFolder", kit:FindFirstChild("UI_THEME_DoNotRename"))
objectValue(sharedUI, "ShadowUITheme", shadowUITheme)
objectValue(sharedUI, "ShadowUIPool", shadowUIPool)
objectValue(sharedUI, "ShadowUIFactory", shadowUIFactory)

stringValue(uiConfig, "README_CurrentSourceOfTruth", table.concat({
	"Current live UI theme values still come from ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename.",
	"This folder is the future NeoTokyoRacers.Shared.Config.UI location.",
	"Do not delete the old UI_THEME_DoNotRename folder until live UI scripts are switched and tested.",
}, "\n"))

stringValue(uiControllers, "README_TargetControllers", table.concat({
	"Future UI client controllers should live here.",
	"Recommended order: theme/pool/factory, shared widgets, colour picker, dealership, module shop, customisation, HUD.",
	"The current live UI still runs from StarterPlayerScripts.HOVER_RACING_V2_Client.",
}, "\n"))

stringValue(migration, "04_Phase5A_UIMigrationNotes", table.concat({
	"Phase 5A staged UI helper shadow modules only.",
	"No live UI behaviour was switched.",
	"Shadow modules may still reference old HOVER_RACING_V2_KIT paths because this is a parity copy.",
	"Next safe step: test the game, then create one extracted UI widget module at a time.",
}, "\n"))

log("Created/refreshed future UI folders.")
log("Copied UITheme, UIPool, and UIFactory into shadow ModuleScripts.")
log("No live UI scripts or gameplay systems were changed.")
log("Next safe step: test the game, then migrate one low-risk UI widget module.")
