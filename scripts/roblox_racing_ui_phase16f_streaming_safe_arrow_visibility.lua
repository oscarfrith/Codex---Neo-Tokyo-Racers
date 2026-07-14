-- Neo Tokyo Racers - Racing UI Phase 16F Streaming-Safe Arrow Visibility
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
-- Run INSTALL, restart Play, verify, then run SMOKE.

local MODE = "INSTALL" -- INSTALL or SMOKE
local PHASE = "NTR Racing UI Phase 16F"
local MARKER = "NTR_RACING_UI_PHASE16F_STREAMING_SAFE_ARROWS"

local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message) error("[" .. PHASE .. "] " .. tostring(message), 2) end
local function log(message) print("[" .. PHASE .. "] " .. tostring(message)) end
local function must(parent, name, className)
	local item = parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. parent:GetFullName() .. "." .. name)
	end
	return item
end
local function replaceRange(source, firstAnchor, nextAnchor, replacement, label)
	local first = string.find(source, firstAnchor, 1, true)
	if not first then fail("Could not find " .. label .. " start anchor. Refresh the Studio mirror before another source repair.") end
	local nextStart = string.find(source, nextAnchor, first + #firstAnchor, true)
	if not nextStart then fail("Could not find " .. label .. " end anchor. Refresh the Studio mirror before another source repair.") end
	return string.sub(source, 1, first - 1) .. replacement .. "\n\n" .. string.sub(source, nextStart)
end

local controllers = must(must(must(StarterPlayer, "StarterPlayerScripts"), "NeoTokyoRacersClient"), "Controllers")
local racing = must(controllers, "Racing")
local owner = must(racing, "RaceSessionAssetsClient_Active", "LuaSourceContainer")

local PART_CACHE_REPAIR = [==[
local function applyPart(record,visible)
	local item=record.Part
	if not item.Parent then return end
	item.LocalTransparencyModifier=visible and 0 or 1
	if visible then item.Transparency=record.Original end
	item.CanCollide=false item.CanTouch=false item.CanQuery=false
end

local function registerSegmentPart(segment,item)
	if not item:IsA("BasePart") or segment.PartSet[item] then return end
	segment.PartSet[item]=true
	local record={Part=item,Original=tonumber(item:GetAttribute("NTR_ArrowOriginalTransparency")) or 0}
	table.insert(segment.Parts,record)
	applyPart(record,segment.Visible==true)
end

local function segmentParts(segment)
	if segment.Parts then return segment.Parts end
	segment.Parts={}
	segment.PartSet=setmetatable({},{__mode="k"})
	for _,item in ipairs(segment.Folder:GetDescendants()) do registerSegmentPart(segment,item) end
	segment.DescendantAdded=segment.Folder.DescendantAdded:Connect(function(item)
		registerSegmentPart(segment,item)
	end)
	return segment.Parts
end

local function setSegmentVisible(segment,visible)
	segment.Visible=visible
	for _,record in ipairs(segmentParts(segment)) do applyPart(record,visible) end
end
]==]

local ROUTE_CACHE_REPAIR = [==[
local function routeCache(routeFolder)
	local cached=routeCaches[routeFolder]
	if cached and cached.ArrowRoot and cached.ArrowRoot.Parent then return cached end
	local arrowRoot=routeFolder and routeFolder:FindFirstChild("ArrowMarkers")
	if not arrowRoot then routeCaches[routeFolder]=nil return nil end
	cached={ArrowRoot=arrowRoot,ByIndex={},ByKey={},MaxFrom=0,Wraps=false,Behind=tonumber(arrowRoot:GetAttribute("SegmentWindowBehind")) or 1,Ahead=tonumber(arrowRoot:GetAttribute("SegmentWindowAhead")) or 1}
	local function registerSegment(child)
		local segment=parseSegmentFolder(child)
		if not segment or child:GetAttribute("Enabled")==false then return end
		cached.ByIndex[segment.From]=segment cached.ByKey[segment.Key]=segment
		if segment.From>cached.MaxFrom then cached.MaxFrom=segment.From end
		if segment.To==0 then cached.Wraps=true end
		segmentParts(segment)
	end
	for _,child in ipairs(arrowRoot:GetChildren()) do registerSegment(child) end
	cached.ChildAdded=arrowRoot.ChildAdded:Connect(function(child)
		registerSegment(child)
		activeSignature=nil
	end)
	cached.ChildRemoved=arrowRoot.ChildRemoved:Connect(function()
		routeCaches[routeFolder]=nil
		activeSignature=nil
	end)
	routeCaches[routeFolder]=cached
	return cached
end

local function normalizedRouteId(value)
	return string.lower((tostring(value or ""):gsub("[^%w]","")))
end

local function findRouteFolder(routes,routeId)
	if not routes then return nil end
	local exact=routes:FindFirstChild(tostring(routeId or ""))
	if exact then return exact end
	local wanted=normalizedRouteId(routeId)
	if wanted=="" then return nil end
	for _,candidate in ipairs(routes:GetChildren()) do
		if normalizedRouteId(candidate.Name)==wanted or normalizedRouteId(candidate:GetAttribute("RouteId"))==wanted then return candidate end
	end
	return nil
end
]==]

local HIDE_REPAIR = [==[
local function hideAllOnce()
	local routes=raceRoutesRoot()
	for _,routeFolder in ipairs(routes and routes:GetChildren() or {}) do
		local cached=routeCache(routeFolder)
		if cached then
			for _,segment in pairs(cached.ByKey) do setSegmentVisible(segment,false) end
			for _,item in ipairs(cached.ArrowRoot:GetChildren()) do
				if item:IsA("BasePart") then item.LocalTransparencyModifier=1 item.CanCollide=false item.CanTouch=false item.CanQuery=false end
			end
		end
	end
end
]==]

local function install()
	local source = owner.Source
	if string.find(source, MARKER, 1, true) then log("Already installed.") return end
	if not string.find(source, "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP", 1, true) then
		fail("Phase 16E runtime owner is not installed. Refresh the mirror and do not patch an older arrow controller.")
	end
	source = replaceRange(source, "local function segmentParts(segment)", "local function routeCache(routeFolder)", PART_CACHE_REPAIR, "streamed arrow-part cache")
	source = replaceRange(source, "local function routeCache(routeFolder)", "local function desiredSegments(cached,segmentIndex)", ROUTE_CACHE_REPAIR, "route cache")
	source = replaceRange(source, "local function hideAllOnce()", "local function participantSet(list)", HIDE_REPAIR, "initial arrow hide")
	local oldLookup = 'local routes=raceRoutesRoot() local routeFolder=routes and routes:FindFirstChild(state.RouteId)\n\tlocal cached=routeFolder and routeCache(routeFolder)\n\tif not (cached and cached.ArrowRoot) then clearVisible() activeSignature=signature return end'
	local newLookup = 'local routes=raceRoutesRoot() local routeFolder=findRouteFolder(routes,state.RouteId)\n\tlocal cached=routeFolder and routeCache(routeFolder)\n\tif not (cached and cached.ArrowRoot) then clearVisible() activeSignature=nil return end'
	local first,last=string.find(source,oldLookup,1,true)
	if not first then fail("Could not find active route lookup anchor. Refresh the Studio mirror before another source repair.") end
	source=string.sub(source,1,first-1)..newLookup..string.sub(source,last+1)
	owner.Source="-- "..MARKER.."\n"..source
	log("Installed streaming-safe local course-arrow visibility. Restart Play before testing.")
end

local function smoke()
	local source=owner.Source
	local checks={
		{MARKER,"Phase 16F marker"},
		{'segment.Folder.DescendantAdded:Connect',"late streamed arrow-part registration"},
		{'applyPart(record,segment.Visible==true)',"late part inherits current segment visibility"},
		{'findRouteFolder(routes,state.RouteId)',"normalized route resolution"},
		{'clearVisible() activeSignature=nil return',"missing streamed route retries"},
		{'NTR_ArrowOriginalTransparency")) or 0',"visible-transparency fallback"},
	}
	for _,check in ipairs(checks) do if not string.find(source,check[1],1,true) then fail("Smoke failed: missing "..check[2]) end end
	if string.find(source,'routes and routes:FindFirstChild(state.RouteId)',1,true) then fail("Smoke failed: fragile exact-only route lookup remains.") end
	log("SMOKE PASS: late-streamed local arrow parts are owned without broad polling or opponent markers.")
end

if MODE=="INSTALL" then install()
elseif MODE=="SMOKE" then smoke()
else fail("Unknown MODE "..tostring(MODE)) end
