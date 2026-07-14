-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
-- Event-driven participant visibility. No per-frame descendant scans.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local raceEvent=ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceEvent")
local sessions={}
local originals=setmetatable({},{__mode="k"})
local modelState=setmetatable({},{__mode="k"})
local modelAdded=setmetatable({},{__mode="k"})

local function vehiclesRoot()
	local world=Workspace:FindFirstChild("NeoTokyoRacersWorld") local runtime=world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end
local function remember(item,key,value) local data=originals[item] if not data then data={} originals[item]=data end if data[key]==nil then data[key]=value end end
local function original(item,key,fallback) local data=originals[item] return data and data[key]~=nil and data[key] or fallback end
local function toggleable(item) return item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") or item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") end
local function setOne(item,hidden)
	if item:IsA("BasePart") then remember(item,"LTM",item.LocalTransparencyModifier) item.LocalTransparencyModifier=hidden and 1 or original(item,"LTM",0)
	elseif item:IsA("Decal") or item:IsA("Texture") then remember(item,"Transparency",item.Transparency) item.Transparency=hidden and 1 or original(item,"Transparency",item.Transparency)
	elseif toggleable(item) then remember(item,"Enabled",item.Enabled) item.Enabled=hidden and false or original(item,"Enabled",item.Enabled) if hidden and (item:IsA("ParticleEmitter") or item:IsA("Trail")) then pcall(function() item:Clear() end) end
	elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") or item:IsA("Highlight") or item:IsA("SelectionBox") then remember(item,"Enabled",item.Enabled) item.Enabled=hidden and false or original(item,"Enabled",item.Enabled) end
	if item:IsA("Humanoid") then remember(item,"DisplayDistanceType",item.DisplayDistanceType) remember(item,"NameDisplayDistance",item.NameDisplayDistance) remember(item,"HealthDisplayDistance",item.HealthDisplayDistance) if hidden then item.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None item.NameDisplayDistance=0 item.HealthDisplayDistance=0 else item.DisplayDistanceType=original(item,"DisplayDistanceType",item.DisplayDistanceType) item.NameDisplayDistance=original(item,"NameDisplayDistance",item.NameDisplayDistance) item.HealthDisplayDistance=original(item,"HealthDisplayDistance",item.HealthDisplayDistance) end end
end
local function setModel(model,hidden)
	if not model or modelState[model]==hidden then return end
	modelState[model]=hidden
	setOne(model,hidden)
	for _,item in ipairs(model:GetDescendants()) do setOne(item,hidden) end
	if not modelAdded[model] then modelAdded[model]=model.DescendantAdded:Connect(function(item) if modelState[model]==true then setOne(item,true) end end) end
end
local function runSet(userId)
	local result={} for runId,session in pairs(sessions) do if session[tonumber(userId)] then result[runId]=true end end return result
end
local function shares(a,b) for runId in pairs(a) do if b[runId] then return true end end return false end
local function shouldHide(userId,explicitRun)
	if next(sessions)==nil then return false end
	local localRuns=runSet(player.UserId) local subjectRuns=runSet(userId)
	if explicitRun~="" then subjectRuns[explicitRun]=true end
	if next(localRuns) then return not shares(localRuns,subjectRuns) end
	return next(subjectRuns)~=nil
end
local function apply()
	for _,other in ipairs(Players:GetPlayers()) do setModel(other.Character,shouldHide(other.UserId,"")) end
	local root=vehiclesRoot()
	for _,vehicle in ipairs(root and root:GetChildren() or {}) do if vehicle:IsA("Model") then setModel(vehicle,shouldHide(vehicle:GetAttribute("OwnerUserId"),tostring(vehicle:GetAttribute("NTR_RaceRunId") or ""))) end end
end
local function restore() for _,other in ipairs(Players:GetPlayers()) do setModel(other.Character,false) end local root=vehiclesRoot() for _,vehicle in ipairs(root and root:GetChildren() or {}) do setModel(vehicle,false) end end
local function watchPlayer(other) other.CharacterAdded:Connect(function() task.defer(apply) end) end
Players.PlayerAdded:Connect(watchPlayer) for _,other in ipairs(Players:GetPlayers()) do watchPlayer(other) end
local watchedRoot=nil
local function watchVehicles()
	local root=vehiclesRoot() if root==watchedRoot then return end watchedRoot=root
	if root then root.ChildAdded:Connect(function() task.defer(apply) end) end
end
watchVehicles()
Workspace.DescendantAdded:Connect(function(item) if item.Name=="PlayerVehicles" then watchVehicles() end end)
raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload)~="table" then return end local kind=tostring(payload.Type or "") local runId=tostring(payload.RunId or "")
	if kind=="RaceVisibilityUpdate" and runId~="" then local set={} for _,id in ipairs(payload.Participants or {}) do set[tonumber(id)]=true end if payload.Active==true then sessions[runId]=set else sessions[runId]=nil end apply()
	elseif kind=="RaceFinished" or kind=="RaceDNF" or kind=="RaceExitedToStart" or kind=="RaceEnded" or kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" then if sessions[runId] then sessions[runId][player.UserId]=nil if next(sessions[runId])==nil then sessions[runId]=nil end end if next(sessions) then apply() else restore() end end
end)
print("[NTR Racing UI Phase 16E] Event-driven participant visibility active.")
