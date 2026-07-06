-- Neo Tokyo Racers - Drive-In Customisation Phase 1 Register-Limit Repair
-- Repairs the first Phase 1 bootstrap handoff after Roblox reported:
-- Out of local registers when trying to allocate okController.
--
-- Run in Roblox Studio Command Bar while the place is open.

local StarterPlayer = game:GetService("StarterPlayer")

local OLD_BLOCK = [=[

-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP
local NTR_DRIVE_IN_CUSTOMISATION_OPEN_EVENT_NAME = "OpenDrivingVehicleCustomisation"

local function NTR_driveInRefreshProfile()
	local result = callServer("GetInitial", {})
	if result.Success ~= false then
		if result.Catalog then State.Catalog = result.Catalog end
		if result.Profile then State.Profile = result.Profile end
	end
	return result
end

local function NTR_openDrivenVehicleModuleShop()
	local selectedVehicleId = State.Profile and State.Profile.CurrentVehicleId
	local refresh = NTR_driveInRefreshProfile()
	if refresh.Profile and refresh.Profile.CurrentVehicleId then
		selectedVehicleId = refresh.Profile.CurrentVehicleId
	end
	if not selectedVehicleId or selectedVehicleId == "" then
		warn("[NTR Drive-In Customisation] No current vehicle id available; opening owned customisation picker instead.")
		NTR_openOwnedCockpitCustomisation()
		return
	end

	local wasDrivingVehicle = currentVehicle
	if wasDrivingVehicle then
		callServer("DespawnVehicle", {})
	end
	stopDriving()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.Sit = false
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	NTR_openGarageWithMode("Customisation")
	task.spawn(function()
		for _ = 1, 80 do
			if UI and UI.Gui and typeof(showStage) == "function" and typeof(renderModuleShop) == "function" and typeof(sortedSlots) == "function" then
				break
			end
			task.wait(0.05)
		end

		local getResult = NTR_driveInRefreshProfile()
		if getResult.Profile and getResult.Profile.CurrentVehicleId then
			selectedVehicleId = getResult.Profile.CurrentVehicleId
		end
		local selectResult = callServer("SelectVehicleInstance", { VehicleId = selectedVehicleId })
		if selectResult.Success == false then
			if UI and UI.Subtitle then
				UI.Subtitle.Text = selectResult.Message or "Could not open build modules."
			end
			NTR_openOwnedCockpitCustomisation()
			return
		end

		State.ShopMode = "Customisation"
		State.ModuleMode = "Slots"
		State.SelectedModuleId = nil
		State.SelectedModuleInstanceId = nil
		State.CustomizeTarget = "ALL"
		State.CustomizeMode = "Colour"
		local firstSlot = sortedSlots()[1]
		State.SelectedSlot = firstSlot and firstSlot.SlotId or State.SelectedSlot or "Engine1"
		if UI and UI.Gui then
			UI.Gui.Enabled = true
		end
		setCameraSection(State.SelectedSlot or "Engine1")
		showStage("ModuleShop")
		renderModuleShop()
	end)
end
]=]

