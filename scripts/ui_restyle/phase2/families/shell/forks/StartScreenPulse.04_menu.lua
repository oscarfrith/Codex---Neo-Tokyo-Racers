local playDefaultText = tostring(config:GetAttribute("StartScreenPlayText") or "PLAY")
local shopDefaultText = tostring(config:GetAttribute("StartScreenShopText") or "SHOP")
-- Begin has run and StartScreenActive is true: a failure here must still let the player in. The build is protected;
-- when it fails the kept lines below run as they are (the handlers connect to signals that never fire) and the
-- end of Run() calls the kept release(), the path Play takes.
local scope, built, menu, play, shop = nil, nil, nil, nil, nil
local builtOk, buildProblem = pcall(function()
	scope = Kit.Scope.new()
	built = StartScreen._buildMenu(Kit, safeRoot, Kit.Metrics.Of(safeRoot), scope, { Play = playDefaultText, Shop = shopDefaultText })
	menu, play, shop = built.Menu, built.Play.Instance, built.Shop.Instance
	assert(typeof(menu) == "Instance" and typeof(play) == "Instance" and typeof(shop) == "Instance", "menu parts missing")
end)
if builtOk then
	claimWhenCommitted(SURFACE)
else
	warn("[Pulse.StartScreenPulse] Start menu could not be built; releasing to gameplay. " .. tostring(buildProblem))
	local leftover = safeRoot:FindFirstChild("StartScreenActions")
	menu = if typeof(menu) == "Instance" then menu else leftover
	local never = { Connect = function() end }
	play, shop = { Activated = never }, { Activated = never }
end
