-- NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1
-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
local ViewModel={}
local variantOrder={Standard=1,Lightweight=2,Power=3}
local stateOrder={Equipped=1,Available=2,InUse=3}

function ViewModel.Variant(module)
	local explicit=tostring(module and module.VariantName or "")
	if explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end
	local name=string.lower(tostring(module and (module.DisplayName or module.ModuleId) or ""))
	if string.find(name,"lightweight",1,true) then return "Lightweight" end
	if string.find(name,"power",1,true) then return "Power" end
	return "Standard"
end

function ViewModel.Rating(module,instance,resolver) -- NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1
	if typeof(resolver)=="function" then local ok,value=pcall(resolver,module,instance); if ok and tonumber(value) then return math.floor(tonumber(value)) end end
	return math.floor(tonumber(instance and (instance.Rating or instance.PerformanceRating or instance.PerformanceIndex)) or tonumber(module and (module.Rating or module.PerformanceRating or module.PerformanceIndex)) or 0)
end

function ViewModel.Owned(context)
	local rows={}
	for instanceId,item in pairs(context.Instances or {}) do
		local module=context.ResolveModule(item.TemplateId)
		if module and context.Fits(module,context.Slot) then
			local owner=tostring(item.EquippedVehicleId or ""); local state,status
			if tostring(instanceId)==tostring(context.InstalledInstanceId or "") then state,status="Equipped","EQUIPPED"
			elseif owner~="" and owner~=tostring(context.CurrentVehicleId or "") then state,status="InUse","IN USE BY "..string.upper(context.VehicleName(owner))
			else state,status="Available","AVAILABLE" end
			table.insert(rows,{Id=tostring(instanceId),Module=module,Item=item,State=state,Status=status,Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,item,context.Rating),OwnerVehicleId=owner})
		end
	end
	table.sort(rows,function(a,b)
		local aState=stateOrder[a.State] or 99; local bState=stateOrder[b.State] or 99
		if aState~=bState then return aState<bState end
		if a.Rating~=b.Rating then return a.Rating>b.Rating end
		if a.VehicleName~=b.VehicleName then return a.VehicleName<b.VehicleName end
		if variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end
		return a.Id<b.Id
	end)
	return rows
end

function ViewModel.Shop(context)
	local rows={}
	for _,module in ipairs(context.Modules or {}) do
		local locked=context.IsLocked(module)
		table.insert(rows,{Id=tostring(module.ModuleId),Module=module,State=locked and "Locked" or "Shop",Status=locked and ("BUY "..string.upper(context.SourceVehicleName(module)).." TO UNLOCK") or ("OWNED x"..tostring(context.OwnedCount(module.ModuleId))),Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,nil,context.Rating),SourceRating=context.SourceRating(module),Locked=locked,Price=tonumber(module.Price) or 0})
	end
	table.sort(rows,function(a,b)
		if a.Locked~=b.Locked then return not a.Locked end
		if a.SourceRating~=b.SourceRating then return a.SourceRating<b.SourceRating end
		if a.VehicleName~=b.VehicleName then return a.VehicleName<b.VehicleName end
		if variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end
		return a.Id<b.Id
	end)
	return rows
end

return ViewModel
