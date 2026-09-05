from prepare import *
todo=list(json.loads(read(HERE/'hierarchy-before.json'))['hierarchy'])
while todo:
    n=todo.pop();todo.extend(n.get('children',[]))
    if n['path_parts'] in [
        ['ReplicatedStorage','NeoTokyoRacers'],
        ['ReplicatedStorage','NeoTokyoRacers','Shared','Config','VehiclePerformanceV2_EditAttributes'],
        ['StarterPlayer','StarterPlayerScripts','NeoTokyoRacersClient','Controllers','UI','README_TargetControllers']
    ]:print(json.dumps({k:v for k,v in n.items() if k!='children'},indent=2))
