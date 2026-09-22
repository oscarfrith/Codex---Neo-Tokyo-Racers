"""Read-only authoring/public-data drift check against the latest Studio mirror."""
from build import ROOT
from catalogue import project
import json
h=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf8'))
data,source,_=project(h)
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
record=next(r for r in manifest if r['path_parts']==['ReplicatedStorage','Modules','Game','Vehicles','VehicleCatalogData'])
assert (ROOT/record['file']).read_text(encoding='utf8')==source,'Catalogue is stale: regenerate from authoring through the content change installer, then restart Play.'
print(json.dumps({'pass':True,'revision':data['Revision'],'cockpits':len(data['Cockpits']),'modules':len(data['Modules'])}))
