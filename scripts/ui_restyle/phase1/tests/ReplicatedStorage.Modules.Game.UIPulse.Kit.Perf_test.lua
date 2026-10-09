-- Pure tests for Kit.Perf (API.md 9 and 13). Detached instances only, no yield.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		if ok then
			table.insert(results, { name = "Perf: " .. name, ok = true })
		else
			table.insert(results, { name = "Perf: " .. name, ok = false, detail = tostring(detail) })
		end
	end

	case("Enabled is a boolean", function()
		assert(type(M.Enabled) == "boolean", typeof(M.Enabled))
	end)

	case("Count with Enabled false is a no-op", function()
		local Players = game:GetService("Players")
		local player = Players.LocalPlayer
		local playerScripts = player and player:FindFirstChildOfClass("PlayerScripts")
		local before = playerScripts and playerScripts:FindFirstChild("PulsePerf")
		local was = M.Enabled
		M.Enabled = false
		local ok, detail = pcall(function()
			assert(select("#", M.Count("TestCounter")) == 0, "returns nothing")
			M.Count("TestCounter", 5)
			M.Count("Test.Counter with spaces", 1)
		end)
		M.Enabled = was
		assert(ok, detail)
		local after = playerScripts and playerScripts:FindFirstChild("PulsePerf")
		assert(before == after, "Count created the PulsePerf folder while disabled")
	end)

	case("Bind returns a disconnectable handle", function()
		local root = env.Detached("Frame")
		local calls = 0
		local function step()
			calls += 1
		end

		root.Visible = false
		local hidden = M.Bind("TestHidden", root, step)
		assert(type(hidden) == "table" and type(hidden.Disconnect) == "function", "handle shape")
		hidden.Disconnect()
		hidden.Disconnect()

		root.Visible = true
		local shown = M.Bind("TestShown", root, step)
		shown.Disconnect()
		shown:Disconnect()

		assert(calls == 0, "the step ran during a test that never yields")
	end)

	case("Bind refuses bad arguments", function()
		local root = env.Detached("Frame")
		local function step() end
		assert(not pcall(M.Bind, "", root, step), "empty name")
		assert(not pcall(M.Bind, "X", nil, step), "no root")
		assert(not pcall(M.Bind, "X", root, nil), "no step")
		assert(not pcall(M.Bind, "X", env.Detached("Folder"), step), "root is not a GuiObject")
	end)

	return results
end
