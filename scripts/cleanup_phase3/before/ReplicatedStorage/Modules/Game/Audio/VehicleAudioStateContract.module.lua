-- NTR_AUDIO_STATE_CONTRACT_V2_CUES
local Contract = {}

Contract.Version = 1
Contract.States = {
	Ignition = { Off = true, Starting = true, Running = true },
	Drive = { Idle = true, Accelerating = true, Braking = true, Reversing = true },
	Drift = { None = true, Left = true, Right = true },
	Boost = { Off = true, Normal = true, MiniBoost = true },
}

Contract.Cues = { AccelerationEnter = true, AccelerationRelease = true, BoostEmpty = true, FullBoostSpent = true }

Contract.Defaults = {
	Ignition = "Off",
	Drive = "Idle",
	Drift = "None",
	Boost = "Off",
}

function Contract.Validate(payload)
	if typeof(payload) ~= "table" then return false, "PayloadType" end
	local result = {}
	for field, allowed in pairs(Contract.States) do
		local value = tostring(payload[field] or "")
		if not allowed[value] then return false, "Invalid" .. field end
		result[field] = value
	end
	local revision = tonumber(payload.Revision)
	if not revision or revision < 1 or revision % 1 ~= 0 then return false, "InvalidRevision" end
	result.Revision = revision
	local cue = tostring(payload.Cue or "")
	if cue ~= "" and not Contract.Cues[cue] then return false, "InvalidCue" end
	result.Cue = cue
	return true, result
end

return Contract
