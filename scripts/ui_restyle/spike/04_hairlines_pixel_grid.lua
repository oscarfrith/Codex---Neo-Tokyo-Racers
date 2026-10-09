-- Pulse spike 04: hairlines and the pixel grid. Play, Client datamodel. Transient ScreenGui PulseSpike_04 only.
-- Draws 1 px and 2 px frames at whole and half offsets, plain and under static UIScale values, and reports
-- the geometry the engine says it used plus every display-scale hint a script can reach.
local ARGS = {
	scales = { 0.667, 1.25, 1.333, 1.5, 2.0 }, -- UIScale columns after the plain column
	originX = 40, -- whole-pixel card origin; try 40.5-equivalent by setting halfOrigin
	originY = 64,
	halfOrigin = false, -- true shifts the whole card by half a logical pixel (through a scale parent)
}
local ID = "04"
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
local UserInputService = game:GetService("UserInputService")
local gui = freshGui()
local camera = workspace.CurrentCamera

local columnCount = 1 + #ARGS.scales
local card = frame(gui, "Card", ARGS.originX, ARGS.originY, 30 + columnCount * 200, 300, INK, 0)
local content = card
if ARGS.halfOrigin then
	-- a 1 px tall parent with a child at scale 0.5 lands the child on a half logical pixel
	local shim = frame(card, "HalfShim", 0, 0, 1, 1, INK, 1)
	content = frame(shim, "HalfContent", 0, 0, 10, 10, INK, 1)
	content.Position = UDim2.new(0.5, 0, 0.5, 0)
end

