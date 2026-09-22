-- Read-only, bounded Studio measurement. Run in Client or Server during Play.
-- Does not require game modules, invoke remotes, change instances or install code.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and RunService:IsRunning(), "Use Studio Play")
assert(game.PlaceId == 121304917315753, "Wrong place")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local function safe(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return { unavailable = tostring(value) }
end
local function snapshot()
    local result = {memoryMB = safe(function() return Stats:GetTotalMemoryUsageMb() end),
        luaHeapKB = gcinfo(), players = #Players:GetPlayers(), roots = {}, memoryTags = {}, stats = {}}
    for _, name in {"ReplicatedStorage", "Workspace", "PlayerGui", "PlayerScripts"} do
        local root = game:FindFirstChild(name) or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChild(name))
        if root then result.roots[name] = #root:GetDescendants() end
    end
    for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
        result.memoryTags[tag.Name] = safe(function() return Stats:GetMemoryUsageMbForTag(tag) end)
    end
    for _, name in {"InstanceCount", "PrimitivesCount", "MovingPrimitivesCount", "HeartbeatTimeMs", "PhysicsStepTimeMs", "DataReceiveKbps", "DataSendKbps", "RenderCPUFrameTime", "RenderGPUFrameTime"} do
        result.stats[name] = safe(function() return Stats[name] end)
    end
    local base = RunService:IsClient() and Players.LocalPlayer.PlayerScripts:FindFirstChild("ClientBase") or game.ServerScriptService:FindFirstChild("ServerBase")
    local state = base and base:FindFirstChild("StartupState")
    result.startup = state and state:GetAttributes() or {}
    local player = Players.LocalPlayer or Players:GetPlayers()[1]
    result.sandbox = player and player:GetAttribute("StudioVehicleSandboxActive") == true
    result.viewport = workspace.CurrentCamera and tostring(workspace.CurrentCamera.ViewportSize) or "unavailable"
    return result
end
local before = snapshot()
local durations = {}
local event = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat
local start = os.clock()
repeat
    local dt = event:Wait()
    table.insert(durations, dt * 1000)
until os.clock() - start >= 8 or #durations >= 4000
local elapsed = os.clock() - start
table.sort(durations)
local function percentile(q) return durations[math.max(1, math.ceil(#durations * q))] end
local over33, over50 = 0, 0
for _, ms in durations do if ms > 33.333 then over33 += 1 end if ms > 50 then over50 += 1 end end
return game:GetService("HttpService"):JSONEncode({
    mode = RunService:IsClient() and "Client" or "Server", timeUTC = os.date("!%Y-%m-%d %H:%M:%S"),
    engineVersion = version(), durationSeconds = elapsed, samples = #durations,
    intervalMs = {p50 = percentile(0.5), p95 = percentile(0.95), p99 = percentile(0.99), max = durations[#durations], over33 = over33, over50 = over50},
    before = before, after = snapshot(),
    limitations = "Studio single-player; foreground/graphics not controlled; intervals are not script CPU time; no device, cold-join or gameplay-route claim. Memory is engine-reported, not isolated phone memory. Snapshot scans are outside the timed window."
})
