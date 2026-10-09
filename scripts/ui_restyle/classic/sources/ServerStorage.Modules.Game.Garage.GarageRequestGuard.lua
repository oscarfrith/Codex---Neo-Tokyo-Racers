-- Canonical feature implementation; startup is owned by the composition root.
-- Bounded validation before expensive compatibility/profile work. Limits and messages are unchanged;
-- the shared Core.Net guard now owns rate limiting, busy locking, failure isolation and counters.
local Net = require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("Net"))
local Guard = {}
local actions = {}
for action in string.gmatch("EnsureCustomisationAccess GetInitial SelectVehicleInstance BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty BuyVehicleCosmetic SetVehicleCosmeticColor SetAllNeonColor SetCockpitColor SetModuleColor UpgradeModule Upgrade BuyNeon DespawnVehicle ExitVehicle SpawnOwnedVehicleFromFreeRoam SpawnVehicle", "%S+") do actions[action]=true end
-- Retired (architecture P9, no client caller): BuyCockpit, BuyModule, SetThrustColor, ReEnterVehicle, UpgradeGarageCapacity.
local colours = {SetVehicleCosmeticColor=true,SetAllNeonColor=true,SetCockpitColor=true,SetModuleColor=true}
local strings = {CategoryId=true,CockpitId=true,ModuleId=true,VehicleId=true,SlotId=true,ModuleInstanceId=true,PropertyId=true,CosmeticId=true,Channel=true,Scope=true,UpgradeId=true}
local booleans = {AllowReassign=true,ReturnProfile=true}
local function finite(n) return n==n and math.abs(n)<math.huge end

local function validate(_, action, args)
	if args~=nil and type(args)~="table" then return false,"Invalid request." end
	local count=0
	for key,value in pairs(args or {}) do
		count+=1
		if count>20 then return false,"Request too large." end
		if key=="KnownCatalogRevision" then
			if action~="GetInitial" or type(value)~="string" or #value>64 then return false,"Invalid catalogue revision." end
		elseif strings[key] then
			if type(value)~="string" or #value>240 then return false,"Invalid identifier." end
		elseif booleans[key] then
			if type(value)~="boolean" then return false,"Invalid option." end
		elseif key=="Color" then
			if typeof(value)~="Color3" then return false,"Invalid colour." end
			for _,n in ipairs({value.R,value.G,value.B}) do if not finite(n) or n<0 or n>1 then return false,"Invalid colour." end end
		else return false,"Unknown request field." end
	end
	return true
end

function Guard.new(clock)
	local guard = Net.guard({
		name="GarageInvoke", actions=actions, check=validate, capacity=120, refill=60,
		cost=function(action) return colours[action] and 1 or 6 end, busy=true, warnPrefix="[GarageRequestGuard]",
		messages={unknown="Unknown garage action.", rate="Please wait before trying again.",
			busy="A garage request is already running. Please try again.", failed="Garage request unavailable. Please try again."},
	}, clock)
	local api = {}
	api.check = guard.check
	api.forget = guard.forget
	function api.run(player, action, args, callback)
		local rejected, result = guard.run(player, action, args, callback)
		if rejected then return {Ok=false,Success=false,Message=result} end
		return result
	end
	return api
end
return Guard
