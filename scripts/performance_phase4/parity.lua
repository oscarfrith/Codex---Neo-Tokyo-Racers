-- Run the preserved calculation parity harness against relocated authoring templates.
-- Uses isolated loadstring evaluation, never gameplay require through MCP.
assert(game.PlaceId==121304917315753 and not game:GetService("RunService"):IsRunning())
local source=game.HttpService:GetAsync("http://127.0.0.1:8776/performance_phase3/parity.lua")
local from="local root=game.ReplicatedStorage.Assets.Vehicles.Categories"
assert(source:find(from,1,true),"Parity harness anchor changed")
source=source:gsub("local root=game.ReplicatedStorage.Assets.Vehicles.Categories","local root=game.ServerStorage.Assets.Vehicles.Categories",1)
return assert(loadstring(source))()
