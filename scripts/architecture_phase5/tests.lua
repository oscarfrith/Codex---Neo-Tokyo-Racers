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
