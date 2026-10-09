-- Pulse spike 07: ScreenInsets values, TopbarInset coordinate space, GetGuiInset. Play, Client datamodel.
-- Transient ScreenGui PulseSpike_07 only: ONE ScreenGui is cycled through every ScreenInsets value and measured,
-- then left on ARGS.drawInsets with the top-bar rectangle drawn for the capture.
local ARGS = {
	drawInsets = "DeviceSafeInsets", -- the plan's content setting; run again with "None" and "CoreUISafeInsets"
	watchSeconds = 2, -- listens for TopbarInset changes this long
}
local ID = "07"
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

local GuiService = game:GetService("GuiService")
local gui = freshGui()
local camera = workspace.CurrentCamera
local fill = frame(gui, "Fill", 0, 0, 0, 0, PINK, 1)
fill.Size = UDim2.fromScale(1, 1)

local function rectTable(rect)
	return { min = v2(rect.Min), max = v2(rect.Max), size = { r2(rect.Width), r2(rect.Height) } }
end

out.viewport = camera and v2(camera.ViewportSize) or nil
out.defaults = {
	screenInsetsOnNewScreenGui = try("default ScreenInsets", function() local g = Instance.new("ScreenGui"); local v = tostring(g.ScreenInsets); g:Destroy(); return v end),
	safeAreaCompatibility = try("SafeAreaCompatibility", function() return tostring(gui.SafeAreaCompatibility) end),
	clipToDeviceSafeArea = try("ClipToDeviceSafeArea", function() return gui.ClipToDeviceSafeArea end),
}

local names = { "None", "DeviceSafeInsets", "CoreUISafeInsets", "TopbarSafeInsets" }
out.screenInsets = {}
local origins = {}
for _, name in ipairs(names) do
	local row = { exists = false }
	local ok, value = pcall(function() return Enum.ScreenInsets[name] end)
	if ok and value then
		row.exists = true
		local setOk, setErr = pcall(function() gui.ScreenInsets = value end)
		row.setOk = setOk
		row.setErr = (not setOk) and tostring(setErr) or nil
		waitFrames(3)
		row.readBack = tostring(gui.ScreenInsets)
		row.ignoreGuiInset = gui.IgnoreGuiInset
		row.guiAbsPos = v2(gui.AbsolutePosition)
		row.guiAbsSize = v2(gui.AbsoluteSize)
		row.fillAbsPos = v2(fill.AbsolutePosition)
		row.fillAbsSize = v2(fill.AbsoluteSize)
		origins[name] = fill.AbsolutePosition
		row.insetArea = try("GetInsetArea(" .. name .. ")", function() return rectTable(GuiService:GetInsetArea(value)) end)
	else
		row.error = tostring(value)
	end
	out.screenInsets[name] = row
end

-- IgnoreGuiInset mapping
out.ignoreGuiInsetMapping = {}
for _, flag in ipairs({ true, false }) do
	try("IgnoreGuiInset=" .. tostring(flag), function()
		gui.IgnoreGuiInset = flag
		waitFrames(2)
		out.ignoreGuiInsetMapping[tostring(flag)] = { screenInsets = tostring(gui.ScreenInsets), absPos = v2(gui.AbsolutePosition), absSize = v2(gui.AbsoluteSize) }
	end)
end

local topbar = try("GuiService.TopbarInset", function() return GuiService.TopbarInset end)
out.topbarInset = topbar and rectTable(topbar) or nil
out.guiInset = try("GetGuiInset", function() local a, b = GuiService:GetGuiInset(); return { topLeft = v2(a), bottomRight = v2(b) } end)

local changes = 0
local connection = nil
try("TopbarInset signal", function()
	connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() changes += 1 end)
end)

-- Draw: leave the ScreenGui on ARGS.drawInsets and place the top-bar rect using its raw numbers.
local drawValue = try("drawInsets enum", function() return Enum.ScreenInsets[ARGS.drawInsets] end)
if drawValue then try("apply drawInsets", function() gui.ScreenInsets = drawValue end) end
waitFrames(3)
fill.BackgroundTransparency = 0.9
local edge = Instance.new("UIStroke")
edge.Color = PINK
edge.Thickness = 2
edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
pcall(function() edge.BorderStrokePosition = Enum.BorderStrokePosition.Inner end)
edge.Parent = fill
local cornerTag = text(fill, "CornerTag", "PulseSpike_07  ScreenInsets = " .. tostring(gui.ScreenInsets) .. "  (pink edge = this ScreenGui's area)", 14, 8, 0, WHITE)
cornerTag.AnchorPoint = Vector2.new(0, 1)
cornerTag.Position = UDim2.new(0, 8, 1, -8)
if topbar then
	local raw = frame(fill, "TopbarRaw", topbar.Min.X, topbar.Min.Y, topbar.Width, topbar.Height, CYAN, 0.55)
	text(raw, "Tag", "TopbarInset drawn raw in this ScreenGui", 12, 4, 2, INK)
	waitFrames(2)
	out.drawn = {
		screenInsets = tostring(gui.ScreenInsets),
		guiAbsPos = v2(gui.AbsolutePosition),
		rawRectAbsPos = v2(raw.AbsolutePosition),
		rawRectAbsSize = v2(raw.AbsoluteSize),
	}
	-- Where the rect would land if TopbarInset were in each candidate space, expressed in screen space.
	out.topbarInsetIfRelativeTo = {}
	for name, origin in pairs(origins) do
		out.topbarInsetIfRelativeTo[name] = { screenMin = { r2(origin.X + topbar.Min.X), r2(origin.Y + topbar.Min.Y) }, screenMax = { r2(origin.X + topbar.Max.X), r2(origin.Y + topbar.Max.Y) } }
	end
end

local stopAt = os.clock() + math.clamp(ARGS.watchSeconds, 0, 10)
while os.clock() < stopAt do RunService.Heartbeat:Wait() end
if connection then connection:Disconnect() end
out.topbarInsetChangesWhileWatching = changes

out.decides = "Kit.Metrics places top slots below the top bar. If the cyan rect sits exactly in the free gap between the Roblox menu/chat buttons and the right-hand core buttons when drawInsets = DeviceSafeInsets, TopbarInset can be used raw in content ScreenGuis (primary). If it is offset, use the candidate in topbarInsetIfRelativeTo that matches the capture and convert (TopbarInset.Max.Y plus that origin). If no candidate matches, fall back to a fixed top-bar height read from GetGuiInset()."
out.needsCapture = "Capture the whole viewport with PulseSpike_07 showing. (1) The pink edge is the ScreenGui area for " .. ARGS.drawInsets .. ". (2) The cyan rectangle is TopbarInset drawn with its raw numbers: does it sit exactly in the free part of the top bar (between the left core buttons and the right ones), same height as the buttons? Note any offset in px. Run again with ARGS.drawInsets = \"None\" and \"CoreUISafeInsets\". On the device emulator with a notch, repeat to see DeviceSafeInsets move."
return finish()
