-- Pulse spike 06: gauge arc revealed by a rotating UIGradient, against a segmented fallback. Play, Client datamodel.
-- Transient ScreenGui PulseSpike_06 only. Runs a sweep for ARGS.seconds and counts property writes per frame.
-- Ring image: no gauge ring exists in Config.UI or Classic sources. The placeholder is the game's existing ring
-- VFX texture (scripts/hover_feel/vfx/texture_ids.json "shock_ring" = 98670230449915). If it fails to load the
-- gradient method is still measured on a plain white square (the reveal is the same; only the shape differs).
local ARGS = {
	ringImage = "rbxassetid://98670230449915",
	seconds = 8, -- sweep duration (keep the call under 25 s)
	holdFraction = 0.62, -- fill left on screen for the capture
	size = 300, -- logical px
	quantumDegrees = 0.5, -- write-on-change step (plan 5.1 rule 5)
	segments = 48, -- fallback arc segment count
	waitImageSeconds = 5,
}
local ID = "06"
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
local SIZE = ARGS.size
local card = frame(gui, "Card", 30, 60, SIZE * 2 + 150, SIZE + 90, INK, 0)
text(card, "TagA", "A  ring image + rotating UIGradient (2 halves)", 14, 30, 8, CYAN)
text(card, "TagB", "B  fallback: " .. ARGS.segments .. " rotated frames", 14, SIZE + 100, 8, CYAN)

-- A. Two half windows, each showing its half of one full-size image whose gradient hides one half-plane.
local gaugeA = frame(card, "GaugeA", 30, 50, SIZE, SIZE, INK, 1)
local transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local function track(parent)
	local image = Instance.new("ImageLabel")
	image.Name = "Track"
	image.BackgroundTransparency = 1
	image.Image = ARGS.ringImage
	image.ImageColor3 = WHITE
	image.ImageTransparency = 0.8
	image.Size = UDim2.fromOffset(SIZE, SIZE)
	image.Parent = parent
	return image
end
local trackImage = track(gaugeA)
local function half(name, isRight)
	local window = frame(gaugeA, name, isRight and SIZE / 2 or 0, 0, SIZE / 2, SIZE, INK, 1)
	window.ClipsDescendants = true
	window.ZIndex = 2
	local image = Instance.new("ImageLabel")
	image.Name = "Fill"
	image.BackgroundTransparency = 1
	image.Image = ARGS.ringImage
	image.ImageColor3 = CYAN
	image.Size = UDim2.fromOffset(SIZE, SIZE)
	image.Position = UDim2.fromOffset(isRight and -SIZE / 2 or 0, 0)
	image.Parent = window
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = transparency
	gradient.Rotation = isRight and 0 or 180
	gradient.Parent = image
	return image, gradient
end
local rightImage, rightGradient = half("RightHalf", true)
local leftImage, leftGradient = half("LeftHalf", false)

local stop = os.clock() + ARGS.waitImageSeconds
while not rightImage.IsLoaded and os.clock() < stop do RunService.Heartbeat:Wait() end
out.ringImage = { image = ARGS.ringImage, isLoaded = rightImage.IsLoaded }
if not rightImage.IsLoaded then
	-- measure the method on a plain square instead
	for _, image in ipairs({ rightImage, leftImage, trackImage }) do
		image.Image = ""
		image.BackgroundTransparency = image == trackImage and 0.8 or 0
		image.BackgroundColor3 = image == trackImage and WHITE or CYAN
	end
	out.ringImage.fallbackShape = "plain square (image did not load)"
end

-- B. Segments: thin frames around a circle; a fill change recolours only the segments that cross the edge.
local gaugeB = frame(card, "GaugeB", SIZE + 100, 50, SIZE, SIZE, INK, 1)
local segments = {}
local radius = SIZE / 2 - 14
for i = 1, ARGS.segments do
	local angle = (i - 0.5) / ARGS.segments * 2 * math.pi
	local seg = Instance.new("Frame")
	seg.Name = string.format("Seg%02d", i)
	seg.BorderSizePixel = 0
	seg.AnchorPoint = Vector2.new(0.5, 0.5)
	seg.Size = UDim2.fromOffset(math.max(2, math.floor(2 * math.pi * radius / ARGS.segments * 0.62)), 22)
	seg.Position = UDim2.fromOffset(math.floor(SIZE / 2 + math.sin(angle) * radius + 0.5), math.floor(SIZE / 2 - math.cos(angle) * radius + 0.5))
	seg.Rotation = math.deg(angle)
	seg.BackgroundColor3 = WHITE
	seg.BackgroundTransparency = 0.8
	seg.Parent = gaugeB
	segments[i] = seg
