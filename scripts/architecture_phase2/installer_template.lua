-- Canonical Phase 2 installer. Run in Edit mode. Change MODE only for audit/rollback.
local MODE = "INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId == 121304917315753, "Wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK", "Unknown mode")
local edits = {--[[EDITS]]}
local modules = {--[[MODULES]]}
local function find(path)
	local item=game
	for part in path:gmatch("[^%.]+") do
		local found
		for _,child in ipairs(item:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous path "..path); found=child end end
		assert(found,"Missing "..path); item=found
	end
	return item
end
local function hash(s) local h=0 for i=1,#s do h=(h*31+s:byte(i))%4294967296 end return h end
local function replace(s,a,b)
	local first,last=s:find(a,1,true)
	assert(first and not s:find(a,last+1,true),"Source anchor changed")
	return s:sub(1,first-1)..b..s:sub(last+1)
end
local proposed={}
local installedCount=0
for _,edit in ipairs(edits) do
	local item=find(edit.path)
	assert(item:IsA("Script") and not item.Disabled,"Unexpected script state")
	local old=item.Source
	local installed=hash(old)==edit.after and #old==edit.afterBytes
	assert(installed or hash(old)==edit.before and #old==edit.beforeBytes,"Baseline changed: "..edit.path)
	if installed then installedCount+=1 end
	local target=old
	if MODE=="INSTALL" and not installed then for _,pair in ipairs(edit.edits) do target=replace(target,pair[1],pair[2]) end end
	if MODE=="ROLLBACK" and installed then for i=#edit.edits,1,-1 do local pair=edit.edits[i]; target=replace(target,pair[2],pair[1]) end end
	local expected=MODE=="ROLLBACK" and edit.before or MODE=="INSTALL" and edit.after or hash(old)
	assert(hash(target)==expected,"Result fingerprint mismatch")
	local compiled,message=loadstring(target,"="..edit.path); assert(compiled,message)
	table.insert(proposed,{item=item,old=old,source=target})
end
assert(installedCount==0 or installedCount==#edits,"Mixed baseline; inspect before proceeding")
for _,entry in ipairs(modules) do
	entry.parent=find(entry.path)
	entry.item=entry.parent:FindFirstChild(entry.name)
	if entry.item then assert(entry.item:IsA("ModuleScript") and entry.item.Source==entry.source,"Module changed: "..entry.name) end
	assert((installedCount==#edits)==(entry.item~=nil),"Incomplete module installation")
	local compiled,message=loadstring(entry.source,"="..entry.name); assert(compiled,message)
end
if MODE=="AUDIT" then return "PASS Phase 2 "..(installedCount==#edits and "installed" or "baseline") end
local created={}
local ok,message=pcall(function()
	if MODE=="INSTALL" then
		for _,entry in ipairs(modules) do if not entry.item then
			local item=Instance.new("ModuleScript"); table.insert(created,item)
			item.Name=entry.name; item.Source=entry.source; item.Parent=entry.parent; entry.item=item
		end end
	end
	for _,change in ipairs(proposed) do if change.item.Source~=change.source then change.item.Source=change.source end end
	for _,change in ipairs(proposed) do assert(change.item.Source==change.source,"Source write mismatch") end
	if MODE=="ROLLBACK" then for _,entry in ipairs(modules) do if entry.item then entry.item:Destroy() end end end
end)
if not ok then
	for _,change in ipairs(proposed) do change.item.Source=change.old end
	for _,item in ipairs(created) do item:Destroy() end
	error("Phase 2 restored previous sources: "..tostring(message))
end
return "PASS Phase 2 "..MODE.."; gameplay confirmation pending"
