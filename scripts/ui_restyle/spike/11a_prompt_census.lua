-- Pulse spike 11a: static census of every ProximityPrompt the client can see. Play, Client datamodel. Read only;
-- creates nothing. Groups prompts into the ten families from audit/followup-world-prompts.md. Streaming means only
-- streamed-in prompts are listed: run it in free roam near a start zone, again inside an owned garage, and again
-- with another player's car nearby if the passenger and job families matter.
local ARGS = {
	maxPerFamily = 5, -- sample rows kept per family (counts are always complete)
	includeOtherRoots = true, -- also look under PlayerGui and ReplicatedStorage for stray prompts
}
local ID = "11a"
-- ---- shared spike prelude (identical in every spike file; each file is self-contained) ----
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then return '{"spike":"' .. ID .. '","error":"no LocalPlayer: run in Play on the Client datamodel"}' end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
if not playerGui then return '{"spike":"' .. ID .. '","error":"no PlayerGui"}' end

local out = { spike = ID, errors = {} }
local function try(label, fn, ...)
	local r = table.pack(pcall(fn, ...))
	if not r[1] then out.errors[label] = tostring(r[2]); return nil end
	return r[2]
end
local function r2(n) return math.floor(n * 100 + 0.5) / 100 end
local function v2(v) return { r2(v.X), r2(v.Y) } end
local function finish()
	if next(out.errors) == nil then out.errors = nil end
	local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
	return ok and json or ('{"spike":"' .. ID .. '","error":"JSON encode failed"}')
