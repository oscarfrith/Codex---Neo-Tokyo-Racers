-- Integrator Edit helpers. Run once per Studio session through execute_luau (Edit):
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8796/scripts/ui_restyle/phase2/tools/edit_helpers.lua", true))()
-- Defines shared.P2TEST, shared.P2RUN, shared.EDITRUN, shared.SANDBOX, shared.INSTALL. Writes nothing by itself.
local Http = game:GetService("HttpService")
local ORIGIN = "http://127.0.0.1:8796/"
assert(game.PlaceId == 93959280828322, "wrong place")

shared.EDITRUN = function(path, subs)
	local src = Http:GetAsync(ORIGIN .. path, true)
	for _, s in subs or {} do src = src:gsub(s[1], s[2], 1) end
	local fn, err = loadstring(src)
	if not fn then return "COMPILE " .. tostring(err) end
	local ok, res = pcall(fn)
	return tostring(ok) .. " " .. tostring(res):sub(1, 160)
end

shared.SANDBOX = function(mode)
	return shared.EDITRUN("scripts/ui_restyle/probes/sandbox_window.lua",
		{ { 'mode = "status"', 'mode = "' .. mode .. '"' }, { 'note = ""', 'note = "wave 2 Play checks"' } }):sub(1, 40)
end

-- Runs the Edit harness for an install unit and returns a short summary (failures grouped).
shared.P2TEST = function(unit, scope)
	local src = Http:GetAsync(ORIGIN .. "scripts/ui_restyle/phase2/tools/run_tests_phase2.lua", true)
	src = src:gsub('unit = "00_kit"', 'unit = "' .. unit .. '"', 1)
	if scope then src = src:gsub('scope = "unit%+kit"', 'scope = "' .. scope .. '"', 1) end
	local fn, err = loadstring(src)
	if not fn then return "HARNESS COMPILE: " .. tostring(err) end
	local ok, res = pcall(fn)
	if not ok then return "HARNESS ERROR: " .. tostring(res) end
	if type(res) ~= "string" then res = Http:JSONEncode(res) end
	pcall(function() Http:PostAsync(ORIGIN .. "json/p2_tests_" .. unit .. ".json", res) end)
	local d = Http:JSONDecode(res)
	local pass, groups, order = 0, {}, {}
	for _, r in d.results or {} do
		if r.ok then
			pass += 1
		else
			local k = tostring(r.module) .. " | " .. tostring(r.detail):sub(1, 170):gsub("%d+%.%d+", "N")
			if not groups[k] then
				groups[k] = { n = 0, name = r.name }
				table.insert(order, k)
			end
			groups[k].n += 1
		end
	end
	local lines = { "unit=" .. unit .. " pass=" .. pass .. " total=" .. #(d.results or {}) .. " compileErrors="
		.. #(d.compileErrors or {}) }
	for i, c in d.compileErrors or {} do
		if i <= 12 then table.insert(lines, "CE " .. Http:JSONEncode(c):sub(1, 260)) end
	end
	for i = 1, math.min(#order, 30) do
		table.insert(lines, groups[order[i]].n .. "x " .. order[i] .. " | e.g. " .. tostring(groups[order[i]].name):sub(1, 70))
	end
	return table.concat(lines, "\n")
end

-- Runs one built installer script of a unit (out_audit.lua, out_apply.lua, out_rollback.lua) and summarises it.
shared.P2RUN = function(unit, file, tag)
	local src = Http:GetAsync(ORIGIN .. "scripts/ui_restyle/phase2/install/" .. unit .. "/" .. file, true)
	local fn, err = loadstring(src)
	if not fn then return tag .. " COMPILE " .. tostring(err) end
	local ok, res = pcall(fn)
	if type(res) ~= "string" then res = ok and Http:JSONEncode(res) or tostring(res) end
	pcall(function() Http:PostAsync(ORIGIN .. "json/p2_" .. unit .. "_" .. tag .. ".json", res) end)
	local d
	pcall(function() d = Http:JSONDecode(res) end)
	if not d then return tag .. " RAW " .. res:sub(1, 500) end
	local parts = { tag .. ": ok=" .. tostring(d.ok) .. " wrote=" .. tostring(d.wrote) .. " tx=" .. tostring(d.transaction)
		.. " next=" .. tostring(d.next):sub(1, 90) }
	for name, tr in d.transactions or {} do
		local counts = {}
		for _, op in tr.ops do counts[op.state] = (counts[op.state] or 0) + 1 end
		local line = "  " .. name .. "=" .. tostring(tr.state) .. " " .. Http:JSONEncode(counts)
		local shown = 0
		for _, op in tr.ops do
			if (op.state == "BLOCKED" or (op.reason and op.reason ~= "")) and shown < 6 then
				shown += 1
				line ..= "\n    " .. op.id .. " " .. op.state .. " " .. tostring(op.reason):sub(1, 160)
			end
		end
		table.insert(parts, line)
	end
	if #(d.blockers or {}) > 0 then table.insert(parts, "  blockers=" .. Http:JSONEncode(d.blockers):sub(1, 500)) end
	local v = d.classicVerify and d.classicVerify.result
	if v then
		table.insert(parts, "  verify ok=" .. tostring(v.ok) .. " same=" .. tostring(v.scripts.same) .. " added="
			.. #v.scripts.added .. " changed=" .. #v.scripts.changed .. " missing=" .. #v.scripts.missing .. " cfgDiffs="
			.. #v.config.diffs .. " failures=" .. tostring(v.failures))
	end
	return table.concat(parts, "\n")
end

-- APPLY a unit with the sandbox test window closed (the engine refuses while it is open), AUDIT, then reopen it.
shared.INSTALL = function(unit, applies)
	local out = { "close " .. shared.SANDBOX("close") }
	for i = 1, applies or 2 do
		table.insert(out, shared.P2RUN(unit, "out_apply.lua", "apply" .. i))
		task.wait(0.3)
	end
	table.insert(out, shared.P2RUN(unit, "out_audit.lua", "audit_after"))
	table.insert(out, "open " .. shared.SANDBOX("open"))
	return table.concat(out, "\n")
end

-- Runs a list of {unit, "rollback" | "apply" | "audit"} steps with a pause between them (the bridge fetches count
-- against Studio's HTTP request limit) and returns one short line per step. Used to refresh the install chain:
-- a unit's sources transaction carries Routes, so later units' sources are rolled back (newest first) before an
-- earlier unit is re-applied, then everything is applied forward again.
shared.REFIT = function(steps, pause)
	local out = {}
	for _, s in steps do
		local file = s[2] == "rollback" and "out_rollback.lua" or s[2] == "audit" and "out_audit.lua" or "out_apply.lua"
		local r = shared.P2RUN(s[1], file, "refit_" .. s[2])
		local first = r:match("^[^\n]*") or ""
		local blocked = r:match("BLOCKED[^\n]*") or ""
		local verify = s[2] == "audit" and (r:match("verify[^\n]*") or "") or ""
		local blockers = r:match("blockers=%[(.-)%]") or ""
		if s[2] ~= "audit" and blockers:find("Classic verify") and not blockers:find('","') then blockers = "" end
		table.insert(out, s[1] .. " " .. first:sub(1, 120) .. (blocked ~= "" and (" || " .. blocked:sub(1, 150)) or "")
			.. (blockers ~= "" and (" || " .. blockers:sub(1, 180)) or "") .. (verify ~= "" and (" || " .. verify) or ""))
		task.wait(pause or 5)
	end
	return table.concat(out, "\n")
end

return "helpers ready"
