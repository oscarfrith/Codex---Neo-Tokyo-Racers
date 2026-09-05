-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools
if not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,[====[
TrailerModeEnabled]====]) then return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("TrailerMode.client.lua")
-- StarterPlayer > StarterPlayerScripts > TrailerMode.client.lua
-- Press H to toggle trailer mode.
-- Hides Roblox CoreGui + your own ScreenGuis.
-- Press H again to restore UI.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TRAILER_KEY = Enum.KeyCode.H

local trailerMode = false
local savedGuiStates = {}

local coreGuiTypes = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.EmotesMenu,
}

local function setCoreGuiEnabled(enabled)
	for _, coreGuiType in ipairs(coreGuiTypes) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
		end)
	end
end

local function setPlayerGuiEnabled(enabled)
	if not enabled then
		savedGuiStates = {}

		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") then
				savedGuiStates[child] = child.Enabled
				child.Enabled = false
			end
		end
	else
		for gui, wasEnabled in pairs(savedGuiStates) do
			if gui and gui.Parent then
				gui.Enabled = wasEnabled
			end
		end

		savedGuiStates = {}
	end
end

local function setTrailerMode(enabled)
	trailerMode = enabled

	setCoreGuiEnabled(not enabled)
	setPlayerGuiEnabled(not enabled)

	print(enabled and "Trailer Mode ON - UI hidden" or "Trailer Mode OFF - UI restored")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == TRAILER_KEY then
		setTrailerMode(not trailerMode)
	end
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
