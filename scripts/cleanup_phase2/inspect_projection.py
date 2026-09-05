from prepare import *
from path_analysis import tokens
reports=json.loads(read(HERE/'path-analysis.json'))
for row in reports:
    if row['ambiguous_aliases']: print(row['target'],json.dumps(row['ambiguous_aliases']))
print('\nRUNTIME METADATA')
h=json.loads(read(HERE/'hierarchy-before.json'))
todo=list(h['hierarchy'])
while todo:
    n=todo.pop();todo.extend(n.get('children',[]));p='.'.join(n['path_parts'])
    if any(p.startswith(r) for r in ['ServerScriptService.NeoTokyoRacers','StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient']):
        if n.get('class_name')!='ModuleScript':print(p,n.get('class_name'),json.dumps(n.get('attributes',{})))
