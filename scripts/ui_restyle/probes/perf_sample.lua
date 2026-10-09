-- UI restyle probe: perf_sample (datamodel: Client, Play). READ-ONLY, BLOCKS for ARGS.seconds.
-- Frame delta times over a fixed window plus whatever the Stats service exposes to scripts.
-- Every Stats read is pcall-ed; the result lists what exists on this engine build.
-- Studio figures prove nothing about phones (plan 5.3): compare a style against its own
-- run-to-run spread, three runs each.
local ARGS = {
	label = "",      -- e.g. "classic parked spot A run 1"
	seconds = 20,    -- capped at 20
	warmup = 1,      -- seconds discarded before sampling (capped at 4)
	statsEvery = 0.5, -- seconds between Stats samples
	detail = false,  -- true adds the PerformanceStats / child item dump and memory by tag
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

if not Players.LocalPlayer then
	return HttpService:JSONEncode({ probe = "perf_sample", ok = false, error = "no LocalPlayer (run on the Client datamodel in Play)" })
end

local seconds = math.clamp(tonumber(ARGS.seconds) or 20, 0.5, 20)
local warmup = math.clamp(tonumber(ARGS.warmup) or 1, 0, 4)

local STAT_PROPERTIES = {
	"FrameTime", "HeartbeatTime", "HeartbeatTimeMs", "RenderCPUFrameTime", "RenderGPUFrameTime",
	"PhysicsStepTime", "PhysicsStepTimeMs", "SceneDrawcallCount", "SceneTriangleCount",
	"ShadowsDrawcallCount", "ShadowsTriangleCount", "UI2DDrawcallCount", "UI2DTriangleCount",
	"UI3DDrawcallCount", "UI3DTriangleCount", "DrawcallCount", "TriangleCount",
	"InstanceCount", "PrimitivesCount", "MovingPrimitivesCount", "ContactsCount",
	"DataReceiveKbps", "DataSendKbps",
}

-- Find which properties exist once, then sample only those.
local available = {}
local missing = {}
for _, name in ipairs(STAT_PROPERTIES) do
	local ok, value = pcall(function()
		return Stats[name]
	end)
	if ok and type(value) == "number" then
		table.insert(available, name)
	else
		table.insert(missing, name)
	end
end

local series = {}
for _, name in ipairs(available) do
	series[name] = { sum = 0, max = -math.huge, min = math.huge, n = 0, last = 0 }
end
local function sampleStats()
	for _, name in ipairs(available) do
		local ok, value = pcall(function()
			return Stats[name]
		end)
		if ok and type(value) == "number" then
			local entry = series[name]
			entry.sum += value
			entry.n += 1
			entry.last = value
			if value > entry.max then
				entry.max = value
			end
			if value < entry.min then
				entry.min = value
			end
		end
	end
end

local function memoryMb()
	local ok, value = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	return ok and value or nil
end

if warmup > 0 then
	task.wait(warmup)
end

local renderDeltas = {}
local heartbeatDeltas = {}
local memoryStart = memoryMb()
local renderConnection = RunService.RenderStepped:Connect(function(delta)
	table.insert(renderDeltas, delta)
end)
local heartbeatConnection = RunService.Heartbeat:Connect(function(delta)
	table.insert(heartbeatDeltas, delta)
end)

local started = os.clock()
local every = math.max(0.1, tonumber(ARGS.statsEvery) or 0.5)
while os.clock() - started < seconds do
	sampleStats()
	task.wait(math.min(every, math.max(0.03, seconds - (os.clock() - started))))
end
local elapsed = os.clock() - started
renderConnection:Disconnect()
heartbeatConnection:Disconnect()
local memoryEnd = memoryMb()

local function round(value, places)
	local factor = 10 ^ (places or 3)
	return math.floor(value * factor + 0.5) / factor
end

local function summarise(deltas)
	local count = #deltas
	if count == 0 then
		return { frames = 0 }
	end
	local sorted = table.clone(deltas)
	table.sort(sorted)
	local total = 0
	local over33, over50, over100 = 0, 0, 0
	for _, delta in ipairs(deltas) do
		total += delta
		if delta > 1 / 30 then
			over33 += 1
		end
		if delta > 0.05 then
			over50 += 1
		end
		if delta > 0.1 then
			over100 += 1
		end
	end
	local function percentile(fraction)
		return sorted[math.clamp(math.ceil(count * fraction), 1, count)]
	end
	return {
		frames = count,
		meanFps = round(count / total, 2),
		medianMs = round(percentile(0.5) * 1000),
		p95Ms = round(percentile(0.95) * 1000),
		p99Ms = round(percentile(0.99) * 1000),
		maxMs = round(sorted[count] * 1000),
		minMs = round(sorted[1] * 1000),
		meanMs = round(total / count * 1000),
		framesOver33ms = over33, framesOver50ms = over50, framesOver100ms = over100,
	}
end

local statsOut = {}
for _, name in ipairs(available) do
	local entry = series[name]
	if entry.n > 0 then
		statsOut[name] = { mean = round(entry.sum / entry.n, 4), min = round(entry.min, 4), max = round(entry.max, 4), last = round(entry.last, 4), n = entry.n }
	end
end

local camera = workspace.CurrentCamera
local result = {
	probe = "perf_sample", ok = true, label = ARGS.label, seconds = round(elapsed), warmup = warmup,
	render = summarise(renderDeltas), heartbeat = summarise(heartbeatDeltas),
	stats = statsOut, statsMissing = missing,
	memoryMbStart = memoryStart and round(memoryStart, 2) or nil,
	memoryMbEnd = memoryEnd and round(memoryEnd, 2) or nil,
	viewport = camera and { camera.ViewportSize.X, camera.ViewportSize.Y } or nil,
}
if #renderDeltas == 0 then
	result.warning = "RenderStepped never fired: the Studio window is minimised or covered; bring it to the front and rerun"
end

pcall(function()
	result.physicsFps = round(workspace:GetRealPhysicsFPS(), 2)
end)
pcall(function()
	result.savedQualityLevel = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)
end)
pcall(function()
	result.isStudio = RunService:IsStudio()
end)
pcall(function()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		result.position = { round(root.Position.X, 1), round(root.Position.Y, 1), round(root.Position.Z, 1) }
		result.speed = round(root.AssemblyLinearVelocity.Magnitude, 1)
	end
end)

