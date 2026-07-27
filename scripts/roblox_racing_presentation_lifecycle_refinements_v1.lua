-- Neo Tokyo Racers - Racing Presentation And Lifecycle Refinements V1.4
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- INSTALL:
--   1. Leave MODE = "INSTALL".
--   2. Run once in Edit mode.
--   3. Restart Play and complete the documented verification matrix.
--
-- AUDIT:
--   1. Change MODE to "AUDIT".
--   2. Run in Edit mode after verification.
--
-- This is one transactional, idempotent installer. It creates no in-game backup
-- scripts/folders. A failed install restores every source, attribute and enabled
-- state changed by that run. Studio history before INSTALL is the durable rollback.

local MODE = "INSTALL" -- INSTALL or AUDIT
local PHASE = "NTR Racing Presentation Lifecycle V1.4"
local REVISION = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_4"
local PREVIOUS_REVISION = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_3"
local V1_2_REVISION = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_2"
local V1_1_REVISION = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_1"
local V1_REVISION = "NTR_RACING_PRESENTATION_LIFECYCLE_V1"
local PROMPT_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_NATIVE_PROMPT"
local GUIDE_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_GUIDE"
local GUIDE_V1_2_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_2_MOBILE_CHECKPOINT_UI"
local HUD_V1_3_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_3_FULLSCREEN_EXIT"
local HUD_V1_4_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_4_ADAPTIVE_SAFE_EDGE_CANVAS"
local ASSETS_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_DORMANT_ARROWS"
local ASSETS_V1_1_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_1_ROUTE_ARROWS"
local CONTROLLER_MARKER = "NTR_RACING_PRESENTATION_LIFECYCLE_V1_3_LEGACY_RETIREMENT"
local CONTROLLER_NAME = "RaceLifecyclePresentationController_Active"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. tostring(parent and parent:GetFullName() or "<nil>") .. "." .. tostring(name))
	end
	return item
end

local function countPlain(source, needle)
	local count = 0
	local cursor = 1
	while true do
		local first = string.find(source, needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = first + #needle
	end
end

local function replaceOnce(source, anchor, replacement, label)
	local count = countPlain(source, anchor)
	if count ~= 1 then
		fail(label .. " anchor count expected 1, got " .. tostring(count) .. ". Refresh and inspect the live mirror; do not loosen this anchor.")
	end
	local first, last = string.find(source, anchor, 1, true)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function insertBeforeOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, insertion .. anchor, label)
end

local function compile(source, label)
	local chunk, problem = loadstring(source, "=" .. tostring(label))
	if not chunk then
		fail(label .. " compile failed: " .. tostring(problem))
	end
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = must(kit, "Config", "Folder")
local racingConfig = must(config, "Racing", "Folder")
local routeGuideConfig = must(racingConfig, "RouteGuide", "Folder")
local shared = must(kit, "Shared", "Folder")
local remotes = must(shared, "Remotes", "Folder")
local racingRemotes = must(remotes, "Racing", "Folder")
must(racingRemotes, "RaceEvent", "RemoteEvent")

local serverRoot = must(ServerScriptService, "NeoTokyoRacers", "Folder")
local services = must(serverRoot, "Services", "Folder")
local serverRacing = must(services, "Racing", "Folder")
local timeTrial = must(serverRacing, "TimeTrialService_Active", "Script")
local matchmaking = must(serverRacing, "RaceMatchmakingService_Active", "Script")

local starterScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")
local racing = must(controllers, "Racing", "Folder")
local ui = must(controllers, "UI", "Folder")
local routeGuide = must(racing, "RaceRouteGuideClient_Active", "LocalScript")
local sessionAssets = must(racing, "RaceSessionAssetsClient_Active", "LocalScript")
local sharedSession = must(racing, "RaceSessionPresentationController_Active", "LocalScript")
local transition = must(racing, "RaceTransitionClient_Active", "LocalScript")
local entry = must(racing, "RaceEntryMenuClient_Active", "LocalScript")
local entryPresentation = must(racing, "RaceEntryPresentationController_Active", "LocalScript")
local results = must(racing, "RaceTimeTrialResultCoachClient_Active", "LocalScript")
local queue = must(racing, "RaceQueueClient_Active", "LocalScript")
local countdown = must(racing, "RaceCountdownPresentationController_Active", "LocalScript")
local raceClient = must(racing, "RaceClient_Active", "LocalScript")
local oldControls = must(racing, "RaceSessionControlsClient_Active", "LocalScript")
local oldCleanup = must(racing, "RaceHudExitCleanupClient_Active", "LocalScript")
local personalBestBoard = racing:FindFirstChild("RacePersonalBestBoardClient_Active")
if personalBestBoard and not personalBestBoard:IsA("LocalScript") then
	fail("RacePersonalBestBoardClient_Active exists but is not a LocalScript.")
end
local loadingState = must(ui, "LoadingPresentationState")
local entryAction = must(racing, "RaceEntryLegacyAction", "BindableEvent")

local LEGACY_GUI_NAMES = {
	"NTR_RaceHud",
	"NTR_RaceHud_Phase3",
	"NTR_RaceCheckpointBadge_Phase5D",
	"NTR_RaceQueue_Phase8",
	"NTR_RaceSessionControls_Phase8C",
	"NTR_RaceSessionControls_Phase8D",
	"NTR_RaceResults_Phase4",
	"NTR_TimeTrialResultCoach",
	"NTR_RaceEntry",
	"NTR_RaceEntryProbe",
	"NTR_TimeTrialPersonalBestBoard",
}

