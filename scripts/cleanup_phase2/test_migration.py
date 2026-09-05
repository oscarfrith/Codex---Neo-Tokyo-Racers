"""Regression checks for path migration hazards and gameplay-preservation invariants."""
import unittest,re,json
from prepare import ROOT,HERE,read
from path_analysis import rewrite,analyze,tokens

class PathMigrationTests(unittest.TestCase):
    def test_bindable_properties_are_not_child_lookups(self):
        src='local event=script.Parent:WaitForChild("Ready"); event.Event:Connect(function() end)'
        out,_,_=rewrite(src,['StarterPlayer','StarterPlayerScripts','Old','Controller'],
            {('StarterPlayer','StarterPlayerScripts','Old'):('StarterPlayer','StarterPlayerScripts','Runtime','UI')})
        self.assertIn('.Event:Connect',out);self.assertNotIn('WaitForChild("Event")',out)
        self.assertNotIn('WaitForChild("Controller")',out)

    def test_shadowed_module_is_not_treated_as_instance(self):
        src='local module=script.Parent:FindFirstChild("Input"); local function f() local ok,module=pcall(require,playerModule); return module.GetControls end'
        out,_,_=rewrite(src,['ReplicatedStorage','Old','Controller'],
            {('ReplicatedStorage','Old'):('ReplicatedStorage','Modules')})
        self.assertIn('module.GetControls',out)

    def test_optional_endpoint_remains_optional(self):
        src='local endpoint=script.Parent:FindFirstChild("Optional")'
        out,_,_=rewrite(src,['ServerScriptService','Old','Controller'],
            {('ServerScriptService','Old'):('ServerStorage','Runtime','Garage')})
        self.assertIn(':FindFirstChild("Optional")',out)

    def test_current_lod_uses_real_script_context(self):
        src=read(ROOT/'roblox/exported_scripts/ReplicatedStorage/Modules/Game/World/LODClient.module.lua')
        self.assertIn('require(script.Parent.LODPolicy)',src)
        self.assertNotIn('localscript=',src.replace(' ',''))
        self.assertIn('reporter=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("World")',src)

class ContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d=json.loads(read(HERE/'payload.json'))
        cls.sources={'.'.join(r['path']):r['source'] for r in cls.d['sources']}
        cls.before={'.'.join(r['path']):r['source'] for r in cls.d['beforeSources']}

    def test_no_retired_namespace_lookups_or_rebinding(self):
        old_roots=[('ServerScriptService','NeoTokyoRacers'),('StarterPlayer','StarterPlayerScripts','NeoTokyoRacersClient'),('ReplicatedStorage','NeoTokyoRacers','Shared','Modules')]
        failures=[]
        for path,source in self.sources.items():
            self.assertNotRegex(source,r'(?m)^local script\s*=')
            for _,_,resolved,_ in analyze(source,path.split('.'))[0]:
                if any(resolved[:len(root)]==root for root in old_roots):failures.append((path,resolved))
        self.assertEqual([],failures)

    def test_workspace_source_unchanged(self):
        for path,source in self.before.items():
            if path.startswith('Workspace.'):self.assertEqual(source,self.sources[path])

    def test_driving_numbers_and_current_lod_unchanged(self):
        for path in ['ReplicatedStorage.Modules.Game.Vehicles.DrivingClient','ReplicatedStorage.Modules.Game.Vehicles.VehicleDynamics']:
            numbers=lambda s:[t[0] for t in tokens(s) if re.fullmatch(r'\d+(?:\.\d+)?',t[0])]
            self.assertEqual(numbers(self.before[path]),numbers(self.sources[path]),path)
        for name in ('LODPolicy','LODRuntime'):
            path='ReplicatedStorage.Modules.Game.World.'+name
            self.assertEqual(self.before[path],self.sources[path])

    def test_profile_schema_only_moves_dependency_paths(self):
        old=self.before['ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data.PlayerProfileSchema']
        new=self.sources['ReplicatedStorage.Modules.Game.Player.PlayerProfileSchema']
        expected=old.replace('script.Parent:WaitForChild("VehicleCosmeticCatalog")','game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleCosmeticCatalog")')
        self.assertEqual(expected,new)
        for path in ('ServerStorage.Modules.Game.Player.ProfileStore','ServerStorage.Modules.Game.Player.ProfileCompatibility'):
            before=re.sub(r'(?m)^local script = [^\n]*\n','',self.before[path])
            self.assertEqual([t[0] for t in tokens(before)],[t[0] for t in tokens(self.sources[path])])

    def test_countdown_readiness_has_one_player_local_owner(self):
        owner='WaitForChild("Runtime"):WaitForChild("Racing")'
        writer=self.sources['ReplicatedStorage.Modules.Game.Racing.RaceCountdownPresentationClient']
        reader=self.sources['ReplicatedStorage.Modules.Game.Racing.RaceTransitionClient']
        self.assertIn(owner+':SetAttribute("NTR_CountdownPresentationReady",true)',writer)
        self.assertIn('local presenter = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):'+owner,reader)
        self.assertNotIn('FindFirstChild("RaceCountdownPresentationClient")',reader)

if __name__=='__main__':unittest.main()
