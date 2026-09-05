"""Reviewed semantic edits beyond resolved literal instance expressions."""
import re
def apply(sources):
    def edit(p,a,b):
        s=sources[p];assert s.count(a)==1,(p,a,s.count(a));sources[p]=s.replace(a,b,1)
    for p,s in list(sources.items()):
        for match in list(re.finditer(r'^\s*local (\w+) = "NeoTokyoRacers"\s*\n',s,re.M)):
            name=match.group(1)
            assert len(re.findall(r'\b'+name+r'\b',s))==1,(p,name)
            s=s.replace(match.group(0),'\n')
        sources[p]=s
    p='ReplicatedStorage.Modules.Core.PathResolver'
    edit(p,'waitPath(root(), "Shared", "Remotes", "Garage")','waitPath(root(), "Remotes", "Garage")')
    edit(p,'waitPath(root(), "Config", "Runtime")','waitPath(root(), "Config")')
    edit(p,'waitPath(root(), "Config", "Editable")','waitPath(root(), "Config", "Vehicles", "Authoring")')
    edit('ReplicatedStorage.Modules.Game.Vehicles.CharacterSprintClient','{ "NeoTokyoRacers", "Shared", "Config", "CharacterMovement_EditAttributes" }','{ "Config", "Player", "Movement" }')
    edit('ServerStorage.Modules.Game.Garage.OwnedGarageFinish','local function root() local n=ServerStorage:FindFirstChild("NeoTokyoRacers"); return n and game:GetService("ServerStorage"):WaitForChild("Assets"):FindFirstChild("Garage") end','local function root() return ServerStorage:WaitForChild("Assets"):FindFirstChild("Garage") end')
    for p,s in list(sources.items()):
        s=re.sub(r'"NTR Racing Phase [^"\n]+"','"'+p.split('.')[-1]+'"',s)
        sources[p]=s
    p='ReplicatedStorage.Modules.Game.Vehicles.DrivingClient'
    edit(p,'return config and config:FindFirstChild(name)','return config and config:WaitForChild("Vehicles"):FindFirstChild(name)')
    edit(p,':FindFirstChild("DRIVING_CAMERA_ASSIST_EditAttributes")',':WaitForChild("Vehicles"):FindFirstChild("CameraAssist")')
    for a,b in {'DRIVING_MECHANICS_EditAttributes':'Driving','VehicleDynamics_EditAttributes':'Dynamics','HOVER_WOBBLE_EditAttributes':'HoverWobble'}.items():sources[p]=sources[p].replace('"'+a+'"','"'+b+'"')
    p='ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics'
    edit(p,'local runtime = config and config:FindFirstChild("Runtime")\n\treturn runtime and runtime:FindFirstChild("VehicleDynamics_EditAttributes")','local vehicles = config and config:FindFirstChild("Vehicles")\n\treturn vehicles and vehicles:FindFirstChild("Dynamics")')
    edit('ReplicatedStorage.Modules.Game.Vehicles.Performance.PerformanceDefinitions','return config and config:FindFirstChild("VehiclePerformanceV2_EditAttributes")','return config and config:WaitForChild("Vehicles"):FindFirstChild("Performance")')
    edit('ServerStorage.Modules.Game.Player.EconomyServer','local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")\n\treturn runtime and runtime:FindFirstChild("DriveToEarnCash_EditAttributes")','local vehicles = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Vehicles")\n\treturn vehicles and vehicles:FindFirstChild("DriveRewards")')
    return sources
