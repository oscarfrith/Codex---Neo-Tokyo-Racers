-- Single Phase 5 entry point. Complete source replacement; no live text-anchor surgery.
local MODE="INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId==121304917315753,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local original=[====[
-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("LODClient_Active")
print("LOD Script Running")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function resolveFarLod5Root()
	local ntrRoot = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local assetsRoot = ntrRoot and ntrRoot:FindFirstChild("Assets")
	local worldAssets = assetsRoot and assetsRoot:FindFirstChild("World")
	local farLod5Proxies = worldAssets and worldAssets:FindFirstChild("FarLOD5Proxies")
	if farLod5Proxies then
		return farLod5Proxies
	end

	return resolveFarLod5Root()
end



local player = Players.LocalPlayer
local function resolveCityRoot()
	local worldRoot = workspace:FindFirstChild("NeoTokyoRacersWorld")
	local cityRoot = worldRoot and worldRoot:FindFirstChild("City")
	if cityRoot then
		return cityRoot
	end

	return workspace:WaitForChild("GeneratedCityBlocks")
end

local ROOT = resolveCityRoot()


local FAR_LOD5_SOURCE = resolveFarLod5Root()

local UPDATE_RATE = 0.5
local DEBUG_PRINTS = false

local DIST = {
	LOD1 = 200,
	LOD2 = 800,
	LOD3 = 1300,
	LOD4 = 2450,
	LOD5 = 5000,
}

local HYSTERESIS = 50
local FAR_LOD5_START = 2450
local FAR_LOD5_END = 5000

-- Special foliage band
local LOD4_FOLIAGE_MIN = 1275
local LOD4_FOLIAGE_MAX = 2000

local ActiveFarLOD5 = workspace:FindFirstChild("_ActiveFarLOD5")
if not ActiveFarLOD5 then
	ActiveFarLOD5 = Instance.new("Folder")
	ActiveFarLOD5.Name = "_ActiveFarLOD5"
	ActiveFarLOD5.Parent = workspace
end

local Blocks = {}
local OriginalProperties = {}

local function cacheOriginalProperties(obj)
	if OriginalProperties[obj] then return end

	if obj:IsA("BasePart") then
		OriginalProperties[obj] = {
			Transparency = obj.Transparency,
			CanCollide = obj.CanCollide,
			CanTouch = obj.CanTouch,
			CanQuery = obj.CanQuery,
			Anchored = obj.Anchored,
			CastShadow = obj.CastShadow,
			LocalTransparencyModifier = obj.LocalTransparencyModifier,
		}
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		OriginalProperties[obj] = {
			Transparency = obj.Transparency,
		}
	elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
		OriginalProperties[obj] = {
			Enabled = obj.Enabled,
		}
	end
end

local function cacheFolderOriginalProperties(folder)
	if not folder then return end

	for _, obj in ipairs(folder:GetDescendants()) do
		cacheOriginalProperties(obj)
	end
end

local function isBlockModel(model)
	return model:IsA("Model") and model.Name:match("^Block_S%d+_R%d+_B%d+$")
end

local function setInstanceVisible(obj, visible)
	cacheOriginalProperties(obj)

	local original = OriginalProperties[obj]
	if not original then return end

	if obj:IsA("BasePart") then
		if visible then
			obj.Transparency = original.Transparency or 0
			obj.LocalTransparencyModifier = original.LocalTransparencyModifier or 0
			obj.CanCollide = original.CanCollide
			obj.CanTouch = original.CanTouch
			obj.CanQuery = original.CanQuery
			obj.Anchored = original.Anchored
			obj.CastShadow = original.CastShadow
		else
			obj.LocalTransparencyModifier = 1
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Anchored = true
			obj.CastShadow = false
		end

	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		obj.Transparency = visible and original.Transparency or 1

	elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
		obj.Enabled = visible and original.Enabled or false
	end
end

local function setLODVisible(folder, visible)
	if not folder then return end

	for _, obj in ipairs(folder:GetDescendants()) do
		setInstanceVisible(obj, visible)
	end
end

local function setupStreamingVisibilityWatcher(blockData, lodFolder, lodNumber)
	if not lodFolder then return end

	lodFolder.DescendantAdded:Connect(function(obj)
		cacheOriginalProperties(obj)

		local currentState = blockData.LastNearState
		local shouldShow =
			currentState ~= 0
			and lodNumber >= currentState
			and lodNumber <= 4

		setInstanceVisible(obj, shouldShow)
	end)
end

local function setupFoliageVisibilityWatcher(blockData)
	if not blockData.LOD4_Foliage then return end

	blockData.LOD4_Foliage.DescendantAdded:Connect(function(obj)
		cacheOriginalProperties(obj)
		setInstanceVisible(obj, blockData.LastFoliageVisible == true)
	end)
