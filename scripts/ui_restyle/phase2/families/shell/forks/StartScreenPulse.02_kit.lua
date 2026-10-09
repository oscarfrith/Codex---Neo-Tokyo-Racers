local Kit, kitProblem = StartScreen._kit()
if not Kit then
	warn("[Pulse.StartScreenPulse] Kit not available (" .. tostring(kitProblem) .. "); handing the start screen to Classic.")
	return
end
