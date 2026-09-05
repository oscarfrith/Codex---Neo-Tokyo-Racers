local Policy=(function()
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

end)()
local Scope=(function()
-- Owns subscriptions for one explicit binding. destroy is repeat-safe.
local Scope={}
Scope.__index=Scope
function Scope.new() return setmetatable({connections={},destroyed=false},Scope) end
function Scope:connect(signal,callback)
	assert(not self.destroyed,"Cannot bind a destroyed scope")
	local connection=signal:Connect(callback)
	table.insert(self.connections,connection)
	return connection
end
function Scope:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end
return Scope

end)()
local Runtime=(function()
-- Owns one city root's visibility/cache and client far clones. No saved state or gameplay requests.


local Runtime={}; Runtime.__index=Runtime
local function is_block(obj) return obj:IsA("Model") and obj.Name:match("^Block_S%d+_R%d+_B%d+$")~=nil end
local function original(obj)
	if obj:IsA("BasePart") then return {Transparency=obj.Transparency,LocalTransparencyModifier=obj.LocalTransparencyModifier,CanCollide=obj.CanCollide,CanTouch=obj.CanTouch,CanQuery=obj.CanQuery,Anchored=obj.Anchored,CastShadow=obj.CastShadow}
	elseif obj:IsA("Decal") or obj:IsA("Texture") then return {Transparency=obj.Transparency}
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then return {Enabled=obj.Enabled} end
end
function Runtime:_write(obj,key,value)
	if obj[key]~=value then obj[key]=value; self.metrics.writes+=1 end
end
function Runtime:_show(obj,record,visible)
	self.metrics.visits+=1
	local saved=record.original
	if obj:IsA("BasePart") then
		if visible then for key,value in pairs(saved) do self:_write(obj,key,value) end
		else
			self:_write(obj,"LocalTransparencyModifier",1)
			self:_write(obj,"CanCollide",false); self:_write(obj,"CanTouch",false); self:_write(obj,"CanQuery",false)
			self:_write(obj,"Anchored",true); self:_write(obj,"CastShadow",false)
		end
	elseif saved.Transparency~=nil then self:_write(obj,"Transparency",visible and saved.Transparency or 1)
	else self:_write(obj,"Enabled",visible and saved.Enabled or false) end
end
function Runtime:_forget(data,obj)
	self.owners[obj]=nil
	local record=data.members[obj]; if not record then return end
	for key,value in pairs(record.original) do self:_write(obj,key,value) end
	data.buckets[record.bucket].members[obj]=nil; data.members[obj]=nil; self.metrics.cached-=1
end
function Runtime:_track(data,obj,knownBucket)
	if not data.center and obj.Name=="CenterPart" and obj:IsA("BasePart") then data.center=obj; self.owners[obj]=data end
	if not data.rootPart and obj.Name=="Root" and obj:IsA("BasePart") then data.rootPart=obj; self.owners[obj]=data end
	if data.members[obj] then return end
	local saved=original(obj); if not saved then return end
	local bucketName=knownBucket
	if not bucketName then
		local layer=obj
		while layer and layer.Parent~=data.model do
			if layer.Parent and layer.Parent.Name=="LOD" and layer.Parent.Parent==data.model then break end
			layer=layer.Parent
		end
		bucketName=layer and layer.Parent and layer.Parent.Name=="LOD" and layer.Parent.Parent==data.model and layer.Name
	end
	local bucket=bucketName and data.buckets[bucketName]
	if not bucket then return end
	local record={original=saved,bucket=bucketName}; data.members[obj]=record; self.owners[obj]=data; bucket.members[obj]=record; self.metrics.cached+=1
	if bucket.visible~=nil then self:_show(obj,record,bucket.visible) end
end
function Runtime:_register(model)
	if self.blocks[model] then return self.blocks[model] end
	local data={model=model,buckets={},members={}}
	for _,name in ipairs({"LOD1","LOD2","LOD3","LOD4","LOD4_Foliage"}) do data.buckets[name]={members={}} end
	self.blocks[model]=data; self.metrics.blocks+=1
	data.center=model:FindFirstChild("CenterPart",true); data.rootPart=model:FindFirstChild("Root",true)
	if data.center and not data.center:IsA("BasePart") then data.center=nil end
	if data.rootPart and not data.rootPart:IsA("BasePart") then data.rootPart=nil end
	if data.center then self.owners[data.center]=data end; if data.rootPart then self.owners[data.rootPart]=data end
	local lod=model:FindFirstChild("LOD")
	if lod then for name in pairs(data.buckets) do local folder=lod:FindFirstChild(name); if folder then
		self.metrics.scans+=1
		for _,obj in ipairs(folder:GetDescendants()) do self:_track(data,obj,name) end
	end end end
	return data
end
function Runtime:_block_for(obj)
	local current=obj
	while current and current~=self.root do if is_block(current) then return current end; current=current.Parent end
end
function Runtime:_added(obj)
	local block=self:_block_for(obj); if not block then return end
	local data=self.blocks[block] or self:_register(block)
	self:_track(data,obj)
end
function Runtime:_remove_block(model)
	local data=self.blocks[model]; if not data then return end
	for obj in pairs(data.members) do self:_forget(data,obj) end
	if data.center then self.owners[data.center]=nil end; if data.rootPart then self.owners[data.rootPart]=nil end
	data.center=nil; data.rootPart=nil; self.blocks[model]=nil; self.metrics.blocks-=1
end
function Runtime:_removed(obj)
	if self.blocks[obj] then self:_remove_block(obj); return end
	-- Reverse membership survives deferred DescendantRemoving delivery after ancestry is gone.
	local data=self.owners[obj]; if not data then return end
	self:_forget(data,obj)
	if data.center==obj then data.center=nil end; if data.rootPart==obj then data.rootPart=nil end
end
function Runtime.new(options)
	local self=setmetatable({root=options.root,far_root=options.far_root,active=options.active,config=options.config,blocks={},owners={},far={},scope=Scope.new(),metrics={blocks=0,cached=0,scans=0,writes=0,visits=0,clones=0,ticks=0,last_ms=0,max_ms=0}},Runtime)
	local ok,message=xpcall(function()
		self.scope:connect(self.root.DescendantAdded,function(obj) self:_added(obj) end)
		self.scope:connect(self.root.DescendantRemoving,function(obj) self:_removed(obj) end)
		self.metrics.scans+=1
		for _,obj in ipairs(self.root:GetDescendants()) do if is_block(obj) then self:_register(obj) end end
	end,debug.traceback)
	if not ok then self:destroy(); error(message) end
	return self
end
function Runtime:_bucket(data,name,visible)
	local bucket=data.buckets[name]; if bucket.visible==visible then return end
	bucket.visible=visible
	for obj,record in pairs(bucket.members) do self:_show(obj,record,visible) end
end
function Runtime:_drop_clone(entry)
	if entry.clone then entry.clone:Destroy(); entry.clone=nil; self.metrics.clones-=1 end
end
function Runtime:_index_proxies()
	if self.indexed_far_root==self.far_root and self.sources then return end
	if self.proxyScope then self.proxyScope:destroy() end
	self.proxyScope=Scope.new(); self.indexed_far_root=self.far_root; self.sources={}
	if not self.far_root then return end
	local function added(obj) self.sources[obj.Name]=obj end
	for _,obj in ipairs(self.far_root:GetChildren()) do added(obj) end
	self.proxyScope:connect(self.far_root.ChildAdded,added)
	self.proxyScope:connect(self.far_root.ChildRemoved,function(obj) if self.sources[obj.Name]==obj then self.sources[obj.Name]=nil end end)
end
function Runtime:step(position)
	assert(not self.destroyed,"LOD runtime destroyed")
	local started=os.clock(); local cfg=self.config; self.metrics.ticks+=1
	self:_index_proxies()
	for model,data in pairs(self.blocks) do
		local center=data.center and data.center.Position or data.rootPart and data.rootPart.Position or data.lastCenter or model:GetPivot().Position
		data.lastCenter=center
		-- Keep the last observed authored center as plain metadata, not a streamed instance reference.
		local entry=self.far[model.Name]
		if not entry then entry={key=model.Name.."_LOD5"}; self.far[model.Name]=entry end
		entry.center=center
		local delta=position-center; local distance=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
		entry.distance=distance; entry.tick=self.metrics.ticks
		local near=Policy.near(distance,cfg)
		for layer=1,4 do self:_bucket(data,"LOD"..layer,Policy.visible(layer,near)) end
		self:_bucket(data,"LOD4_Foliage",Policy.foliage(distance,cfg))
	end
	for name,entry in pairs(self.far) do
		local source=self.sources[entry.key]
		if source~=entry.source then self:_drop_clone(entry); entry.source=source; entry.visible=false end
		if not source then
			-- Missing proxies are retried from currently loaded blocks next tick, without recursion or warnings per frame.
			self:_drop_clone(entry); self.far[name]=nil
		else
			local distance=entry.distance
			if entry.tick~=self.metrics.ticks then local delta=position-entry.center; distance=math.sqrt(delta.X*delta.X+delta.Z*delta.Z) end
			local visible=Policy.far(distance,entry.visible,cfg); entry.visible=visible
			if visible then
				if not entry.clone then entry.clone=source:Clone(); entry.clone.Name=name.."_LOD5"; entry.clone.Parent=self.active; self.metrics.clones+=1 end
			else self:_drop_clone(entry) end
		end
	end
	self.metrics.last_ms=(os.clock()-started)*1000; self.metrics.max_ms=math.max(self.metrics.max_ms,self.metrics.last_ms)
end
function Runtime:diagnostics()
	local result=table.clone(self.metrics); result.connections=#self.scope.connections+(self.proxyScope and #self.proxyScope.connections or 0)
	local count=0; for _ in pairs(self.far) do count+=1 end; result.proxy_records=count
	return result
end
function Runtime:destroy()
	if self.destroyed then return end; self.destroyed=true
	self.scope:destroy()
	if self.proxyScope then self.proxyScope:destroy() end
	for model in pairs(self.blocks) do self:_remove_block(model) end
	for _,entry in pairs(self.far) do self:_drop_clone(entry) end
	table.clear(self.far)
	table.clear(self.owners)
	self.sources=nil; self.indexed_far_root=nil; self.far_root=nil
end
return Runtime

end)()
-- Isolated objects only. No game module require, DataStore access or authored hierarchy writes.
local count=0
local function check(name,fn) fn(); count+=1; print("PASS "..name) end
local cfg=Policy.read(nil)
local function settle(predicate)
	local deadline=os.clock()+2
	repeat task.wait() until predicate() or os.clock()>=deadline
	assert(predicate(),"Timed out waiting for deferred hierarchy signals")
