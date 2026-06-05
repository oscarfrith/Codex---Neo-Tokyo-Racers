-- Neo Tokyo Racers preview vehicle controller.
-- Phase B module. Not live until HOVER_RACING_V2_Client is explicitly adapted.

local PreviewVehicleController = {}

local controllersFolder = script.Parent.Parent
local coreFolder = controllersFolder:WaitForChild("Core")
local PaintClient = require(coreFolder:WaitForChild("PaintClient"))

PreviewVehicleController.PreviewFolderName = "HOVER_RACING_V2_LOCAL_PREVIEW"

function PreviewVehicleController.FindTemplateByAttribute(root, attr, value)
	if not root or value == nil then
		return nil
	end
	for _, item in ipairs(root:GetDescendants()) do
		if item:GetAttribute(attr) == value then
			return item
		end
	end
	return nil
end

function PreviewVehicleController.GetPreviewRoot(workspaceRef, previewState)
	workspaceRef = workspaceRef or workspace
	previewState = previewState or {}
	if previewState.Root and previewState.Root.Parent then
		return previewState.Root
	end

	local existing = workspaceRef:FindFirstChild(PreviewVehicleController.PreviewFolderName)
	if existing then
		previewState.Root = existing
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = PreviewVehicleController.PreviewFolderName
	root.Parent = workspaceRef
	previewState.Root = root
	return root
end

function PreviewVehicleController.ClearRoot(root)
	if root then
		root:ClearAllChildren()
	end
end

function PreviewVehicleController.GetSlotMount(vehicle, slotId)
	local root = vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
	local slot = root and root:FindFirstChild("SLOT_" .. tostring(slotId))
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end

function PreviewVehicleController.PivotModuleToSlot(moduleClone, mount)
	local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
	if root then
		moduleClone.PrimaryPart = root
	end

	local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
	local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then
		moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
	elseif mount then
		moduleClone:PivotTo(mount.CFrame)
	end
end

function PreviewVehicleController.ModuleColors(profile, slotId)
	profile = profile or {}
	local cockpitColors = profile.CockpitColors or {}
	local moduleSet = profile.ModuleColors and profile.ModuleColors[slotId] or {}
	return PaintClient.ModuleColors(profile, slotId, cockpitColors, moduleSet)
end

function PreviewVehicleController.ClearPreviewModules(state)
	state.PreviewModules = {}
	state.SelectedModuleId = nil
end

function PreviewVehicleController.Build(context)
	local state = context.State
	if not state then
		return nil, "State missing"
	end

	local categoriesRoot = context.CategoriesRoot
	if not categoriesRoot then
		return nil, "Categories root missing"
	end

	local preview = context.Preview or {}
	local root = PreviewVehicleController.GetPreviewRoot(context.Workspace, preview)
	PreviewVehicleController.ClearRoot(root)

	local cockpitId = state.SelectedCockpit or (state.Profile and state.Profile.CurrentCockpit) or "bruiser_01"
	local template = PreviewVehicleController.FindTemplateByAttribute(categoriesRoot, "CockpitId", cockpitId)
	if not template then
		return nil, "Cockpit template not found: " .. tostring(cockpitId)
	end

	local vehicle = template:Clone()
	vehicle.Name = "LOCAL_PREVIEW_" .. tostring(cockpitId)
	vehicle.Parent = root
	preview.Vehicle = vehicle

	local primary = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
	if primary then
		vehicle.PrimaryPart = primary
	end

	local previewPosition = state.Catalog and state.Catalog.PreviewPosition or Vector3.new(860, 104, -1749)
	vehicle:PivotTo(CFrame.new(previewPosition))
	state.TargetFocus = previewPosition

	local cockpitColors = {}
	for key, value in pairs((state.Profile and state.Profile.CockpitColors) or {}) do
		cockpitColors[key] = value
	end
	cockpitColors.FrontLights = cockpitColors.FrontLights or Color3.fromRGB(252, 250, 255)
	cockpitColors.RearLights = cockpitColors.RearLights or Color3.fromRGB(255, 116, 116)
	PaintClient.ApplyColors(vehicle, cockpitColors, true, { Profile = state.Profile })

	local thrustColor = (state.Profile and state.Profile.ThrustColor) or Color3.fromRGB(255, 255, 255)
	root:SetAttribute("ThrustColor", thrustColor)
	root:SetAttribute("ForceThrustPreview", state.ThrustPreviewActive == true)
	vehicle:SetAttribute("ThrustColor", thrustColor)

	local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
	installedRoot.Name = "INSTALLED_MODULES_Runtime"
	installedRoot.Parent = vehicle
	installedRoot:ClearAllChildren()

	local modulesToShow = {}
	for slotId, moduleId in pairs((state.Profile and state.Profile.InstalledModules) or {}) do
		modulesToShow[slotId] = moduleId
	end
	for slotId, moduleId in pairs(state.PreviewModules or {}) do
		modulesToShow[slotId] = moduleId
	end

	for slotId, moduleId in pairs(modulesToShow) do
		local moduleTemplate = PreviewVehicleController.FindTemplateByAttribute(categoriesRoot, "ModuleId", moduleId)
		local mount = PreviewVehicleController.GetSlotMount(vehicle, slotId)
		if moduleTemplate and mount then
			local clone = moduleTemplate:Clone()
			clone.Name = "PREVIEW_" .. tostring(slotId) .. "_" .. moduleTemplate.Name
			clone.Parent = installedRoot
			PreviewVehicleController.PivotModuleToSlot(clone, mount)

			local neonOwned = (state.Profile and state.Profile.NeonOwned) or {}
			local previewNeon = state.PreviewNeonSlot == slotId
			PaintClient.ApplyColors(
				clone,
				PreviewVehicleController.ModuleColors(state.Profile, slotId),
				neonOwned[slotId] == true or previewNeon,
				{ Profile = state.Profile }
			)
		end
	end

	return vehicle, nil
end

return PreviewVehicleController
