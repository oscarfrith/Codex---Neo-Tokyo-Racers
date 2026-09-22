"""Create, check and render scoped evidence records. Does not run gameplay or certify evidence content."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = json.loads((ROOT/'scripts/validation_checks.json').read_text(encoding='utf8'))

def new_record(task, checks):
    if not checks or len(checks)!=len(set(checks)) or any(k not in CATALOGUE for k in checks):
        raise ValueError('Select distinct known checks')
    return dict(schema=1, task=task, build='', changed='', studio_action='', capture='', recovery='', next_action='',
                checks=[dict(id=k, kind=CATALOGUE[k]['kind'], status='pending', observation='',
                             evidence=[], context={}, reason='', next_action='') for k in checks])

def artifact(path, root=ROOT):
    target=(root/path).resolve()
    if not target.is_relative_to(root.resolve()) or not target.is_file(): raise ValueError('Evidence must be a repository file')
    return dict(path=target.relative_to(root.resolve()).as_posix(),sha256=hashlib.sha256(target.read_bytes()).hexdigest())

def validate(record, root=ROOT):
    if record.get('schema')!=1: raise ValueError('Unsupported evidence schema')
    for field in ('task','build','changed','studio_action','capture','recovery','next_action'):
        if not isinstance(record.get(field),str) or not record[field].strip(): raise ValueError('Missing '+field)
    rows=record.get('checks')
    if not isinstance(rows,list) or not rows: raise ValueError('No checks selected')
    seen=set()
    for row in rows:
        key=row['id']; status=row['status']; ctx=row['context']
        if key in seen or key not in CATALOGUE or row['kind']!=CATALOGUE[key]['kind']: raise ValueError('Unknown, duplicate or relabelled check')
        seen.add(key)
        if status not in ('pass','fail','pending','deferred','not-applicable'): raise ValueError('Invalid status')
        if not isinstance(ctx,dict) or not isinstance(row['evidence'],list): raise ValueError('Invalid evidence/context')
        for ref in row['evidence']:
            if artifact(ref['path'],root)!=ref: raise ValueError('Evidence changed; review and repin')
        if status in ('pass','fail'):
            if not row['observation'].strip() or not row['evidence']: raise ValueError('Observed results need pinned evidence')
        if status!='pass':
            if not row['reason'].strip(): raise ValueError('Non-pass needs reason')
            if status!='not-applicable' and not row['next_action'].strip(): raise ValueError('Open check needs next action')
        if status!='pass': continue
        kind=row['kind']
        if kind!='static':
            for field in ('session','build','environment','device','input','time_utc'):
                if not isinstance(ctx.get(field),str) or not ctx[field].strip(): raise ValueError('Missing runtime context: '+field)
            if ctx['build']!=record['build']: raise ValueError('Evidence build differs from record')
        if kind in ('ui','device'):
            if ctx.get('interaction')!='normal-ui' or ctx.get('start_screen_active') is not False or ctx.get('visible_input_verified') is not True:
                raise ValueError('API/hidden-start evidence cannot pass UI checks')
        if kind=='device' and ctx.get('environment')!='physical-device': raise ValueError('Simulator is not physical-device evidence')
        if kind in ('multiplayer','persistence') and ctx.get('environment')!='isolated-published': raise ValueError('Requires isolated published evidence')
        if kind=='multiplayer':
            for field in ('players','required_players','minutes','required_minutes'):
                if type(ctx.get(field)) not in (int,float) or not 0<ctx[field]<float('inf'): raise ValueError('Invalid load/duration')
            if ctx['players']<ctx['required_players'] or ctx['minutes']<ctx['required_minutes']: raise ValueError('Load/duration target not met')
        if kind=='persistence' and ctx.get('saving_enabled') is not True: raise ValueError('No-save sandbox is not persistence evidence')
    return {'pass':sum(r['status']=='pass' for r in rows),
            'open':[r['id'] for r in rows if r['status'] not in ('pass','not-applicable')],
            'not_applicable':[r['id'] for r in rows if r['status']=='not-applicable'],
            'scope':'Selected checks only; evidence content and selection require human/assistant review.'}

def render(record, root=ROOT):
    summary=validate(record,root)
    lines=['# '+record['task'], '', 'Build: '+record['build'], '', record['changed'], '',
           'Selected checks: '+('OPEN: '+', '.join(summary['open']) if summary['open'] else 'all resolved (not a game-wide acceptance claim).'), '']
    for row in record['checks']:
        lines.append('- '+row['id']+' — '+row['status']+': '+(row['observation'] or row['reason']))
        if row['status']!='pass': lines.append('  Reason: '+row['reason']+'; next: '+(row['next_action'] or 'not applicable'))
        if row['evidence']: lines.append('  Evidence: '+', '.join(r['path'] for r in row['evidence']))
    lines+=['','Studio action: '+record['studio_action'],'','Capture: '+record['capture'],'','Recovery: '+record['recovery'],'','Next: '+record['next_action'],'']
    return '\n'.join(lines)

def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    init=sub.add_parser('init');init.add_argument('output');init.add_argument('--task',required=True);init.add_argument('--checks',nargs='+',choices=CATALOGUE,required=True)
    pin=sub.add_parser('artifact');pin.add_argument('path')
    for action in ('check','handoff'):
        p=sub.add_parser(action);p.add_argument('record')
    args=parser.parse_args()
    if args.command=='init':
        # Never overwrite an existing result with a pending template.
        with Path(args.output).open('x',encoding='utf8') as f: json.dump(new_record(args.task,args.checks),f,indent=2)
    elif args.command=='artifact': print(json.dumps(artifact(args.path),indent=2))
    else:
        record=json.loads(Path(args.record).read_text(encoding='utf8'))
        if args.command=='handoff': print(render(record))
        else:
            summary=validate(record);print(json.dumps(summary,indent=2))
            if summary['open']: raise SystemExit(2)

if __name__=='__main__': main()
