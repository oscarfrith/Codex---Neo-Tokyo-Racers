-- Pulse spike 11b: local ProximityPrompt Style = Custom, the three behaviours in plan 7.2. Play, Client datamodel.
-- Transient ScreenGui PulseSpike_11b only (a status line, and the remembered original Style as attributes).
-- The ONLY write to a game instance is a client-local Style on one prompt, restored at the end (or by
-- restoreOnly = true, or by spike_cleanup.lua). Never fires a remote, never triggers the prompt, never writes Enabled.
-- Source facts: TimeTrialServer.ensurePrompt writes prompt.Style = Default at 1298 (create) and 1311 (every pass);
-- ensureAllPrompts(false) runs every 3 s (1414-1417, task.wait(3) at 1416). The server value never changes, so no
-- property update should replicate and the local Custom should hold: this spike measures that.
--
-- Three runs answer the three behaviours:
--   R1 "survives re-assert": stand near a start zone, defaults below. Look at reverts (expect 0 over >= 4 server passes).
--   R2 "Custom before first show": stand FAR from the zone (prompt not showing), leaveCustom = true; then drive in,
--       capture (no engine prompt should appear), then run restoreOnly = true.
--   R3 "PromptShown steady while seated": sit in a car parked inside a start zone, zone centre off screen if
--       possible, seconds = 18. Look at shownTarget / hiddenTarget and the event log.
local ARGS = {
	promptPath = "", -- full path from 11a (GetFullName). "" = nearest RaceEntryPrompt to the character
	seconds = 14, -- watch time with Style = Custom (max 20; 3 s server pass => 14 s covers 4 passes)
	baselineSeconds = 1.5, -- watch before the write, original Style
	reassert = true, -- on a revert, write Custom again so every server pass can be counted
	leaveCustom = false, -- true: do not restore at the end (run R2)
	restoreOnly = false, -- true: restore the remembered Style and exit
	sampleEvery = 0.5,
}
local ID = "11b"
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

local ProximityPromptService = game:GetService("ProximityPromptService")
local CUSTOM = Enum.ProximityPromptStyle.Custom

local function resolve(path)
	if path == "" then return nil end
	local node = game
	local first = true
	for part in string.gmatch(path, "[^%.]+") do
		local nextNode = nil
		if first then
			first = false
			local ok, service = pcall(function() return game:GetService(part) end)
			nextNode = ok and service or game:FindFirstChild(part)
		else
			nextNode = node:FindFirstChild(part)
		end
		if not nextNode then node = nil; break end
		node = nextNode
	end
	if node and node:IsA("ProximityPrompt") then return node end
	-- names with dots: fall back to a full-name search
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst:GetFullName() == path then return inst end
	end
	return nil
end

