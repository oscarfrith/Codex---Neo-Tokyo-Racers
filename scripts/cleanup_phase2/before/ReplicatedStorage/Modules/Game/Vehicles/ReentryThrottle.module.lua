-- Phase 4 canonical helper. Legacy paths forward to this instance.
local script = game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Controllers"):WaitForChild("ReentryThrottle")
local ReentryThrottle = {}
local Probe = {}
Probe.__index = Probe

function ReentryThrottle.new(intervalSeconds)
	return setmetatable({
		Interval = intervalSeconds or 0.15,
		NextCheck = 0,
	}, Probe)
end

function Probe:ShouldRun(now)
	now = now or os.clock()
	if now < self.NextCheck then return false end
	self.NextCheck = now + self.Interval
	return true
end

function Probe:Cooldown(seconds)
	self.NextCheck = os.clock() + (seconds or self.Interval)
end

return ReentryThrottle