local NEW_BLOCK = [=[

-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP
_G.NTRDriveInCustomisationPhase1 = _G.NTRDriveInCustomisationPhase1 or {}
_G.NTRDriveInCustomisationPhase1.OpenEventName = "OpenDrivingVehicleCustomisation"

function _G.NTRDriveInCustomisationPhase1.RefreshProfile()
	local result = callServer("GetInitial", {})
	if result.Success ~= false then
		if result.Catalog then State.Catalog = result.Catalog end
		if result.Profile then State.Profile = result.Profile end
	end
	return result
end

function _G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	local selectedVehicleId = State.Profile and State.Profile.CurrentVehicleId
	local refresh = _G.NTRDriveInCustomisationPhase1.RefreshProfile()
	if refresh.Profile and refresh.Profile.CurrentVehicleId then
		selectedVehicleId = refresh.Profile.CurrentVehicleId
	end
	if not selectedVehicleId or selectedVehicleId == "" then
		warn("[NTR Drive-In Customisation] No current vehicle id available; opening owned customisation picker instead.")
		NTR_openOwnedCockpitCustomisation()
		return
	end

	if currentVehicle then
		callServer("DespawnVehicle", {})
	end
	stopDriving()
	local humanoid = getHumanoid()
	if humanoid then
		humanoid.Sit = false
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	NTR_openGarageWithMode("Customisation")
	task.spawn(function()
		for _ = 1, 80 do
			if UI and UI.Gui and typeof(showStage) == "function" and typeof(renderModuleShop) == "function" and typeof(sortedSlots) == "function" then
				break
			end
			task.wait(0.05)
		end

		local getResult = _G.NTRDriveInCustomisationPhase1.RefreshProfile()
		if getResult.Profile and getResult.Profile.CurrentVehicleId then
			selectedVehicleId = getResult.Profile.CurrentVehicleId
		end
		local selectResult = callServer("SelectVehicleInstance", { VehicleId = selectedVehicleId })
		if selectResult.Success == false then
			if UI and UI.Subtitle then
				UI.Subtitle.Text = selectResult.Message or "Could not open build modules."
			end
			NTR_openOwnedCockpitCustomisation()
			return
		end

		State.ShopMode = "Customisation"
		State.ModuleMode = "Slots"
		State.SelectedModuleId = nil
		State.SelectedModuleInstanceId = nil
		State.CustomizeTarget = "ALL"
		State.CustomizeMode = "Colour"
		local firstSlot = sortedSlots()[1]
		State.SelectedSlot = firstSlot and firstSlot.SlotId or State.SelectedSlot or "Engine1"
		if UI and UI.Gui then
			UI.Gui.Enabled = true
		end
		setCameraSection(State.SelectedSlot or "Engine1")
		showStage("ModuleShop")
		renderModuleShop()
	end)
end
-- NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END
]=]

local OLD_EVENT = [=[
	local driveInEvent = introFolder:FindFirstChild(NTR_DRIVE_IN_CUSTOMISATION_OPEN_EVENT_NAME)
	if driveInEvent and not driveInEvent:IsA("BindableEvent") then
		warn("[NTR Drive-In Customisation Phase 1] " .. driveInEvent:GetFullName() .. " exists but is " .. driveInEvent.ClassName .. ", expected BindableEvent.")
		return
	end
	if not driveInEvent then
		driveInEvent = Instance.new("BindableEvent")
		driveInEvent.Name = NTR_DRIVE_IN_CUSTOMISATION_OPEN_EVENT_NAME
		driveInEvent.Parent = introFolder
	end
	driveInEvent.Event:Connect(NTR_openDrivenVehicleModuleShop)
]=]

local NEW_EVENT = [=[
	_G.NTRDriveInCustomisationPhase1.Event = introFolder:FindFirstChild(_G.NTRDriveInCustomisationPhase1.OpenEventName)
	if _G.NTRDriveInCustomisationPhase1.Event and not _G.NTRDriveInCustomisationPhase1.Event:IsA("BindableEvent") then
		warn("[NTR Drive-In Customisation Phase 1] " .. _G.NTRDriveInCustomisationPhase1.Event:GetFullName() .. " exists but is " .. _G.NTRDriveInCustomisationPhase1.Event.ClassName .. ", expected BindableEvent.")
		return
	end
	if not _G.NTRDriveInCustomisationPhase1.Event then
		_G.NTRDriveInCustomisationPhase1.Event = Instance.new("BindableEvent")
		_G.NTRDriveInCustomisationPhase1.Event.Name = _G.NTRDriveInCustomisationPhase1.OpenEventName
		_G.NTRDriveInCustomisationPhase1.Event.Parent = introFolder
	end
	_G.NTRDriveInCustomisationPhase1.Event.Event:Connect(function()
		_G.NTRDriveInCustomisationPhase1.OpenDrivenVehicleModuleShop()
	end)
]=]

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local clientRoot = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient")
local scriptObject = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
local source = scriptObject.Source

if string.find(source, "NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP_END", 1, true) then
	print("[NTR Drive-In Customisation Register Repair] Register-safe handoff already installed.")
	return
end

assert(string.find(source, "NTR_DRIVE_IN_CUSTOMISATION_PHASE1_BOOTSTRAP", 1, true), "Drive-in customisation bootstrap marker not found. Run Phase 1 first or refresh the Studio mirror.")

source = replaceOnce(source, OLD_BLOCK, NEW_BLOCK, "old drive-in customisation bootstrap helper block")
source = replaceOnce(source, OLD_EVENT, NEW_EVENT, "old drive-in customisation event hook")

scriptObject.Source = source
print("[NTR Drive-In Customisation Register Repair] Replaced drive-in bootstrap handoff with register-safe table-backed bridge. Restart Play and retest.")
