"""Exact frozen-source Phase 5 catalogue transport migration."""
from pathlib import Path
import gzip,hashlib,json
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf8')
def checksum(s):return str(sum(i*b for i,b in enumerate(s.encode(),1))%1000000007)
def replace(s,a,b):
    assert s.count(a)==1,('anchor count',s.count(a),a[:130]);return s.replace(a,b,1)
def main():
    if not (HERE/'baseline.json').exists():
        rows=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
        dump(HERE/'baseline.json',rows)
        dump(HERE/'sources-before.json',{r['roblox_path']:(ROOT/r['file']).read_text(encoding='utf8') for r in rows})
        (HERE/'hierarchy-before.json.gz').write_bytes(gzip.compress((ROOT/'roblox/studio_snapshot/hierarchy.json').read_bytes(),mtime=0))
    rows=json.loads((HERE/'baseline.json').read_text());old=json.loads((HERE/'sources-before.json').read_text());new=dict(old)
    p='ServerStorage.Modules.Game.Garage.GarageServer';s=old[p]
    s=replace(s,'local function garageServer_catalog()','local function garageServer_buildCatalog()')
    wrapper='''local catalogueSnapshot
	local catalogueRevision=game:GetService("HttpService"):GenerateGUID(false)
	local function freezeCatalogue(value)
		for _,v in pairs(value) do if type(v)=="table" then freezeCatalogue(v) end end
		return table.freeze(value)
	end
	local function garageServer_catalog(knownRevision)
		if not catalogueSnapshot then catalogueSnapshot=freezeCatalogue(garageServer_buildCatalog()) end
		if knownRevision==catalogueRevision then return nil,catalogueRevision end
		return catalogueSnapshot,catalogueRevision
	end

	local function totalStats(profile)'''
    s=replace(s,'local function totalStats(profile)',wrapper)
    s=replace(s,'return { Success = true, Catalog = garageServer_catalog(), Profile = profileForClient(profile) }','local catalogue,revision=garageServer_catalog(args.KnownCatalogRevision)\n\t\t\t\treturn { Success = true, Catalog = catalogue, CatalogRevision = revision, CatalogProtocol = 1, Profile = profileForClient(profile) }')
    new[p]=s
    p='ServerStorage.Modules.Game.Garage.GarageRequestGuard'
    new[p]=replace(old[p],'if strings[key] then','if key=="KnownCatalogRevision" then\n\t\t\t\tif action~="GetInitial" or type(value)~="string" or #value>64 then return false,"Invalid catalogue revision." end\n\t\t\telseif strings[key] then')
    prefix='local CatalogTransport=require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageCatalogClient"))\n'
    p='ReplicatedStorage.Modules.Game.Garage.GarageUI'
    new[p]=prefix+replace(old[p],'return garageInvoke:InvokeServer(actionName,payload or {})','if actionName=="GetInitial" then return CatalogTransport.Fetch(garageInvoke,payload) end; return garageInvoke:InvokeServer(actionName,payload or {})')
    p='ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI'
    new[p]=prefix+replace(old[p],'return garageInvoke:InvokeServer("GetInitial", {})','return CatalogTransport.Fetch(garageInvoke,{})')
    p='ReplicatedStorage.Modules.Game.UI.MobileFreeRoamHudUI'
    # Its existing helper wraps all garage commands; only the read takes this branch.
    s=old[p];line=next(x for x in s.splitlines() if x.startswith('local function call('))
    assert 'InvokeServer' in line
    import re
    match=re.search(r'return (\w+):InvokeServer\((\w+),([^)]*)\)',line);assert match,line
    remote,action,payload=match.groups()
    replacement=f'if {action}=="GetInitial" then return CatalogTransport.Fetch({remote},{payload}) end; '+match.group(0)
    new[p]=prefix+replace(s,match.group(0),replacement)
    for name in ['RaceEntryMenuClient','RaceEntryPresentationClient']:
        p='ReplicatedStorage.Modules.Game.Racing.'+name;s=old[p]
        if name=='RaceEntryMenuClient':anchor='return remote:InvokeServer(action,payload or {})';args='payload'
        else:anchor='return remote:InvokeServer(action, data or {})';args='data'
        new[p]=prefix+replace(s,anchor,f'if remote==garageInvoke and action=="GetInitial" then return CatalogTransport.Fetch(remote,{args}) end; '+anchor)
    changes=[dict(path=p.split('.'),before=old[p],after=s) for p,s in new.items() if old[p]!=s];assert len(changes)==7
    fps=[]
    for r in rows:
        p=r['roblox_path'];assert hashlib.sha256(old[p].encode()).hexdigest()==r['source_sha256']
        fps.append(dict(path=r['path_parts'],className=r['class_name'],disabled=r['disabled'],beforeBytes=len(old[p].encode()),bytes=len(new[p].encode()),beforeChecksum=checksum(old[p]),checksum=checksum(new[p]),sha256=hashlib.sha256(new[p].encode()).hexdigest()))
    p='ReplicatedStorage.Modules.Game.Garage.GarageCatalogClient';source=(HERE/'GarageCatalogClient.lua').read_text(encoding='utf8')
    d=dict(sources=changes,fingerprints=fps,new=[dict(path=p.split('.'),source=source,sha256=hashlib.sha256(source.encode()).hexdigest())])
    dump(HERE/'payload.json',d)
    encoded=json.dumps(d,separators=(',',':'),ensure_ascii=False);assert ']========]' not in encoded
    template=(HERE/'installer.lua').read_text(encoding='utf8')
    (ROOT/'scripts/roblox_performance_phase5_catalogue_transport.lua').write_text(template.replace('--[[PAYLOAD]]','[========['+encoded+']========]'),encoding='utf8')
    print(json.dumps({'changedSources':[r['path'] for r in changes],'newModule':p},indent=2))
if __name__=='__main__':main()