local CONTROLLER_SOURCE = [==[
-- NTR_RACING_PRESENTATION_LIFECYCLE_V1_3_LEGACY_RETIREMENT
-- Local-only start-zone aura/prompt eligibility and exact legacy racing surface cleanup.
-- Server race state, prompts, checkpoints, timing, rewards and persistence remain authoritative.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local controllers=script.Parent.Parent
local ui=controllers:WaitForChild("UI")
local loadingState=ui:WaitForChild("LoadingPresentationState")
local raceEvent=kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceEvent")
local entryAction=script.Parent:WaitForChild("RaceEntryLegacyAction")

local legacyNames={
	NTR_RaceHud=true,
	NTR_RaceHud_Phase3=true,
	NTR_RaceCheckpointBadge_Phase5D=true,
	NTR_RaceQueue_Phase8=true,
	NTR_RaceSessionControls_Phase8C=true,
	NTR_RaceSessionControls_Phase8D=true,
	NTR_RaceResults_Phase4=true,
	NTR_TimeTrialResultCoach=true,
	NTR_RaceEntry=true,
	NTR_RaceEntryProbe=true,
	NTR_TimeTrialPersonalBestBoard=true,
}

local entryOpen=false
local launchPending=false
local launchGeneration=0
local activeSession=false
local activeRunId=""
local stateGeneration=0
local trackedZones=setmetatable({},{__mode="k"})
local originals=setmetatable({},{__mode="k"})
local connections={}
local PROMPT_NAME="NTR_RaceEntryPrompt"

local function connect(signal,callback)
	local connection=signal:Connect(callback)
	table.insert(connections,connection)
	return connection
end

local function destroyLegacy(child)
	if child and child:IsA("ScreenGui") and legacyNames[child.Name] then
		child:Destroy()
	end
end

for _,child in ipairs(playerGui:GetChildren()) do destroyLegacy(child) end
connect(playerGui.ChildAdded,destroyLegacy)

local function remember(item,key,value)
	local record=originals[item]
	if not record then record={} originals[item]=record end
	if record[key]==nil then record[key]=value end
end

local function original(item,key,fallback)
	local record=originals[item]
	if record and record[key]~=nil then return record[key] end
	return fallback
end

local function setAuraItem(item,visible)
	if item:IsA("BasePart") then
		remember(item,"LocalTransparencyModifier",item.LocalTransparencyModifier)
		item.LocalTransparencyModifier=visible and original(item,"LocalTransparencyModifier",0) or 1
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail")
		or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
		or item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
		remember(item,"Enabled",item.Enabled)
		-- Eligible means visibly on, even if the authored emitter happened to be disabled.
		item.Enabled=visible
		if not visible and (item:IsA("ParticleEmitter") or item:IsA("Trail")) then
			pcall(function() item:Clear() end)
		end
	end
end

local function restoreAuraItem(item)
	if item:IsA("BasePart") then
		item.LocalTransparencyModifier=original(item,"LocalTransparencyModifier",item.LocalTransparencyModifier)
	elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail")
		or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
		or item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
		item.Enabled=original(item,"Enabled",item.Enabled)
	end
end

local function isBlocked()
	return player:GetAttribute("NTR_StartScreenActive")==true
		or player:GetAttribute("NTR_RaceQueueActive")==true
		or loadingState:GetAttribute("Active")==true
		or entryOpen
		or launchPending
		or activeSession
end

local function auraRoots(zone)
	local roots={}
	for _,child in ipairs(zone:GetChildren()) do
		if string.lower(child.Name)=="vfx_aura" then table.insert(roots,child) end
	end
	return roots
end

local function desiredPromptEnabled(zone)
	return not isBlocked() and zone:GetAttribute("Enabled")~=false
end

local function applyPrompt(zone,prompt)
	if prompt and prompt.Parent and prompt:IsA("ProximityPrompt") and prompt.Name==PROMPT_NAME then
		local enabled=desiredPromptEnabled(zone)
		if prompt.Enabled~=enabled then prompt.Enabled=enabled end
	end
end

local function applyZone(zone,generation)
	if generation~=stateGeneration or not zone.Parent then return end
	local visible=desiredPromptEnabled(zone)
	for _,root in ipairs(auraRoots(zone)) do
		setAuraItem(root,visible)
		for _,item in ipairs(root:GetDescendants()) do setAuraItem(item,visible) end
	end
	for _,child in ipairs(zone:GetChildren()) do applyPrompt(zone,child) end
end

local function refresh()
	stateGeneration+=1
	local generation=stateGeneration
	for zone in pairs(trackedZones) do
		task.defer(applyZone,zone,generation)
	end
end

local function isRaceStartZone(item)
	if not (item:IsA("BasePart") and item.Parent and item.Parent.Name=="StartZones") then return false end
	local mode=tostring(item:GetAttribute("Mode") or "")
	return mode=="Race" or mode=="TimeTrial"
end

local function trackZone(zone)
	if trackedZones[zone] or not isRaceStartZone(zone) then return end
	local record={Connections={},Prompts=setmetatable({},{__mode="k"})}
	trackedZones[zone]=record
	local function trackPrompt(prompt)
		if not (prompt:IsA("ProximityPrompt") and prompt.Name==PROMPT_NAME) or record.Prompts[prompt] then return end
		local connection
		connection=prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			local generation=stateGeneration
			task.defer(applyZone,zone,generation)
		end)
		record.Prompts[prompt]=connection
		table.insert(record.Connections,connection)
		applyPrompt(zone,prompt)
	end
	table.insert(record.Connections,zone.ChildAdded:Connect(function(child)
		if string.lower(child.Name)=="vfx_aura" then
			table.insert(record.Connections,child.DescendantAdded:Connect(function()
				refresh()
			end))
			refresh()
		elseif child:IsA("ProximityPrompt") and child.Name==PROMPT_NAME then
			trackPrompt(child)
			refresh()
		end
	end))
	for _,child in ipairs(zone:GetChildren()) do
		if string.lower(child.Name)=="vfx_aura" then
			table.insert(record.Connections,child.DescendantAdded:Connect(function()
				refresh()
			end))
		elseif child:IsA("ProximityPrompt") and child.Name==PROMPT_NAME then
			trackPrompt(child)
		end
	end
	table.insert(record.Connections,zone:GetAttributeChangedSignal("Enabled"):Connect(refresh))
	table.insert(record.Connections,zone.AncestryChanged:Connect(function(_,parent)
		if parent then return end
		for _,connection in ipairs(record.Connections) do connection:Disconnect() end
		trackedZones[zone]=nil
	end))
	refresh()
end

for _,item in ipairs(Workspace:GetDescendants()) do
	if isRaceStartZone(item) then trackZone(item) end
end
connect(Workspace.DescendantAdded,function(item)
	if isRaceStartZone(item) then trackZone(item) end
end)

local terminalKinds={
	TimeTrialFinished=true,TimeTrialEnded=true,TimeTrialError=true,
	RaceFinished=true,RaceDNF=true,RaceEnded=true,RaceExitedToStart=true,RaceQueueError=true,
}
local activeKinds={
	TimeTrialStaged=true,TimeTrialCountdownReveal=true,TimeTrialCountdownScheduled=true,
	TimeTrialCountdown=true,TimeTrialStarted=true,
	RaceStaged=true,RaceCountdownReveal=true,RaceCountdownScheduled=true,
	RaceCountdown=true,RaceStarted=true,
}

connect(raceEvent.OnClientEvent,function(payload)
	if typeof(payload)~="table" then return end
	local kind=tostring(payload.Type or "")
	if kind=="OpenRaceEntry" then
		entryOpen=true
		launchPending=false
		launchGeneration+=1
	elseif activeKinds[kind] then
		entryOpen=false
		launchPending=false
		launchGeneration+=1
		activeSession=true
		local runId=tostring(payload.RunId or "")
		if runId~="" then activeRunId=runId end
	elseif terminalKinds[kind] then
		local runId=tostring(payload.RunId or "")
		if activeRunId=="" or runId=="" or runId==activeRunId then
			entryOpen=false
			launchPending=false
			launchGeneration+=1
			activeSession=false
			activeRunId=""
		end
	end
	refresh()
end)

connect(entryAction.Event,function(action)
	if action=="Close" then
		entryOpen=false
		launchPending=false
		launchGeneration+=1
	elseif action=="StartSelectedVehicle" then
		entryOpen=false
		launchPending=true
		launchGeneration+=1
		local generation=launchGeneration
		task.delay(3,function()
			if generation~=launchGeneration or activeSession then return end
			if loadingState:GetAttribute("Active")==true or player:GetAttribute("NTR_RaceQueueActive")==true then return end
			launchPending=false
			refresh()
		end)
	end
	refresh()
end)

connect(player:GetAttributeChangedSignal("NTR_StartScreenActive"),refresh)
connect(player:GetAttributeChangedSignal("NTR_RaceQueueActive"),function()
	if player:GetAttribute("NTR_RaceQueueActive")~=true and launchPending and not activeSession and loadingState:GetAttribute("Active")~=true then
		launchPending=false
		launchGeneration+=1
	end
	refresh()
end)
connect(loadingState:GetAttributeChangedSignal("Active"),function()
	if loadingState:GetAttribute("Active")~=true and launchPending and not activeSession and player:GetAttribute("NTR_RaceQueueActive")~=true then
		launchPending=false
		launchGeneration+=1
	end
	refresh()
end)
connect(player.CharacterAdded,function()
	-- Preserve an active reset session, but invalidate every pending visibility write.
	refresh()
end)

script.Destroying:Connect(function()
	stateGeneration+=1
	for _,connection in ipairs(connections) do connection:Disconnect() end
	for zone,record in pairs(trackedZones) do
		for _,connection in ipairs(record.Connections) do connection:Disconnect() end
		for _,root in ipairs(zone.Parent and auraRoots(zone) or {}) do
			restoreAuraItem(root)
			for _,item in ipairs(root:GetDescendants()) do restoreAuraItem(item) end
		end
		for _,child in ipairs(zone.Parent and zone:GetChildren() or {}) do
			if child:IsA("ProximityPrompt") and child.Name==PROMPT_NAME then
				child.Enabled=zone:GetAttribute("Enabled")~=false
			end
		end
	end
end)

refresh()
script:SetAttribute("NTR_AuraVisibilityOwnerReady",true)
script:SetAttribute("NTR_PromptVisibilityOwnerReady",true)
print("[NTR Racing Presentation Lifecycle V1.3] All-start-zone aura, prompt and legacy-surface owner active.")
]==]

