-- Pure tests for the shared minimap rotation helpers (no game module require, no instances).
local source = game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/minimap_rotation/FreeRoamMapPlayerMarkers.lua")
local Module = assert(loadstring(source))()
local results, failures = {}, 0
local function check(name, ok)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name)
end
local function near(a, b) return math.abs(a - b) < 1e-4 end
local function config(attrs) return { GetAttribute = function(_, key) return attrs[key] end } end
local function player(mode) return { GetAttribute = function(_, key) return key == "MinimapMode" and mode or nil end } end

-- ResolveRotation
local r = Module.ResolveRotation(config({}), player(nil))
check("defaults Camera/Orbit/10/16", r.Mode == "Camera" and r.NorthMode == "Orbit" and r.Response == 10 and r.NorthInset == 16)
check("invalid mode falls back to Camera", Module.ResolveRotation(config({ MapRotationMode = "Spin" }), nil).Mode == "Camera")
check("player NORTH UP wins", Module.ResolveRotation(config({ MapRotationMode = "Subject" }), player("NORTH UP")).Mode == "NorthUp")
check("player ROTATE keeps Subject", Module.ResolveRotation(config({ MapRotationMode = "Subject" }), player("ROTATE")).Mode == "Subject")
check("player ROTATE overrides config NorthUp", Module.ResolveRotation(config({ MapRotationMode = "NorthUp" }), player("ROTATE")).Mode == "Camera")
check("negative response clamps to 0", Module.ResolveRotation(config({ MapRotationResponse = -5 }), nil).Response == 0)

-- MapHeading with the live calibration (90 degree coordinate rotation, no flips)
local c, s = math.cos(math.rad(90)), math.sin(math.rad(90))
check("world +X maps to heading 180", near(Module.MapHeading(Vector3.new(1, 0, 0), c, s, false, false), 180))
check("world -Z maps to heading 90", near(Module.MapHeading(Vector3.new(0, 0, -1), c, s, false, false), 90))
check("straight down returns nil", Module.MapHeading(Vector3.new(0, -1, 0), c, s, false, false) == nil)
check("flipX mirrors", near(Module.MapHeading(Vector3.new(-1, 0, 0), c, s, true, false), 180))
-- Identity calibration: -Z is up, +X is right
check("identity -Z is 0", near(Module.MapHeading(Vector3.new(0, 0, -1), 1, 0, false, false), 0))
check("identity +X is 90", near(Module.MapHeading(Vector3.new(1, 0, 0), 1, 0, false, false), 90))

-- StepHeading
check("first step snaps", Module.StepHeading(nil, 45, 10, 1 / 60) == 45)
check("nil target holds", Module.StepHeading(30, nil, 10, 1 / 60) == 30)
check("nil both gives 0", Module.StepHeading(nil, nil, 10, 1 / 60) == 0)
check("response 0 snaps", Module.StepHeading(10, 100, 0, 1 / 60) == 100)
local wrapped = Module.StepHeading(170, -170, 0, 1 / 60)
check("shortest path wraps through 180", near(wrapped, 190))
local partial = Module.StepHeading(0, 90, 10, 1 / 60)
check("smoothed step is partial and positive", partial > 0 and partial < 90)

-- PlaceNorth
local arrow = { Rotation = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10) }
local corner = { Vector2.new(1, 1), UDim2.new(1, -10, 1, -10) }
Module.PlaceNorth(arrow, { Mode = "Camera", NorthMode = "Orbit", NorthInset = 16 }, 0, 245, corner[1], corner[2])
check("orbit at 0 sits top centre", arrow.AnchorPoint == Vector2.new(0.5, 0.5) and near(arrow.Position.X.Scale, 0.5) and near(arrow.Position.Y.Scale, 16 / 245))
Module.PlaceNorth(arrow, { Mode = "Camera", NorthMode = "Orbit", NorthInset = 16 }, 90, 245, corner[1], corner[2])
check("orbit at 90 sits right centre", near(arrow.Position.X.Scale, 1 - 16 / 245) and near(arrow.Position.Y.Scale, 0.5) and arrow.Rotation == 90)
Module.PlaceNorth(arrow, { Mode = "NorthUp", NorthMode = "Orbit", NorthInset = 16 }, 0, 245, corner[1], corner[2])
check("NorthUp restores corner", arrow.AnchorPoint == corner[1] and arrow.Position == corner[2] and arrow.Rotation == 0)
Module.PlaceNorth(arrow, { Mode = "Camera", NorthMode = "Corner", NorthInset = 16 }, -30, 245, corner[1], corner[2])
check("Corner mode keeps corner but rotates", arrow.Position == corner[2] and arrow.Rotation == -30)

return { failures = failures, results = results }
