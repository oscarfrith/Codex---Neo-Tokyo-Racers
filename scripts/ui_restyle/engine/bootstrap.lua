-- bootstrap.lua: binds the engine to the real place. build.py puts MODE, DATA, hash.lua, plan.lua and engine.lua
-- above this. Run in Studio Edit; returns one JSON string.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local function isEdit()
	local ok, edit = pcall(function()
		return RunService:IsEdit()
	end)
	if ok and edit ~= true then
		return false
	end
	return not RunService:IsRunning()
end
local env = {
	placeId = game.PlaceId,
	isEdit = isEdit(),
	root = function(name)
		local ok, service = pcall(function()
			return game:GetService(name)
		end)
		if ok then
			return service
		end
		return nil
	end,
	fetch = function(file)
		if DATA.inline then
			-- Sources were stored by the out_<mode>.partN.lua files; the fingerprint check still applies.
			local stash = shared.UIRestyleInline and shared.UIRestyleInline[DATA.build]
			local chunks = stash and stash[file]
			local count = DATA.inlineFiles[file]
			if type(chunks) ~= "table" or count == nil then
				error("inline source not loaded (run every part file first): " .. file)
			end
			for i = 1, count do
				if type(chunks[i]) ~= "string" then
					error("inline source incomplete, chunk " .. i .. " of " .. count .. ": " .. file)
				end
			end
			return table.concat(chunks, "", 1, count)
		end
		return HttpService:GetAsync(DATA.origin .. file .. "?t=" .. tostring(os.clock()), true)
	end,
	loadChunk = Engine.loadChunk,
	getSource = function(node)
		return node.Source
	end,
	setSource = function(node, text)
		node.Source = text
	end,
	wait = function()
		task.wait()
	end,
	waypoint = function(label)
		game:GetService("ChangeHistoryService"):SetWaypoint(label)
	end,
	jsonDecode = function(text)
		return HttpService:JSONDecode(text)
	end,
}
local ran, report = pcall(Engine.run, MODE, DATA, env)
if not ran then
	return HttpService:JSONEncode({ engine = Engine.VERSION, phase = DATA.phase, mode = MODE, ok = false, blockers = { "engine error: " .. tostring(report) } })
end
if DATA.inline and MODE ~= "AUDIT" and report.ok and report.next:sub(1, 8) == "Complete" and shared.UIRestyleInline then
	shared.UIRestyleInline[DATA.build] = nil
end
return HttpService:JSONEncode(report)
