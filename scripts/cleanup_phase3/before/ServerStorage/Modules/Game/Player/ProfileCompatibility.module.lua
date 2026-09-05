-- In-memory garage fields attached to the one ProfileServer session table.
-- No cache, DataStore, remotes, startup or independent inventory owner.
local Compatibility = {}
local transient={}
for name in string.gmatch("_Player CurrentCategory CurrentCockpit OwnedCockpits CockpitColors ThrustColor OwnedModules InstalledModules ModuleColors NeonOwned UpgradeLevels GarageCapacity OwnedGarageProperties GarageProperties GarageDisplaySpaces ModuleUpgradeLevels", "%S+") do transient[name]=true end
function Compatibility.attach(profile, view)
	for key in pairs(transient) do if view[key]~=nil then profile[key]=view[key] end end
	if not profile.CurrentVehicleId then profile.CurrentVehicleId=view.CurrentVehicleId end
	return profile
end
function Compatibility.persistent(profile)
	local data={}
	for key,value in pairs(profile) do if not transient[key] then data[key]=value end end
	return data
end
function Compatibility.commit(profile)
	local garage=profile.Garage
	local vehicles,cockpits=0,0
	for _ in pairs(profile.Vehicles or {}) do vehicles+=1 end
	for _ in pairs(profile.OwnedCockpits or {}) do cockpits+=1 end
	garage.Capacity=math.max(2,tonumber(profile.GarageCapacity) or 2,vehicles,cockpits)
	garage.OwnedGarageProperties=profile.OwnedGarageProperties or garage.OwnedGarageProperties
	-- Preserve the existing mapper's missing-display-slot initialisation.
	local i=0
	for id in pairs(profile.Vehicles or {}) do
		i+=1; local key="Space"..i
		garage.DisplaySpaces[key]=garage.DisplaySpaces[key] or {}
		garage.DisplaySpaces[key].VehicleId=garage.DisplaySpaces[key].VehicleId or id
	end
end
return Compatibility
