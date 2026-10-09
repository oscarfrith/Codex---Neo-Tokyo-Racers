-- Pulse spike 09: the player's Text Size setting (GuiService.PreferredTextSize). Play, Client datamodel.
-- Transient ScreenGui PulseSpike_09 only. Reads only. Run once at each setting (Esc menu > Settings > Text Size, or
-- the Studio device emulator's accessibility controls) and compare the reports: the multiplier for a setting is
-- free.lineHeight divided by the same value at the default setting. Within one run, "constrained" (capped by a
-- UITextSizeConstraint at the requested size) is the unscaled reference, so multiplierVsConstrained is a same-run estimate.
local ARGS = {
	sizes = { 14, 18, 24, 31, 56 }, -- TextSize values to sample (Label floor .. ScreenTitle cap height range)
	watchSeconds = 0, -- >0 keeps listening for a setting change during the call (max 15)
	waitFontSeconds = 4,
}
local ID = "09"
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
local TextService = game:GetService("TextService")
local gui = freshGui()
local font = barlow(Enum.FontWeight.SemiBold)
out.fontLoaded = waitFont(font, ARGS.waitFontSeconds)

local okPref, pref = pcall(function() return GuiService.PreferredTextSize end)
out.preferredTextSize = okPref and tostring(pref) or ("error: " .. tostring(pref))
out.preferredTextSizeValue = okPref and select(2, pcall(function() return pref.Value end)) or nil
out.enumItems = try("Enum.PreferredTextSize", function()
	local list = {}
	for _, item in ipairs(Enum.PreferredTextSize:GetEnumItems()) do list[#list + 1] = item.Name .. "=" .. item.Value end
	return list
end)
out.userGameSettingsPreferredTextSize = select(2, pcall(function() return tostring(UserSettings():GetService("UserGameSettings").PreferredTextSize) end))

local card = frame(gui, "Card", 30, 60, 1100, 60, SLATE, 0)
local SAMPLE = "Text size sample 0123"
out.samples = {}
local y = 10
text(card, "Head", "free                         | UITextSizeConstraint max = size   | TextScaled in a fixed box", 12, 10, y, CYAN)
y += 22
local rows = {}
for _, size in ipairs(ARGS.sizes) do
	local free = text(card, "Free" .. size, SAMPLE, size, 10, y, WHITE, font)
	local constrained = text(card, "Constrained" .. size, SAMPLE, size, 380, y, WHITE, font)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.MinTextSize = 1
	cap.Parent = constrained
	local scaled = Instance.new("TextLabel")
	scaled.Name = "Scaled" .. size
	scaled.BackgroundTransparency = 1
	scaled.TextColor3 = WHITE
	scaled.TextXAlignment = Enum.TextXAlignment.Left
	scaled.TextScaled = true
	scaled.Text = SAMPLE
	scaled.FontFace = font
	scaled.Position = UDim2.fromOffset(750, y)
	scaled.Size = UDim2.fromOffset(330, size)
	scaled.Parent = card
	rows[#rows + 1] = { size = size, free = free, constrained = constrained, scaled = scaled }
	y += math.floor(size * 2.2) + 8
end
card.Size = UDim2.fromOffset(1100, y + 6)
waitFrames(4)

local function measure()
	local list = {}
	for _, row in ipairs(rows) do
		local fb, cb, sb = row.free.TextBounds, row.constrained.TextBounds, row.scaled.TextBounds
		local async = select(2, pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = SAMPLE
			params.Font = font
			params.Size = row.size
			params.Width = 10000
			return TextService:GetTextBoundsAsync(params)
		end))
		list[#list + 1] = {
			textSize = row.size,
			textSizeReadBack = row.free.TextSize,
			free = v2(fb),
			constrained = v2(cb),
			textScaled = v2(sb),
			getTextBoundsAsync = typeof(async) == "Vector2" and v2(async) or tostring(async),
			freeLineHeightPerTextSize = r2(fb.Y / row.size),
			multiplierVsConstrained = cb.Y > 0 and r2(fb.Y / cb.Y) or nil,
			widthMultiplierVsConstrained = cb.X > 0 and r2(fb.X / cb.X) or nil,
			textFitsFree = row.free.TextFits,
		}
	end
	return list
end
out.samples = measure()

if ARGS.watchSeconds > 0 and okPref then
	local changes = {}
	local started = os.clock()
	local connection = nil
	try("PreferredTextSize signal", function()
		connection = GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(function()
			if #changes < 8 then changes[#changes + 1] = { t = r2(os.clock() - started), value = tostring(GuiService.PreferredTextSize) } end
		end)
	end)
	local stopAt = started + math.clamp(ARGS.watchSeconds, 0, 15)
	while os.clock() < stopAt do RunService.Heartbeat:Wait() end
	if connection then connection:Disconnect() end
	out.changesWhileWatching = changes
	if #changes > 0 then
		waitFrames(4)
		out.samplesAfterChange = measure()
		out.preferredTextSizeAfter = tostring(GuiService.PreferredTextSize)
	end
end

out.decides = "If multiplierVsConstrained is 1.0 at every setting, experience text is not scaled and body containers need no extra room (record it; keep the Largest pass). If it grows, the largest value seen at Largest sizes every body-role container, and display roles keep their UITextSizeConstraint (the constrained column must stay at 1.0 x). If PreferredTextSize errors, the setting is not readable and only the capture pass at Largest remains."
out.needsCapture = "Capture PulseSpike_09 at each Text Size setting. Left column should grow with the setting, middle column (constraint) and right column (TextScaled) should not. Note any clipped or overlapping rows at Largest."
return finish()
