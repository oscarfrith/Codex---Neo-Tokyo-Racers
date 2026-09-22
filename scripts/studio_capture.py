"""Read-only Studio captures. Immutable source blobs and atomically published scoped records.

Never imports into either full-mirror directory. Run `receive --help` for capture scope.
"""
from pathlib import Path
import argparse, base64, collections, copy, hashlib, json, os, re, secrets, time
from http.server import BaseHTTPRequestHandler, HTTPServer
import import_studio_snapshot as legacy

ROOT=Path(__file__).resolve().parents[1]
SERVICES={'ReplicatedFirst','ReplicatedStorage','ServerScriptService','ServerStorage','StarterPlayer','StarterGui','Workspace','Lighting','SoundService'}
VEHICLES=[['ServerStorage','Assets','Vehicles'],['ReplicatedStorage','Assets','VehiclePreviews']]
PRESETS={'sources':[], 'vehicles':VEHICLES, 'config':[['ReplicatedStorage','Config'],['ServerStorage','Config']]}

def canonical(v):return json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def digest(raw):return hashlib.sha256(raw).hexdigest()
def nodes(h):
    todo=list(h);out=[]
    while todo:
        n=todo.pop();out.append(n);todo.extend(n.get('children',[]))
    return out
def validate_request(r):
    if set(r)-{'roots','token','properties'} or not {'roots','token'}<=set(r) or not isinstance(r['roots'],list) or len(r['roots'])>32:raise ValueError('Invalid capture request')
    if not re.fullmatch('[a-f0-9]{32}',r['token']):raise ValueError('Invalid nonce')
    paths=[]
    for p in r['roots']:
        if not isinstance(p,list) or not p or p[0] not in SERVICES or any(not isinstance(x,str) or not x for x in p):raise ValueError('Invalid root path')
        if any(p[:len(q)]==q or q[:len(p)]==p for q in paths):raise ValueError('Overlapping roots')
        paths.append(p)
    extra=r.get('properties',{})
    if not isinstance(extra,dict) or len(extra)>32:raise ValueError('Invalid property coverage')
    for cls,names in extra.items():
        if not re.fullmatch('[A-Za-z][A-Za-z0-9]*',cls) or not isinstance(names,list) or len(names)>64 or any(not isinstance(n,str) or not re.fullmatch('[A-Za-z][A-Za-z0-9]*',n) for n in names):raise ValueError('Invalid property coverage')

def producer(request):
    validate_request(request)
    original=(ROOT/'scripts/studio_export_snapshot.lua').read_text(encoding='utf8')
    marker='local services = {}'
    if original.count(marker)!=1:raise ValueError('Shared serializer boundary changed; review builder')
    prefix=original.split(marker)[0]
    replacements={
        'local function makeNode(instance)':'local function makeNode(instance, shallow)',
        'local children = instance:GetChildren()':'if shallow then return node end\n\tlocal children = instance:GetChildren()',
        'properties = getProperties(instance),':'properties = getProperties(instance),\n\t\ttags = game:GetService("CollectionService"):GetTags(instance),',
    }
    for old,new in replacements.items():
        if prefix.count(old)!=1:raise ValueError('Shared serializer anchor changed; review builder')
        prefix=prefix.replace(old,new)
    encoded=json.dumps(json.dumps(request,ensure_ascii=True,separators=(',',':')))
    return prefix+'\nlocal request=HttpService:JSONDecode('+encoded+')\n'+(ROOT/'scripts/capture_scoped_tail.lua').read_text(encoding='utf8')

