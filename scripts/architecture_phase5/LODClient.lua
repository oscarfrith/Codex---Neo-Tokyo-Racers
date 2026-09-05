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
