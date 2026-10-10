-- Radio v2 (Oscar, 2026-10-10): values that changed on instances the first radio install created. The installer
-- engine reports these as tuned and does not rewrite them. Edit mode. Guarded: each value must be its before or
-- after value or nothing is written. MODE = "ROLLBACK" restores. Generated with scripts/ui_restyle/radio/spec.json.
local MODE = "APPLY"
local PLACE_ID = 103397770260610

local radio = game:GetService("ReplicatedStorage").Config.Audio.Radio
-- { instance, key, before, after, isProperty }
local OPS = {
	{ radio, "CrossfadeSeconds", nil, 4, false },
	{ radio, "FadeSeconds", nil, 1.5, false },
	{ radio, "ShowStrip", nil, false, false },
	{ radio, "StartScreenVolume", nil, 0.5, false },
	{ radio, "StartScreenFadeOutSeconds", nil, 2, false },
	{ radio.Tracks, "Shuffle", nil, true, false },
	{ radio.Tracks.Track01, "First", nil, false, false },
	{ radio.Tracks.Track02, "First", nil, false, false },
	{ radio.Tracks.Track02, "Gain", 1, 0.95, false },
	{ radio.Tracks.Track03, "First", nil, false, false },
	{ radio.Tracks.Track04, "First", nil, false, false },
	{ radio.Tracks.Track04, "Gain", 1, 1.1, false },
	{ radio.Tracks.Track05, "First", nil, false, false },
	{ radio.Tracks.Track05, "Gain", 1, 1.2, false },
	{ radio.Tracks.Track06, "First", nil, false, false },
	{ radio.Tracks.Track06, "Gain", 1, 1.3, false },
	{ radio.Tracks.Track07, "First", nil, false, false },
	{ radio.Tracks.Track07, "Gain", 1, 1.6, false },
	{ radio.Tracks.Track08, "First", nil, true, false },
	{ radio.Tracks.Track08, "Gain", 1, 1.15, false },
	{ radio.Tracks.Track03, "Value", "9044545921", "", true },
}

assert(game.PlaceId == PLACE_ID, "wrong place")
assert(not game:GetService("RunService"):IsRunning(), "stop Play first")
local function read(op)
	if op[5] then return op[1][op[2]] end
	return op[1]:GetAttribute(op[2])
end
local function same(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 1e-6 end
	return a == b
end
for _, op in ipairs(OPS) do
	local now = read(op)
	assert(same(now, op[3]) or same(now, op[4]), op[1]:GetFullName() .. " " .. op[2] .. " is " .. tostring(now) .. ", neither before nor after")
end
local wrote = 0
for _, op in ipairs(OPS) do
	local target = op[4]
	if MODE == "ROLLBACK" then target = op[3] end
	if not same(read(op), target) then
		if op[5] then op[1][op[2]] = target else op[1]:SetAttribute(op[2], target) end
		wrote += 1
	end
end
return MODE .. ": wrote " .. wrote .. " of " .. #OPS
