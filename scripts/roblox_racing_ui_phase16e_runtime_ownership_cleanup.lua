-- Neo Tokyo Racers - Racing UI Phase 16E Runtime Ownership Cleanup
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Run INSTALL, restart Play, verify, then run SMOKE.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 16E"
local MARKER = "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP"

local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item = parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then fail("Missing " .. parent:GetFullName() .. "." .. name) end
	return item
end
local function replaceOnce(source, anchor, replacement, label)
	if string.find(source, replacement, 1, true) then return source end
	local first, last = string.find(source, anchor, 1, true)
	if not first then fail("Could not find " .. label .. " anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end
local function replaceRange(source, firstAnchor, nextAnchor, replacement, label)
	local first = string.find(source, firstAnchor, 1, true)
	if not first then fail("Could not find " .. label .. " start anchor. Refresh the Studio mirror before another source repair.") end
	local nextStart = string.find(source, nextAnchor, first + #firstAnchor, true)
	if not nextStart then fail("Could not find " .. label .. " end anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source, 1, first - 1) .. replacement .. "\n" .. string.sub(source, nextStart)
end

local controllers = must(must(must(StarterPlayer, "StarterPlayerScripts"), "NeoTokyoRacersClient"), "Controllers")
local racing = must(controllers, "Racing")
local ui = must(controllers, "UI")
local runtime = must(controllers, "Runtime")
local bootstrap = must(controllers.Parent, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled", "LuaSourceContainer")

local HEADLESS_ENTRY_SOURCE = [==[
-- NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP
-- Headless race-entry state/action bridge. This script intentionally constructs no UI.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local shared=kit:WaitForChild("Shared")
local remotes=shared:WaitForChild("Remotes")
local racingRemotes=remotes:WaitForChild("Racing")
local raceRequest=racingRemotes:WaitForChild("RaceRequest")
local raceEvent=racingRemotes:WaitForChild("RaceEvent")
local garageInvoke=remotes:WaitForChild("Garage"):WaitForChild("GarageInvoke")
local presentationRequest=script.Parent:WaitForChild("RaceEntryPresentationRequest")
local presentationAction=script.Parent:WaitForChild("RaceEntryLegacyAction")
local startRaceQueueEvent=script.Parent:WaitForChild("StartRaceQueueRequest")
local entry=nil

local function call(remote, action, payload)
	local ok,result=pcall(function() return remote:InvokeServer(action,payload or {}) end)
	if not ok then return {Success=false,Ok=false,Message=tostring(result)} end
	return type(result)=="table" and result or {Success=result==true,Ok=result==true}
end
local function uiEvent(name)
	local folder=script.Parent.Parent:FindFirstChild("UI")
	local event=folder and folder:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then event:Fire() end
end
local function cockpitFor(vehicleId, supplied)
	if tostring(supplied or "")~="" then return tostring(supplied) end
	local result=call(garageInvoke,"GetInitial",{})
	local profile=result.Profile or result.Data or result
	local vehicle=profile and profile.Vehicles and (profile.Vehicles[vehicleId] or profile.Vehicles[tostring(vehicleId)])
	if not vehicle then return "" end
	if tostring(vehicle.CockpitId or "")~="" then return tostring(vehicle.CockpitId) end
	local owned=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return tostring(owned and owned.TemplateId or "")
end
local function spawnVehicle(data)
	local vehicleId=tostring(data.VehicleId or "")
	if vehicleId=="" then return false,"No vehicle selected." end
	local cockpitId=cockpitFor(vehicleId,data.CockpitId)
	local result=call(garageInvoke,"SpawnOwnedVehicleFromFreeRoam",{VehicleId=vehicleId,CockpitId=cockpitId})
	if result.Success~=true and result.Ok~=true then
		local selected=call(garageInvoke,"SelectVehicleInstance",{VehicleId=vehicleId,CockpitId=cockpitId})
		if selected.Success~=true and selected.Ok~=true then return false,tostring(selected.Message or result.Message or "Vehicle selection failed.") end
		result=call(garageInvoke,"SpawnVehicle",{})
		if result.Success~=true and result.Ok~=true then return false,tostring(result.Message or "Vehicle spawn failed.") end
	end
	uiEvent("FreeRoamVehicleSpawned")
	return true,cockpitId
end

presentationAction.Event:Connect(function(action,data)
	data=type(data)=="table" and data or {}
	if action~="StartSelectedVehicle" then return end
	local ok,cockpitOrMessage=spawnVehicle(data)
	if not ok then warn("[NTR Phase 16E Entry Bridge] "..cockpitOrMessage) return end
	task.wait(0.35)
	local mode=tostring(data.Mode)=="Race" and "Race" or "TimeTrial"
	local eventId=tostring(data.EventId or (entry and entry.EventId) or "")
	if mode=="Race" then
		startRaceQueueEvent:Fire({EventId=eventId,VehicleId=tostring(data.VehicleId),CockpitId=cockpitOrMessage,DisplayName=entry and entry.Summary and entry.Summary.DisplayName})
	else
		local result=call(raceRequest,"StartStagedTimeTrial",{EventId=eventId,VehicleId=tostring(data.VehicleId),LapCount=tonumber(data.LapCount) or 1})
		if result.Success~=true and result.Ok~=true then warn("[NTR Phase 16E Entry Bridge] "..tostring(result.Message or "Time trial start failed.")) end
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload)~="table" then return end
	local kind=tostring(payload.Type or "")
	if kind=="OpenRaceEntry" then
		entry={EventId=payload.EventId,RaceEventId=payload.RaceEventId,TimeTrialEventId=payload.TimeTrialEventId,Summary=payload.Summary}
		presentationRequest:Fire(payload)
	elseif kind=="TimeTrialStarted" then
		local route=Workspace:FindFirstChild("NeoTokyoRacersWorld")
		route=route and route:FindFirstChild("RaceRoutes")
		route=route and route:FindFirstChild(tostring(payload.RouteId or ""))
		local gate=route and route:FindFirstChild("Checkpoint1",true)
		if gate and gate:IsA("BasePart") then pcall(function() player:RequestStreamAroundAsync(gate.Position,3) end) end
		task.defer(function() uiEvent("FreeRoamVehicleSpawned") end)
	elseif kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceExitedToStart" then
		uiEvent("FreeRoamVehicleExited")
	end
end)
print("[NTR Racing UI Phase 16E] Headless race-entry bridge active.")
]==]

local VISIBILITY_SOURCE = [==[
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
]==]

local function installMobileOnly(localScript, moduleName)
	local module = localScript.Parent:FindFirstChild(moduleName)
	if not module then
		module = Instance.new("ModuleScript") module.Name = moduleName module.Source = localScript.Source .. "\nreturn true" module.Parent = localScript.Parent
	elseif not module:IsA("ModuleScript") then fail(module:GetFullName() .. " must be a ModuleScript") end
	localScript.Source = "-- "..MARKER.."\nlocal UserInputService=game:GetService(\"UserInputService\")\nif not UserInputService.TouchEnabled then return end\nrequire(script.Parent:WaitForChild(\""..moduleName.."\"))"
	localScript.Disabled = false
end

local function publishFunction(owner, keepTelemetry)
	return "local function publishPresentation(open)\n\tlocal folder=script.Parent.Parent:FindFirstChild(\"UI\")\n\tlocal event=folder and folder:FindFirstChild(\"FreeRoamHudPresentationMode\")\n\tif event and event:IsA(\"BindableEvent\") then event:Fire({Owner=\""..owner.."\",Active=open==true,KeepTelemetry="..tostring(keepTelemetry).."}) end\nend\n"
end

local function install()
	-- Obsolete racing presentation owners: never start them again.
	for _,name in ipairs({"RaceClient_Active","RaceSessionControlsClient_Active","RaceHudExitCleanupClient_Active"}) do
		local item=must(racing,name,"LocalScript") item.Disabled=true item:SetAttribute("NTRRetiredByPhase16E",true)
	end
	local entry=must(racing,"RaceEntryMenuClient_Active","LocalScript") entry.Source=HEADLESS_ENTRY_SOURCE entry.Disabled=false
	local visibility=must(racing,"RaceParticipantVisibilityClient_Active","LocalScript") visibility.Source=VISIBILITY_SOURCE visibility.Disabled=false

	-- Large legacy free-roam controllers are loaded only on touch devices.
	installMobileOnly(must(ui,"FreeRoamNavController_Active","LocalScript"),"FreeRoamNavMobileLegacy")
	installMobileOnly(must(ui,"FreeRoamVehicleExitButton_Active","LocalScript"),"FreeRoamVehicleExitMobileLegacy")
	installMobileOnly(must(runtime,"DriveHudController_Active","LocalScript"),"DriveHudMobileLegacy")
	installMobileOnly(must(runtime,"MobileDriveControlsController_Active","LocalScript"),"MobileDriveControlsLegacy")

	-- Register-limited bootstrap: replace only the drive-HUD constructor entrance with a table proxy on PC.
	if not string.find(bootstrap.Source,MARKER,1,true) then bootstrap.Source=replaceOnce(bootstrap.Source,
		"local function ensureDriveHud()\n\tif driveGui and driveGui.Parent then return end",
		"local function ensureDriveHud()\n\t-- "..MARKER.."\n\tif driveGui and driveGui.Parent then return end\n\tif not UserInputService.TouchEnabled then driveGui={Name=\"NTR_HeadlessDriveHudProxy\",Parent=player:WaitForChild(\"PlayerGui\"),Enabled=false} driveHud=nil return end",
		"headless desktop drive HUD") end

	-- Old checkpoint badge is no longer constructed; world course guidance remains intact.
	local route=must(racing,"RaceRouteGuideClient_Active","LocalScript")
	if not string.find(route.Source,MARKER,1,true) then route.Source=replaceRange(route.Source,"local function ensureCheckpointHud()","local function makeBillboard", "local function setCheckpointHud(_text,_color)\n\t-- "..MARKER..": presentation owned by RaceSessionPresentationController_Active.\nend", "legacy checkpoint badge") end

	-- Local course arrows: authored transparency wins; otherwise visible means zero transparency.
	local assets=must(racing,"RaceSessionAssetsClient_Active","LocalScript")
	if not string.find(assets.Source,MARKER,1,true) then
		assets.Source=replaceOnce(assets.Source,"tonumber(item:GetAttribute(\"NTR_ArrowOriginalTransparency\")) or item.Transparency","tonumber(item:GetAttribute(\"NTR_ArrowOriginalTransparency\")) or 0","local arrow visibility fallback")
		assets.Source="-- "..MARKER.."\n"..assets.Source
	end

	-- Current entry UI publishes state on PC instead of scanning/suppressing every ScreenGui.
	local entryPresentation=must(racing,"RaceEntryPresentationController_Active","LocalScript")
	if not string.find(entryPresentation.Source,MARKER,1,true) then
	entryPresentation.Source=replaceOnce(entryPresentation.Source,
		"legacyAction:Fire(\"StartSelectedVehicle\", { Mode = selectedMode, EventId = pairedEventId(selectedMode), VehicleId = selectedVehicleId, Tier = selectedTier, LapCount = selectedLap })",
		"local selectedRow\n\t\tfor _,row in ipairs(racingVehicleRows()) do if row.VehicleId==selectedVehicleId then selectedRow=row break end end\n\t\tlegacyAction:Fire(\"StartSelectedVehicle\", { Mode = selectedMode, EventId = pairedEventId(selectedMode), VehicleId = selectedVehicleId, CockpitId = selectedRow and selectedRow.CockpitId, Tier = selectedTier, LapCount = selectedLap })",
		"entry cockpit handoff")
	entryPresentation.Source=replaceRange(entryPresentation.Source,"local function suppressOthers(open)","local function setOpen(open)",publishFunction("RaceEntry",false).."local function suppressOthers(open)\n\tif not touch then publishPresentation(open) return end\n\t-- Mobile keeps its independent compatibility suppression.\n\tif open then\n\t\ttable.clear(suppressed)\n\t\tlocal function suppress(item) if item:IsA(\"ScreenGui\") and item~=gui then if suppressed[item]==nil then suppressed[item]=item.Enabled end item.Enabled=false end end\n\t\tfor _,item in ipairs(playerGui:GetChildren()) do suppress(item) end suppressAdded=playerGui.ChildAdded:Connect(suppress)\n\telse\n\t\tif suppressAdded then suppressAdded:Disconnect() suppressAdded=nil end\n\t\tfor item,enabled in pairs(suppressed) do if item.Parent then item.Enabled=enabled end end table.clear(suppressed)\n\tend\nend", "entry UI ownership")
	entryPresentation.Source="-- "..MARKER.."\n"..entryPresentation.Source end

	local browser=must(racing,"RaceBrowserClient_Active","LocalScript")
	if not string.find(browser.Source,MARKER,1,true) then browser.Source=replaceRange(browser.Source,"local function setOpen(open)","local function teleportSelected()",publishFunction("RaceBrowser",false).."local function setOpen(open)\n\tif not touch then\n\t\tpublishPresentation(open)\n\telse\n\t\tif open then\n\t\t\ttable.clear(suppressedGuis) local function suppress(child) if child:IsA(\"ScreenGui\") and child~=gui then if suppressedGuis[child]==nil then suppressedGuis[child]=child.Enabled end child.Enabled=false end end\n\t\t\tfor _,child in ipairs(playerGui:GetChildren()) do suppress(child) end suppressionChildAdded=playerGui.ChildAdded:Connect(suppress)\n\t\telse\n\t\t\tif suppressionChildAdded then suppressionChildAdded:Disconnect() suppressionChildAdded=nil end for otherGui,wasEnabled in pairs(suppressedGuis) do if otherGui.Parent then otherGui.Enabled=wasEnabled end end table.clear(suppressedGuis)\n\t\tend\n\tend\n\toverlay.Visible=open\n\tif open then buildRows() renderList() renderDetail() status.Visible=false end\nend", "browser UI ownership") browser.Source="-- "..MARKER.."\n"..browser.Source end

	local session=must(racing,"RaceSessionPresentationController_Active","LocalScript")
	if not string.find(session.Source,MARKER,1,true) then session.Source=replaceOnce(session.Source,"local function suppress(active) for _,name in ipairs({\"NTR_RaceHud\",\"NTR_RaceHud_Phase3\",\"NTR_RaceCheckpointBadge_Phase5D\",\"NTR_RaceQueue_Phase8\",\"NTR_RaceSessionControls_Phase8D\"}) do local other=playerGui:FindFirstChild(name) if other and other:IsA(\"ScreenGui\") then if active and suppressed[other]==nil then suppressed[other]=other.Enabled other.Enabled=false elseif not active and suppressed[other]~=nil then other.Enabled=suppressed[other] suppressed[other]=nil end end end end","local function suppress(_active) end -- "..MARKER,"session legacy suppression")
	session.Source=replaceOnce(session.Source,"local function presentationMode(enabled) if freeRoamMode and freeRoamMode:IsA(\"BindableEvent\") then freeRoamMode:Fire(enabled and \"Racing\" or \"FreeRoam\") end end","local function presentationMode(enabled) if freeRoamMode and freeRoamMode:IsA(\"BindableEvent\") then freeRoamMode:Fire({Owner=\"RaceSession\",Active=enabled==true,KeepTelemetry=true}) end end","session explicit state")
	session.Source=replaceOnce(session.Source,"local function hide(restoreLegacy) active=nil clearHudMapState() canvas.Visible=false modalShade.Visible=false busy=false if restoreLegacy~=false then suppress(false) presentationMode(false) end clear(boardBody) end","local function hide(_restoreLegacy) active=nil clearHudMapState() canvas.Visible=false modalShade.Visible=false busy=false suppress(false) presentationMode(false) clear(boardBody) end","session ownership release")
	session.Source=replaceOnce(session.Source,"RunService.RenderStepped:Connect(function(dt) updateHudMapMarker(dt) if active and active.Mode==\"TimeTrial\" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)","RunService.RenderStepped:Connect(function(dt) if not active then return end updateHudMapMarker(dt) if active.Mode==\"TimeTrial\" and active.Running and active.LapLocalStart then metricValue.Text=timeText(os.clock()-active.LapLocalStart) end end)","inactive session render gate") end

	-- Phase 8H remains the confirmed reset/camera owner, but no longer polls PlayerGui to hide retired HUDs.
	local transition=must(racing,"RaceTransitionClient_Active","LocalScript")
	if not string.find(transition.Source,MARKER,1,true) then
		transition.Source=replaceRange(transition.Source,"local function suppressFreeRoamHud()","local function tweenFade", "local function suppressFreeRoamHud() end -- "..MARKER, "transition legacy HUD suppression")
		transition.Source=replaceOnce(transition.Source,"RunService.Heartbeat:Connect(function()\n\tif sessionActive and os.clock() - lastHudPulse > 0.2 then\n\t\tlastHudPulse = os.clock()\n\t\tsuppressFreeRoamHud()\n\tend\nend)","-- "..MARKER..": no HUD suppression heartbeat; presentation owners publish lifecycle state.","transition HUD polling loop")
	end

	local results=must(racing,"RaceTimeTrialResultCoachClient_Active","LocalScript")
	if not string.find(results.Source,MARKER,1,true) then results.Source=replaceRange(results.Source,"local function setSuppressed(open)","local function fireDrivingExit()",publishFunction("RaceResults",false).."local function setSuppressed(open)\n\tif not touch then publishPresentation(open) return end\n\tlocal other=playerGui:FindFirstChild(\"NTR_RaceQueue_Phase8\") if other and other~=gui then if open and suppressed[other]==nil then suppressed[other]=other.Enabled other.Enabled=false elseif not open and suppressed[other]~=nil then other.Enabled=suppressed[other] suppressed[other]=nil end end\nend", "results UI ownership")
	results.Source=string.gsub(results.Source,"\n\tfor _, delaySeconds in ipairs%(%{0,0%.05,0%.2,0%.5%}%) do task%.delay%(delaySeconds,function%(%) if overlay%.Visible then hideLegacyResultPanel%(%) end end%) end","")
	results.Source="-- "..MARKER.."\n"..results.Source end

	-- Phase 4A desktop shell owns current PC UI and honours named presentation states.
	local desktop=must(ui,"DesktopFreeRoamHudController_Active","LocalScript")
	if not string.find(desktop.Source,MARKER,1,true) then desktop.Source=replaceOnce(desktop.Source,"local racingPresentationActive = false -- NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE","local racingPresentationActive = false -- NTR_PC_FREEROAM_RACING_PRESENTATION_BRIDGE\nlocal racingTelemetryOnly = false\nlocal presentationOwners = {} -- "..MARKER,"desktop presentation state")
	desktop.Source=replaceRange(desktop.Source,"local function suppressLegacyDesktop()","local function closeChoiceList()","local function suppressLegacyDesktop() end -- "..MARKER, "desktop legacy suppression")
	desktop.Source=replaceOnce(desktop.Source,"local function updateRuntime(dt)\n\tsuppressLegacyDesktop()","local function updateRuntime(dt)\n\tif racingPresentationActive and not racingTelemetryOnly then gui.Enabled=false return end\n\tgui.Enabled=true","desktop inactive gate")
	desktop.Source=replaceRange(desktop.Source,"local presentationEvent=script.Parent:FindFirstChild(\"FreeRoamHudPresentationMode\")","pcall(function() RunService:UnbindFromRenderStep(\"NTR_PCFreeRoamHudPhase1\") end)","local presentationEvent=script.Parent:FindFirstChild(\"FreeRoamHudPresentationMode\")\nif presentationEvent and presentationEvent:IsA(\"BindableEvent\") then\n\tpresentationEvent.Event:Connect(function(message)\n\t\tif typeof(message)==\"table\" then\n\t\t\tlocal owner=tostring(message.Owner or \"Racing\") presentationOwners[owner]=message.Active==true and {KeepTelemetry=message.KeepTelemetry==true} or nil\n\t\telse presentationOwners.Racing=tostring(message)==\"Racing\" and {KeepTelemetry=true} or nil end\n\t\tracingPresentationActive=next(presentationOwners)~=nil racingTelemetryOnly=racingPresentationActive\n\t\tfor _,state in pairs(presentationOwners) do if not state.KeepTelemetry then racingTelemetryOnly=false break end end\n\t\tif racingPresentationActive then carPanel.Visible=false closeChoiceList() closeModal() end\n\t\tif not racingPresentationActive then gui.Enabled=true end\n\tend)\nend\n", "desktop explicit lifecycle") end

	log("Installed. Legacy PC UI owners no longer construct interfaces; mobile loaders remain separate; current UI now uses explicit lifecycle ownership.")
end

local function smoke()
	for _,name in ipairs({"RaceClient_Active","RaceSessionControlsClient_Active","RaceHudExitCleanupClient_Active"}) do if not must(racing,name,"LocalScript").Disabled then fail(name.." is not retired") end end
	if not string.find(must(racing,"RaceEntryMenuClient_Active","LocalScript").Source,"Headless race-entry state/action bridge",1,true) then fail("Headless entry bridge missing") end
	if string.find(must(racing,"RaceParticipantVisibilityClient_Active","LocalScript").Source,"BindToRenderStep",1,true) then fail("Participant visibility still has a render-step scan") end
	if not string.find(must(racing,"RaceSessionAssetsClient_Active","LocalScript").Source,"NTR_ArrowOriginalTransparency\")) or 0",1,true) then fail("Arrow visibility fallback missing") end
	if string.find(must(racing,"RaceRouteGuideClient_Active","LocalScript").Source,"NTR_RaceCheckpointBadge_Phase5D",1,true) then fail("Old checkpoint badge constructor remains") end
	for _,pair in ipairs({{ui,"FreeRoamNavController_Active"},{ui,"FreeRoamVehicleExitButton_Active"},{runtime,"DriveHudController_Active"},{runtime,"MobileDriveControlsController_Active"}}) do if not string.find(must(pair[1],pair[2],"LocalScript").Source,MARKER,1,true) then fail(pair[2].." is not a mobile-only loader") end end
	local sessionSource=must(racing,"RaceSessionPresentationController_Active","LocalScript").Source
	if string.find(sessionSource,"OpponentMarker",1,true) or string.find(sessionSource,"OtherPlayerMarker",1,true) then fail("Opponent map marker presentation remains") end
	if not string.find(sessionSource,"PlayerMarker",1,true) then fail("Local map marker owner missing") end
	local transitionSource=must(racing,"RaceTransitionClient_Active","LocalScript").Source
	if string.find(transitionSource,"suppressFreeRoamHud()\n\tend\nend)",1,true) then fail("Transition HUD suppression polling remains") end
	if not string.find(bootstrap.Source,"NTR_HeadlessDriveHudProxy",1,true) then fail("Desktop bootstrap HUD proxy missing") end
	log("SMOKE PASS: legacy PC presentations retired, mobile isolated, local-only map marker retained, arrow fallback repaired, and visibility is event-driven.")
end

if MODE=="INSTALL" then install() elseif MODE=="SMOKE" then smoke() else fail("MODE must be INSTALL or SMOKE") end
