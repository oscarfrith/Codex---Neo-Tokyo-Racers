import tempfile
import unittest
from pathlib import Path
import validation_record as v

class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name); (self.root/'evidence.txt').write_text('observed',encoding='utf8')
    def record(self,key='tooling'):
        r=v.new_record('Test',[key])
        for f in ('build','changed','studio_action','capture','recovery','next_action'): r[f]='test'
        row=r['checks'][0];row.update(status='pass',observation='Observed',evidence=[v.artifact('evidence.txt',self.root)])
        row['context']=dict(session='s1',build='test',environment='Studio',device='desktop',input='mouse',time_utc='2026-09-22T20:00:00Z')
        return r
    def test_static(self): self.assertEqual(v.validate(self.record(),self.root)['open'],[])
    def test_pending_not_pass(self):
        r=self.record();r['checks'][0].update(status='pending',reason='Not run',next_action='Run focused test')
        self.assertEqual(v.validate(r,self.root)['open'],['tooling']);self.assertIn('OPEN',v.render(r,self.root))
    def test_changed_evidence(self):
        r=self.record();(self.root/'evidence.txt').write_text('changed',encoding='utf8')
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_outside(self):
        with self.assertRaises(ValueError):v.artifact('../outside.txt',self.root)
    def test_no_artifact(self):
        r=self.record();r['checks'][0]['evidence']=[]
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_duplicate(self):
        r=self.record();r['checks']*=2
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_no_relabel(self):
        r=self.record('startup');r['checks'][0]['kind']='static'
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_api_not_ui(self):
        r=self.record('garage');r['checks'][0]['context'].update(interaction='api',start_screen_active=True)
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_ui(self):
        r=self.record('startup');r['checks'][0]['context'].update(interaction='normal-ui',start_screen_active=False,visible_input_verified=True)
        self.assertEqual(v.validate(r,self.root)['open'],[])
    def test_emulator_not_device(self):
        r=self.record('device');r['checks'][0]['context'].update(interaction='normal-ui',start_screen_active=False,visible_input_verified=True)
        with self.assertRaises(ValueError):v.validate(r,self.root)
        r['checks'][0]['context']['environment']='physical-device';v.validate(r,self.root)
    def test_sandbox_not_save(self):
        r=self.record('persistence');r['checks'][0]['context'].update(environment='isolated-published',saving_enabled=False)
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_load(self):
        r=self.record('multiplayer');r['checks'][0]['context'].update(environment='isolated-published',players=1,required_players=15,minutes=30,required_minutes=30)
        with self.assertRaises(ValueError):v.validate(r,self.root)
        r['checks'][0]['context']['players']=15;v.validate(r,self.root)
    def test_stale_build(self):
        r=self.record('api');r['checks'][0]['context']['build']='old'
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_exclusion_reason(self):
        r=self.record();r['checks'][0]['status']='not-applicable'
        with self.assertRaises(ValueError):v.validate(r,self.root)
    def test_deferred_next(self):
        r=self.record('device');r['checks'][0].update(status='deferred',reason='No device',next_action='Arrange physical device',evidence=[])
        self.assertEqual(v.validate(r,self.root)['open'],['device'])

if __name__=='__main__':unittest.main()
