-- Command Bar / execute_luau (Edit), PR98. 2026-10-10 mobile pass: RadioStripView lays the strip out with the buttons'
-- real (touch hit box) size. Guarded: writes only when the live source equals before_ or after_RadioStripView.lua.
-- The script was created by scripts/ui_restyle/radio (its recorded after-hash for this script is stale from here).
assert(game.PlaceId == 103397770260610, "wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8796/scripts/ui_restyle/radio/mobile_fix/"
local function norm(s) return (s:gsub("\r\n", "\n")) end
local before = norm(Http:GetAsync(base .. "before_RadioStripView.lua", true))
local after = norm(Http:GetAsync(base .. "after_RadioStripView.lua", true))
local target = game.ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.RadioStripView
local live = norm(target.Source)
if live == after then return "already after" end
assert(live == before, "RadioStripView was edited since the radio delivery; refusing to write")
assert(loadstring(after), "after source does not compile")
target.Source = after
return "written " .. #after
