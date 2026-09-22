-- Studio Client only: bounded API lifecycle smoke test, not a driven lap or UI test.
-- Prerequisite: already own a sandbox vehicle. This invokes gameplay APIs, including race staging.
-- Read docs/architecture/performance-phase6-validation.md for limitations and the remaining gates.
assert(game.PlaceId==121304917315753 and game:GetService("RunService"):IsStudio())
local player=game.Players.LocalPlayer
assert(player:GetAttribute("StudioVehicleSandboxActive")==true,"Requires no-save sandbox")
local garage=game.ReplicatedStorage.Remotes.Garage.GarageInvoke
local race=game.ReplicatedStorage.Remotes.Racing.RaceRequest
local results={}
local function call(remote,action,payload)
 local start=os.clock()
 local ok,r=pcall(function()return remote:InvokeServer(action,payload or {})end)
 local passed=ok and type(r)=="table" and (r.Success==true or r.Ok==true)
 table.insert(results,{action=action,pass=passed,seconds=os.clock()-start,message=type(r)=="table" and r.Message or tostring(r)})
 task.wait(0.75)
 assert(passed,"Stopped after failed "..action)
 return r
end
for cycle=1,5 do
 local initial=call(garage,"GetInitial")
 call(garage,"SpawnVehicle")
 call(garage,"ExitVehicle")
 call(garage,"ReEnterVehicle")
 call(race,"StartTimeTrial",{EventId="shifted_canal_sprint_tt",VehicleId=initial.Profile.CurrentVehicleId})
 call(race,"CancelTimeTrial")
 call(garage,"DespawnVehicle")
end
return game.HttpService:JSONEncode({cycles=5,steps=results,playerAttributes=player:GetAttributes(),workspaceDescendants=#workspace:GetDescendants(),playerGuiDescendants=#player.PlayerGui:GetDescendants()})
