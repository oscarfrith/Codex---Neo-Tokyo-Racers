-- PR98 mix change (Oscar, 2026-10-10): vehicle sound 1.5x, radio 0.7x. Edit mode, config attributes only.
-- Guarded: each value must be its before or after value, or nothing is written. MODE = "ROLLBACK" restores.
local MODE = "APPLY"
local PLACE_ID = 103397770260610

local audio = game:GetService("ReplicatedStorage").Config.Audio
local OPS = {
	{ audio.Global, "LocalDriverGain", 0.7, 1.05 },
	{ audio.Global, "ExternalVehicleGain", 0.6, 0.9 },
	{ audio.Radio, "Volume", 0.5, 0.35 },
}

assert(game.PlaceId == PLACE_ID, "wrong place")
assert(not game:GetService("RunService"):IsRunning(), "stop Play first")
local function same(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
for _, op in ipairs(OPS) do
	local now = op[1]:GetAttribute(op[2])
	assert(same(now, op[3]) or same(now, op[4]), op[2] .. " is " .. tostring(now) .. ", neither before nor after")
end
local out = {}
for _, op in ipairs(OPS) do
	local target = MODE == "ROLLBACK" and op[3] or op[4]
	local now = op[1]:GetAttribute(op[2])
	if not same(now, target) then op[1]:SetAttribute(op[2], target) end
	table.insert(out, op[2] .. " " .. tostring(now) .. " -> " .. tostring(op[1]:GetAttribute(op[2])))
end
return MODE .. ": " .. table.concat(out, "; ")