local function promptPosition(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then return parent.WorldPosition end
	if parent and parent:IsA("BasePart") then return parent.Position end
	return nil
end
local character = player.Character
local rootPart = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local previous = playerGui:FindFirstChild("PulseSpike_" .. ID)
local rememberedPath = previous and previous:GetAttribute("PromptPath") or nil
local rememberedStyle = previous and previous:GetAttribute("OrigStyle") or nil

if ARGS.restoreOnly then
	out.mode = "restoreOnly"
	if not (rememberedPath and rememberedStyle) then
		out.note = "nothing remembered (no PulseSpike_11b with a stored Style)"
		if previous then previous:Destroy() end
		return finish()
	end
	local prompt = resolve(rememberedPath)
	if prompt then
		local ok, err = pcall(function() prompt.Style = Enum.ProximityPromptStyle[rememberedStyle] end)
		out.restored = ok
		out.restoreErr = (not ok) and tostring(err) or nil
		out.styleNow = tostring(prompt.Style)
	else
		out.restored = false
		out.note = "prompt no longer present (streamed out or destroyed); a new copy arrives with the server's Style"
	end
	out.promptPath = rememberedPath
	previous:Destroy()
	return finish()
end

local prompt = resolve(ARGS.promptPath)
if not prompt and ARGS.promptPath == "" then
	local best, bestDistance = nil, nil
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Name == "RaceEntryPrompt" then
			local position = promptPosition(inst)
			local distance = (position and rootPart) and (position - rootPart.Position).Magnitude or 1e9
			if not bestDistance or distance < bestDistance then best, bestDistance = inst, distance end
		end
	end
	prompt = best
end
if not prompt then
	out.error = "prompt not found (promptPath = '" .. ARGS.promptPath .. "'). Run 11a and pass a path, or move so a start zone streams in."
	return finish()
end

local path = prompt:GetFullName()
-- keep the first remembered original if an earlier run left Custom on this same prompt
local originalStyle = prompt.Style
local originalName = originalStyle.Name
if rememberedPath == path and rememberedStyle then
	originalName = rememberedStyle
	originalStyle = Enum.ProximityPromptStyle[rememberedStyle]
elseif rememberedPath and rememberedStyle then
	-- a different prompt was left Custom earlier: put that one back first
	local other = resolve(rememberedPath)
	if other then pcall(function() other.Style = Enum.ProximityPromptStyle[rememberedStyle] end) end
	out.restoredEarlierPrompt = rememberedPath
end

local gui = freshGui()
gui:SetAttribute("PromptPath", path)
gui:SetAttribute("OrigStyle", originalName)
local status = text(gui, "Status", "PulseSpike_11b: watching " .. prompt.Name, 14, 40, 110, CYAN)

local function defaultUiCount()
	local holder = playerGui:FindFirstChild("ProximityPrompts")
	if not holder then return -1 end
	return #holder:GetChildren()
end
local function distanceNow()
	local position = promptPosition(prompt)
	return (position and rootPart and rootPart.Parent) and r2((position - rootPart.Position).Magnitude) or nil
end

out.prompt = {
	path = path,
	originalStyle = originalName,
	styleAtStart = tostring(prompt.Style),
	enabled = prompt.Enabled,
	actionText = prompt.ActionText,
	objectText = prompt.ObjectText,
	maxActivationDistance = prompt.MaxActivationDistance,
	requiresLineOfSight = prompt.RequiresLineOfSight,
	exclusivity = prompt.Exclusivity.Name,
	parentSize = (prompt.Parent and prompt.Parent:IsA("BasePart")) and { r2(prompt.Parent.Size.X), r2(prompt.Parent.Size.Y), r2(prompt.Parent.Size.Z) } or nil,
	studsFromCharacter = distanceNow(),
}
out.player = {
	seated = humanoid ~= nil and humanoid.SeatPart ~= nil,
	seat = (humanoid and humanoid.SeatPart) and humanoid.SeatPart:GetFullName() or nil,
}
local camera = workspace.CurrentCamera
out.promptAnchorOnScreen = select(2, pcall(function()
	local position = promptPosition(prompt)
	if not (position and camera) then return "unknown" end
	local _, onScreen = camera:WorldToViewportPoint(position)
	return onScreen
end))

local started = os.clock()
local function since() return r2(os.clock() - started) end
local events = {}
local function log(kind, detail)
	if #events < 60 then events[#events + 1] = string.format("%.2f %s %s", os.clock() - started, kind, tostring(detail or "")) end
end

-- "expected" is the Style this spike last wrote; any other value seen is somebody else's write (works in both
-- immediate and deferred signal modes).
local expected = prompt.Style
local watching = false
local writeAt = nil
local hiddenLate = 0
local reverts, revertTimes, ownWrites, styleChanges = 0, {}, 0, 0
local shownTarget, hiddenTarget, shownOther, hiddenOther = 0, 0, 0, 0
local firstShownAt, lastHiddenAt = nil, nil
local connections = {}

connections[#connections + 1] = prompt:GetPropertyChangedSignal("Style"):Connect(function()
	styleChanges += 1
	local style = prompt.Style
	if style == expected then
		ownWrites += 1
		log("Style(own write)", style.Name)
		return
	end
	log("Style(not ours)", style.Name)
	if watching and expected == CUSTOM then
		reverts += 1
		if #revertTimes < 12 then revertTimes[#revertTimes + 1] = since() end
		if ARGS.reassert and reverts < 12 then
			task.defer(function()
				if watching and prompt.Parent then pcall(function() prompt.Style = CUSTOM end) end
			end)
		end
	end
end)
connections[#connections + 1] = ProximityPromptService.PromptShown:Connect(function(shown, inputType)
	if shown == prompt then
		shownTarget += 1
		firstShownAt = firstShownAt or since()
		log("PromptShown(target)", tostring(inputType))
	else
		shownOther += 1
		log("PromptShown(other)", shown.Name)
	end
end)
connections[#connections + 1] = ProximityPromptService.PromptHidden:Connect(function(hidden)
	if hidden == prompt then
		hiddenTarget += 1
		lastHiddenAt = since()
		if writeAt and os.clock() - writeAt > 1 then hiddenLate += 1 end
		log("PromptHidden(target)", "")
	else
		hiddenOther += 1
		log("PromptHidden(other)", hidden.Name)
	end
end)
local destroyed = false
connections[#connections + 1] = prompt.AncestryChanged:Connect(function()
	if not prompt:IsDescendantOf(game) then destroyed = true; log("Prompt removed", "streamed out or recreated") end
end)

