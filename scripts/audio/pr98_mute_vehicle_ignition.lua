-- PR98 (Oscar, 2026-10-10): mute the vehicle start-up (ignition) one-shot. Edit mode, config attributes only.
-- IgnitionGain 0 keeps the cue playing silently, so the start sequence that waits for it is unchanged.
-- Guarded: each value must be its before or after value, or nothing is written. MODE = "ROLLBACK" restores.
local MODE = "APPLY"
local PLACE_ID = 103397770260610
local BEFORE, AFTER = 0.85, 0

assert(game.PlaceId == PLACE_ID, "wrong place")
assert(not game:GetService("RunService"):IsRunning(), "stop Play first")
local profiles = game:GetService("ReplicatedStorage").Config.Audio.VehicleProfiles
local function same(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
local targets = {}
for _, profile in ipairs(profiles:GetChildren()) do
	local now = profile:GetAttribute("IgnitionGain")
	if now ~= nil then
		assert(same(now, BEFORE) or same(now, AFTER), profile.Name .. " IgnitionGain is " .. tostring(now) .. ", neither before nor after")
		table.insert(targets, profile)
	end
end
local out = {}
for _, profile in ipairs(targets) do
	local now = profile:GetAttribute("IgnitionGain")
	local target = MODE == "ROLLBACK" and BEFORE or AFTER
	if not same(now, target) then profile:SetAttribute("IgnitionGain", target) end
	table.insert(out, profile.Name .. " " .. tostring(now) .. " -> " .. tostring(profile:GetAttribute("IgnitionGain")))
end
return MODE .. " (" .. #profiles:GetChildren() .. " profiles): " .. table.concat(out, "; ")
