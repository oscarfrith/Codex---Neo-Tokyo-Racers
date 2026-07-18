-- Neo Tokyo Racers - Transient module preview lifecycle
-- NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1"
local BASELINE = "NTR_GARAGE_UPGRADE_PATH_LOCAL_PRICING_V1"
local PREFIX = "[NTR Garage Preview Lifecycle]"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local application = need(need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder"), "ModuleShopUIController", "ModuleScript")
assert(kit ~= nil, "NeoTokyoRacers kit missing")
assert(string.find(application.Source, BASELINE, 1, true) or string.find(application.Source, REVISION, 1, true), "Confirmed path-pricing UI baseline missing; refresh the mirror rather than patching an unknown source")

local source = application.Source
if not string.find(source, REVISION, 1, true) then
	source = replaceOnce(source,
		[[local function clearPreview() if preview.Root and preview.Root.Parent then preview.Root:Destroy() end; table.clear(preview); State.PreviewModules={}; State.GarageCameraActive=false end]],
		[[local function clearPreview() if preview.Root and preview.Root.Parent then preview.Root:Destroy() end; table.clear(preview); State.PreviewModules={}; State.GarageCameraActive=false end
local function clearTransientModulePreview() -- NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1
	State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; State.PreviewUpgradeId=nil; State.PreviewNeonSlot=nil
end]], "transient preview reset owner")
	source = replaceOnce(source,
		[[c.OnNext=function() State.ModuleMode="Slots"; State.ModuleOptionMode=nil; section("Engine1"); buildPreview(); renderBuild() end]],
		[[c.OnNext=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; section("Engine1"); buildPreview(); renderBuild() end]], "paint to build boundary")
	source = replaceOnce(source,
		[[	c.OnBack=function() if State.ModuleMode=="Options" then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; State.PreviewModules={}; buildPreview(); renderBuild() else renderPaint() end end; c.OnNext=function() local e,s,b=coreReady(); if not(e and s and b) then message("Equip one engine, stabilisers, and boost first."); return end; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; renderCustomise() end; workspaceUI:Show(c)]],
		[[	c.OnBack=function() clearTransientModulePreview(); if State.ModuleMode=="Options" then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() else buildPreview(); renderPaint() end end; c.OnNext=function() local e,s,b=coreReady(); if not(e and s and b) then message("Equip one engine, stabilisers, and boost first."); return end; clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; renderCustomise() end; workspaceUI:Show(c)]], "build page boundaries")
	source = replaceOnce(source,
		[[	c.OnBack=function() if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else State.ModuleMode="Slots"; renderBuild() end end
	c.OnNext=function() action:Session("End",{ReturnToEntry=false}); local r=action:Call("SpawnVehicle",{}); if not r.Success then message(r.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end]],
		[[	c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode~="Overview" and target~="ALL" then State.CustomizeMode="Overview"; renderCustomise() else State.ModuleMode="Slots"; buildPreview(); renderBuild() end end
	c.OnNext=function() clearTransientModulePreview(); action:Session("End",{ReturnToEntry=false}); local r=action:Call("SpawnVehicle",{}); if not r.Success then message(r.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end]], "customise back and drive boundaries")
end
compile("ModuleShopUIController", source)

local function sourceHas(marker)
	return string.find(application.Source, marker, 1, true) ~= nil
end

local function audit()
	local pass, fail = 0, 0
	local function check(condition, message)
		if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end
	end
	check(sourceHas(REVISION), "one transient-preview reset owner is installed")
	check(string.find(application.Source, [[c.OnNext=function() clearTransientModulePreview(); State.ModuleMode="Slots"]], 1, true) ~= nil, "Paint to Build restores equipped modules")
	check(string.find(application.Source, [[c.OnBack=function() clearTransientModulePreview(); if State.ModuleMode=="Options"]], 1, true) ~= nil, "Build Back restores equipped modules")
	check(string.find(application.Source, [[clearTransientModulePreview(); State.CustomizeTarget="ALL"]], 1, true) ~= nil, "Build to Customise restores equipped modules")
	check(string.find(application.Source, [[c.OnBack=function() clearTransientModulePreview(); if State.CustomizeMode]], 1, true) ~= nil, "Customise Back restores equipped modules")
	check(string.find(application.Source, [[c.OnNext=function() clearTransientModulePreview(); action:Session]], 1, true) ~= nil, "Start Driving discards transient selections")
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d", PREFIX, pass, fail))
	assert(fail == 0, "Post-install audit failed")
end

if MODE == "AUDIT" then audit(); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")
if sourceHas(REVISION) then audit(); print(PREFIX .. " already installed; no changes made"); return end

local oldSource = application.Source
local ok, err = pcall(function()
	application.Source = source
	audit()
end)
if not ok then pcall(function() application.Source = oldSource end); error(PREFIX .. " rolled back: " .. tostring(err), 0) end
print(PREFIX .. " INSTALL COMPLETE - Restart Play and verify unequipped previews disappear on Back, Next, Customise and Start Driving boundaries.")