local samples = {}
local function sample(phase)
	if #samples < 60 then
		samples[#samples + 1] = { t = since(), phase = phase, style = prompt.Style.Name, defaultUi = defaultUiCount(), enabled = prompt.Enabled, studs = distanceNow() }
	end
end
local function watch(seconds, phase)
	local stopAt = os.clock() + seconds
	local nextSample = 0
	while os.clock() < stopAt and not destroyed do
		if os.clock() >= nextSample then sample(phase); nextSample = os.clock() + ARGS.sampleEvery end
		RunService.Heartbeat:Wait()
	end
end

-- baseline with the original Style
watch(math.clamp(ARGS.baselineSeconds, 0, 5), "baseline")
out.baseline = { defaultUiChildren = defaultUiCount(), shownEvents = shownTarget, hiddenEvents = hiddenTarget }

-- the local write
local shownBeforeWrite, hiddenBeforeWrite = shownTarget, hiddenTarget
expected = CUSTOM
watching = true
writeAt = os.clock()
local writeOk, writeErr = pcall(function() prompt.Style = CUSTOM end)
out.write = { ok = writeOk, err = (not writeOk) and tostring(writeErr) or nil, t = since(), styleAfter = prompt.Style.Name }
status.Text = "PulseSpike_11b: LOCAL Style = Custom on " .. prompt.Name .. " - the engine prompt should NOT draw"
log("WRITE", "Style = Custom")

watch(math.clamp(ARGS.seconds, 1, 20), "custom")
local styleAtEndOfWatch = destroyed and "prompt removed" or prompt.Style.Name
local heldCustom = (not destroyed) and prompt.Style == CUSTOM
watching = false

local minUi, maxUi = nil, nil
for _, s in ipairs(samples) do
	if s.phase == "custom" then
		minUi = minUi and math.min(minUi, s.defaultUi) or s.defaultUi
		maxUi = maxUi and math.max(maxUi, s.defaultUi) or s.defaultUi
	end
end
out.custom = {
	watchedSeconds = r2(math.clamp(ARGS.seconds, 1, 20)),
	expectedServerPasses = math.floor(math.clamp(ARGS.seconds, 1, 20) / 3),
	styleAtEnd = styleAtEndOfWatch,
	reverts = reverts,
	revertTimes = revertTimes,
	styleChangedEvents = styleChanges,
	ownWriteEvents = ownWrites,
	survivesServerReassert = writeOk and reverts == 0 and heldCustom,
	shownTarget = shownTarget - shownBeforeWrite,
	hiddenTarget = hiddenTarget - hiddenBeforeWrite,
	firstShownAt = firstShownAt,
	lastHiddenAt = lastHiddenAt,
	shownOther = shownOther,
	hiddenOther = hiddenOther,
	defaultUiChildrenMin = minUi,
	defaultUiChildrenMax = maxUi,
	promptRemovedDuringTest = destroyed,
}
-- A Style switch on a showing prompt may cause one hide/show pair in the first second; that is not flicker.
-- hiddenLate counts PromptHidden for the target later than 1 s after the write.
out.custom.hiddenLaterThan1s = hiddenLate
out.custom.promptShownSteady = hiddenLate == 0 and ((shownTarget - shownBeforeWrite) >= 1 or (out.baseline.defaultUiChildren or 0) > 0)
out.custom.steadyNote = "promptShownSteady is only meaningful if the prompt was in range for the whole watch (see samples.studs and the prompt's maxActivationDistance). shownTarget = 0 with defaultUi = 0 at baseline means it was never showing."

if ARGS.leaveCustom then
	out.leftCustom = true
	out.restore = "NOT restored: run again with ARGS.restoreOnly = true (or spike_cleanup.lua)"
	for _, connection in ipairs(connections) do connection:Disconnect() end
else
	if not destroyed then
		expected = originalStyle
		local restoreOk, restoreErr = pcall(function() prompt.Style = originalStyle end)
		watch(1.0, "restored")
		out.restore = { ok = restoreOk, err = (not restoreOk) and tostring(restoreErr) or nil, styleNow = prompt.Style.Name, defaultUiChildren = defaultUiCount() }
	else
		out.restore = "prompt was removed during the test; nothing to restore"
	end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	gui:SetAttribute("OrigStyle", nil)
	gui:SetAttribute("PromptPath", nil)
	status.Text = "PulseSpike_11b: finished, Style restored to " .. originalName
end

out.events = events
out.samples = samples
out.defaultUiNote = "defaultUi = child count of PlayerGui.ProximityPrompts (the engine's default prompt holder); -1 = holder not found. A drop when Custom is written, and a rise after restore, is the measured form of 'Custom suppresses the default UI'."
out.decides = "Primary (Pulse banners on a local Custom style) needs: survivesServerReassert = true, AND the R2 capture shows no engine prompt after Custom was set before first show. If either fails, prompts stay engine-drawn under Pulse (recorded exception). promptShownSteady = false in R3 (seated in the zone) does not fail the primary: the Start banner then uses its own zone-box test instead of PromptShown."
out.needsCapture = ARGS.leaveCustom
	and "Style = Custom is LEFT ON. Now move into the prompt's range and capture: the engine prompt must NOT appear (no key cap, no text). Then run ARGS.restoreOnly = true, wait a moment and capture again: the engine prompt is back."
	or "Capture is optional for this run (data answers it). For R2 run with ARGS.leaveCustom = true from outside the prompt's range."
return finish()
