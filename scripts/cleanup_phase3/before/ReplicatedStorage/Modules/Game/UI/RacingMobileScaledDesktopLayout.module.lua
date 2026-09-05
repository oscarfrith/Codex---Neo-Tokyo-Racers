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
		local safeTop = math.max(0, numberAttribute("SafeTop", 84))
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
