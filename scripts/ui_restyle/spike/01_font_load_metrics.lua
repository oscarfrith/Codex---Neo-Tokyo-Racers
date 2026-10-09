-- Pulse spike 01: font load signals and metrics. Play, Client datamodel. Transient ScreenGui PulseSpike_01 only.
-- A cold-cache answer is only valid on the FIRST run of a fresh Studio session; later runs report a warm cache.
local ARGS = {
	waitSeconds = 8, -- upper bound for the load watch (keep the whole call under 25 s)
	size = 100, -- measuring TextSize (the engine clamps at 100)
	drawSize = 56, -- TextSize of the capture rows
	barlow = "rbxassetid://12187372847",
	robotoCondensed = "rbxasset://fonts/families/RobotoCondensed.json",
	capRatios = { Barlow = 0.583, RobotoCondensed = 0.607 }, -- audit values, drawn as reference bars
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")

local ID = "01"
local player = Players.LocalPlayer
if not player then return '{"spike":"01","error":"no LocalPlayer: run in Play on the Client datamodel"}' end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
if not playerGui then return '{"spike":"01","error":"no PlayerGui"}' end

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
	return ok and json or '{"spike":"01","error":"JSON encode failed"}'
end

local old = playerGui:FindFirstChild("PulseSpike_" .. ID)
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "PulseSpike_" .. ID
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local SLATE, WHITE, PINK, CYAN = Color3.fromRGB(14, 13, 26), Color3.fromRGB(243, 240, 255), Color3.fromRGB(255, 45, 149), Color3.fromRGB(34, 228, 255)

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundColor3 = SLATE
card.BorderSizePixel = 0
card.Position = UDim2.fromOffset(40, 70)
card.Size = UDim2.fromOffset(1100, 5 * (ARGS.drawSize + 14) + 20)
card.Parent = gui

local faces = {
	{ key = "BarlowExtraBoldItalic", family = ARGS.barlow, weight = Enum.FontWeight.ExtraBold, cap = ARGS.capRatios.Barlow },
	{ key = "BarlowSemiBoldItalic", family = ARGS.barlow, weight = Enum.FontWeight.SemiBold, cap = ARGS.capRatios.Barlow },
	{ key = "BarlowBlackItalic", family = ARGS.barlow, weight = Enum.FontWeight.Heavy, cap = ARGS.capRatios.Barlow },
	{ key = "RobotoCondensedBoldItalic", family = ARGS.robotoCondensed, weight = Enum.FontWeight.Bold, cap = ARGS.capRatios.RobotoCondensed },
	-- control: a family id that cannot resolve, to learn what the fallback face measures
	{ key = "ControlBogusFamily", family = "rbxassetid://1", weight = Enum.FontWeight.ExtraBold, cap = 0.5 },
}

local t0 = os.clock()
local function since() return r2(os.clock() - t0) end

-- 1. Labels first, so the TextBounds signal is the first thing that asks for each face.
for index, face in ipairs(faces) do
	face.result = { boundsChanges = {}, boundsAtCreate = nil }
	face.font = try(face.key .. ".Font.new", Font.new, face.family, face.weight, Enum.FontStyle.Italic)
	local label = Instance.new("TextLabel")
	label.Name = face.key
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	label.TextSize = ARGS.drawSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Position = UDim2.fromOffset(46, 10 + (index - 1) * (ARGS.drawSize + 14))
	label.Text = "HCUSTOMISE 0123456789 1111111111 0000000000"
	if face.font then try(face.key .. ".FontFace", function() label.FontFace = face.font end) end
	label.Parent = card
	face.label = label
	face.result.boundsAtCreate = v2(label.TextBounds)
	label:GetPropertyChangedSignal("TextBounds"):Connect(function()
		local list = face.result.boundsChanges
		if #list < 6 then list[#list + 1] = { t = since(), bounds = v2(label.TextBounds) } end
	end)
	-- cap-height reference bar: its height is drawSize x the audit cap ratio; compare with the leading H
	local bar = Instance.new("Frame")
	bar.Name = face.key .. "_CapBar"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = index % 2 == 0 and CYAN or PINK
	bar.Size = UDim2.fromOffset(26, math.floor(ARGS.drawSize * face.cap + 0.5))
	bar.Position = UDim2.fromOffset(12, 10 + (index - 1) * (ARGS.drawSize + 14))
	bar.Parent = card
	face.bar = bar
end

-- 2. PreloadAsync on the Font-bearing label, and 3. GetTextBoundsAsync, each timed on its own thread.
local pending = 0
for _, face in ipairs(faces) do
	local result = face.result
	pending += 2
	task.spawn(function()
		local statuses = {}
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync({ face.label }, function(assetId, status)
				if #statuses < 6 then statuses[#statuses + 1] = tostring(assetId) .. "=" .. tostring(status) end
			end)
		end)
		result.preloadLabel = { t = since(), ok = ok, err = (not ok) and tostring(err) or nil, callbacks = statuses }
		pending -= 1
	end)
	task.spawn(function()
		if not face.font then result.getTextBoundsAsync = { ok = false, err = "no Font" }; pending -= 1; return end
		local ok, value = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = "CUSTOMISE"
			params.Font = face.font
			params.Size = ARGS.size
			params.Width = 10000
			return TextService:GetTextBoundsAsync(params)
		end)
		result.getTextBoundsAsync = { t = since(), ok = ok, err = (not ok) and tostring(value) or nil, bounds = ok and v2(value) or nil }
		pending -= 1
	end)
