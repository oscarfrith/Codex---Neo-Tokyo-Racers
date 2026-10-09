-- Pulse spike 12: start-up facts that can still be read after the fact. Play, Client datamodel. Read only; creates
-- nothing. It CANNOT show what had replicated at ReplicatedFirst time on a cold start - see 12_replicatedfirst_note.md
-- for the one-off experiment that does (Phase 1, with the latch).
-- Source facts: ClientBase creates Folder "StartupState" under its own script (ClientBase 104) and writes one
-- attribute per entry holding a status string (110). No times are published.
local ARGS = {
	pollSeconds = 0, -- >0: keep sampling StartupState this long (max 15) to see late entries turn ready
}
local ID = "12"
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

out.gameIsLoaded = game:IsLoaded()
out.clock = {
	distributedGameTime = r2(workspace.DistributedGameTime),
	timeSinceClientStart = r2(time()),
	serverTimeNow = select(2, pcall(function() return r2(workspace:GetServerTimeNow()) end)),
}

-- Config.UI as the client sees it now
local config = ReplicatedStorage:FindFirstChild("Config")
local ui = config and config:FindFirstChild("UI")
if ui then
	local attributes = {}
	for key, value in pairs(ui:GetAttributes()) do attributes[key] = tostring(value) end
	local children = {}
	for _, child in ipairs(ui:GetChildren()) do children[#children + 1] = child.Name end
	table.sort(children)
	out.configUI = {
		attributeCount = (function() local n = 0; for _ in pairs(attributes) do n += 1 end; return n end)(),
		attributes = attributes,
		children = children,
		uiStyle = tostring(ui:GetAttribute("UIStyle")),
		hasPulseChild = ui:FindFirstChild("Pulse") ~= nil,
		hasStyleChild = ui:FindFirstChild("Style") ~= nil,
	}
	local loading = ui:FindFirstChild("LoadingSystem")
	out.loadingSystem = loading and { startScreenEnabled = tostring(loading:GetAttribute("StartScreenEnabled")), timeoutSeconds = tostring(loading:GetAttribute("TimeoutSeconds")) } or "LoadingSystem not found"
else
	out.configUI = "ReplicatedStorage.Config.UI not found"
end

-- ClientBase.StartupState
local playerScripts = player:FindFirstChild("PlayerScripts")
local clientBase = playerScripts and playerScripts:FindFirstChild("ClientBase")
local state = clientBase and clientBase:FindFirstChild("StartupState")
local function readState()
	local byStatus, notReady, total, numeric = {}, {}, 0, 0
	for name, status in pairs(state:GetAttributes()) do
		total += 1
		if type(status) == "number" then numeric += 1 end
		local key = tostring(status)
		byStatus[key] = (byStatus[key] or 0) + 1
		if key ~= "ready" and key ~= "skipped" and #notReady < 40 then notReady[#notReady + 1] = name .. "=" .. key end
	end
	table.sort(notReady)
	return { entries = total, byStatus = byStatus, notReady = notReady, numericAttributes = numeric }
end
if state then
	out.startupState = readState()
	out.startupState.path = state:GetFullName()
	out.startupState.timingsPublished = out.startupState.numericAttributes > 0
	out.startupState.expectedEntriesFromSource = "46 entries in ClientBase 5-103, 4 of them dev tools (status skipped unless their Config.Development.ClientTools flag is on). Statuses from ClientLifecycle 27-44: pending, starting, ready, failed, blocked, skipped"
	if ARGS.pollSeconds > 0 then
		local started = os.clock()
		local timeline = {}
		local lastSignature = nil
		while os.clock() - started < math.clamp(ARGS.pollSeconds, 0, 15) do
			local snapshot = readState()
			local signature = HttpService:JSONEncode(snapshot.byStatus)
			if signature ~= lastSignature and #timeline < 20 then
				timeline[#timeline + 1] = { t = r2(os.clock() - started), byStatus = snapshot.byStatus }
				lastSignature = signature
			end
			task.wait(0.25)
		end
		out.startupTimeline = timeline
	end
else
	out.startupState = "PlayerScripts.ClientBase.StartupState not found (clientBase present = " .. tostring(clientBase ~= nil) .. ")"
end

-- ReplicatedFirst contents the latch will sit beside
out.replicatedFirst = {}
for _, child in ipairs(ReplicatedFirst:GetChildren()) do
	local row = child.ClassName .. " " .. child.Name
	if child.Name == "Loading" then
		local names = {}
		for _, inner in ipairs(child:GetChildren()) do names[#names + 1] = inner.ClassName .. " " .. inner.Name end
		table.sort(names)
		out.loadingPackage = names
	end
	out.replicatedFirst[#out.replicatedFirst + 1] = row
end
out.latchPresent = ReplicatedFirst:FindFirstChild("UIStyleSwitch") ~= nil

out.playerAttributes = (function()
	local list = {}
	for key, value in pairs(player:GetAttributes()) do list[#list + 1] = key .. "=" .. tostring(value) end
	table.sort(list)
	return list
end)()

out.limits = "This run happens seconds after start-up. It proves the present state only (Config.UI has no UIStyle attribute and no Style/Pulse child before Phase 1; every ClientBase entry ready). 'Attributes present at ReplicatedFirst time' and 'ClientBase before ReplicatedStorage has arrived' need the Phase 1 one-off experiment."
out.decides = "Nothing is selected by this spike alone. It records the baseline the Phase 1 experiment is compared with, and startupState.notReady (anything not ready or skipped) must be empty in Classic (proof 'Start-up state' in plan 1.8)."
out.needsCapture = "none (data only)"
return finish()
