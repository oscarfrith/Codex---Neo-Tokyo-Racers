-- Pure tests for RaceEntry.RaceEntryClient. start() is never called here: it claims the surface and creates the
-- ScreenGui, which is a Play check (phase2 CONTRACT step 11). The two resolvers are pure and are tested on
-- detached folders (plain Folders stand in for the two remotes: no remote instance is ever created by Pulse code).
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then
			error(message, 2)
		end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = (not ok) and tostring(detail) or nil })
	end

	-- Builds Folder chains under a detached root; the last name of each path gets `className`.
	local function tree(paths)
		local root = env.Detached("Folder")
		for _, entry in ipairs(paths) do
			local current = root
			for index, name in ipairs(entry.Path) do
				local child = current:FindFirstChild(name)
				if not child then
					child = Instance.new(index == #entry.Path and entry.Class or "Folder")
					child.Name = name
					child.Parent = current
				end
				current = child
			end
		end
		return root
	end

	local function storage(skip)
		local paths = {}
		if skip ~= "RaceRequest" then
			table.insert(paths, { Path = { "Remotes", "Racing", "RaceRequest" }, Class = "Folder" })
		end
		if skip ~= "GarageInvoke" then
			table.insert(paths, { Path = { "Remotes", "Garage", "GarageInvoke" }, Class = "Folder" })
		end
		return tree(paths)
	end

	local function scripts(skip)
		local paths = { { Path = { "Runtime", "UI", "FreeRoamHudPresentationMode" }, Class = "BindableEvent" } }
		if skip ~= "Request" then
			table.insert(paths, { Path = { "Runtime", "Racing", "RaceEntryPresentationRequest" }, Class = "BindableEvent" })
		end
		if skip ~= "LegacyAction" then
			table.insert(paths, { Path = { "Runtime", "Racing", "RaceEntryLegacyAction" }, Class = "BindableEvent" })
		end
		return tree(paths)
	end

	case("owner shape: start exists and nothing ran at require", function()
		expect(type(M) == "table", "module is a table")
		expect(type(M.start) == "function", "start is a function")
		expect(M.Controller == nil, "no Controller before start")
	end)

	case("_find walks by name and returns nil on any missing step", function()
		local root = storage(nil)
		local remote = M._find(root, { "Remotes", "Racing", "RaceRequest" })
		expect(remote ~= nil and remote.Name == "RaceRequest" and remote.Parent.Name == "Racing", "found the remote")
		expect(M._find(root, { "Remotes", "Nope", "RaceRequest" }) == nil, "missing middle step")
		expect(M._find(root, { "Remotes", "Racing", "Nope" }) == nil, "missing last step")
		expect(M._find(nil, { "Remotes" }) == nil, "nil root")
		expect(M._find(root, {}) == root, "empty path is the root")
	end)

	case("_resolve finds the four Classic objects by their Classic names", function()
		local found, missing = M._resolve({ Storage = storage(nil), Scripts = scripts(nil) })
		expect(#missing == 0, "nothing missing: " .. table.concat(missing, ","))
		expect(found.RaceRequest.Name == "RaceRequest" and found.RaceRequest.Parent.Name == "Racing", "RaceRequest")
		expect(found.GarageInvoke.Name == "GarageInvoke" and found.GarageInvoke.Parent.Name == "Garage", "GarageInvoke")
		expect(found.Request.Name == "RaceEntryPresentationRequest" and found.Request:IsA("BindableEvent"), "request bindable")
		expect(found.LegacyAction.Name == "RaceEntryLegacyAction" and found.LegacyAction:IsA("BindableEvent"), "legacy action bindable")
		local count = 0
		for _ in pairs(found) do
			count += 1
		end
		expect(count == 4, "exactly four objects")
	end)

	case("_resolve reports what is missing instead of waiting", function()
		for _, key in ipairs({ "RaceRequest", "GarageInvoke" }) do
			local _, missing = M._resolve({ Storage = storage(key), Scripts = scripts(nil) })
			expect(#missing == 1 and missing[1] == key, key .. " reported")
		end
		for _, key in ipairs({ "Request", "LegacyAction" }) do
			local _, missing = M._resolve({ Storage = storage(nil), Scripts = scripts(key) })
			expect(#missing == 1 and missing[1] == key, key .. " reported")
		end
		local _, missing = M._resolve({ Storage = storage(nil), Scripts = nil })
		expect(table.concat(missing, ",") == "LegacyAction,Request", "no PlayerScripts yet: " .. table.concat(missing, ","))
	end)

	return results
end
