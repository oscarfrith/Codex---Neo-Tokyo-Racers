"""Generate exact candidate names and source consumers; no automatic mutation."""
from prepare import *
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import tokens,literal,analyze
h=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
nodes=flatten(h);rows=json.loads(read(HERE/'baseline.json'))
sources={r['roblox_path']:read(HERE/r['before_file']) for r in rows}
def inscope(p):return p[0]!='Workspace' or p[:2]==['Workspace','NeoTokyoRacersWorld']
brand=re.compile(r'NTR|NeoTokyoRacers|HOVER_RACING')
strings=collections.defaultdict(list);identifiers=collections.defaultdict(list)
for name,s in sources.items():
    if name.startswith('Workspace.') and not name.startswith('Workspace.NeoTokyoRacersWorld.'):continue
    for t,a,b in tokens(s):
        if brand.search(t):
            entry={'source':name,'line':s.count('\n',0,a)+1}
            if literal(t)!=None:strings[literal(t)].append(entry)
            elif re.fullmatch(r'\w+',t):identifiers[t].append(entry)
attrs=collections.defaultdict(list)
for n in nodes:
    if inscope(n['path_parts']):
        for k,v in n.get('attributes',{}).items() if isinstance(n.get('attributes'),dict) else []:
            attrs[k].append({'path':n['path_parts'],'value':v})
attribute_report=[]
for k,items in attrs.items():
    if brand.search(k) or re.search(r'Phase|Revision|Installed|Migrated|CreatedBy|CreatedOrUpdatedBy|LegacyName|RunId|Patch|SourceSheet|ShadowOnly',k):
        uses=[{'source':p,'count':s.count(k)} for p,s in sources.items() if k in s]
        attribute_report.append({'key':k,'instances':len(items),'source_mentions':uses,'values':list({json.dumps(x['value'],sort_keys=True) for x in items})[:6]})
dump(HERE/'source-name-candidates.json',{'strings':dict(sorted(strings.items())),'identifiers':dict(sorted(identifiers.items()))})
dump(HERE/'attribute-candidates.json',attribute_report)
out=[]
for n in nodes:
    p=n['path_parts']
    if (p[:3]==['ReplicatedStorage','NeoTokyoRacers','Config'] and len(p)==5) or (p[:4]==['ReplicatedStorage','NeoTokyoRacers','Shared','Config'] and len(p)==5):
        uses=[name for name,s in sources.items() if n['name'] in s]
        out.append({'path':p,'class':n['class_name'],'children':len(n.get('children',[])),'consumers':uses})
dump(HERE/'config-consumers.json',out)
print('Candidates:',len(strings),'string literals,',len(identifiers),'identifiers,',len(attribute_report),'metadata keys;',len(out),'configuration roots')
print('External storage declarations:')
for p,s in sources.items():
    for line in s.splitlines():
        if re.search(r'GetDataStore|GetOrderedDataStore|StoreName|StorePrefix|DataStoreName',line):print(p,':',line.strip())
