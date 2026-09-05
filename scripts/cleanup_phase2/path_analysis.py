"""Conservative literal Luau path analysis. Generates evidence; ambiguous aliases are not guessed."""
import re

TOKEN=re.compile(r'--\[(=*)\[.*?\]\1\]|--[^\n]*|\[(=*)\[.*?\]\2\]|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][A-Za-z_0-9]*|\d+(?:\.\d+)?|[^\s]',re.S)
def tokens(source): return [(m.group(),m.start(),m.end()) for m in TOKEN.finditer(source) if not m.group().startswith('--')]
def literal(token):
    return token[1:-1] if len(token)>1 and token[0] in "\"'" else None
def normal(path):
    p=tuple(path)
    if p[:3]==('Players','LocalPlayer','PlayerScripts'): p=('StarterPlayer','StarterPlayerScripts')+p[3:]
    return p
def expression(path):
    p=list(path)
    if p[:2]==['StarterPlayer','StarterPlayerScripts']:
        out='game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")'; p=p[2:]
    else:
        out='game:GetService("'+p.pop(0)+'")'
    return out+''.join(':WaitForChild("'+part+'")' for part in p)

def analyze(source,context):
    ts=tokens(source); n=len(ts); aliases={'game':{()},'workspace':{('Workspace',)},'script':{tuple(context)}}
    constants={ts[i][0]:literal(ts[i+2][0]) for i in range(n-2) if ts[i+1][0]=='=' and literal(ts[i+2][0]) is not None}
    def string_value(token):return literal(token) or constants.get(token)
    def parse(i):
        if ts[i][0]=='ensureFolder' and i+2<n and ts[i+1][0]=='(':
            arg=parse(i+2)
            if arg:
                j,path,_=arg
                if j+2<n and ts[j][0]==',' and string_value(ts[j+1][0]) is not None and ts[j+2][0]==')':
                    path=path+(string_value(ts[j+1][0]),)
                    return j+3,path,[(path,ts[j+2][2])]
        name=ts[i][0]; paths=aliases.get(name)
        if not paths or len(paths)!=1: return None
        path=next(iter(paths)); j=i+1;steps=[(normal(path),ts[i][2])]
        while j<n:
            if ts[j][0]=='.' and j+1<n and re.fullmatch(r'[A-Za-z_]\w*',ts[j+1][0]):
                key=ts[j+1][0]
                if key in {'Event','OnInvoke','OnServerInvoke','OnClientInvoke','OnClientEvent','OnServerEvent','Destroying','Changed','ChildAdded','ChildRemoved','DescendantAdded','DescendantRemoving','AncestryChanged','Name','ClassName','Value','Source','Disabled','Enabled','Archivable','AbsoluteSize','AbsolutePosition','Position','Size','Visible','CFrame','WorldCFrame','ViewportSize','CurrentCamera','TouchEnabled','UserId','Character','CharacterAdded','CharacterRemoving','PrimaryPart','AssemblyLinearVelocity','AssemblyAngularVelocity','AssemblyMass','CameraSubject','CameraType','SeatPart','Occupant','LocalPlayer'} and key!='LocalPlayer':break
                path=path[:-1] if key=='Parent' else path+(key,); j+=2
            elif ts[j][0]==':' and j+4<n and ts[j+1][0] in ('WaitForChild','FindFirstChild','GetService') and ts[j+2][0]=='(' and string_value(ts[j+3][0]) is not None:
                end=j+4
                if ts[end][0]==',' and end+2<n and ts[end+2][0]==')': end+=2
                if ts[end][0]!=')': break
                path=path+(string_value(ts[j+3][0]),);j=end+1
            else: break
            steps.append((normal(path),ts[j-1][2]))
        return j,normal(path),steps
    # Candidate names come from local assignments. Short-circuit guards may precede the concrete path.
    assignments=[]
    for i in range(n-2):
        if re.fullmatch(r'[A-Za-z_]\w*',ts[i][0]) and ts[i+1][0]=='=' and (i==0 or ts[i-1][0] not in ('.',':')):
            assignments.append((ts[i][0],i+2))
    for _ in range(12):
        changed=False
        for name,i in assignments:
            if name in ('script','game','workspace'): continue
            result=parse(i)
            if not result: continue
            j,path,_=result
            while j<n and ts[j][0]=='and':
                other=parse(j+1)
                if not other: break
                j,path,_=other
            # Do not mistake method results (GetAttributes etc), arithmetic, or optional alternatives for an instance.
            if j<n and ts[j][0] in (':','(','or','+','-','*','/'): continue
            values=aliases.setdefault(name,set())
            if path not in values: values.add(path);changed=True
        if not changed: break
    # A name reassigned to a non-instance (including a shadowed require result) is unsafe globally.
    # Repeatedly discard it and aliases derived from it. The report exposes cases for explicit edits.
    for _ in range(12):
        blocked=set()
        for name,i in assignments:
            if name not in aliases or name in ('script','game','workspace'):continue
            result=parse(i)
            if not result:
                if ts[i][0]!='nil':blocked.add(name)
                continue
            j,_,_=result
            if j<n and ts[j][0] in (':','('):blocked.add(name)
        if not blocked:break
        for name in blocked:aliases.pop(name,None)
    chains=[];i=0
    while i<n:
        if i and ts[i-1][0] in ('.',':'): i+=1;continue
        result=parse(i)
        if result and result[0]>i+1:
            j,path,steps=result;chains.append((ts[i][1],ts[j-1][2],path,steps));i=j
        else:i+=1
    return chains,aliases

def rewrite(source,context,mapping):
    chains,aliases=analyze(source,context); edits=[]
    for start,end,path,steps in chains:
        match=next((path[:i] for i in range(len(path),0,-1) if path[:i] in mapping),None)
        if match:
            # Literal instance navigation can collapse Parent; object properties are excluded by parse.
            exact=next(((p,stop) for p,stop in steps if p==match),None)
            if exact:
                _,stop=exact;target=mapping[match]
            else:
                stop=end;target=mapping[match]+path[len(match):]
            value=expression(target)
            # Optional runtime endpoint lookups stay optional; required module dependencies are explicit.
            chunk=source[start:stop]
            if re.search(r':FindFirstChild\([^()]*\)\s*$',chunk) and target:
                last=':WaitForChild("'+target[-1]+'")'
                if value.endswith(last):value=value[:-len(last)]+':FindFirstChild("'+target[-1]+'")'
            edits.append((start,stop,value,chunk,'.'.join(target)))
    for start,end,value,*_ in reversed(edits):source=source[:start]+value+source[end:]
    return source,edits,{k:[list(p) for p in v] for k,v in aliases.items() if len(v)>1}
