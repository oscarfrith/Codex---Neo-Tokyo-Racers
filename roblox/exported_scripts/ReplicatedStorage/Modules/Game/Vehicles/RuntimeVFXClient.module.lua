-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local ok, runtime = pcall(function()
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleVFXClient"))
end)

if ok and typeof(runtime) == "table" and typeof(runtime.Start) == "function" then
	runtime.Start()
	print("[RuntimeVFXClient] Cached thrust visual runtime active.")
else
	warn("[RuntimeVFXClient] Cached thrust visual runtime failed to start: " .. tostring(runtime))
end


end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
