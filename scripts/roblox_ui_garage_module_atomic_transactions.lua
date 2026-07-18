-- Neo Tokyo Racers - Atomic physical module purchase/equip/reassignment
-- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.
-- This guarded installer adds one isolated transaction runtime and replaces only
-- the existing physical-copy buy/equip functions plus the canonical buy callback.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local function replaceRange(source, firstMarker, nextMarker, replacement, label)
	local first = string.find(source, firstMarker, 1, true)
	assert(first, "Missing source start anchor: " .. label)
	assert(not string.find(source, firstMarker, first + #firstMarker, true), "Duplicate source start anchor: " .. label)
	local nextAt = string.find(source, nextMarker, first + #firstMarker, true)
	assert(nextAt, "Missing source end anchor: " .. label)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, nextAt)
end

local services = need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local garage = need(services, "Garage", "Folder")
local server = need(garage, "GarageActionController_Shadow_Disabled", "Script")
local existingRuntime = garage:FindFirstChild("GarageModuleTransactionRuntime")
if existingRuntime then assert(existingRuntime:IsA("ModuleScript"), "GarageModuleTransactionRuntime exists with the wrong class") end

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local client = need(ui, "ModuleShopUIController", "ModuleScript")

assert(string.find(server.Source, "NTR_GARAGE_MODULE_REFERENCE_RECONCILE_V1", 1, true), "Canonical reference reconciliation baseline missing")
assert(string.find(server.Source, "NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1", 1, true), "Module-instance customisation authority baseline missing")
assert(string.find(client.Source, "NTR_GARAGE_MODULE_INSTANCE_READONLY_PREVIEW_V1", 1, true), "Read-only physical-copy preview baseline missing")

local runtimeSource = [==[
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
]==]
compile("GarageModuleTransactionRuntime", runtimeSource)

local serverSource = server.Source
if not string.find(serverSource, REVISION, 1, true) then
	serverSource = replaceOnce(serverSource,
		[[local V97_ModuleInstances = require(script.Parent:WaitForChild("GarageModuleInstanceCustomizationRuntime")) -- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1]],
		[[local V97_ModuleInstances = require(script.Parent:WaitForChild("GarageModuleInstanceCustomizationRuntime")) -- NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1
	local V98_ModuleTransactions = require(script.Parent:WaitForChild("GarageModuleTransactionRuntime")) -- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1]],
		"atomic transaction runtime require")

	local replacement = [==[
	-- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
	local function V98_vehicleModuleContext(profile, vehicleId, slotId)
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]
		if typeof(vehicle)~="table" then return nil,nil,nil,"Vehicle instance not found." end
		local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		local cockpit=cockpitInstance and V56_findCockpit(vehicle.CategoryId or profile.CurrentCategory,tostring(cockpitInstance.TemplateId or ""))
		local mount=cockpit and cockpit:FindFirstChild("SLOT_"..tostring(slotId),true)
		if not cockpit then return vehicle,nil,nil,"Cockpit template not found." end
		if not mount then return vehicle,cockpit,nil,"Slot not found on this cockpit." end
		return vehicle,cockpit,mount
	end

	local function V98_instanceFits(profile,instance,vehicleId,slotId)
		local vehicle,_,mount,contextMessage=V98_vehicleModuleContext(profile,vehicleId,slotId); if not mount then return false,contextMessage end
		local module=V56_findModule(vehicle.CategoryId or profile.CurrentCategory,tostring(instance and instance.TemplateId or "")); if not module then return false,"Module template not found." end
		local slotType=V56_string(mount,"ModuleType",V56_moduleTypeFromText(slotId)); local moduleType=V56_moduleTypeForModel(module)
		if slotType and slotType~="" and moduleType~=slotType then return false,"That module does not fit this slot." end
		if not V86_moduleFitsSlot(module,slotId,V56_string(mount,"AllowedModuleFolder","")) then return false,"That module does not fit this slot." end
		return true
	end

	local function V98_instanceRating(profile,instance,vehicleId)
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=tonumber(instance and instance[key]); if value then return value end end
		local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId or "")]; local categoryId=vehicle and vehicle.CategoryId or profile.CurrentCategory
		local module=V56_findModule(categoryId,tostring(instance and instance.TemplateId or "")); if not module then return math.huge end
		for _,key in ipairs({"Rating","PerformanceRating","PerformanceIndex","ModuleRating"}) do local value=V56_number(module,key,nil); if value then return value end end
		local sourceId,cockpit=V85_findSourceCockpit(profile,module); local sourceRating=cockpit and (V56_number(cockpit,"BaseRating",nil) or V56_number(cockpit,"PerformanceIndex",nil) or V56_number(cockpit,"Rating",nil))
		if not sourceRating then local tier=string.upper(tostring(cockpit and cockpit:GetAttribute("Tier") or "")); sourceRating=({E=1000,D=2000,C=3000,B=4000,A=5000,S=6000})[tier] or (sourceId and 7000 or 0) end
		return sourceRating+V85_moduleVariantOrder(module)
	end

	local function V98_coreSlotRequired(profile,vehicleId,slotId)
		if slotId=="Stabilisers" or slotId=="Boost" then return true end
		if slotId=="Engine1" or slotId=="Engine2" then
			local vehicle=profile.Vehicles and profile.Vehicles[tostring(vehicleId)]; local other=slotId=="Engine1" and "Engine2" or "Engine1"
			return not (vehicle and vehicle.InstalledModules and vehicle.InstalledModules[other])
		end
		return false
	end

	local function V98_afterModuleTransaction(profile)
		local current=profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; profile.InstalledModules={}
		for slotId,instanceId in pairs((current and current.InstalledModules) or {}) do local instance=profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)]; if typeof(instance)=="table" then profile.InstalledModules[slotId]=tostring(instance.TemplateId or "") end end
		return V97_ModuleInstances.HydrateAll(profile)
	end

	local function V98_transactionHooks(profile)
		return {
			Fits=function(instance,vehicleId,slotId) return V98_instanceFits(profile,instance,vehicleId,slotId) end,
			Rating=function(instance,vehicleId) return V98_instanceRating(profile,instance,vehicleId) end,
			IsCoreSlot=V98_coreSlotRequired,
			After=V98_afterModuleTransaction,
			Validate=function(value) return V97_ModuleInstances.Validate(value) end,
		}
	end

	local function V98_captureCurrentModuleState(profile)
		return V97_ModuleInstances.CaptureAll(profile,V77_ModuleUpgrades.GetLevels(profile._Player))
	end

	local function V84_buyModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; V84_ensureInstanceInventory(profile)
		local moduleId=tostring(args.ModuleId or ""); local vehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""); local slotId=tostring(args.SlotId or "")
		local module=V56_findModule(profile.CurrentCategory,moduleId); if not module then return false,"Module not found." end
		local lockMessage=V85_moduleLockedMessage(profile,module); if lockMessage then return false,lockMessage end
		local fits,fitMessage=V98_instanceFits(profile,{TemplateId=moduleId},vehicleId,slotId); if not fits then return false,fitMessage end
		local captured,captureMessage=V98_captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		local moduleInstanceId=V84_generateId("module")
		local record={TemplateId=moduleId,EquippedVehicleId=nil,UpgradeLevels={},V2UpgradePoints={},Colors={},NeonOwned=false,Source="BuyModuleInstance",AcquisitionKind="Purchase",AcquiredAtUnix=os.time()}
		return V98_ModuleTransactions.BuyAndEquip(profile,{InstanceId=moduleInstanceId,Record=record,Price=V85_modulePurchasePrice(module),VehicleId=vehicleId,SlotId=slotId},V98_transactionHooks(profile))
	end

	local function V84_equipModuleInstance(profile,args)
		args=typeof(args)=="table" and args or {}; V84_ensureInstanceInventory(profile)
		local captured,captureMessage=V98_captureCurrentModuleState(profile); if not captured then return false,captureMessage end
		return V98_ModuleTransactions.Equip(profile,{InstanceId=tostring(args.ModuleInstanceId or ""),VehicleId=tostring(args.VehicleId or profile.CurrentVehicleId or ""),SlotId=tostring(args.SlotId or ""),AllowReassign=args.AllowReassign==true},V98_transactionHooks(profile))
	end

]==]
	serverSource = replaceRange(serverSource, "\tlocal function V84_buyModuleInstance(profile, args)", "\t-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE", replacement, "canonical buy/equip function pair")
