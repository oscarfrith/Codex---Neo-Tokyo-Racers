-- Phase 1 canonical read-only Studio audit. Execute through MCP in Edit mode.
-- No require, source assignment, attributes, object creation or DataStore calls.
assert(game.PlaceId == 121304917315753, "BLOCKER: expected Space Racers v1")
assert(not game:GetService("RunService"):IsRunning(), "BLOCKER: Edit mode required")
local report = { place_id = game.PlaceId, status = "PASS", scripts = {}, blockers = {}, warnings = {} }
for _, name in ipairs({"ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer", "StarterGui", "Workspace"}) do
	for _, item in ipairs(game:GetService(name):GetDescendants()) do
		if item:IsA("LuaSourceContainer") then
			local source = item.Source
			local checksum = 0
			for i = 1, #source do checksum = (checksum + string.byte(source, i) * i) % 1000000007 end
			local compiled, message = loadstring(source, "=" .. item:GetFullName())
			if not compiled then table.insert(report.blockers, {path=item:GetFullName(), error=tostring(message)}) end
			table.insert(report.scripts, {path=item:GetFullName(), checksum=tostring(checksum), bytes=#source, disabled=item:IsA("BaseScript") and item.Disabled or false})
		end
	end
end
local ntr = game:GetService("ReplicatedStorage"):FindFirstChild("NeoTokyoRacers")
local runtime = ntr and ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
local onboarding = runtime and runtime:FindFirstChild("Onboarding_EditAttributes")
report.studio_replay = onboarding and onboarding:GetAttribute("StudioReplayEveryPlay")
report.studio_vehicle_sandbox = onboarding and onboarding:GetAttribute("StudioVehicleSandboxEveryPlay")
report.orientation = tostring(game:GetService("StarterGui").ScreenOrientation)
report.streaming_enabled = workspace.StreamingEnabled
if report.studio_vehicle_sandbox then table.insert(report.warnings, "Studio sandbox is enabled: this session cannot verify persistence") end
table.sort(report.scripts, function(a,b) return a.path < b.path end)
if #report.blockers > 0 then report.status = "BLOCKER" end
print("[NTR Architecture Phase 1] " .. report.status .. " scripts=" .. #report.scripts .. " compileErrors=" .. #report.blockers)
return game:GetService("HttpService"):JSONEncode(report)
