"""Offline proof for the catalogue split. No Studio and no Lua binary.

Run:  py -3 scripts/exotic_category/catalogue/test_chunks.py
It checks that out/ on disk is the split form generated from the before capture (it does not rewrite out/;
build_stage_a_sources.py does, and this test builds out/ only when it is absent), then proves:
  (a) the legacy source and the merged split form evaluate to the same Cockpits and Modules
      (a small parser for the generated table-literal grammar; the index loop is matched as fixed text),
  (b) Revision is the expected one,
  (c) every source is under 190,000 characters,
  (d) both checker scripts pass on the before capture and report the legacy form; check_projection.check and
      source_form (the function both scripts call) accept exactly the legacy form or the split form and reject
      every malformed manifest; check_catalogue.py refuses a capture without the server vehicle root,
  (e) a second category (a renamed copy of Piercer with the opt-in attributes) leaves the Piercer chunks
      byte-identical and still merges to the projected data; chunk_sources refuses what catalogue_gen.lua refuses,
  (f) catalogue.py and catalogue_gen.lua carry the same whitelist, limits and fixed index and chunk text.
check_catalogue.py is a script, so its split-form path is covered through source_form: a split-form capture
needs blobs under roblox/source_store, which only a real capture after the install provides.
--emit-synthetic DIR also writes the two-category tree and the expected hashes for selftest_gen.lua.
"""
from pathlib import Path
import copy,hashlib,json,re,subprocess,sys,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
import build_stage_a_sources as stage
sys.path.insert(0,str(ROOT/'scripts/performance_phase4'))
import catalogue,studio_capture
from catalogue import project,chunk_sources,source_form,luau_safe,flat,DATA_PATH,OPT_IN
from check_projection import check
EXPECTED_REVISION='469d9bd81944a3d71a127ea1d5e702720b75f55524391cb27008e05e8fc2cf0e'
LIMIT=190000
# The generated text is pinned here, apart from catalogue.py, so a change to either side fails the test.
LEGACY_HEADER='-- GENERATED public catalogue; edit canonical model attributes, regenerate, then restart Play.'
INDEX_HEADER='-- GENERATED public catalogue index; edit canonical model attributes, regenerate, then restart Play.'
CHUNK_HEADER='-- GENERATED public catalogue chunk; edit canonical model attributes, regenerate, then restart Play.'
INDEX_LOOP=['\tlocal chunk=require(script:WaitForChild(name))',
            '\tfor _,kind in {"Cockpits","Modules"} do',
            '\t\tfor id,record in pairs(chunk[kind]) do',
            '\t\t\tassert(data[kind][id]==nil,"Duplicate catalogue id "..tostring(id).." in "..name)',
            '\t\t\tdata[kind][id]=record',
            '\t\tend',
            '\tend',
            'end']
FREEZE_LINES=['local function freeze(t) for _,v in pairs(t) do if type(v)=="table" then freeze(v) end end return table.freeze(t) end','return freeze(data)','']

