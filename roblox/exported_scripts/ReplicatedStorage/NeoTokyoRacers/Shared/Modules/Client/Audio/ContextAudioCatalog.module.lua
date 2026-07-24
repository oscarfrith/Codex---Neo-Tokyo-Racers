-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CATALOG_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local contextConfig = kit:WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("Context")
local contexts = contextConfig:WaitForChild("Contexts")
local global = contextConfig:WaitForChild("Global")

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function trackRows(folder)
	local rows = {}
	for _, object in ipairs(folder and folder:GetChildren() or {}) do
		if object:IsA("StringValue") then
			local id = assetId(object.Value)
			if id ~= "" then
				table.insert(rows, {
					Id = id,
					Name = object.Name,
					Order = tonumber(object:GetAttribute("Order")) or 0,
					Gain = math.clamp(tonumber(object:GetAttribute("Gain")) or 1, 0, 3),
					Loop = object:GetAttribute("Loop") == true,
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Name < b.Name
	end)
	local limit = math.max(1, math.floor(tonumber(global:GetAttribute("MaxTracksPerChannel")) or 64))
	while #rows > limit do table.remove(rows) end
	return rows
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "boolean" and value or fallback
end

function Catalog.GlobalNumber(name, fallback)
	local value = tonumber(global:GetAttribute(name))
	return value ~= nil and value or fallback
end

function Catalog.GlobalString(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

function Catalog.HasContext(contextId)
	local folder = contexts:FindFirstChild(tostring(contextId or ""))
	return folder ~= nil and folder:IsA("Folder")
end

function Catalog.Get(contextId)
	local folder = contexts:FindFirstChild(tostring(contextId or ""))
	if not (folder and folder:IsA("Folder")) then return nil end
	return {
		Id = folder.Name,
		DisplayName = tostring(folder:GetAttribute("DisplayName") or folder.Name),
		Priority = tonumber(folder:GetAttribute("Priority")) or 0,
		FadeSeconds = math.clamp(tonumber(folder:GetAttribute("FadeSeconds")) or 1.5, 0, 10),
		MusicGain = math.clamp(tonumber(folder:GetAttribute("MusicGain")) or 0.55, 0, 3),
		AmbienceGain = math.clamp(tonumber(folder:GetAttribute("AmbienceGain")) or 0.45, 0, 3),
		PlaylistMode = tostring(folder:GetAttribute("PlaylistMode") or "Sequential"),
		Music = trackRows(folder:FindFirstChild("MusicTracks")),
		Ambience = trackRows(folder:FindFirstChild("AmbienceTracks")),
	}
end

function Catalog.CountPopulatedTracks()
	local count = 0
	for _, context in ipairs(contexts:GetChildren()) do
		if context:IsA("Folder") then
			for _, childName in ipairs({ "MusicTracks", "AmbienceTracks" }) do
				local tracks = context:FindFirstChild(childName)
				for _, track in ipairs(tracks and tracks:GetChildren() or {}) do
					if track:IsA("StringValue") and tostring(track.Value or "") ~= "" then count += 1 end
				end
			end
		end
	end
	return count
end

return Catalog
