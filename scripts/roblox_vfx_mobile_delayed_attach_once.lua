-- Neo Tokyo Racers - mobile VFX delayed attach-once reliability fix
--
-- Purpose:
--   Keep the restored known-good VFX baseline, but make mobile attachment wait
--   briefly for vehicle/customisation preview descendants to settle before the
--   single template clone pass.
--
-- This intentionally does NOT add continuous socket rescans, host clearing,
-- rebuild loops, or extra VFX owners.
--
-- Run in Studio edit mode with Play stopped, after confirming
-- roblox_vfx_restore_mirror_known_good_baseline.lua restored the working VFX
-- baseline.

local LOG_PREFIX = "[NTR VFX Mobile Delayed Attach Once]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	assert(child, LOG_PREFIX .. " Missing " .. tostring(name))
	if className then
		assert(child:IsA(className), LOG_PREFIX .. " Expected " .. child:GetFullName() .. " to be " .. className .. ", got " .. child.ClassName)
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	if string.find(source, newText, 1, true) then
		log(label .. " already installed.")
		return source, false
	end
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, LOG_PREFIX .. " Could not find expected source block: " .. label)
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1), true
end

local kit = requireChild(ReplicatedStorage, "NeoTokyoRacers")
local templates = requireChild(requireChild(requireChild(kit, "Assets"), "VFX"), "VehicleTemplates")
local globalSettingsFolder = requireChild(templates, "00_GLOBAL_VFX_SETTINGS")

local delayValue = globalSettingsFolder:FindFirstChild("MobileInitialAttachDelaySeconds")
if not delayValue then
	delayValue = Instance.new("NumberValue")
	delayValue.Name = "MobileInitialAttachDelaySeconds"
	delayValue.Parent = globalSettingsFolder
end
delayValue.Value = 0.45
log("Set VehicleTemplates.00_GLOBAL_VFX_SETTINGS.MobileInitialAttachDelaySeconds = 0.45")

local controller = requireChild(requireChild(requireChild(requireChild(requireChild(kit, "Shared"), "Modules"), "Client"), "VFX"), "VehicleVFXController", "ModuleScript")
local source = controller.Source
local changed = false

source, changed = replaceExact(source, [==[
		CullDistanceStuds = readValue(folder, "CullDistanceStuds", 260),
	}
end
]==], [==[
		CullDistanceStuds = readValue(folder, "CullDistanceStuds", 260),
		MobileInitialAttachDelaySeconds = math.clamp(readValue(folder, "MobileInitialAttachDelaySeconds", 0.45), 0, 2),
	}
end
]==], "add configurable mobile initial attach delay")

source, changed = replaceExact(source, [==[
local function prepRuntimeHost(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Transparency = 1
	for _, descendant in ipairs(part:GetDescendants()) do
]==], [==[
local function prepRuntimeHost(part)
	part:SetAttribute("NTR_VFXRuntimeHost", true)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Transparency = 1
	for _, descendant in ipairs(part:GetDescendants()) do
]==], "mark cloned runtime hosts")

source, changed = replaceExact(source, [==[
function VehicleVFXController.Attach(vehicle, templates, isMobile)
	local self = setmetatable({
		Vehicle = vehicle,
		Templates = templates,
		IsMobile = isMobile == true,
		Items = {},
		CreatedHosts = {},
		Elapsed = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
	}, VehicleVFXController)

	if not vehicle or not templates then
		return self
	end

	for _, socket in ipairs(vehicle:GetDescendants()) do
		if socket:IsA("Attachment") and (socket:GetAttribute("VFXSocket") == true or string.sub(socket.Name, 1, 4) == "VFX_") then
			local templateName = templateNameFromSocket(socket)
			local template = templateName and templates:FindFirstChild(templateName)
			if template then
				attachWholeTemplate(self, socket, template, templateName)
			end
		end
	end

	return self
end
]==], [==[
local function isRuntimeHostDescendant(instance)
	local current = instance
	while current do
		if current:GetAttribute("NTR_VFXRuntimeHost") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function attachVehicleSocketsOnce(self)
	if self.Destroyed or self.SocketAttachDone then return end
	self.SocketAttachDone = true

	local vehicle = self.Vehicle
	local templates = self.Templates
	if not vehicle or not vehicle.Parent or not templates then
		return
	end

	self.Root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true) or self.Root

	for _, socket in ipairs(vehicle:GetDescendants()) do
		if socket:IsA("Attachment")
			and not isRuntimeHostDescendant(socket)
			and (socket:GetAttribute("VFXSocket") == true or string.sub(socket.Name, 1, 4) == "VFX_") then
			local templateName = templateNameFromSocket(socket)
			local template = templateName and templates:FindFirstChild(templateName)
			if template then
				attachWholeTemplate(self, socket, template, templateName)
			end
		end
	end
end

function VehicleVFXController.Attach(vehicle, templates, isMobile)
	local self = setmetatable({
		Vehicle = vehicle,
		Templates = templates,
		IsMobile = isMobile == true,
		Items = {},
		CreatedHosts = {},
		Elapsed = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
		SocketAttachDone = false,
		Destroyed = false,
	}, VehicleVFXController)

	if not vehicle or not templates then
		return self
	end

	local delaySeconds = self.IsMobile and self.Globals.MobileInitialAttachDelaySeconds or 0
	if delaySeconds > 0 then
		task.delay(delaySeconds, function()
			attachVehicleSocketsOnce(self)
		end)
	else
		attachVehicleSocketsOnce(self)
	end

	return self
end
]==], "replace immediate attach with mobile delayed attach-once")

source, changed = replaceExact(source, [==[
function VehicleVFXController:Destroy()
	for _, record in ipairs(self.Items) do
]==], [==[
function VehicleVFXController:Destroy()
	self.Destroyed = true
	for _, record in ipairs(self.Items) do
]==], "mark controller destroyed before pending delayed attach")

controller.Source = source
log("Installed mobile delayed attach-once patch in VehicleVFXController.")
log("Stop Play and start a fresh mobile/emulator test. Desktop attach remains immediate.")