def validate(p):
    if p.get('format')!='SPACE_RACERS_SCOPED_CAPTURE' or p.get('schema_revision')!=1 or p.get('place_id')!=121304917315753 or p.get('export_mode')!='Edit':raise ValueError('Wrong place/mode/schema')
    validate_request(p['request'])
    if set(p['services_scanned'])!=SERVICES or not p.get('include_disabled_scripts'):raise ValueError('Incomplete source inventory')
    if p.get('diagnostics',{}).get('property_read_errors'):raise ValueError('Property read errors')
    roots=p['request']['roots'];found=[n['path_parts'] for n in p['hierarchy']];missing=p['missing_roots']
    if collections.Counter(map(tuple,found+missing))!=collections.Counter(map(tuple,roots)):raise ValueError('Incomplete root coverage')
    for tree in p['hierarchy']:
        scope=tree['path_parts']
        for n in nodes([tree]):
            path=n['path_parts']
            if path[:len(scope)]!=scope or n['path']!='.'.join(path) or n['name']!=path[-1]:raise ValueError('Node outside scope')
            if not isinstance(n.get('tags'),list) or any(not isinstance(t,str) for t in n['tags']):raise ValueError('Missing tag coverage')
            n['tags']=sorted(set(n['tags']))
            for child in n.get('children',[]):
                if child['path_parts'][:-1]!=path:raise ValueError('Broken hierarchy')
    # Reuse source validation with a synthetic service envelope; no mirror mutation.
    q=dict(p,format='STUDIO_SNAPSHOT_V1',hierarchy=[{'name':s,'children':[]} for s in sorted(SERVICES)])
    q['hierarchy'][0]['children']=p['source_nodes']
    sources=legacy.validate_payload(q)
    bypath={tuple(s.path_parts):s for s in sources}
    for n in p['source_nodes']:
        if n['path_parts'][0] not in SERVICES or not isinstance(n.get('tags'),list) or 'properties' not in n:raise ValueError('Incomplete source metadata')
        n['tags']=sorted(set(n['tags']))
    for n in nodes(p['hierarchy']):
        if n['class_name'] in ('Script','LocalScript','ModuleScript'):
            s=bypath.get(tuple(n['path_parts']))
            if not s or (n['source_checksum'],n['disabled'],n['class_name'])!=(s.source_checksum,s.disabled,s.class_name):raise ValueError('Scoped source/inventory mismatch')
    return sources

def atomic_write(path,raw):
    path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_name(path.name+'.'+secrets.token_hex(8)+'.tmp')
    try:
        if isinstance(raw,dict):
            legacy.write_hierarchy_json(temp,raw)
            with temp.open('r+b') as f:os.fsync(f.fileno())
        else:
            with temp.open('xb') as f:f.write(raw);f.flush();os.fsync(f.fileno())
        os.replace(temp,path)
    finally:
        if temp.exists():temp.unlink()

def save(p,name,root=ROOT):
    if not re.fullmatch('[a-z0-9][a-z0-9-]{0,79}',name):raise ValueError('Use a short capture slug')
    target=root/'roblox/captures'/name/'capture.json'
    if target.exists():raise ValueError('Capture exists; choose a new name')
    sources=validate(p)
    result=copy.deepcopy(p);result.pop('scripts');result.pop('source_nodes');result['request'].pop('token')
    result['manifest']=[]
    metadata={tuple(n['path_parts']):n for n in p['source_nodes']}
    for s in sorted(sources,key=lambda x:x.path_parts):
        raw=s.source.encode('utf8');sha=digest(raw)
        rel='roblox/source_store/'+sha+'.lua';dest=root/rel
        if dest.exists():
            if dest.read_bytes()!=raw:raise ValueError('Corrupt source store')
        else:atomic_write(dest,raw)
        node=metadata[tuple(s.path_parts)]
        result['manifest'].append(dict(roblox_path=s.roblox_path,path_parts=s.path_parts,class_name=s.class_name,disabled=s.disabled,attributes=s.attributes,properties=node['properties'],tags=node['tags'],source_sha256=sha,source_bytes=len(raw),file=rel))
    # IDs depend on traversal order; fingerprints/comparison use paths and source hashes.
    result['content_sha256']=digest(canonical(result).encode())
    atomic_write(target,result)
    return target

def load(path,root=ROOT):
    p=json.loads(Path(path).read_text(encoding='utf8'))
    sha=p.pop('content_sha256')
    if digest(canonical(p).encode())!=sha:raise ValueError('Capture integrity failed')
    p['content_sha256']=sha
    if p['format']!='SPACE_RACERS_SCOPED_CAPTURE' or p['schema_revision']!=1 or p['place_id']!=121304917315753 or p['export_mode']!='Edit':raise ValueError('Invalid capture')
    for r in p['manifest']:
        if not re.fullmatch('[a-f0-9]{64}',r['source_sha256']) or r['file']!='roblox/source_store/'+r['source_sha256']+'.lua':raise ValueError('Invalid source reference')
        raw=(root/r['file']).read_bytes()
        if digest(raw)!=r['source_sha256'] or len(raw)!=r['source_bytes']:raise ValueError('Source integrity failed')
    return p