local function projectPrompt(source)
	if countPlain(source, PROMPT_MARKER) == 1 then return source end
	if not string.find(source, "NTR_RACING_STAGING_READINESS_GATE_V1", 1, true) then
		fail("TimeTrialService is not the confirmed readiness-gated source.")
	end
	source = replaceOnce(source,
		"\t\tprompt.KeyboardKeyCode = Enum.KeyCode.E\n\t\tprompt.HoldDuration = 0",
		"\t\tprompt.KeyboardKeyCode = Enum.KeyCode.E\n\t\tprompt.GamepadKeyCode = Enum.KeyCode.ButtonX\n\t\tprompt.ClickablePrompt = true\n\t\tprompt.Style = Enum.ProximityPromptStyle.Default\n\t\tprompt.HoldDuration = 0",
		"native prompt input")
	source = replaceOnce(source,
		"\tprompt.ActionText = \"Open Race Menu\"\n\tprompt.ObjectText = mode == \"Race\" and \"Race\" or \"Time Trial\"",
		"\tprompt.KeyboardKeyCode = Enum.KeyCode.E\n\tprompt.GamepadKeyCode = Enum.KeyCode.ButtonX\n\tprompt.ClickablePrompt = true\n\tprompt.Style = Enum.ProximityPromptStyle.Default\n\tprompt.ActionText = tostring(zone:GetAttribute(\"PromptActionText\") or \"Open Race Menu\")\n\tprompt.ObjectText = mode == \"Race\" and \"Race\" or \"Time Trial\"",
		"native prompt presentation")
	return "-- " .. PROMPT_MARKER .. "\n" .. source
end

local function projectGuide(source)
	if countPlain(source, GUIDE_MARKER) == 1 then return source end
	if not string.find(source, "NTR_RACING_FLOW_COUNTDOWN_GUIDE_GATE_V2", 1, true)
		or not string.find(source, "NTR_SHARED_RESPONSIVE_UI_FOUNDATION_V1_1", 1, true) then
		fail("RaceRouteGuide is not the confirmed countdown-gated shared-foundation source.")
	end
	source = insertBeforeOnce(source,
		"local function drawGateFrame(gate)",
		[[
local function finishGateText(run)
	local lapTarget = math.max(0, math.floor(tonumber(run and run.LapTarget) or 1))
	local currentLap = math.max(1, math.floor(tonumber(run and run.CurrentLap) or 1))
	if lapTarget == 1 then return "FINISH LINE" end
	if lapTarget > 1 and currentLap >= lapTarget then return "FINAL LAP" end
	return "LAP " .. tostring(currentLap)
end

]],
		"finish-gate wording helper")
	source = replaceOnce(source,
		"\tlocal label = gate.IsFinish and \"FINISH\" or (\"CHECKPOINT \" .. tostring(gate.Index or activeRun.NextGateIndex or \"?\"))",
		"\tlocal label = gate.IsFinish and finishGateText(activeRun) or (\"CHECKPOINT \" .. tostring(gate.Index or activeRun.NextGateIndex or \"?\"))",
		"finish-gate wording")
	source = replaceOnce(source,
		"\tif not boolAttr(\"ShowDynamicNextArrow\", true) then return end",
		"\tif not boolAttr(\"ShowCheckpointArrows\", false) or not boolAttr(\"ShowDynamicNextArrow\", true) then return end",
		"dynamic arrow master gate")
	source = replaceOnce(source,
		"\tif not boolAttr(\"ShowAuthoringArrows\", true) then return end",
		"\tif not boolAttr(\"ShowCheckpointArrows\", false) or not boolAttr(\"ShowAuthoringArrows\", true) then return end",
		"authored arrow master gate")
	source = replaceOnce(source,
		[[
local function setActive(payload)
	activeRun = activeRun or {}
	activeRun.RunId = payload.RunId or activeRun.RunId
	activeRun.EventId = payload.EventId or activeRun.EventId
	activeRun.RouteId = payload.RouteId or activeRun.RouteId
	activeRun.DisplayName = payload.DisplayName or activeRun.DisplayName
	activeRun.NextGateIndex = payload.NextGateIndex or activeRun.NextGateIndex or 1
	activeRun.GateCount = payload.GateCount or activeRun.GateCount or 1
	renderGuide()
end]],
		[[
local function setActive(payload)
	activeRun = activeRun or {}
	local previousLap = activeRun.CurrentLap
	local previousTarget = activeRun.LapTarget
	activeRun.RunId = payload.RunId or activeRun.RunId
	activeRun.EventId = payload.EventId or activeRun.EventId
	activeRun.RouteId = payload.RouteId or activeRun.RouteId
	activeRun.DisplayName = payload.DisplayName or activeRun.DisplayName
	activeRun.NextGateIndex = payload.NextGateIndex or activeRun.NextGateIndex or 1
	activeRun.GateCount = payload.GateCount or activeRun.GateCount or 1
	activeRun.CurrentLap = payload.NextLap or payload.CurrentLap or activeRun.CurrentLap or 1
	activeRun.LapTarget = payload.LapTarget ~= nil and payload.LapTarget or activeRun.LapTarget or 1
	if activeRun.CurrentLap ~= previousLap or activeRun.LapTarget ~= previousTarget then
		renderedGateIndex = nil
	end
	renderGuide()
end]],
		"trusted lap-state consumption")
	source = replaceOnce(source,
		"\telseif kind == \"TimeTrialCheckpoint\" or kind == \"RaceCheckpoint\" then\n\t\tsetActive(payload)",
		"\telseif kind == \"TimeTrialCheckpoint\" or kind == \"RaceCheckpoint\" or kind == \"TimeTrialLapCompleted\" or kind == \"RaceLapCompleted\" then\n\t\tsetActive(payload)",
		"lap-completed presentation event")
	return "-- " .. GUIDE_MARKER .. "\n" .. source
