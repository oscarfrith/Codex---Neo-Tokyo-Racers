"""Failure-oriented tests. Uses disposable repo-local output, never the live mirror."""
import base64
import copy
import json
import os
import subprocess
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import import_studio_snapshot as pipeline


def fixture():
    source = '-- café\nreturn 7\n'
    raw = source.encode('utf-8')
    record = dict(id='script_0001', name='Example', path='ReplicatedStorage.Example',
                  path_parts=['ReplicatedStorage', 'Example'], class_name='ModuleScript', disabled=False,
                  attributes={}, source_lines=3, source_bytes=len(raw),
                  source_checksum=str(sum(i*b for i, b in enumerate(raw, 1)) % 1000000007),
                  source_base64=base64.b64encode(raw).decode('ascii'))
    roots = [dict(name=name, path=name, class_name=name, children=[]) for name in
             ['ReplicatedFirst', 'ReplicatedStorage', 'ServerScriptService', 'ServerStorage',
              'StarterPlayer', 'StarterGui', 'Workspace', 'Lighting', 'SoundService']]
    roots[1]['children'] = [dict(record, script_id=record['id'], children=[])]
    return dict(format=pipeline.EXPORT_START, place_id=121304917315753, script_count=1,
                services_scanned=[r['name'] for r in roots], include_disabled_scripts=True,
                hierarchy=roots, scripts=[record])


class PipelineTests(unittest.TestCase):
    def setUp(self):
        (pipeline.REPO_ROOT / 'tmp').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=pipeline.REPO_ROOT / 'tmp')
        self.root = Path(self.temp.name)
        self.scripts, self.snapshot = self.root / 'scripts', self.root / 'snapshot'
        for directory in [self.scripts, self.snapshot]:
            directory.mkdir()
            (directory / 'sentinel').write_text('original')

    def tearDown(self):
        self.temp.cleanup()

    def preserved(self):
        for directory in [self.scripts, self.snapshot]:
            self.assertEqual((directory / 'sentinel').read_text(), 'original')

    def test_roundtrip_unicode_sha_and_properties(self):
        payload = fixture()
        payload['schema_revision'] = 3
        payload['hierarchy'][1]['properties'] = {'Value': {'type': 'number', 'value': 3}}
        manifest = pipeline.import_payload(payload, self.scripts, self.snapshot)
        self.assertEqual(len(manifest[0]['source_sha256']), 64)
        self.assertEqual((pipeline.REPO_ROOT / manifest[0]['file']).read_text(encoding='utf-8'), '-- café\nreturn 7\n')
        saved = json.loads((self.snapshot / 'hierarchy.json').read_text())
        self.assertEqual(saved['hierarchy'][1]['properties']['Value']['value'], 3)

    def test_corruption_rejected_before_output_change(self):
        payload = fixture(); payload['scripts'][0]['source_bytes'] += 1
        with self.assertRaises(ValueError): pipeline.import_payload(payload, self.scripts, self.snapshot)
        self.preserved()

    @unittest.skipUnless(os.name == 'nt', 'Windows ACL regression')
    def test_staging_inherits_repository_access(self):
        original = pipeline.write_scripts
        observed = []
        def inspect(scripts, candidate, final):
            # Check before promotion: moving a private tempfile ACL does not
            # make its files readable by the user's GitHub Desktop account.
            env = dict(os.environ, SNAPSHOT_TEST_STAGE=str(candidate.parent))
            # Windows PowerShell must use its own modules when invoked from pwsh.
            env.pop('PSModulePath', None)
            result = subprocess.check_output([
                shutil.which('pwsh') or 'powershell', '-NoProfile', '-Command',
                '(Get-Acl -LiteralPath $env:SNAPSHOT_TEST_STAGE).AreAccessRulesProtected'
            ], env=env, text=True).strip()
            observed.append(result)
            return original(scripts, candidate, final)
        with patch.object(pipeline, 'write_scripts', inspect):
            pipeline.import_payload(fixture(), self.scripts, self.snapshot)
        self.assertEqual(observed, ['False'])

    def test_wrong_place_and_missing_service(self):
        for key, value in [('place_id', 72149467460773), ('services_scanned', [])]:
            payload = fixture(); payload[key] = value
            with self.assertRaises(ValueError): pipeline.import_payload(payload, self.scripts, self.snapshot)
        self.preserved()

    def test_duplicate_sources_rejected(self):
        payload = fixture(); payload['scripts'].append(copy.deepcopy(payload['scripts'][0])); payload['script_count'] = 2
        with self.assertRaises(ValueError): pipeline.import_payload(payload, self.scripts, self.snapshot)
        self.preserved()

    def test_missing_end_marker(self):
        with self.assertRaises(ValueError): pipeline.parse_payload(pipeline.EXPORT_START + '\n' + json.dumps(fixture()))

    def test_hierarchy_disagreement(self):
        payload = fixture(); payload['hierarchy'][1]['children'][0]['disabled'] = True
        with self.assertRaises(ValueError): pipeline.import_payload(payload, self.scripts, self.snapshot)
        self.preserved()

    def test_failed_second_promotion_restores_both_outputs(self):
        original = Path.rename
        def fail(source, target):
            if source.name == 'snapshot' and source.parent.name.startswith('.mirror-stage-'):
                raise OSError('simulated promotion failure')
            return original(source, target)
        with patch.object(Path, 'rename', fail):
            with self.assertRaises(OSError): pipeline.import_payload(fixture(), self.scripts, self.snapshot)
        self.preserved()

    def test_protected_and_overlapping_outputs_rejected(self):
        for target in [pipeline.REPO_ROOT, pipeline.REPO_ROOT / '.git' / 'mirror', self.scripts / 'nested']:
            with self.assertRaises(ValueError): pipeline.import_payload(fixture(), self.scripts, target)
        self.preserved()


if __name__ == '__main__': unittest.main()
