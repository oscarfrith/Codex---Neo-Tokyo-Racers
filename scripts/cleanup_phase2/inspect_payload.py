from prepare import *
d=json.loads(read(HERE/'payload.json'))
for r in d['retired']:
    if r['node']['class_name']=='ObjectValue':print(json.dumps(r['node'],indent=2))
print('runtime', '\n'.join('.'.join(r['path']) for r in d['containers']))
