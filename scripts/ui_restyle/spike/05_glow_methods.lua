-- Pulse spike 05: three glow methods around a selected tile. Play, Client datamodel. Transient ScreenGui PulseSpike_05 only.
-- A: UIShadow (may not exist). B: 9-slice ImageLabel placeholder. C: stacked UIStroke + UIGradient.
-- The placeholder image is the game's existing soft radial glow VFX texture (scripts/hover_feel/vfx/texture_ids.json
-- "glow_soft" = 77716974295974). No soft-glow UI image exists in Config.UI or the Classic sources, and SliceCenter is
-- used nowhere in Classic. Its pixel size is not readable from script, so sliceCenter below assumes 256 x 256.
local ARGS = {
	glowImage = "rbxassetid://77716974295974",
	sliceCenter = { 112, 112, 144, 144 }, -- assumes a 256 px radial texture; adjust if the capture shows a seam
	glowReach = 46, -- logical px the glow extends past the tile (sheet value)
	tileW = 315,
	tileH = 242,
	tileScale = 0.8, -- draw the three tiles smaller so the card fits 1280 x 720
	waitFontSeconds = 4,
	waitImageSeconds = 5,
}
local ID = "05"
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

local W = math.floor(ARGS.tileW * ARGS.tileScale + 0.5)
local H = math.floor(ARGS.tileH * ARGS.tileScale + 0.5)
local REACH = math.floor(ARGS.glowReach * ARGS.tileScale + 0.5)
local GAP = REACH * 2 + 40
local card = frame(gui, "Card", 30, 60, 3 * W + 4 * GAP, H + 2 * REACH + 90, INK, 0)

local function tile(index, title)
	local x = GAP + (index - 1) * (W + GAP)
	local y = REACH + 50
	text(card, "Tag" .. index, title, 14, x, 10, CYAN)
	-- unselected neighbour edge, to judge how far the glow spills
	frame(card, "Neighbour" .. index, x + W + 12, y, 24, H, SLATE, 0.14)
	-- holder is the fixed layout cell; glow goes behind the tile inside it
	local holder = frame(card, "Cell" .. index, x, y, W, H, INK, 1)
	local t = frame(holder, "Tile", 0, 0, W, H, WHITE, 0)
	t.ZIndex = 2
	local base = frame(t, "BaseLine", 0, H - 6, W, 6, PINK, 0)
	base.ZIndex = 3
	local name = text(t, "Name", "LANCER GT", 27, 14, H - 50, INK, font)
	name.ZIndex = 3
	local sub = text(t, "Sub", "SELECTED", 14, 14, H - 68, INK, barlow(Enum.FontWeight.SemiBold))
	sub.ZIndex = 3
	return holder, t
end

local function setProp(report, inst, name, value)
	local ok, err = pcall(function() inst[name] = value end)
	local read = nil
	if ok then
		local rok, rvalue = pcall(function() return inst[name] end)
		read = rok and tostring(rvalue) or ("read error: " .. tostring(rvalue))
	end
	report[name] = ok and ("ok -> " .. tostring(read)) or ("error: " .. tostring(err))
	return ok
end

-- A. UIShadow
do
	local holder, t = tile(1, "A  UIShadow")
	local report = { exists = false }
	local ok, shadow = pcall(function() return Instance.new("UIShadow") end)
	if ok and shadow then
		report.exists = true
		report.props = {}
		-- property names are tried blind; the report says which the engine accepted
		setProp(report.props, shadow, "Color", PINK)
		setProp(report.props, shadow, "Transparency", 0.35)
		for _, name in ipairs({ "BlurRadius", "Blur", "Radius", "Spread", "Size", "Thickness" }) do
			setProp(report.props, shadow, name, REACH)
		end
		if not setProp(report.props, shadow, "Offset", UDim2.fromOffset(0, 0)) then
			report.props.OffsetVector2 = pcall(function() shadow.Offset = Vector2.new(0, 0) end) and "ok" or "error"
		end
		setProp(report.props, shadow, "ShowBehindParent", true)
		setProp(report.props, shadow, "Inset", false)
		report.mode = select(2, pcall(function() return tostring(shadow.Mode) end))
		local parentOk, parentErr = pcall(function() shadow.Parent = t end)
		report.parented = parentOk
		report.parentErr = (not parentOk) and tostring(parentErr) or nil
		report.instances = 1
	else
		report.createError = tostring(shadow)
		text(holder, "Missing", "UIShadow not available", 14, 8, 8, PINK).ZIndex = 5
	end
	out.uiShadow = report
