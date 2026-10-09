-- The kit lays the menu out and follows the screen by itself. The one thing release() has to end is the kit scope,
-- which it does through the loop it already runs over layoutConnections. Protected: release() must reach its
-- StartScreenActive write and its Complete call whatever the scope does.
local layoutConnections = { { Disconnect = function()
	if scope then
		local destroyed, destroyProblem = pcall(scope.destroy, scope)
		if not destroyed then warn("[Pulse.StartScreenPulse] " .. tostring(destroyProblem)) end
	end
end } }
