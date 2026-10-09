-- Pulse spike 10: PreferredInput and the input flags Kit.Metrics will read. Play, Client datamodel.
-- Transient ScreenGui PulseSpike_10 only (it holds the listener log as attributes; nothing is drawn but one status line).
-- mode = "block": listen for ARGS.seconds inside this call (drive input from a second tool call, or by hand).
-- mode = "start": connect listeners that keep logging after this call returns; mode = "read": return the log.
--   (If "read" shows no entries after input was sent, connections did not outlive the call: use "block".)
local ARGS = {
	mode = "block", -- "block" | "start" | "read"
	seconds = 8, -- for "block" (max 20)
}
local ID = "10"
-- ---- shared spike prelude (identical in every spike file; each file is self-contained) ----
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return '{"spike":"' .. ID .. '","error":"no LocalPlayer: run in Play on the Client datamodel"}' end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
if not playerGui then return '{"spike":"' .. ID .. '","error":"no PlayerGui"}' end

local out = { spike = ID, errors = {} }
local function try(label, fn, ...)
	local r = table.pack(pcall(fn, ...))
	if not r[1] then out.errors[label] = tostring(r[2]); return nil end
	return r[2]
end
local function r2(n) return math.floor(n * 100 + 0.5) / 100 end
local function v2(v) return { r2(v.X), r2(v.Y) } end
local function finish()
	if next(out.errors) == nil then out.errors = nil end
	local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
	return ok and json or ('{"spike":"' .. ID .. '","error":"JSON encode failed"}')
