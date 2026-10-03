"""Read-only authoring/public-data drift check against the latest Studio mirror, or a scoped capture (--capture)."""
from build import ROOT
from catalogue import project,flat,source_form,ROOT_PATH
import argparse,copy,json,sys
parser=argparse.ArgumentParser();parser.add_argument('--capture');args=parser.parse_args()
if args.capture:
    sys.path.insert(0,str(ROOT/'scripts'))
    from studio_capture import load,VEHICLES
    h=load(args.capture);manifest=h['manifest']
    assert VEHICLES[0] in h['request']['roots'] and VEHICLES[0] not in h['missing_roots'],'Capture must include the complete server vehicle root '+'.'.join(VEHICLES[0])
else:
    h=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf8'))
    manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
# Authoring moved to ServerStorage in Performance Phase 4; project() reads the original ReplicatedStorage path.
tree=next((n for n in flat(h) if n['path_parts']==['ServerStorage']+ROOT_PATH[1:3]),None)
if tree:
    tree=copy.deepcopy(tree)
    for n in flat({'hierarchy':[tree]}):n['path_parts']=ROOT_PATH[:1]+n['path_parts'][1:];n['path']='.'.join(n['path_parts'])
    h={'hierarchy':[tree]}
data,source,_=project(h)
# Exactly one generated form: the single legacy module, or the index plus exactly its chunk children.
form,problems=source_form(data,source,manifest,lambda row:(ROOT/row['file']).read_text(encoding='utf8'))
assert form,'Catalogue is stale: regenerate from authoring through the content change installer, then restart Play. '+'; '.join(problems)
print(json.dumps({'pass':True,'form':form,'revision':data['Revision'],'cockpits':len(data['Cockpits']),'modules':len(data['Modules'])}))
