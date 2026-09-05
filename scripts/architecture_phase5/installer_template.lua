-- Single Phase 5 entry point. Complete source replacement; no live text-anchor surgery.
local MODE="INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId==121304917315753,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local original=--[[ORIGINAL]]
local target=--[[TARGET]]
local extras={--[[EXTRAS]]}
local function find(path)
	local current=game
	for part in path:gmatch("[^%.]+") do
		local found
		for _,child in ipairs(current:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous "..path); found=child end end
		if not found then return end; current=found
	end
	return current
end
local owner=assert(find("ReplicatedStorage.Modules.Game.World.LODClient"),"Missing canonical LOD owner")
assert(owner:IsA("ModuleScript") and #owner:GetChildren()==0,"Unexpected LOD owner shape")
local installed=owner.Source==target
assert(installed or owner.Source==original,"LOD source drift: inspect/refresh before changing anything")
local function compile(source) local f,e=loadstring(source); assert(f,e) end
compile(original); compile(target)
for _,entry in ipairs(extras) do
	entry.item=find(entry.path)
	assert((entry.item~=nil)==installed,"Mixed installation or occupied destination: "..entry.path)
	if entry.source then compile(entry.source) end
	if installed then
		assert(entry.item.ClassName==entry.class and #entry.item:GetChildren()==0,"Extra shape changed")
		if entry.source then assert(entry.item.Source==entry.source,"Helper changed: "..entry.path) end
		for key,value in pairs(entry.attributes or {}) do assert(entry.item:GetAttribute(key)==value,"Restore default config before migration: "..key) end
	end
end
if MODE=="AUDIT" then return "PASS Phase 5 "..(installed and "installed" or "baseline") end
if MODE=="INSTALL" and installed or MODE=="ROLLBACK" and not installed then return "PASS Phase 5 already in requested state" end
local created,detached={},{}
local before=owner.Source
local ok,message=xpcall(function()
	if MODE=="INSTALL" then
		for _,entry in ipairs(extras) do
			local parentPath,name=entry.path:match("^(.*)%.([^%.]+)$")
			local parent=assert(find(parentPath),"Missing existing parent "..parentPath)
			local item=Instance.new(entry.class); table.insert(created,item); item.Name=name
			if entry.source then item.Source=entry.source end
			for key,value in pairs(entry.attributes or {}) do item:SetAttribute(key,value) end
			item.Parent=parent
		end
		owner.Source=target
	else
		owner.Source=original
		for _,entry in ipairs(extras) do table.insert(detached,{item=entry.item,parent=entry.item.Parent}); entry.item.Parent=nil end
	end
	assert(owner.Source==(MODE=="INSTALL" and target or original),"Source write did not persist")
end,debug.traceback)
if not ok then
	owner.Source=before
	for _,item in ipairs(created) do item:Destroy() end
	for _,entry in ipairs(detached) do entry.item.Parent=entry.parent end
	error("Phase 5 restored previous state: "..tostring(message))
end
for _,entry in ipairs(detached) do entry.item:Destroy() end
return "PASS Phase 5 "..MODE.."; test fresh Play and refresh mirror"