end
local function waitFrames(n) for _ = 1, n or 2 do RunService.Heartbeat:Wait() end end
local function freshGui(order)
	local old = playerGui:FindFirstChild("PulseSpike_" .. ID)
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PulseSpike_" .. ID
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order or 20000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end
local SLATE, WHITE, INK = Color3.fromRGB(14, 13, 26), Color3.fromRGB(243, 240, 255), Color3.fromRGB(7, 6, 13)
local PINK, VIOLET, CYAN, YELLOW = Color3.fromRGB(255, 45, 149), Color3.fromRGB(154, 61, 255), Color3.fromRGB(34, 228, 255), Color3.fromRGB(255, 228, 51)
local BARLOW = "rbxassetid://12187372847"
local function barlow(weight) return Font.new(BARLOW, weight or Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic) end
local function frame(parent, name, x, y, w, h, color, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or SLATE
	f.BackgroundTransparency = transparency or 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end
local function text(parent, name, str, size, x, y, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = color or WHITE
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Position = UDim2.fromOffset(x, y)
	l.Text = str
	if font then pcall(function() l.FontFace = font end) else l.Font = Enum.Font.RobotoMono end
	l.Parent = parent
	return l
end
-- Yields until the face can be measured (or the time runs out). True when it loaded.
local function waitFont(font, seconds)
	local done, ok = false, false
	task.spawn(function()
		ok = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = "H"
			params.Font = font
			params.Size = 20
			params.Width = 1000
			return game:GetService("TextService"):GetTextBoundsAsync(params)
		end)
		done = true
	end)
	local stop = os.clock() + (seconds or 4)
	while not done and os.clock() < stop do RunService.Heartbeat:Wait() end
	return done and ok
end
-- ---- end of prelude ----

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
out.mode = ARGS.mode

local function snapshot()
	local s = {}
	s.preferredInput = select(2, pcall(function() return tostring(UserInputService.PreferredInput) end))
	for _, name in ipairs({ "TouchEnabled", "KeyboardEnabled", "MouseEnabled", "GamepadEnabled", "AccelerometerEnabled", "GyroscopeEnabled", "VREnabled" }) do
		local ok, value = pcall(function() return UserInputService[name] end)
		if ok then s[name] = value else s[name] = "error: " .. tostring(value) end
	end
	s.lastInputType = select(2, pcall(function() return tostring(UserInputService:GetLastInputType()) end))
	s.connectedGamepads = select(2, pcall(function()
		local list = {}
		for _, pad in ipairs(UserInputService:GetConnectedGamepads()) do list[#list + 1] = tostring(pad) end
		return list
	end))
	s.viewportDisplaySize = select(2, pcall(function() return tostring(GuiService.ViewportDisplaySize) end))
	s.isTenFoot = select(2, pcall(function() return GuiService:IsTenFootInterface() end))
	return s
end

if ARGS.mode == "read" then
	local holder = playerGui:FindFirstChild("PulseSpike_" .. ID)
	out.now = snapshot()
	if not holder then
		out.error = "no PulseSpike_10: run mode = \"start\" first"
		return finish()
	end
	out.log = {}
	local count = holder:GetAttribute("LogCount") or 0
	for i = 1, math.min(count, 40) do out.log[#out.log + 1] = holder:GetAttribute("Log" .. i) end
	out.logCount = count
	out.listenersAlive = count > 0
	out.needsCapture = "none"
	return finish()
end

local gui = freshGui()
text(gui, "Status", "PulseSpike_10 listening for input changes (" .. ARGS.mode .. ")", 14, 40, 70, CYAN)
out.before = snapshot()
out.enumItems = try("Enum.PreferredInput", function()
	local list = {}
	for _, item in ipairs(Enum.PreferredInput:GetEnumItems()) do list[#list + 1] = item.Name end
	return list
end)

local started = os.clock()
local count = 0
local memory = {}
local function log(kind, value)
	count += 1
	local line = string.format("%.2f %s %s", os.clock() - started, kind, tostring(value))
	if #memory < 40 then memory[#memory + 1] = line end
	if count <= 40 then
		pcall(function()
			gui:SetAttribute("Log" .. count, line)
			gui:SetAttribute("LogCount", count)
		end)
	end
end

local connections = {}
out.listeners = {}
local function listen(label, getSignal, handler)
	local ok, err = pcall(function() connections[#connections + 1] = getSignal():Connect(handler) end)
	out.listeners[label] = ok and "connected" or ("error: " .. tostring(err))
end
listen("PreferredInput changed", function() return UserInputService:GetPropertyChangedSignal("PreferredInput") end, function()
	log("PreferredInput", UserInputService.PreferredInput)
end)
listen("LastInputTypeChanged", function() return UserInputService.LastInputTypeChanged end, function(inputType)
	log("LastInputType", inputType)
end)
listen("GamepadConnected", function() return UserInputService.GamepadConnected end, function(pad) log("GamepadConnected", pad) end)
listen("GamepadDisconnected", function() return UserInputService.GamepadDisconnected end, function(pad) log("GamepadDisconnected", pad) end)
listen("TouchEnabled changed", function() return UserInputService:GetPropertyChangedSignal("TouchEnabled") end, function()
	log("TouchEnabled", UserInputService.TouchEnabled)
end)

if ARGS.mode == "start" then
	out.note = "listeners left connected; send keyboard, mouse, gamepad or touch input, then run mode = \"read\""
	out.needsCapture = "none"
	return finish()
end

local stopAt = started + math.clamp(ARGS.seconds, 1, 20)
while os.clock() < stopAt do RunService.Heartbeat:Wait() end
for _, connection in ipairs(connections) do connection:Disconnect() end
out.after = snapshot()
out.events = memory
out.eventCount = count
out.lastInputTypeChurn = "count of LastInputType lines against PreferredInput lines shows why Input reads PreferredInput (plan 3.1)"
out.decides = "Input answer = PreferredInput if the property reads and its changed signal fires when the device in use changes. If it errors, fall back to LastInputTypeChanged mapped to three classes with a 0.5 s hold. Arrangement (TouchDrive) stays TouchEnabled either way. Two cases still need real hardware or the device emulator: a touch laptop (expect TouchEnabled = true, PreferredInput = KeyboardAndMouse until the screen is touched) and a phone with a gamepad (expect PreferredInput = Gamepad after a button press, TouchEnabled still true)."
out.needsCapture = "none (data only). Record which device or emulator profile the run used."
return finish()
