-- Neo Tokyo Racers - Cleanup Phase M: Print Action Sections
-- Run in Roblox Studio Command Bar, Edit mode, after Phase M audit.
--
-- Purpose:
--   Prints only the actionable sections from the latest Phase M audit report,
--   so they can be pasted back into Codex without the full hierarchy tree.
--
-- Safe effects:
--   - None. This script only reads StringValues and prints to Output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SECTION_TITLES = {
	"Warnings",
	"Missing Required Migrated Paths",
	"Unexpected Active Scripts",
	"Missing Expected Active Scripts",
	"Source Legacy Token Hits",
	"Stale ObjectValues",
	"Attribute Legacy Token Hits",
	"StringValue Legacy Token Hits Outside Reports",
	"Legacy-Named Instances",
	"Auto Cleanup Candidates",
	"Review Before Delete Candidates",
}

local function log(message)
	print("[NTR Cleanup Phase M Sections] " .. message)
end

local function readReportText()
	local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local compatibility = ntr and ntr:FindFirstChild("Compatibility")
	local cleanupReports = compatibility and compatibility:FindFirstChild("CleanupReports")
	if not cleanupReports then
		error("Could not find ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports. Run Phase M first.")
	end

	local chunks = {}
	for _, child in ipairs(cleanupReports:GetChildren()) do
		if child:IsA("StringValue") and string.match(child.Name, "^CleanupPhaseM_PostKitMigrationAudit_%d%d%d$") then
			table.insert(chunks, child)
		end
	end

	table.sort(chunks, function(a, b)
		return a.Name < b.Name
	end)

	if #chunks == 0 then
		error("No CleanupPhaseM_PostKitMigrationAudit chunks found. Run Phase M first.")
	end

	local parts = {}
	for _, chunk in ipairs(chunks) do
		table.insert(parts, chunk.Value)
	end
	return table.concat(parts, "")
end

local function extractSection(reportText, title)
	local heading = "## " .. title
	local startIndex = string.find(reportText, heading, 1, true)
	if not startIndex then
		return heading .. "\n\n- Section not found.\n"
	end

	local nextIndex = string.find(reportText, "\n## ", startIndex + #heading, true)
	if nextIndex then
		return string.sub(reportText, startIndex, nextIndex - 1)
	end
	return string.sub(reportText, startIndex)
end

local reportText = readReportText()
local output = {
	"# Cleanup Phase M Action Sections",
	"",
}

for _, title in ipairs(SECTION_TITLES) do
	table.insert(output, extractSection(reportText, title))
	table.insert(output, "")
end

log("Action sections extracted. Paste everything below back into Codex.")
print(table.concat(output, "\n"))
