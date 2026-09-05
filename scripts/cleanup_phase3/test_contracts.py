"""Focused safeguards for the naming migration's non-literal dependencies."""
import unittest,json,re
from prepare import HERE,read

class NamingContracts(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.payload=json.loads(read(HERE/'payload.json'))
  cls.sources={'.'.join(r['path']):r for r in cls.payload['sources']}
 def test_camera_zoom_logic_is_unchanged(self):
  r=self.sources['ReplicatedStorage.Modules.Game.Vehicles.DrivingCameraClient']
  def block(s):return s[s.index('local function setLockedDistance'):s.index('local function restoreZoom')]
  self.assertEqual(block(r['before']),block(r['source']))
 def test_dynamic_driving_reader_uses_vehicle_feature(self):
  s=self.sources['ReplicatedStorage.Modules.Game.Vehicles.DrivingClient']['source']
  self.assertIn('config:WaitForChild("Vehicles"):FindFirstChild(name)',s)
  self.assertIn('configNumber("Dynamics"',s)
  self.assertIn('configNumber("Driving"',s)
 def test_tag_consumers_and_config_values_agree(self):
  for feature,tag in [('WindowMaterialClient','WindowMaterial'),('NightLamppostLightClient','NightLamppostLight')]:
   s=self.sources['ReplicatedStorage.Modules.Game.World.'+feature]['source']
   self.assertIn('"'+tag+'"',s)
   self.assertNotIn('"NTR_'+tag+'"',s)
  changes=[c for r in self.payload['metadata'] for c in r['changes']]
  for name,target in [('RoadSpawnTag','RoadSpawnPoint'),('ZoneTag','AudioContextZone')]:
   self.assertTrue(any(c['old']==name and c.get('afterValue',{}).get('value')==target for c in changes))
 def test_wip_allowlist_is_exact_and_tag_only(self):
  self.assertEqual(len(self.payload['wipTags']),62)
  for m in self.payload['moves']:
   if m['before'][0]=='Workspace':self.assertEqual(m['before'][1],'NeoTokyoRacersWorld')
  for m in self.payload['metadata']:
   if m['path'][0]=='Workspace':self.assertEqual(m['path'][1],'NeoTokyoRacersWorld')
 def test_protected_assets_are_not_retired(self):
  for n in self.payload['retired']:
   self.assertNotIn(n['class_name'],['Model','Part','MeshPart','UnionOperation','Attachment'])
   self.assertNotIn('VehiclePerformanceV2_Staging',n['path_parts'])
   self.assertNotIn('Archive',n['path_parts'])
 def test_optional_driving_defaults_remain_optional(self):
  s=self.sources['ReplicatedStorage.Modules.Game.Vehicles.DrivingClient']['source']
  self.assertIn(':FindFirstChild("CameraAssist")',s)
  self.assertNotIn(':WaitForChild("CameraAssist")',s)

if __name__=='__main__':unittest.main()
