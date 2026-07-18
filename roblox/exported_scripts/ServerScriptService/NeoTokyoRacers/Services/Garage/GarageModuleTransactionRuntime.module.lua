-- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
-- Pure profile transaction engine. Vehicle slot references are canonical;
-- EquippedVehicleId is derived and repaired from those references.
local Runtime={}

local function clone(value,seen)
	if typeof(value)~="table" then return value end
	seen=seen or {}; if seen[value] then return seen[value] end
	local copy={}; seen[value]=copy
	for key,child in pairs(value) do copy[clone(key,seen)]=clone(child,seen) end
	return copy
end

local function restore(target,snapshot)
	for key in pairs(target) do target[key]=nil end
	for key,value in pairs(snapshot) do target[key]=clone(value) end
end

local function references(profile)
	local result={}
	for vehicleIdValue,vehicle in pairs(profile.Vehicles or {}) do
		local vehicleId=tostring(vehicleIdValue)
		if typeof(vehicle)~="table" then return nil,"Invalid vehicle record "..vehicleId end
		vehicle.InstalledModules=typeof(vehicle.InstalledModules)=="table" and vehicle.InstalledModules or {}
		for slotIdValue,instanceIdValue in pairs(vehicle.InstalledModules) do
			local slotId=tostring(slotIdValue); local instanceId=tostring(instanceIdValue)
			if typeof((profile.OwnedModuleInstances or {})[instanceId])~="table" then return nil,"Missing instance "..instanceId.." referenced by "..vehicleId.."."..slotId end
			if result[instanceId] then return nil,"Instance "..instanceId.." is referenced by more than one slot" end
			result[instanceId]={VehicleId=vehicleId,SlotId=slotId}
		end
	end
	return result
end

local function reconcile(profile)
	local refs,message=references(profile); if not refs then return false,message end
	for instanceIdValue,instance in pairs(profile.OwnedModuleInstances or {}) do
		local instanceId=tostring(instanceIdValue); if typeof(instance)~="table" then return false,"Invalid module instance "..instanceId end
		local ref=refs[instanceId]; instance.EquippedVehicleId=ref and ref.VehicleId or nil
	end
	return true,refs
end

local function candidate(profile,refs,requestedId,vehicleId,slotId,hooks)
	local choices={}
	for instanceIdValue,instance in pairs(profile.OwnedModuleInstances or {}) do
		local instanceId=tostring(instanceIdValue)
		if instanceId~=requestedId and not refs[instanceId] then
			local fits,fitMessage=hooks.Fits(instance,vehicleId,slotId)
			if fits then table.insert(choices,{Id=instanceId,Instance=instance,Rating=tonumber(hooks.Rating(instance,vehicleId,slotId)) or math.huge})
			elseif fitMessage=="FATAL" then return nil,"Candidate compatibility audit failed for "..instanceId end
		end
	end
	table.sort(choices,function(a,b) if a.Rating~=b.Rating then return a.Rating<b.Rating end return a.Id<b.Id end)
	return choices[1]
end

