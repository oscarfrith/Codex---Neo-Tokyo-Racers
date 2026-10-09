-- Pulse spike 08: core UI state, the core-gui changed signal, chat window rectangle and run-time restyle.
-- Play, Client datamodel. Transient ScreenGui PulseSpike_08 only.
-- Writes, all restored: (1) PlayerList core GUI toggled once and put back; (2) three ChatWindowConfiguration
-- properties written and put back. mode = "apply" leaves the chat restyle on for a capture and stores the originals
-- as attributes on PulseSpike_08; mode = "restore" (or spike_cleanup.lua, or any later run) puts them back.
-- execute_luau may run at a higher script identity than a LocalScript: a write that works here is confirmed for
-- game scripts only when the Phase 1 kit repeats it from a real ModuleScript.
local ARGS = {
	mode = "probe", -- "probe" | "apply" | "restore"
	togglePlayerList = true, -- the only core write; skipped unless mode = "probe"
	signalWaitSeconds = 1.0,
}
local ID = "08"
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

local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local TextChatService = game:GetService("TextChatService")
out.mode = ARGS.mode

local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
local WRITE_TESTS = {
	{ prop = "BackgroundColor3", value = SLATE },
	{ prop = "TextColor3", value = WHITE },
	{ prop = "FontFace", value = barlow(Enum.FontWeight.SemiBold) },
}

-- Put back anything an earlier "apply" left behind (originals live on the old spike ScreenGui).
local function restoreStored(holder)
	local restored = {}
	if not (holder and window) then return restored end
	for _, test in ipairs(WRITE_TESTS) do
		local stored = holder:GetAttribute("Orig_" .. test.prop)
		if stored ~= nil then
			local ok, err = pcall(function() window[test.prop] = stored end)
			restored[test.prop] = ok and "restored" or ("error: " .. tostring(err))
			if ok then holder:SetAttribute("Orig_" .. test.prop, nil) end
		end
	end
	return restored
end
local previous = playerGui:FindFirstChild("PulseSpike_" .. ID)
local restoredFromEarlier = restoreStored(previous)
if next(restoredFromEarlier) ~= nil then out.restoredFromEarlierApply = restoredFromEarlier end
if ARGS.mode == "restore" then
	if previous then previous:Destroy() end
	out.note = "restore only"
	return finish()
end

local gui = freshGui()

-- 1. Core GUI state
out.coreGuiEnabled = {}
for _, item in ipairs(Enum.CoreGuiType:GetEnumItems()) do
	local ok, value = pcall(function() return StarterGui:GetCoreGuiEnabled(item) end)
	if ok then out.coreGuiEnabled[item.Name] = value else out.coreGuiEnabled[item.Name] = "error: " .. tostring(value) end
end

-- 2. CoreGuiChangedSignal, with one PlayerList toggle that is always put back
local signalReport = { exists = false, events = {} }
local started = os.clock()
local signalConnection = nil
do
	local ok, signal = pcall(function() return StarterGui.CoreGuiChangedSignal end)
	if ok and signal then
		signalReport.exists = true
		local connectOk, connectErr = pcall(function()
			signalConnection = signal:Connect(function(coreGuiType, enabled)
				local list = signalReport.events
				if #list < 12 then list[#list + 1] = { t = r2(os.clock() - started), type = tostring(coreGuiType), enabled = enabled } end
			end)
		end)
		signalReport.connectErr = (not connectOk) and tostring(connectErr) or nil
	else
		signalReport.error = tostring(signal)
	end
end
if ARGS.togglePlayerList and ARGS.mode == "probe" then
	local playerList = Enum.CoreGuiType.PlayerList
	local readOk, original = pcall(function() return StarterGui:GetCoreGuiEnabled(playerList) end)
	if readOk then
		local toggle = { original = original }
		local function waitForEvents(count)
			local stopAt = os.clock() + ARGS.signalWaitSeconds
			while #signalReport.events < count and os.clock() < stopAt do RunService.Heartbeat:Wait() end
		end
		local ok1, err1 = pcall(function() StarterGui:SetCoreGuiEnabled(playerList, not original) end)
		toggle.firstWrite = ok1 and "ok" or ("error: " .. tostring(err1))
		waitForEvents(1)
		toggle.readAfterFirstWrite = select(2, pcall(function() return StarterGui:GetCoreGuiEnabled(playerList) end))
		toggle.eventsAfterFirstWrite = #signalReport.events
		-- always restore, and retry once
		local ok2, err2 = pcall(function() StarterGui:SetCoreGuiEnabled(playerList, original) end)
		toggle.restoreWrite = ok2 and "ok" or ("error: " .. tostring(err2))
		waitForEvents(toggle.eventsAfterFirstWrite + 1)
		local final = select(2, pcall(function() return StarterGui:GetCoreGuiEnabled(playerList) end))
		if final ~= original then
			pcall(function() StarterGui:SetCoreGuiEnabled(playerList, original) end)
			waitFrames(3)
			final = select(2, pcall(function() return StarterGui:GetCoreGuiEnabled(playerList) end))
		end
		toggle.finalState = final
		toggle.restored = final == original
		signalReport.playerListToggle = toggle
		signalReport.firesOnSetCoreGuiEnabled = #signalReport.events >= 2
	else
		signalReport.playerListToggle = "skipped: " .. tostring(original)
	end
