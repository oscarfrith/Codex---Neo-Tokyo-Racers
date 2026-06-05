local ok, runtime = pcall(function()
	return require(game:GetService("ReplicatedStorage")
		:WaitForChild("HOVER_RACING_V2_KIT")
		:WaitForChild("CLIENT_MODULES")
		:WaitForChild("Visuals")
		:WaitForChild("CachedThrustVisualRuntime"))
end)

if ok and typeof(runtime) == "table" and typeof(runtime.Start) == "function" then
	runtime.Start()
	print("[V64] Cached thrust visual runtime active.")
else
	warn("[V64] Cached thrust visual runtime failed to start: " .. tostring(runtime))
end
