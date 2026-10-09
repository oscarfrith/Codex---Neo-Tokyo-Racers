-- Owns the scale, class, band, arrangement, input, safe-area and top-bar answers and the only listeners for them; owns no ScreenGui, slot or text size.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics. Requires: Tokens.
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Tokens = require(script.Parent.Tokens)

local Metrics = {}

export type Context = {
	Class: string,
	Band: string,
	Arrangement: string,
	Input: string,
	Scale: number,
	Size: Vector2,
	Origin: Vector2,
	TopBarHeight: number,
	TopBarKeepOut: Vector2,
	Px: (design: number) -> number,
	Hair: (design: number) -> number,
	Touch: (drawn: number) -> number,
	Changed: RBXScriptSignal,
}

-- Guards the snap against float error (0.85 x 20 must floor to 17). From API.md 6.
local SNAP_EPSILON = 1e-6

local INPUT_NAMES = {
	KeyboardAndMouse = "KeyboardAndMouse",
	Gamepad = "Gamepad",
	MicroGamepad = "Gamepad",
	Touch = "Touch",
}

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.Metrics] " .. message)
end

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- Pure: no service, no state. WasCompact gives the leave threshold its hysteresis.
function Metrics.Compute(input: { SafeSize: Vector2, TouchEnabled: boolean, PreferredInput: string, WasCompact: boolean? })
	assert(type(input) == "table" and typeof(input.SafeSize) == "Vector2", "[Pulse.Metrics] Compute needs SafeSize")
	local scale = Tokens.Scale
	local width, height = input.SafeSize.X, input.SafeSize.Y

	local compact = height < scale.CompactEnterHeight or width < scale.CompactEnterWidth
	if not compact and input.WasCompact then
		compact = not (height >= scale.CompactLeaveHeight and width >= scale.CompactEnterWidth)
	end

	local band = "Normal"
	if width < scale.NarrowBelow then
		band = "Narrow"
	elseif width > scale.WideAbove then
		band = "Wide"
	end

	local value
	if compact then
		local raw = clamp(height / scale.CompactRefHeight, scale.CompactMin, scale.CompactMax)
		value = math.floor(raw * scale.CompactSteps + SNAP_EPSILON) / scale.CompactSteps
	else
		local raw = math.min(height / scale.RegularRefHeight, width / scale.RegularRefWidth)
		raw = clamp(raw, scale.RegularMin, scale.RegularMax)
		value = math.floor(raw * scale.RegularSteps + SNAP_EPSILON) / scale.RegularSteps
	end

	local preferred = input.PreferredInput
	if typeof(preferred) == "EnumItem" then
		preferred = preferred.Name
	end

	return {
		Class = compact and "Compact" or "Regular",
		Band = band,
		Arrangement = input.TouchEnabled and "TouchDrive" or "Standard",
		Input = INPUT_NAMES[preferred] or "KeyboardAndMouse",
		Scale = value,
	}
end

-- The helpers read the context's fields at call time, so they stay right after the screen context changes.
local function newContext(changed: RBXScriptSignal)
	local ctx = {}
	ctx.Changed = changed
	ctx.Px = function(design: number): number
		if design == 0 then
			return 0
		end
		local value = math.round(math.abs(design) * ctx.Scale)
		if value < 1 then
			value = 1
		end
		return design < 0 and -value or value
	end
	ctx.Hair = function(design: number): number
		return math.max(1, math.round(design * ctx.Scale))
	end
	ctx.Touch = function(drawn: number): number
		local size = ctx.Px(drawn)
		if ctx.Input == "Touch" or ctx.Class == "Compact" then
			return math.max(size, Tokens.Space.TouchMin)
		end
		return size
	end
	return ctx
end

local screen -- the one live context; created by Screen()
local screenEvent -- BindableEvent behind screen.Changed
local fixedEvent -- shared by every Fixed context; never fired
local safeGui -- ScreenGui given to AttachSafeArea
local listening = false
local cameraConnection
local guiConnections = {}

local generation = 0
local settling = false
local inputQueued = false
local textDirty = false

local function readSafeArea()
	local gui = safeGui
	if gui and gui.Parent then
		local size = gui.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			return size, gui.AbsolutePosition
		end
	end
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize, Vector2.zero
	end
	return Vector2.zero, Vector2.zero
end

-- Writes the screen context's fields; returns whether layout answers and whether Input changed.
local function refresh()
	local ctx = screen
	local size, origin = readSafeArea()
	local inset = GuiService.TopbarInset
	local topBarHeight = inset.Height
	local keepOut = Vector2.new(inset.Min.X, inset.Height)
	local computed = Metrics.Compute({
		SafeSize = size,
		TouchEnabled = UserInputService.TouchEnabled,
		PreferredInput = UserInputService.PreferredInput.Name,
		WasCompact = ctx.Class == "Compact",
	})

	local layoutChanged = ctx.Class ~= computed.Class
		or ctx.Band ~= computed.Band
		or ctx.Arrangement ~= computed.Arrangement
		or ctx.Scale ~= computed.Scale
		or ctx.Size ~= size
		or ctx.Origin ~= origin
		or ctx.TopBarHeight ~= topBarHeight
		or ctx.TopBarKeepOut ~= keepOut
	local inputChanged = ctx.Input ~= computed.Input

	ctx.Class = computed.Class
	ctx.Band = computed.Band
	ctx.Arrangement = computed.Arrangement
	ctx.Input = computed.Input
	ctx.Scale = computed.Scale
	ctx.Size = size
	ctx.Origin = origin
	ctx.TopBarHeight = topBarHeight
	ctx.TopBarKeepOut = keepOut
	return layoutChanged, inputChanged