end

local function projectGuideV1_2(source)
	if countPlain(source, GUIDE_V1_2_MARKER) == 1 then return source end
	if countPlain(source, GUIDE_MARKER) ~= 1 then
		fail("RaceRouteGuide must contain exactly one V1 guide marker before the V1.2 mobile checkpoint UI repair.")
	end
	source = insertBeforeOnce(source,
		"local function clientRoot()",
		[[
local function checkpointUiScale()
	if not Foundation.IsMobile() then return 1 end
	return math.clamp(numberAttr("MobileCheckpointUIScale",0.6),0.25,1)
end

]],
		"mobile checkpoint UI scale helper")
	source = replaceOnce(source,
		[[
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = boolAttr("CheckpointWorldTextAlwaysOnTop", true)
	gui.Size = UDim2.fromOffset(numberAttr("CheckpointPillWidth", 168), numberAttr("CheckpointPillHeight", 28))
	local yOffset = numberAttr("CheckpointPillYOffset", 7)]],
		[[
	local uiScale = checkpointUiScale()
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = adornee
	gui.AlwaysOnTop = boolAttr("CheckpointWorldTextAlwaysOnTop", true)
	gui.Size = UDim2.fromOffset(numberAttr("CheckpointPillWidth", 168) * uiScale, numberAttr("CheckpointPillHeight", 28) * uiScale)
	local yOffset = numberAttr("CheckpointPillYOffset", 7)]],
		"checkpoint pill geometry scale")
	source = replaceOnce(source,
		"\tlabel.TextSize = numberAttr(\"CheckpointWorldTextSize\", 15)",
		"\tlabel.TextSize = math.max(8, numberAttr(\"CheckpointWorldTextSize\", 15) * uiScale)",
		"checkpoint pill text scale")
	source = replaceOnce(source,
		"\tFoundation.Corner(label,numberAttr(\"CheckpointPillCornerRadius\",8))",
		"\tFoundation.Corner(label,numberAttr(\"CheckpointPillCornerRadius\",8) * uiScale)",
		"checkpoint pill corner scale")
	source = replaceOnce(source,
		"\tstroke.Thickness = numberAttr(\"CheckpointPillStrokeThickness\", 1)",
		"\tstroke.Thickness = numberAttr(\"CheckpointPillStrokeThickness\", 1) * uiScale",
		"checkpoint pill stroke scale")
	return "-- " .. GUIDE_V1_2_MARKER .. "\n" .. source
end

local function projectSharedSessionV1_3(source)
	if countPlain(source, HUD_V1_3_MARKER) == 1 then return source end
	if not string.find(source, "NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD", 1, true)
		or not string.find(source, "NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP", 1, true) then
		fail("RaceSessionPresentationController is not the confirmed shared HUD/reset/exit owner.")
	end
	source = replaceOnce(source,
		"local gui=Instance.new(\"ScreenGui\") gui.Name=\"NTR_SharedInRaceHUD\" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=155 gui.Parent=playerGui",
		"local gui=Instance.new(\"ScreenGui\") gui.Name=\"NTR_SharedInRaceHUD\" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=155 gui.ZIndexBehavior=Enum.ZIndexBehavior.Global pcall(function() gui.ScreenInsets=Enum.ScreenInsets.None end) pcall(function() gui.ClipToDeviceSafeArea=false end) gui.Parent=playerGui",
		"full-screen HUD inset contract")
	source = replaceOnce(source,
		"local modalShade=Instance.new(\"Frame\") modalShade.Name=\"ExitConfirmationShade\" modalShade.BackgroundColor3=Color3.new(0,0,0) modalShade.BackgroundTransparency=.34 modalShade.BorderSizePixel=0 modalShade.Size=UDim2.fromScale(1,1) modalShade.Visible=false modalShade.ZIndex=100 modalShade.Parent=canvas",
		[[
local modalBackdrop=Instance.new("Frame") modalBackdrop.Name="ExitConfirmationFullScreenBackdrop" modalBackdrop.Active=true modalBackdrop.BackgroundColor3=Color3.new(0,0,0) modalBackdrop.BackgroundTransparency=.34 modalBackdrop.BorderSizePixel=0 modalBackdrop.Position=UDim2.fromScale(0,0) modalBackdrop.Size=UDim2.fromScale(1,1) modalBackdrop.Visible=false modalBackdrop.ZIndex=90 modalBackdrop.Parent=gui
local modalShade=Instance.new("Frame") modalShade.Name="ExitConfirmationShade" modalShade.BackgroundTransparency=1 modalShade.BorderSizePixel=0 modalShade.Size=UDim2.fromScale(1,1) modalShade.Visible=false modalShade.ZIndex=100 modalShade.Parent=canvas]],
		"full-screen exit backdrop")
	source = insertBeforeOnce(source,
		"local busy=false",
		[[
local function setExitModalVisible(visible)
	visible=visible==true
	modalBackdrop.Visible=visible
	modalShade.Visible=visible
end
]],
		"atomic exit modal visibility")
	source = replaceOnce(source,
		"if busy or not active then return end busy=true modalShade.Visible=false transition(\"FadeOut\"",
		"if busy or not active then return end busy=true setExitModalVisible(false) transition(\"FadeOut\"",
		"exit invoke backdrop cleanup")
	source = replaceOnce(source,
		"exitButton.Activated:Connect(function() if not active then return end modalTitle.Text=active.Mode==\"Race\" and \"EXIT RACE?\" or \"EXIT TIME TRIAL?\" modalShade.Visible=true end)",
		"exitButton.Activated:Connect(function() if not active then return end modalTitle.Text=active.Mode==\"Race\" and \"EXIT RACE?\" or \"EXIT TIME TRIAL?\" setExitModalVisible(true) end)",
		"exit backdrop open")
	source = replaceOnce(source,
		"noButton.Activated:Connect(function() modalShade.Visible=false end)",
		"noButton.Activated:Connect(function() setExitModalVisible(false) end)",
		"exit backdrop cancel")
	source = replaceOnce(source,
		"local function hide(_restoreLegacy) active=nil clearHudMapState() canvas.Visible=false modalShade.Visible=false busy=false suppress(false) presentationMode(false) clear(boardBody) end",
		"local function hide(_restoreLegacy) active=nil clearHudMapState() canvas.Visible=false setExitModalVisible(false) busy=false suppress(false) presentationMode(false) clear(boardBody) end",
		"session hide backdrop cleanup")
	return "-- " .. HUD_V1_3_MARKER .. "\n" .. source
end

