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
