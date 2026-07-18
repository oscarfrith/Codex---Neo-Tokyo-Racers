-- NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1
-- Pure client-side projection for browser previews. It never changes ownership or calls the server.
local Resolver={}

local function clone(value,active)
	if typeof(value)~="table" then return value end
	active=active or {}; if active[value] then return active[value] end
	local copy={}; active[value]=copy
	for key,child in pairs(value) do copy[clone(key,active)]=clone(child,active) end
	return copy
end
local function byText(dictionary,key)
	if typeof(dictionary)~="table" or key==nil then return nil end
	local direct=dictionary[key] or dictionary[tostring(key)]; if direct~=nil then return direct end
	for id,item in pairs(dictionary) do if tostring(id)==tostring(key) then return item end end
end
local function defaultColours(cockpit)
	cockpit=cockpit or {}
	return {
		Primary=cockpit.DefaultPrimaryColor or Color3.fromRGB(0,205,230),
		Secondary=cockpit.DefaultSecondaryColor or Color3.fromRGB(235,247,204),
		Detail=cockpit.DefaultDetailColor or Color3.fromRGB(38,44,50),
		Neon=cockpit.DefaultNeonColor or Color3.fromRGB(255,255,255),
		FrontLights=cockpit.DefaultFrontLightsColor or Color3.fromRGB(252,250,255),
		RearLights=cockpit.DefaultRearLightsColor or Color3.fromRGB(255,116,116),
	}
end
local function defaultModules(cockpit)
	cockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId
	return {
		Engine1=engine,
		Engine2=cockpit.DefaultRearEngineModuleId or cockpit.DefaultEngineBModuleId or engine,
		Stabilisers=cockpit.DefaultStabilisersModuleId or cockpit.DefaultStabiliserModuleId,
		Boost=cockpit.DefaultBoostModuleId,
	}
end
local function cleanModules(source)
	local result={}; for slotId,moduleId in pairs(source or {}) do if moduleId~=nil and tostring(moduleId)~="" then result[slotId]=tostring(moduleId) end end; return result
end

function Resolver.Factory(state,row)
	local cockpit=row and row.Cockpit or {}; local colours=defaultColours(cockpit); local installed=cleanModules(defaultModules(cockpit)); local moduleColours={}
	for slotId in pairs(installed) do moduleColours[slotId]={Primary=colours.Primary,Secondary=colours.Secondary,Detail=colours.Detail,Neon=Color3.fromRGB(255,255,255)} end
	return {
		PreviewKind="Factory",CurrentCategory=row and row.CategoryId or state.CategoryId,CurrentCockpit=row and row.CockpitId or cockpit.CockpitId,CurrentVehicleId=nil,
		CockpitColors=colours,ThrustColor=Color3.fromRGB(255,255,255),InstalledModules=installed,ModuleColors=moduleColours,NeonOwned={},Vehicles={},OwnedModuleInstances={},
		Performance=row and row.Performance or nil,
	}
end

function Resolver.Owned(state,row)
	local source=state.Profile or {}; local vehicleId=row and row.VehicleId; local vehicle=byText(source.Vehicles,vehicleId)
	if typeof(vehicle)~="table" then return Resolver.Factory(state,row) end
	local cockpitColours=defaultColours(row and row.Cockpit); for channel,color in pairs(vehicle.CockpitColors or {}) do cockpitColours[channel]=color end
	local installed={}; local moduleColours={}; local neon={}; local levels={}
	for slotId,instanceId in pairs(vehicle.InstalledModules or {}) do
		local instance=byText(source.OwnedModuleInstances,instanceId)
		if typeof(instance)=="table" and instance.TemplateId then
			installed[slotId]=tostring(instance.TemplateId); moduleColours[slotId]=clone(instance.Colors or {}); neon[slotId]=instance.NeonOwned==true; levels[tostring(instance.TemplateId)]=clone(instance.UpgradeLevels or {})
		end
	end
	return {
		PreviewKind="OwnedVehicle",CurrentCategory=vehicle.CategoryId or (row and row.CategoryId) or state.CategoryId,CurrentCockpit=row and row.CockpitId,CurrentVehicleId=tostring(vehicleId),
		CockpitColors=cockpitColours,ThrustColor=vehicle.ThrustColor or Color3.fromRGB(255,255,255),InstalledModules=installed,ModuleColors=moduleColours,NeonOwned=neon,
		Vehicles=source.Vehicles,OwnedModuleInstances=source.OwnedModuleInstances,ModuleUpgradeLevels=levels,Performance=row and row.Performance or nil,
	}
end

function Resolver.ForBrowser(state,row)
	if state and state.ShopMode=="Customisation" and row and row.VehicleId then return Resolver.Owned(state,row) end
	return Resolver.Factory(state,row)
end

return Resolver
