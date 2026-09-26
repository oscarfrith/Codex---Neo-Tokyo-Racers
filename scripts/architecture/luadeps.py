"""Luau dependency analysis for mechanical extractions (read-only helper).

Lexes Luau and, for a line range of a file, reports free variables, free variables assigned in the range,
and top-level declarations (exports). Declarations are handled for `local a, b`, `local function f`,
`function(params)`, `function name(params)` and `for a, b in/=`. Scoping is flat within the range (a name
declared anywhere in the range counts as declared), so results are verified again at runtime.
"""
import re
import sys
from pathlib import Path

KEYWORDS = set('and break do else elseif end false for function goto if in local nil not or repeat return then true until while continue'.split())
GLOBALS = set('''game workspace script Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Ray RaycastParams OverlapParams
TweenInfo NumberRange NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint Rect Region3 BrickColor
PhysicalProperties Font DateTime Random Axes Faces PathWaypoint math string table coroutine os task debug utf8 bit32
buffer print warn error assert pcall xpcall type typeof tostring tonumber pairs ipairs next select unpack rawget rawset
rawequal rawlen setmetatable getmetatable require tick time wait delay spawn shared _G elapsedTime version settings
UserSettings getfenv setfenv loadstring gcinfo collectgarbage newproxy SharedTable self'''.split())
ASSIGN_OPS = {'=', '+=', '-=', '*=', '/=', '..=', '%=', '^=', '//='}

TOKEN = re.compile(r'''
  (?P<long>--\[(?P<eq>=*)\[.*?\](?P=eq)\]) |
  (?P<comment>--[^\n]*) |
  (?P<lstr>\[(?P<eq2>=*)\[.*?\](?P=eq2)\]) |
  (?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`) |
  (?P<num>0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+) |
  (?P<name>[A-Za-z_][A-Za-z0-9_]*) |
  (?P<op>\.\.\.|\.\.=|//=|\.\.|==|~=|<=|>=|[-+*/%^]=|::|[^\s])
''', re.S | re.X)


def lex(text):
    out, pos, line = [], 0, 1
    for m in TOKEN.finditer(text):
        line += text.count('\n', pos, m.start())
        if m.lastgroup in ('name', 'op', 'str', 'num', 'lstr'):
            out.append((m.lastgroup, m.group(), line))
        line += m.group().count('\n')
        pos = m.end()
    return out


def analyse_tokens(body):
    declared, used, assigned, toplevel = set(), {}, set(), []
    n = len(body)
    i = 0
    depth = 0  # block depth to identify top-level declarations
    while i < n:
        kind, value, line = body[i]
        prev = body[i - 1][1] if i else ''
        if kind == 'name' and value == 'local':
            j = i + 1
            if j < n and body[j][1] == 'function':
                declared.add(body[j + 1][1])
                if depth == 0: toplevel.append(body[j + 1][1])
                i = j  # let 'function' be processed next for params
                continue
            names = []
            while j < n and body[j][0] == 'name' and body[j][1] not in KEYWORDS:
                names.append(body[j][1]); j += 1
                if j < n and body[j][1] == ',': j += 1
                else: break
            declared.update(names)
            if depth == 0: toplevel.extend(names)
            i = j
            continue
        if kind == 'name' and value == 'function':
            depth += 1
            j = i + 1
            if j < n and body[j][0] == 'name':  # function a.b:c(
                # the base name is a use (e.g. function Service.start) unless it was `local function`
                if prev != 'local' and body[j][1] not in declared:
                    used.setdefault(body[j][1], body[j][2])
                while j < n and body[j][1] != '(':
                    j += 1
            if j < n and body[j][1] == '(':
                j += 1
                while j < n and body[j][1] != ')':
                    if body[j][0] == 'name': declared.add(body[j][1])
                    j += 1
            i = j + 1
            continue
        if kind == 'name' and value == 'for':
            j = i + 1
            while j < n and body[j][1] not in ('in', '='):
                if body[j][0] == 'name': declared.add(body[j][1])
                j += 1
            depth += 1
            i = j
            continue
        if kind == 'name' and value in ('do', 'then', 'repeat'):
            if value == 'do' and prev != 'while' and not any(body[k][1] in ('for', 'while') for k in range(max(0, i - 12), i)):
                depth += 1
            elif value in ('then', 'repeat'):
                depth += 1
            elif value == 'do':
                pass  # for/while already counted at 'for'; while counted below
        if kind == 'name' and value == 'while':
            depth += 1
        if kind == 'name' and value in ('end', 'until'):
            depth = max(0, depth - 1)
        if kind == 'name' and value in ('elseif',):
            depth = max(0, depth - 1)
        if kind == 'name' and value not in KEYWORDS:
            nxt = body[i + 1][1] if i + 1 < n else ''
            if prev in ('.', ':'):
                pass
            elif nxt == '=' and prev in ('{', ',', ';') and _in_table(body, i):
                pass
            else:
                used.setdefault(value, line)
                if nxt in ASSIGN_OPS:
                    assigned.add(value)
                elif nxt == ',':  # multiple assignment a, b = ...
                    k = i + 1
                    while k < n and body[k][1] == ',' and k + 1 < n and body[k + 1][0] == 'name':
                        k += 2
                    if k < n and body[k][1] == '=' and prev not in ('local',):
                        assigned.add(value)
        i += 1
    free = {k: v for k, v in used.items() if k not in declared and k not in GLOBALS}
    return declared, free, assigned, toplevel


