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