end
compile("GarageActionController_Shadow_Disabled", serverSource)

local clientSource = client.Source
if not string.find(clientSource, REVISION, 1, true) then
	local oldBuy = [[OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id}); if not buy.Success then message(buy.Message); return end; State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; buildPreview(); renderBuild(); message("Module purchased. Open Owned Modules to equip it.") end]]
	local newBuy = [=[OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if not buy.Success then message(buy.Message); return end; State.ModuleMode="Slots"; State.ModuleOptionMode=nil; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; buildPreview(); renderBuild(); message("Module purchased and equipped.") end -- NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1
]=]
	clientSource = replaceOnce(clientSource, oldBuy, newBuy, "canonical buy-and-auto-equip callback")
end
compile("ModuleShopUIController", clientSource)

local failures={}
local function expect(ok,message) if not ok then table.insert(failures,message) end end
expect(string.find(runtimeSource,"restore(profile,snapshot)",1,true)~=nil,"transaction rollback missing")
expect(string.find(runtimeSource,"hooks.IsCoreSlot",1,true)~=nil,"core-slot backfill gate missing")
expect(string.find(runtimeSource,"report.BackfillInstanceId",1,true)~=nil,"backfill reporting missing")
expect(string.find(runtimeSource,"profile.OwnedModuleInstances[instanceId]=clone(args.Record)",1,true)~=nil,"single-copy purchase creation missing")
expect(string.find(serverSource,"V98_ModuleTransactions.BuyAndEquip",1,true)~=nil,"server buy transaction bridge missing")
expect(string.find(serverSource,"V98_ModuleTransactions.Equip",1,true)~=nil,"server equip transaction bridge missing")
expect(string.find(clientSource,"Module purchased and equipped.",1,true)~=nil,"client auto-equip flow missing")
expect(not string.find(clientSource,"Open Owned Modules to equip it.",1,true),"old buy-without-equip flow remains")
if #failures>0 then error("[NTR Garage Atomic Transactions] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Garage Atomic Transactions] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldServerSource=server.Source; local oldClientSource=client.Source
local oldRuntimeSource=existingRuntime and existingRuntime.Source or nil; local created=false
local ok,err=xpcall(function()
	local runtime=existingRuntime
	if not runtime then runtime=Instance.new("ModuleScript"); runtime.Name="GarageModuleTransactionRuntime"; runtime.Parent=garage; created=true end
	runtime.Source=runtimeSource; server.Source=serverSource; client.Source=clientSource
	assert(runtime.Source==runtimeSource and server.Source==serverSource and client.Source==clientSource,"Source readback mismatch")
	print("[NTR Garage Atomic Transactions] INSTALL PASS")
	print("Restart Play. Buy a module and verify it equips immediately. Then move an in-use module and verify the old vehicle receives the lowest-rated compatible available copy, or the whole action is rejected without changing cash/inventory when a required slot cannot be backfilled.")
end,debug.traceback)
if not ok then
	pcall(function() server.Source=oldServerSource end); pcall(function() client.Source=oldClientSource end)
	if created then pcall(function() garage.GarageModuleTransactionRuntime:Destroy() end) elseif existingRuntime and oldRuntimeSource then pcall(function() existingRuntime.Source=oldRuntimeSource end) end
	error("[NTR Garage Atomic Transactions] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