end
-- string form of PreloadAsync on the family id itself
pending += 1
task.spawn(function()
	local statuses = {}
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ ARGS.barlow }, function(assetId, status)
			statuses[#statuses + 1] = tostring(assetId) .. "=" .. tostring(status)
		end)
	end)
	out.preloadFamilyString = { t = since(), ok = ok, err = (not ok) and tostring(err) or nil, callbacks = statuses }
	pending -= 1
end)

local deadline = t0 + math.min(ARGS.waitSeconds, 14)
while pending > 0 and os.clock() < deadline do RunService.Heartbeat:Wait() end
-- settle: let late TextBounds changes land
for _ = 1, 20 do RunService.Heartbeat:Wait() end
out.threadsStillPendingAtDeadline = pending
out.watchSeconds = since()

-- 4. Metrics with whatever is loaded now.
local probe = Instance.new("TextLabel")
probe.Name = "MeasureProbe"
probe.BackgroundTransparency = 1
probe.TextTransparency = 1
probe.AutomaticSize = Enum.AutomaticSize.XY
probe.TextSize = ARGS.size
probe.Position = UDim2.fromOffset(0, -400)
probe.Parent = gui

local function labelWidth(font, text)
	probe.FontFace = font
	probe.Text = text
	RunService.Heartbeat:Wait()
	return probe.TextBounds
end
local function asyncWidth(font, text)
	local ok, value = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = font
		params.Size = ARGS.size
		params.Width = 10000
		return TextService:GetTextBoundsAsync(params)
	end)
	return ok and value or nil
end

local strings = { "CUSTOMISE", "0123456789", "1111111111", "0000000000", "H" }
out.faces = {}
local control
for _, face in ipairs(faces) do
	local result = face.result
	result.boundsFinal = v2(face.label.TextBounds)
	result.metrics = {}
	if face.font then
		-- skip the yielding call when the timed one failed or never returned (it could block this thread)
		local canAsync = result.getTextBoundsAsync ~= nil and result.getTextBoundsAsync.ok == true
		for _, text in ipairs(strings) do
			local a = labelWidth(face.font, text)
			local b = canAsync and asyncWidth(face.font, text) or nil
			result.metrics[text] = { textBounds = v2(a), getTextBoundsAsync = b and v2(b) or "error", equal = b ~= nil and math.abs(a.X - b.X) < 0.51 and math.abs(a.Y - b.Y) < 0.51 }
		end
		local digits = {}
		for d = 0, 9 do digits[#digits + 1] = r2(labelWidth(face.font, string.rep(tostring(d), 10)).X / 10) end
		result.digitWidthAt100 = digits
		local lo, hi = math.huge, 0
		for _, w in ipairs(digits) do lo = math.min(lo, w); hi = math.max(hi, w) end
		result.digitsTabular = (hi - lo) < 0.06
		result.tenOnesVsTenZeros = { result.metrics["1111111111"].textBounds[1], result.metrics["0000000000"].textBounds[1] }
		result.lineHeightPerTextSize = r2(result.metrics["H"].textBounds[2] / ARGS.size)
		result.capBarPixelsAtDrawSize = face.bar.AbsoluteSize.Y
	end
	result.fontReadBack = try(face.key .. ".readback", function() return tostring(face.label.FontFace) end)
	out.faces[face.key] = result
	if face.key == "ControlBogusFamily" then control = result end
end
probe:Destroy()

-- "Loaded" verdict: a real face must not measure the same as the bogus-family control.
if control and control.metrics and control.metrics["CUSTOMISE"] then
	local cw = control.metrics["CUSTOMISE"].textBounds[1]
	for key, result in pairs(out.faces) do
		if key ~= "ControlBogusFamily" and result.metrics and result.metrics["CUSTOMISE"] then
			result.differsFromFallbackControl = math.abs(result.metrics["CUSTOMISE"].textBounds[1] - cw) > 0.6
		end
	end
end
local eb, sb, bl = out.faces.BarlowExtraBoldItalic, out.faces.BarlowSemiBoldItalic, out.faces.BarlowBlackItalic
if eb and sb and bl and eb.metrics and sb.metrics and bl.metrics then
	local a, b, c = eb.metrics["CUSTOMISE"].textBounds[1], sb.metrics["CUSTOMISE"].textBounds[1], bl.metrics["CUSTOMISE"].textBounds[1]
	out.barlowWeightsDistinct = { extraBoldVsSemiBold = math.abs(a - b) > 0.6, blackVsExtraBold = math.abs(c - a) > 0.6, widths = { sb = b, eb = a, black = c } }
end

out.viewport = workspace.CurrentCamera and v2(workspace.CurrentCamera.ViewportSize) or nil
out.howToRead = "Signal works = it reported a time and (for TextBounds) at least one change after create. boundsChanges empty with differsFromFallbackControl=true means the face was already cached (warm run)."
out.needsCapture = "Capture PulseSpike_01 card at device resolution. Check: (1) rows 1-3 are three visibly different Barlow italic weights and row 4 is Roboto Condensed; row 5 is the fallback control; (2) the coloured bar left of each row is as tall as the capital H beside it (cap ratio 0.583 Barlow / 0.607 Roboto Condensed; if the H is taller or shorter, correct CapRatio) and where the H sits vertically against the bar (BaselineShift); (3) italic overhang on the last glyph is not clipped."
return finish()
