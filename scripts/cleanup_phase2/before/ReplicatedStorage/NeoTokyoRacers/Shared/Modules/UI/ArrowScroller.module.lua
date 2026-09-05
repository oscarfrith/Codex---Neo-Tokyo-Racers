local RunService = game:GetService("RunService")
local UIFactory = require(script.Parent:WaitForChild("UIFactory"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))

local ArrowScroller = {}

function ArrowScroller.Attach(parent, scroller, axis, step)
	local theme = UITheme.Read()
	axis = axis or "X"
	step = step or 240

	local back = UIFactory.Button(parent, axis == "X" and "<" or "^", UDim2.fromOffset(24, 42), UDim2.fromScale(0, 0.5), theme.Panel)
	local forward = UIFactory.Button(parent, axis == "X" and ">" or "v", UDim2.fromOffset(24, 42), UDim2.fromScale(1, 0.5), theme.Panel)
	back.AnchorPoint = Vector2.new(0, 0.5)
	forward.AnchorPoint = Vector2.new(1, 0.5)
	back.ZIndex = (parent.ZIndex or 1) + 5
	forward.ZIndex = back.ZIndex

	local function maxCanvas()
		if axis == "X" then
			return math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteWindowSize.X)
		end
		return math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
	end

	local function update()
		local max = maxCanvas()
		local current = axis == "X" and scroller.CanvasPosition.X or scroller.CanvasPosition.Y
		back.Visible = current > 1
		forward.Visible = current < max - 1
	end

	local function scroll(direction)
		local current = scroller.CanvasPosition
		local max = maxCanvas()
		if axis == "X" then
			scroller.CanvasPosition = Vector2.new(math.clamp(current.X + direction * step, 0, max), current.Y)
		else
			scroller.CanvasPosition = Vector2.new(current.X, math.clamp(current.Y + direction * step, 0, max))
		end
		update()
	end

	local connections = {
		back.MouseButton1Click:Connect(function() scroll(-1) end),
		forward.MouseButton1Click:Connect(function() scroll(1) end),
		scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(update),
		scroller:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update),
		scroller:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update),
		RunService.RenderStepped:Connect(update),
	}
	update()

	return {
		Back = back,
		Forward = forward,
		Destroy = function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			back:Destroy()
			forward:Destroy()
		end,
	}
end

return ArrowScroller
