-- Edit-only, controlled transition CPU benchmark. Not an FPS or real streaming measurement.
assert(not game:GetService("RunService"):IsRunning(),"Use Edit for consistent authored properties")
local source=workspace.NeoTokyoRacersWorld.City
local farSource=game.ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies
local trace={Vector3.new(860,100,-1749),Vector3.new(1080,100,-1749),Vector3.new(1760,100,-1749),Vector3.new(2300,100,-1749),Vector3.new(4000,100,-1749),Vector3.new(7000,100,-1749),Vector3.new(860,100,-1749)}
local function run(make)
	local root=source:Clone(); local active=Instance.new("Folder")
	local runtime,result
	local ok,message=xpcall(function()
		local start=os.clock(); runtime=make({root=root,far_root=farSource,active=active,config=Policy.read(nil)}); local registration=(os.clock()-start)*1000
		for _,position in ipairs(trace) do runtime:step(position) end
		local samples={}
		for _=1,7 do
			start=os.clock(); for _,position in ipairs(trace) do runtime:step(position) end; table.insert(samples,(os.clock()-start)*1000)
		end
		table.sort(samples)
		local before=runtime.diagnostics and runtime:diagnostics()
		start=os.clock(); for _=1,30 do runtime:step(trace[#trace]) end
		result={registration_ms=registration,trace_median_ms=samples[4],trace_min_ms=samples[1],steady_30_ticks_ms=(os.clock()-start)*1000,metrics=runtime.diagnostics and runtime:diagnostics(),before_steady=before}
	end,debug.traceback)
	if runtime and runtime.destroy then runtime:destroy() end
	root:Destroy(); active:Destroy()
	assert(ok,message); return result
end
local old=run(legacy); local new=run(Runtime.new)
return game:GetService("HttpService"):JSONEncode({kind="isolated Edit city-clone CPU trace; not FPS",legacy=old,phase5=new})