def _in_table(body, i):
    depth = 0
    for k in range(i - 1, -1, -1):
        v = body[k][1]
        if v in (')', ']', '}'): depth += 1
        elif v in ('(', '['):
            if depth == 0: return False
            depth -= 1
        elif v == '{':
            if depth == 0: return True
            depth -= 1
    return False


def analyse(text, start, end):
    body = [t for t in lex(text) if start <= t[2] <= end]
    declared, free, assigned, toplevel = analyse_tokens(body)
    return declared, free, assigned & set(free), toplevel


def uses_outside(text, start, end, names):
    """Names referenced / assigned outside [start, end] (field accesses excluded)."""
    toks = [t for t in lex(text) if not (start <= t[2] <= end)]
    refs, assigns = set(), set()
    for i, (kind, value, line) in enumerate(toks):
        if kind != 'name' or value not in names: continue
        prev = toks[i - 1][1] if i else ''
        nxt = toks[i + 1][1] if i + 1 < len(toks) else ''
        if prev in ('.', ':'): continue
        refs.add(value)
        if nxt in ASSIGN_OPS and prev != 'local': assigns.add(value)
    return refs, assigns


if __name__ == '__main__':
    path, start, end = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    text = Path(path).read_text(encoding='utf8')
    declared, free, assigned, toplevel = analyse(text, start, end)
    refs, assigns = uses_outside(text, start, end, set(toplevel))
    print('FREE', sorted(free))
    print('ASSIGNED_FREE', sorted(assigned))
    print('TOPLEVEL', toplevel)
    print('EXPORTS_USED_OUTSIDE', sorted(refs))
    print('EXPORTS_ASSIGNED_OUTSIDE', sorted(assigns))


def toplevel_by_indent(text, start, end, indent='\t'):
    """Top-level declarations in [start, end] at exactly `indent` (exact for tab-indented closures)."""
    names = []
    pat = re.compile('^' + re.escape(indent) + r'local\s+(?:function\s+([A-Za-z_]\w*)|([A-Za-z_][\w\s,]*?)\s*(?:=|$))')
    for number, line in enumerate(text.split('\n'), 1):
        if start <= number <= end:
            m = pat.match(line)
            if m and not line.startswith(indent + '\t'):
                if m.group(1): names.append(m.group(1))
                else: names.extend(x.strip() for x in m.group(2).split(',') if x.strip())
    return names
