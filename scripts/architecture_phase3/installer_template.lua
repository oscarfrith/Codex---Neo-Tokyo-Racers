-- One Phase 3 migration/recovery entry point. Edit mode only; never publish here.
local MODE="INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId==121304917315753,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local records={--[[RECORDS]]}
local extras={--[[EXTRAS]]}
local function find(path)
	local item=game
	for part in path:gmatch("[^%.]+") do
		local found
		for _,child in ipairs(item:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous path "..path); found=child end end
		if not found then return nil end
		item=found
	end
	return item
end
local function hash(source) local n=0 for i=1,#source do n=(n*31+source:byte(i))%4294967296 end return n end
local function replace(source,a,b)
	local i,j=source:find(a,1,true)
	assert(i and not source:find(a,j+1,true),"Source anchor mismatch")
	return source:sub(1,i-1)..b..source:sub(j+1)
end
local function compile(source,path) local f,e=loadstring(source,"="..path); assert(f,e) end
local installed=find("ServerScriptService.ServerBase")~=nil
-- Stage and compile every projected source before changing any instance.
for _,r in ipairs(records) do
	r.item=assert(find(r.old),"Missing "..r.old)
	assert(#r.item:GetChildren()==0,"Unexpected children; inspect "..r.old)
	if installed then
		assert(r.item:IsA("ModuleScript") and r.item.Source==r.adapter,"Adapter changed "..r.old)
		r.canonical=assert(find(r.new),"Missing "..r.new)
		assert(r.canonical:IsA("ModuleScript") and #r.canonical:GetChildren()==0,"Unexpected canonical shape")
		r.target=r.canonical.Source
		assert(#r.target==r.afterBytes and hash(r.target)==r.after,"Canonical source changed "..r.new)
		assert(r.target:sub(1,#r.prefix)==r.prefix,"Prefix changed")
		r.original=r.target:sub(#r.prefix+1,#r.target-#r.suffix)
		for i=#r.edits,1,-1 do local pair=r.edits[i]; r.original=replace(r.original,pair[2],pair[1]) end
	else
		assert(r.item.ClassName==r.class,"Class mismatch "..r.old)
		if r.item:IsA("Script") then assert(not r.item.Disabled,"Disabled baseline "..r.old) end
		assert(not find(r.new),"Destination occupied "..r.new)
		r.original=r.item.Source
		r.target=r.original
		for _,pair in ipairs(r.edits) do r.target=replace(r.target,pair[1],pair[2]) end
		r.target=r.prefix..r.target..r.suffix
	end
	assert(hash(r.original)==r.before and #r.original==r.beforeBytes,"Baseline changed "..r.old)
	assert(hash(r.target)==r.after and #r.target==r.afterBytes,"Projected source mismatch "..r.new)
	compile(r.original,r.old); compile(r.target,r.new); compile(r.adapter,r.old)
end
for _,e in ipairs(extras) do
	e.item=find(e.path)
	assert((e.item~=nil)==installed,"Mixed extra installation "..e.path)
	if installed then assert(e.item.ClassName==e.class and e.item.Source==e.source and #e.item:GetChildren()==0,"Extra changed "..e.path) end
	compile(e.source,e.path)
end
if MODE=="AUDIT" then return "PASS Phase 3 "..(installed and "installed" or "baseline") end
if MODE=="INSTALL" and installed or MODE=="ROLLBACK" and not installed then return "PASS Phase 3 already in requested state" end
local created,changed,detached={}, {}, {}
local function parentFor(path)
	local parentPath,name=path:match("^(.*)%.([^%.]+)$")
	local parent=game
	for part in parentPath:gmatch("[^%.]+") do
		local nextItem=parent:FindFirstChild(part)
		if not nextItem then
			nextItem=Instance.new("Folder"); nextItem.Name=part
			nextItem:SetAttribute("NTRArchitecturePhase3Folder",true)
			table.insert(created,nextItem); nextItem.Parent=parent
		end
		parent=nextItem
	end
	return parent,name
end
local function make(path,class,source,attrs)
	local parent,name=parentFor(path)
	assert(not parent:FindFirstChild(name),"Occupied "..path)
	local item=Instance.new(class); table.insert(created,item)
	item.Name=name; item.Source=source
	for k,v in pairs(attrs or {}) do item:SetAttribute(k,v) end
	item.Parent=parent
	return item
end
local function detach(item)
	table.insert(detached,{item=item,parent=item.Parent})
	item.Parent=nil
end
local function assign(item,source)
	table.insert(changed,{item=item,source=item.Source}); item.Source=source
end
local ok,message=xpcall(function()
	if MODE=="INSTALL" then
		for _,r in ipairs(records) do make(r.new,"ModuleScript",r.target) end
		for _,e in ipairs(extras) do make(e.path,e.class,e.source) end
		for _,r in ipairs(records) do
			if r.class=="Script" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"ModuleScript",r.adapter,attrs)
			else assign(r.item,r.adapter) end
		end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.adapter and find(r.new).Source==r.target,"Post-install mismatch") end
	else
		for _,r in ipairs(records) do
			if r.class=="Script" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"Script",r.original,attrs)
			else assign(r.item,r.original) end
			detach(r.canonical)
		end
		for _,e in ipairs(extras) do detach(e.item) end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.original,"Post-rollback mismatch") end
	end
end,debug.traceback)
if not ok then
	for _,c in ipairs(changed) do c.item.Source=c.source end
	for i=#created,1,-1 do created[i]:Destroy() end
	for _,d in ipairs(detached) do d.item.Parent=d.parent end
	error("Phase 3 restored previous state: "..tostring(message))
end
for _,d in ipairs(detached) do d.item:Destroy() end
if MODE=="ROLLBACK" then
	local folders={}
	for _,item in ipairs(game.ServerStorage:GetDescendants()) do if item:IsA("Folder") and item:GetAttribute("NTRArchitecturePhase3Folder")==true then table.insert(folders,item) end end
	for i=#folders,1,-1 do if #folders[i]:GetChildren()==0 then folders[i]:Destroy() end end
end
return "PASS Phase 3 "..MODE.."; verify a fresh Play session"
