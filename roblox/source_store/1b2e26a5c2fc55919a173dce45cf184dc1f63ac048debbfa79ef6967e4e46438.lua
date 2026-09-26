-- Canonical feature implementation; startup is owned by the composition root.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
-- NTR Lighting Phase AQ - isolated six-stage server owner
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = game:GetService("ReplicatedStorage")
local presets = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LightingPresets"))
local skyPresets = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("World"):WaitForChild("Skies")
local config = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("World"):WaitForChild("Lighting")
local schedule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LightingSchedule"))

-- Continuous mode transfers only environment presentation; this server retains cycle state.
local requestedMode=config:GetAttribute("CycleMode") or "Stepped"
assert(requestedMode=="Stepped" or requestedMode=="Continuous","Invalid CycleMode")
Lighting:SetAttribute("LightingCycleMode",requestedMode)
if requestedMode=="Continuous" then
    local RunService=game:GetService("RunService")
    local HttpService=game:GetService("HttpService")
    local World=ReplicatedStorage.Modules.Game.World
    local Cycle=require(World.LightingCycle)
    local definition=require(World.LightingCycleDefinition)
    local sessionEpoch=workspace:GetServerTimeNow()
    local signature,cycle,settings
    local revision=0
    local alive=true
    local function put(name,value) if Lighting:GetAttribute(name)~=value then Lighting:SetAttribute(name,value) end end
    local function update()
        local base=config:GetAttribute("BaseDurationSeconds") or 90
        local latitude=config:GetAttribute("ContinuousGeographicLatitude") or 35
        local sunrise=config:GetAttribute("SunriseClockTime") or 6
        local sunset=config:GetAttribute("SunsetClockTime") or 18
        local manual=config:GetAttribute("ManualStage") or "Day"
        local auto=config:GetAttribute("AutoCycleEnabled")~=false
        local synchronized=config:GetAttribute("SynchronizeAcrossServers")~=false
        local key=table.concat({tostring(base),tostring(latitude),tostring(sunrise),tostring(sunset),tostring(manual),tostring(auto),tostring(synchronized)},"|")
        if key~=signature then
            assert(Cycle.finite(sunrise) and Cycle.finite(sunset) and sunrise>=0 and sunrise<sunset and sunset<24,"Invalid sunrise/sunset")
            local built=Cycle.build(presets,schedule,definition,base,latitude)
            assert(built.byName[manual],"Invalid ManualStage")
            revision+=1
            settings={Version=1,Revision=revision,Epoch=synchronized and 0 or sessionEpoch,BaseDurationSeconds=base,Latitude=latitude,Sunrise=sunrise,Sunset=sunset,Auto=auto,ManualStage=manual}
            cycle,signature=built,key
            put("LightingCycleState",HttpService:JSONEncode(settings))
        end
        local now=workspace:GetServerTimeNow()
        local seconds=settings.Auto and (now-settings.Epoch) or cycle.byName[settings.ManualStage].start
        local _,info=Cycle.sample(cycle,seconds)
        local night=Cycle.isNight(info.clock,settings.Sunrise,settings.Sunset)
        local frame=cycle.frames[info.index]
        local endsAt=settings.Auto and (settings.Epoch+math.floor(seconds/cycle.total)*cycle.total+frame.start+frame.duration) or 0
        put("LightingPreset",info.preset); put("LightingStageIndex",info.index)
        put("LightingStageEndsAtUnix",endsAt)
        put("StreetLightsOn",night); put("WindowMode",night and "Night" or "Day")
        put("StreetLightBrightness",config:GetAttribute("DefaultStreetLightBrightness") or 2)
    end
    update()
    local elapsed=0
    local lastError
    local connection
    connection=RunService.Heartbeat:Connect(function(dt)
        if not alive then return end
        elapsed+=dt; if elapsed<.25 then return end; elapsed=0
        local success,problem=xpcall(update,debug.traceback)
        if not success then
            put("LightingCycleError",tostring(problem))
            if problem~=lastError then warn("[LightingServer] "..tostring(problem)); lastError=problem end
        else lastError=nil; put("LightingCycleError",nil) end
    end)
    script.Destroying:Once(function() alive=false; connection:Disconnect() end)
    return
