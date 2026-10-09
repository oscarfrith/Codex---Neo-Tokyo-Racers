-- Owns the start of the Pulse owned-garage client: the OwnedGarage claim, the four parts in the Classic order, and Runtime.UI@OwnedGarageClientStarted; not what any part does.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageClient. Requires: Kit.Layers, Garage.OwnedGarageBrowserUI, Garage.OwnedGarageWorkspaceUI, Garage.GarageInteriorHud, Garage.GarageInteriorTransitionUI, Garage.OwnedGarageDeskView (LastFailure only).
-- It also runs the desk watch: a listen-only check that warns "[Pulse.OwnedGarageClient] <reason>" when the desk prompt was triggered and the desk is not open a second later.
-- Replaces Classic UI.OwnedGarageClient (entry OwnedGarageClient; dependency LoadingTransitionUI unchanged).
local Players = game:GetService("Players")

local SURFACE = "OwnedGarage"
local WATCH_SECONDS = 1
-- Classic line 8, with the interior HUD in the place of GarageInteriorModeUI (it starts Garage.TouchCameraGuard).
local ORDER = { "OwnedGarageBrowserUI", "OwnedGarageWorkspaceUI", "GarageInteriorHud", "GarageInteriorTransitionUI" }

local Client = {}
local state

local function run()
	local garage = script.Parent
	-- 1. Claim before anything is required or created.
	require(garage.Parent.Kit.Layers).Switch().Claim(SURFACE)

	-- 2. Classic line 9: each part's Start() must return ok.
	for _, name in ipairs(ORDER) do
		local controller = require(garage:WaitForChild(name))
		local ok, message = controller.Start()
		assert(ok, "Owned garage client failed: " .. name .. " / " .. tostring(message))
	end

	-- 2b. The desk watch. It only listens and warns: no attribute, bindable or remote call, and it cannot fail the
	-- start. One second after the desk prompt is triggered or OpenManagement arrives, a desk that is not open is
	-- reported with the reason (Client._deskVerdict).
	local watchOk, watchProblem = pcall(function()
		local player = Players.LocalPlayer
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		local garageRemotes = remotes and remotes:FindFirstChild("Garage")
		local push = garageRemotes and garageRemotes:FindFirstChild("OwnedGarageEvent")
		local desk = require(garage.OwnedGarageWorkspaceUI)
		local view = require(garage.OwnedGarageDeskView)
		local pushedAt, checking = nil, false
		local function check()
			if checking then return end
			checking = true
			local startedAt = os.clock()
			task.delay(WATCH_SECONDS, function()
				checking = false
				local pushed = pushedAt ~= nil and pushedAt >= startedAt - WATCH_SECONDS
				local open = playerGui ~= nil and playerGui:GetAttribute("OwnedGarageManagementOpen") == true
				-- A failure counts only when it belongs to this press (the fork's listener may run before this one).
				local recent = view.LastFailureAt ~= nil and view.LastFailureAt >= startedAt - WATCH_SECONDS
				local verdict = Client._deskVerdict(pushed, open, desk.IsOpen() == true, recent and view.LastFailure or nil)
				if verdict then warn("[Pulse.OwnedGarageClient] " .. verdict) end
			end)
		end
		if push and push:IsA("RemoteEvent") then
			push.OnClientEvent:Connect(function(message)
				if type(message) == "table" and message.Type == "OpenManagement" and not desk.IsOpen() then
					pushedAt = os.clock()
					check()
				end
			end)
		else
			warn("[Pulse.OwnedGarageClient] Remotes.Garage.OwnedGarageEvent was not found; the desk cannot be opened by its prompt")
		end
		game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
			if prompt.Name == "ManageGaragePrompt" and who == player and not desk.IsOpen() then
				check()
			end
		end)
	end)
	if not watchOk then
		warn("[Pulse.OwnedGarageClient] the desk watch did not start: " .. tostring(watchProblem))
	end

	-- 3. Classic line 10: set only after every part started.
	Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):SetAttribute("OwnedGarageClientStarted", true)
end

function Client.start()
	if state then
		assert(state == "ready", "Client startup already attempted: " .. tostring(state))
		return
	end
	state = "starting"
	local ok, message = xpcall(run, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

-- Pure. Why the desk is not open after the desk prompt was pressed, or nil when it is open. `pushed` is whether the
-- server's OpenManagement arrived; `open` is PlayerGui@OwnedGarageManagementOpen; `shown` is the fork's IsOpen().
function Client._deskVerdict(pushed, open, shown, lastFailure)
	if open and shown then
		return nil
	end
	if not pushed then
		return "ManageGaragePrompt was triggered but the server sent no OpenManagement (prompt not bound to this session, or the server still has ManagementOpen set)"
	end
	if lastFailure ~= nil then
		return "OpenManagement arrived and the desk view failed: " .. tostring(lastFailure)
	end
	if open ~= shown then
		return "OpenManagement arrived but the desk is half open (OwnedGarageManagementOpen=" .. tostring(open) .. ", shown=" .. tostring(shown) .. ")"
	end
	return "OpenManagement arrived and the desk was closed again with no view failure (the fork's close ran: GetManagementState said not in a garage, or a transition or presentation owner closed it)"
end

-- The order, for the pure test.
Client._order = ORDER

return Client