end

-- B. 9-slice ImageLabel
do
	local holder = tile(2, "B  9-slice ImageLabel (placeholder image)")
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow9Slice"
	glow.BackgroundTransparency = 1
	glow.Image = ARGS.glowImage
	glow.ImageColor3 = PINK
	glow.ImageTransparency = 0.25
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(ARGS.sliceCenter[1], ARGS.sliceCenter[2], ARGS.sliceCenter[3], ARGS.sliceCenter[4])
	glow.Position = UDim2.fromOffset(-REACH, -REACH)
	glow.Size = UDim2.fromOffset(W + 2 * REACH, H + 2 * REACH)
	glow.ZIndex = 1
	glow.Parent = holder
	-- slice corners are image pixels; SliceScale maps them onto the reach
	local corner = ARGS.sliceCenter[1]
	glow.SliceScale = REACH / corner
	local stop = os.clock() + ARGS.waitImageSeconds
	while not glow.IsLoaded and os.clock() < stop do RunService.Heartbeat:Wait() end
	out.nineSlice = {
		image = ARGS.glowImage,
		isLoaded = glow.IsLoaded,
		sliceCenter = ARGS.sliceCenter,
		sliceScale = r2(glow.SliceScale),
		absSize = v2(glow.AbsoluteSize),
		instances = 1,
		note = "placeholder radial VFX texture; the real asset is a purpose-drawn white 9-slice. Judge the method (falloff, corners, cost), not this image.",
	}
end

-- C. UIStroke + UIGradient
do
	local holder, t = tile(3, "C  stacked UIStroke + UIGradient")
	local report = { strokes = 0, gradients = 0, errors = {} }
	local layers = { { 4, 0.35 }, { 10, 0.6 }, { 18, 0.78 }, { 28, 0.9 } }
	for i, layer in ipairs(layers) do
		local ok, err = pcall(function()
			local stroke = Instance.new("UIStroke")
			stroke.Name = "GlowStroke" .. i
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Color = WHITE
			stroke.Thickness = math.max(1, math.floor(layer[1] * ARGS.tileScale + 0.5))
			stroke.Transparency = layer[2]
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(PINK, VIOLET)
			gradient.Parent = stroke
			stroke.Parent = t
		end)
		if ok then report.strokes += 1; report.gradients += 1 else report.errors[#report.errors + 1] = tostring(err) end
	end
	waitFrames(2)
	local present = 0
	for _, child in ipairs(t:GetChildren()) do if child:IsA("UIStroke") then present += 1 end end
	report.strokesPresentOnTile = present
	report.instances = report.strokes + report.gradients
	if #report.errors == 0 then report.errors = nil end
	out.strokeGradient = report
end

out.tile = { w = W, h = H, reach = REACH }
out.viewport = workspace.CurrentCamera and v2(workspace.CurrentCamera.ViewportSize) or nil
out.decides = "Default stays the 9-slice (B): it works on every client. UIShadow (A) becomes the default only if it exists, renders a soft coloured glow here AND is later seen on a live phone and PC client. C is the reference for why strokes are not used (hard bands, 8 instances, stroke budget). Studio alone cannot promote A."
out.needsCapture = "Capture PulseSpike_05. Compare the three white selected tiles on the ink card: (A) is there a soft pink glow at all, is it behind the tile only, any jagged corners; (B) even falloff on all four sides, no visible seams where slices meet, corners not pinched (adjust ARGS.sliceCenter if so); (C) visible banding between stroke layers. Note how far each glow spills onto the grey neighbour strip to the right (rail padding must reserve it)."
return finish()