end

local function flush()
	generation += 1 -- cancels a pending settle
	settling = false
	local forced = textDirty
	textDirty = false
	local layoutChanged, inputChanged = refresh()
	layoutChanged = layoutChanged or forced
	if layoutChanged or inputChanged then
		screenEvent:Fire({ Layout = layoutChanged, Input = inputChanged })
	end
end

-- Every layout source restarts the settle timer, so Changed fires once after a resize stops.
local function scheduleLayout()
	generation += 1
	local mine = generation
	settling = true
	task.delay(Tokens.Scale.ResizeSettle, function()
		if mine == generation then
			flush()
		end
	end)
end

local function scheduleTextSize()
	textDirty = true
	scheduleLayout()
end

-- An input change is not debounced; if a resize is settling it rides along with that flush.
local function scheduleInput()
	if settling or inputQueued then
		return
	end
	inputQueued = true
	task.defer(function()
		inputQueued = false
		if not settling then
			flush()
		end
	end)
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(scheduleLayout)
	end
end

local function watchSafeGui()
	for _, connection in guiConnections do
		connection:Disconnect()
	end
	table.clear(guiConnections)
	local gui = safeGui
	if gui then
		table.insert(guiConnections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
		table.insert(guiConnections, gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleLayout))
		table.insert(guiConnections, gui.AncestryChanged:Connect(scheduleLayout))
	end
end

-- Session-long service listeners; there is no owner scope to release them and none is needed.
local function listen()
	listening = true
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		scheduleLayout()
	end)
	watchCamera()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(scheduleLayout)
	GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(scheduleTextSize)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(scheduleInput)
	watchSafeGui()
end

function Metrics.Screen(): Context
	if screen then
		return screen
	end
	local event = Instance.new("BindableEvent")
	event.Name = "PulseMetricsChanged"
	screenEvent = event
	screen = newContext(event.Event)
	refresh()
	-- In Edit (the pure tests) the context is a snapshot: nothing is left connected in the session.
	if RunService:IsRunning() then
		listen()
	end
	return screen
end

function Metrics.AttachSafeArea(gui: ScreenGui)
	assert(typeof(gui) == "Instance" and gui:IsA("ScreenGui"), "[Pulse.Metrics] AttachSafeArea needs a ScreenGui")
	if safeGui == gui then
		return
	end
	if safeGui and safeGui.Parent then
		warnOnce("AttachSafeArea called again with " .. gui.Name .. "; keeping " .. safeGui.Name)
		return
	end
	safeGui = gui
	if screen then
		if listening then
			watchSafeGui()
		end
		flush()
	end
end

function Metrics.Fixed(spec: { Size: Vector2, TouchEnabled: boolean?, Input: string?, TopBarHeight: number?, TopBarKeepOut: Vector2? }): Context
	assert(type(spec) == "table" and typeof(spec.Size) == "Vector2", "[Pulse.Metrics] Fixed needs Size")
	if not fixedEvent then
		fixedEvent = Instance.new("BindableEvent")
		fixedEvent.Name = "PulseMetricsFixed"
	end
	local touch = spec.TouchEnabled == true
	local computed = Metrics.Compute({
		SafeSize = spec.Size,
		TouchEnabled = touch,
		PreferredInput = spec.Input or (touch and "Touch" or "KeyboardAndMouse"),
		WasCompact = false,
	})
	local topBarHeight = spec.TopBarHeight or 0
	local ctx = newContext(fixedEvent.Event)
	ctx.Class = computed.Class
	ctx.Band = computed.Band
	ctx.Arrangement = computed.Arrangement
	ctx.Input = computed.Input
	ctx.Scale = computed.Scale
	ctx.Size = spec.Size
	ctx.Origin = Vector2.zero
	ctx.TopBarHeight = topBarHeight
	ctx.TopBarKeepOut = spec.TopBarKeepOut or Vector2.new(0, topBarHeight)
	return ctx
end

-- Instance keys in a weak table can drop while the instance is alive, so the entry is strong and is
-- removed when the root is destroyed. Bound roots must be destroyed, not just dropped.
local bound = {}

function Metrics.Bind(root: GuiObject, ctx: Context)
	assert(typeof(root) == "Instance", "[Pulse.Metrics] Bind needs an Instance root")
	assert(type(ctx) == "table" and type(ctx.Px) == "function", "[Pulse.Metrics] Bind needs a Context")
	local first = bound[root] == nil
	bound[root] = ctx
	if first then
		root.Destroying:Connect(function()
			bound[root] = nil
		end)
	end
end

-- Build time only: walks the ancestors once.
function Metrics.Of(instance: Instance): Context
	local node = instance
	while node do
		local ctx = bound[node]
		if ctx then
			return ctx
		end
		node = node.Parent
	end
	return Metrics.Screen()
end

return Metrics
