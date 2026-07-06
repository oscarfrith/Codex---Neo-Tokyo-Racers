-- Neo Tokyo Racers - driving-only parked exit button
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_EXIT_CLIENT
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4B_EXIT_CLIENT_REPAIR
-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_EVENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local garageInvoke = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")

local gui = Instance.new("ScreenGui")
gui.Name = "NTR_FreeRoamVehicleExitButton"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 82
gui.Enabled = true
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "ExitVehicleButton"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -70 or -46)
button.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 132 or 148, UserInputService.TouchEnabled and 38 or 34)
button.BackgroundColor3 = Color3.fromRGB(176, 70, 66)
button.BackgroundTransparency = 0.04
button.BorderSizePixel = 0
button.AutoButtonColor = true
button.Text = "EXIT VEHICLE"
button.TextColor3 = Color3.fromRGB(255, 226, 249)
button.TextSize = UserInputService.TouchEnabled and 10 or 11
button.TextStrokeTransparency = 0.25
button.Font = Enum.Font.GothamBold
button.Visible = false
button.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = button

local function ownerVehicleFromInstance(instance)
	local current = instance
	while current do
		if current:IsA("Model") and current:GetAttribute("OwnerUserId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function ownedVehicleSeat()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil
	end
	local vehicle = ownerVehicleFromInstance(seat)
	if vehicle and tonumber(vehicle:GetAttribute("OwnerUserId")) == player.UserId then
		return seat, vehicle
	end
	return nil
end

local function fireExited()
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local clientRoot = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	local ui = controllers and controllers:FindFirstChild("UI")
	local event = ui and ui:FindFirstChild("FreeRoamVehicleExited")
	if event and event:IsA("BindableEvent") then
		event:Fire()
	end
end

local busy = false
local function exitVehicle()
	if busy then return end
	local _, parkedVehicle = ownedVehicleSeat()
	if not parkedVehicle then return end
	busy = true
	fireExited()
	local ok = pcall(function()
		garageInvoke:InvokeServer("ExitVehicle", {})
	end)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
	end
	task.delay(0.15, function()
		if parkedVehicle and parkedVehicle.Parent then
			parkedVehicle:SetAttribute("DriveReady", true)
			parkedVehicle:SetAttribute("DriverUserId", nil)
			parkedVehicle:SetAttribute("ParkedShowcase", true)
		end
		fireExited()
	end)
	busy = false
	if not ok then
		warn("[NTR] ExitVehicle request failed.")
	end
end

button.MouseButton1Click:Connect(exitVehicle)

RunService.RenderStepped:Connect(function()
	button.Visible = ownedVehicleSeat() ~= nil
end)