local function internalEquip(profile,args,hooks)
	local owned=profile.OwnedModuleInstances or {}; local vehicles=profile.Vehicles or {}
	local requestedId=tostring(args.InstanceId or ""); local targetVehicleId=tostring(args.VehicleId or ""); local targetSlotId=tostring(args.SlotId or "")
	local requested=owned[requestedId]; local targetVehicle=vehicles[targetVehicleId]
	if typeof(requested)~="table" then return false,"Module instance not found." end
	if typeof(targetVehicle)~="table" then return false,"Vehicle instance not found." end
	local fits,fitMessage=hooks.Fits(requested,targetVehicleId,targetSlotId); if not fits then return false,fitMessage or "That module does not fit this slot." end

	local ok,refsOrMessage=reconcile(profile); if not ok then return false,refsOrMessage end
	local refs=refsOrMessage; local source=refs[requestedId]
	if source and source.VehicleId==targetVehicleId and source.SlotId==targetSlotId then return true,"Module instance already equipped.",{AlreadyEquipped=true} end
	if source and source.VehicleId~=targetVehicleId and args.AllowReassign~=true then return false,"That module copy is already installed on another vehicle." end

	targetVehicle.InstalledModules=typeof(targetVehicle.InstalledModules)=="table" and targetVehicle.InstalledModules or {}
	local displacedId=targetVehicle.InstalledModules[targetSlotId] and tostring(targetVehicle.InstalledModules[targetSlotId]) or nil
	if source then vehicles[source.VehicleId].InstalledModules[source.SlotId]=nil end
	if displacedId then targetVehicle.InstalledModules[targetSlotId]=nil end
	targetVehicle.InstalledModules[targetSlotId]=requestedId

	ok,refsOrMessage=reconcile(profile); if not ok then return false,refsOrMessage end; refs=refsOrMessage
	local report={MovedInstanceId=requestedId,FromVehicleId=source and source.VehicleId or nil,FromSlotId=source and source.SlotId or nil,ToVehicleId=targetVehicleId,ToSlotId=targetSlotId,DisplacedInstanceId=displacedId}
	if source and not (source.VehicleId==targetVehicleId and source.SlotId==targetSlotId) then
		local replacement,replacementError=candidate(profile,refs,requestedId,source.VehicleId,source.SlotId,hooks)
		if replacementError then return false,replacementError end
		if replacement then
			vehicles[source.VehicleId].InstalledModules[source.SlotId]=replacement.Id; report.BackfillInstanceId=replacement.Id
		elseif hooks.IsCoreSlot(profile,source.VehicleId,source.SlotId) then
			return false,"Cannot move this module because "..source.VehicleId.." has no compatible available replacement for "..source.SlotId.."."
		else report.OptionalSourceLeftEmpty=true end
	end

	ok,refsOrMessage=reconcile(profile); if not ok then return false,refsOrMessage end
	local afterOk,afterMessage=hooks.After(profile); if afterOk==false then return false,afterMessage or "Failed to refresh the equipped vehicle." end
	local valid,validationMessage=hooks.Validate(profile); if not valid then return false,"Post-transaction invariant failed: "..tostring(validationMessage) end
	return true,"Module instance equipped.",report
end

local function transact(profile,operation)
	local snapshot=clone(profile)
	local ok,success,message,report=xpcall(operation,debug.traceback)
	if not ok then restore(profile,snapshot); return false,"Transaction error: "..tostring(success) end
	if success~=true then restore(profile,snapshot); return false,message end
	return true,message,report
end

function Runtime.Equip(profile,args,hooks)
	return transact(profile,function() return internalEquip(profile,args,hooks) end)
end

function Runtime.BuyAndEquip(profile,args,hooks)
	return transact(profile,function()
		local instanceId=tostring(args.InstanceId or ""); if instanceId=="" then return false,"New module instance id missing." end
		profile.OwnedModuleInstances=typeof(profile.OwnedModuleInstances)=="table" and profile.OwnedModuleInstances or {}
		if profile.OwnedModuleInstances[instanceId]~=nil then return false,"New module instance id already exists." end
		local price=math.max(0,math.floor(tonumber(args.Price) or 0)); if (tonumber(profile.Cash) or 0)<price then return false,"Not enough cash." end
		profile.Cash=(tonumber(profile.Cash) or 0)-price
		profile.OwnedModules=typeof(profile.OwnedModules)=="table" and profile.OwnedModules or {}; profile.OwnedModules[tostring(args.Record.TemplateId)]=true
		profile.OwnedModuleInstances[instanceId]=clone(args.Record)
		local equipArgs={InstanceId=instanceId,VehicleId=args.VehicleId,SlotId=args.SlotId,AllowReassign=true}
		local success,message,report=internalEquip(profile,equipArgs,hooks); if not success then return false,message end
		report=report or {}; report.PurchasedInstanceId=instanceId; report.Price=price
		return true,"Module purchased and equipped.",report
	end)
end

return Runtime
