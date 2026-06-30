-- Neo Tokyo Racers - VFX Mobile Late Socket Rescan Repair
-- Run this whole file in the Roblox Studio Command Bar while NOT play-testing.
--
-- Fixes intermittent missing engine/boost/stabiliser VFX on mobile by making
-- VehicleVFXController rescan vehicles for VFX sockets after the initial attach.
-- This keeps late-replicated module sockets/root parts from being permanently missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SCRIPT_ID = "roblox_vfx_mobile_late_socket_rescan_repair"

local function requireChild(parent, name, className)
	local child = parent and parent:FindFirstChild(name)
	if not child then
		error(("[NTR VFX Late Socket Repair] Missing %s under %s. No changes applied.")
			:format(name, parent and parent:GetFullName() or "nil"))
	end
	if className and not child:IsA(className) then
		error(("[NTR VFX Late Socket Repair] %s is %s, expected %s. No changes applied.")
			:format(child:GetFullName(), child.ClassName, className))
	end
	return child
end

local function replaceExact(source, oldText, newText, label)
	local first, last = string.find(source, oldText, 1, true)
	if not first then
		error(("[NTR VFX Late Socket Repair] Preflight failed at %s. Refresh the Studio mirror before another patch; no changes applied.")
			:format(label))
	end
	if string.find(source, oldText, last + 1, true) then
		error(("[NTR VFX Late Socket Repair] Multiple matches at %s; no changes applied.")
			:format(label))
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, last + 1)
end

local ntr = requireChild(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local shared = requireChild(ntr, "Shared", "Folder")
local modules = requireChild(shared, "Modules", "Folder")
local client = requireChild(modules, "Client", "Folder")
local vfx = requireChild(client, "VFX", "Folder")
local controller = requireChild(vfx, "VehicleVFXController", "ModuleScript")

local source = controller.Source
if string.find(source, "NTR_VFX_MOBILE_LATE_SOCKET_RESCAN", 1, true) then
	print("[NTR VFX Late Socket Repair] Already installed; no source changes needed.")
	controller:SetAttribute("LastUpdatedBy", SCRIPT_ID)
	controller:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))
	return
end

source = replaceExact(source, [==[
local CONFIG_NAME = "STABILISER_VFX_DIRECTION_DoNotRename"
]==], [==[
local CONFIG_NAME = "STABILISER_VFX_DIRECTION_DoNotRename"
local RESCAN_INTERVAL = 0.35 -- NTR_VFX_MOBILE_LATE_SOCKET_RESCAN
]==], "rescan interval constant")

source = replaceExact(source, [==[
local function attachWholeTemplate(self, socket, template, templateName)
	local settings = templateSettings(template)
	if self.IsMobile and not settings.EnabledOnMobile then return end

	local socketSide = templateName == "StabiliserJet" and stabiliserSideFromSocket(socket) or nil
	local parts = topLevelTemplateParts(template)
	if #parts == 0 then return end

	local reference = template:FindFirstChild("TemplateHost_Invisible", true)
	if not (reference and reference:IsA("BasePart")) then
		reference = parts[1]
	end

	local parentPart = socket.Parent
	if not (parentPart and parentPart:IsA("BasePart")) then return end

	for _, templatePart in ipairs(parts) do
		local relative = reference.CFrame:ToObjectSpace(templatePart.CFrame)
		local clone = templatePart:Clone()
		clone.Name = socket.Name .. "_" .. templatePart.Name .. "_Runtime"
		prepRuntimeHost(clone)
		clone.CFrame = socket.WorldCFrame * relative
		clone.Parent = parentPart
		weldNestedParts(clone)

		local weld = Instance.new("WeldConstraint")
		weld.Name = "VFX_RuntimeWeld"
		weld.Part0 = parentPart
		weld.Part1 = clone
		weld.Parent = clone

		repairBeamAttachments(clone)
		table.insert(self.CreatedHosts, clone)

		for _, descendant in ipairs(clone:GetDescendants()) do
			if isToggleable(descendant) then
				trackEffect(self, descendant, templateName, settings, socketSide)
			end
		end
	end
end

function VehicleVFXController.Attach(vehicle, templates, isMobile)
]==], [==[
local function attachWholeTemplate(self, socket, template, templateName)
	local settings = templateSettings(template)
	if self.IsMobile and not settings.EnabledOnMobile then return end

	local socketSide = templateName == "StabiliserJet" and stabiliserSideFromSocket(socket) or nil
	local parts = topLevelTemplateParts(template)
	if #parts == 0 then return end

	local reference = template:FindFirstChild("TemplateHost_Invisible", true)
	if not (reference and reference:IsA("BasePart")) then
		reference = parts[1]
	end

	local parentPart = socket.Parent
	if not (parentPart and parentPart:IsA("BasePart")) then return end

	for _, templatePart in ipairs(parts) do
		local relative = reference.CFrame:ToObjectSpace(templatePart.CFrame)
		local clone = templatePart:Clone()
		clone.Name = socket.Name .. "_" .. templatePart.Name .. "_Runtime"
		prepRuntimeHost(clone)
		clone.CFrame = socket.WorldCFrame * relative
		clone.Parent = parentPart
		weldNestedParts(clone)

		local weld = Instance.new("WeldConstraint")
		weld.Name = "VFX_RuntimeWeld"
		weld.Part0 = parentPart
		weld.Part1 = clone
		weld.Parent = clone

		repairBeamAttachments(clone)
		table.insert(self.CreatedHosts, clone)

		for _, descendant in ipairs(clone:GetDescendants()) do
			if isToggleable(descendant) then
				trackEffect(self, descendant, templateName, settings, socketSide)
			end
		end
	end
end

function VehicleVFXController:AttachSocket(socket)
	if not (socket and socket.Parent and socket:IsA("Attachment")) then return end
	if not (socket:GetAttribute("VFXSocket") == true or string.sub(socket.Name, 1, 4) == "VFX_") then return end
	self.AttachedSockets = self.AttachedSockets or setmetatable({}, { __mode = "k" })
	if self.AttachedSockets[socket] then return end

	local templateName = templateNameFromSocket(socket)
	local template = templateName and self.Templates and self.Templates:FindFirstChild(templateName)
	if not template then return end

	self.AttachedSockets[socket] = true
	attachWholeTemplate(self, socket, template, templateName)
end

function VehicleVFXController:ScanSockets()
	if not (self.Vehicle and self.Vehicle.Parent) then return end
	for _, socket in ipairs(self.Vehicle:GetDescendants()) do
		self:AttachSocket(socket)
	end
end

function VehicleVFXController.Attach(vehicle, templates, isMobile)
]==], "socket rescan methods")

