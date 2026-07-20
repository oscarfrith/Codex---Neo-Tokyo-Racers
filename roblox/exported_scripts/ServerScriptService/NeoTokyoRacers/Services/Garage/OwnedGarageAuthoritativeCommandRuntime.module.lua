-- NTR_OWNED_GARAGE_AUTHORITATIVE_COMMAND_RUNTIME_V1
-- NTR_OWNED_GARAGE_STRUCTURE_COMMAND_V1
-- NTR_OWNED_GARAGE_DECORATION_COMMAND_V1
-- NTR_OWNED_GARAGE_LIGHTING_COMMAND_V1
-- NTR_OWNED_GARAGE_ACCESS_INVITATIONS_COMMAND_V1
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Assignment=require(script.Parent:WaitForChild("OwnedGarageDisplayAssignmentRuntime"))
local Runtime={ApiVersion=1}
local ALLOWED={Assign=true,Clear=true,SetActive=true,SetSurfaceStyle=true,SetAccessMode=true,ConfigureStructure=true,ConfigureDecoration=true,ConfigureLighting=true,SetInvitation=true}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
local function equal(a,b,seen)
	if type(a)~="table" or type(b)~="table" then return a==b end; seen=seen or {}; if seen[a]==b then return true end; seen[a]=b
	for key,value in pairs(a) do if not equal(value,b[key],seen) then return false end end
	for key in pairs(b) do if a[key]==nil then return false end end; return true
end
local function response(success,message,operation,baseRevision,revision,extra)
	local result={Success=success==true,Message=tostring(message or ""),Operation=tostring(operation or ""),BaseRevision=baseRevision,Revision=revision,ApiVersion=Runtime.ApiVersion}
	for key,value in pairs(type(extra)=="table" and extra or {}) do result[key]=value end; return result
end
local function dirty(commit,reason) if type(commit)~="function" then return false,"Dirty owner missing." end; return commit(reason) end
function Runtime.Execute(player,profile,command,commit)
	if type(profile)~="table" then return response(false,"Profile is not loaded.","",nil,0) end; command=type(command)=="table" and command or {}; local operation=tostring(command.Operation or ""); local current=math.max(0,math.floor(tonumber(profile.OwnedGarage and profile.OwnedGarage.Revision) or 0))
	if operation=="Ensure" then
		local before=clone(profile.OwnedGarage); local reset=command.Reset==true; local garage=Profile.Ensure(profile,reset); if reset then garage.TesterResetToken=tostring(command.ResetToken or "") end; local changed=not equal(before,garage)
		if changed then garage.Revision=current+1; local valid,message=Profile.Validate(profile); if not valid then if type(before)=="table" then Profile.Restore(profile,before) else profile.OwnedGarage=nil end; return response(false,message,operation,current,current) end; local marked,markMessage=dirty(commit,reset and "OwnedGarageTesterReset" or "OwnedGarageEnsure"); if not marked then if type(before)=="table" then Profile.Restore(profile,before) else profile.OwnedGarage=nil end; return response(false,markMessage,operation,current,current) end end
		return response(true,changed and "Owned garage state normalised." or "Owned garage state current.",operation,current,garage.Revision,{Changed=changed,ResetApplied=reset and changed,State=Profile.State(profile)})
	elseif operation=="Restore" then
		local baseRevision=tonumber(command.BaseRevision); if baseRevision~=current then return response(false,"Garage changed before compensation could complete.",operation,baseRevision,current,{Conflict=true}) end; if type(command.State)~="table" then return response(false,"Compensation state is missing.",operation,baseRevision,current) end
		local before=Profile.Snapshot(profile); local restored=clone(command.State); restored.Revision=current+1; Profile.Restore(profile,restored); local valid,message=Profile.Validate(profile); if not valid then Profile.Restore(profile,before); return response(false,message,operation,baseRevision,current) end; local marked,markMessage=dirty(commit,tostring(command.Reason or "OwnedGarageCompensation")); if not marked then Profile.Restore(profile,before); return response(false,markMessage,operation,baseRevision,current) end
		return response(true,"Owned garage compensation committed.",operation,baseRevision,current+1,{State=Profile.State(profile),Compensated=true})
	elseif not ALLOWED[operation] then return response(false,"Command not allowed.",operation,command.BaseRevision,current) end
	local args=type(command.Args)=="table" and command.Args or {}; args.BaseRevision=command.BaseRevision
	return Assignment.Apply(player,profile,tostring(command.RequestId or ""),operation,args,function() return dirty(commit,tostring(command.Reason or ("OwnedGarageCommand:"..operation))) end)
end
function Runtime.ForgetPlayer(player) Assignment.ForgetPlayer(player) end
return Runtime
