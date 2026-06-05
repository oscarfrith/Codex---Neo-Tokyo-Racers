-- Neo Tokyo Racers garage API client boundary.
-- Phase A module. Wraps GarageInvoke response handling without changing response shape.

local GarageApiClient = {}
GarageApiClient.__index = GarageApiClient

function GarageApiClient.new(remoteFunction, state)
	return setmetatable({
		Remote = remoteFunction,
		State = state,
		LastError = nil,
	}, GarageApiClient)
end

function GarageApiClient:Call(action, args)
	if not self.Remote then
		self.LastError = "Garage remote missing."
		return { Success = false, Message = self.LastError }
	end

	local ok, result = pcall(function()
		return self.Remote:InvokeServer(action, args or {})
	end)

	if ok and typeof(result) == "table" then
		if result.Profile and self.State then
			self.State.Profile = result.Profile
		end
		self.LastError = nil
		return result
	end

	self.LastError = ok and "Garage server returned an invalid response." or tostring(result)
	return { Success = false, Message = "Garage server did not respond." }
end

return GarageApiClient