def compare(before,after,details=False):
    if before['request']['roots']!=after['request']['roots'] or before['property_schema']!=after['property_schema']:raise ValueError('Incomparable coverage')
    def sources(p):return {tuple(r['path_parts']):(r['source_sha256'],r['class_name'],r['disabled'],canonical(r['attributes']),canonical(r['properties']),canonical(r['tags'])) for r in p['manifest']}
    a,b=sources(before),sources(after)
    def tree(p):return collections.Counter(canonical({k:v for k,v in n.items() if k not in ('children','script_id')}) for n in nodes(p['hierarchy']))
    x,y=tree(before),tree(after)
    result=dict(sourceAdded=[list(k) for k in sorted(b.keys()-a.keys())],sourceRemoved=[list(k) for k in sorted(a.keys()-b.keys())],sourceChanged=[list(k) for k in sorted(a.keys()&b.keys()) if a[k]!=b[k]],nodesRemovedOrChanged=sum((x-y).values()),nodesAddedOrChanged=sum((y-x).values()),missingBefore=before['missing_roots'],missingAfter=after['missing_roots'],coverage='All inventoried sources; selected subtrees only. Moves appear as remove/add, never inferred automatically.')
    if details:result.update(removedOrChangedRecords=[dict(count=n,node=json.loads(k)) for k,n in sorted((x-y).items())],addedOrChangedRecords=[dict(count=n,node=json.loads(k)) for k,n in sorted((y-x).items())])
    return result

class Assembler:
    def __init__(self,token):self.token=token;self.parts={};self.total=None;self.size=0
    def add(self,m):
        if m.get('token')!=self.token:raise ValueError('Wrong capture nonce')
        i,n,d=m['index'],m['total'],m['data']
        if type(i)!=int or type(n)!=int or not 1<=i<=n<=256 or not isinstance(d,str) or len(d.encode())>200000:raise ValueError('Invalid chunk')
        if self.total is not None and self.total!=n:raise ValueError('Changed chunk total')
        if i in self.parts and self.parts[i]!=d:raise ValueError('Conflicting duplicate chunk')
        self.total=n
        if i not in self.parts:self.size+=len(d.encode());self.parts[i]=d
        if self.size>46080000:raise ValueError('Capture too large')
        return json.loads(''.join(self.parts[k] for k in range(1,n+1))) if len(self.parts)==n else None

def receive(name,roots,timeout=600,properties=None):
    if not re.fullmatch('[a-z0-9][a-z0-9-]{0,79}',name) or (ROOT/'roblox/captures'/name/'capture.json').exists():raise ValueError('Capture name invalid or already exists')
    request=dict(roots=roots,token=secrets.token_hex(16))
    if properties:request['properties']=properties
    code=producer(request);assembler=Assembler(request['token'])
    state={'done':False,'error':None}
    class Handler(BaseHTTPRequestHandler):
        def setup(self):self.request.settimeout(10);super().setup()
        def log_message(self,*args):pass
        def reply(self,status,data):
            raw=data.encode();self.send_response(status);self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        def do_GET(self):
            if self.path!='/script':return self.reply(404,'Not found')
            self.reply(200,code)
        def do_POST(self):
            try:
                if self.path!='/chunk':raise ValueError('Invalid endpoint')
                size=int(self.headers.get('Content-Length',0))
                if not 0<size<=1024*1024:raise ValueError('Invalid body size')
                self.connection.settimeout(10)
                p=assembler.add(json.loads(self.rfile.read(size)))
                if p is not None:
                    if p['request']!=request:raise ValueError('Unexpected capture scope')
                    target=save(p,name);state['done']=True;print('PASS: '+str(target),flush=True)
                self.reply(200,'OK')
            except Exception as e:state['error']=str(e);self.reply(400,str(e))
    with HTTPServer(('127.0.0.1',8766),Handler) as server:
        server.timeout=1;end=time.monotonic()+timeout
        print('Ready. In Space Racers Edit via MCP/Command Bar: loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/script"))()',flush=True)
        while not state['done'] and not state['error'] and time.monotonic()<end:server.handle_request()
    if not state['done']:raise ValueError(state['error'] or 'Capture timed out; no capture published')

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    r=sub.add_parser('receive');r.add_argument('--name',required=True);r.add_argument('--preset',choices=PRESETS,default='sources');r.add_argument('--roots',help='JSON array of path-part arrays, instead of preset');r.add_argument('--properties',help='Additional property coverage, JSON class to property-name arrays')
    v=sub.add_parser('verify');v.add_argument('capture')
    c=sub.add_parser('compare');c.add_argument('before');c.add_argument('after');c.add_argument('--details',action='store_true')
    args=parser.parse_args()
    if args.command=='receive':receive(args.name,json.loads(args.roots) if args.roots else PRESETS[args.preset],properties=json.loads(args.properties) if args.properties else None)
    elif args.command=='verify':
        p=load(args.capture);print(json.dumps(dict(passIntegrity=True,sources=len(p['manifest']),roots=p['request']['roots'],nodes=len(nodes(p['hierarchy'])),time=p['generated_in_studio']),indent=2))
    else:print(json.dumps(compare(load(args.before),load(args.after),args.details),indent=2))
if __name__=='__main__':main()
