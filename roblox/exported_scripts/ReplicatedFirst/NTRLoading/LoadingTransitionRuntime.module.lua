-- NTR_LOADING_SYSTEM_PHASE1_TRANSITION_RUNTIME_V1_2
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local packageFolder = ReplicatedFirst:WaitForChild("NTRLoading")
local Catalog = require(packageFolder:WaitForChild("LoadingArtworkCatalog"))
local View = require(packageFolder:WaitForChild("LoadingScreenView"))

local Runtime = {}
local singleton = nil

local function waitRenderedFrames(count)
	for _ = 1, count do RunService.RenderStepped:Wait() end
end

local function smoothstep(value)
	local alpha = math.clamp(tonumber(value) or 0, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function automaticProgress(elapsed, minimum)
	local firstStage = math.max(0.05, minimum * 0.8)
	if elapsed <= firstStage then
		return 0.02 + (0.85 - 0.02) * smoothstep(elapsed / firstStage)
	end
	if elapsed <= minimum then
		return 0.85 + (0.94 - 0.85) * smoothstep((elapsed - firstStage) / math.max(0.05, minimum - firstStage))
	end
	return 0.94 + 0.04 * (1 - math.exp(-(elapsed - minimum) * 0.22))
end

function Runtime.Start(options)
	if singleton then return singleton end
	options = options or {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")
	local colours = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud"):WaitForChild("Colours")
	local inputGate = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Input"):WaitForChild("GameplayInputGate"))
	local audioMixer = require(kit.Shared.Modules.Client:WaitForChild("Audio"):WaitForChild("AudioMixController"))
	local uiFolder = options.UIFolder or error("UIFolder required")
	local presentationEvent = uiFolder:WaitForChild("FreeRoamHudPresentationMode")
	local presentationState = uiFolder:WaitForChild("LoadingPresentationState")
	local presentationChanged = uiFolder:WaitForChild("LoadingPresentationChanged")
	local view = View.Create(playerGui, config, colours)
	local api = {}
	local generation = 0
	local current = nil
	local previousArtworkId = nil

	audioMixer.Start(config)
	view:Warm(Catalog.List(config, "Default"), tonumber(config:GetAttribute("WarmPoolSize")) or 2)

	local function publish(active, fadeStarted, destination, reason)
		presentationState:SetAttribute("Active", active == true)
		presentationState:SetAttribute("Generation", current and current.Generation or generation)
		presentationState:SetAttribute("Destination", tostring(destination or (current and current.Destination) or ""))
		presentationState:SetAttribute("FadeStarted", fadeStarted == true)
		presentationState:SetAttribute("Reason", tostring(reason or ""))
		presentationChanged:Fire({ Active = active == true, FadeStarted = fadeStarted == true, Generation = current and current.Generation or generation, Destination = destination or (current and current.Destination), Reason = reason })
	end

	local function suppress(active)
		presentationEvent:Fire({ Owner = "LoadingTransition", Active = active == true, KeepTelemetry = false })
	end

	local function releaseCurrent(requireNeutral)
		if not current then return end
		local token = current.InputToken
		current = nil
		if token then inputGate.Release(token, requireNeutral ~= false) end
	end

	local function begin(payload)
		payload = type(payload) == "table" and payload or {}
		if current then return current.Generation end
		generation += 1
		local destination = tostring(payload.Destination or "Default")
		local artwork = Catalog.Choose(config, destination, previousArtworkId)
		previousArtworkId = artwork.ArtworkId
		current = {
			Generation = generation,
			Destination = destination,
			StartedAt = os.clock(),
			InputToken = inputGate.Acquire("LoadingTransition", generation),
			DisplayProgress = 0.02,
			ReportedProgress = 0.02,
			Completing = false,
		}
		view:SetArtwork(artwork)
		view:Show(payload.Status or "LOADING")
		view:SetProgressImmediate(0.02)
		view:StartMotion(config:GetAttribute("MotionEnabled") ~= false and payload.StartScreen ~= true)
		suppress(true)
		publish(true, false, destination, "Begin")
		audioMixer.Begin(generation)

		local thisGeneration = generation
		task.spawn(function()
			local lastStep = os.clock()
			while current and current.Generation == thisGeneration do
				RunService.RenderStepped:Wait()
				if not current or current.Generation ~= thisGeneration then return end
				if not current.Completing then
					local now = os.clock()
					local elapsed = now - current.StartedAt
					local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
					local target = math.max(automaticProgress(elapsed, minimum), math.min(0.98, current.ReportedProgress or 0))
					local delta = math.max(0, now - lastStep)
					local reportedBlend = math.min(1, delta * 5)
					local smoothedTarget = current.DisplayProgress + (target - current.DisplayProgress) * reportedBlend
					current.DisplayProgress = math.max(current.DisplayProgress, automaticProgress(elapsed, minimum), smoothedTarget)
					view:SetProgressImmediate(current.DisplayProgress)
					lastStep = now
				end
			end
		end)
		task.delay(math.max(1, tonumber(config:GetAttribute("TimeoutSeconds")) or 12), function()
			if current and current.Generation == thisGeneration then
				api:Handle("Fail", { Generation = thisGeneration, Status = "TRANSITION TIMED OUT", Reason = "Timeout" })
			end
		end)
		return generation
	end

	local function finish(payload, success)
		payload = type(payload) == "table" and payload or {}
		if not current or tonumber(payload.Generation) ~= current.Generation then return false, "StaleGeneration" end
		local finishing = current
		audioMixer.MarkReady(finishing.Generation)
		local readyHold = math.max(0, tonumber(config:GetAttribute("ReadyHoldSeconds")) or 0.06)
		local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
		local completionFill = math.max(0.05, tonumber(config:GetAttribute("CompletionFillSeconds")) or 0.2)
		local remaining = math.max(0, minimum - completionFill - (os.clock() - finishing.StartedAt))
		if remaining > 0 then task.wait(remaining) end
		if not current or current.Generation ~= finishing.Generation then return false, "Superseded" end
		finishing.Completing = true
		view:SetStatus(payload.Status or (success and "READY" or "RETURNING"))
		view:SetProgress(1, completionFill)
		task.wait(completionFill + readyHold)
		if not current or current.Generation ~= finishing.Generation then return false, "Superseded" end
		publish(true, true, finishing.Destination, success and "Ready" or tostring(payload.Reason or "Failed"))
		suppress(false)
		local fade = math.max(0.03, tonumber(config:GetAttribute("FadeOutSeconds")) or 0.3)
		audioMixer.Finish(finishing.Generation, fade)
		waitRenderedFrames(2)
		view:FadeOut(fade)
		view:Hide()
		publish(false, false, finishing.Destination, success and "Complete" or tostring(payload.Reason or "Failed"))
		releaseCurrent(true)
		return true
	end

	function api:Handle(action, payload)
		action = tostring(action or "")
		if action == "Begin" then return begin(payload)
		elseif action == "Progress" then
			if not current or tonumber(payload and payload.Generation) ~= current.Generation then return false end
			current.ReportedProgress = math.max(current.ReportedProgress, math.clamp(tonumber(payload.Progress) or 0, 0, 0.98))
			if payload.Status then view:SetStatus(payload.Status) end
			return true
		elseif action == "Complete" then return finish(payload, true)
		elseif action == "Fail" or action == "Cancel" then return finish(payload, false)
		elseif action == "GetState" then
			return { Active = current ~= nil, Generation = current and current.Generation or generation, Destination = current and current.Destination or "", InputLocked = inputGate.IsLocked(), AudioActive = audioMixer.IsActive() }
		end
		return false, "UnknownAction"
	end

	singleton = api
	return api
end

return Runtime
