-- Neo Tokyo Racers - Cockpit Customisation Zone Client
-- Installed by Dealership / Customisation Split Phase 2.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local OPEN_EVENT_NAME = "OpenOwnedCockpitCustomisation"

local function waitForRoot()
	while true do
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			return root
		end
		task.wait(0.1)
	end
end

local function waitForTrigger()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:WaitForChild("Dealership")
	local customisation = dealership:WaitForChild("Customisation")
	local trigger = customisation:WaitForChild("CustomisationDeskTrigger")
	if trigger:IsA("BasePart") then
		return trigger
	end
	warn("[NTR Customisation Zone] CustomisationDeskTrigger is not a BasePart.")
	return nil
end

local function openCustomisation()
	local event = script.Parent:FindFirstChild(OPEN_EVENT_NAME)
	if not event then
		event = script.Parent:WaitForChild(OPEN_EVENT_NAME, 5)
	end
	if event and event:IsA("BindableEvent") then
		event:Fire()
	else
		warn("[NTR Customisation Zone] " .. OPEN_EVENT_NAME .. " was not available.")
	end
end

local root = waitForRoot()
local trigger = waitForTrigger()
if not trigger then
	return
end

local wasInside = false
local dismissedUntilLeave = false

while true do
	if not root.Parent then
		root = waitForRoot()
	end
	local enabled = trigger:GetAttribute("Enabled") ~= false
	local activationDistance = tonumber(trigger:GetAttribute("ActivationDistance")) or 12
	local distance = (root.Position - trigger.Position).Magnitude
	local inside = enabled and distance <= activationDistance
	local reopenDistance = math.max(activationDistance + 3, activationDistance * 1.5)

	if dismissedUntilLeave and distance >= reopenDistance then
		dismissedUntilLeave = false
		wasInside = false
	end

	if inside and not wasInside and not dismissedUntilLeave then
		openCustomisation()
		dismissedUntilLeave = true
	end

	wasInside = inside
	task.wait(0.15)
end
