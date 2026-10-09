-- Pulse spike 03: OpenTypeFeatures = "tnum" (tabular digits). Play, Client datamodel. Transient ScreenGui PulseSpike_03 only.
local ARGS = {
	feature = "tnum",
	size = 100, -- measuring size
	drawSize = 40,
	waitFontSeconds = 4,
}
local ID = "03"
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
local card = frame(gui, "Card", 30, 60, 1180, 330, SLATE, 0)

local faces = {
	{ key = "BarlowExtraBoldItalic", font = barlow(Enum.FontWeight.ExtraBold), feature = ARGS.feature },
	{ key = "BarlowSemiBoldItalic", font = barlow(Enum.FontWeight.SemiBold), feature = ARGS.feature },
	{ key = "RobotoCondensedBoldItalic", font = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic), feature = ARGS.feature },
	-- control: the announcement names "zero" on Builder Sans, so this shows whether the property does anything at all
	{ key = "BuilderSansBold_zero", font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal), feature = "zero" },
}

local probeHolder = frame(gui, "HiddenProbes", 0, -2000, 10, 10, SLATE, 1)
local function digitWidths(label)
	local widths, lo, hi = {}, nil, nil
	for d = 0, 9 do
		label.Text = string.rep(tostring(d), 10)
		waitFrames(1)
		local w = r2(label.TextBounds.X / 10)
		widths[#widths + 1] = w
		lo = lo and math.min(lo, w) or w
		hi = hi and math.max(hi, w) or w
	end
	return widths, r2(hi - lo)
end

out.faces = {}
for index, face in ipairs(faces) do
	local result = { feature = face.feature }
	result.loaded = waitFont(face.font, ARGS.waitFontSeconds)
	local x = 14 + (index - 1) * 290

	-- capture blocks: ones above zeros, plain on the first row, feature on the second
	text(card, "Tag" .. index, face.key, 12, x, 6, CYAN)
	text(card, "PlainOnes" .. index, "1111111111", ARGS.drawSize, x, 26, WHITE, face.font)
	text(card, "PlainZeros" .. index, "0000000000", ARGS.drawSize, x, 26 + ARGS.drawSize, WHITE, face.font)
	text(card, "FeatTag" .. index, "OpenTypeFeatures = " .. face.feature, 12, x, 170, YELLOW)
	local featOnes = text(card, "FeatOnes" .. index, "1111111111", ARGS.drawSize, x, 190, WHITE, face.font)
	local featZeros = text(card, "FeatZeros" .. index, "0000000000", ARGS.drawSize, x, 190 + ARGS.drawSize, WHITE, face.font)

	local plainProbe = text(probeHolder, "Plain" .. index, "0", ARGS.size, 0, 0, WHITE, face.font)
	local featProbe = text(probeHolder, "Feat" .. index, "0", ARGS.size, 0, 0, WHITE, face.font)

	result.propertyReadBefore = try(face.key .. ".read", function() return tostring(featProbe.OpenTypeFeatures) end)
	local setOk, setErr = pcall(function()
		featProbe.OpenTypeFeatures = face.feature
		featOnes.OpenTypeFeatures = face.feature
		featZeros.OpenTypeFeatures = face.feature
	end)
	result.setOk = setOk
	result.setErr = (not setOk) and tostring(setErr) or nil
	result.propertyReadAfter = try(face.key .. ".readAfter", function() return tostring(featProbe.OpenTypeFeatures) end)
	result.errorProperty = try(face.key .. ".OpenTypeFeaturesError", function() return tostring(featProbe.OpenTypeFeaturesError) end)
	waitFrames(3)

	local before, spreadBefore = digitWidths(plainProbe)
	local after, spreadAfter = digitWidths(featProbe)
	result.digitWidthBefore, result.spreadBefore = before, spreadBefore
	result.digitWidthAfter, result.spreadAfter = after, spreadAfter
	local changed = false
	for i = 1, 10 do if math.abs(before[i] - after[i]) > 0.05 then changed = true end end
	result.featureChangedWidths = changed
	result.tabularBefore = spreadBefore < 0.06
	result.tabularAfter = spreadAfter < 0.06
	out.faces[face.key] = result
end

out.decides = "Barlow tabularAfter=true on both weights means tnum works and the cash chip may use it (still keep the fixed chip width). Otherwise: fixed-width chip for cash, BigNumber sprites for large numbers, as planned. The Builder Sans 'zero' control only shows whether the property is live (a width change is not expected; look for a slashed zero in the capture)."
out.needsCapture = "Capture PulseSpike_03. In each block the row of ones sits above the row of zeros, left-aligned. Top = plain, bottom = with the feature. If the right-hand ends line up, digits are tabular. Fourth block: bottom zeros should be slashed if OpenTypeFeatures is live."
return finish()
