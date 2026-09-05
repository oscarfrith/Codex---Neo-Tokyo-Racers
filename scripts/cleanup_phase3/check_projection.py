"""Check path projection, numeric tokens and saved-contract exceptions."""
from prepare import *
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import analyze,tokens
p=json.loads(read(HERE/'payload.json'));h=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()));nodes=flatten(h)
def target(path):
 for m in sorted(p['moves'],key=lambda r:-len(r['before'])):
  if path[:len(m['before'])]==m['before']:return m['after']+path[len(m['before']):]
 return path
retired={tuple(n['path_parts']) for n in p['retired']}
paths={tuple(target(n['path_parts'])) for n in nodes if tuple(n['path_parts']) not in retired}|{tuple(n['path']) for n in p['created']}
missing=[]
for r in p['sources']:
 if r['beforePath'][0]=='Workspace':assert r['before']==r['source']
 before_nums=[t for t,_,_ in tokens(r['before']) if re.fullmatch(r'\d+(?:\.\d+)?',t)]
 after_nums=[t for t,_,_ in tokens(r['source']) if re.fullmatch(r'\d+(?:\.\d+)?',t)]
 assert before_nums==after_nums,('numeric token drift',r['path'])
 for term in ['NTRSessionToken','NTRSessionLeaseUntil','NTR_PlayerProfiles_v1','NTR_DealershipIntro_v1','NTR_TimeTrialPersonalBests_v1','NTR_TT_Global_v1','NTR_TT_Global_Metadata_v1']:
  assert r['before'].count(term)==r['source'].count(term),(r['path'],term)
 chains,_=analyze(r['source'],r['path'])
 for a,b,path,steps in chains:
  if path[:2] in [('ReplicatedStorage','Config'),('ReplicatedStorage','Modules'),('ReplicatedStorage','Remotes'),('ServerStorage','Modules'),('ServerStorage','Assets')]:
   # Only unresolved explicit children; table member accesses after require are not instance paths.
   if path not in paths and 'WaitForChild' in r['source'][a:b]:missing.append({'source':r['path'],'line':r['source'].count('\n',0,a)+1,'path':list(path),'text':r['source'][a:b]})
dump(HERE/'path-check.json',missing)
print('PASS: all source numeric tokens, saved contract strings and excluded Workspace sources unchanged;',len(missing),'paths need classification')
