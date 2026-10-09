-- Owns the Roblox core UI policy under Pulse: player list, health and backpack off, chat hidden while a full-screen Pulse surface is open, engine GUI auto-selection off, chat window colours; not the top bar, the Esc menu, name tags, prompts or anything in Classic (this module is never required in Classic).
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Shell.CoreUiPolicy. Requires: Layers, Presence, Tokens, Text, Core.ConnectionScope (all resolved inside start).
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local SURFACE = "CoreUi"

-- Presence kinds that hide chat: every kind except "Race" (API2 2.4 rule 4, 3.9, 5.3). Chat stays in races.
local BLOCKING_KINDS = table.freeze({ "FullMenu", "Garage", "Results", "Map", "Modal", "SidePanel", "Loading" })
-- Core elements that are off for the whole session (PC 7.1).
local OFF = table.freeze({ "PlayerList", "Health", "Backpack" })

local Policy = {}
local state

-- Pure: is a surface open that hides chat?
function Policy._blocking(presence)
	for _, kind in ipairs(BLOCKING_KINDS) do
		if presence.Any(kind) then
			return true
		end
	end
	return false
end

-- Pure: chat shows only if it was on when the policy started and nothing blocking is open.
function Policy._chatWanted(baseline, blocking)
	return baseline == true and not blocking
end

-- The policy over injected services, so the tests run it with fakes. deps = { Presence, SetCore(name, enabled),
-- GetCore(name) -> boolean, SetAutoSelect(enabled), Warn(text) }. Every engine call is protected: a refusal is
-- reported once and never fails start.
function Policy._new(deps)
	local warned = {}
	local function try(label, callback, ...)
		local ok, result = pcall(callback, ...)
		if not ok and not warned[label] then
			warned[label] = true
			deps.Warn("[Pulse.CoreUiPolicy] " .. label .. " failed: " .. tostring(result))
		end
		return ok, result
	end

	local policy = { ChatBaseline = true, ChatShown = nil, Blocking = false }

	function policy.AssertOff()
		for _, name in ipairs(OFF) do
			try("SetCoreGuiEnabled " .. name, deps.SetCore, name, false)
		end
	end

	-- Writes the chat state only when the wanted value changes.
	function policy.ApplyChat()
		local blocking = Policy._blocking(deps.Presence)
		policy.Blocking = blocking
		local wanted = Policy._chatWanted(policy.ChatBaseline, blocking)
		if wanted ~= policy.ChatShown then
			local ok = try("SetCoreGuiEnabled Chat", deps.SetCore, "Chat", wanted)
			if ok then
				policy.ChatShown = wanted
			end
		end
	end

	function policy.Start()
		policy.AssertOff()
		try("AutoSelectGuiEnabled", deps.SetAutoSelect, false)
		local ok, enabled = try("GetCoreGuiEnabled Chat", deps.GetCore, "Chat")
		policy.ChatBaseline = not ok or enabled == true
		policy.ChatShown = policy.ChatBaseline
		policy.ApplyChat()
	end

	-- A surface opened or closed. The three "off" elements are asserted again here because the Studio trailer tool
	-- turns all core UI back on when it exits and the engine's changed signal cannot be connected (Phase 0 spike 08):
	-- the next menu open or close repairs it. Nothing is polled.
	function policy.OnPresenceChanged()
		policy.AssertOff()
		policy.ApplyChat()
	end

	return policy
end

-- Chat window colours and face from the tokens (Phase 0 spike 08: the three properties are writable at run time).
local function restyleChat(Tokens, Text)
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if not window then
		return false
	end
	window.FontFace = Text.Font("Body")
	window.TextColor3 = Tokens.Colour.White
	window.BackgroundColor3 = Tokens.Colour.Slate
	return true
end

local function run()
	local pulse = script.Parent.Parent
	local kit = pulse.Kit
	local Layers = require(kit.Layers)
	Layers.Switch().Claim(SURFACE)

	local Presence = require(kit.Presence)
	local Tokens = require(kit.Tokens)
	local Text = require(kit.Text)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	local policy = Policy._new({
		Presence = Presence,
		SetCore = function(name, enabled)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], enabled)
		end,
		GetCore = function(name)
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType[name])
		end,
		SetAutoSelect = function(enabled)
			GuiService.AutoSelectGuiEnabled = enabled
		end,
		Warn = warn,
	})
	policy.Start()
	scope:connect(Presence.Changed, policy.OnPresenceChanged)

	local okStyle, styled = pcall(restyleChat, Tokens, Text)
	if not okStyle then
		warn("[Pulse.CoreUiPolicy] chat restyle failed: " .. tostring(styled))
	end
	policy.ChatStyled = okStyle and styled == true

	Policy.Controller = policy
end

function Policy.start()
	if state then
		assert(state == "ready", "Client startup already attempted: " .. tostring(state))
		return
	end
	state = "starting"
	local ok, message = xpcall(run, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return Policy
