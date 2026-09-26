"""Build one canonical architecture-programme installer from a spec and a verified targeted capture.

Extends the guarded delivery model with creation/removal of new scripts. Never executes or publishes.
Operations:
  {"kind":"source","path":[...],"file":"scripts/..."}            existing script body (before from capture)
  {"kind":"module","path":[...],"class":"ModuleScript","file":..} new script; before = absent
  {"kind":"attribute","path":[...],"key":"K","value":v,"before":b} primitive attribute with explicit expected before
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import studio_capture as capture  # noqa: E402
from studio_delivery import lua  # noqa: E402

SCRIPT_CLASSES = ('ModuleScript', 'Script', 'LocalScript')


def _check_path(path):
    if not isinstance(path, list) or len(path) < 2 or any(not isinstance(x, str) or not x for x in path):
        raise ValueError('Invalid path')
    if path[0] not in capture.SERVICES or (path[0] == 'Workspace' and path[1:2] != ['World']):
        raise ValueError('Outside supported boundary')
    if path[:2] in (['ServerStorage', 'Archive'], ['ServerStorage', 'NeoTokyoRacers']):
        raise ValueError('Protected root')


def _read(rel):
    dest = (ROOT / rel).resolve()
    if not dest.is_relative_to(ROOT.resolve()):
        raise ValueError('Source outside repository')
    return dest.read_bytes().decode('utf8')


def build(spec, baseline):
    if spec.get('lane') not in ('Standard', 'High-Risk') or not spec.get('task') or not spec.get('verification') or not spec.get('contract'):
        raise ValueError('Task, lane, contract and verification required')
    if not spec.get('operations'):
        raise ValueError('Empty installer')
    manifest = baseline['manifest']
    ops, seen = [], set()
    for req in spec['operations']:
        path, kind = req['path'], req['kind']
        _check_path(path)
        identity = (tuple(path), req.get('key', ''))
        if identity in seen:
            raise ValueError('Duplicate operation')
        seen.add(identity)
        existing = [r for r in manifest if r['path_parts'] == path]
        if kind == 'source':
            if len(existing) != 1:
                raise ValueError('Source target missing or ambiguous: ' + '.'.join(path))
            rec = existing[0]
            ops.append(dict(kind='source', path=path, class_name=rec['class_name'],
                            before=_read(rec['file']), after=_read(req['file'])))
        elif kind == 'module':
            if existing:
                raise ValueError('Module already exists in capture: ' + '.'.join(path))
            if req.get('class', 'ModuleScript') not in SCRIPT_CLASSES:
                raise ValueError('Invalid script class')
            ops.append(dict(kind='module', path=path, class_name=req.get('class', 'ModuleScript'),
                            before=None, after=_read(req['file'])))
        elif kind == 'attribute':
            key, value, old = req['key'], req['value'], req.get('before')
            if not isinstance(key, str) or not key or key.startswith('RBX'):
                raise ValueError('Invalid attribute name')
            for v in (value, old):
                if v is not None and type(v) not in (str, bool, int, float):
                    raise ValueError('Non-primitive attribute')
                lua(v)
            ops.append(dict(kind='attribute', path=path, class_name=req['class'], key=key, before=old, after=value))
        else:
            raise ValueError('Unsupported kind')
    return dict(place_id=baseline['place_id'], capture_sha256=baseline['content_sha256'],
                task=spec['task'], lane=spec['lane'], operations=ops)


ENV = '''
local env = {
	placeId = game.PlaceId, isEdit = not game:GetService("RunService"):IsRunning(),
	resolve = function(op)
		local current = game
		for index, name in ipairs(op.path) do
			local found = nil
			for _, child in ipairs(current:GetChildren()) do
				if child.Name == name then assert(not found, "Ambiguous path: " .. table.concat(op.path, ".")); found = child end
			end
			if not found and op.kind == "module" and index == #op.path then return nil end
			assert(found, "Missing path: " .. table.concat(op.path, ".")); current = found
		end
		return current
	end,
	compile = function(source) return loadstring(source) end,
	read = function(target, op)
		if op.kind == "attribute" then return target:GetAttribute(op.key) end
		if target == nil then return nil end
		if op.kind == "module" then assert(#target:GetChildren() == 0, "New module acquired children; refusing") end
		return target.Source
	end,
	write = function(target, op, value)
		if op.kind == "attribute" then target:SetAttribute(op.key, value); return target end
		if op.kind == "module" then
			if value == nil then if target then target:Destroy() end; return nil end
			if target == nil then
				local parent = game
				for index = 1, #op.path - 1 do parent = parent:FindFirstChild(op.path[index]); assert(parent, "Missing parent") end
				target = Instance.new(op.class_name)
				target.Name = op.path[#op.path]
				target.Source = value
				target.Parent = parent
				return target
			end
		end
		target.Source = value
		return target
	end,
}
'''


def render(bundle, mode='AUDIT'):
    if mode not in ('AUDIT', 'APPLY', 'ROLLBACK'):
        raise ValueError('Invalid mode')
    engine = (ROOT / 'scripts/architecture/installer.lua').read_text(encoding='utf8')
    return ('-- Generated architecture installer: review spec and capture. No live text replacement.\n'
            'local run=(function()\n' + engine + '\nend)()\nlocal bundle=' + lua(bundle) + '\n' + ENV +
            'return run(bundle, ' + lua(mode) + ', env)\n')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('spec'); p.add_argument('capture'); p.add_argument('output')
    p.add_argument('--mode', choices=['AUDIT', 'APPLY', 'ROLLBACK'], default='AUDIT')
    a = p.parse_args()
    bundle = build(json.loads(Path(a.spec).read_text(encoding='utf8')), capture.load(a.capture))
    dest = Path(a.output).resolve()
    if not dest.is_relative_to((ROOT / 'scripts').resolve()):
        raise ValueError('Installer must be under scripts/')
    dest.write_text(render(bundle, a.mode), encoding='utf8', newline='\n')
    print(json.dumps(dict(task=bundle['task'], mode=a.mode, operations=len(bundle['operations']), output=str(dest))))


if __name__ == '__main__':
    main()
