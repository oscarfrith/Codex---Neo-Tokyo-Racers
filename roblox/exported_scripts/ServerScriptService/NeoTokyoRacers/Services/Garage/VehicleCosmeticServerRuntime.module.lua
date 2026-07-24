-- NTR_CUSTOMISATION_VEHICLE_COSMETIC_SERVER_RUNTIME_V1
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("VehicleCosmeticCatalog"))
local Runtime={}

local function clone(value) if typeof(value)~="table" then return value end; local result={}; for key,child in pairs(value) do result[key]=clone(child) end; return result end
local function current(profile)
	local id=tostring(profile and profile.CurrentVehicleId or "")
	local vehicle=id~="" and profile.Vehicles and profile.Vehicles[id]
	if typeof(vehicle)~="table" then return nil,nil,"Vehicle instance not found." end
	return vehicle,Catalog.NormalizeVehicle(vehicle)
end
local function restore(target,snapshot) for key in pairs(target) do target[key]=nil end; for key,value in pairs(snapshot) do target[key]=clone(value) end end

function Runtime.Ensure(profile)
	if typeof(profile)~="table" then return end
	for _,vehicle in pairs(typeof(profile.Vehicles)=="table" and profile.Vehicles or {}) do Catalog.NormalizeVehicle(vehicle) end
end

function Runtime.Purchase(profile,cosmeticId,cockpit)
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	local definition=Catalog.Get(cosmeticId)
	if not (definition and definition.Available) then return false,"Vehicle cosmetic is unavailable." end
	if cosmeticId=="Underglow" and not Catalog.HasUnderglowMount(cockpit) then return false,"Underglow is not supported by this vehicle." end
	if state.Unlocks[cosmeticId]==true then return true,"Vehicle cosmetic already unlocked." end
	local price=definition.Price
	if (tonumber(profile.Cash) or 0)<price then return false,"Not enough cash." end
	profile.Cash=(tonumber(profile.Cash) or 0)-price
	state.Unlocks[cosmeticId]=true
	if cosmeticId=="Underglow" then state.Colours.Underglow=state.Colours.Underglow or definition.DefaultColor end
	return true,"Vehicle cosmetic unlocked."
end

function Runtime.SetColour(profile,cosmeticId,colour,captureAll)
	if typeof(colour)~="Color3" then return false,"Invalid cosmetic colour." end
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	if state.Unlocks[cosmeticId]~=true then return false,"Purchase this vehicle cosmetic first." end
	if cosmeticId=="Underglow" then state.Colours.Underglow=colour; return true,"Underglow colour updated." end
	if cosmeticId~="ThrustColour" then return false,"Unknown vehicle cosmetic." end
	local snapshot={ThrustColor=profile.ThrustColor,VehicleThrust=vehicle.ThrustColor,ModuleColors=clone(profile.ModuleColors or {}),Instances=clone(profile.OwnedModuleInstances or {})}
	profile.ThrustColor=colour
	vehicle.ThrustColor=colour
	for slotId in pairs(profile.InstalledModules or {}) do profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId].ThrustColor=colour end
	local ok,result=typeof(captureAll)=="function" and captureAll() or true
	if not ok then
		profile.ThrustColor=snapshot.ThrustColor; vehicle.ThrustColor=snapshot.VehicleThrust
		restore(profile.ModuleColors,snapshot.ModuleColors); restore(profile.OwnedModuleInstances,snapshot.Instances)
		return false,tostring(result or "Thrust colour could not be captured.")
	end
	return true,"Thrust colour updated."
end

function Runtime.SetAllNeon(profile,colour,captureAll)
	if typeof(colour)~="Color3" then return false,"Invalid neon colour." end
	local vehicle,state,message=current(profile); if not vehicle then return false,message end
	local snapshot={Cockpit=clone(profile.CockpitColors or {}),VehicleCockpit=clone(vehicle.CockpitColors or {}),ModuleColors=clone(profile.ModuleColors or {}),Instances=clone(profile.OwnedModuleInstances or {}),Cosmetics=clone(vehicle.Cosmetics)}
	profile.CockpitColors=profile.CockpitColors or {}; profile.CockpitColors.Neon=colour
	vehicle.CockpitColors=clone(profile.CockpitColors)
	for slotId in pairs(profile.InstalledModules or {}) do
		if profile.NeonOwned and profile.NeonOwned[slotId]==true then profile.ModuleColors[slotId]=profile.ModuleColors[slotId] or {}; profile.ModuleColors[slotId].Neon=colour end
	end
	if state.Unlocks.Underglow==true then state.Colours.Underglow=colour end
	local ok,result=typeof(captureAll)=="function" and captureAll() or true
	if not ok then
		restore(profile.CockpitColors,snapshot.Cockpit); restore(vehicle.CockpitColors,snapshot.VehicleCockpit)
		restore(profile.ModuleColors,snapshot.ModuleColors); restore(profile.OwnedModuleInstances,snapshot.Instances); vehicle.Cosmetics=snapshot.Cosmetics
		return false,tostring(result or "Neon colour could not be captured.")
	end
	return true,"All owned neon updated."
end

return Runtime
