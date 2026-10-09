-- Owns the UI style of the session (Classic or Pulse), read once from Config.UI; owns no UI, entry list or route.
-- Pulse UI (phase1). ReplicatedFirst.UIStyleSwitch. Requires: none.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Pure. raw and devRaw are the attribute values as read (nil when absent). -> style, reason, dev family list or nil.
local function resolve(raw, devRaw, isStudio)
	local style, reason = "Classic", "attribute:invalid"
	if raw == nil then
		reason = "attribute:absent"
	elseif raw == "Pulse" then
		style, reason = "Pulse", "attribute:Pulse"
	elseif raw == "Classic" then
		reason = "attribute:Classic"
	end
	local dev = nil
	if isStudio == true and type(devRaw) == "string" then
		local list = {}
		for name in string.gmatch(devRaw, "[^,]+") do
			local trimmed = string.match(name, "^%s*(.-)%s*$")
			if trimmed ~= "" then
				list[#list + 1] = trimmed
			end
		end
		if #list > 0 then
			dev = list
		end
	end
	return style, reason, dev
end

-- Builds one latch. publish(name, value) receives every state change; tests pass their own.
local function new(raw, devRaw, isStudio, publish)
	local Switch = {}
	local style, reason, dev = resolve(raw, devRaw, isStudio)
	local devSet = nil
	if dev then
		devSet = {}
		for _, family in ipairs(dev) do
			devSet[family] = true
		end
	end
	local committed, families, familySet, claims, claimSet = false, {}, {}, {}, {}
	local function publishAll()
		publish("UIStyleResolved", Switch.Style)
		publish("UIStyleReason", Switch.Reason)
		publish("UIStyleCommitted", committed)
		publish("UIStyleClaims", table.concat(claims, ","))
	end
	Switch.Style = style
	Switch.Reason = reason
	function Switch.Active(family)
		if Switch.Style ~= "Pulse" or type(family) ~= "string" then
			return false
		end
		if devSet and not devSet[family] then
			return false
		end
		return not committed or familySet[family] == true
	end
	function Switch.Commit(report)
		assert(Switch.Style == "Pulse", "UIStyleSwitch.Commit: style is " .. tostring(Switch.Style))
		assert(not committed, "UIStyleSwitch.Commit: already committed")
		assert(type(report) == "table" and type(report.Families) == "table", "UIStyleSwitch.Commit: Families list required")
		local list, set = {}, {}
		for _, family in ipairs(report.Families) do
			assert(type(family) == "string" and family ~= "", "UIStyleSwitch.Commit: family names must be strings")
			assert(not set[family], "UIStyleSwitch.Commit: duplicate family " .. family)
			assert(devSet == nil or devSet[family], "UIStyleSwitch.Commit: family outside the dev list: " .. family)
			list[#list + 1] = family
			set[family] = true
		end
		families, familySet, committed = list, set, true
		publishAll()
	end
	function Switch.Claim(surface)
		assert(type(surface) == "string" and surface ~= "", "UIStyleSwitch.Claim: surface name required")
		assert(Switch.Style == "Pulse", "UIStyleSwitch.Claim(" .. surface .. "): style is " .. tostring(Switch.Style) .. " (" .. tostring(Switch.Reason) .. ")")
		assert(committed, "UIStyleSwitch.Claim(" .. surface .. "): routes are not committed")
		assert(not claimSet[surface], "UIStyleSwitch.Claim(" .. surface .. "): already claimed")
		claimSet[surface] = true
		claims[#claims + 1] = surface
		publishAll()
	end
	function Switch.Downgrade(why)
		assert(#claims == 0, "UIStyleSwitch.Downgrade: refused after a Claim (" .. table.concat(claims, ",") .. ")")
		Switch.Style = "Classic"
		Switch.Reason = "downgraded:" .. tostring(why)
		publishAll()
	end
	function Switch.Report()
		return {
			Style = Switch.Style, Reason = Switch.Reason, Committed = committed,
			Families = table.clone(families), Claims = table.clone(claims), DevFamilies = dev and table.clone(dev) or nil,
		}
	end
	Switch._resolve = resolve
	Switch._new = new
	publishAll()
	return Switch
end

-- The only yield: the first require waits for the config folder. Read once; later changes are ignored.
local ui = ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI")
local rawStyle = ui:GetAttribute("UIStyle")
local rawDev = ui:GetAttribute("UIStyleDevFamilies")
local function publishAttribute(name, value)
	-- A failed attribute write must never stop start-up; the attributes are evidence only.
	pcall(function()
		script:SetAttribute(name, value)
	end)
end
publishAttribute("UIStyleRawAtRead", tostring(rawStyle))
publishAttribute("UIStyleLoadedAtRead", game:IsLoaded())
return new(rawStyle, rawDev, RunService:IsStudio(), publishAttribute)