source = replaceExact(source, [==[
		CreatedHosts = {},
		Elapsed = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
	}, VehicleVFXController)
]==], [==[
		CreatedHosts = {},
		AttachedSockets = setmetatable({}, { __mode = "k" }),
		Elapsed = 0,
		SocketScanTimer = 0,
		Globals = globalSettings(templates),
		Root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)),
	}, VehicleVFXController)
]==], "controller state fields")

source = replaceExact(source, [==[
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
	self:ScanSockets()

	return self
end
]==], "initial socket scan")

source = replaceExact(source, [==[
	self.Elapsed = 0

	state = state or {}
	local visible = self:Visible()
]==], [==[
	self.Elapsed = 0
	self.SocketScanTimer = (self.SocketScanTimer or 0) + interval
	if self.SocketScanTimer >= RESCAN_INTERVAL then
		self.SocketScanTimer = 0
		self:ScanSockets()
	end

	state = state or {}
	local visible = self:Visible()
]==], "periodic socket rescan")

source = replaceExact(source, [==[
function VehicleVFXController:Visible()
	if not self.Root or not self.Root.Parent then return false end
	local camera = Workspace.CurrentCamera
]==], [==[
function VehicleVFXController:Visible()
	if not self.Root or not self.Root.Parent then
		self.Root = self.Vehicle and (self.Vehicle.PrimaryPart or self.Vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	end
	if not self.Root or not self.Root.Parent then return false end
	local camera = Workspace.CurrentCamera
]==], "late root refresh")

source = replaceExact(source, [==[
	self.SocketScanTimer = (self.SocketScanTimer or 0) + interval
	if self.SocketScanTimer >= RESCAN_INTERVAL then
		self.SocketScanTimer = 0
		self:ScanSockets()
	end
]==], [==[
	self.SocketScanTimer = (self.SocketScanTimer or 0) + interval
	if self.SocketScanTimer >= RESCAN_INTERVAL then
		self.SocketScanTimer = 0
		if not self.Root or not self.Root.Parent then
			self.Root = self.Vehicle and (self.Vehicle.PrimaryPart or self.Vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
		end
		self:ScanSockets()
	end
]==], "periodic root refresh")

controller.Source = source
controller:SetAttribute("LastUpdatedBy", SCRIPT_ID)
controller:SetAttribute("LastUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))

print("[NTR VFX Late Socket Repair] Installed.")
print("[NTR VFX Late Socket Repair] VehicleVFXController now rescans for late engine/boost/stabiliser sockets and refreshes late roots.")
print("[NTR VFX Late Socket Repair] Stop Play and start a fresh mobile/emulator session to verify.")
