"""Read-only local naming/dependency evidence; findings never authorize deletion."""
from pathlib import Path
import collections,json,re,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/cleanup_phase2'))
from path_analysis import tokens,literal
EXTERNAL={'NTRSessionToken','NTRSessionLeaseUntil','NTR_PlayerProfiles_v1','NTR_DealershipIntro_v1','NTR_TimeTrialPersonalBests_v1','NTR_TT_Global_v1','NTR_TT_Global_Metadata_v1'}
def audit(manifest=None):
    if manifest is None:manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text())
    errors=[];contracts=collections.Counter();guards=collections.Counter();comments=0
    for r in manifest:
        if r['path_parts'][0]=='Workspace':continue
        source=(ROOT/r['file']).read_text(encoding='utf-8')
        for t,a,b in tokens(source):
            v=literal(t)
            if v in EXTERNAL:contracts[v]+=1;continue
            if v and re.search(r'NeoTokyoRacers|HOVER_RACING|\bNTR_',v):errors.append({'path':r['roblox_path'],'literal':v})
            if re.fullmatch(r'(?:[vV]\d+[A-Za-z]?_\w+|ntr|neoTokyo|phase1Global)',t):errors.append({'path':r['roblox_path'],'identifier':t})
            if re.fullmatch(r'\w+_Phase\d+[A-Za-z]*',t):guards[t]+=1
        comments+=sum('NTR_' in line and '--' in line for line in source.splitlines())
    return {'pass':not errors,'errors':errors,'external_identity_contracts':dict(contracts),'retained_surface_suppression_keys':dict(guards),'historical_comment_lines':comments,'scope':'Current executable mirror outside Workspace scripts. Saved identities and exact lifecycle suppression contracts are classified exceptions; comments are not execution paths.'}
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument('--capture');mode.add_argument('--legacy-mirror',action='store_true');args=parser.parse_args()
    manifest=None
    if args.capture:
        from studio_capture import load
        manifest=load(args.capture)['manifest']
    result=audit(manifest)
    if args.capture:result['scope']='Verified scoped-capture complete source inventory outside Workspace scripts; not a physical naming audit.'
    print(json.dumps(result,indent=2));sys.exit(0 if result['pass'] else 1)
