-- Pure tests for Toasts.ToastClient. start() is never called here: it claims the surface, waits for PlayerGui and
-- creates a ScreenGui, which is a Play check (CONTRACT 7.5 U3 to U7).
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
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

	case("bindable: created with the Classic name, class and parent", function()
		local folder = env.Detached("Folder")
		local event = M._bindable(folder)
		expect(event.ClassName == "BindableEvent", "BindableEvent")
		expect(event.Name == "ShowTopNotification", "name")
		expect(event.Parent == folder, "parent")
		expect(#folder:GetChildren() == 1, "one child")
	end)

	case("bindable: an existing one is adopted, not duplicated", function()
		local folder = env.Detached("Folder")
		local first = M._bindable(folder)
		local second = M._bindable(folder)
		expect(first == second, "same instance")
		expect(#folder:GetChildren() == 1, "still one child")
	end)

	case("bindable: adopts one made by someone else, keeping its connections", function()
		local folder = env.Detached("Folder")
		local existing = Instance.new("BindableEvent")
		existing.Name = "ShowTopNotification"
		existing.Parent = folder
		local adopted = M._bindable(folder)
		expect(adopted == existing, "adopted")
	end)

	return results
end
