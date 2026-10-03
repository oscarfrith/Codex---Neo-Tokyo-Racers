-- Runner for tests.lua. Paste into Studio (Edit) through execute_luau or the Command Bar. Read-only: it fetches
-- text from a localhost file server, compiles it with loadstring and runs pure tests. Nothing in the DataModel
-- is created, changed or destroyed, and no gameplay module is required.
--
-- Start the file server at the repository root first (any free port):
--   py -3 -m http.server 8793 --bind 127.0.0.1
-- If HttpService cannot reach localhost, build the `sources` table another way and call tests.lua directly.
local BASE = "http://127.0.0.1:8793/"
local LIVE = true -- also run the read-only parity tests on the real Piercer templates

local Http = game:GetService("HttpService")
local function fetch(path) return Http:GetAsync(BASE .. path, true) end
local index = Http:JSONDecode(fetch("scripts/exotic_category/stage_a/server/test_sources.json"))
local sources = { before = {}, after = {} }
for name, path in pairs(index.before) do sources.before[name] = fetch(path) end
for name, path in pairs(index.after) do sources.after[name] = fetch(path) end
local run = assert(loadstring(fetch(index.tests), "tests"))()
local report = run(sources, { liveCategoriesRoot = LIVE and game:GetService("ServerStorage").Assets.Vehicles.Categories or nil })
return "failures=" .. report.failures .. " of " .. #report.results .. "\n" .. table.concat(report.results, "\n")
