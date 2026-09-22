"""Failure-oriented scoped capture tests; disposable files, no Studio writes."""
import base64,copy,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import studio_capture as c

def fixture():
    source='-- café\nreturn 7\n';raw=source.encode()
    rec=dict(id='script_0001',name='Example',path='ReplicatedStorage.Example',path_parts=['ReplicatedStorage','Example'],class_name='ModuleScript',disabled=False,attributes={},source_lines=3,source_bytes=len(raw),source_checksum=str(sum(i*b for i,b in enumerate(raw,1))%1000000007),source_base64=base64.b64encode(raw).decode())
    node={k:v for k,v in rec.items() if k not in ('id','source_base64','source_bytes')};node.update(script_id=rec['id'],properties={},children=[],tags=[])
    root=dict(name='Config',class_name='Folder',path='ReplicatedStorage.Config',path_parts=['ReplicatedStorage','Config'],attributes={},properties={},tags=['Example'],children=[])
    return dict(format='SPACE_RACERS_SCOPED_CAPTURE',schema_revision=1,place_id=121304917315753,export_mode='Edit',request={'roots':[root['path_parts']],'token':'a'*32},services_scanned=sorted(c.SERVICES),include_disabled_scripts=True,diagnostics={'property_read_errors':[]},property_schema={},generated_in_studio='fixture',hierarchy=[root],missing_roots=[],source_nodes=[node],scripts=[rec],script_count=1)

