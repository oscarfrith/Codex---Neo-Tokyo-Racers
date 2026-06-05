local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local StatBars = {}

function StatBars.Render(parent, stats, baseStats, order)
	local theme = UITheme.Read()
	order = order or { "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost" }
	local y = 0
	for _, name in ipairs(order) do
		local value = stats and stats[name] or 0
		local base = baseStats and baseStats[name]
		UIFactory.Label(parent, name, UDim2.new(0, 112, 0, 22), UDim2.fromOffset(0, y), 11)
		local back = Instance.new("Frame")
		back.Name = name .. "Bar"
		back.BorderSizePixel = 0
		back.BackgroundColor3 = Color3.fromRGB(45, 58, 56)
		back.Size = UDim2.new(1, -126, 0, 10)
		back.Position = UDim2.fromOffset(118, y + 6)
		back.Parent = parent
		UIFactory.Corner(back, 3)

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = theme.Accent
		fill.Size = UDim2.fromScale(math.clamp(value / 160, 0, 1), 1)
		fill.Parent = back
		UIFactory.Corner(fill, 3)

		if typeof(base) == "number" and base ~= value then
			local delta = Instance.new("Frame")
			delta.Name = "PreviewDelta"
			delta.BorderSizePixel = 0
			delta.BackgroundColor3 = value > base and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(220, 70, 70)
			local baseScale = math.clamp(base / 160, 0, 1)
			local valueScale = math.clamp(value / 160, 0, 1)
			delta.Position = UDim2.fromScale(math.min(baseScale, valueScale), 0)
			delta.Size = UDim2.fromScale(math.abs(valueScale - baseScale), 1)
			delta.Parent = back
			UIFactory.Corner(delta, 3)
		end
		y += 25
	end
	return y
end

return StatBars
