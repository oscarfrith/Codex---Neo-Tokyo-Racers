"""Build one reviewable guarded delivery from a verified targeted capture.

Existing source bodies and primitive attributes only; never executes or publishes.
"""
import argparse
import json
import math
from pathlib import Path
import studio_capture as capture

ROOT = capture.ROOT

def lua(value):
    if value is None: return 'nil'
    if type(value) is bool: return 'true' if value else 'false'
    if type(value) in (int, float):
        if not math.isfinite(value): raise ValueError('Non-finite number')
        return repr(value)
    if isinstance(value, str):
        # Decimal byte escapes are valid Luau and preserve exact UTF-8/CRLF.
        return '"' + ''.join('\\%03d' % b for b in value.encode('utf8')) + '"'
    if isinstance(value, list): return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict): return '{' + ','.join('['+lua(k)+']='+lua(v) for k,v in value.items()) + '}'
    raise ValueError('Unsupported value')

def build(spec, baseline, root=ROOT):
    if spec.get('lane') not in ('Fast','Standard','High-Risk') or not spec.get('task') or not spec.get('verification'):
        raise ValueError('Task, semantic lane and verification required')
    if spec['lane'] != 'Fast' and not spec.get('contract'): raise ValueError('Connected work needs contract')
    if not spec.get('operations'): raise ValueError('Empty delivery')
    operations, seen = [], set()
    for request in spec['operations']:
        path = request['path']
        if not isinstance(path,list) or not path or any(not isinstance(x,str) or not x for x in path): raise ValueError('Invalid path')
        if path[0] not in capture.SERVICES or (path[0]=='Workspace' and path[1:2]!=['World']): raise ValueError('Outside supported boundary')
        if path[:2] in (['ServerStorage','Archive'],['ServerStorage','NeoTokyoRacers']): raise ValueError('Protected root')
        kind = request['kind']
        if kind not in ('source','attribute'): raise ValueError('Requires dedicated migration')
        key = request.get('key','') if kind=='attribute' else ''
        identity = (tuple(path),kind,key)
        if identity in seen: raise ValueError('Duplicate operation')
        seen.add(identity)
        pool = baseline['manifest'] if kind=='source' else capture.nodes(baseline['hierarchy'])
        matches = [r for r in pool if r['path_parts']==path]
        if len(matches)!=1: raise ValueError('Target missing, ambiguous or not captured')
        record = matches[0]
        op = dict(kind=kind,path=path,class_name=record['class_name'])
        if kind=='source':
            dest = (root/request['file']).resolve()
            if not dest.is_relative_to(root.resolve()): raise ValueError('Source outside repository')
            op.update(before=(root/record['file']).read_bytes().decode('utf8'),after=dest.read_bytes().decode('utf8'))
        else:
            if not isinstance(key,str) or not key or key.startswith('RBX'): raise ValueError('Invalid attribute name')
            old = dict(record['attributes']).get(key)
            if old and old['type'] not in ('string','boolean','number'): raise ValueError('Non-primitive attribute')
            value = request['value']
            if value is not None and type(value) not in (str,bool,int,float): raise ValueError('Non-primitive value')
            lua(value)
            op.update(key=key,before=old['value'] if old else None,after=value)
        operations.append(op)
    return dict(place_id=baseline['place_id'],capture_sha256=baseline['content_sha256'],task=spec['task'],lane=spec['lane'],operations=operations)

def render(bundle, mode='AUDIT'):
    if mode not in ('AUDIT','APPLY','ROLLBACK'): raise ValueError('Invalid mode')
    engine=(ROOT/'scripts/studio_delivery.lua').read_text(encoding='utf8')
    return '-- Generated delivery: review spec and before/after capture. No live text replacement.\nlocal run=(function()\n'+engine+'\nend)()\nlocal bundle='+lua(bundle)+'''\nlocal env = {
    placeId=game.PlaceId, isEdit=not game:GetService("RunService"):IsRunning(),
    resolve=function(path)
        local current=game
        for _, name in ipairs(path) do
            local found=nil
            for _, child in ipairs(current:GetChildren()) do
                if child.Name==name then assert(not found,"Ambiguous path"); found=child end
            end
            assert(found,"Missing path"); current=found
        end
        return current
    end,
    compile=function(source) return loadstring(source) end,
    read=function(target,op) if op.kind=="source" then return target.Source end return target:GetAttribute(op.key) end,
    write=function(target,op,value) if op.kind=="source" then target.Source=value else target:SetAttribute(op.key,value) end end,
}
return run(bundle, '''+lua(mode)+''', env)
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec'); parser.add_argument('capture'); parser.add_argument('output')
    parser.add_argument('--mode',choices=['AUDIT','APPLY','ROLLBACK'],default='AUDIT')
    args=parser.parse_args()
    spec=json.loads(Path(args.spec).read_text(encoding='utf8'))
    bundle=build(spec,capture.load(args.capture))
    dest=Path(args.output).resolve()
    if not dest.is_relative_to((ROOT/'scripts').resolve()): raise ValueError('Delivery must be under scripts/')
    dest.write_text(render(bundle,args.mode),encoding='utf8',newline='\n')
    print(json.dumps(dict(task=bundle['task'],mode=args.mode,operations=len(bundle['operations']),output=str(dest))))

if __name__=='__main__': main()
