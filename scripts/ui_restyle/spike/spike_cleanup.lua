-- Pulse spike cleanup. Play, Client datamodel. Removes every PulseSpike_* ScreenGui under PlayerGui and puts back
-- the two things a spike may have left changed on purpose: the chat restyle from 08 (mode = "apply") and the local
-- prompt Style from 11b (leaveCustom = true). Safe to run at any time and more than once.
local ARGS = {
	prefix = "PulseSpike_",
}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local out = { spike = "cleanup", removed = {}, restored = {}, errors = {} }
local function finish()
	if next(out.errors) == nil then out.errors = nil end
	if next(out.restored) == nil then out.restored = nil end
	local ok, json = pcall(function() return HttpService:JSONEncode(out) end)
	return ok and json or '{"spike":"cleanup","error":"JSON encode failed"}'
end

local player = Players.LocalPlayer
if not player then return '{"spike":"cleanup","error":"no LocalPlayer: run in Play on the Client datamodel"}' end
local playerGui = player:FindFirstChildOfClass("PlayerGui")
if not playerGui then return '{"spike":"cleanup","error":"no PlayerGui"}' end

-- 08: chat window originals stored as attributes
local chatHolder = playerGui:FindFirstChild(ARGS.prefix .. "08")
if chatHolder then
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	for _, prop in ipairs({ "BackgroundColor3", "TextColor3", "FontFace" }) do
		local stored = chatHolder:GetAttribute("Orig_" .. prop)
		if stored ~= nil then
			if window then
				local ok, err = pcall(function() window[prop] = stored end)
				if ok then out.restored["chat." .. prop] = tostring(stored) else out.errors["chat." .. prop] = tostring(err) end
			else
				out.errors["chat." .. prop] = "ChatWindowConfiguration not found"
			end
		end
	end
end

-- 11b: prompt Style left on Custom
local promptHolder = playerGui:FindFirstChild(ARGS.prefix .. "11b")
if promptHolder then
	local path = promptHolder:GetAttribute("PromptPath")
	local styleName = promptHolder:GetAttribute("OrigStyle")
	if path and styleName then
		local found = nil
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("ProximityPrompt") and inst:GetFullName() == path then found = inst; break end
		end
		if found then
			local ok, err = pcall(function() found.Style = Enum.ProximityPromptStyle[styleName] end)
			if ok then out.restored["prompt.Style"] = path .. " -> " .. styleName else out.errors["prompt.Style"] = tostring(err) end
		else
			out.restored["prompt.Style"] = "prompt not present (streamed out); a new copy carries the server's Style"
		end
	end
end

-- 13: render-step binding, in case a run was interrupted
pcall(function() RunService:UnbindFromRenderStep("PulseSpike13_Bound") end)

for _, child in ipairs(playerGui:GetChildren()) do
	if string.sub(child.Name, 1, #ARGS.prefix) == ARGS.prefix then
		out.removed[#out.removed + 1] = child.Name
		child:Destroy()
	end
end
table.sort(out.removed)

local left = 0
for _, child in ipairs(playerGui:GetChildren()) do
	if string.sub(child.Name, 1, #ARGS.prefix) == ARGS.prefix then left += 1 end
end
out.remaining = left
out.note = "Connections made by a spike that returned early (10 mode = start) end with the Play session; nothing else persists."
out.needsCapture = "Optional: one capture to confirm the screen shows only the game's own UI."
return finish()