end

local function getNearLODState(dist)
	if dist <= DIST.LOD1 then
		return 1
	elseif dist <= DIST.LOD2 then
		return 2
	elseif dist <= DIST.LOD3 then
		return 3
	elseif dist < FAR_LOD5_START then
		return 4
	else
		return 0
	end
end

local function shouldNearLODBeVisible(lodNumber, state)
	if state == 0 then
		return false
	end

	return lodNumber >= state and lodNumber <= 4
end

local function applyNearLOD(blockData, state)
	if blockData.LastNearState == state then
		return
	end

	blockData.LastNearState = state

	for i = 1, 4 do
		local lodFolder = blockData.LODs["LOD" .. i]
		local visible = shouldNearLODBeVisible(i, state)
		setLODVisible(lodFolder, visible)
	end
end

local function shouldShowLOD4Foliage(dist)
	return dist >= LOD4_FOLIAGE_MIN and dist <= LOD4_FOLIAGE_MAX
end

local function applyLOD4Foliage(blockData, visible)
	if blockData.LastFoliageVisible == visible then
		return
	end

	blockData.LastFoliageVisible = visible
	setLODVisible(blockData.LOD4_Foliage, visible)
end

local function shouldShowFarLOD5(dist, wasVisible)
	if wasVisible then
		return dist >= FAR_LOD5_START - HYSTERESIS and dist <= FAR_LOD5_END + HYSTERESIS
	end

	return dist >= FAR_LOD5_START and dist <= FAR_LOD5_END
end

local function applyFarLOD5(blockData, visible)
	if blockData.LastFarVisible == visible then
		return
	end

	blockData.LastFarVisible = visible

	if not FAR_LOD5_SOURCE then
		return
	end

	if visible then
		if not blockData.FarLOD5Clone then
			local source = FAR_LOD5_SOURCE:FindFirstChild(blockData.Model.Name .. "_LOD5")

			if source then
				local clone = source:Clone()
				clone.Name = blockData.Model.Name .. "_LOD5"
				clone.Parent = ActiveFarLOD5
				blockData.FarLOD5Clone = clone
			else
				warn("Missing FarLOD5 proxy:", blockData.Model.Name .. "_LOD5")
			end
		else
			blockData.FarLOD5Clone.Parent = ActiveFarLOD5
		end
	else
		if blockData.FarLOD5Clone then
			blockData.FarLOD5Clone.Parent = nil
		end
	end
end

local function getBlockCenterPosition(blockData)
	if blockData.CenterPart and blockData.CenterPart.Parent then
		return blockData.CenterPart.Position
	end

	if blockData.RootPart and blockData.RootPart.Parent then
		return blockData.RootPart.Position
	end

	return blockData.Model:GetPivot().Position
end