end
check("exact near, foliage and far boundaries",function()
	for _,pair in ipairs({{0,1},{200,1},{200.01,2},{800,2},{800.01,3},{1300,3},{1300.01,4},{2449.99,4},{2450,0}}) do assert(Policy.near(pair[1],cfg)==pair[2]) end
	assert(Policy.visible(4,2) and not Policy.visible(1,2) and not Policy.visible(4,0))
	assert(Policy.foliage(1275,cfg) and Policy.foliage(2000,cfg) and not Policy.foliage(2001,cfg))
	assert(not Policy.far(2400,false,cfg) and Policy.far(2400,true,cfg) and Policy.far(5050,true,cfg) and not Policy.far(5050.1,true,cfg))
end)
local function folder(name,parent) local f=Instance.new("Folder"); f.Name=name; f.Parent=parent; return f end
local function part(name,parent)
	local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.Transparency=0.3; p.CanCollide=true; p.CanTouch=true; p.CanQuery=true; p.CastShadow=true; p.Parent=parent; return p
end
local root=folder("FixtureCity"); local far=folder("FixtureProxies"); local active=folder("FixtureActive")
local block=Instance.new("Model"); block.Name="Block_S99_R1_B1"; block.Parent=root
local center=part("CenterPart",block); center.Position=Vector3.zero
local lod=folder("LOD",block); local layer=folder("LOD1",lod); local p=part("NearPart",layer)
local decal=Instance.new("Decal"); decal.Transparency=0.4; decal.Parent=p
local fx=Instance.new("ParticleEmitter"); fx.Enabled=true; fx.Parent=p
local runtime=Runtime.new({root=root,far_root=far,active=active,config=cfg})
local ok,message=xpcall(function()
	check("hide and exact authored restoration",function()
		runtime:step(Vector3.new(900,0,0)); assert(p.LocalTransparencyModifier==1 and not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow and not fx.Enabled and decal.Transparency==1)
		runtime:step(Vector3.zero); assert(p.LocalTransparencyModifier==0 and p.CanCollide and p.CanQuery and p.CanTouch and p.CastShadow and fx.Enabled and math.abs(p.Transparency-0.3)<0.001 and math.abs(decal.Transparency-0.4)<0.001)
	end)
	check("unchanged tick avoids hierarchy scans and visibility visits",function()
		local before=runtime:diagnostics(); runtime:step(Vector3.zero); local after=runtime:diagnostics()
		assert(before.visits==after.visits and before.writes==after.writes and before.scans==after.scans)
	end)
	check("late LOD folder and descendants inherit current band",function()
		runtime:step(Vector3.new(3000,0,0)); local late=folder("LOD2",lod); local added=part("Late",late); settle(function() return runtime.owners[added]~=nil end); runtime:step(Vector3.new(3000,0,0)); assert(added.LocalTransparencyModifier==1)
		late.Parent=nil; settle(function() return runtime.owners[added]==nil end); assert(added.CanCollide and added.LocalTransparencyModifier==0); late:Destroy()
	end)
	check("missing and late proxy, hysteresis and bounded clones",function()
		runtime:step(Vector3.new(3000,0,0)); assert(#active:GetChildren()==0)
		local proxy=folder(block.Name.."_LOD5",far); part("Proxy",proxy); settle(function() return runtime.sources[proxy.Name]==proxy end)
		runtime:step(Vector3.new(3000,0,0)); assert(#active:GetChildren()==1)
		runtime:step(Vector3.new(2400,0,0)); assert(#active:GetChildren()==1)
		runtime:step(Vector3.new(2399,0,0)); assert(#active:GetChildren()==0 and runtime:diagnostics().clones==0)
	end)
	check("whole block removal releases references, preserves far metadata",function()
		runtime:step(Vector3.new(3000,0,0)); block.Parent=nil; settle(function() return runtime:diagnostics().cached==0 end)
		assert(runtime:diagnostics().blocks==0 and runtime:diagnostics().cached==0 and next(runtime.owners)==nil)
		runtime:step(Vector3.new(3000,0,0)); assert(#active:GetChildren()==1)
	end)
	check("twenty remove/re-add cycles do not retain memberships",function()
		for _=1,20 do block.Parent=root; settle(function() return runtime:diagnostics().blocks==1 end); runtime:step(Vector3.zero); block.Parent=nil; settle(function() return runtime:diagnostics().cached==0 end); assert(next(runtime.owners)==nil) end
		block.Parent=root; settle(function() return runtime:diagnostics().blocks==1 end); runtime:step(Vector3.new(3000,0,0))
	end)
	check("destroy restores authored properties and releases all resources",function()
		runtime:destroy(); runtime:destroy(); local stats=runtime:diagnostics()
		assert(stats.cached==0 and stats.blocks==0 and stats.connections==0 and stats.clones==0 and stats.proxy_records==0)
		assert(p.CanCollide and p.LocalTransparencyModifier==0)
	end)
end,debug.traceback)
runtime:destroy(); block:Destroy(); root:Destroy(); far:Destroy(); active:Destroy()
assert(ok,message)
return "PASS "..count.." Phase 5 isolated checks"
