-- Owns one city root's visibility/cache and client far clones. No saved state or gameplay requests.
local Policy=require(script.Parent.LODPolicy)
local Scope=require(game:GetService("ReplicatedStorage").Modules.Core.ConnectionScope)
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
