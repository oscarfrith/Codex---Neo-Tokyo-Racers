-- Pure table mocks only. Caller provides local run from studio_delivery.lua.
local checks=0
local function fresh()
    local targets={{ClassName="ModuleScript",value="return 1"},{ClassName="Folder",value=1}}
    local bundle={place_id=121304917315753,operations={
        {kind="source",path={1},class_name="ModuleScript",before="return 1",after="return 2"},
        {kind="attribute",path={2},class_name="Folder",before=1,after=2},
    }}
    local env={placeId=bundle.place_id,isEdit=true,resolve=function(p) return targets[p[1]] end,
        compile=loadstring,read=function(t) return t.value end,write=function(t,op,v) t.value=v end}
    return targets,bundle,env
end
local function test(fn) fn(); checks+=1 end
test(function()
    local t,b,e=fresh()
    assert(run(b,"AUDIT",e).state=="before" and t[1].value=="return 1")
    assert(run(b,"APPLY",e).changed==2)
    assert(run(b,"APPLY",e).changed==0)
    assert(run(b,"ROLLBACK",e).changed==2)
    assert(run(b,"ROLLBACK",e).changed==0)
end)
for _, failure in ipairs({"place","mode","drift","mixed","compile","class"}) do
    test(function()
        local t,b,e=fresh()
        if failure=="place" then e.placeId=0 elseif failure=="mode" then e.isEdit=false
        elseif failure=="drift" then t[1].value="return 3"
        elseif failure=="mixed" then t[1].value="return 2"
        elseif failure=="compile" then b.operations[2]={kind="source",path={2},class_name="Folder",before=1,after="invalid syntax"}; e.compile=function(s) return type(s)=="string" and loadstring(s) end
        elseif failure=="class" then t[2].ClassName="Part" end
        local old=t[1].value
        assert(not pcall(run,b,"APPLY",e)); assert(t[1].value==old)
    end)
end
test(function()
    local t,b,e=fresh(); local failed=false
    e.write=function(target,op,v) if target==t[2] and not failed then failed=true; error("Injected") end target.value=v end
    local ok,err=pcall(run,b,"APPLY",e)
    assert(not ok and string.find(err,"restored attempted")); assert(t[1].value=="return 1" and t[2].value==1)
end)
test(function()
    local t,b,e=fresh()
    e.write=function(target,op,v) if target==t[2] then t[1].value="external edit"; error("Injected") end target.value=v end
    local ok,err=pcall(run,b,"APPLY",e)
    assert(not ok and string.find(err,"RECOVERY INCOMPLETE")); assert(t[1].value=="external edit")
end)
test(function()
    local t,b,e=fresh(); run(b,"APPLY",e); t[1].value="external edit"
    assert(not pcall(run,b,"ROLLBACK",e)); assert(t[1].value=="external edit")
end)
return {passed=checks,gameInstancesCreated=0}
