-- Neo Tokyo Racers - Owned Garage Phase 4 committed-state audit
-- Read-only. Run in Studio Edit mode after the canonical installer returns.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this audit in Studio Edit mode after the installer has returned.")

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 4 Persistence Audit]"
local EXPECTED_REVISION="NTR_OWNED_GARAGE_PHASE4_MANAGEMENT_WORKSPACE_RECOVERY_V1"

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local runId=tostring(config:GetAttribute("OwnedGarageInstallRunId") or "")
local revision=tostring(config:GetAttribute("OwnedGarageRevision") or "")
local pass,fail=0,0

local function check(condition,message)
	if condition then pass+=1; print(TAG.." PASS "..message) else fail+=1; warn(TAG.." FAIL "..message) end
end

check(runId~="","config install run ID exists")
check(revision==EXPECTED_REVISION,"config revision="..revision)

local roots={
	ReplicatedStorage=ReplicatedStorage,
	ServerScriptService=ServerScriptService,
	StarterPlayer=StarterPlayer,
}
local expected={
	{"ReplicatedStorage","NeoTokyoRacers.Shared.Modules.Data.OwnedGaragePropertyCatalog","ModuleScript","NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1",false},
	{"ReplicatedStorage","NeoTokyoRacers.Shared.Modules.Data.OwnedGarageInteriorStyleCatalog","ModuleScript","NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1",true},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageProfileRuntime","ModuleScript","function Runtime.SetSurfaceStyle",false},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageDisplayAssignmentRuntime","ModuleScript",'operation=="SetSurfaceStyle"',false},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageInteriorRuntime","ModuleScript","NTR_OWNED_GARAGE_INTERIOR_RUNTIME_V1",false},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageDisplayRuntime","ModuleScript","NTR_OWNED_GARAGE_DISPLAY_RUNTIME_V1",false},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageManagementRuntime","ModuleScript",'Type="OpenManagement"',false},
	{"StarterPlayer","StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageBrowserController","ModuleScript","NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1",false},
	{"StarterPlayer","StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageWorkspaceController","ModuleScript","NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1",true},
	{"ReplicatedStorage","NeoTokyoRacers.Shared.Remotes.Garage.OwnedGarageInvoke","RemoteFunction"},
	{"ReplicatedStorage","NeoTokyoRacers.Shared.Remotes.Garage.OwnedGarageEvent","RemoteEvent"},
	{"ServerScriptService","NeoTokyoRacers.Services.Garage.OwnedGarageVehicleLifecycleBridge","BindableFunction"},
	{"StarterPlayer","StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OpenOwnedGarageBrowser","BindableEvent"},
	{"StarterPlayer","StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OpenOwnedGarageWorkspace","BindableEvent",nil,true},
}

for _,item in ipairs(expected) do
	local object=find(roots[item[1]],item[2]); local label=item[1].."."..item[2]
	local valid=object and object.ClassName==item[3]
	if valid and item[4] then local ok,source=pcall(function() return object.Source end); valid=ok and string.find(source,item[4],1,true)~=nil end
	if valid and item[5] then valid=object:GetAttribute("OwnedGarageRevision")==EXPECTED_REVISION and object:GetAttribute("OwnedGarageInstallRunId")==runId end
	check(valid,label)
end

local invoke=find(kit,"Shared.Remotes.Garage.OwnedGarageInvoke")
local openWorkspace=find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OpenOwnedGarageWorkspace")
check(invoke and invoke:GetAttribute("OwnedGarageStagingInert")==true,"remote remains inert")
check(openWorkspace and openWorkspace:GetAttribute("OwnedGarageStagingInert")==true,"workspace event remains inert")

print(TAG.." RESULT pass="..pass.." fail="..fail.." runId="..runId.." placeId="..tostring(game.PlaceId))
assert(fail==0,TAG.." committed-state audit failed")