local function projectSharedSessionV1_4(source)
	if countPlain(source, HUD_V1_4_MARKER) == 1 then return source end
	if countPlain(source, HUD_V1_3_MARKER) ~= 1 then
		fail("RaceSessionPresentationController must contain exactly one confirmed V1.3 full-screen EXIT marker before the V1.4 canvas repair.")
	end
	source = replaceOnce(source,
		"local ReplicatedStorage=game:GetService(\"ReplicatedStorage\")\nlocal RunService=game:GetService(\"RunService\")",
		"local ReplicatedStorage=game:GetService(\"ReplicatedStorage\")\nlocal GuiService=game:GetService(\"GuiService\")\nlocal RunService=game:GetService(\"RunService\")",
		"adaptive canvas GuiService owner")
	source = replaceOnce(source,
		[[local canvas=Instance.new("Frame") canvas.Name="ReferenceCanvas" canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Visible=false canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local function updateScale() local camera=Workspace.CurrentCamera local v=camera and camera.ViewportSize or Vector2.new(1920,1080) scale.Scale=math.min(v.X/1920,v.Y/1080) end updateScale() if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end]],
		[[local canvas=Instance.new("Frame") canvas.Name="ReferenceCanvas" canvas.AnchorPoint=Vector2.new(.5,.5) canvas.Position=UDim2.fromScale(.5,.5) canvas.Size=UDim2.fromOffset(1920,1080) canvas.BackgroundTransparency=1 canvas.Visible=false canvas.Parent=gui
local scale=Instance.new("UIScale") scale.Parent=canvas
local REFERENCE_VIEWPORT=Vector2.new(1920,1080)
local cameraViewportConnection=nil
local function safeViewportRect(viewport)
	local origin=Vector2.zero local size=viewport
	local ok,fullRect,deviceRect=pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.None),GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	end)
	if ok and fullRect and deviceRect then
		origin=deviceRect.Min-fullRect.Min
		size=deviceRect.Max-deviceRect.Min
	end
	origin=Vector2.new(math.clamp(origin.X,0,math.max(0,viewport.X-1)),math.clamp(origin.Y,0,math.max(0,viewport.Y-1)))
	size=Vector2.new(math.clamp(size.X,1,math.max(1,viewport.X-origin.X)),math.clamp(size.Y,1,math.max(1,viewport.Y-origin.Y)))
	return origin,size
end
local function updateScale()
	local camera=Workspace.CurrentCamera
	local viewport=camera and camera.ViewportSize or gui.AbsoluteSize
	if viewport.X<1 or viewport.Y<1 then viewport=REFERENCE_VIEWPORT end
	local origin,safeSize=safeViewportRect(viewport)
	local uniformScale=math.max(.01,math.min(safeSize.X/REFERENCE_VIEWPORT.X,safeSize.Y/REFERENCE_VIEWPORT.Y))
	scale.Scale=uniformScale
	canvas.Position=UDim2.fromOffset(origin.X+safeSize.X*.5,origin.Y+safeSize.Y*.5)
	canvas.Size=UDim2.fromOffset(safeSize.X/uniformScale,safeSize.Y/uniformScale)
end
local function bindCameraViewport()
	if cameraViewportConnection then cameraViewportConnection:Disconnect() cameraViewportConnection=nil end
	local camera=Workspace.CurrentCamera
	if camera then cameraViewportConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	updateScale()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraViewport)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
bindCameraViewport()]],
		"adaptive device-safe reference canvas")
	source = replaceOnce(source,
		"\tcontrols.Position=UDim2.fromOffset(MN(\"SessionControlsCenterX\",760),1080-MN(\"SessionControlsBottomOffset\",24))",
		"\tcontrols.Position=UDim2.new(0,MN(\"SessionControlsCenterX\",760),1,-MN(\"SessionControlsBottomOffset\",24))",
		"touch controls safe-bottom anchor")
	return "-- " .. HUD_V1_4_MARKER .. "\n" .. source
end

local function projectSessionAssets(source)
	if countPlain(source, ASSETS_MARKER) == 1 then return source end
	if not string.find(source, "NTR_RACING_UI_PHASE16F_STREAMING_SAFE_ARROWS", 1, true)
		or not string.find(source, "NTR_RACING_PHASE11L_ARROW_VISUAL_PROXY_SYNC_V2_TRANSPARENCY_RESTORE", 1, true) then
		fail("RaceSessionAssets is not the confirmed streaming-safe arrow proxy source.")
	end
	source = replaceOnce(source,
		"local performanceConfig=racingConfig:WaitForChild(\"PresentationPerformance\")",
		"local performanceConfig=racingConfig:WaitForChild(\"PresentationPerformance\")\nlocal routeGuideConfig=racingConfig:WaitForChild(\"RouteGuide\")\nlocal function checkpointArrowsEnabled() return routeGuideConfig:GetAttribute(\"ShowCheckpointArrows\")==true end",
		"arrow configuration bridge")
	source = replaceOnce(source,
		"local function applyPart(record,visible)\n\tlocal item=record.Part",
		"local function applyPart(record,visible)\n\tvisible=visible and checkpointArrowsEnabled()\n\tlocal item=record.Part",
		"segment visibility master gate")
	source = replaceOnce(source,
		"local function apply(force)\n\tlocal runId,state=bestLocalRun()",
		"local function apply(force)\n\tif not checkpointArrowsEnabled() then\n\t\tclearVisible()\n\t\thideAllOnce()\n\t\tactiveSignature=\"ARROWS_DISABLED\"\n\t\treturn\n\tend\n\tlocal runId,state=bestLocalRun()",
		"runtime arrow disable gate")
	source = replaceOnce(source,
		"\t\tif next(localRuns)~=nil and os.clock()-lastApplyClock>=interval then lastApplyClock=os.clock() apply(false) end",
		"\t\tif checkpointArrowsEnabled() and next(localRuns)~=nil and os.clock()-lastApplyClock>=interval then lastApplyClock=os.clock() apply(false) end",
		"disabled arrow polling gate")
	source = insertBeforeOnce(source,
		"task.defer(hideAllOnce)",
		[[
local function belongsToAuthoredArrowRoot(item)
	local current=item and item.Parent
	while current and current~=Workspace do
		if current.Name=="ArrowMarkers" and current.Parent and current.Parent.Parent and current.Parent.Parent.Name=="RaceRoutes" then
			return true
		end
		current=current.Parent
	end
	return false
end

Workspace.DescendantAdded:Connect(function(item)
	if checkpointArrowsEnabled() or not item:IsA("BasePart") then return end
	task.defer(function()
		if item.Parent and belongsToAuthoredArrowRoot(item) then
			item.LocalTransparencyModifier=1
			item.CanCollide=false item.CanTouch=false item.CanQuery=false
		end
	end)
end)

routeGuideConfig:GetAttributeChangedSignal("ShowCheckpointArrows"):Connect(function()
	activeSignature=nil
	if checkpointArrowsEnabled() then apply(true) else hideAllOnce() clearVisible() end
end)

]],
		"streaming-safe dormant arrow enforcement")
	return "-- " .. ASSETS_MARKER .. "\n" .. source
end

