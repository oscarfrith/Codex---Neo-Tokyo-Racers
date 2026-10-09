-- Pure tests for RaceSession.RaceHudClient. start() is never called here: it claims the surface, waits for PlayerGui
-- and the racing remotes and creates two ScreenGuis, which is a Play check (NOTES.md).
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table" and type(M.start) == "function", "start")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("_asset: the Classic rule (line 29)", function()
		expect(M._asset(nil) == "" and M._asset("") == "", "empty")
		expect(M._asset(12345) == "rbxassetid://12345", M._asset(12345))
		expect(M._asset("12345") == "rbxassetid://12345", "digits")
		expect(M._asset("rbxassetid://777") == "rbxassetid://777", "already a content id")
		expect(M._asset("none") == "none", "no digits: unchanged")
	end)

	case("_subject: the seat's vehicle root, else the seat, else the character root", function()
		local character = env.Detached("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = character
		local player = { Character = character }
		expect(M._subject(player) == root, "on foot: HumanoidRootPart")
		expect(M._subject({ Character = nil }) == nil, "no character")
		local empty = env.Detached("Model")
		expect(M._subject({ Character = empty }) == nil, "no root part")
	end)

	case("_mapConfig: an unknown event gives a disabled map with no image and never errors", function()
		local config = M._mapConfig("Race", "__pulse_test_no_such_event__")
		expect(type(config) == "table", "a table")
		expect(config.Enabled == false and config.Anchor == nil, "disabled, no anchor")
		expect(config.Image == "", "no image")
	end)

	return results
end
