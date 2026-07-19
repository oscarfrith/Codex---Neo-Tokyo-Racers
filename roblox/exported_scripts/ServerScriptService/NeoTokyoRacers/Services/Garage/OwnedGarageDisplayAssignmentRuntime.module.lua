-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V1
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Runtime={}
local locks=setmetatable({},{__mode="k"}); local completed=setmetatable({},{__mode="k"})
function Runtime.Apply(player,profile,requestId,operation,args,commit)
	if locks[player] then return {Success=false,Message="Garage request already in progress."} end
	requestId=tostring(requestId or ""); if requestId=="" then return {Success=false,Message="Request id required."} end
	completed[player]=completed[player] or {}; if completed[player][requestId] then return completed[player][requestId] end
	local before=Profile.Snapshot(profile); locks[player]=true
	local ok,result=pcall(function()
		local success,message
		if operation=="Assign" then success,message=Profile.Assign(profile,args)
		elseif operation=="Clear" then success,message=Profile.Clear(profile,args)
		elseif operation=="SetActive" then success,message=Profile.SetActive(profile,args and args.GarageId)
		elseif operation=="SetSurfaceStyle" then success,message=Profile.SetSurfaceStyle(profile,args)
		elseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)
		else success,message=false,"Unknown garage operation." end
		if not success then error(message) end
		local valid,validation=Profile.Validate(profile); if not valid then error(validation) end
		if type(commit)=="function" then local committed,commitMessage=commit(); if committed~=true then error(commitMessage or "Profile commit failed.") end end
		return {Success=true,Message=message,State=Profile.State(profile)}
	end)
	if not ok then Profile.Restore(profile,before); result={Success=false,Message=tostring(result)} end
	locks[player]=nil; completed[player][requestId]=result
	local count=0; for _ in pairs(completed[player]) do count+=1 end; if count>64 then completed[player]={ [requestId]=result } end
	return result
end
function Runtime.Validate(profile) return Profile.Validate(profile) end
return Runtime