local function projectSessionAssetsV1_1(source)
	if countPlain(source, ASSETS_V1_1_MARKER) == 1 then return source end
	if countPlain(source, ASSETS_MARKER) ~= 1 then
		fail("RaceSessionAssets must contain exactly one V1 arrow marker before the V1.1 route-arrow repair.")
	end
	source = replaceOnce(source,
		"local function checkpointArrowsEnabled() return routeGuideConfig:GetAttribute(\"ShowCheckpointArrows\")==true end",
		"local function routeArrowMarkersEnabled() return routeGuideConfig:GetAttribute(\"ShowRouteArrowMarkers\")~=false end",
		"route-arrow configuration split")
	source = replaceOnce(source,
		"\tvisible=visible and checkpointArrowsEnabled()",
		"\tvisible=visible and routeArrowMarkersEnabled()",
		"segment route-arrow gate")
	source = replaceOnce(source,
		"\tif not checkpointArrowsEnabled() then\n\t\tclearVisible()\n\t\thideAllOnce()\n\t\tactiveSignature=\"ARROWS_DISABLED\"\n\t\treturn\n\tend",
		"\tif not routeArrowMarkersEnabled() then\n\t\tclearVisible()\n\t\thideAllOnce()\n\t\tactiveSignature=\"ROUTE_ARROWS_DISABLED\"\n\t\treturn\n\tend",
		"runtime route-arrow gate")
	source = replaceOnce(source,
		"\t\tif checkpointArrowsEnabled() and next(localRuns)~=nil and os.clock()-lastApplyClock>=interval then lastApplyClock=os.clock() apply(false) end",
		"\t\tif routeArrowMarkersEnabled() and next(localRuns)~=nil and os.clock()-lastApplyClock>=interval then lastApplyClock=os.clock() apply(false) end",
		"active route-arrow polling")
	source = replaceOnce(source,
		"\tif checkpointArrowsEnabled() or not item:IsA(\"BasePart\") then return end",
		"\tif routeArrowMarkersEnabled() or not item:IsA(\"BasePart\") then return end",
		"streamed route-arrow fallback")
	source = replaceOnce(source,
		"routeGuideConfig:GetAttributeChangedSignal(\"ShowCheckpointArrows\"):Connect(function()\n\tactiveSignature=nil\n\tif checkpointArrowsEnabled() then apply(true) else hideAllOnce() clearVisible() end\nend)",
		"routeGuideConfig:GetAttributeChangedSignal(\"ShowRouteArrowMarkers\"):Connect(function()\n\tactiveSignature=nil\n\tif routeArrowMarkersEnabled() then apply(true) else hideAllOnce() clearVisible() end\nend)",
		"route-arrow config listener")
	return "-- " .. ASSETS_V1_1_MARKER .. "\n" .. source
end

local function assertBaseline()
	if raceClient.Disabled ~= true then fail("RaceClient_Active must remain retired.") end
	local installedRevision = kit:GetAttribute("RacingPresentationLifecycleRevision")
	if installedRevision ~= nil and installedRevision ~= V1_REVISION and installedRevision ~= V1_1_REVISION and installedRevision ~= V1_2_REVISION and installedRevision ~= PREVIOUS_REVISION and installedRevision ~= REVISION then
		fail("Unexpected installed racing presentation lifecycle revision: " .. tostring(installedRevision))
	end
	if installedRevision ~= PREVIOUS_REVISION and installedRevision ~= REVISION then
		if not personalBestBoard then fail("RacePersonalBestBoardClient_Active is missing before its guarded V1.3 retirement.") end
		if not string.find(personalBestBoard.Source, "NTR_RACING_PHASE11O_TIME_TRIAL_PB_BOARD_V2_MENU_CLOSE_SYNC", 1, true) then
			fail("RacePersonalBestBoardClient_Active is not the confirmed superseded Phase 11O V2 source.")
		end
	end
	for _,item in ipairs({routeGuide, sessionAssets, sharedSession, transition, entry, entryPresentation, results, queue, countdown}) do
		if item.Disabled then fail(item.Name .. " is an intended active owner but is disabled.") end
	end
	if not string.find(entry.Source, "Headless race-entry state/action bridge", 1, true) then
		fail("RaceEntryMenuClient is not the confirmed Phase 16E headless bridge.")
	end
	if not string.find(sharedSession.Source, "NTR_SharedInRaceHUD", 1, true)
		or not string.find(sharedSession.Source, "ResetActiveTimeTrial", 1, true)
		or not string.find(sharedSession.Source, "ExitRaceToStart", 1, true) then
		fail("Shared race HUD/reset/exit owner contract is incomplete.")
	end
	if not string.find(matchmaking.Source, "NTR_RACING_STAGING_READINESS_GATE_V1", 1, true) then
		fail("RaceMatchmakingService is not the confirmed readiness-gated source.")
	end
	if not loadingState:GetAttribute("ControllerReady") and MODE == "AUDIT" then
		log("LoadingPresentationState ControllerReady is false in Edit mode; runtime controller readiness must be verified in Play.")
	end
end

local function authoredArrowCount()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local routes = world and world:FindFirstChild("RaceRoutes")
	local roots = 0
	local parts = 0
	for _,route in ipairs(routes and routes:GetChildren() or {}) do
		local arrowRoot = route:FindFirstChild("ArrowMarkers")
		if arrowRoot then
			roots += 1
			for _,item in ipairs(arrowRoot:GetDescendants()) do
				if item:IsA("BasePart") then parts += 1 end
			end
		end
	end
	return roots, parts
end

