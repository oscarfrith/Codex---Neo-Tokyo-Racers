-- Pure distance policy. Defaults preserve the confirmed live bands, not historical docs.
local Policy={}
Policy.defaults={UpdateSeconds=0.5,Near1=200,Near2=800,Near3=1300,FarStart=2450,FarEnd=5000,Hysteresis=50,FoliageMin=1275,FoliageMax=2000}
function Policy.read(config)
	local values={}
	for key,fallback in pairs(Policy.defaults) do
		local value=config and config:GetAttribute(key)
		values[key]=type(value)=="number" and value==value and value<math.huge and value>=0 and value or fallback
	end
	assert(values.UpdateSeconds>=0.1 and values.UpdateSeconds<=10,"LOD UpdateSeconds must be 0.1–10")
	assert(values.Near1<=values.Near2 and values.Near2<=values.Near3 and values.Near3<values.FarStart and values.FarStart<values.FarEnd,"LOD distances must be ordered")
	assert(values.FoliageMin<=values.FoliageMax and values.Hysteresis<=values.FarStart,"Invalid LOD bands")
	return values
end
function Policy.near(distance,c)
	if distance<=c.Near1 then return 1 elseif distance<=c.Near2 then return 2 elseif distance<=c.Near3 then return 3 elseif distance<c.FarStart then return 4 else return 0 end
end
function Policy.visible(layer,state) return state~=0 and layer>=state and layer<=4 end
function Policy.foliage(distance,c) return distance>=c.FoliageMin and distance<=c.FoliageMax end
function Policy.far(distance,visible,c)
	local margin=visible and c.Hysteresis or 0
	return distance>=c.FarStart-margin and distance<=c.FarEnd+margin
end
return Policy
