-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageRequestGuard")
-- Bounded validation before expensive compatibility/profile work.
local Guard = {}
local actions = {}
for action in string.gmatch("EnsureCustomisationAccess GetInitial SelectVehicleInstance BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty UpgradeGarageCapacity BuyCockpit BuyVehicleCosmetic SetVehicleCosmeticColor SetAllNeonColor SetCockpitColor BuyModule SetModuleColor UpgradeModule Upgrade BuyNeon SetThrustColor DespawnVehicle ExitVehicle ReEnterVehicle SpawnOwnedVehicleFromFreeRoam SpawnVehicle", "%S+") do actions[action]=true end
local colours = {SetVehicleCosmeticColor=true,SetAllNeonColor=true,SetCockpitColor=true,SetModuleColor=true,SetThrustColor=true}
local strings = {CategoryId=true,CockpitId=true,ModuleId=true,VehicleId=true,SlotId=true,ModuleInstanceId=true,PropertyId=true,CosmeticId=true,Channel=true,Scope=true,UpgradeId=true}
local booleans = {AllowReassign=true,ReturnProfile=true}
local function finite(n) return n==n and math.abs(n)<math.huge end

function Guard.new(clock)
	local states = setmetatable({}, {__mode="k"})
	local api = {}
	clock = clock or os.clock
	function api.check(player, action, args)
		if type(action)~="string" or not actions[action] then return false,"Unknown garage action." end
		if args~=nil and type(args)~="table" then return false,"Invalid request." end
		local count=0
		for key,value in pairs(args or {}) do
			count+=1
			if count>20 then return false,"Request too large." end
			if strings[key] then
				if type(value)~="string" or #value>240 then return false,"Invalid identifier." end
			elseif booleans[key] then
				if type(value)~="boolean" then return false,"Invalid option." end
			elseif key=="Color" then
				if typeof(value)~="Color3" then return false,"Invalid colour." end
				for _,n in ipairs({value.R,value.G,value.B}) do if not finite(n) or n<0 or n>1 then return false,"Invalid colour." end end
			else return false,"Unknown request field." end
		end
		local now=clock()
		local state=states[player]
		if not state then state={time=now,tokens=120}; states[player]=state end
		state.tokens=math.min(120,state.tokens+math.max(0,now-state.time)*60); state.time=now
		local cost=colours[action] and 1 or 6
		if state.tokens<cost then return false,"Please wait before trying again." end
		state.tokens-=cost
		return true
	end
	function api.forget(player) states[player]=nil end
	function api.run(player, action, args, callback)
		local allowed, message = api.check(player, action, args)
		if not allowed then return {Ok=false,Success=false,Message=message} end
		local state=states[player]
		if state.busy then return {Ok=false,Success=false,Message="A garage request is already running. Please try again."} end
		state.busy=true
		local ok,result=pcall(callback)
		state.busy=false
		if not ok then warn("[GarageRequestGuard] "..tostring(result)); return {Ok=false,Success=false,Message="Garage request unavailable. Please try again."} end
		return result
	end
	return api
end
return Guard