local function audit()
	assertBaseline()
	local failures = {}
	local function expect(condition, message)
		if not condition then table.insert(failures, message) end
	end
	local controller = racing:FindFirstChild(CONTROLLER_NAME)
	expect(routeGuideConfig:GetAttribute("ShowCheckpointArrows") == false, "ShowCheckpointArrows must be false")
	expect(routeGuideConfig:GetAttribute("ShowRouteArrowMarkers") == true, "ShowRouteArrowMarkers must be true")
	expect(routeGuideConfig:GetAttribute("ArrowMarkersDormant") == false, "ArrowMarkersDormant must be false")
	expect(routeGuideConfig:GetAttribute("CheckpointGuideArrowsDisabled") == true, "CheckpointGuideArrowsDisabled must be true")
	expect(routeGuideConfig:GetAttribute("MobileCheckpointUIScale") == 0.6, "MobileCheckpointUIScale must be 0.6")
	expect(routeGuideConfig:GetAttribute("PresentationLifecycleRevision") == REVISION, "route-guide revision missing")
	expect(kit:GetAttribute("RacingPresentationLifecycleRevision") == REVISION, "kit revision missing")
	expect(countPlain(timeTrial.Source, PROMPT_MARKER) == 1, "native prompt marker missing/duplicated")
	expect(countPlain(routeGuide.Source, GUIDE_MARKER) == 1, "route-guide marker missing/duplicated")
	expect(countPlain(routeGuide.Source, GUIDE_V1_2_MARKER) == 1, "route-guide V1.2 marker missing/duplicated")
	expect(countPlain(sharedSession.Source, HUD_V1_3_MARKER) == 1, "shared HUD V1.3 marker missing/duplicated")
	expect(countPlain(sharedSession.Source, HUD_V1_4_MARKER) == 1, "shared HUD V1.4 marker missing/duplicated")
	expect(countPlain(sessionAssets.Source, ASSETS_MARKER) == 1, "session-assets marker missing/duplicated")
	expect(countPlain(sessionAssets.Source, ASSETS_V1_1_MARKER) == 1, "session-assets V1.1 marker missing/duplicated")
	expect(timeTrial.Source:find("Enum.KeyCode.E", 1, true) ~= nil, "keyboard E prompt contract missing")
	expect(timeTrial.Source:find("Enum.KeyCode.ButtonX", 1, true) ~= nil, "controller prompt contract missing")
	expect(timeTrial.Source:find("prompt.ClickablePrompt = true", 1, true) ~= nil, "touch prompt contract missing")
	expect(routeGuide.Source:find("FINISH LINE", 1, true) ~= nil and routeGuide.Source:find("FINAL LAP", 1, true) ~= nil, "lap gate wording missing")
	expect(routeGuide.Source:find("ShowCheckpointArrows", 1, true) ~= nil, "route-guide arrow master gate missing")
	expect(routeGuide.Source:find("Foundation.IsMobile()", 1, true) ~= nil, "shared mobile classification missing from checkpoint UI")
	expect(routeGuide.Source:find("MobileCheckpointUIScale", 1, true) ~= nil, "mobile checkpoint UI scale missing")
	expect(sharedSession.Source:find("ExitConfirmationFullScreenBackdrop", 1, true) ~= nil, "full-screen exit backdrop missing")
	expect(sharedSession.Source:find("gui.ScreenInsets=Enum.ScreenInsets.None", 1, true) ~= nil, "full-screen inset contract missing")
	expect(sharedSession.Source:find("gui.ClipToDeviceSafeArea=false", 1, true) ~= nil, "device safe-area clipping override missing")
	expect(sharedSession.Source:find("setExitModalVisible", 1, true) ~= nil, "atomic exit modal visibility missing")
	expect(sharedSession.Source:find("GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)", 1, true) ~= nil, "device-safe HUD canvas missing")
	expect(sharedSession.Source:find("canvas.Size=UDim2.fromOffset(safeSize.X/uniformScale,safeSize.Y/uniformScale)", 1, true) ~= nil, "aspect-adaptive HUD canvas sizing missing")
	expect(sharedSession.Source:find("Workspace:GetPropertyChangedSignal(\"CurrentCamera\")", 1, true) ~= nil, "camera replacement geometry rebind missing")
	expect(sharedSession.Source:find("controls.Position=UDim2.new(0,MN(\"SessionControlsCenterX\",760),1,-MN(\"SessionControlsBottomOffset\",24))", 1, true) ~= nil, "touch controls safe-bottom anchor missing")
	expect(sessionAssets.Source:find("ShowRouteArrowMarkers", 1, true) ~= nil, "route-arrow marker gate missing")
	expect(sessionAssets.Source:find("checkpointArrowsEnabled", 1, true) == nil, "route arrows still consume the checkpoint-arrow gate")
	expect(oldControls.Disabled == true and oldCleanup.Disabled == true and raceClient.Disabled == true, "superseded racing clients are not all retired")
	expect(racing:FindFirstChild("RacePersonalBestBoardClient_Active") == nil, "superseded standalone PB board owner still exists")
	expect(controller and controller:IsA("LocalScript") and controller.Disabled == false, "lifecycle presentation controller missing/disabled")
	expect(controller and countPlain(controller.Source, CONTROLLER_MARKER) == 1, "lifecycle presentation controller V1.3 marker missing/duplicated")
	if controller then
		for _,name in ipairs(LEGACY_GUI_NAMES) do
			expect(controller.Source:find(name, 1, true) ~= nil, "legacy cleanup name missing: " .. name)
		end
		expect(controller.Source:find("Workspace.DescendantAdded", 1, true) ~= nil, "streaming-safe aura discovery missing")
		expect(controller.Source:find("stateGeneration", 1, true) ~= nil, "generation-safe aura state missing")
		expect(controller.Source:find("NTR_RaceEntryPrompt", 1, true) ~= nil, "local prompt eligibility owner missing")
		expect(controller.Source:find('mode=="Race" or mode=="TimeTrial"', 1, true) ~= nil, "TimeTrial start-zone eligibility missing")
		expect(controller.Source:find("item.Enabled=visible", 1, true) ~= nil, "eligible aura does not explicitly enable effects")
		expect(controller.Source:find("GetPropertyChangedSignal(\"Enabled\")", 1, true) ~= nil, "prompt reassertion listener missing")
	end
	local roots, parts = authoredArrowCount()
	expect(roots > 0 and parts > 0, "authored ArrowMarkers route data is missing")
	for _,pair in ipairs({
		{timeTrial, "TimeTrialService"},
		{routeGuide, "RaceRouteGuide"},
		{sessionAssets, "RaceSessionAssets"},
		{sharedSession, "RaceSessionPresentationController"},
		{controller, "RaceLifecyclePresentationController"},
	}) do
		if pair[1] then
			local ok, problem = pcall(compile, pair[1].Source, pair[2] .. " committed")
			expect(ok, pair[2] .. " compile failed: " .. tostring(problem))
		end
	end
	if #failures > 0 then fail("AUDIT FAIL | " .. table.concat(failures, " | ")) end
	log("AUDIT PASS | shared HUD=aspect-adaptive device-safe edges | 16:9 reference sizing=preserved | exit backdrop=full physical screen | entry owner=new presentation only | standalone PB board=removed | native prompt=all start zones+session hidden | checkpoint UI=PC 100%/mobile 60% | route ArrowMarkers=on and preserved=" .. tostring(parts) .. " parts/" .. tostring(roots) .. " roots | legacy owners retired")
	return true
end

assertBaseline()

if MODE == "AUDIT" then
	audit()
	return
end

if MODE ~= "INSTALL" then fail("MODE must be INSTALL or AUDIT.") end

local alreadyInstalled = kit:GetAttribute("RacingPresentationLifecycleRevision") == REVISION
	and countPlain(timeTrial.Source, PROMPT_MARKER) == 1
	and countPlain(routeGuide.Source, GUIDE_MARKER) == 1
	and countPlain(routeGuide.Source, GUIDE_V1_2_MARKER) == 1
	and countPlain(sharedSession.Source, HUD_V1_3_MARKER) == 1
	and countPlain(sharedSession.Source, HUD_V1_4_MARKER) == 1
	and countPlain(sessionAssets.Source, ASSETS_MARKER) == 1
	and countPlain(sessionAssets.Source, ASSETS_V1_1_MARKER) == 1
	and racing:FindFirstChild(CONTROLLER_NAME)
	and countPlain(racing[CONTROLLER_NAME].Source, CONTROLLER_MARKER) == 1
	and racing:FindFirstChild("RacePersonalBestBoardClient_Active") == nil

if alreadyInstalled then
	audit()
	log("INSTALL PASS (already installed; no mutation)")
	return
end

-- Project and compile every source before the first mutation.
local projectedPrompt = projectPrompt(timeTrial.Source)
local projectedGuide = projectGuideV1_2(projectGuide(routeGuide.Source))
local projectedAssets = projectSessionAssetsV1_1(projectSessionAssets(sessionAssets.Source))
local projectedSharedSession = projectSharedSessionV1_4(projectSharedSessionV1_3(sharedSession.Source))
compile(projectedPrompt, "TimeTrialService projected")
compile(projectedGuide, "RaceRouteGuide projected")
compile(projectedAssets, "RaceSessionAssets projected")
compile(projectedSharedSession, "RaceSessionPresentationController projected")
compile(CONTROLLER_SOURCE, CONTROLLER_NAME .. " projected")

local rootsBefore, arrowPartsBefore = authoredArrowCount()
if rootsBefore == 0 or arrowPartsBefore == 0 then
	fail("Preflight found no authored ArrowMarkers parts. Stop and inspect the live route hierarchy.")
end

local controllerBefore = racing:FindFirstChild(CONTROLLER_NAME)
if controllerBefore and not controllerBefore:IsA("LocalScript") then
	fail(CONTROLLER_NAME .. " exists but is not a LocalScript.")
end

