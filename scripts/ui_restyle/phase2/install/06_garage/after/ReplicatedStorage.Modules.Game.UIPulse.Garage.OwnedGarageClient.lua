-- Owns the start of the Pulse owned-garage client: the OwnedGarage claim, the four parts in the Classic order, and Runtime.UI@OwnedGarageClientStarted; not what any part does.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageClient. Requires: Kit.Layers, Garage.OwnedGarageBrowserUI, Garage.OwnedGarageWorkspaceUI, Garage.GarageInteriorHud, Garage.GarageInteriorTransitionUI.
-- Replaces Classic UI.OwnedGarageClient (entry OwnedGarageClient; dependency LoadingTransitionUI unchanged).
local Players = game:GetService("Players")

local SURFACE = "OwnedGarage"
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

-- The order, for the pure test.
Client._order = ORDER

return Client
