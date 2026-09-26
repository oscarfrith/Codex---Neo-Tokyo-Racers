-- P7 CameraService tests with an injected fake camera and player (no game mutation).
return function(source)
	local results, failures = {}, 0
	local function test(name, body)
		local ok, err = pcall(body)
		table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
		if not ok then failures += 1 end
	end
	local camera = { FieldOfView = 70 }
	local writes = {}
	local player = setmetatable({}, {
		__index = function(_, k) return rawget(writes, k) end,
		__newindex = function(_, k, v)
			rawset(writes, k, v)
			local mn, mx = rawget(writes, "CameraMinZoomDistance"), rawget(writes, "CameraMaxZoomDistance")
			assert(not (mn and mx and mn > mx), "engine would see min > max")
		end,
	})
	rawset(writes, "CameraMinZoomDistance", 0.5); rawset(writes, "CameraMaxZoomDistance", 128)
	local fakeGame = { GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = player } end
		if name == "Workspace" then return { CurrentCamera = camera } end
		if name == "StarterPlayer" then return { CameraMinZoomDistance = 0.5, CameraMaxZoomDistance = 128 } end
	end }
	local fn = assert(loadstring(source))
	setfenv(fn, setmetatable({ game = fakeGame }, { __index = getfenv(0) }))
	local C = fn()
	test("priority wins and restore to captured base", function()
		C.SetFieldOfView("Sprint", 80, 10); assert(camera.FieldOfView == 80)
		C.SetFieldOfView("DrivingCamera", 85, 100); assert(camera.FieldOfView == 85)
		C.SetFieldOfView("Sprint", 75, 10); assert(camera.FieldOfView == 85)
		C.ClearFieldOfView("DrivingCamera"); assert(camera.FieldOfView == 75)
		C.ClearFieldOfView("Sprint"); assert(camera.FieldOfView == 70)
	end)
	test("invalid FOV ignored and clamped", function()
		C.SetFieldOfView("X", 0 / 0, 1); assert(camera.FieldOfView == 70)
		C.SetFieldOfView("X", 500, 1); assert(camera.FieldOfView == 120)
		C.ClearFieldOfView("X"); assert(camera.FieldOfView == 70)
	end)
	test("zoom lock and restore keep min<=max and reject NaN", function()
		C.SetZoomLimits("DrivingCamera", 22, 22, 100)
		assert(player.CameraMinZoomDistance == 22 and player.CameraMaxZoomDistance == 22)
		C.SetZoomLimits("DrivingCamera", 0 / 0, 0 / 0, 100)
		assert(player.CameraMinZoomDistance == 22)
		C.SetZoomLimits("DrivingCamera", 300, 300, 100)
		assert(player.CameraMaxZoomDistance == 300)
		C.ClearZoomLimits("DrivingCamera")
		assert(player.CameraMinZoomDistance == 0.5 and player.CameraMaxZoomDistance == 128)
	end)
	test("inverted range is normalised", function()
		C.SetZoomLimits("Y", 50, 10, 1)
		assert(player.CameraMinZoomDistance == 50 and player.CameraMaxZoomDistance == 50)
		C.ClearZoomLimits("Y")
	end)
	test("owners diagnostic", function()
		C.SetFieldOfView("A", 60, 5); C.SetFieldOfView("B", 65, 6)
		local fovOwner = C.Owners(); assert(fovOwner == "B")
		C.ClearFieldOfView("A"); C.ClearFieldOfView("B")
	end)
	return { failures = failures, results = results }
end