# ---- Parser for the generated grammar: {["key"]=value,...} | {value,...} | {} | "string" | number | true | false | Color3.new(n,n,n)
EMPTY=('empty',)
NUMBER=re.compile(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?')
STRING=re.compile(r'"(?:[^"\\]|\\.)*"')
class Table(dict):
    """Keyed table. spans[key] is the (start,end) of the whole ["key"]=value entry in the parsed text."""
class Parser:
    def __init__(self,text,pos=0):self.t=text;self.i=pos
    def take(self,s):
        assert self.t.startswith(s,self.i),('expected',s,'at',self.i,self.t[self.i:self.i+40]);self.i+=len(s)
    def string(self):
        m=STRING.match(self.t,self.i);assert m,('string expected at',self.i,self.t[self.i:self.i+40])
        raw=m.group();self.i=m.end()
        # Only escapes that mean the same in JSON and in Luau.
        assert all(e in '"\\nrtbf' for e in re.findall(r'\\(.)',raw)),('escape Luau would not read the same way',raw)
        return json.loads(raw)
    def number(self):
        m=NUMBER.match(self.t,self.i);assert m,('number expected at',self.i,self.t[self.i:self.i+40]);self.i=m.end();return m.group()
    def value(self):
        t,i=self.t,self.i
        if t[i]=='{':return self.table()
        if t[i]=='"':return self.string()
        for word,result in (('true',True),('false',False)):
            if t.startswith(word,i):self.i+=len(word);return result
        if t.startswith('Color3.new(',i):
            self.i+=len('Color3.new(');parts=[]
            for n in range(3):parts.append(self.number());self.take(')' if n==2 else ',')
            return ('Color3',)+tuple(parts)
        return ('num',self.number())
    def table(self):
        self.take('{')
        if self.t[self.i]=='}':self.i+=1;return EMPTY
        keyed=self.t[self.i]=='[';out=Table() if keyed else []
        if keyed:out.spans={}
        while True:
            if keyed:
                start=self.i;self.take('[');key=self.string();self.take(']=')
                assert key not in out,('duplicate key',key)
                out[key]=self.value();out.spans[key]=(start,self.i)
            else:out.append(self.value())
            if self.t[self.i]==',':self.i+=1;continue
            self.take('}');return out
def literal(line,prefix):
    assert line.startswith(prefix),(prefix,line[:60])
    p=Parser(line,len(prefix));v=p.value();assert p.i==len(line),('trailing text',line[p.i:p.i+40]);return v
def norm(v):
    """project() data in the parser's value model."""
    if isinstance(v,dict):
        if v.get('type')=='Color3':return ('Color3',repr(v['r']),repr(v['g']),repr(v['b']))
        return {k:norm(x) for k,x in v.items()} or EMPTY
    if isinstance(v,list):return [norm(x) for x in v] or EMPTY
    if isinstance(v,bool):return v
    if isinstance(v,(int,float)):return ('num',json.dumps(v))
    assert isinstance(v,str),type(v);return v

# ---- Evaluation of the two source forms
def evaluate_legacy(source):
    lines=source.split('\n')
    assert len(lines)==5 and lines[0]==LEGACY_HEADER and lines[2:]==FREEZE_LINES,'legacy source shape'
    return literal(lines[1],'local data=')
def evaluate_split(index,children):
    """What the index returns, given its children {name: source}; also each record's exact text."""
    lines=index.split('\n')
    assert len(lines)==14 and lines[0]==INDEX_HEADER and lines[3:11]==INDEX_LOOP and lines[11:]==FREEZE_LINES,'index source shape'
    data=literal(lines[1],'local data=')
    assert set(data)=={'Cockpits','Modules','Revision','SchemaVersion'} and data['Cockpits']==EMPTY and data['Modules']==EMPTY,'index data shape'
    assert lines[2].endswith(' do');names=literal(lines[2][:-3],'for _,name in ')
    assert isinstance(names,list) and all(isinstance(n,str) for n in names) and len(set(names))==len(names),'chunk name list'
    merged={'Cockpits':{},'Modules':{}};texts={'Cockpits':{},'Modules':{}}
    for name in names:
        assert name in children,'script:WaitForChild would never return: '+name
        chunk_lines=children[name].split('\n')
        assert len(chunk_lines)==3 and chunk_lines[0]==CHUNK_HEADER and chunk_lines[2]=='','chunk source shape '+name
        chunk=literal(chunk_lines[1],'return ')
        assert set(chunk)=={'Cockpits','Modules'},'chunk keys '+name
        for kind in ('Cockpits','Modules'):
            block=chunk[kind]
            for key in ([] if block==EMPTY else block):
                assert key not in merged[kind],'Duplicate catalogue id '+key+' in '+name
                merged[kind][key]=block[key];a,b=block.spans[key];texts[kind][key]=chunk_lines[1][a:b]
    assert set(children)==set(names),('chunk children the index never requires',sorted(set(children)-set(names)))
    return dict(Cockpits=merged['Cockpits'] or EMPTY,Modules=merged['Modules'] or EMPTY,Revision=data['Revision'],SchemaVersion=data['SchemaVersion']),texts,names
def revision_of(data):
    return hashlib.sha256(json.dumps({k:v for k,v in data.items() if k!='Revision'},sort_keys=True,separators=(',',':')).encode()).hexdigest()

# ---- A second category for the packing and opt-in tests
def exotic_id(value):
    out=value.replace('BRUISER','EXOTIC').replace('bruiser','exotic')
    return out if out!=value else value+'_EXOTIC'
ODD={'Price':1000000000000000,'NeonPrice':9007199254740991,'TopSpeed':0.0001,'Weight':0.30000000000000004,'EngineOutput':-0.03,'Drag':123456789.125,
     'DisplayName':'Quote " Back\\slash Tab\t New\nline ~ end'}
def two_categories(h):
    """Authoring tree with EXOTIC: a renamed copy of PIERCER carrying the opt-in attributes and awkward values."""
    hierarchy=stage.authoring(h);tree=hierarchy['hierarchy'][0]
    categories=next(n for n in tree['children'] if n['name']=='Categories')
    piercer=next(n for n in categories['children'] if n['name']=='PIERCER')
    exotic=copy.deepcopy(piercer);depth=len(piercer['path_parts'])-1
    for n in flat({'hierarchy':[exotic]}):
        n['path_parts'][depth]='EXOTIC';n['path']='.'.join(n['path_parts'])
        if len(n['path_parts'])==depth+1:n['name']='EXOTIC'
        a=n.get('attributes') or {}
        if n['class_name']!='Model' or not ('CockpitId' in a or 'ModuleId' in a):continue
        for k,v in a.items():
            if k in ('CockpitId','ModuleId','SourceCockpitId') or (k.startswith('Default') and k.endswith('ModuleId')):v['value']=exotic_id(v['value'])
        a['CategoryId']={'type':'string','value':'exotic'}
        if 'CockpitId' in a:
            for i,name in enumerate(x for x in OPT_IN if x.startswith('Default')):a[name]={'type':'string','value':exotic_id('MODULE_FRONTBUMPER_LVL%d'%(i%3+1))}
        else:
            a['RatingReferenceCockpitId']={'type':'string','value':'exotic_03'}
            if a['ModuleId']['value']=='MODULE_BOOST_EXOTIC_01_POWER':
                for k,v in ODD.items():a[k]={'type':'string' if isinstance(v,str) else 'number','value':v}
    categories['children'].append(exotic)
    return hierarchy
def slim(node):
    """The part of a node that the generator reads, for selftest_gen.lua."""
    out=dict(n=node['name'],c=node['class_name'])
    if node.get('attributes'):out['a']=node['attributes']
    if node['class_name']=='StringValue':out['v']=node['properties']['Value']['value']
    kids=[slim(c) for c in node.get('children',[]) if c['class_name'] in ('Model','Folder','StringValue')]
    if kids:out['k']=kids
    return out

# ---- catalogue_gen.lua read as text: the whitelist and the fixed text it carries
GEN_SHAPE=['local RAW = string.split(LIST, " ")',
           'for _, x in RAW do PUBLIC[x] = true; PUBLIC["PerformanceDelta_" .. x] = true; PATH_KEYS["DeltaFraction_" .. x] = true; PATH_KEYS["DeltaFlat_" .. x] = true end',
           'for _, x in string.split(LIST, " ") do PUBLIC[x] = true end',
           'for _, x in string.split(LIST, " ") do assert(not PUBLIC[x], x); PUBLIC[x] = true end',
           'for i = 1, 6 do PUBLIC["Point" .. i .. "CostGuide"] = true; PATH_KEYS["Point" .. i .. "CostGuide"] = true end',
           'for _, x in { "PathId", "DisplayName", "MaxPoints" } do PATH_KEYS[x] = true end']
def luau_string(text,name):
    """The value of a one-line Luau string constant."""
    m=re.search(r'^local '+name+r' = (["\'])(.*)\1$',text,re.M);assert m,'catalogue_gen.lua constant not found: '+name
    assert all(e in 'nt"\'\\' for e in re.findall(r'\\(.)',m.group(2))),name
    return re.sub(r'\\(.)',lambda e:{'n':'\n','t':'\t'}.get(e.group(1),e.group(1)),m.group(2))
def luau_generator(text):
    """What catalogue_gen.lua carries by hand: RAW, PUBLIC, PATH_KEYS, OPT_IN, the limits and the fixed text."""
    lists=[x.split(' ') for x in re.findall(r'string\.split\("([^"]+)", " "\)',text)]
    assert len(lists)==3,'catalogue_gen.lua whitelist layout changed'
    # The lines that fill the two sets are pinned, so a new name or a new loop on the Luau side fails here.
    shape=re.sub(r'string\.split\("[^"]+", " "\)','string.split(LIST, " ")',text)
    for line in GEN_SHAPE:assert shape.count('\n'+line+'\n')==1,'catalogue_gen.lua whitelist layout changed: '+line
    assert len(re.findall(r'\b(?:PUBLIC|PATH_KEYS)\[[^\]]+\] = true',text))==9,'catalogue_gen.lua fills its whitelist somewhere else too'
    raw,names,opt_in=lists;points={'Point%dCostGuide'%i for i in range(1,7)}
    limits=re.search(r'^local CHUNK_FILL, SOURCE_LIMIT = (\d+), (\d+)$',text,re.M);assert limits,'catalogue_gen.lua limits not found'
    return dict(RAW=raw,OPT_IN=opt_in,
                PUBLIC=set(raw)|{'PerformanceDelta_'+x for x in raw}|set(names)|set(opt_in)|points,
                PATH_KEYS={'PathId','DisplayName','MaxPoints'}|{'DeltaFraction_'+x for x in raw}|{'DeltaFlat_'+x for x in raw}|points,
                CHUNK_FILL=int(limits.group(1)),SOURCE_LIMIT=int(limits.group(2)),
                **{name:luau_string(text,name) for name in ('INDEX_HEADER','CHUNK_HEADER','MERGE','FREEZE')})

def fails(fn,*args):
    try:fn(*args)
    except AssertionError:return True
    return False
def main():
    results={}
    generated=stage.generate();h,data,legacy,sources=generated
    # out/ as it was on disk before this run. Built here only when it is absent; never rewritten.
    out_files=stage.render(generated)[2]
    built=not stage.OUT.is_dir()
    if built:stage.write()
    problems=stage.stale(out_files)
    assert not problems,'out/ is not the generated split form ('+'; '.join(problems)+'); run build_stage_a_sources.py'
    results['outWasCurrent']='absent, built by this run' if built else True
    out_manifest=json.loads((stage.OUT/'manifest.json').read_text(encoding='utf8'))
    files={r['name']:(ROOT/r['file']).read_bytes().decode('utf8') for r in out_manifest}
    assert [(r['name'],files[r['name']]) for r in out_manifest]==sources,'out/ is not the generated split form; run build_stage_a_sources.py'
    assert all(hashlib.sha256(files[r['name']].encode()).hexdigest()==r['sha256'] and len(files[r['name']])==r['chars'] for r in out_manifest)
    row=next(r for r in h['manifest'] if r['path_parts']==DATA_PATH)
    before=(ROOT/row['file']).read_bytes().decode('utf8')
    index=files[DATA_PATH[-1]];children={n:s for n,s in files.items() if n!=DATA_PATH[-1]}

    # project() and the whitelist: today's output is unchanged and no existing model carries an opt-in name.
    assert legacy==before and hashlib.sha256(legacy.encode()).hexdigest()==row['source_sha256'],'project() no longer reproduces the before blob'
    assert set(OPT_IN)<=catalogue.PUBLIC
    carried=sorted({k for n in flat(h) for k in (n.get('attributes') or {}) if k in OPT_IN})
    assert not carried,carried
    results['projectUnchanged']=dict(legacyChars=len(legacy),legacySha256=row['source_sha256'],optInNamesOnExistingModels=carried)

    # (a) deep equality
    old=evaluate_legacy(before);new,texts,names=evaluate_split(index,children)
    assert old==norm(data),'parser and project() disagree on the legacy source'
    assert set(old)=={'Cockpits','Modules','Revision','SchemaVersion'}
    for kind in ('Cockpits','Modules'):assert old[kind]==new[kind],kind+' differ'
    assert old==new,'merged split form differs from the legacy data'
    rebuilt=LEGACY_HEADER+'\nlocal data={'+','.join('["%s"]={%s}'%(kind,','.join(texts[kind][k] for k in sorted(texts[kind]))) for kind in ('Cockpits','Modules'))+',["Revision"]='+json.dumps(new['Revision'])+',["SchemaVersion"]='+new['SchemaVersion'][1]+'}\n'+'\n'.join(FREEZE_LINES)
    assert rebuilt==before,'record text in the chunks is not the legacy record text'
    results['a_deepEquality']=dict(identical=True,cockpits=len(new['Cockpits']),modules=len(new['Modules']),legacyRebuiltFromChunkTextByteIdentical=True,chunks=names)

    # (b) revision
    assert data['Revision']==EXPECTED_REVISION==new['Revision']==old['Revision']==revision_of(data)
    results['b_revision']=new['Revision']

    # (c) size
    sizes={name:len(text) for name,text in sources}
    assert all(n<LIMIT for n in sizes.values()) and all(text.isascii() for _,text in sources)
    results['c_chars']=dict(sizes,limit=LIMIT,legacy=len(before))

    # (d) checkers on the before capture, then on the split form
    capture=str(stage.CAPTURE)
    ran={}
    for script in ('scripts/performance_phase4/check_projection.py','scripts/performance_phase3/check_catalogue.py'):
        p=subprocess.run([sys.executable,str(ROOT/script),'--capture',capture],capture_output=True,text=True,cwd=str(ROOT))
        assert p.returncode==0,(script,p.stderr[-2000:])
        ran[script]=json.loads(p.stdout)
    assert ran['scripts/performance_phase4/check_projection.py']['catalogueForm']=='legacy' and ran['scripts/performance_phase4/check_projection.py']['previewProjectionFresh'] is True
    assert ran['scripts/performance_phase3/check_catalogue.py']=={'pass':True,'form':'legacy','revision':EXPECTED_REVISION,'cockpits':6,'modules':116}
    results['d_checkersOnBeforeCapture']=ran
    others=[r for r in h['manifest'] if r['path_parts'][:len(DATA_PATH)]!=DATA_PATH]
    split_rows=[dict(path_parts=r['path_parts'],class_name=r['class_name'],file=r['file']) for r in out_manifest]
    def with_rows(rows):return others+rows
    assert check(h,h['manifest'])['catalogueForm']=='legacy'
    assert check(h,with_rows(split_rows))['catalogueForm']=='split'
    legacy_row=dict(path_parts=DATA_PATH,class_name='ModuleScript',file=row['file'])
    def chunk_row(name,file=None,cls='ModuleScript'):return dict(path_parts=DATA_PATH+[name],class_name=cls,file=file or next(r['file'] for r in out_manifest if r['name']==name))
    rejected={
        'no catalogue row':others,
        'missing chunk':split_rows[:-1],
        'index only':split_rows[:1],
        'extra chunk':split_rows+[chunk_row('PIERCER_3',split_rows[2]['file'])],
        'extra nested row':split_rows+[dict(path_parts=DATA_PATH+['PIERCER_1','Inner'],class_name='ModuleScript',file=split_rows[1]['file'])],
        'stale chunk':[split_rows[0],split_rows[1],chunk_row('PIERCER_2',split_rows[1]['file'])],
        'stale index':[dict(split_rows[0],file=split_rows[1]['file'])]+split_rows[1:],
        'legacy index with chunks':[legacy_row]+split_rows[1:],
        'legacy index with one stray child':[legacy_row,chunk_row('PIERCER_1')],
        'split index as legacy':[dict(legacy_row,file=split_rows[0]['file'])],
        'chunk is not a ModuleScript':[split_rows[0],split_rows[1],chunk_row('PIERCER_2',cls='Script')],
        'index is not a ModuleScript':[dict(split_rows[0],class_name='Script')]+split_rows[1:],
        'legacy module is not a ModuleScript':[dict(legacy_row,class_name='Script')],
        'stale legacy module':[dict(legacy_row,file=split_rows[1]['file'])],
        'duplicated index row':[legacy_row,legacy_row],
    }
    for label,rows in rejected.items():assert fails(check,h,with_rows(rows)),'checker accepted: '+label
    # A lone module that is neither form is named as such, before the missing-chunk lines.
    read_file=lambda r:(ROOT/r['file']).read_text(encoding='utf8')
    lone='single module is neither the current legacy source nor a current index (stale legacy form?)'
    for label in ('stale legacy module','legacy module is not a ModuleScript'):
        form,problems=source_form(data,legacy,rejected[label],read_file)
        assert form is None and problems[0]==lone and len(problems)>1,(label,problems)
    assert 'not a ModuleScript '+'.'.join(DATA_PATH) in source_form(data,legacy,rejected['legacy module is not a ModuleScript'],read_file)[1]
    for label in ('index only','split index as legacy','missing chunk','stale chunk','extra chunk','legacy index with chunks'):
        form,problems=source_form(data,legacy,rejected[label],read_file)
        assert form is None and problems and lone not in problems,(label,problems)
    # check_catalogue.py --capture needs the complete server vehicle root, and says so.
    raw=json.loads(stage.CAPTURE.read_text(encoding='utf8'));raw.pop('content_sha256')
    server_root=studio_capture.VEHICLES[0];refused={}
    raw['hierarchy']=[n for n in raw['hierarchy'] if n['path_parts']!=server_root]
    with tempfile.TemporaryDirectory() as temp:
        for label,roots,missing in (('root reported missing',raw['request']['roots'],raw['missing_roots']+[server_root]),
                                    ('root not requested',[r for r in raw['request']['roots'] if r!=server_root],raw['missing_roots'])):
            p=dict(raw,request=dict(raw['request'],roots=roots),missing_roots=missing)
            p['content_sha256']=studio_capture.digest(studio_capture.canonical(p).encode())
            path=Path(temp)/'capture.json';path.write_text(json.dumps(p),encoding='utf8')
            studio_capture.load(path)
            run=subprocess.run([sys.executable,str(ROOT/'scripts/performance_phase3/check_catalogue.py'),'--capture',str(path)],capture_output=True,text=True,cwd=str(ROOT))
            assert run.returncode!=0 and 'Capture must include the complete server vehicle root' in run.stderr,(label,run.stderr[-2000:])
            refused[label]=run.stderr.strip().splitlines()[-1]
    results['d_checkerForms']=dict(beforeCapture='legacy',splitRows='split',rejected=sorted(rejected),loneModuleMessage=lone,checkCatalogueWithoutServerVehicleRoot=refused)

    # (e) a second category
    h2=two_categories(h);data2,legacy2,_=project(h2);sources2=chunk_sources(data2)
    names2=[n for n,_ in sources2[1:]];by_name=dict(sources2)
    assert len(data2['Cockpits'])==12 and len(data2['Modules'])==232
    assert names2==sorted(names2) and [n for n in names2 if n.startswith('PIERCER_')]==names and names2[0]=='EXOTIC_1'
    for name in names:assert by_name[name]==children[name],'Piercer chunk changed when a category was added: '+name
    for kind in ('Cockpits','Modules'):
        for key,record in data[kind].items():assert data2[kind][key]==record,'Piercer record changed: '+key
    new2,_,order2=evaluate_split(sources2[0][1],{n:s for n,s in sources2[1:]})
    assert order2==names2 and new2==norm(data2) and evaluate_legacy(legacy2)==new2
    assert new2['Revision']==data2['Revision']==revision_of(data2)!=EXPECTED_REVISION
    assert all(len(s)<LIMIT for _,s in sources2)
    for name in OPT_IN:
        holders=[k for kind in ('Cockpits','Modules') for k,r in data2[kind].items() if name in r]
        assert holders and not set(holders)&(set(data['Cockpits'])|set(data['Modules'])),name
    assert new2['Modules']['MODULE_BOOST_EXOTIC_01_POWER']['DisplayName']==ODD['DisplayName']
    rows2=[dict(path_parts=DATA_PATH+([] if i==0 else [n]),class_name='ModuleScript',text=s) for i,(n,s) in enumerate(sources2)]
    read=lambda r:r['text']
    assert source_form(data2,legacy2,rows2,read)==('split',[])
    assert source_form(data2,legacy2,[dict(rows2[0],text=legacy2)],read)==('legacy',[])
    assert source_form(data2,legacy2,rows2[:-1],read)[0] is None and source_form(data2,legacy2,rows2+[dict(rows2[1],path_parts=DATA_PATH+['OTHER_1'])],read)[0] is None
    assert source_form(data2,legacy2,[dict(rows2[0],text=index)]+rows2[1:],read)[0] is None
    def dangling(attribute,id_field):
        h3=two_categories(h)
        node=next(n for n in flat(h3) if n['class_name']=='Model' and n['path_parts'][4:5]==['EXOTIC'] and id_field in (n.get('attributes') or {}))
        node['attributes'][attribute]={'type':'string','value':'nothing_here'}
        chunk_sources(project(h3)[0])
    assert fails(dangling,'DefaultFrontBodyModuleId','CockpitId') and fails(dangling,'RatingReferenceCockpitId','ModuleId')
    # chunk_sources() refuses what catalogue_gen.lua refuses (its jstr and num; selftest_gen.lua has the same lists).
    # project() is unchanged and still accepts the data, so only the split form is guarded.
    for good in (0,1,-1,0.0001,-0.03,350000,12500000,4.8999999999999995,0.30000000000000004,123456789.125,9007199254740991,10**15,True,False,'','plain ~','a"b\\c\nd\te\rf\bg\fh'):
        luau_safe(good)
    for bad in (-0.0,0.0,5.0,float('nan'),float('inf'),float('-inf'),1e21,1e100,1e22,0.00001,2**53,10**16,1e16,-1e-7,'café','x\x01y','x\x7fy','x\x00y','x\x0by',None,[],{}):
        assert fails(luau_safe,bad),('luau_safe accepted',bad)
    number=lambda v:{'type':'number','value':v}
    text=lambda v:{'type':'string','value':v}
    unsafe={
        'non-ASCII text':('DisplayName',text('café')),
        'control character':('DisplayName',text('x\x01y')),
        'DEL':('VariantName',text('x\x7fy')),
        'reviewer probe text':('DisplayName',text('café \x01 \x7f')),
        'small number':('TopSpeed',number(0.00001)),
        'large number':('Weight',number(1e22)),
        '2^53':('Price',number(2**53)),
        'whole float':('Price',number(5.0)),
        'negative zero':('Drag',number(-0.0)),
        'not a number':('Drag',number(float('nan'))),
        'numeric id':('ModuleId',number(12345)),
        'Vector3':('DefaultPrimaryColor',{'type':'Vector3','x':1,'y':2,'z':3,'text':'1, 2, 3'}),
        'Color3 part in exponent form':('DefaultPrimaryColor',{'type':'Color3','r':0.00001,'g':0,'b':1,'text':'1e-05, 0, 1'}),
    }
    target='MODULE_BOOST_EXOTIC_01_POWER'
    h3=two_categories(h)
    module=next(n for n in flat(h3) if n['class_name']=='Model' and (n.get('attributes') or {}).get('ModuleId',{}).get('value')==target)
    path=next(c for c in next(c for c in module['children'] if c['name']=='VehiclePerformanceV2UpgradePaths')['children'] if c['class_name']=='Folder')
    def unsafe_tree(attribute,value,in_path=False):
        """project() data of the two-category tree with one attribute changed on one module, or on one of its paths."""
        node=path if in_path else module;kept=dict(node['attributes'])
        node['attributes'][attribute]=value
        try:return project(h3)[0]
        finally:node['attributes']=kept
    for label,(attribute,value) in unsafe.items():
        assert fails(chunk_sources,unsafe_tree(attribute,value)),'chunk_sources accepted: '+label
    in_paths={'non-ASCII path name':('DisplayName',text('café')),'small path delta':('DeltaFraction_TopSpeed',number(0.00001)),'numeric PathId':('PathId',number(7))}
    for label,(attribute,value) in in_paths.items():
        assert fails(chunk_sources,unsafe_tree(attribute,value,True)),'chunk_sources accepted: '+label
    probe=unsafe_tree('DisplayName',text('café \x01 \x7f'))
    assert '\\u00e9' in catalogue.lua(probe['Modules'][target]) and '\\u0001' in catalogue.lua(probe['Modules'][target]),'the probe no longer shows what Python alone would write'
    chunk_sources(unsafe_tree('DisplayName',text(ODD['DisplayName'])))
    results['e_secondCategory']=dict(cockpits=12,modules=232,chunks={n:len(s) for n,s in sources2},piercerChunksByteIdentical=True,piercerRecordsUnchanged=True,mergedEqualsProjection=True,
                                     revision=data2['Revision'],danglingDefaultRejected=True,danglingRatingReferenceRejected=True,
                                     unsafeValuesRejectedByChunkSources=sorted(unsafe)+sorted(in_paths),projectStillAcceptsThem=True)

    # (f) one whitelist, one fixed text: catalogue.py, catalogue_gen.lua and the constants pinned in this file.
    gen=luau_generator((HERE/'catalogue_gen.lua').read_text(encoding='utf8'))
    for name in ('RAW','OPT_IN','PUBLIC','PATH_KEYS','CHUNK_FILL','SOURCE_LIMIT','INDEX_HEADER','CHUNK_HEADER','MERGE','FREEZE'):
        assert gen[name]==getattr(catalogue,name),'catalogue.py and catalogue_gen.lua differ: '+name
    assert catalogue.INDEX_HEADER==INDEX_HEADER+'\n' and catalogue.CHUNK_HEADER==CHUNK_HEADER+'\n','headers differ from the pinned text'
    assert catalogue.MERGE=='\n'.join(INDEX_LOOP)+'\n' and catalogue.FREEZE=='\n'.join(FREEZE_LINES),'index loop or freeze differs from the pinned text'
    assert catalogue.SOURCE_LIMIT==LIMIT and catalogue.CHUNK_FILL<LIMIT
    assert fails(luau_generator,(HERE/'catalogue_gen.lua').read_text(encoding='utf8').replace('"PathId", "DisplayName", "MaxPoints"','"PathId", "DisplayName", "MaxPoints", "Extra"'))
    results['f_generatorsInStep']=dict(public=len(catalogue.PUBLIC),pathKeys=len(catalogue.PATH_KEYS),optIn=catalogue.OPT_IN,chunkFill=catalogue.CHUNK_FILL,sourceLimit=catalogue.SOURCE_LIMIT,fixedTextEqual=True)
    if '--emit-synthetic' in sys.argv:
        target=Path(sys.argv[sys.argv.index('--emit-synthetic')+1]);target.mkdir(parents=True,exist_ok=True)
        root=next(n for n in flat(h2) if n['path_parts']==catalogue.ROOT_PATH)
        (target/'synthetic_tree.json').write_bytes(json.dumps(slim(root),separators=(',',':')).encode('utf8'))
        expected=dict(revision=data2['Revision'],cockpits=12,modules=232,sources=[dict(name=n,chars=len(s),sha256=hashlib.sha256(s.encode()).hexdigest()) for n,s in sources2])
        (target/'synthetic_expected.json').write_bytes(json.dumps(expected,indent=1).encode('utf8'))
        results['syntheticWritten']=str(target)
    results['pass']=True
    print(json.dumps(results,indent=2))
if __name__=='__main__':main()