-- One test pattern in design pixels (about 70 x 96).
local function pattern(parent, report)
	local function line(name, x, y, w, h)
		local f = frame(parent, name, x, y, w, h, WHITE, 0)
		report[#report + 1] = { name = name, inst = f }
		return f
	end
	local function halfLine(name, x, y, w, h, axis)
		-- lands on x+0.5 or y+0.5 without relying on fractional offsets
		local shim = frame(parent, name .. "_Shim", x, y, 1, 1, INK, 1)
		local f = frame(shim, name, 0, 0, w, h, WHITE, 0)
		f.Position = axis == "Y" and UDim2.new(0, 0, 0.5, 0) or UDim2.new(0.5, 0, 0, 0)
		report[#report + 1] = { name = name, inst = f }
		return f
	end
	for i, y in ipairs({ 4, 7, 11, 16 }) do line("H1_y" .. y, 0, y, 60, 1) end
	for i, y in ipairs({ 22, 25, 29, 34 }) do line("H2_y" .. y, 0, y, 60, 2) end
	halfLine("H1_half_y40", 0, 40, 60, 1, "Y")
	halfLine("H2_half_y45", 0, 45, 60, 2, "Y")
	for i, x in ipairs({ 2, 5, 9, 14 }) do line("V1_x" .. x, x, 54, 1, 40) end
	for i, x in ipairs({ 20, 23, 27, 32 }) do line("V2_x" .. x, x, 54, 2, 40) end
	halfLine("V1_half_x40", 40, 54, 1, 40, "X")
	halfLine("V2_half_x46", 46, 54, 2, 40, "X")
	-- panel sample: slate block with the sheet's 2 px top (0.85) and bottom (0.22) hairlines
	local panel = frame(parent, "PanelSample", 54, 54, 16, 40, SLATE, 0.14)
	local top = frame(panel, "Top", 0, 0, 16, 2, WHITE, 0.15)
	local bottom = frame(panel, "Bottom", 0, 38, 16, 2, WHITE, 0.78)
	report[#report + 1] = { name = "PanelTop2", inst = top }
	report[#report + 1] = { name = "PanelBottom2", inst = bottom }
end

local columns = {}
local function column(index, scale)
	local x = 16 + (index - 1) * 200
	text(card, "Tag" .. index, scale and ("UIScale " .. tostring(scale)) or "plain", 12, x, 6, CYAN)
	local holder = frame(content, "Column" .. index, x, 30, 72, 100, INK, 1)
	if scale then
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = scale
		uiScale.Parent = holder
	end
	local report = {}
	pattern(holder, report)
	columns[#columns + 1] = { scale = scale or 1, holder = holder, report = report }
end
column(1, nil)
for i, scale in ipairs(ARGS.scales) do column(i + 1, scale) end

-- Does a fractional offset survive assignment?
local fractional = frame(card, "FractionalOffsetProbe", 0, 0, 4, 1, PINK, 0)
fractional.Position = UDim2.fromOffset(4.5, 280.5)
fractional.Size = UDim2.fromOffset(40.5, 1.5)
-- The kit rule: outside any UIScale, thickness = max(1, round(2 x scale)) at whole positions.
local kitX = 60
for _, scale in ipairs({ 0.667, 1.0, 1.25, 1.333, 1.5, 2.0 }) do
	frame(card, "KitRule_" .. tostring(scale), kitX, 276, 60, math.max(1, math.floor(2 * scale + 0.5)), WHITE, 0)
	kitX += 70
end

waitFrames(4)

out.fractionalOffset = {
	assigned = { 4.5, 280.5, 40.5, 1.5 },
	positionReadBack = { fractional.Position.X.Offset, fractional.Position.Y.Offset },
	sizeReadBack = { fractional.Size.X.Offset, fractional.Size.Y.Offset },
	absPos = v2(fractional.AbsolutePosition),
	absSize = v2(fractional.AbsoluteSize),
}
out.columns = {}
for _, col in ipairs(columns) do
	local items = {}
	local wholeCount, total = 0, 0
	for _, item in ipairs(col.report) do
		local p, s = item.inst.AbsolutePosition, item.inst.AbsoluteSize
		items[#items + 1] = { item.name, r2(p.X), r2(p.Y), r2(s.X), r2(s.Y) }
		total += 1
		local function whole(n) return math.abs(n - math.floor(n + 0.5)) < 0.005 end
		if whole(p.X) and whole(p.Y) and whole(s.X) and whole(s.Y) then wholeCount += 1 end
	end
	out.columns[#out.columns + 1] = { uiScale = col.scale, holderAbsPos = v2(col.holder.AbsolutePosition), wholePixelItems = wholeCount, totalItems = total, items = items }
end
out.itemFormat = "[name, absX, absY, absW, absH] in logical pixels"

-- Display-scale hints. None is documented to give the device-pixel ratio; report whatever answers.
local hints = {}
hints.cameraViewportSize = camera and v2(camera.ViewportSize) or nil
hints.screenGuiAbsoluteSize = v2(gui.AbsoluteSize)
hints.guiInset = try("GetGuiInset", function() local a, b = GuiService:GetGuiInset(); return { v2(a), v2(b) } end)
hints.getScreenResolution = try("GuiService:GetScreenResolution", function() return v2(GuiService:GetScreenResolution()) end)
hints.getResolutionScale = try("GuiService:GetResolutionScale", function() return GuiService:GetResolutionScale() end)
hints.viewportDisplaySize = try("GuiService.ViewportDisplaySize", function() return tostring(GuiService.ViewportDisplaySize) end)
hints.isTenFootInterface = try("GuiService:IsTenFootInterface", function() return GuiService:IsTenFootInterface() end)
hints.mouseLocation = try("GetMouseLocation", function() return v2(UserInputService:GetMouseLocation()) end)
hints.cameraAttributes = try("camera:GetAttributes", function()
	local list = {}
	for key, value in pairs(camera:GetAttributes()) do list[#list + 1] = tostring(key) .. "=" .. tostring(value) end
	return list
end)
hints.userGameSettings = {}
local settingsOk, gameSettings = pcall(function() return UserSettings():GetService("UserGameSettings") end)
if settingsOk and gameSettings then
	for _, name in ipairs({ "SavedQualityLevel", "GraphicsQualityLevel", "Fullscreen", "UiNavigationKeyBindEnabled", "PreferredTextSize", "ReducedMotion", "PreferredTransparency", "FramerateCap" }) do
		local ok, value = pcall(function() return gameSettings[name] end)
		hints.userGameSettings[name] = ok and tostring(value) or ("error: " .. tostring(value))
	end
	hints.fullscreen = try("InFullScreen", function() return gameSettings:InFullScreen() end)
	hints.studioMode = try("InStudioMode", function() return gameSettings:InStudioMode() end)
else
	hints.userGameSettings = "error: " .. tostring(gameSettings)
end
if hints.getScreenResolution and hints.cameraViewportSize then
	hints.screenResolutionOverViewport = { r2(hints.getScreenResolution[1] / hints.cameraViewportSize[1]), r2(hints.getScreenResolution[2] / hints.cameraViewportSize[2]) }
end
out.dpiHints = hints
out.halfOrigin = ARGS.halfOrigin

out.decides = "Primary: no UIScale over chrome, rounded whole logical pixels, hairline = max(1, round(2 x scale)) (bottom KitRule row). It stands if the plain column and the KitRule row are even at 100%, 125% and 150% display scale. If plain whole-pixel lines are already uneven on a scaled display, the fallback is even hairline values only (2 px minimum) and the device capture stays the gate. The UIScale columns show why a canvas scale is not used."
out.needsCapture = "Capture PulseSpike_04 at DEVICE resolution (record the OS display scale and the capture's pixel size against cameraViewportSize - that ratio is the device-pixel ratio no script can read). Zoom in: (1) plain column - are the four 1 px lines identical in thickness and brightness, and the four 2 px lines? (2) the half-offset lines - blurred into two rows, or snapped? (3) each UIScale column - which lines are thicker, thinner, grey or missing? (4) bottom KitRule row - six crisp bars of 1,2,3,3,3,4 px. (5) the pink fractional probe. Repeat with ARGS.halfOrigin = true and on 125% / 150% displays."
return finish()
