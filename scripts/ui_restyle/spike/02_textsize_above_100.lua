-- Pulse spike 02: TextSize above 100, and TextSize 100 inside a static UIScale holder. Play, Client datamodel.
-- Transient ScreenGui PulseSpike_02 only. Run once per view and capture each: view = "sizes", then view = "scale".
local ARGS = {
	view = "sizes", -- "sizes" or "scale" (both are measured on every run; only one is drawn)
	text = "RACE 8",
	waitFontSeconds = 4,
}
local ID = "02"
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

local gui = freshGui()
local font = barlow()
out.fontLoaded = waitFont(font, ARGS.waitFontSeconds)
out.view = ARGS.view

local function view(name)
	local f = frame(gui, name, 30, 60, 0, 0, SLATE, 0)
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Visible = ARGS.view == name
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = f
	return f
end

-- View "sizes": plain labels 60..100, then requests above 100 with read-back.
local sizesView = view("sizes")
local plain = {}
local y = 8
for _, size in ipairs({ 60, 70, 80, 90, 100 }) do
	text(sizesView, "Tag" .. size, tostring(size), 14, 6, y, CYAN)
	plain[#plain + 1] = { size = size, label = text(sizesView, "Plain" .. size, ARGS.text, size, 40, y, WHITE, font) }
	y += size + 6
end
local requests = {}
y = 8
for _, size in ipairs({ 101, 120, 136, 200 }) do
	local label = text(sizesView, "Request" .. size, tostring(size) .. " " .. ARGS.text, 100, 480, y, WHITE, font)
	local setOk, setErr = pcall(function() label.TextSize = size end)
	local readBack = label.TextSize
	requests[#requests + 1] = { requested = size, label = label, setOk = setOk, setErr = (not setOk) and tostring(setErr) or nil, readBack = readBack }
	y += math.max(readBack, 100) + 6
end

-- Other routes past 100: a UITextSizeConstraint maximum, and TextScaled in a tall box.
local hidden = frame(gui, "HiddenProbes", 0, -2000, 900, 400, SLATE, 1)
local constraintLabel = text(hidden, "ConstraintProbe", ARGS.text, 100, 0, 0, WHITE, font)
local constraint = Instance.new("UITextSizeConstraint")
local constraintSetOk = pcall(function() constraint.MaxTextSize = 200 end)
constraint.Parent = constraintLabel
local scaledLabel = Instance.new("TextLabel")
scaledLabel.Name = "TextScaledProbe"
scaledLabel.BackgroundTransparency = 1
scaledLabel.Size = UDim2.fromOffset(900, 260)
scaledLabel.Position = UDim2.fromOffset(0, 120)
scaledLabel.TextScaled = true
scaledLabel.Text = "8"
pcall(function() scaledLabel.FontFace = font end)
scaledLabel.Parent = hidden

-- View "scale": every row is a label inside a holder Frame that carries a static UIScale.
local scaleView = view("scale")
local rows = {
	{ key = "A_plain100", textSize = 100, scale = nil, x = 10, y = 8 },
	{ key = "E_50_x2.0_eff100", textSize = 50, scale = 2.0, x = 10, y = 116 },
	{ key = "F_80_x1.25_eff100", textSize = 80, scale = 1.25, x = 10, y = 224 },
	{ key = "B_100_x1.25_eff125", textSize = 100, scale = 1.25, x = 10, y = 332 },
	{ key = "C_100_x1.5_eff150", textSize = 100, scale = 1.5, x = 470, y = 8 },
	{ key = "D_100_x2.0_eff200", textSize = 100, scale = 2.0, x = 470, y = 170 },
}
for _, row in ipairs(rows) do
	local holder = frame(scaleView, "Holder_" .. row.key, row.x, row.y, 0, 0, SLATE, 1)
	holder.AutomaticSize = Enum.AutomaticSize.XY
	if row.scale then
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = row.scale
		uiScale.Parent = holder
	end
	row.label = text(holder, "Label", ARGS.text, row.textSize, 0, 0, WHITE, font)
	row.holder = holder
	text(scaleView, "Tag_" .. row.key, row.key, 12, row.x, row.y - 2, CYAN)
end

waitFrames(4)

out.sizes = {}
for _, item in ipairs(plain) do
	out.sizes[#out.sizes + 1] = { textSize = item.size, readBack = item.label.TextSize, textBounds = v2(item.label.TextBounds), absSize = v2(item.label.AbsoluteSize), textFits = item.label.TextFits }
end
out.requestsAbove100 = {}
local clamped = true
for _, item in ipairs(requests) do
	local now = item.label.TextSize
	if now > 100 then clamped = false end
	out.requestsAbove100[#out.requestsAbove100 + 1] = { requested = item.requested, setOk = item.setOk, setErr = item.setErr, readBack = now, textBounds = v2(item.label.TextBounds), absSize = v2(item.label.AbsoluteSize) }
end
out.textSizeClampsAt100 = clamped
out.constraint = { setMax200Ok = constraintSetOk, maxTextSizeReadBack = constraint.MaxTextSize, labelTextSize = constraintLabel.TextSize, textBounds = v2(constraintLabel.TextBounds) }
out.textScaled = { boxHeight = 260, textBounds = v2(scaledLabel.TextBounds), textSizeReadBack = scaledLabel.TextSize, note = "textBounds.Y above the plain-100 line height means TextScaled renders past the clamp" }
out.uiScaleRows = {}
for _, row in ipairs(rows) do
	out.uiScaleRows[#out.uiScaleRows + 1] = { key = row.key, textSize = row.textSize, uiScale = row.scale or 1, textBounds = v2(row.label.TextBounds), absSize = v2(row.label.AbsoluteSize), holderAbsSize = v2(row.holder.AbsoluteSize), absPos = v2(row.label.AbsolutePosition) }
end
out.viewport = workspace.CurrentCamera and v2(workspace.CurrentCamera.ViewportSize) or nil
out.decides = "If rows E and F (effective 100 through a holder) are as sharp as row A (plain 100), text is re-rasterised under a static UIScale and titles above 100 may use the text-only holder (rows B, C, D must also be sharp). If E/F are softer than A, titles stop growing at TextSize 100."
out.needsCapture = ARGS.view == "scale"
	and "Capture PulseSpike_02 at device resolution (no downscale) and zoom on glyph edges. Rows A, E, F are the same effective size: compare edge sharpness. Then check B, C, D for blur, stair-stepping or clipped italic overhang. Repeat on a 125% and a 150% display."
	or "Capture PulseSpike_02 (view=sizes). Left column: sizes 60..100 step visibly. Right column: requests 101/120/136/200 - do any draw larger than the 100 row? Then run again with ARGS.view = \"scale\"."
return finish()