end

-- Outside counters: every property change on the animated instances, counted per frame.
local changedA, changedB = 0, 0
local connections = {}
for _, inst in ipairs({ rightGradient, leftGradient, rightImage, leftImage }) do
	connections[#connections + 1] = inst.Changed:Connect(function() changedA += 1 end)
end
for _, seg in ipairs(segments) do
	connections[#connections + 1] = seg.Changed:Connect(function() changedB += 1 end)
end

local lastRight, lastLeft, lastLit = -1, -1, 0
local writesA, writesB = 0, 0
local function apply(fraction)
	local wA, wB = 0, 0
	local degrees = math.clamp(fraction, 0, 1) * 360
	degrees = math.floor(degrees / ARGS.quantumDegrees + 0.5) * ARGS.quantumDegrees
	local right = math.min(degrees, 180)
	local left = 180 + math.max(degrees - 180, 0)
	if right ~= lastRight then rightGradient.Rotation = right; lastRight = right; wA += 1 end
	if left ~= lastLeft then leftGradient.Rotation = left; lastLeft = left; wA += 1 end
	local lit = math.floor(math.clamp(fraction, 0, 1) * ARGS.segments + 0.5)
	if lit ~= lastLit then
		local from, to = math.min(lit, lastLit) + 1, math.max(lit, lastLit)
		for i = from, to do
			local on = i <= lit
			segments[i].BackgroundColor3 = on and CYAN or WHITE
			segments[i].BackgroundTransparency = on and 0 or 0.8
			wB += 2
		end
		lastLit = lit
	end
	writesA += wA
	writesB += wB
	return wA, wB
end

local frames, maxA, maxB, framesWithWriteA, framesWithWriteB = 0, 0, 0, 0, 0
local dtSum, dtMax = 0, 0
local duration = math.clamp(ARGS.seconds, 1, 18)
local started = os.clock()
while true do
	local dt = RunService.RenderStepped:Wait()
	local elapsed = os.clock() - started
	if elapsed >= duration then break end
	-- two full sweeps, 0 -> 1 -> 0 -> 1 -> 0, eased so the speed varies like a real gauge
	local phase = (elapsed / duration) * 4
	local tri = phase % 2
	if tri > 1 then tri = 2 - tri end
	local eased = tri * tri * (3 - 2 * tri)
	local wA, wB = apply(eased)
	frames += 1
	if wA > 0 then framesWithWriteA += 1 end
	if wB > 0 then framesWithWriteB += 1 end
	maxA = math.max(maxA, wA)
	maxB = math.max(maxB, wB)
	dtSum += dt
	dtMax = math.max(dtMax, dt)
end
apply(ARGS.holdFraction)
waitFrames(2)
for _, connection in ipairs(connections) do connection:Disconnect() end

out.sweep = { seconds = r2(duration), frames = frames, meanDtMs = frames > 0 and r2(dtSum / frames * 1000) or nil, maxDtMs = r2(dtMax * 1000) }
out.gradientReveal = {
	instances = 7, -- 2 windows, 2 fills, 2 gradients, 1 track (tick ring and needle not included)
	writesPerFrameMax = maxA,
	writesPerFrameMean = frames > 0 and r2(writesA / frames) or nil,
	framesWithAWrite = framesWithWriteA,
	totalWrites = writesA,
	changedEventsSeenFromOutside = changedA,
	quantumDegrees = ARGS.quantumDegrees,
}
out.segmentFallback = {
	instances = ARGS.segments,
	writesPerFrameMax = maxB,
	writesPerFrameMean = frames > 0 and r2(writesB / frames) or nil,
	framesWithAWrite = framesWithWriteB,
	totalWrites = writesB,
	changedEventsSeenFromOutside = changedB,
}
out.classicReference = "Classic gauge: 32 gauge writes per frame while driving (plan 5.2, from source)"
out.holdFraction = ARGS.holdFraction
out.decides = "Primary (gradient reveal) stands if writesPerFrameMax is 1-2 and the capture shows no seam at 12 and 6 o'clock and a clean leading edge. If a seam or a soft/aliased edge shows, use the segmented arc (B): it writes only on a segment change. Either way the live-layer budget of median 16 writes per frame is met."
out.needsCapture = "Capture PulseSpike_06 at device resolution with the fill held at " .. tostring(ARGS.holdFraction) .. ". Gauge A: look for a gap or double-bright line where the two halves meet (12 and 6 o'clock), a hard or stair-stepped leading edge, and any bleed of cyan on the unfilled side. The fill should start at 12 o'clock and run clockwise; if it is mirrored, that is a sign convention only. Gauge B: segment gaps even, rotated edges not jagged."
return finish()
