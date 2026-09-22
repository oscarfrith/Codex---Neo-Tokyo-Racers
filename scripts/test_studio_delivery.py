import tempfile
import unittest
from pathlib import Path
import studio_delivery as delivery

class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        (self.root/'before.lua').write_bytes(b'return 1\r\n')
        (self.root/'after.lua').write_bytes('return "é"\n'.encode())
        self.path=['ReplicatedStorage','Example']
        self.record=dict(path_parts=self.path,class_name='ModuleScript',file='before.lua',attributes={})
        self.baseline=dict(manifest=[self.record],hierarchy=[dict(self.record,children=[])],place_id=121304917315753,content_sha256='test')
        self.spec=dict(task='test',lane='Fast',verification='Focused check',operations=[dict(kind='source',path=self.path,file='after.lua')])
    def build(self): return delivery.build(self.spec,self.baseline,self.root)
    def test_exact_bytes(self):
        op=self.build()['operations'][0]
        self.assertEqual(op['before'],'return 1\r\n'); self.assertEqual(op['after'],'return "é"\n')
        self.assertIn('\\195\\169',delivery.lua(op['after']))
    def test_duplicate(self):
        self.spec['operations']*=2
        with self.assertRaises(ValueError): self.build()
    def test_ambiguous(self):
        self.baseline['manifest']*=2
        with self.assertRaises(ValueError): self.build()
    def test_missing(self):
        self.baseline['manifest']=[]
        with self.assertRaises(ValueError): self.build()
    def test_boundary(self):
        self.spec['operations'][0]['path']=['Workspace','WIP']
        with self.assertRaises(ValueError): self.build()
    def test_escape(self):
        self.spec['operations'][0]['file']='../outside.lua'
        with self.assertRaises(ValueError): self.build()
    def test_contract(self):
        self.spec['lane']='High-Risk'
        with self.assertRaises(ValueError): self.build()
        self.spec['contract']='Authoritative owner reviewed'; self.build()
    def test_attribute_removal(self):
        self.record['attributes']={'Example':dict(type='number',value=2)}
        self.baseline['hierarchy'][0]['attributes']=self.record['attributes']
        self.spec['operations']=[dict(kind='attribute',path=self.path,key='Example',value=None)]
        self.assertEqual(self.build()['operations'][0]['before'],2)
    def test_nonfinite(self):
        self.spec['operations']=[dict(kind='attribute',path=self.path,key='Example',value=float('nan'))]
        with self.assertRaises(ValueError): self.build()
    def test_mode(self):
        with self.assertRaises(ValueError): delivery.render(self.build(),'INSTALL')

if __name__=='__main__': unittest.main()
