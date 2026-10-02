-- Vehicle frame-class blockout showroom: Command Bar installer (design exploration only, not game content).
--
-- Use this when the Studio Assistant cannot fetch local files itself (its sandbox has no Network capability).
-- 1. From the repo root, export the layouts and start the local file server:
--      py -3 scripts/vehicle_blockouts/export_showroom.py
--      py -3 -m http.server 8778 --bind 127.0.0.1 --directory scripts/vehicle_blockouts
-- 2. In Studio (Space Racers Backup v2, Edit mode), paste this whole file into the Command Bar and press Enter.
--
-- It rebuilds every class block under Workspace.VehicleCategoryBlockouts and touches nothing else.
-- Each class is replaced in place; the PIERCER_Reference row is left alone. One Undo step per class.
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8778/"
local ORIGIN_X, ORIGIN_Y, ORIGIN_Z = 6200, 2600, -200
local PITCH_X, PITCH_Z = 480, 340
local GRID = {
	{ "rift", "muscle", "exotic", "gt" },
	{ "street", "rodder", "rider", "apex" },
	{ "cruiser", "hauler", "dart", "tether" },
}

local template = HttpService:GetAsync(BASE .. "builder.lua", true)
for r, row in ipairs(GRID) do
	for c, id in ipairs(row) do
		local origin = string.format("%d, %d, %d", ORIGIN_X + (c - 1) * PITCH_X, ORIGIN_Y, ORIGIN_Z + (r - 1) * PITCH_Z)
		local src = template:gsub("__SPEC_NAME__", id):gsub("__ORIGIN__", origin)
		local fn, err = loadstring(src)
		if not fn then
			warn("[VehicleBlockouts] " .. id .. " did not compile: " .. tostring(err))
		else
			local ok, res = pcall(fn)
			if ok then print("[VehicleBlockouts] " .. tostring(res)) else warn("[VehicleBlockouts] " .. id .. " failed: " .. tostring(res)) end
		end
		task.wait()
	end
end
print("[VehicleBlockouts] done")