class CaptureTests(unittest.TestCase):
    def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
    def saved(self,p=None,name='before'):
        path=c.save(p or fixture(),name,self.root);return c.load(path,self.root)
    def test_roundtrip_and_dedup(self):
        a=self.saved();b=self.saved(name='after');self.assertEqual(len(list((self.root/'roblox/source_store').glob('*.lua'))),1)
        self.assertEqual(c.compare(a,b)['nodesAddedOrChanged'],0)
    def test_wrong_place_mode_and_schema(self):
        for key,value in [('place_id',1),('export_mode','Client'),('schema_revision',2)]:
            p=fixture();p[key]=value
            with self.assertRaises(ValueError):c.save(p,'bad',self.root)
        self.assertFalse((self.root/'roblox').exists())
    def test_bad_source_rejected(self):
        p=fixture();p['scripts'][0]['source_base64']=base64.b64encode(b'corrupted').decode()
        with self.assertRaises(ValueError):c.save(p,'bad',self.root)
    def test_missing_inventory_service(self):
        p=fixture();p['services_scanned'].pop()
        with self.assertRaises(ValueError):c.validate(p)
    def test_duplicate_source_rejected(self):
        p=fixture();p['scripts']*=2;p['script_count']=2
        with self.assertRaises(ValueError):c.validate(p)
    def test_scope_missing_requires_explicit_record(self):
        p=fixture();p['hierarchy']=[]
        with self.assertRaises(ValueError):c.validate(p)
        p['missing_roots']=p['request']['roots'];c.validate(p)
    def test_out_of_scope_and_missing_tags(self):
        p=fixture();p['hierarchy'][0]['children']=[dict(p['hierarchy'][0],path_parts=['Workspace','Bad'])]
        with self.assertRaises(ValueError):c.validate(p)
        p=fixture();del p['hierarchy'][0]['tags']
        with self.assertRaises(ValueError):c.validate(p)
    def test_overlap_rejected(self):
        r=fixture()['request'];r['roots'].append(['ReplicatedStorage'])
        with self.assertRaises(ValueError):c.producer(r)
    def test_property_read_failure(self):
        p=fixture();p['diagnostics']['property_read_errors']=['denied']
        with self.assertRaises(ValueError):c.validate(p)
    def test_no_overwrite_and_slug_escape(self):
        a=self.saved()
        for name in ['before','../escape']:
            with self.assertRaises(ValueError):c.save(fixture(),name,self.root)
        self.assertEqual(a,c.load(self.root/'roblox/captures/before/capture.json',self.root))
    def test_atomic_failure_keeps_prior_capture(self):
        self.saved()
        with patch.object(c.os,'replace',side_effect=OSError('locked')):
            with self.assertRaises(OSError):c.save(fixture(),'after',self.root)
        c.load(self.root/'roblox/captures/before/capture.json',self.root)
        self.assertFalse((self.root/'roblox/captures/after/capture.json').exists())
    def test_corrupt_blob_or_record(self):
        a=self.saved();file=self.root/a['manifest'][0]['file'];file.write_text('wrong')
        with self.assertRaises(ValueError):c.load(self.root/'roblox/captures/before/capture.json',self.root)
    def test_capture_digest(self):
        self.saved();path=self.root/'roblox/captures/before/capture.json';p=json.loads(path.read_text());p['place_id']=0;path.write_text(json.dumps(p))
        with self.assertRaises(ValueError):c.load(path,self.root)
    def test_diffs_detect_source_metadata_tags_properties_removal(self):
        a=self.saved();p=fixture();p['scripts'][0]['disabled']=True;p['source_nodes'][0]['disabled']=True
        p['hierarchy'][0]['tags']=['Changed'];p['hierarchy'][0]['properties']={'Value':{'type':'number','value':2}}
        b=self.saved(p,'after');d=c.compare(a,b)
        self.assertEqual(len(d['sourceChanged']),1);self.assertEqual(d['nodesRemovedOrChanged'],1)
        p=fixture();p['missing_roots']=p['request']['roots'];p['hierarchy']=[]
        self.assertEqual(c.compare(a,self.saved(p,'removed'))['nodesRemovedOrChanged'],1)
    def test_multisets_and_coverage(self):
        a=self.saved();p=fixture();child=copy.deepcopy(p['hierarchy'][0]);child.update(name='Duplicate',path_parts=['ReplicatedStorage','Config','Duplicate'],path='ReplicatedStorage.Config.Duplicate')
        p['hierarchy'][0]['children']=[child,copy.deepcopy(child)]
        b=self.saved(p,'after');self.assertEqual(c.compare(a,b)['nodesAddedOrChanged'],2)
        b['property_schema']={'different':[]}
        with self.assertRaises(ValueError):c.compare(a,b)
    def test_chunk_reordering_duplicate_conflict_nonce_bounds(self):
        m={'token':'a','index':2,'total':2,'data':'1}'};a=c.Assembler('a');self.assertIsNone(a.add(m));self.assertIsNone(a.add(m))
        self.assertEqual(a.add(dict(m,index=1,data='{"x":')),{'x':1})
        for bad in [dict(m,data='different'),dict(m,token='b'),dict(m,total=3),dict(m,index=0),dict(m,data='x'*200001)]:
            with self.assertRaises(ValueError):a.add(bad)
    def test_builder_reuses_serializer_and_read_only_asserts(self):
        r=fixture()['request'];r['properties']={'BasePart':['Reflectance']};source=c.producer(r)
        self.assertIn('EXPECTED_PLACE_ID = 121304917315753',source);self.assertIn('export the Edit datamodel',source)
        self.assertIn('CollectionService',source);self.assertNotIn('Instance.new(',source)
        self.assertNotIn('.Source =',source)
    def test_source_text_add_remove_and_metadata(self):
        a=self.saved();p=fixture();r=p['scripts'][0];raw=b'return 8\n'
        r.update(source_base64=base64.b64encode(raw).decode(),source_bytes=len(raw),source_lines=2,source_checksum=str(sum(i*b for i,b in enumerate(raw,1))%1000000007))
        p['source_nodes'][0].update(source_lines=2,source_checksum=r['source_checksum'],tags=['Changed'])
        b=self.saved(p,'changed');self.assertEqual(len(c.compare(a,b)['sourceChanged']),1)
        p=fixture();r=copy.deepcopy(p['scripts'][0]);r.update(id='script_0002',name='Added',path='ReplicatedStorage.Added',path_parts=['ReplicatedStorage','Added'])
        n=copy.deepcopy(p['source_nodes'][0]);n.update(script_id=r['id'],name=r['name'],path=r['path'],path_parts=r['path_parts'])
        p['scripts'].append(r);p['source_nodes'].append(n);p['script_count']=2
        b=self.saved(p,'added');self.assertEqual(c.compare(a,b)['sourceAdded'],[r['path_parts']]);self.assertEqual(c.compare(b,a)['sourceRemoved'],[r['path_parts']])
    def test_detailed_attribute_records(self):
        a=self.saved();p=fixture();p['hierarchy'][0]['attributes']={'Tuning':{'type':'number','value':5}}
        b=self.saved(p,'after');d=c.compare(a,b,True)
        self.assertEqual(d['addedOrChangedRecords'][0]['node']['attributes']['Tuning']['value'],5)
    def test_projection_consumes_capture_and_rejects_stale_outputs(self):
        import sys
        sys.path.insert(0,str(c.ROOT/'scripts/performance_phase4'))
        from check_projection import check
        original=c.load(c.ROOT/'roblox/captures/workflow-phase2-check-b/capture.json')
        self.assertTrue(check(original,original['manifest'])['previewProjectionFresh'])
        p=copy.deepcopy(original)
        node=next(n for n in c.nodes(p['hierarchy']) if n['path_parts'][:3]==c.VEHICLES[0] and 'CockpitId' in (n['attributes'] or {}))
        node['attributes']['Price']={'type':'number','value':9999999}
        with self.assertRaises(AssertionError):check(p,p['manifest'])
        p=copy.deepcopy(original)
        node=next(n for n in c.nodes(p['hierarchy']) if n['path_parts'][:3]==c.VEHICLES[1] and 'CanCollide' in (n['properties'] or {}))
        node['properties']['CanCollide']['value']=not node['properties']['CanCollide']['value']
        with self.assertRaises(AssertionError):check(p,p['manifest'])
    def test_unicode_scope_and_crlf_source_bytes(self):
        r=fixture()['request'];r['roots']=[['ReplicatedStorage','Café']]
        code=c.producer(r);self.assertIn('Caf\\\\u00e9',code)
        p=fixture();raw=b'return 7\r\n';r=p['scripts'][0]
        r.update(source_base64=base64.b64encode(raw).decode(),source_bytes=len(raw),source_lines=2,source_checksum=str(sum(i*b for i,b in enumerate(raw,1))%1000000007))
        p['source_nodes'][0].update(source_lines=2,source_checksum=r['source_checksum'])
        saved=self.saved(p);self.assertEqual((self.root/saved['manifest'][0]['file']).read_bytes(),raw)

if __name__=='__main__':unittest.main()