-- Memory by developer tag (Gui, Instances, LuaHeap, Script, GraphicsTexture, ...).
local memoryTags = {}
pcall(function()
	for _, tag in ipairs(Enum.DeveloperMemoryTag:GetEnumItems()) do
		local ok, value = pcall(function()
			return Stats:GetMemoryUsageMbForTag(tag)
		end)
		if ok and type(value) == "number" and (ARGS.detail or tag.Name == "Gui" or tag.Name == "Instances" or tag.Name == "LuaHeap" or tag.Name == "Script" or tag.Name == "GraphicsTexture" or tag.Name == "GraphicsMeshParts") then
			memoryTags[tag.Name] = round(value, 2)
		end
	end
end)
result.memoryMbByTag = memoryTags

-- Stats children that scripts can see (PerformanceStats, FrameRateManager, RenderStats, ...).
local children = {}
pcall(function()
	for _, child in ipairs(Stats:GetChildren()) do
		table.insert(children, child.Name .. ":" .. child.ClassName)
	end
end)
result.statsChildren = children

if ARGS.detail then
	local items = {}
	local budget = 80
	local function dump(parent, prefix, depth)
		local ok, list = pcall(function()
			return parent:GetChildren()
		end)
		if not ok then
			return
		end
		for _, child in ipairs(list) do
			if budget <= 0 then
				return
			end
			local okValue, value = pcall(function()
				return child:GetValue()
			end)
			if okValue and type(value) == "number" then
				budget -= 1
				items[prefix .. child.Name] = round(value, 4)
			end
			if depth > 1 then
				dump(child, prefix .. child.Name .. ".", depth - 1)
			end
		end
	end
	for _, name in ipairs({ "PerformanceStats", "FrameRateManager", "RenderStats", "Workspace", "Network" }) do
		local okFind, node = pcall(function()
			return Stats:FindFirstChild(name)
		end)
		if okFind and node then
			dump(node, name .. ".", 2)
		end
	end
	result.statsItems = items
	result.statsItemsTruncated = budget <= 0
end

return HttpService:JSONEncode(result)
