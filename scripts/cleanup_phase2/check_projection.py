from prepare import *
from path_analysis import analyze,tokens,literal
index=json.loads(read(HERE/'projection-index.json'));maps=json.loads(read(HERE/'module-map.json'))
old_names={p.rsplit('.',1)[-1] for p,v in maps.items() if p.rsplit('.',1)[-1]!=v.rsplit('.',1)[-1]}
hits=[]
for path in index:
    source=read(HERE/'projected'/('/'.join(path.split('.'))+'.lua'))
    for value,start,end in tokens(source):
        if literal(value) in old_names:
            line=source.count('\n',0,start)+1
            hits.append((path,line,source.splitlines()[line-1].strip()))
for row in hits:print(':'.join(map(str,row)))
print('Old-name literals:',len(hits))
