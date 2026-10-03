-- Exotic Stage A client: runner for tests.lua and parity.lua (paste into execute_luau, Edit datamodel).
-- Read-only: fetches text from a localhost server, reads live Source and attributes, runs loadstring tests with fakes.
-- It creates nothing, sets nothing and never calls require.
--
-- Before running, serve this folder:  py -3 -m http.server 8847 --bind 127.0.0.1
--   (run it inside scripts/exotic_category/stage_a/client; stop it afterwards)
-- Before APPLY: "before" is the live Source and "after" is after/<Name>.lua. Expect 0 failures in every run.
-- After APPLY: set AFTER_IS_LIVE = true. "after" is then the live Source and "before" is before/<Name>.lua.
--   build.py writes before/<Name>.lua (the exotic-before blob bytes, sha256 checked against the manifest); nothing to copy by hand.
-- RUN_PARITY: parity.lua loads the live calculation modules with loadstring into a private cache (it never calls require).
--   Set it to false to run only the pure tests. It only exercises VehiclePerformanceResolver and GarageVehiclePreviewProfile.
local AFTER_IS_LIVE = false
local RUN_PARITY = true
local Http = game:GetService("HttpService")
local function get(path) return Http:GetAsync("http://127.0.0.1:8847/" .. path, true) end
local G = game:GetService("ReplicatedStorage").Modules.Game
local live = {
	GarageWorkspaceUI = G.UI.GarageWorkspaceUI, GarageUI = G.Garage.GarageUI, GarageBrowserUI = G.UI.GarageBrowserUI,
	GarageModuleCardViewModel = G.UI.GarageModuleCardViewModel, GarageVehiclePreviewProfile = G.Garage.GarageVehiclePreviewProfile,
	VehiclePerformanceResolver = G.Vehicles.Performance.VehiclePerformanceResolver, PreviewCameraClient = G.Garage.PreviewCameraClient,
}
local sources = { Before = {} }
local report = {}
for name, scriptObject in pairs(live) do
	local served = { After = get("after/" .. name .. ".lua"), Before = get("before/" .. name .. ".lua") }
	if AFTER_IS_LIVE then
		sources[name] = scriptObject.Source; sources.Before[name] = served.Before
		if scriptObject.Source ~= served.After then table.insert(report, "NOTE live " .. name .. " differs from after/" .. name .. ".lua") end
	else
		sources[name] = served.After; sources.Before[name] = scriptObject.Source
		if scriptObject.Source ~= served.Before then table.insert(report, "NOTE live " .. name .. " differs from before/" .. name .. ".lua (the exotic-before blob)") end
	end
end
local function run(label, file, argument)
	local out = assert(loadstring(get(file)))()(argument)
	table.insert(report, label .. ": failures=" .. out.failures)
	for _, line in ipairs(out.results) do table.insert(report, "  " .. line) end
end
run("tests (after against before)", "tests.lua", sources)
local afterOnly = {}
for name in pairs(live) do afterOnly[name] = sources[name] end
run("tests (after only)", "tests.lua", afterOnly)
if RUN_PARITY then run("parity (live Piercer data)", "parity.lua", sources) end
return table.concat(report, "\n")
