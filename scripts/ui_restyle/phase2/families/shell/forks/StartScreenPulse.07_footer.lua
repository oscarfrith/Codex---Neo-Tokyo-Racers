if not builtOk then
	release(true, "MenuUnavailable")
	return
end
print("[StartScreenPulse] Pulse Play/Shop start screen ready.")
end)
if not ok and began then
	-- After Begin: a reported failure, as an error in the Classic script is. Never a second flow.
	error(problem, 0)
end
if not ok then
	warn("[Pulse.StartScreenPulse] Stopped before Begin; handing the start screen to Classic. " .. tostring(problem))
end
return began
end

return StartScreen
