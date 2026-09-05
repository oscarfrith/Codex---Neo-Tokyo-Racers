-- NTR_SMALL_REFINEMENTS_SHARED_PRESENTATION_V1
-- Player-facing vehicle names only. Stable category/cockpit IDs remain unchanged.
local M={}

local function titleWords(value)
	local text=string.gsub(tostring(value or ""),"_"," ")
	text=string.gsub(text,"%s+"," ")
	text=string.gsub(text,"^%s+","")
	text=string.gsub(text,"%s+$","")
	return string.gsub(string.lower(text),"(%a)([%w']*)",function(first,rest) return string.upper(first)..rest end)
end

local function cockpitIdFrom(profile,vehicle)
	if type(vehicle)~="table" then return "" end
	local cockpitId=tostring(vehicle.CockpitId or "")
	if cockpitId=="" and vehicle.CockpitInstanceId and type(profile)=="table" and type(profile.OwnedCockpitInstances)=="table" then
		local instance=profile.OwnedCockpitInstances[tostring(vehicle.CockpitInstanceId)]
		cockpitId=tostring(type(instance)=="table" and instance.TemplateId or "")
	end
	return cockpitId
end

function M.FindCockpit(categoriesRoot,cockpitId)
	if not categoriesRoot then return nil,nil end
	local wanted=string.lower(tostring(cockpitId or ""))
	if wanted=="" then return nil,nil end
	for _,category in ipairs(categoriesRoot:GetChildren()) do
		for _,item in ipairs(category:GetDescendants()) do
			if item:IsA("Model") then
				local id=string.lower(tostring(item:GetAttribute("CockpitId") or item:GetAttribute("TemplateId") or item.Name))
				local compact=string.gsub(id,"^cockpit_","")
				if id==wanted or compact==wanted then return item,category end
			end
		end
	end
	return nil,nil
end

function M.CockpitName(categoriesRoot,cockpitId)
	local cockpit=M.FindCockpit(categoriesRoot,cockpitId)
	local display=cockpit and cockpit:GetAttribute("DisplayName")
	if display~=nil and tostring(display)~="" then return titleWords(display) end
	return titleWords(cockpitId~="" and cockpitId or "Vehicle")
end

function M.CategoryName(categoriesRoot,categoryId,cockpitId)
	local _,category=M.FindCockpit(categoriesRoot,cockpitId)
	if not category and categoriesRoot then
		local wanted=string.lower(tostring(categoryId or ""))
		for _,candidate in ipairs(categoriesRoot:GetChildren()) do
			if string.lower(candidate.Name)==wanted then category=candidate; break end
		end
		-- "bruiser" is a stable legacy data ID; PIERCER is its current player-facing asset family.
		if not category and wanted=="bruiser" then category=categoriesRoot:FindFirstChild("PIERCER") end
	end
	local display=category and category:GetAttribute("DisplayName")
	return titleWords(display~=nil and tostring(display)~="" and display or (category and category.Name or categoryId or "Other"))
end

function M.FullVehicleName(profile,vehicleId,categoriesRoot)
	local vehicle=type(profile)=="table" and type(profile.Vehicles)=="table" and profile.Vehicles[tostring(vehicleId or "")] or nil
	if type(vehicle)~="table" then return titleWords(vehicleId~="" and vehicleId or "Vehicle") end
	local cockpitId=cockpitIdFrom(profile,vehicle)
	local cockpit=M.CockpitName(categoriesRoot,cockpitId)
	local category=M.CategoryName(categoriesRoot,vehicle.CategoryId or vehicle.Category,cockpitId)
	if string.lower(string.sub(cockpit,1,#category))==string.lower(category) then return cockpit end
	return category~="" and (category.." "..cockpit) or cockpit
end

return M