end
local function waitFrames(n) for _ = 1, n or 2 do RunService.Heartbeat:Wait() end end
local function freshGui(order)
	local old = playerGui:FindFirstChild("PulseSpike_" .. ID)
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PulseSpike_" .. ID
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = order or 20000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end
local SLATE, WHITE, INK = Color3.fromRGB(14, 13, 26), Color3.fromRGB(243, 240, 255), Color3.fromRGB(7, 6, 13)
local PINK, VIOLET, CYAN, YELLOW = Color3.fromRGB(255, 45, 149), Color3.fromRGB(154, 61, 255), Color3.fromRGB(34, 228, 255), Color3.fromRGB(255, 228, 51)
local BARLOW = "rbxassetid://12187372847"
local function barlow(weight) return Font.new(BARLOW, weight or Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic) end
local function frame(parent, name, x, y, w, h, color, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color or SLATE
	f.BackgroundTransparency = transparency or 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end
local function text(parent, name, str, size, x, y, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = color or WHITE
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Position = UDim2.fromOffset(x, y)
	l.Text = str
	if font then pcall(function() l.FontFace = font end) else l.Font = Enum.Font.RobotoMono end
	l.Parent = parent
	return l
end
-- Yields until the face can be measured (or the time runs out). True when it loaded.
local function waitFont(font, seconds)
	local done, ok = false, false
	task.spawn(function()
		ok = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = "H"
			params.Font = font
			params.Size = 20
			params.Width = 1000
			return game:GetService("TextService"):GetTextBoundsAsync(params)
		end)
		done = true
	end)
	local stop = os.clock() + (seconds or 4)
	while not done and os.clock() < stop do RunService.Heartbeat:Wait() end
	return done and ok
end
-- ---- end of prelude ----

-- name -> family, from source:
--   RaceEntryPrompt               TimeTrialServer 109, 1293-1314 (server; Style = Default at 1298 and 1311)
--   EnterVehiclePrompt            VehicleAccessServer 11, 88-106 (server; Style never set)
--   DriveOutPrompt                OwnedGarageManagement 188-201 (server)
--   FootExitPrompt, ManageGaragePrompt   interior template clones (server)
--   OwnedGarageDriveInEntryPrompt, OwnedGarageFootEntryPrompt   static exterior instances
--   Canonical<Mode>               GarageEntranceClient 152-163 (client-made; Style = Default at 154)
--   PassengerRidePrompt           PassengerClientView 9, 69-79 (client-made)
--   JobPrompt                     JobClient 198-206 (client-made, on the local car)
local FAMILY_ORDER = {
	"01 RaceEntryPrompt", "02 EnterVehiclePrompt", "03 DriveOutPrompt", "04 FootExitPrompt", "05 ManageGaragePrompt",
	"06 OwnedGarageDriveInEntryPrompt", "07 OwnedGarageFootEntryPrompt", "08 Canonical<Mode>", "09 PassengerRidePrompt",
	"10 JobPrompt", "99 Other",
}
local EXACT = {
	RaceEntryPrompt = FAMILY_ORDER[1], EnterVehiclePrompt = FAMILY_ORDER[2], DriveOutPrompt = FAMILY_ORDER[3],
	FootExitPrompt = FAMILY_ORDER[4], ManageGaragePrompt = FAMILY_ORDER[5],
	OwnedGarageDriveInEntryPrompt = FAMILY_ORDER[6], OwnedGarageFootEntryPrompt = FAMILY_ORDER[7],
	PassengerRidePrompt = FAMILY_ORDER[9], JobPrompt = FAMILY_ORDER[10],
}
local function familyOf(prompt)
	local exact = EXACT[prompt.Name]
	if exact then return exact end
	if string.sub(prompt.Name, 1, 9) == "Canonical" then return FAMILY_ORDER[8] end
	return FAMILY_ORDER[11]
end

local character = player.Character
local rootPart = character and character:FindFirstChild("HumanoidRootPart")
local function worldPosition(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("Attachment") then return parent.WorldPosition end
	if parent:IsA("BasePart") then return parent.Position end
	if parent:IsA("Model") then local ok, pivot = pcall(function() return parent:GetPivot().Position end); return ok and pivot or nil end
	return nil
end

local families = {}
for _, name in ipairs(FAMILY_ORDER) do families[name] = { count = 0, styles = {}, lineOfSightTrue = 0, enabledCount = 0, samples = {} } end
local total = 0
local function visit(prompt)
	total += 1
	local family = families[familyOf(prompt)]
	family.count += 1
	local style = tostring(prompt.Style)
	family.styles[style] = (family.styles[style] or 0) + 1
	if prompt.RequiresLineOfSight then family.lineOfSightTrue += 1 end
	if prompt.Enabled then family.enabledCount += 1 end
	if #family.samples < ARGS.maxPerFamily then
		local position = worldPosition(prompt)
		family.samples[#family.samples + 1] = {
			path = prompt:GetFullName(),
			style = style,
			actionText = prompt.ActionText,
			objectText = prompt.ObjectText,
			requiresLineOfSight = prompt.RequiresLineOfSight,
			maxActivationDistance = prompt.MaxActivationDistance,
			enabled = prompt.Enabled,
			holdDuration = prompt.HoldDuration,
			keyboardKey = prompt.KeyboardKeyCode.Name,
			gamepadKey = prompt.GamepadKeyCode.Name,
			clickable = prompt.ClickablePrompt,
			exclusivity = prompt.Exclusivity.Name,
			uiOffset = v2(prompt.UIOffset),
			parentClass = prompt.Parent and prompt.Parent.ClassName or "nil",
			parentSize = (prompt.Parent and prompt.Parent:IsA("BasePart")) and { r2(prompt.Parent.Size.X), r2(prompt.Parent.Size.Y), r2(prompt.Parent.Size.Z) } or nil,
			studsFromCharacter = (position and rootPart) and r2((position - rootPart.Position).Magnitude) or nil,
		}
	end
end

local started = os.clock()
local roots = { workspace }
if ARGS.includeOtherRoots then
	roots[#roots + 1] = playerGui
	roots[#roots + 1] = game:GetService("ReplicatedStorage")
end
local scanned = 0
for _, root in ipairs(roots) do
	local ok, err = pcall(function()
		for _, inst in ipairs(root:GetDescendants()) do
			scanned += 1
			if inst:IsA("ProximityPrompt") then visit(inst) end
		end
	end)
	if not ok then out.errors["scan " .. root.Name] = tostring(err) end
end

out.totalPrompts = total
out.instancesScanned = scanned
out.scanSeconds = r2(os.clock() - started)
out.families = {}
local nonDefault = 0
for _, name in ipairs(FAMILY_ORDER) do
	local family = families[name]
	if #family.samples == 0 then family.samples = nil end
	if next(family.styles) == nil then family.styles = nil end
	out.families[name] = family
	if family.styles then
		for style, n in pairs(family.styles) do if style ~= "Enum.ProximityPromptStyle.Default" then nonDefault += n end end
	end
end
out.promptsNotDefaultStyle = nonDefault

-- the scoped roots WorldPromptView would listen on (plan 7.2)
local function exists(path)
	local node = workspace
	for part in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(part)
		if not node then return false end
	end
	return true
end
out.knownRoots = {
	["World.Runtime.PlayerVehicles"] = exists("World.Runtime.PlayerVehicles"),
	["World.Interiors.OwnedGarageInstances"] = exists("World.Interiors.OwnedGarageInstances"),
	["World.RaceRoutes"] = exists("World.RaceRoutes"),
	["World.OwnedGarageExteriors"] = exists("World.OwnedGarageExteriors"),
}
out.streamingEnabled = select(2, pcall(function() return workspace.StreamingEnabled end))
out.character = { present = rootPart ~= nil, seated = select(2, pcall(function()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart ~= nil
end)) }
local promptService = game:GetService("ProximityPromptService")
out.promptService = { enabled = promptService.Enabled, maxPromptsVisible = promptService.MaxPromptsVisible }
out.defaultPromptGui = select(2, pcall(function()
	local holder = playerGui:FindFirstChild("ProximityPrompts")
	return holder and { class = holder.ClassName, children = #holder:GetChildren() } or "PlayerGui.ProximityPrompts not found"
end))

out.decides = "Confirms the family list WorldPromptView must cover and each family's Style, text casing, key and distance before 11b. Any prompt in '99 Other' is an eleventh family the plan has not named. Use one RaceEntryPrompt sample path as ARGS.promptPath for 11b."
out.needsCapture = "none (data only). Optional: a capture standing at a start zone showing the default engine prompt, as the 'before' picture for 11b."
return finish()