end
Lighting.GeographicLatitude=config:GetAttribute("SteppedGeographicLatitude") or Lighting.GeographicLatitude

local function getOrCreateEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then existing:Destroy() end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

local effects = {
	Atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere"),
	ColorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection"),
	Bloom = getOrCreateEffect("BloomEffect", "Bloom"),
	SunRays = getOrCreateEffect("SunRaysEffect", "SunRays"),
	DepthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField"),
}

local function applyProperties(instance, properties)
	for propertyName, value in pairs(properties or {}) do
		if instance == Lighting and propertyName == "Fogcolor" then propertyName = "FogColor" end
		local ok, err = pcall(function() instance[propertyName] = value end)
		if not ok then warn("[Lighting AQ] Could not apply", instance.Name, propertyName, err) end
	end
end

local function applySky(name)
	if not name then return end
	local template = skyPresets:FindFirstChild(name)
	if not template or not template:IsA("Sky") then
		warn("[Lighting AQ] Missing Sky preset:", name)
		return
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then child:Destroy() end
	end
	local clone = template:Clone()
	clone.Name = "ActiveSky"
	clone.Parent = Lighting
end

local currentPreset
local function applyStage(stage, index, endsAtUnix)
	local preset = presets[stage.Preset]
	if not preset then
		warn("[Lighting AQ] Missing preset:", stage.Preset)
		return
	end
	if currentPreset ~= stage.Preset then
		applyProperties(Lighting, preset.Lighting)
		for section, effect in pairs(effects) do applyProperties(effect, preset[section]) end
		applySky(preset.SkyName)
		currentPreset = stage.Preset
		print("[Lighting AQ] Applied stage:", stage.DisplayName or stage.Preset)
	end
	Lighting:SetAttribute("LightingPreset", stage.Preset)
	Lighting:SetAttribute("StreetLightsOn", stage.StreetLightsOn == true)
	Lighting:SetAttribute("WindowMode", stage.WindowMode or "Day")
	Lighting:SetAttribute("LightingStageIndex", index)
	Lighting:SetAttribute("LightingStageEndsAtUnix", endsAtUnix or 0)
end

local localCycleStartedAt = os.clock()
local function stageFromCycle()
	local base = math.max(1, tonumber(config:GetAttribute("BaseDurationSeconds")) or 300)
	local total = 0
	for _, stage in ipairs(schedule) do total += base * math.max(0.01, tonumber(stage.DurationWeight) or 1) end
	local synchronized = config:GetAttribute("SynchronizeAcrossServers") ~= false
	local now = synchronized and os.time() or (os.clock() - localCycleStartedAt)
	local position = now % total
	local cursor = 0
	for index, stage in ipairs(schedule) do
		local duration = base * math.max(0.01, tonumber(stage.DurationWeight) or 1)
		if position < cursor + duration then
			local remaining = cursor + duration - position
			return stage, index, synchronized and (os.time() + math.ceil(remaining)) or 0
		end
		cursor += duration
	end
	return schedule[1], 1, 0
end

local function manualStage()
	local wanted = tostring(config:GetAttribute("ManualStage") or "Day")
	for index, stage in ipairs(schedule) do
		if stage.Preset == wanted then return stage, index end
	end
	warn("[Lighting AQ] Invalid ManualStage; using Day:", wanted)
	return schedule[1], 1
end

task.spawn(function()
while true do
	local stage, index, endsAt
	if config:GetAttribute("AutoCycleEnabled") == false then
		stage, index = manualStage()
		endsAt = 0
	else
		stage, index, endsAt = stageFromCycle()
	end
	applyStage(stage, index, endsAt)
	task.wait(1)
end
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