local function registerBlocks()
	for _, block in ipairs(ROOT:GetDescendants()) do
		if isBlockModel(block) then
			local lodRoot = block:FindFirstChild("LOD")
			local centerPart = block:FindFirstChild("CenterPart", true)
			local rootPart = block:FindFirstChild("Root", true)

			if not lodRoot then
				warn("Block missing LOD folder:", block.Name)
				continue
			end

			local blockData = {
				Model = block,
				CenterPart = centerPart,
				RootPart = rootPart,
				LODRoot = lodRoot,

				LODs = {
					LOD1 = lodRoot:FindFirstChild("LOD1"),
					LOD2 = lodRoot:FindFirstChild("LOD2"),
					LOD3 = lodRoot:FindFirstChild("LOD3"),
					LOD4 = lodRoot:FindFirstChild("LOD4"),
				},

				LOD4_Foliage = lodRoot:FindFirstChild("LOD4_Foliage"),

				LastNearState = -1,
				LastFoliageVisible = nil,
				LastFarVisible = false,
				FarLOD5Clone = nil,
			}

			for i = 1, 4 do
				local lodFolder = blockData.LODs["LOD" .. i]

				if lodFolder then
					cacheFolderOriginalProperties(lodFolder)
					setupStreamingVisibilityWatcher(blockData, lodFolder, i)
				else
					warn(block.Name .. " missing LOD" .. i)
				end
			end

			if blockData.LOD4_Foliage then
				cacheFolderOriginalProperties(blockData.LOD4_Foliage)
				setupFoliageVisibilityWatcher(blockData)
			else
				warn(block.Name .. " missing LOD4_Foliage")
			end

			table.insert(Blocks, blockData)
		end
	end

	print("Registered blocks:", #Blocks)
end

registerBlocks()

task.spawn(function()
while true do
	task.wait(UPDATE_RATE)

	local character = player.Character
	if not character then continue end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then continue end

	local playerPos = rootPart.Position

	for _, blockData in ipairs(Blocks) do
		local centerPos = getBlockCenterPosition(blockData)

		local dx = playerPos.X - centerPos.X
		local dz = playerPos.Z - centerPos.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local nearState = getNearLODState(dist)

		if DEBUG_PRINTS then
			print(
				blockData.Model.Name,
				"Distance:", math.floor(dist),
				"NearState:", nearState,
				"LOD4_Foliage:", shouldShowLOD4Foliage(dist)
			)
		end

		applyNearLOD(blockData, nearState)

		local foliageVisible = shouldShowLOD4Foliage(dist)
		applyLOD4Foliage(blockData, foliageVisible)

		local farVisible = shouldShowFarLOD5(dist, blockData.LastFarVisible)
		applyFarLOD5(blockData, farVisible)
	end
end
end)

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
]====]
local target=[====[
-- ClientBase starts this single city LOD owner. Config changes apply on a fresh client session.
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Policy=require(script.Parent.LODPolicy)
local Runtime=require(script.Parent.LODRuntime)
local Client={}
local controller,worker,active,owns_active,settings,reporter
local started=false
local function roots()
	local world=workspace:FindFirstChild("NeoTokyoRacersWorld")
	local kit=RS:FindFirstChild("NeoTokyoRacers")
	local assets=kit and kit:FindFirstChild("Assets")
	local assetWorld=assets and assets:FindFirstChild("World")
	return world and world:FindFirstChild("City") or workspace:FindFirstChild("GeneratedCityBlocks"),
		assetWorld and assetWorld:FindFirstChild("FarLOD5Proxies") or RS:FindFirstChild("FarLOD5")
end
function Client.destroy()
	started=false
	if worker then task.cancel(worker); worker=nil end
	if controller then controller:destroy(); controller=nil end
	if active and owns_active then active:Destroy() end; active=nil; owns_active=nil
end
function Client.start()
	if started then return end
	settings=RS.NeoTokyoRacers.Config.Runtime:WaitForChild("WorldLOD")
	local config=Policy.read(settings)
	local player=game:GetService("Players").LocalPlayer
	reporter=player:WaitForChild("PlayerScripts").NeoTokyoRacersClient.Controllers.World.LODClient_Active
	active=workspace:FindFirstChild("_ActiveFarLOD5")
	if not active then active=Instance.new("Folder"); active.Name="_ActiveFarLOD5"; active.Parent=workspace; owns_active=true end
	started=true
	reporter:SetAttribute("Phase5Status","waiting")
	worker=task.spawn(function()
		local ok,message=xpcall(function()
		local nextReport=0
		while started do
			task.wait(config.UpdateSeconds)
			local city,far=roots()
			if controller and controller.root~=city then controller:destroy(); controller=nil end
			if city and not controller then controller=Runtime.new({root=city,far_root=far,active=active,config=config}); reporter:SetAttribute("Phase5Status","running") end
			local character=player.Character; local rootPart=character and character:FindFirstChild("HumanoidRootPart")
			if controller then
				controller.far_root=far
				if rootPart then debug.profilebegin("NTR.WorldLOD.Step"); controller:step(rootPart.Position); debug.profileend() end
			end
			if RunService:IsStudio() and settings:GetAttribute("DiagnosticsEnabled")==true and os.clock()>=nextReport then
				nextReport=os.clock()+5
				reporter:SetAttribute("Phase5Diagnostics",game:GetService("HttpService"):JSONEncode(controller and controller:diagnostics() or {waiting_for_city=true}))
			end
		end
		end,debug.traceback)
		if not ok then
			started=false; worker=nil
			if controller then controller:destroy(); controller=nil end
			if active and owns_active then active:Destroy(); active=nil; owns_active=nil end
			reporter:SetAttribute("Phase5Status","failed"); warn("[WorldLOD] stopped and restored authored visibility: "..tostring(message))
		end
	end)
end
return Client
]====]
local extras={{path=[====[
ReplicatedStorage.Modules.Game.World.LODPolicy]====],class=[====[
ModuleScript]====],source=[====[
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
]====]},{path=[====[
ReplicatedStorage.Modules.Game.World.LODRuntime]====],class=[====[
ModuleScript]====],source=[====[
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
]====]},{path=[====[
ReplicatedStorage.NeoTokyoRacers.Config.Runtime.WorldLOD]====],class=[====[
Configuration]====],attributes={UpdateSeconds=0.5,Near1=200,Near2=800,Near3=1300,FarStart=2450,FarEnd=5000,Hysteresis=50,FoliageMin=1275,FoliageMax=2000,DiagnosticsEnabled=false}}}
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
