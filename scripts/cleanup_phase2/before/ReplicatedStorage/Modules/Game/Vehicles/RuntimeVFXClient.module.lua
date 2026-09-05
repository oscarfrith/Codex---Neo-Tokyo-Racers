-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Runtime"):WaitForChild("RuntimeVFXController_Active")
local ok, runtime = pcall(function()
	return require(game:GetService("ReplicatedStorage")
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client")
		:WaitForChild("Visuals")
		:WaitForChild("CachedThrustVisualRuntime"))
end)

if ok and typeof(runtime) == "table" and typeof(runtime.Start) == "function" then
	runtime.Start()
	print("[V64] Cached thrust visual runtime active.")
else
	warn("[V64] Cached thrust visual runtime failed to start: " .. tostring(runtime))
end


end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
