"""Reviewed semantic edits after literal path migration; every source anchor is occurrence guarded."""
from prepare import read,HERE
from path_analysis import expression

def apply(projected):
    def get(tail,server=False):return ('ServerStorage' if server else 'ReplicatedStorage')+'.Modules.'+tail
    def replace(path,a,b,count=1):
        source=projected[path];assert source.count(a)==count,(path,a[:90],source.count(a))
        projected[path]=source.replace(a,b)
    def block(path,a,b,replacement):
        source=projected[path];assert source.count(a)==1 and source.count(b)==1,(path,a,b)
        i=source.index(a);j=source.index(b,i);replace(path,source[i:j],replacement)

    # The legacy closure's garage entry functions return unconditionally. The real GarageUI owns
    # all current garage presentation. Its only live external handoff is the driving session.
    del projected[get('Game.Garage.GarageClient')]
    projected[get('Game.Vehicles.DriveSessionClient')]=read(HERE/'DriveSessionClient.lua')
    garage=get('Game.Garage.GarageUI')
    source=projected[garage]
    projected[garage]='-- Current garage application; ClientBase owns startup.\nlocal Client={}\nlocal started=false\nfunction Client.start()\nif started then return end\nstarted=true\n'+source+'\nend\nreturn Client\n'
    for tail in ('Game.Vehicles.DriveHudClient','Game.UI.FreeRoamNavUI','Game.Vehicles.DrivingFallbackClient'):
        del projected[get(tail)]
    mobile=get('Game.UI.MobileFreeRoamHudUI')
    block(mobile,'local legacyItemConnections=', '-- Local toast visuals were retired;', '')

    gate=get('Game.Vehicles.GameplayInputGate')
    block(gate,'local function mobileState()','local function resetMobile()',
          'local function mobileState()\n\treturn require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.MobileDriveInputState)\nend\n\n')

    driving=get('Game.Vehicles.DrivingClient')
    block(driving,'local VehicleDynamicsModel\n','local REVERSE_MAX_MPH',
          'local VehicleDynamicsModel = require(game:GetService("ReplicatedStorage").Modules.Game.Vehicles.VehicleDynamics)\n\n')
    # Current UITheme has a guaranteed authored folder. Preserve its effective values/defaults.
    theme=get('Game.UI.UITheme')
    block(theme,'local function findThemeFolder()','local function color(',
          'local function findThemeFolder()\n\treturn ReplicatedStorage:WaitForChild("NeoTokyoRacers"):WaitForChild("Config"):WaitForChild("UI"):WaitForChild("Theme")\nend\n\n')

    initial='ReplicatedFirst.NTRLoading.InitialLoadingAndStartScreenClient'
    replace(initial,'local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient")\nlocal uiFolder = clientRoot:WaitForChild("Controllers"):WaitForChild("UI")',
            'local uiFolder = playerScripts:WaitForChild("Runtime"):WaitForChild("UI")')
    resolver=get('Core.PathResolver')
    block(resolver,'function PathResolver.SharedModules()','function PathResolver.GarageRemotes()', '')
    replace(get('Game.Racing.RaceBrowserClient'),'local modules = shared:WaitForChild("Modules")\n','')

    for tail in ('Game.Racing.MatchmakingServer','Game.Racing.TimeTrialServer'):
        path=get(tail,True)
        block(path,'local function getRaceVehicleSpawner()','local function invokeRaceVehicleSpawner(',
              'local function getRaceVehicleSpawner()\n\tlocal root=game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage")\n\tlocal binding=root:FindFirstChild("RaceVehicleSpawner")\n\tif binding and binding:IsA("BindableFunction") then return binding,nil end\n\treturn nil,"Race vehicle spawner is not ready."\nend\n\n')
    tt=get('Game.Racing.TimeTrialServer',True)
    replace(tt,'local services = serverRoot and serverRoot:FindFirstChild("Services")','local services = serverRoot')
    projection=get('Game.Player.ProfileCompatibilityServer',True)
    replace(projection,'local dataModules = ntr:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data")\n','')

    owned=get('Game.UI.OwnedGarageClient')
    replace(owned,'local order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}',
            'local order={"OwnedGarageBrowserUI","OwnedGarageWorkspaceUI","GarageInteriorModeUI","GarageInteriorTransitionUI"}')
    replace(owned,expression(['StarterPlayer','StarterPlayerScripts','Runtime','UI'])+':WaitForChild(name)',
            'game:GetService("ReplicatedStorage").Modules.Game.UI:WaitForChild(name)')

    # A test-only injected child must not override the production catalogue.
    profile=get('Game.Garage.OwnedGarageProfile',True)
    import re
    s=projected[profile]
    s,n=re.subn(r'game:GetService\("ServerStorage"\):WaitForChild\("Modules"\):WaitForChild\("Game"\):WaitForChild\("Garage"\):WaitForChild\("OwnedGarageProfile"\):FindFirstChild\("OwnedGarage(?:Property|InteriorStyle|Decoration|Lighting)Catalog"\) or ', '', s)
    assert n==4,n
    projected[profile]=s

    # The explicit composition list is the only executable startup authority.
    base='StarterPlayer.StarterPlayerScripts.ClientBase'
    s=projected[base]
    for name in ('DriveHudClient','FreeRoamNavUI'):
        s,n=re.subn(r'\{name=\[====\[\n'+name+r'\]====\],path=\[====\[\n[^\n]+\]====\],dependencies=\{\}\},?', '', s)
        assert n==1,(name,n)
    s=re.sub(r'(?<!\w)GarageClient(?!\w)','GarageUI',s)
    s=s.replace('local entries={','local entries={{name="DriveSessionClient",path="ReplicatedStorage.Modules.Game.Vehicles.DriveSessionClient",dependencies={}},',1)
    # GarageUI now starts directly and requires the driving handoff before it opens a workshop.
    marker='ReplicatedStorage.Modules.Game.Garage.GarageUI]====],dependencies={'
    assert s.count(marker)==1
    s=s.replace(marker,marker+'"DriveSessionClient",')
    projected[base]=s
    # Retire only helpers whose callers belonged exclusively to the disabled garage closure.
    retired=[
        'Core.ClientThemeAdapter','Game.Garage.GarageApiClient','Game.Garage.GarageState',
        'Game.Garage.PreviewInputClient','Game.UI.CockpitPaintUIUI','Game.UI.CustomisationUIUI',
        'Game.UI.DealershipUIUI','Game.UI.GaragePropertyMenuUI','Game.UI.NavigationUI',
        'Game.UI.StatsPanelUI','Game.UI.UIPool','Game.Vehicles.ReentryThrottle',
        'Game.Vehicles.Performance.PerformanceProjection','Game.Vehicles.VehicleData',
        'Game.Vehicles.VehicleStatsCache','Game.UI.ArrowScroller','Game.UI.ColourUtils',
        'Game.UI.ResponsiveLayout','Game.UI.StatBars','Game.Garage.CatalogClient',
        'Game.UI.ColourPickerUI','Game.Vehicles.Performance.PerformanceProjectionDefinitions',
        'Game.UI.ResponsiveUIFactory','Game.UI.UIFactory','Game.UI.ThemeValues',
    ]
    retirement={get(t) for t in retired}|{get('Game.Garage.GarageDisplay',True)}
    from path_analysis import tokens
    remaining_words=set(re.findall(r'\w+',' '.join(t[0] for p,s in projected.items() if p not in retirement for t in tokens(s))))
    for path in retirement:
        assert path.rsplit('.',1)[-1] not in remaining_words,('Retired helper still referenced',path)
        del projected[path]

    # Race endpoints belong to the feature runtime, never to an implementation module.
    server=get('Game.Garage.GarageServer',True)
    replace(server,'binding.Parent = script','binding.Parent = game:GetService("ServerStorage").Runtime.Garage')
    block(server,'\tlocal function V83_garageCatalog()','\tlocal function V83_startingGarageCapacity()',
          '\tlocal function V83_garageCatalog()\n\t\tif not V83_cachedGarageCatalog then V83_cachedGarageCatalog=require(game:GetService("ReplicatedStorage").Modules.Game.Garage.GaragePropertyCatalog) end\n\t\treturn V83_cachedGarageCatalog\n\tend\n\n\tlocal function V83_garageProperties()\n\t\treturn V83_garageCatalog().List()\n\tend\n\n\tlocal function V83_propertyById(propertyId)\n\t\treturn V83_garageCatalog().ById(tostring(propertyId or ""))\n\tend\n\n')
    for key in ('StartingCash','SpawnX','SpawnY','SpawnZ','PreviewX','PreviewY','PreviewZ'):
        replace(server,'V56_kit:GetAttribute("'+key+'")','game:GetService("ReplicatedStorage").Config.Garage:GetAttribute("'+key+'")')

    for path,source in list(projected.items()):
        if path.startswith('ReplicatedStorage.Modules.') and 'script:SetAttribute' in source:
            feature=path.split('.')[3] if path.startswith('ReplicatedStorage.Modules.Game.') else 'UI'
            source=source.replace('script:SetAttribute',expression(['StarterPlayer','StarterPlayerScripts','Runtime',feature])+':SetAttribute')
        if path.startswith('ReplicatedStorage.Modules.'):
            source=source.replace('script.Destroying',expression(['StarterPlayer','StarterPlayerScripts'])+'.Destroying')
        projected[path]=source
    # Readiness is player-local too; the reader must follow the migrated presenter state owner.
    replace(get('Game.Racing.RaceTransitionClient'),
            expression(['ReplicatedStorage','Modules','Game','Racing'])+':FindFirstChild("RaceCountdownPresentationClient")',
            expression(['StarterPlayer','StarterPlayerScripts','Runtime','Racing']))
    replace(get('Game.World.LODClient'),'reporter='+expression(['ReplicatedStorage','Modules','Game','World','LODClient']),
            'reporter='+expression(['StarterPlayer','StarterPlayerScripts','Runtime','World']))
    return projected
