local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TOUCH = UserInputService.TouchEnabled

local mobileState
pcall(function()
	mobileState = require(ReplicatedStorage
		:WaitForChild("HOVER_RACING_V2_KIT")
		:WaitForChild("CLIENT_MODULES")
		:WaitForChild("Controllers")
		:WaitForChild("MobileDriveInputState"))
end)

local hidden = setmetatable({}, { __mode = "k" })
local connections = setmetatable({}, { __mode = "k" })
local scanTimer = 0

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function mobileGui()
	return playerGui:FindFirstChild("HOVER_RACING_V67_MobileDriveControlsUI")
end

local function mobileRoot()
	local gui = mobileGui()
	return gui and gui:FindFirstChild("Root")
end

local function isOwnMobileUi(item)
	local gui = mobileGui()
	local root = mobileRoot()
	return item == gui
		or item == root
		or (gui and item:IsDescendantOf(gui))
		or (root and item:IsDescendantOf(root))
end

local function isRobloxTouchUi(item)
	local current = item
	while current and current ~= playerGui do
		if current.Name == "TouchGui" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function garageVisible()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled then
			local name = lower(gui.Name)
			if string.find(name, "garage", 1, true) or string.find(name, "dealership", 1, true) then
				return true
			end
			local garageRoot = gui:FindFirstChild("GarageRoot", true) or gui:FindFirstChild("DealershipRoot", true)
			if garageRoot and garageRoot:IsA("GuiObject") and garageRoot.Visible then
				return true
			end
		end
	end
	return false
end

local function suppressActive()
	if not TOUCH then return false end
	if garageVisible() then return false end
	local root = mobileRoot()
	if root and root.Visible then return true end
	return mobileState and mobileState.IsDriving == true
end

local function textLooksDesktopDrive(item)
	if not (item:IsA("TextLabel") or item:IsA("TextButton")) then return false end
	local text = lower(item.Text)
	if text == "" then return false end
	return string.find(text, "wasd", 1, true) ~= nil
		or string.find(text, "shift", 1, true) ~= nil
		or string.find(text, "space", 1, true) ~= nil
		or string.find(text, "r reset", 1, true) ~= nil
		or string.find(text, "speed", 1, true) ~= nil
		or string.find(text, "drift", 1, true) ~= nil
		or string.find(text, "mph", 1, true) ~= nil
end

local function nameLooksDesktopDrive(item)
	local name = lower(item.Name)
	return string.find(name, "desktopdrive", 1, true) ~= nil
		or string.find(name, "drivepanel", 1, true) ~= nil
		or string.find(name, "speedpanel", 1, true) ~= nil
		or string.find(name, "speedhud", 1, true) ~= nil
		or string.find(name, "boostpanel", 1, true) ~= nil
		or string.find(name, "boosthud", 1, true) ~= nil
		or string.find(name, "controlshint", 1, true) ~= nil
		or string.find(name, "desktop", 1, true) ~= nil and string.find(name, "drive", 1, true) ~= nil
end

local function hasDesktopDriveContent(item)
	for _, descendant in ipairs(item:GetDescendants()) do
		if descendant:IsA("GuiObject") and not isOwnMobileUi(descendant) then
			local name = lower(descendant.Name)
			if nameLooksDesktopDrive(descendant)
				or string.find(name, "speedlabel", 1, true) ~= nil
				or string.find(name, "mphlabel", 1, true) ~= nil
				or string.find(name, "driftlabel", 1, true) ~= nil
				or string.find(name, "boostfill", 1, true) ~= nil
				or textLooksDesktopDrive(descendant) then
				return true
			end
		end
	end
	return false
end

local function nearestPanel(item)
	local current = item
	local best = item
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not isOwnMobileUi(current) and not isRobloxTouchUi(current) then
			local name = lower(current.Name)
			if name ~= "drivehud" and name ~= "root" then
				best = current
			end
			if current:IsA("Frame") and name ~= "drivehud" and name ~= "root" then
				local styled = current.BackgroundTransparency < 1
					or current:FindFirstChildOfClass("UICorner") ~= nil
					or current:FindFirstChildOfClass("UIStroke") ~= nil
				if styled then
					return current
				end
			end
		end
		current = current.Parent
	end
	return best
end

local function addTarget(item)
	if not (item and item:IsA("GuiObject")) then return end
	if isOwnMobileUi(item) or isRobloxTouchUi(item) then return end
	if hidden[item] == nil then
		hidden[item] = item.Visible
	end
	item.Visible = false
	if not connections[item] then
		connections[item] = item:GetPropertyChangedSignal("Visible"):Connect(function()
			if suppressActive() and item.Parent and item.Visible then
				item.Visible = false
			end
		end)
	end
end

local function clearDead()
	for item in pairs(hidden) do
		if not item.Parent or isOwnMobileUi(item) then
			hidden[item] = nil
			if connections[item] then
				connections[item]:Disconnect()
				connections[item] = nil
			end
		end
	end
end

local function restoreTargets()
	for item, oldVisible in pairs(hidden) do
		if item.Parent and not isOwnMobileUi(item) then
			item.Visible = oldVisible
		end
		hidden[item] = nil
		if connections[item] then
			connections[item]:Disconnect()
			connections[item] = nil
		end
	end
end

local function scan()
	if not suppressActive() then
		restoreTargets()
		return
	end
	clearDead()
	for _, item in ipairs(playerGui:GetDescendants()) do
		if item:IsA("GuiObject") and not isOwnMobileUi(item) and not isRobloxTouchUi(item) then
			if nameLooksDesktopDrive(item) then
				addTarget(item)
			elseif textLooksDesktopDrive(item) then
				addTarget(nearestPanel(item))
			elseif item:IsA("Frame") and hasDesktopDriveContent(item) then
				addTarget(item)
			end
		end
	end
end

local function forceHidden()
	if not suppressActive() then return end
	for item in pairs(hidden) do
		if item.Parent and not isOwnMobileUi(item) and item.Visible then
			item.Visible = false
		end
	end
end

local function blankAcceleratorText()
	local gui = mobileGui()
	local accel = gui and gui:FindFirstChild("AcceleratorPedal", true)
	if not accel then return end
	if accel:IsA("TextButton") then accel.Text = "" end
	for _, descendant in ipairs(accel:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local text = lower(descendant.Text)
			if text == "accel" or text == "accelerate" then
				descendant.Text = ""
			end
		end
	end
end

playerGui.DescendantAdded:Connect(function(descendant)
	if not TOUCH then return end
	if descendant:IsA("GuiObject") then
		task.defer(function()
			blankAcceleratorText()
			if suppressActive() then scan(); forceHidden() end
		end)
	end
end)

RunService:BindToRenderStep("HOVER_RACING_V71_MobilePcHudSuppressor", 2200, function(dt)
	if not TOUCH then return end
	blankAcceleratorText()
	scanTimer += dt
	if scanTimer >= 0.08 then
		scanTimer = 0
		scan()
	end
	forceHidden()
end)

RunService.Heartbeat:Connect(function()
	if TOUCH then
		forceHidden()
	end
end)

task.defer(function()
	blankAcceleratorText()
	scan()
	forceHidden()
end)
