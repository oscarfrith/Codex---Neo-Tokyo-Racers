-- Pulse spike 13: MicroProfiler label and memory-category APIs on the client. Play, Client datamodel.
-- Creates no instances. For ARGS.seconds it runs one labelled RenderStepped connection and one labelled
-- BindToRenderStep callback (both removed before return) so the integrator can open the MicroProfiler
-- (Ctrl+F6, pause with Ctrl+P) and see how script work is labelled. Classic render-step names are listed in
-- 13_profiler_notes.md (from source).
local ARGS = {
	seconds = 10, -- how long the labelled steps run (max 20). 0 = API checks only
	busyLoop = 20000, -- iterations of trivial work inside each labelled step, so the bars are wide enough to find
}
local ID = "13"
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

-- 1. API availability
out.api = {
	profilebegin = typeof(debug.profilebegin),
	profileend = typeof(debug.profileend),
	getmemorycategory = typeof(debug.getmemorycategory),
	setmemorycategory = typeof(debug.setmemorycategory),
	resetmemorycategory = typeof(debug.resetmemorycategory),
}
local beginOk, beginErr = pcall(function()
	debug.profilebegin("PulseSpike13.ApiCheck")
	debug.profileend()
end)
out.profileBeginEnd = beginOk and "ok" or ("error: " .. tostring(beginErr))

-- cost of an empty labelled region
if beginOk then
	local n = 20000
	local t0 = os.clock()
	for _ = 1, n do
		debug.profilebegin("PulseSpike13.Empty")
		debug.profileend()
	end
	out.profilePairCostMicroseconds = r2((os.clock() - t0) / n * 1e6)
end

-- memory category: read, set, read, reset
do
	local report = {}
	report.before = select(2, pcall(function() return debug.getmemorycategory() end))
	local setOk, setErr = pcall(function() debug.setmemorycategory("PulseSpike13") end)
	report.set = setOk and "ok" or ("error: " .. tostring(setErr))
	report.during = select(2, pcall(function() return debug.getmemorycategory() end))
	local resetOk, resetErr = pcall(function() debug.resetmemorycategory() end)
	report.reset = resetOk and "ok" or ("error: " .. tostring(resetErr))
	report.after = select(2, pcall(function() return debug.getmemorycategory() end))
	out.memoryCategory = report
end

-- Stats values a perf_sample probe could read
do
	local Stats = game:GetService("Stats")
	local stats = {}
	for _, name in ipairs({ "FrameTime", "HeartbeatTime", "RenderCPUFrameTime", "RenderGPUFrameTime", "PhysicsStepTime", "SceneDrawcallCount", "SceneTriangleCount", "InstanceCount", "PrimitivesCount", "DataReceiveKbps" }) do
		local ok, value = pcall(function() return Stats[name] end)
		if ok then stats[name] = type(value) == "number" and r2(value) or tostring(value) else stats[name] = "error: " .. tostring(value) end
	end
	stats.totalMemoryMb = select(2, pcall(function() return r2(Stats:GetTotalMemoryUsageMb()) end))
	stats.guiMemoryMb = select(2, pcall(function() return r2(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Gui)) end))
	stats.luaHeapMb = select(2, pcall(function() return r2(Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.LuaHeap)) end))
	stats.gcinfoKb = select(2, pcall(function() return gcinfo() end))
	out.stats = stats
end

-- 2. Labelled steps for a MicroProfiler look
local seconds = math.clamp(ARGS.seconds, 0, 20)
if seconds > 0 and beginOk then
	local frames, boundFrames = 0, 0
	local sink = 0
	local connection = RunService.RenderStepped:Connect(function()
		debug.profilebegin("PulseSpike13.ConnectedStep")
		for i = 1, ARGS.busyLoop do sink += i % 7 end
		debug.profileend()
		frames += 1
	end)
	local BOUND_NAME = "PulseSpike13_Bound"
	local bindOk, bindErr = pcall(function()
		RunService:BindToRenderStep(BOUND_NAME, Enum.RenderPriority.Last.Value + 50, function()
			debug.profilebegin("PulseSpike13.BoundStep")
			for i = 1, ARGS.busyLoop do sink += i % 5 end
			debug.profileend()
			boundFrames += 1
		end)
	end)
	local stopAt = os.clock() + seconds
	while os.clock() < stopAt do RunService.Heartbeat:Wait() end
	connection:Disconnect()
	pcall(function() RunService:UnbindFromRenderStep(BOUND_NAME) end)
	out.labelledSteps = {
		seconds = seconds,
		connectedFrames = frames,
		bind = bindOk and "ok" or ("error: " .. tostring(bindErr)),
		boundFrames = boundFrames,
		labels = { "PulseSpike13.ConnectedStep", "PulseSpike13.BoundStep", "PulseSpike13_Bound" },
		removedBeforeReturn = true,
	}
end

out.classicLabelsFromSource = "Only LODClient 44 calls debug.profilebegin ('.WorldLOD.Step'). The Classic HUD has no label of its own; its frame work is the BindToRenderStep callback 'PCFreeRoamHudPhase4A' (DesktopFreeRoamHudUI 1368) and one RenderStepped connection in MobileFreeRoamHudUI 391. See 13_profiler_notes.md."
out.decides = "Kit.Perf wraps every Pulse frame step in debug.profilebegin if profileBeginEnd = ok (else no labels and script time is not reported). A Classic-vs-Pulse script-time comparison is made only if the MicroProfiler capture shows the Classic HUD step as its own bar (by its render-step name 'PCFreeRoamHudPhase4A' or by a per-script label); otherwise script time is reported for Pulse alone and Classic is compared on frame time and write counts."
out.needsCapture = "While this call runs (or run with a longer ARGS.seconds): open the MicroProfiler (Ctrl+F6), pause (Ctrl+P), zoom into one frame on the main thread and capture. Look for (1) 'PulseSpike13.ConnectedStep' and 'PulseSpike13.BoundStep' bars - proves labels show; (2) what their PARENT bar is called - a script name, 'RenderStepped', or the binding name 'PulseSpike13_Bound'; (3) whether a bar named 'PCFreeRoamHudPhase4A' (or DesktopFreeRoamHudUI) exists while in free roam - that is the Classic HUD step; (4) '.WorldLOD.Step' as the known-good Classic label."
return finish()
