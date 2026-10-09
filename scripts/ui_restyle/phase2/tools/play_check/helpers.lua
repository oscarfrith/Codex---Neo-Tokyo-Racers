-- Integrator Play helpers (client, read-only). Run as the source of an unparented ModuleScript; defines shared.STATE,
-- shared.BTNS and shared.WAITSTART for later execute_luau calls in the same Play session.
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")

shared.STATE = function()
	local p = Players.LocalPlayer
	local st = p.PlayerScripts.ClientBase:FindFirstChild("StartupState")
	local counts, bad = {}, {}
	for k, v in st:GetAttributes() do
		counts[tostring(v)] = (counts[tostring(v)] or 0) + 1
		if v ~= "ready" and v ~= "skipped" then table.insert(bad, k .. "=" .. tostring(v)) end
	end
	local pulse, classic, names, dup = {}, {}, {}, {}
	for _, g in p.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			if names[g.Name] then table.insert(dup, g.Name) end
			names[g.Name] = true
			if g:GetAttribute("UIStyle") ~= nil then
				table.insert(pulse, g.Name .. ":" .. #g:GetDescendants())
			else
				table.insert(classic, g.Name)
			end
		end
	end
	local logs = {}
	pcall(function()
		for _, m in game:GetService("LogService"):GetLogHistory() do
			local text = m.message
			if m.messageType == Enum.MessageType.MessageError
				or (m.messageType == Enum.MessageType.MessageWarning
					and (text:find("Pulse") or text:find("ClientBase") or text:find("UIStyle"))) then
				if #logs < 16 then table.insert(logs, text:sub(1, 320)) end
			end
		end
	end)
	return Http:JSONEncode({
		counts = counts, bad = bad, claims = game.ReplicatedFirst.UIStyleSwitch:GetAttribute("UIStyleClaims"),
		pulse = pulse, classic = classic, dup = dup, logs = logs,
	})
end

shared.BTNS = function(guiName, max)
	local root = Players.LocalPlayer.PlayerGui:FindFirstChild(guiName)
	if not root then return "no gui " .. guiName end
	local names = {}
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and #names < (max or 40) then
			local vis, a = true, d
			while a and a:IsA("GuiObject") do
				if not a.Visible then vis = false break end
				a = a.Parent
			end
			if vis then
				local c = d.AbsolutePosition + d.AbsoluteSize / 2
				local label = d:IsA("TextButton") and d.Text or ""
				if label == "" then
					local t = d:FindFirstChildWhichIsA("TextLabel", true)
					label = t and t.Text or ""
				end
				table.insert(names, d.Name .. "[" .. label:sub(1, 22) .. "]@" .. math.floor(c.X) .. "," .. math.floor(c.Y)
					.. (d.Active and "" or "(inactive)"))
			end
		end
	end
	return table.concat(names, "; ")
end

shared.WAITSTART = function()
	local p = Players.LocalPlayer
	local t = 0
	while not p:GetAttribute("StartScreenActive") and t < 20 do
		task.wait(0.5)
		t += 0.5
	end
	task.wait(3)
	return shared.STATE()
end

-- Visible text under a ScreenGui (first `max` labels and buttons with text).
shared.TEXTS = function(guiName, max)
	local root = Players.LocalPlayer.PlayerGui:FindFirstChild(guiName)
	if not root then return "no gui " .. guiName end
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and #out < (max or 30) then
			local vis, a = true, d
			while a and a:IsA("GuiObject") do
				if not a.Visible then vis = false break end
				a = a.Parent
			end
			if vis then table.insert(out, d.Text:sub(1, 40)) end
		end
	end
	return table.concat(out, " | ")
end

-- Nearest ProximityPrompt with this name; walks the character into range when `walk` is true, then triggers it.
shared.PROMPT = function(name, walk)
	local p = Players.LocalPlayer
	local hrp = p.Character.HumanoidRootPart
	local best, bd
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == name and d.Parent:IsA("BasePart") then
			local dist = (d.Parent.Position - hrp.Position).Magnitude
			if not bd or dist < bd then best, bd = d, dist end
		end
	end
	if not best then return "no prompt " .. name end
	if walk then
		local hum = p.Character.Humanoid
		local t = 0
		local want = math.max(6, best.MaxActivationDistance - 4)
		while (best.Parent.Position - hrp.Position).Magnitude > want and t < 25 do
			hum:MoveTo(best.Parent.Position)
			task.wait(0.5)
			t += 0.5
		end
		hum:MoveTo(hrp.Position)
		task.wait(1.2)
	end
	local layer = p.PlayerGui:FindFirstChild("PulseWorldPrompts")
	local seen = "banner=[" .. shared.TEXTS("PulseWorldPrompts", 6) .. "] shown=" .. tostring(layer and layer:GetAttribute("PulseShownPrompts"))
		.. " err=" .. tostring(layer and layer:GetAttribute("PulseLastPromptError"))
	best:InputHoldBegin()
	task.wait(0.2)
	best:InputHoldEnd()
	return name .. " dist=" .. math.floor((best.Parent.Position - hrp.Position).Magnitude) .. " style="
		.. tostring(best.Style):match("[^.]+$") .. " " .. seen
end

shared.LOGS = function()
	return shared.STATE():match('"logs":%b[]')
end

return true
