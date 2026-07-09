-- Neo Tokyo Racers - Racing Phase 11I Idle Engine VFX Flush
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- Builds on Phase 11H by making the isolated racing visibility client flush
-- hidden ParticleEmitter/Trail remnants every frame. This targets the remaining
-- idle engine VFX leak where EngineIdle/EngineOff particles can stay visible
-- briefly even after Enabled=false.

local PHASE = "NTR Racing Phase 11I"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function child(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
	end
	return item
end

local function findScript(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if current == game then
			local ok, service = pcall(function()
				return game:GetService(token)
			end)
			current = ok and service or current:FindFirstChild(token)
		else
			current = child(current, token)
		end
	end
	if not current:IsA("LocalScript") then
		fail(path .. " is " .. current.ClassName .. ", expected LocalScript")
	end
	return current
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	local second = string.find(source, needle, endIndex + 1, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local visibilityClient = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceParticipantVisibilityClient_Active")
local source = visibilityClient.Source

if string.find(source, "NTR_RACING_PHASE11I_IDLE_VFX_FLUSH", 1, true) then
	info("RaceParticipantVisibilityClient already has Phase 11I idle VFX flush.")
	return
end

source = replaceOnce(source, [==[local function isToggleable(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end
]==], [==[local function isToggleable(instance)
	return instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
end

local function flushLingeringVfx(instance)
	-- NTR_RACING_PHASE11I_IDLE_VFX_FLUSH
	if instance:IsA("ParticleEmitter") or instance:IsA("Trail") then
		pcall(function()
			instance:Clear()
		end)
	end
end

local function forceRuntimeVfxHostHidden(instance, hidden)
	if not hidden then return end
	if instance:IsA("BasePart") and instance:GetAttribute("NTR_VFXRuntimeHost") == true then
		instance.LocalTransparencyModifier = 1
		instance.Transparency = 1
	end
end
]==], "add idle vfx flush helpers")

source = replaceOnce(source, [==[	if instance:IsA("BasePart") then
		remember(instance, "LocalTransparencyModifier", instance.LocalTransparencyModifier)
		instance.LocalTransparencyModifier = hidden and 1 or originalValue(instance, "LocalTransparencyModifier", 0)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
]==], [==[	if instance:IsA("BasePart") then
		remember(instance, "LocalTransparencyModifier", instance.LocalTransparencyModifier)
		instance.LocalTransparencyModifier = hidden and 1 or originalValue(instance, "LocalTransparencyModifier", 0)
		forceRuntimeVfxHostHidden(instance, hidden)
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
]==], "force runtime vfx host parts hidden")

source = replaceOnce(source, [==[	elseif isToggleable(instance) then
		-- Do not restore VFX/light Enabled here. The real VFX owner should decide
		-- when visible again; this gate only forces hidden session effects off.
		if hidden then
			instance.Enabled = false
		end
	else
]==], [==[	elseif isToggleable(instance) then
		-- Do not restore VFX/light Enabled here. The real VFX owner should decide
		-- when visible again; this gate only forces hidden session effects off.
		if hidden then
			instance.Enabled = false
			flushLingeringVfx(instance)
		end
	else
]==], "flush hidden toggleable vfx")

visibilityClient.Source = source
visibilityClient.Disabled = false

info("Installed Phase 11I idle engine VFX flush into RaceParticipantVisibilityClient_Active.")
info("Restart Play and verify hidden race/time-trial vehicles no longer show idle engine flames.")
