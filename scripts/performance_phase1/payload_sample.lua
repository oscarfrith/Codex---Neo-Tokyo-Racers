-- Studio Client only. Samples the existing public read request in sandbox.
-- No module requires or source edits; the normal handler may reconcile sandbox state.
assert(game.PlaceId == 121304917315753 and game:GetService("RunService"):IsStudio(), "Wrong place/environment")
local player = game:GetService("Players").LocalPlayer
assert(player and player:GetAttribute("StudioVehicleSandboxActive") == true, "Sandbox client required")
local remote = game.ReplicatedStorage.Remotes.Garage.GarageInvoke
local HttpService = game:GetService("HttpService")
local out = {}
for i = 1, 5 do
    local start = os.clock()
    local result = remote:InvokeServer("GetInitial", {})
    local elapsed = (os.clock() - start) * 1000
    local ok, encoded = pcall(function() return HttpService:JSONEncode(result) end)
    table.insert(out, {durationMs = elapsed, success = result.Success,
        jsonBytes = ok and #encoded or nil,
        catalogJsonBytes = result.Catalog and #HttpService:JSONEncode(result.Catalog) or nil,
        profileJsonBytes = result.Profile and #HttpService:JSONEncode(result.Profile) or nil})
    task.wait(0.5)
end
-- JSON size is a comparison proxy, not Roblox encoded network size. No profile values logged.
return HttpService:JSONEncode(out)