local snapshot = {
	TimeTrialSource = timeTrial.Source,
	RouteGuideSource = routeGuide.Source,
	SessionAssetsSource = sessionAssets.Source,
	SharedSessionSource = sharedSession.Source,
	OldControlsDisabled = oldControls.Disabled,
	OldCleanupDisabled = oldCleanup.Disabled,
	RaceClientDisabled = raceClient.Disabled,
	ShowCheckpointArrows = routeGuideConfig:GetAttribute("ShowCheckpointArrows"),
	ShowRouteArrowMarkers = routeGuideConfig:GetAttribute("ShowRouteArrowMarkers"),
	ArrowMarkersDormant = routeGuideConfig:GetAttribute("ArrowMarkersDormant"),
	CheckpointGuideArrowsDisabled = routeGuideConfig:GetAttribute("CheckpointGuideArrowsDisabled"),
	MobileCheckpointUIScale = routeGuideConfig:GetAttribute("MobileCheckpointUIScale"),
	RouteRevision = routeGuideConfig:GetAttribute("PresentationLifecycleRevision"),
	KitRevision = kit:GetAttribute("RacingPresentationLifecycleRevision"),
	OldControlsRetiredBy = oldControls:GetAttribute("NTRRetiredBy"),
	OldCleanupRetiredBy = oldCleanup:GetAttribute("NTRRetiredBy"),
	RaceClientRetiredBy = raceClient:GetAttribute("NTRRetiredBy"),
	ControllerExisted = controllerBefore ~= nil,
	ControllerSource = controllerBefore and controllerBefore.Source,
	ControllerDisabled = controllerBefore and controllerBefore.Disabled,
	ControllerOwnerContract = controllerBefore and controllerBefore:GetAttribute("OwnerContract"),
	ControllerRevision = controllerBefore and controllerBefore:GetAttribute("InstallerRevision"),
	PersonalBestBoardExisted = personalBestBoard ~= nil,
	PersonalBestBoardSource = personalBestBoard and personalBestBoard.Source,
	PersonalBestBoardDisabled = personalBestBoard and personalBestBoard.Disabled,
	PersonalBestBoardAttributes = personalBestBoard and personalBestBoard:GetAttributes() or {},
}

ChangeHistoryService:SetWaypoint(PHASE .. " Before Install")
local createdController = nil
local ok, problem = pcall(function()
	if timeTrial.Source ~= projectedPrompt then timeTrial.Source = projectedPrompt end
	if routeGuide.Source ~= projectedGuide then routeGuide.Source = projectedGuide end
	if sessionAssets.Source ~= projectedAssets then sessionAssets.Source = projectedAssets end
	if sharedSession.Source ~= projectedSharedSession then sharedSession.Source = projectedSharedSession end

	local controller = controllerBefore
	if not controller then
		controller = Instance.new("LocalScript")
		controller.Name = CONTROLLER_NAME
		controller.Parent = racing
		createdController = controller
	end
	controller.Source = CONTROLLER_SOURCE
	controller.Disabled = false
	controller:SetAttribute("OwnerContract", "Local Race/TimeTrial start-zone aura/prompt eligibility and exact legacy racing ScreenGui cleanup")
	controller:SetAttribute("InstallerRevision", REVISION)

	oldControls.Disabled = true
	oldControls:SetAttribute("NTRRetiredBy", REVISION)
	oldCleanup.Disabled = true
	oldCleanup:SetAttribute("NTRRetiredBy", REVISION)
	raceClient.Disabled = true
	raceClient:SetAttribute("NTRRetiredBy", "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP")
	if personalBestBoard then personalBestBoard:Destroy() end

	routeGuideConfig:SetAttribute("ShowCheckpointArrows", false)
	routeGuideConfig:SetAttribute("ShowRouteArrowMarkers", true)
	routeGuideConfig:SetAttribute("ArrowMarkersDormant", false)
	routeGuideConfig:SetAttribute("CheckpointGuideArrowsDisabled", true)
	routeGuideConfig:SetAttribute("MobileCheckpointUIScale", 0.6)
	routeGuideConfig:SetAttribute("PresentationLifecycleRevision", REVISION)
	kit:SetAttribute("RacingPresentationLifecycleRevision", REVISION)

	local rootsAfter, arrowPartsAfter = authoredArrowCount()
	if rootsAfter ~= rootsBefore or arrowPartsAfter ~= arrowPartsBefore then
		fail("Authored ArrowMarkers changed during install; automatic rollback required.")
	end
	audit()
end)

if not ok then
	timeTrial.Source = snapshot.TimeTrialSource
	routeGuide.Source = snapshot.RouteGuideSource
	sessionAssets.Source = snapshot.SessionAssetsSource
	sharedSession.Source = snapshot.SharedSessionSource
	oldControls.Disabled = snapshot.OldControlsDisabled
	oldCleanup.Disabled = snapshot.OldCleanupDisabled
	raceClient.Disabled = snapshot.RaceClientDisabled
	oldControls:SetAttribute("NTRRetiredBy", snapshot.OldControlsRetiredBy)
	oldCleanup:SetAttribute("NTRRetiredBy", snapshot.OldCleanupRetiredBy)
	raceClient:SetAttribute("NTRRetiredBy", snapshot.RaceClientRetiredBy)
	routeGuideConfig:SetAttribute("ShowCheckpointArrows", snapshot.ShowCheckpointArrows)
	routeGuideConfig:SetAttribute("ShowRouteArrowMarkers", snapshot.ShowRouteArrowMarkers)
	routeGuideConfig:SetAttribute("ArrowMarkersDormant", snapshot.ArrowMarkersDormant)
	routeGuideConfig:SetAttribute("CheckpointGuideArrowsDisabled", snapshot.CheckpointGuideArrowsDisabled)
	routeGuideConfig:SetAttribute("MobileCheckpointUIScale", snapshot.MobileCheckpointUIScale)
	routeGuideConfig:SetAttribute("PresentationLifecycleRevision", snapshot.RouteRevision)
	kit:SetAttribute("RacingPresentationLifecycleRevision", snapshot.KitRevision)
	if createdController then
		createdController:Destroy()
	elseif controllerBefore then
		controllerBefore.Source = snapshot.ControllerSource
		controllerBefore.Disabled = snapshot.ControllerDisabled
		controllerBefore:SetAttribute("OwnerContract", snapshot.ControllerOwnerContract)
		controllerBefore:SetAttribute("InstallerRevision", snapshot.ControllerRevision)
	end
	if snapshot.PersonalBestBoardExisted and not racing:FindFirstChild("RacePersonalBestBoardClient_Active") then
		local restored = Instance.new("LocalScript")
		restored.Name = "RacePersonalBestBoardClient_Active"
		restored.Source = snapshot.PersonalBestBoardSource
		restored.Disabled = snapshot.PersonalBestBoardDisabled
		for name,value in pairs(snapshot.PersonalBestBoardAttributes) do restored:SetAttribute(name,value) end
		restored.Parent = racing
	end
	ChangeHistoryService:SetWaypoint(PHASE .. " Automatic Rollback")
	fail("INSTALL ROLLED BACK | " .. tostring(problem))
end

ChangeHistoryService:SetWaypoint(PHASE .. " Installed")
log("INSTALL PASS | restart Play, run the full verification matrix, then rerun this same script with MODE=\"AUDIT\".")
