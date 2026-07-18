local RunService = game:GetService("RunService")

local asset = script.Parent
local startingPivot = asset:GetPivot()

local degreesPerSecond = 10
local angle = 0

RunService.Heartbeat:Connect(function(deltaTime)
	angle = (angle + math.rad(degreesPerSecond) * deltaTime) % (math.pi * 2)

	asset:PivotTo(
		startingPivot * CFrame.Angles(0, angle, 0)
	)
end)print("Hello world!")
