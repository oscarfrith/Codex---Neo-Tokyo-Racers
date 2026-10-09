-- Pure tests for RaceMenu.RaceMenuClient. start() is never called here: it claims the surface, waits for PlayerGui
-- and creates a ScreenGui, which is a Play check (NOTES.md). Only the owner shape and the two start helpers.
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
		expect(type(M) == "table", "module is a table")
		expect(type(M.start) == "function", "start is a function")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("resolve: walks existing children without waiting", function()
		local root = env.Detached("Folder")
		local remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = root
		local racing = Instance.new("Folder")
		racing.Name = "Racing"
		racing.Parent = remotes
		expect(M._resolve(root, { "Remotes", "Racing" }, 0) == racing, "two hops")
		expect(M._resolve(root, {}, 0) == root, "no hops is the root")
	end)

	case("resolve: a nil root or a missing hop gives nil, never an error (timeout 0 = no wait)", function()
		local root = env.Detached("Folder")
		expect(M._resolve(nil, { "Anything" }, 0) == nil, "nil root")
		expect(M._resolve(root, { "Missing", "Deeper" }, 0) == nil, "missing hop")
	end)

	case("shared: nil in, nil out", function()
		expect(M._shared(nil) == nil, "a missing module is nil, not an error")
	end)

	return results
end
