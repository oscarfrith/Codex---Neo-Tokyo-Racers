from prepare import *
from path_analysis import tokens
import re
paths=json.loads(read(HERE/'projection-index.json'))
sources={p:read(HERE/'projected'/('/'.join(p.split('.'))+'.lua')) for p in paths}
code={p:set(re.findall(r'\w+',' '.join(t[0] for t in tokens(s)))) for p,s in sources.items()}
removed=[]
while True:
    batch=[]
    for path in code:
        if '.Modules.' not in path:continue
        name=path.rsplit('.',1)[-1]
        if not any(name in s for p,s in code.items() if p!=path):batch.append(path)
    if not batch:break
    removed.extend(batch)
    for p in batch:del code[p]
print(json.dumps(removed,indent=2))
