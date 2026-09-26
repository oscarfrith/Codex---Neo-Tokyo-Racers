-- Shared server request guard for every client->server remote. Wraps existing handlers without changing
-- remote objects, action names or reply fields. Validates before the handler runs; owns no gameplay state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = {}

local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end

-- Generic payload sanity for remotes whose handlers already validate semantics: bounded size/depth,
-- finite numbers, bounded strings. Instances and Roblox value types are allowed (handlers check them).
local function sane(value, depth, budget)
	local kind = typeof(value)
	if kind == "number" then return finite(value) end
	if kind == "string" then return #value <= 8192 end
	if kind == "Vector3" then return finite(value.X) and finite(value.Y) and finite(value.Z) end
	if kind == "CFrame" then local p = value.Position; return finite(p.X) and finite(p.Y) and finite(p.Z) end
	if kind == "Color3" then return finite(value.R) and finite(value.G) and finite(value.B) end
	if kind == "table" then
		if depth >= 4 then return false end
		for k, v in pairs(value) do
			budget.n += 1
			if budget.n > 64 then return false end
			if not sane(k, depth + 1, budget) or not sane(v, depth + 1, budget) then return false end
		end
		return true
	end
	return true
end
Net.IsSane = function(value) return sane(value, 0, { n = 0 }) end
Net.IsFinite = finite

-- Per-action call/reject counters. In Studio they are mirrored (at most every 5 s, only when changed) to
-- ServerStorage.Runtime.NetStats attributes as evidence for later retirement decisions.
local stats, dirty = {}, false
local function count(name, action, field, known)
	-- Unknown/non-string actions share one key so arbitrary client strings cannot grow this table.
	local key = name .. "." .. ((known ~= false and type(action) == "string") and action:sub(1, 48) or "?")
	local row = stats[key]
	if not row then row = { calls = 0, rejected = 0 }; stats[key] = row end
	row[field] += 1
	dirty = true
end
function Net.Stats() return stats end
if RunService:IsStudio() and RunService:IsRunning() then
	task.spawn(function()
		local runtime = ServerStorage:WaitForChild("Runtime", 30)
		if not runtime then return end
		local folder = runtime:FindFirstChild("NetStats") or Instance.new("Configuration")
		folder.Name = "NetStats"; folder.Parent = runtime
		while true do
			task.wait(5)
			if dirty then
				dirty = false
				for key, row in pairs(stats) do folder:SetAttribute(key:gsub("[^%w_]", "_"), row.calls .. "/" .. row.rejected) end
			end
		end
	end)
end

local guards = setmetatable({}, { __mode = "k" })
Players.PlayerRemoving:Connect(function(player)
	for guard in pairs(guards) do guard.forget(player) end
end)

-- spec: name, actions (set; nil = no action argument), check(player, action, args) -> ok, message (optional
-- field validation), capacity, refill (tokens/s), cost(action) or number, busy (bool), messages {unknown,
-- rate, busy, failed}, warnPrefix. Returns guard with check/run/forget.
function Net.guard(spec, clock)
	assert(type(spec.name) == "string", "Net guard needs a name")
	clock = clock or os.clock
	local capacity, refill = spec.capacity or 60, spec.refill or 20
	local messages = spec.messages or {}
	local states = setmetatable({}, { __mode = "k" })
	local api = {}
	function api.check(player, action, args)
		if spec.actions and (type(action) ~= "string" or not spec.actions[action]) then
			return false, messages.unknown or "Unknown request."
		end
		if spec.check then
			local ok, message = spec.check(player, action, args)
			if not ok then return false, message end
		end
		local now = clock()
		local state = states[player]
		if not state then state = { time = now, tokens = capacity }; states[player] = state end
		state.tokens = math.min(capacity, state.tokens + math.max(0, now - state.time) * refill); state.time = now
		local cost = type(spec.cost) == "function" and spec.cost(action) or spec.cost or 1
		if state.tokens < cost then return false, messages.rate or "Please wait before trying again." end
		state.tokens -= cost
		return true
	end
	function api.forget(player) states[player] = nil end
	-- Returns rejected=true plus message when refused; otherwise the callback's results.
	function api.known(action) return spec.actions == nil or (type(action) == "string" and spec.actions[action] == true) end
	function api.run(player, action, args, callback)
		local known = api.known(action)
		count(spec.name, action, "calls", known)
		local allowed, message = api.check(player, action, args)
		if not allowed then count(spec.name, action, "rejected", known); return true, message end
		local state = states[player]
		if spec.busy then
			if state.busy then count(spec.name, action, "rejected", known); return true, messages.busy or "A request is already running. Please try again." end
			state.busy = true
		end
		local result = table.pack(xpcall(callback, debug.traceback))
		if spec.busy then state.busy = false end
		if not result[1] then
			warn((spec.warnPrefix or ("[Net] " .. spec.name .. "." .. tostring(action))) .. " " .. tostring(result[2]))
			return true, messages.failed or "Request unavailable. Please try again."
		end
		return false, table.unpack(result, 2, result.n)
	end
	guards[api] = true
	return api
end

local function normalise(result)
	if type(result) == "table" then
		if result.Success == nil and result.Ok ~= nil then result.Success = result.Ok end
		if result.Ok == nil and result.Success ~= nil then result.Ok = result.Success end
	end
	return result
end

-- RemoteFunction handler. spec.reply: "table" (default; rejections return {Ok=false,Success=false,Message}
-- and existing replies gain the missing Ok/Success twin) or "boolean" (rejections return false, replies raw).
-- spec.withAction=false for remotes whose first argument is not an action string.
function Net.invoke(spec, handler)
	local guard = Net.guard(spec)
	local boolean = spec.reply == "boolean"
	return function(player, ...)
		local args = table.pack(...)
		local action = spec.withAction == false and "call" or args[1]
		local payload = spec.withAction == false and args[1] or args[2]
		if not Net.IsSane(payload) or (spec.withAction ~= false and args[3] ~= nil and not Net.IsSane(args[3])) then
			local known = guard.known(action)
			count(spec.name, action, "calls", known); count(spec.name, action, "rejected", known)
			if boolean then return false end
			return { Ok = false, Success = false, Message = spec.messages and spec.messages.invalid or "Invalid request." }
		end
		local reply = table.pack(guard.run(player, action, payload, function() return handler(player, table.unpack(args, 1, args.n)) end))
		if reply[1] then
			if boolean then return false end
			return { Ok = false, Success = false, Message = reply[2] }
		end
		if boolean then return table.unpack(reply, 2, reply.n) end
		return normalise(reply[2]), table.unpack(reply, 3, reply.n)
	end
end

-- RemoteEvent handler: rejected events are dropped (counted), accepted ones call the handler.
function Net.event(spec, handler)
	local guard = Net.guard(spec)
	return function(player, ...)
		local args = table.pack(...)
		local action = spec.actionFrom and spec.actionFrom(table.unpack(args, 1, args.n)) or "event"
		for i = 1, args.n do
			if not Net.IsSane(args[i]) then count(spec.name, action, "calls"); count(spec.name, action, "rejected"); return end
		end
		guard.run(player, action, nil, function() return handler(player, table.unpack(args, 1, args.n)) end)
	end
end

return Net
