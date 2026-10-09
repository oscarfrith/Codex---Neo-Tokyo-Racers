-- Pulse Play check: startup_state. CLIENT side, READ-ONLY. Run during Play as the source of an unparented
-- ModuleScript (no loadstring). It requires no game module, fires no remote, writes no attribute and creates no
-- instance. Returns ONE JSON string:
--   { ok, style, startup = {counts, notReady, statuses}, latch, config, guis = [...], duplicates, logs = {errors, warnings} }
-- CONTRACT.md steps 10 and 11: every entry ready, one owner per surface, every Pulse gui marked, no duplicate names.
local ARGS = {
	maxLog = 40, -- newest errors / warnings kept
	warnPatterns = { "Pulse", "ClientBase" }, -- warnings are listed only when they contain one of these
	expectStyle = nil, -- "Pulse" | "Classic": when set, ok is false if the latch reports another style
	absentGuis = {}, -- ScreenGui names that must NOT exist (the replaced Classic guis of the families delivered)
}

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function plain(value)
	local kind = typeof(value)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return value
	end
	return tostring(value)
end

local function attributesOf(instance)
	local out = {}
	if instance then
		for name, value in pairs(instance:GetAttributes()) do
			out[name] = plain(value)
		end
	end
	return out
end

local problems = {}
local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
local playerScripts = player and player:FindFirstChild("PlayerScripts")

-- ClientBase.StartupState: one attribute per entry name -----------------------------------------------------------
local startup = { found = false, statuses = {}, counts = {}, notReady = {} }
local clientBase = playerScripts and playerScripts:FindFirstChild("ClientBase")
local startupState = clientBase and clientBase:FindFirstChild("StartupState")
if startupState then
	startup.found = true
	for name, value in pairs(startupState:GetAttributes()) do
		local status = tostring(value)
		startup.statuses[name] = status
		startup.counts[status] = (startup.counts[status] or 0) + 1
		if status ~= "ready" and status ~= "skipped" then
			table.insert(startup.notReady, name .. "=" .. status)
		end
	end
	table.sort(startup.notReady)
	if #startup.notReady > 0 then
		table.insert(problems, #startup.notReady .. " entries are not ready")
	end
else
	table.insert(problems, "PlayerScripts.ClientBase.StartupState not found")
end

-- The style latch (attributes the latch publishes on its own ModuleScript) and the config it read -----------------
local latchModule = ReplicatedFirst:FindFirstChild("UIStyleSwitch")
local latch = attributesOf(latchModule)
local config = {}
local configFolder = ReplicatedStorage:FindFirstChild("Config")
local uiConfig = configFolder and configFolder:FindFirstChild("UI")
if uiConfig then
	config.UIStyle = plain(uiConfig:GetAttribute("UIStyle"))
	config.UIStyleDevFamilies = plain(uiConfig:GetAttribute("UIStyleDevFamilies"))
end
local development = configFolder and configFolder:FindFirstChild("Development")
local clientTools = development and development:FindFirstChild("ClientTools")
if clientTools then
	config.PulseGalleryEnabled = plain(clientTools:GetAttribute("PulseGalleryEnabled"))
end
local onboarding = configFolder and configFolder:FindFirstChild("Player") and configFolder.Player:FindFirstChild("Onboarding")
if onboarding then
	config.StudioVehicleSandboxEveryPlay = plain(onboarding:GetAttribute("StudioVehicleSandboxEveryPlay"))
	config.StudioReplayEveryPlay = plain(onboarding:GetAttribute("StudioReplayEveryPlay"))
end

-- Every ScreenGui under PlayerGui -----------------------------------------------------------------------------------
local guis, byName, duplicates = {}, {}, {}
local pulseCount, classicCount = 0, 0
if playerGui then
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			byName[child.Name] = (byName[child.Name] or 0) + 1
		end
	end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			local style = child:GetAttribute("UIStyle")
			local root = child:FindFirstChild("Root")
			if style == "Pulse" then
				pulseCount += 1
			else
				classicCount += 1
			end
			table.insert(guis, {
				name = child.Name,
				uiStyle = plain(style),
				pulseLayer = plain(child:GetAttribute("PulseLayer")),
				displayOrder = child.DisplayOrder,
				enabled = child.Enabled,
				rootVisible = if root and root:IsA("GuiObject") then root.Visible else nil,
				resetOnSpawn = child.ResetOnSpawn,
				ignoreGuiInset = child.IgnoreGuiInset,
				descendants = #child:GetDescendants(),
				duplicate = byName[child.Name] > 1,
			})
		end
	end
	table.sort(guis, function(a, b)
		if a.displayOrder ~= b.displayOrder then
			return a.displayOrder < b.displayOrder
		end
		return a.name < b.name
	end)
	for name, count in pairs(byName) do
		if count > 1 then
			table.insert(duplicates, name .. " x" .. count)
		end
	end
	table.sort(duplicates)
	if #duplicates > 0 then
		table.insert(problems, "duplicate ScreenGui names: " .. table.concat(duplicates, ", "))
	end
	for _, name in ipairs(ARGS.absentGuis) do
		if byName[name] then
			local classic = false
			for _, row in ipairs(guis) do
				if row.name == name and row.uiStyle ~= "Pulse" then
					classic = true
				end
			end
			if classic then
				table.insert(problems, "a Classic ScreenGui named " .. name .. " exists (its owner was replaced)")
			end
		end
	end
else
	table.insert(problems, "PlayerGui not found")
end

-- The client log: every error; warnings that mention Pulse or ClientBase ----------------------------------------------
local errors, warnings = {}, {}
local okLog, history = pcall(function()
	return LogService:GetLogHistory()
end)
if okLog and type(history) == "table" then
	for _, entry in ipairs(history) do
		local message = tostring(entry.message)
		if entry.messageType == Enum.MessageType.MessageError then
			table.insert(errors, { t = entry.timestamp, message = string.sub(message, 1, 400) })
		elseif entry.messageType == Enum.MessageType.MessageWarning then
			for _, pattern in ipairs(ARGS.warnPatterns) do
				if string.find(message, pattern, 1, true) then
					table.insert(warnings, { t = entry.timestamp, message = string.sub(message, 1, 400) })
					break
				end
			end
		end
	end
else
	table.insert(problems, "LogService:GetLogHistory failed: " .. tostring(history))
end
local function newest(list)
	local out = {}
	for index = math.max(1, #list - ARGS.maxLog + 1), #list do
		table.insert(out, list[index])
	end
	return out
end
if #errors > 0 then
	table.insert(problems, #errors .. " errors in the client log")
end

local style = latch.UIStyle or latch.UIStyleResolved or latch.Style
if ARGS.expectStyle and style ~= nil and style ~= ARGS.expectStyle then
	table.insert(problems, "latch style is " .. tostring(style) .. ", expected " .. ARGS.expectStyle)
end

return HttpService:JSONEncode({
	check = "startup_state",
	ok = #problems == 0,
	problems = problems,
	style = style,
	startup = startup,
	latch = latch,
	config = config,
	guiCount = { pulse = pulseCount, other = classicCount },
	guis = guis,
	duplicates = duplicates,
	logs = { errorCount = #errors, warningCount = #warnings, errors = newest(errors), warnings = newest(warnings) },
})