else
	signalReport.playerListToggle = "skipped (mode or ARGS)"
end
if signalConnection then signalConnection:Disconnect() end
out.coreGuiChangedSignal = signalReport

-- 3. Gamepad selection flags (read only)
out.guiService = {}
for _, name in ipairs({ "AutoSelectGuiEnabled", "GuiNavigationEnabled", "CoreGuiNavigationEnabled", "MenuIsOpen", "TouchControlsEnabled" }) do
	local ok, value = pcall(function() return GuiService[name] end)
	if ok then out.guiService[name] = value else out.guiService[name] = "error: " .. tostring(value) end
end
out.guiService.selectedObject = select(2, pcall(function() return GuiService.SelectedObject and GuiService.SelectedObject:GetFullName() or "nil" end))

-- 4. Chat
local function readProps(inst, names)
	local t = {}
	for _, name in ipairs(names) do
		local ok, value = pcall(function() return inst[name] end)
		if not ok then t[name] = "error: " .. tostring(value)
		elseif typeof(value) == "Vector2" then t[name] = v2(value)
		elseif type(value) == "boolean" or type(value) == "number" then t[name] = value
		else t[name] = tostring(value) end
	end
	return t
end
local chat = { chatVersion = select(2, pcall(function() return tostring(TextChatService.ChatVersion) end)) }
chat.window = window and readProps(window, { "Enabled", "AbsolutePosition", "AbsoluteSize", "HorizontalAlignment", "VerticalAlignment", "WidthScale", "HeightScale", "BackgroundColor3", "BackgroundTransparency", "TextColor3", "TextSize", "FontFace", "TextStrokeTransparency" }) or "ChatWindowConfiguration not found"
chat.inputBar = inputBar and readProps(inputBar, { "Enabled", "AbsolutePosition", "AbsoluteSize", "BackgroundColor3", "BackgroundTransparency", "TextColor3", "TextSize", "FontFace", "IsFocused", "KeyboardKeyCode" }) or "ChatInputBarConfiguration not found"

if window then
	chat.writeTests = {}
	for _, test in ipairs(WRITE_TESTS) do
		local row = {}
		local readOk, original = pcall(function() return window[test.prop] end)
		if not readOk then
			row.error = "read: " .. tostring(original)
		else
			row.original = tostring(original)
			local writeOk, writeErr = pcall(function() window[test.prop] = test.value end)
			row.writeOk = writeOk
			row.writeErr = (not writeOk) and tostring(writeErr) or nil
			waitFrames(2)
			local after = select(2, pcall(function() return window[test.prop] end))
			row.afterWrite = tostring(after)
			row.valueTook = writeOk and after == test.value
			if ARGS.mode == "apply" and writeOk then
				local storeOk = pcall(function() gui:SetAttribute("Orig_" .. test.prop, original) end)
				row.leftApplied = storeOk
				if not storeOk then
					-- cannot remember the original, so do not leave it changed
					pcall(function() window[test.prop] = original end)
				end
			else
				local restoreOk, restoreErr = pcall(function() window[test.prop] = original end)
				waitFrames(1)
				local final = select(2, pcall(function() return window[test.prop] end))
				row.restored = restoreOk and final == original
				row.restoreErr = (not restoreOk) and tostring(restoreErr) or nil
			end
		end
		chat.writeTests[test.prop] = row
	end
end
out.chat = chat

-- 5. Draw the reported chat rectangles so the capture shows their coordinate space
do
	local function outline(name, inst, color)
		local ok, pos = pcall(function() return inst.AbsolutePosition end)
		local ok2, size = pcall(function() return inst.AbsoluteSize end)
		if not (ok and ok2) then return end
		local f = frame(gui, name, pos.X, pos.Y, size.X, size.Y, color, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		text(f, "Tag", name, 12, 4, 2, color)
	end
	if window then outline("ChatWindowRect", window, CYAN) end
	if inputBar then outline("ChatInputBarRect", inputBar, YELLOW) end
end

out.decides = "Core policy re-assert: if coreGuiChangedSignal.firesOnSetCoreGuiEnabled is true, CoreUiPolicy re-asserts on the signal after trailer mode; if false, the trailer exception is recorded and nothing polls. Chat: the top-left slot starts below chat.window AbsolutePosition.Y + AbsoluteSize.Y when the cyan outline matches the real window; if the rectangle is zero or wrong, use a fixed chat allowance from the capture. Chat restyle is adopted only if all three writeTests valueTook = true AND the mode = apply capture shows the change."
out.needsCapture = ARGS.mode == "apply"
	and "Chat restyle is LEFT ON. Open the chat window (press / or click the chat button) and capture: slate background, off-white text, Barlow SemiBold Italic? Then run this spike with ARGS.mode = \"restore\" and capture again to confirm it is back."
	or "Capture with the chat window open: the cyan outline should sit exactly on the chat window and the yellow one on the input bar (same origin, same size). Confirm the player list looks as it did before the run. Then run with ARGS.mode = \"apply\" for the restyle capture."
return finish()
