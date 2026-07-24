-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V1
-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED
-- NTR_OWNED_GARAGE_STRUCTURE_TRANSACTION_V1
-- NTR_OWNED_GARAGE_DECORATION_TRANSACTION_V1
-- NTR_OWNED_GARAGE_LIGHTING_TRANSACTION_V1
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_TRANSACTION_V1
-- NTR_OWNED_GARAGE_FINISH_TRANSACTION_V1
-- NTR_OWNED_GARAGE_PHASE13_V1_1_ATTRIBUTE_PLATFORM_TRANSACTION
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Runtime={ApiVersion=2}
local locks=setmetatable({},{__mode="k"}); local completed=setmetatable({},{__mode="k"})
local function revision(profile) return math.max(0,math.floor(tonumber(profile and profile.OwnedGarage and profile.OwnedGarage.Revision) or 0)) end
local function stable(value)
	if type(value)~="table" then return tostring(value) end; local keys={}; for key in pairs(value) do table.insert(keys,tostring(key)) end; table.sort(keys); local parts={}; for _,key in ipairs(keys) do local raw=value[key] if raw==nil then raw=value[tonumber(key)] end; table.insert(parts,key.."="..stable(raw)) end; return "{"..table.concat(parts,",").."}"
end
local function fingerprint(operation,args)
	return table.concat({tostring(operation or ""),tostring(args.GarageId or ""),tostring(args.SlotId or args.AnchorId or ""),tostring(args.VehicleId or ""),tostring(args.SurfaceGroup or ""),tostring(args.StyleId or ""),tostring(args.AccessMode or ""),tostring(args.SectionId or ""),tostring(args.Action or ""),tostring(args.Channel or ""),tostring(args.Material or ""),stable(args.Color),tostring(args.ItemId or ""),tostring(args.PresetId or ""),tostring(args.Intensity or ""),tostring(args.TargetUserId or ""),tostring(args.MaxInvites or ""),stable(args.Colors),stable(args.Materials)},"|")
end
local function response(success,message,requestId,baseRevision,currentRevision,extra)
	local result={Success=success==true,Message=tostring(message or ""),RequestId=tostring(requestId or ""),BaseRevision=baseRevision,Revision=currentRevision,ApiVersion=Runtime.ApiVersion}
	for key,value in pairs(type(extra)=="table" and extra or {}) do result[key]=value end
	return result
end
function Runtime.Apply(player,profile,requestId,operation,args,commit)
	requestId=tostring(requestId or ""); args=type(args)=="table" and args or {}; local currentRevision=revision(profile); local baseRevision=tonumber(args.BaseRevision)
	local requestFingerprint=fingerprint(operation,args)
	if locks[player] then return response(false,"Garage request already in progress.",requestId,baseRevision,currentRevision,{Busy=true}) end
	if requestId=="" then return response(false,"Request id required.",requestId,baseRevision,currentRevision) end
	completed[player]=completed[player] or {}
	local previous=completed[player][requestId]
	if previous then
		if previous.Fingerprint~=requestFingerprint or previous.BaseRevision~=baseRevision then return response(false,"Request id was already used for a different garage mutation.",requestId,baseRevision,currentRevision,{RequestIdConflict=true}) end
		local replay={}; for key,value in pairs(previous.Result) do replay[key]=value end; replay.Replayed=true; return replay
	end
	if baseRevision~=nil and baseRevision~=currentRevision then
		local conflict=response(false,"Garage changed while this menu was open. The latest state has been loaded.",requestId,baseRevision,currentRevision,{Conflict=true,CurrentRevision=currentRevision})
		completed[player][requestId]={Fingerprint=requestFingerprint,BaseRevision=baseRevision,Result=conflict}; return conflict
	end
	local before=Profile.Snapshot(profile); locks[player]=true
	local ok,result=pcall(function()
		local success,message
		if operation=="Assign" then success,message=Profile.Assign(profile,args)
		elseif operation=="Clear" then success,message=Profile.Clear(profile,args)
		elseif operation=="SetActive" then success,message=Profile.SetActive(profile,args and args.GarageId)
		elseif operation=="SetSurfaceStyle" then success,message=Profile.SetSurfaceStyle(profile,args)
		elseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)
		elseif operation=="SetInvitation" then success,message=Profile.SetInvitation(profile,args)
		elseif operation=="ConfigureStructure" then success,message=Profile.ConfigureStructure(profile,args)
		elseif operation=="ConfigureDecoration" then success,message=Profile.ConfigureDecoration(profile,args)
		elseif operation=="ConfigureLighting" then success,message=Profile.ConfigureLighting(profile,args)
		else success,message=false,"Unknown garage operation." end
		if not success then error(message) end
		local valid,validation=Profile.Validate(profile); if not valid then error(validation) end
		if type(commit)=="function" then local committed,commitMessage=commit(); if committed~=true then error(commitMessage or "Profile commit failed.") end end
		return response(true,message,requestId,baseRevision,revision(profile),{State=Profile.State(profile)})
	end)
	if not ok then Profile.Restore(profile,before); result=response(false,tostring(result),requestId,baseRevision,revision(profile)) end
	locks[player]=nil; completed[player][requestId]={Fingerprint=requestFingerprint,BaseRevision=baseRevision,Result=result}
	local count=0; for _ in pairs(completed[player]) do count+=1 end; if count>64 then completed[player]={[requestId]=completed[player][requestId]} end
	return result
end
function Runtime.ForgetPlayer(player) locks[player]=nil; completed[player]=nil end
function Runtime.Validate(profile) return Profile.Validate(profile) end
return Runtime
