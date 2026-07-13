-- Neo Tokyo Racers - Racing UI Phase 16B2A endlocal Parse Repair
-- Paste into Roblox Studio Command Bar in Edit mode.
-- Repairs only the malformed token boundary produced by the first 16B2 installer.

local PHASE="NTR Racing UI Phase 16B2A"
local StarterPlayer=game:GetService("StarterPlayer")
local function fail(m) error("["..PHASE.."] "..tostring(m),2) end
local root=StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("Racing")
local item=root:FindFirstChild("RaceSessionPresentationController_Active")
if not (item and item:IsA("LuaSourceContainer")) then fail("Missing RaceSessionPresentationController_Active") end
local source=item.Source
if not string.find(source,"NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT",1,true) then fail("Phase 16B2 marker missing; this repair does not apply") end
local repaired,count=string.gsub(source,"endlocal ","end\nlocal ")
if count==0 then
	if string.find(source,"NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR",1,true) then print("["..PHASE.."] Repair already installed.") return end
	fail("No endlocal boundary found. Refresh the mirror before another repair.")
end
repaired=repaired:gsub("%-%- NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT","-- NTR_RACING_UI_PHASE16B2_HUD_VISUAL_ALIGNMENT\n-- NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR",1)
item.Source=repaired
assert(not string.find(item.Source,"endlocal ",1,true),"Malformed endlocal boundary remains")
assert(string.find(item.Source,"NTR_RACING_UI_PHASE16B2A_ENDLOCAL_PARSE_REPAIR",1,true),"Repair marker missing")
print("["..PHASE.."] Repaired "..tostring(count).." malformed token boundary. Restart Play.")
