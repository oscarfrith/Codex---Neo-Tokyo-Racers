#!/usr/bin/env python3
"""Static contract extractor for the Classic UI owners (Pulse UI restyle, Phase 0).

Reads the byte-exact Luau dump in scripts/ui_restyle/classic/sources (index:
classic/manifest_raw.json) and writes one contract table per client UI owner to
classic/contracts/<ScriptName>.json, plus cross-reference tables and INDEX.md.

It is a tokeniser plus pattern scanner, not a Luau interpreter. Everything it
reports is read from source text. Anything whose name is built at run time is
reported as unresolved with file:line and is never guessed.

Usage:  py -3 scripts/ui_restyle/tools/extract_contracts.py [--check]
        --check  analyse and print totals without writing files
Stdlib only. No Studio access, no network.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CLASSIC = ROOT / "classic"
SOURCES = CLASSIC / "sources"
MANIFEST = CLASSIC / "manifest_raw.json"
OUT = CLASSIC / "contracts"

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
SERVICES_TRACKED = {
    "UserInputService", "GuiService", "StarterGui", "ContextActionService", "RunService",
    "ProximityPromptService",
}
RUN_SIGNALS = {"Heartbeat", "RenderStepped", "PreRender", "PreSimulation", "PostSimulation",
               "Stepped", "PreAnimation"}
RENDER_PRIORITY = {"First": 0, "Input": 100, "Camera": 200, "Character": 300, "Last": 2000}
CLIENT_ROOTS = ("ReplicatedStorage.", "ReplicatedFirst.", "StarterPlayer.")
# Receivers rooted here cannot be instances a UI owner creates at run time.
STATIC_ROOTS = ("ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "ServerScriptService",
                "StarterPlayer", "StarterGui", "Lighting", "SoundService")
UI_MARKERS = ("PlayerGui", "PlayerScripts", "ContextActionService", "SetCore", "SetCoreGuiEnabled")
UI_CLASSES = {"ScreenGui", "BillboardGui", "SurfaceGui", "Frame", "TextLabel", "TextButton",
              "ImageLabel", "ImageButton", "ScrollingFrame", "CanvasGroup", "ProximityPrompt",
              "ViewportFrame", "UIScale"}
CLASS_RE = re.compile(r"^[A-Z][A-Za-z0-9]+$")
INSTANCE_NEW_RE = re.compile(r"""Instance\.new\(\s*["'](\w+)["']""")
# Class names seen in Instance.new("...") anywhere in the dump. A call f("Class", {props}, ...) is read as an
# instance factory only when "Class" is one of these, so request("Action", {...}) is not mistaken for one.
KNOWN_CLASSES = set()

TOKEN_RE = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<lcom>--\[(?P<lceq>=*)\[)
  | (?P<com>--[^\n]*)
  | (?P<lstr>\[(?P<lseq>=*)\[)
  | (?P<dq>"(?:\\.|\\\n|[^"\\\n])*")
  | (?P<sq>'(?:\\.|\\\n|[^'\\\n])*')
  | (?P<bt>`(?:\\.|[^`\\])*`)
  | (?P<num>0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.[\d_]*)?(?:[eE][+-]?\d+)?|\.\d[\d_]*(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<sym>\.\.\.|\.\.=|\.\.|==|~=|<=|>=|::|->|\+=|-=|\*=|//=|/=|%=|\^=|//|[-+*/%^\#<>=(){}\[\];:,.&|?@~])
    """,
    re.X | re.S,
)
ESC_RE = re.compile(r"\\(z\s*|\n|x[0-9a-fA-F]{2}|\d{1,3}|u\{[0-9a-fA-F]+\}|.)", re.S)
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}


def _unescape(body: str) -> str:
    if "\\" not in body:
        return body

    def rep(m):
        e = m.group(1)
        if e[0] == "z" or e == "\n":
            return "" if e[0] == "z" else "\n"
        if e[0] == "x":
            return chr(int(e[1:], 16))
        if e[0].isdigit():
            return chr(int(e))
        if e[0] == "u":
            return chr(int(e[2:-1], 16))
        return _ESC.get(e, e)

    return ESC_RE.sub(rep, body)


def tokenize(src: str):
    """Return parallel lists (types, values, lines, starts, ends). Comments are dropped.
    types: name, kw, str, istr (backtick string), num, sym."""
    T, V, L, S, E = [], [], [], [], []
    pos, line, n = 0, 1, len(src)
    while pos < n:
        m = TOKEN_RE.match(src, pos)
        if not m:
            pos += 1  # unknown byte: skip, keep going
            continue
        kind = m.lastgroup
        end = m.end()
        if kind == "ws" or kind == "com":
            pass
        elif kind in ("lcom", "lstr"):
            eq = m.group("lceq") if kind == "lcom" else m.group("lseq")
            close = src.find("]" + eq + "]", end)
            stop = n if close < 0 else close + len(eq) + 2
            if kind == "lstr":
                body = src[end:close if close >= 0 else n]
                if body.startswith("\r\n"):
                    body = body[2:]
                elif body.startswith("\n"):
                    body = body[1:]
                T.append("str"); V.append(body); L.append(line); S.append(pos); E.append(stop)
            end = stop
        elif kind in ("dq", "sq"):
            T.append("str"); V.append(_unescape(src[pos + 1:end - 1])); L.append(line); S.append(pos); E.append(end)
        elif kind == "bt":
            T.append("istr"); V.append(src[pos + 1:end - 1]); L.append(line); S.append(pos); E.append(end)
        elif kind == "num":
            T.append("num"); V.append(src[pos:end]); L.append(line); S.append(pos); E.append(end)
        elif kind == "name":
            v = src[pos:end]
            T.append("kw" if v in KEYWORDS else "name"); V.append(v); L.append(line); S.append(pos); E.append(end)
        else:
            T.append("sym"); V.append(src[pos:end]); L.append(line); S.append(pos); E.append(end)
        line += src.count("\n", pos, end)
        pos = end
    return T, V, L, S, E


EXPR_PREV = {"=", "(", ",", "{", "[", "..", "+", "-", "*", "/", "//", "%", "^", "==", "~=", "<", ">",
             "<=", ">=", "+=", "-=", "*=", "/=", "..=", "return", "and", "or", "not", "then_x", "else_x"}


class Script:
    def __init__(self, entry):
        self.path = entry["path"]
        self.cls = entry["class"]
        self.file = entry["file"]
        self.name = self.path.rsplit(".", 1)[-1]
        self.src = (SOURCES / self.file).read_bytes().decode("utf-8", errors="replace")
        self.line_count = self.src.count("\n") + 1
        self.T, self.V, self.L, self.S, self.E = tokenize(self.src)
        self.n = len(self.T)
        self.items = {}          # category -> list of dict
        self.unresolved = []     # {category, line, detail}
        self.templates = {}      # func id -> list of template dict
        self.calls = {}          # func id -> list of '(' token index (same-file call sites)
        self.ext_calls = []      # (target script path, func short name, '(' idx)
        self.service_uses = []
        self.instance_classes = {}
        self._structure()
        self._bindings()

    # ------------------------------------------------------------------ structure
    def _structure(self):
        T, V, n = self.T, self.V, self.n
        match = [-1] * n
        block_end = {}
        func_of = [-1] * n
        blk_of = [-1] * n       # innermost block opener token index
        in_table = [False] * n
        stack = []              # (kind, idx)  kind: '(' '{' '[' 'block' 'ifexpr' 'func'
        funcs = []
        fstack = []
        else_closed_ifexpr = -2
        pairs = {")": "(", "}": "{", "]": "["}
        for i in range(n):
            v = V[i]
            t = T[i]
            # context of this token (before any push)
            ctx_table = False
            for kind, idx in reversed(stack):
                if kind == "{":
                    ctx_table = True
                    break
                if kind in ("block", "func"):
                    break
            in_table[i] = ctx_table
            func_of[i] = fstack[-1] if fstack else -1
            for kind, idx in reversed(stack):
                if kind in ("block", "func"):
                    blk_of[i] = idx
                    break
            if t == "sym":
                if v in "({[" and len(v) == 1:
                    stack.append((v, i))
                elif v in pairs:
                    want = pairs[v]
                    while stack and stack[-1][0] == "ifexpr":
                        stack.pop()
                    if stack and stack[-1][0] == want:
                        match[stack[-1][1]] = i
                        match[i] = stack[-1][1]
                        stack.pop()
            elif t == "kw":
                if v == "function":
                    fid = len(funcs)
                    funcs.append({"id": fid, "start": i, "parent": fstack[-1] if fstack else -1})
                    stack.append(("func", i))
                    fstack.append(fid)
                elif v == "if":
                    pv = V[i - 1] if i else ""
                    pt = T[i - 1] if i else ""
                    is_expr = (pt in ("sym", "kw") and pv in EXPR_PREV) or (pv == "else" and else_closed_ifexpr == i - 1)
                    stack.append(("ifexpr" if is_expr else "block", i))
                elif v in ("do", "repeat"):
                    stack.append(("block", i))
                elif v == "else":
                    if stack and stack[-1][0] == "ifexpr":
                        stack.pop()
                        else_closed_ifexpr = i
                elif v in ("end", "until"):
                    while stack and stack[-1][0] not in ("block", "func"):
                        stack.pop()
                    if stack:
                        kind, idx = stack.pop()
                        block_end[idx] = i
                        if kind == "func":
                            funcs[fstack.pop()]["end"] = i
        for f in funcs:
            f.setdefault("end", n - 1)
        self.match, self.block_end, self.func_of, self.blk_of, self.in_table = match, block_end, func_of, blk_of, in_table
        self.funcs = funcs
        self.members = {}   # short name -> [fid] for member / field functions
        for f in funcs:
            self._describe_function(f)

    def _describe_function(self, f):
        T, V = self.T, self.V
        i = f["start"]
        j = i + 1
        name, full, kind, owner = None, None, "anon", None
        if j < self.n and T[j] == "name":
            parts = [V[j]]
            j += 1
            while j + 1 < self.n and V[j] in (".", ":") and T[j + 1] == "name":
                parts.append(V[j]); parts.append(V[j + 1])
                j += 2
            full = "".join(parts)
            name = parts[-1]
            if len(parts) > 1:
                kind, owner = "member", parts[0]
            else:
                kind = "local" if (i and V[i - 1] == "local") else "global"
        elif i >= 2 and V[i - 1] == "=":
            if T[i - 2] == "name":
                name = V[i - 2]
                if i >= 3 and V[i - 3] in (".", ":"):
                    a, _ = self.recv_range(i - 3)
                    kind, owner, full = "member", V[a], self.text(a, i - 1)
                elif self.in_table[i - 2]:
                    kind, full = "field", name
                else:
                    kind, full = "local", name
            elif V[i - 2] == "]" and T[i - 3] == "str" and self.in_table[i - 2]:
                name, kind, full = V[i - 3], "field", V[i - 3]
        params, vararg = [], False
        if j < self.n and V[j] == "(" and self.match[j] > 0:
            close = self.match[j]
            k = j + 1
            expect = True
            depth = 0
            while k < close:
                v = V[k]
                if v in ("(", "{", "[", "<"):
                    depth += 1
                elif v in (")", "}", "]", ">"):
                    depth -= 1
                elif depth == 0 and v == ",":
                    expect = True
                elif depth == 0 and expect and T[k] == "name":
                    params.append(v); expect = False
                elif depth == 0 and expect and v == "...":
                    vararg = True; expect = False
                k += 1
            f["body"] = close + 1
        else:
            f["body"] = j
        f.update(name=name, full=full, kind=kind, owner=owner, params=params, vararg=vararg, line=self.L[i])
        if kind in ("member", "field") and name:
            self.members.setdefault(name, []).append(f["id"])

    # ------------------------------------------------------------------ helpers
    def text(self, a, b, limit=160):
        if b <= a:
            return ""
        s = " ".join(self.src[self.S[a]:self.E[b - 1]].split())
        return s if len(s) <= limit else s[:limit - 3] + "..."

    def recv_range(self, i):
        """i is the index of '.' or ':' before a member name; return (start, i)."""
        T, V = self.T, self.V
        j = i - 1
        start = i
        while j >= 0:
            v, t = V[j], T[j]
            if t == "sym" and v in (")", "]"):
                k = self.match[j]
                if k < 0:
                    break
                if v == ")" and not (k > 0 and (T[k - 1] == "name" or V[k - 1] in (")", "]"))):
                    start = k
                    break
                start = k
                j = k - 1
                continue
            if t == "name" or (t == "str" and j > 0 and False):
                start = j
                if j > 0 and V[j - 1] in (".", ":") and T[j - 1] == "sym":
                    j -= 2
                    continue
                break
            break
        return start, i

    def args(self, open_idx):
        """Split call arguments. Returns list of (a, b) token ranges."""
        close = self.match[open_idx]
        if close < 0:
            return []
        out, a, k = [], open_idx + 1, open_idx + 1
        while k < close:
            v = self.V[k]
            if self.T[k] == "sym" and v in ("(", "{", "[") and self.match[k] > 0:
                k = self.match[k] + 1
                continue
            if self.T[k] == "kw" and v == "function":
                k = self.funcs_by_start[k]["end"] + 1
                continue
            if v == "," and self.T[k] == "sym":
                out.append((a, k)); a = k + 1
            k += 1
        if a < close:
            out.append((a, close))
        return out

    def expr_end(self, i):
        T, V, n = self.T, self.V, self.n
        j = i
        operand = False
        ifx = 0
        while j < n:
            t, v = T[j], V[j]
            if t == "kw":
                if v == "function" and not operand:
                    j = self.funcs_by_start[j]["end"] + 1; operand = True; continue
                if v in ("nil", "true", "false"):
                    if operand:
                        break
                    operand = True; j += 1; continue
                if v in ("and", "or"):
                    operand = False; j += 1; continue
                if v == "not":
                    if operand:
                        break
                    j += 1; continue
                if v == "if" and not operand:
                    ifx += 1; j += 1; continue
                if ifx and v in ("then", "elseif"):
                    operand = False; j += 1; continue
                if ifx and v == "else":
                    ifx -= 1; operand = False; j += 1; continue
                break
            if t == "sym":
                if v in ("(", "[", "{"):
                    m = self.match[j]
                    if m < 0:
                        break
                    if v == "[" and not operand:
                        break
                    j = m + 1; operand = True; continue
                if v in (")", "}", "]", ";", ",", "=", "+=", "-=", "*=", "/=", "..=", "//=", "%=", "^="):
                    break
                if v in (".", ":"):
                    j += 2; continue
                if v == "::":
                    j += 2
                    continue
                if v == "...":
                    if operand:
                        break
                    operand = True; j += 1; continue
                operand = False; j += 1; continue
            # name / str / num / istr
            if operand:
                break
            operand = True
            j += 1
        return j

    def enclosing_named(self, i):
        fid = self.func_of[i]
        while fid >= 0:
            f = self.funcs[fid]
            if f["name"]:
                return f["full"] or f["name"]
            fid = f["parent"]
        return None

    def scope_end(self, i):
        b = self.blk_of[i]
        return self.block_end.get(b, self.n) if b >= 0 else self.n

    # ------------------------------------------------------------------ tables
    def table_fields(self, open_idx):
        """Top-level fields of a table constructor: list of (key, a, b). key None for positional."""
        close = self.match[open_idx]
        out = []
        if close < 0:
            return out
        k = open_idx + 1
        T, V = self.T, self.V
        while k < close:
            key = None
            if T[k] == "name" and k + 1 < close and V[k + 1] == "=" and T[k + 1] == "sym":
                key = V[k]; a = k + 2
            elif V[k] == "[" and T[k] == "sym" and self.match[k] > 0 and V[self.match[k] + 1] == "=":
                m = self.match[k]
                key = V[k + 1] if (m == k + 2 and T[k + 1] in ("str", "num")) else {"expr": self.text(k + 1, m)}
                a = m + 2
            else:
                a = k
            b = self.expr_end(a)
            if b <= a:
                b = a + 1
            b = min(b, close)
            out.append((key, a, b))
            k = b
            if k < close and V[k] in (",", ";"):
                k += 1
        return out

    def value(self, a, b):
        T, V = self.T, self.V
        if b - a == 1:
            if T[a] == "str":
                return V[a]
            if T[a] == "num":
                try:
                    return float(V[a].replace("_", "")) if ("." in V[a] or "e" in V[a].lower()) and not V[a].lower().startswith("0x") else int(V[a].replace("_", ""), 0)
                except ValueError:
                    return {"expr": V[a]}
            if V[a] == "true":
                return True
            if V[a] == "false":
                return False
            if V[a] == "nil":
                return None
        if b - a == 2 and V[a] == "-" and T[a + 1] == "num":
            v = self.value(a + 1, b)
            return -v if isinstance(v, (int, float)) else {"expr": self.text(a, b)}
        return {"expr": self.text(a, b)}

    def table_to_py(self, open_idx):
        fields = self.table_fields(open_idx)
        if fields and all(k is None for k, _, _ in fields):
            return [self._tv(a, b) for _, a, b in fields]
        out = {}
        pos = 1
        for k, a, b in fields:
            if k is None:
                k = pos; pos += 1
            out[k if isinstance(k, str) else json.dumps(k)] = self._tv(a, b)
        return out

    def _tv(self, a, b):
        if self.V[a] == "{" and self.T[a] == "sym" and self.match[a] == b - 1:
            return self.table_to_py(a)
        return self.value(a, b)

    # ------------------------------------------------------------------ bindings
    def _bindings(self):
        T, V, n = self.T, self.V, self.n
        self.funcs_by_start = {f["start"]: f for f in self.funcs}
        self.bind = {}  # name -> list of dict(pos, end, kind, ...)
        script_segs = self.path.split(".")

        def add(name, pos, end, b):
            b["pos"], b["end"], b["name"] = pos, end, name
            self.bind.setdefault(name, []).append(b)
            return b

        self._script_segs = script_segs
        for f in self.funcs:
            for idx, p in enumerate(f["params"]):
                add(p, f["body"], f["end"], {"kind": "param", "func": f["id"], "idx": idx})
            if f["kind"] in ("local", "global") and f["name"]:
                # visible from its own body onward within the declaring block
                add(f["name"], f["start"], self.scope_end(f["start"]), {"kind": "function", "func": f["id"]})
        i = 0
        while i < n:
            t, v = T[i], V[i]
            if t == "kw" and v == "for":
                names, k = [], i + 1
                while k < n and T[k] == "name":
                    names.append(V[k]); k += 1
                    if V[k] == ":" :  # type annotation
                        while k < n and V[k] not in (",", "in", "="):
                            k += 1
                    if V[k] == ",":
                        k += 1
                    else:
                        break
                d = k
                while d < n and not (T[d] == "kw" and V[d] == "do"):
                    if T[d] == "kw" and V[d] == "function":
                        d = self.funcs_by_start[d]["end"]
                    d += 1
                end = self.block_end.get(d, n)
                vals = [None] * len(names)
                if k < n and V[k] == "in":
                    vals = self._loop_values(k + 1, d, len(names), i)
                for nm, val in zip(names, vals):
                    add(nm, d, end, val or {"kind": "dynamic", "why": "loop variable"})
                i = k
                continue
            if t == "kw" and v == "local" and i + 1 < n and T[i + 1] == "name":
                names, k = [], i + 1
                while k < n and T[k] == "name":
                    names.append(V[k]); k += 1
                    if k < n and V[k] == ":":
                        depth = 0
                        while k < n:
                            if V[k] in ("(", "{", "<"):
                                depth += 1
                            elif V[k] in (")", "}", ">"):
                                depth -= 1
                            elif depth == 0 and (V[k] in (",", "=") or (T[k] in ("kw",) and V[k] not in ("nil", "true", "false"))):
                                break
                            elif depth == 0 and T[k] == "name" and T[k - 1] == "name":
                                break
                            k += 1
                    if k < n and V[k] == ",":
                        k += 1
                    else:
                        break
                send = self.scope_end(i)
                if k < n and V[k] == "=" and T[k] == "sym":
                    a = k + 1
                    ranges = []
                    while True:
                        b = self.expr_end(a)
                        ranges.append((a, b))
                        if b < n and V[b] == "," and b > a:
                            a = b + 1
                        else:
                            break
                    stop = ranges[-1][1]
                    for idx, nm in enumerate(names):
                        if idx < len(ranges):
                            bd = self.classify(ranges[idx][0], ranges[idx][1], ranges[idx][0])
                        else:
                            bd = {"kind": "unknown"}
                        bd["decl"] = True
                        bd["def"] = i
                        add(nm, max(stop, k + 1), send, bd)
                    i = k + 1
                    continue
                for nm in names:
                    add(nm, k, send, {"kind": "decl_only", "decl": True, "def": i})
                i = k
                continue
            if (t == "name" and i + 1 < n and V[i + 1] == "=" and T[i + 1] == "sym" and not self.in_table[i]
                    and (i == 0 or not (T[i - 1] == "sym" and V[i - 1] in (".", ":", ",")) and V[i - 1] not in ("for", "local"))):
                a = i + 2
                b = self.expr_end(a)
                cur = self.lookup(v, i)
                self_ref = any(T[x] == "name" and V[x] == v and (x == a or V[x - 1] not in (".", ":")) for x in range(a, b))
                if cur and cur["kind"] in ("param", "loopvals", "vararg") and self_ref:
                    cur.setdefault("transformed", self.text(a, b))
                else:
                    decl = cur
                    send = decl["end"] if decl else n
                    bd = self.classify(a, b, a)
                    bd["def"] = i
                    if decl is not None:
                        bd["decl_of"] = decl.get("decl_of", decl["pos"])
                    add(v, max(b, a), send, bd)
            i += 1
        for lst in self.bind.values():
            lst.sort(key=lambda b: b["pos"])

    def _loop_values(self, a, d, count, for_idx):
        T, V = self.T, self.V
        out = [None] * count
        if not (T[a] == "name" and V[a] in ("ipairs", "pairs") and V[a + 1] == "(" and self.match[a + 1] > 0):
            return out
        mode = V[a]
        x, y = a + 2, self.match[a + 1]
        open_idx = None
        if V[x] == "{" and self.match[x] == y - 1:
            open_idx = x
        elif y - x == 1 and T[x] == "name":
            b = self.lookup(V[x], for_idx)
            if b and b["kind"] == "table" and self._single_assignment(V[x], b):
                open_idx = b["open"]
        if open_idx is None:
            return out
        fields = self.table_fields(open_idx)
        if len(fields) == 1 and fields[0][0] is None and V[fields[0][1]] == "..." and fields[0][2] - fields[0][1] == 1:
            fid = self.func_of[for_idx]
            if fid >= 0 and self.funcs[fid]["vararg"] and count >= 2:
                out[1] = {"kind": "vararg", "func": fid, "idx": len(self.funcs[fid]["params"])}
            return out
        if mode == "ipairs":
            vals = [V[fa] for k, fa, fb in fields if k is None and fb - fa == 1 and T[fa] == "str"]
            if vals and len(vals) == len(fields) and count >= 2:
                out[1] = {"kind": "loopvals", "values": vals, "table_line": self.L[open_idx]}
        else:
            keys = [k for k, fa, fb in fields if isinstance(k, str)]
            if keys and len(keys) == len(fields):
                out[0] = {"kind": "loopvals", "values": keys, "table_line": self.L[open_idx]}
            vals = [V[fa] for k, fa, fb in fields if fb - fa == 1 and T[fa] == "str"]
            if vals and len(vals) == len(fields) and count >= 2:
                out[1] = {"kind": "loopvals", "values": vals, "table_line": self.L[open_idx]}
        return out

    def _single_assignment(self, name, b):
        """True when the declaration `b` is never reassigned as a whole."""
        return not any(o is not b and o.get("decl_of") == b["pos"] for o in self.bind.get(name, ()))

    def lookup(self, name, pos):
        best = None
        for b in self.bind.get(name, ()):
            if b["pos"] <= pos < b["end"]:
                if best is None or b["pos"] >= best["pos"]:
                    best = b
        if best is not None and best["kind"] == "decl_only":
            later = [b for b in self.bind.get(name, ()) if b.get("decl_of") == best["pos"] and b["kind"] not in ("unknown", "decl_only")]
            if len(later) == 1:
                return later[0]
        return best

    def classify(self, a, b, pos):
        T, V = self.T, self.V
        if b <= a:
            return {"kind": "unknown"}
        if b - a == 1:
            if T[a] == "str":
                return {"kind": "const", "value": V[a]}
            if T[a] == "num":
                return {"kind": "num", "value": self.value(a, b)}
        if V[a] == "{" and T[a] == "sym" and self.match[a] == b - 1:
            return {"kind": "table", "open": a}
        if b - a >= 3 and T[a] == "str" and V[a + 1] == "..":
            return {"kind": "prefix", "value": V[a], "expr": self.text(a, b)}
        if b - a >= 5:
            vals = self.choice_values(a, b)
            if vals:
                return {"kind": "loopvals", "values": vals, "choice": True}
        if T[a] == "kw" and V[a] == "function":
            return {"kind": "function", "func": self.funcs_by_start[a]["id"]}
        if T[a] == "name" and V[a] == "require" and a + 1 < b and V[a + 1] == "(":
            m = self.match[a + 1]
            if m > 0 and m <= b - 1:
                r = self.resolve(a + 2, m, pos)
                return {"kind": "require", "path": path_str(r) if r and not r["dyn"] else None,
                        "expr": self.text(a + 2, m), "line": self.L[a]}
        inst = self._instance_expr(a, b)
        if inst:
            return inst
        # A or B / A and B
        groups = self._split_logic(a, b)
        for ga, gb in groups:
            inst = self._instance_expr(ga, gb)
            r = self.resolve(ga, gb, pos)
            if r and r["segs"]:
                out = {"kind": "path", "segs": r["segs"], "dyn": r["dyn"], "line": self.L[ga]}
                alts = []
                for oa, ob in groups:
                    orr = self.resolve(oa, ob, pos)
                    if orr and orr["segs"] and path_str(orr) not in alts:
                        alts.append(path_str(orr))
                if len(alts) > 1:
                    out["alternatives"] = alts
                for oa, ob in groups:
                    oi = self._instance_expr(oa, ob)
                    if oi:
                        out["fallback_new"] = oi["cls"]
                        out["props"] = {}
                        out["prop_lines"] = {}
                return out
        for ga, gb in groups:
            inst = self._instance_expr(ga, gb)
            if inst:
                return inst
        # <something unresolved>:WaitForChild("Literal"): keep the child name, mark the parent unknown
        if (b - a >= 6 and V[b - 1] == ")" and self.match[b - 1] > a + 2 and V[self.match[b - 1] - 1] in ("WaitForChild", "FindFirstChild")
                and V[self.match[b - 1] - 2] == ":"):
            o = self.match[b - 1]
            ar = self.args(o)
            if ar and ar[0][1] - ar[0][0] == 1 and T[ar[0][0]] == "str":
                ra, rb = self.recv_range(o - 2)
                if ra == a:
                    return {"kind": "path", "segs": [("?", self.text(ra, rb), None, None), V[ar[0][0]]], "dyn": True,
                            "line": self.L[a], "parent_unresolved": True}
        return {"kind": "unknown", "expr": self.text(a, b, 80)}

    def _split_logic(self, a, b):
        """Operands to try, in order: for `x or y` each side; for `x and y` the last operand."""
        T, V = self.T, self.V
        ors, cur, k = [], a, a
        segs = []
        while k < b:
            if T[k] == "sym" and V[k] in ("(", "{", "[") and self.match[k] > 0:
                k = self.match[k] + 1
                continue
            if T[k] == "kw" and V[k] == "function":
                k = self.funcs_by_start[k]["end"] + 1
                continue
            if T[k] == "kw" and V[k] in ("or", "and"):
                segs.append((cur, k, V[k])); cur = k + 1
            k += 1
        segs.append((cur, b, None))
        if len(segs) == 1:
            return [(a, b)]
        out, group = [], []
        for sa, sb, op in segs:
            group.append((sa, sb))
            if op != "and":
                out.append(group[-1])
                group = []
        return out

    def _instance_expr(self, a, b):
        T, V = self.T, self.V
        if b - a >= 6 and V[a] == "Instance" and V[a + 1] == "." and V[a + 2] == "new" and V[a + 3] == "(" and self.match[a + 3] == b - 1:
            ar = self.args(a + 3)
            if ar and ar[0][1] - ar[0][0] == 1 and T[ar[0][0]] == "str":
                d = {"kind": "instance", "cls": V[ar[0][0]], "props": {}, "prop_lines": {}, "line": self.L[a], "factory": None}
                if len(ar) > 1:
                    d["props"]["Parent"] = {"expr": self.text(*ar[1])}
                return d
            return None
        # factory form: f("Class", { props }, parent)
        k = a
        if T[k] != "name":
            return None
        while k + 2 < b and V[k + 1] in (".", ":") and T[k + 2] == "name":
            k += 2
        if k + 1 < b and V[k + 1] == "(" and self.match[k + 1] == b - 1:
            ar = self.args(k + 1)
            if (len(ar) >= 2 and ar[0][1] - ar[0][0] == 1 and T[ar[0][0]] == "str" and V[ar[0][0]] in KNOWN_CLASSES
                    and V[ar[1][0]] == "{" and self.match[ar[1][0]] == ar[1][1] - 1):
                d = {"kind": "instance", "cls": V[ar[0][0]], "props": {}, "prop_lines": {}, "line": self.L[a],
                     "factory": self.text(a, k + 1)}
                for key, fa, fb in self.table_fields(ar[1][0]):
                    if isinstance(key, str):
                        d["props"][key] = self.value(fa, fb)
                        d["prop_lines"][key] = self.L[fa]
                if len(ar) > 2:
                    d["props"].setdefault("Parent", {"expr": self.text(*ar[2])})
                return d
        return None

    def resolve(self, a, b, pos):
        """Resolve an instance path expression. Returns {'segs': [...], 'dyn': bool} or None.
        A dynamic segment is ('?', source text)."""
        T, V = self.T, self.V
        while b - a >= 2 and V[a] == "(" and self.match[a] == b - 1:
            a, b = a + 1, b - 1
        if b <= a:
            return None
        if any(T[k] == "kw" and V[k] in ("or", "and") for k in range(a, b)):
            groups = self._split_logic(a, b)
            if len(groups) > 1 or groups[0] != (a, b):
                for ga, gb in groups:
                    r = self.resolve(ga, gb, pos)
                    if r and r["segs"]:
                        return r
                return None
        h = V[a]
        dyn = False
        if T[a] != "name":
            return None
        if h == "assert" and b - a >= 4 and V[a + 1] == "(" and self.match[a + 1] == b - 1:
            ar = self.args(a + 1)
            return self.resolve(ar[0][0], ar[0][1], pos) if ar else None
        is_game = False
        if h == "game":
            segs = []; is_game = True
        elif h == "workspace":
            segs = ["Workspace"]
        elif h == "script":
            segs = list(self._script_segs)
        else:
            bd = self.lookup(h, pos)
            if not bd or bd["kind"] != "path":
                return None
            segs = list(bd["segs"]); dyn = bd.get("dyn", False)
        k = a + 1
        while k < b:
            v = V[k]
            if v == "." and k + 1 < b and T[k + 1] == "name":
                nm = V[k + 1]
                if nm == "Parent":
                    if not segs:
                        return None
                    segs.pop()
                else:
                    segs.append(nm)
                k += 2
            elif v == ":" and k + 2 < b and T[k + 1] == "name" and V[k + 2] == "(" and 0 < self.match[k + 2] < b:
                meth = V[k + 1]
                close = self.match[k + 2]
                ar = self.args(k + 2)
                if meth == "GetService" and is_game and not segs and ar and T[ar[0][0]] == "str":
                    segs = [V[ar[0][0]]]
                elif meth in ("WaitForChild", "FindFirstChild") and ar:
                    src = self.name_source(ar[0][0], ar[0][1], pos)
                    if src[0] == "lit" and len(src[1]) == 1:
                        segs.append(src[1][0])
                    else:
                        segs.append(("?", self.text(*ar[0]), ar[0], src[1] if src[0] == "lit" else None))
                        dyn = True
                else:
                    return None
                k = close + 1
            elif v == "[" and self.match[k] == k + 2 and T[k + 1] == "str":
                segs.append(V[k + 1]); k += 3
            elif v == "::":
                break
            else:
                return None
        return {"segs": segs, "dyn": dyn}

    def choice_values(self, a, b, depth=0):
        """String values an and/or expression can yield (`c and "A" or "B"`), or None."""
        T, V = self.T, self.V
        while b - a >= 2 and V[a] == "(" and self.match[a] == b - 1:
            a, b = a + 1, b - 1
        if b - a == 1:
            return [V[a]] if T[a] == "str" else None
        if depth > 4 or not any(T[k] == "kw" and V[k] in ("and", "or") for k in range(a, b)):
            return None
        groups = self._split_logic(a, b)
        if groups == [(a, b)]:
            return None
        out = []
        for ga, gb in groups:
            v = self.choice_values(ga, gb, depth + 1)
            if not v:
                return None
            out += [x for x in v if x not in out]
        return out

    def name_source(self, a, b, pos):
        """Where a name argument comes from. ('lit', [values]) | ('param', fid, idx) |
        ('vararg', fid, idx) | ('prefix', text, expr) | ('dyn', expr)."""
        T, V = self.T, self.V
        while b - a >= 2 and V[a] == "(" and self.match[a] == b - 1:
            a, b = a + 1, b - 1
        if b - a == 1:
            if T[a] == "str":
                return ("lit", [V[a]])
            if T[a] == "name":
                bd = self.lookup(V[a], pos)
                if bd:
                    if bd["kind"] == "const" and self._single_assignment(V[a], bd) and not bd.get("decl_of"):
                        return ("lit", [bd["value"]])
                    if bd["kind"] == "prefix" and self._single_assignment(V[a], bd) and not bd.get("decl_of"):
                        return ("prefix", bd["value"], bd["expr"])
                    if bd["kind"] == "loopvals":
                        return ("lit", list(bd["values"]))
                    if bd["kind"] == "param":
                        return ("param", bd["func"], bd["idx"])
                    if bd["kind"] == "vararg":
                        return ("vararg", bd["func"], bd["idx"])
        if b - a >= 5:
            vals = self.choice_values(a, b)
            if vals:
                return ("lit", vals)
        if b - a >= 3 and T[a] == "str" and V[a + 1] == "..":
            return ("prefix", V[a], self.text(a, b))
        if b - a == 4 and T[a] == "name" and V[a] == "tostring" and V[a + 1] == "(" and T[a + 2] == "name":
            return self.name_source(a + 2, a + 3, pos)
        return ("dyn", self.text(a, b))


def path_str(r):
    segs = r["segs"] if isinstance(r, dict) else r
    return ".".join(s if isinstance(s, str) else "<" + s[1] + ">" for s in segs)


# ====================================================================== extraction
class Extractor:
    def __init__(self, scripts):
        self.scripts = scripts
        self.by_path = {s.path: s for s in scripts}
        self.exports = {}      # script path -> module table name
        self.work = []         # pending templates (script, fid, template)

    # ---- emission -------------------------------------------------------------
    def emit(self, s, cat, base, fields, line, pos, via=None):
        """fields: {field: source}. Sources are name_source tuples, or ('path', str),
        ('keys', [...], {lits}), ('none',)."""
        fid = None
        for f, src in fields.items():
            if src[0] in ("param", "vararg"):
                fid = src[1]
                break
        if fid is not None:
            tpl = {"cat": cat, "base": base, "fields": fields, "line": line}
            key = json.dumps([cat, base, {k: list(v[:3]) for k, v in fields.items()}], sort_keys=True, default=str)
            seen = s.templates.setdefault(fid, {})
            if key not in seen:
                seen[key] = tpl
                self.work.append((s, fid, tpl))
            return
        item = dict(base)
        item["line"] = line
        fn = s.enclosing_named(pos)
        if fn:
            item["in_function"] = fn
        if via:
            item["via"] = via
        multi = []
        for f, src in fields.items():
            kind = src[0]
            if kind == "lit":
                if len(src[1]) == 1:
                    item[f] = src[1][0]
                else:
                    multi.append((f, src[1]))
            elif kind == "path":
                item[f] = src[1]
            elif kind == "keys":
                item[f + "_keys"] = src[1]
                if src[2]:
                    item[f + "_literals"] = src[2]
            elif kind == "none":
                pass
            elif kind == "prefix":
                item[f] = None
                item[f + "_pattern"] = src[1] + "*"
                item[f + "_expr"] = src[2]
                s.unresolved.append({"category": cat, "field": f, "line": line,
                                     "detail": "name built at run time: " + src[2]})
            elif f == "receiver_path":
                item[f] = None
                item["receiver"] = src[1]
                item["receiver_kind"] = self.receiver_kind(str(src[1]), None)
            else:
                item[f] = None
                item[f + "_expr"] = src[1]
                if f in ("payload",):
                    pass
                else:
                    s.unresolved.append({"category": cat, "field": f, "line": line,
                                         "detail": "not a literal: " + str(src[1])})
        combos = [item]
        for f, vals in multi:
            nxt = []
            for base_item in combos:
                for val in vals:
                    it = dict(base_item); it[f] = val
                    it.setdefault("via", "literal list")
                    nxt.append(it)
            combos = nxt
        s.items.setdefault(cat, []).extend(combos)

    def payload_source(self, s, a, b, pos):
        T, V = s.T, s.V
        if b <= a:
            return ("none",)
        if V[a] == "{" and s.match[a] == b - 1:
            keys, lits = [], {}
            for k, fa, fb in s.table_fields(a):
                if isinstance(k, str):
                    keys.append(k)
                    if fb - fa == 1 and T[fa] == "str":
                        lits[k] = V[fa]
                elif k is None:
                    keys.append("[positional]")
                else:
                    keys.append("[" + k["expr"] + "]")
            return ("keys", keys, lits)
        # `payload or {}` -> the first operand
        e = a
        while e < b and not (T[e] == "kw" and V[e] in ("or", "and")):
            e += 1
        if e - a == 1 and T[a] == "name":
            bd = s.lookup(V[a], pos)
            if bd and bd["kind"] == "param":
                return ("param", bd["func"], bd["idx"])
            if bd and bd["kind"] == "table":
                return self.payload_source(s, bd["open"], s.match[bd["open"]] + 1, pos)
        return ("dyn", s.text(a, b))

    def path_source(self, s, a, b, pos):
        if b - a == 1 and s.T[a] == "name":
            bd = s.lookup(s.V[a], pos)
            if bd and bd.get("alternatives"):
                return ("dyn", "chosen at run time, one of: " + " | ".join(bd["alternatives"]))
        r = s.resolve(a, b, pos)
        if r and r["segs"]:
            if not r["dyn"]:
                return ("path", path_str(r))
            return ("dyn", path_str(r))
        if b - a == 1 and s.T[a] == "name":
            bd = s.lookup(s.V[a], pos)
            if bd and bd["kind"] == "param":
                return ("param", bd["func"], bd["idx"])
        return ("dyn", s.text(a, b))

    @staticmethod
    def receiver_kind(text, path):
        if path:
            if path == "Players.LocalPlayer":
                return "player"
            if path.startswith("Players.LocalPlayer.PlayerGui"):
                return "playerGui" if path.endswith("PlayerGui") else "gui"
            if path.startswith("Players.LocalPlayer.Character"):
                return "character"
            if path.startswith("ReplicatedStorage.Config"):
                return "config"
            if path.startswith("Workspace"):
                return "workspace"
            if path.startswith("Players.LocalPlayer.PlayerScripts"):
                return "playerScripts"
        last = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text or "")
        last = last[-1].lower() if last else ""
        if last in ("player", "plr", "localplayer", "owner", "otherplayer", "targetplayer", "other", "driver", "passenger", "opponent"):
            return "player?"
        if last == "playergui":
            return "playerGui?"
        if "character" in last or last == "char":
            return "character?"
        if "vehicle" in last or last in ("car", "model"):
            return "vehicle?"
        if "config" in last or last in ("cfg", "settings", "layout", "colours", "colors", "assets", "defaults", "effects", "folder"):
            return "config?"
        if last == "script":
            return "script"
        return "other"

    # ---- per script scan -------------------------------------------------------
    def scan(self, s):
        T, V, L, n = s.T, s.V, s.L, s.n
        # module return table
        for i in range(n - 1, -1, -1):
            if T[i] == "kw" and V[i] == "return" and s.func_of[i] == -1:
                if i + 1 < n and T[i + 1] == "name":
                    self.exports[s.path] = V[i + 1]
                break
        for i in range(n):
            t, v = T[i], V[i]
            if t == "name":
                nxt = V[i + 1] if i + 1 < n else ""
                prev = V[i - 1] if i else ""
                prev_sym = prev if i and T[i - 1] == "sym" else ""
                if nxt == "(" and T[i + 1] == "sym" and s.match[i + 1] > 0:
                    self._call(s, i, v, prev_sym)
                elif prev_sym == "." and v in ("Name", "Text") and i + 1 < n:
                    self._compare(s, i, v)
                if v in SERVICES_TRACKED or (prev_sym not in (".", ":") and nxt in (".", ":")):
                    self._service_member(s, i)
                if s.in_table[i] and v == "Name" and nxt == "=" and T[i + 1] == "sym" and prev_sym in ("{", ",", ";"):
                    self._table_name(s, i)
                if prev_sym not in (".", ":") and nxt == "[" and s.match[i + 1] > 0:
                    self._name_set(s, i)
            elif t == "sym" and v == "=" and not s.in_table[i] and i >= 3 and T[i - 1] == "name" and V[i - 2] == "." and T[i - 2] == "sym":
                self._prop_write(s, i)
        self._public_api(s)

    def _call(self, s, i, name, prev_sym):
        T, V, L = s.T, s.V, s.L
        open_idx = i + 1
        line = L[i]
        ar = s.args(open_idx)
        if prev_sym in (".", ":"):
            ra, rb = s.recv_range(i - 1)
            rtext = s.text(ra, rb)
            rres = s.resolve(ra, rb, i)
            rpath = path_str(rres) if rres and rres["segs"] else None
        else:
            ra = rb = i
            rtext, rres, rpath = "", None, None

        is_def = ra > 0 and T[ra - 1] == "kw" and V[ra - 1] == "function"
        if is_def:
            return
        member = prev_sym in (".", ":")
        req = None
        if name == "require" and not member and ar:
            req = ar[0]
        elif name == "pcall" and not member and len(ar) >= 2 and ar[0][1] - ar[0][0] == 1 and V[ar[0][0]] == "require":
            req = ar[1]
        if req:
            r = s.resolve(req[0], req[1], i)
            item = {"expr": s.text(*req)}
            if name == "pcall":
                item["protected"] = True
            if i >= 2 and V[i - 1] == "=" and T[i - 2] == "name":
                item["as"] = V[i - 2]
            dyn = [x for x in (r["segs"] if r else []) if not isinstance(x, str)]
            if r and r["segs"] and not dyn:
                self.emit(s, "requires", item, {"target": ("path", path_str(r))}, line, i)
            elif r and len(dyn) == 1 and len(dyn[0]) > 3 and dyn[0][3]:
                targets = [".".join(v if x is dyn[0] else x for x in r["segs"]) for v in dyn[0][3]]
                self.emit(s, "requires", item, {"target": ("lit", targets)}, line, i)
            else:
                self.emit(s, "requires", item, {"target": ("dyn", path_str(r) if r and r["segs"] else s.text(*req))}, line, i)
            return
        if prev_sym == ":" and name in ("InvokeServer", "FireServer"):
            fields = {"remote": self.path_source(s, ra, rb, i)}
            first_is_table = ar and V[ar[0][0]] == "{"
            if ar and not first_is_table:
                fields["action"] = s.name_source(ar[0][0], ar[0][1], i)
                fields["payload"] = self.payload_source(s, ar[1][0], ar[1][1], i) if len(ar) > 1 else ("none",)
            elif ar:
                fields["payload"] = self.payload_source(s, ar[0][0], ar[0][1], i)
            base = {"method": name, "receiver": rtext, "arg_count": len(ar)}
            if "action" in fields and fields["action"][0] == "dyn":
                # first argument is not an action name (e.g. an instance): keep as text, not unresolved
                base["first_arg_expr"] = fields.pop("action")[1]
            self.emit(s, "remote_calls", base, fields, line, i)
            return
        if prev_sym == ":" and name in ("Connect", "Once", "ConnectParallel") and rb - ra >= 1:
            self._connect(s, i, ra, rb, rtext, ar, line)
            return
        if prev_sym == ":" and name in ("Fire", "Invoke") and rtext:
            bd = s.lookup(V[ra], i) if rb - ra == 1 else None
            src = None
            created = False
            if bd and bd["kind"] == "instance":
                if bd["cls"] not in ("BindableEvent", "BindableFunction"):
                    return
                created = True
                nm = bd["props"].get("Name")
                src_name = ("lit", [nm]) if isinstance(nm, str) else ("dyn", (nm or {}).get("expr", "unnamed instance") if isinstance(nm, dict) else "unnamed instance")
                fields = {"name": src_name}
                base_extra = {"lookup": "created in this script (line %d)" % bd["line"]}
            else:
                fields, base_extra = self._bindable_ref(s, ra, rb, i)
                if fields is None:
                    # Signal-style member (Module.Changed:Fire) or unknown receiver
                    kind = "signal_fires" if (rb - ra >= 3 and V[rb - 2] == ".") else None
                    if kind and name == "Fire":
                        s.items.setdefault(kind, []).append({"receiver": rtext, "line": line, "in_function": s.enclosing_named(i)})
                    elif name == "Fire" or name == "Invoke":
                        s.unresolved.append({"category": "bindable_" + name.lower(), "line": line,
                                             "detail": "receiver not resolved to an instance path: " + rtext})
                    return
            base = {"receiver": rtext, "created_here": created}
            base.update(base_extra)
            if name == "Invoke":
                if ar:
                    fields["action"] = s.name_source(ar[0][0], ar[0][1], i)
                    if fields["action"][0] == "dyn":
                        base["first_arg_expr"] = fields.pop("action")[1]
                fields["payload"] = self.payload_source(s, ar[1][0], ar[1][1], i) if len(ar) > 1 else ("none",)
                self.emit(s, "bindable_invokes", base, fields, line, i)
            else:
                fields["payload"] = self.payload_source(s, ar[0][0], ar[0][1], i) if ar else ("none",)
                base["arg_count"] = len(ar)
                if len(ar) > 1:
                    base["args"] = [s.text(a, b, 60) for a, b in ar]
                self.emit(s, "bindable_fires", base, fields, line, i)
            return
        if prev_sym == ":" and name in ("GetAttribute", "SetAttribute", "GetAttributeChangedSignal") and ar:
            cat = {"GetAttribute": "attribute_reads", "SetAttribute": "attribute_writes",
                   "GetAttributeChangedSignal": "attribute_listens"}[name]
            base = {"receiver": rtext, "receiver_path": rpath, "receiver_kind": self.receiver_kind(rtext, rpath)}
            if name == "SetAttribute" and len(ar) > 1:
                val = s.value(*ar[1])
                base["value"] = val
            fields = {"name": s.name_source(ar[0][0], ar[0][1], i)}
            if rpath is None and rb - ra == 1:
                bd = s.lookup(V[ra], i)
                if bd and bd["kind"] == "param":
                    fields["receiver_path"] = ("param", bd["func"], bd["idx"])
                    base.pop("receiver_path")
            self.emit(s, cat, base, fields, line, i)
            return
        if prev_sym == ":" and name in ("FindFirstChild", "WaitForChild", "FindFirstAncestor", "FindFirstDescendant") and ar:
            base = {"method": name, "receiver": rtext, "receiver_path": rpath,
                    "root": (rpath.split(".")[0] if rpath else None)}
            if name == "FindFirstChild" and len(ar) > 1 and V[ar[1][0]] == "true":
                base["recursive"] = True
            fields = {"name": s.name_source(ar[0][0], ar[0][1], i)}
            if rpath is None and rb - ra == 1:
                bd = s.lookup(V[ra], i)
                if bd and bd["kind"] == "param":
                    fields["receiver_path"] = ("param", bd["func"], bd["idx"])
                    base.pop("receiver_path")
            self.emit(s, "lookups", base, fields, line, i)
            return
        if prev_sym == ":" and name == "IsA":
            return
        if prev_sym == ":" and name in ("BindToRenderStep", "UnbindFromRenderStep") and ar:
            base = {"method": name}
            if name == "BindToRenderStep" and len(ar) > 1:
                base["priority_expr"] = s.text(*ar[1])
                base["priority"] = self._priority(s, ar[1])
                if len(ar) > 2:
                    base["callback"] = s.text(ar[2][0], ar[2][1], 60)
            self.emit(s, "render_steps", base, {"name": s.name_source(ar[0][0], ar[0][1], i)}, line, i)
            return
        if prev_sym == ":" and name in ("BindAction", "BindActionAtPriority", "UnbindAction") and ar:
            base = {"method": name}
            keys_from = None
            if name == "BindAction" and len(ar) >= 3:
                base["create_touch_button"] = s.value(*ar[2]); keys_from = 3
            elif name == "BindActionAtPriority" and len(ar) >= 4:
                base["create_touch_button"] = s.value(*ar[2])
                base["priority_expr"] = s.text(*ar[3])
                base["priority"] = self._priority(s, ar[3])
                keys_from = 4
            if keys_from is not None:
                base["inputs"] = [s.text(a, b) for a, b in ar[keys_from:]]
            self.emit(s, "context_actions", base, {"name": s.name_source(ar[0][0], ar[0][1], i)}, line, i)
            return
        if prev_sym == ":" and name in ("SetCore", "SetCoreGuiEnabled", "GetCore", "GetCoreGuiEnabled"):
            s.items.setdefault("startergui_core", []).append(
                {"method": name, "receiver": rtext, "args": [s.text(a, b, 80) for a, b in ar], "line": line,
                 "in_function": s.enclosing_named(i)})
            return
        if name in ("find", "match", "sub", "lower", "upper") and prev_sym in (".", ":"):
            self._text_search(s, i, name, prev_sym, ra, rb, rtext, ar, line)
        if name == "new" and prev_sym == "." and rtext == "Instance" and ar and T[ar[0][0]] == "str":
            cls = V[ar[0][0]]
            s.instance_classes[cls] = s.instance_classes.get(cls, 0) + 1
        elif len(ar) >= 2 and T[ar[0][0]] == "str" and ar[0][1] - ar[0][0] == 1 and V[ar[0][0]] in KNOWN_CLASSES and V[ar[1][0]] == "{":
            cls = V[ar[0][0]]
            s.instance_classes[cls] = s.instance_classes.get(cls, 0) + 1
        # audio bridge
        if prev_sym in (".", ":") and rb - ra == 1:
            bd = s.lookup(V[ra], i)
            if bd and bd["kind"] == "require" and bd["path"]:
                if bd["path"].endswith(".PresentationAudioBridge"):
                    base = {"method": name, "receiver": rtext, "args": [s.text(a, b, 60) for a, b in ar]}
                    fields = {}
                    if ar:
                        fields["cue"] = s.name_source(ar[0][0], ar[0][1], i)
                        if fields["cue"][0] == "dyn":
                            base["cue_expr"] = fields.pop("cue")[1]
                        last = ar[-1]
                        if len(ar) > 1 and V[last[0]] == "{":
                            fields["payload"] = self.payload_source(s, last[0], last[1], i)
                    self.emit(s, "audio_bridge", base, fields, line, i)
                if not is_def:
                    s.ext_calls.append((bd["path"], name, open_idx))
        # same-file call sites for wrapper expansion
        if not is_def:
            if not member:
                bd = s.lookup(name, i)
                if bd and bd["kind"] == "function":
                    s.calls.setdefault(bd["func"], []).append(open_idx)
            else:
                for fid in s.members.get(name, ()):
                    s.calls.setdefault(fid, []).append(open_idx)

    def _priority(self, s, rng):
        txt = s.text(*rng).replace(" ", "")
        m = re.fullmatch(r"Enum\.(RenderPriority|ContextActionPriority)\.(\w+)\.Value(?:([+-])(\d+))?", txt)
        if m:
            table = RENDER_PRIORITY if m.group(1) == "RenderPriority" else {"Low": 1000, "Medium": 2000, "Default": 2000, "High": 3000}
            if m.group(2) in table:
                base = table[m.group(2)]
                if m.group(3):
                    base += int(m.group(4)) * (1 if m.group(3) == "+" else -1)
                return base
        v = s.value(*rng)
        return v if isinstance(v, (int, float)) else None

    def _bindable_ref(self, s, ra, rb, pos):
        """Resolve a bindable receiver to (fields, base) or (None, None)."""
        r = s.resolve(ra, rb, pos)
        if not r or not r["segs"]:
            return None, None
        segs = r["segs"]
        last = segs[-1]
        parent = path_str(segs[:-1])
        if any(not isinstance(x, str) for x in segs[:-1]):
            if isinstance(last, str):
                return {"name": ("lit", [last])}, {"lookup": parent, "lookup_unresolved": True}
            return {"name": ("dyn", path_str(segs))}, {"lookup": parent}
        if not (parent.startswith("Players.LocalPlayer.PlayerScripts") or parent.startswith("ReplicatedFirst")
                or parent.startswith("ReplicatedStorage") or parent.startswith("Players.LocalPlayer")):
            # a path, but not somewhere bindables live: treat as a signal object
            return None, None
        if isinstance(last, str):
            return {"name": ("lit", [last])}, {"lookup": parent}
        a, b = last[2]
        return {"name": s.name_source(a, b, pos)}, {"lookup": parent}

    def _connect(self, s, i, ra, rb, rtext, ar, line):
        T, V = s.T, s.V
        # receiver ends with a member:  X.Signal   or   X:GetAttributeChangedSignal("N")
        handler = self._handler(s, ar[0]) if ar else None
        if V[rb - 1] == ")":
            return  # GetAttributeChangedSignal(...) and friends are recorded at their own call
        if rb - ra < 3 or V[rb - 2] != ".":
            return
        sig = V[rb - 1]
        oa, ob = ra, rb - 2
        otext = s.text(oa, ob)
        ores = s.resolve(oa, ob, i)
        opath = path_str(ores) if ores and ores["segs"] else None
        base = {"signal": sig, "receiver": otext, "method": V[i]}
        if handler:
            base.update(handler)
        if sig == "OnClientEvent":
            self.emit(s, "remote_listens", base, {"remote": self.path_source(s, oa, ob, i)}, line, i)
        elif sig == "Event":
            bd = s.lookup(V[oa], i) if ob - oa == 1 else None
            if bd and bd["kind"] == "instance" and bd["cls"] in ("BindableEvent", "BindableFunction"):
                nm = bd["props"].get("Name")
                base["lookup"] = "created in this script (line %d)" % bd["line"]
                base["created_here"] = True
                self.emit(s, "bindable_connects", base,
                          {"name": ("lit", [nm]) if isinstance(nm, str) else ("dyn", "unnamed instance")}, line, i)
                return
            fields, extra = self._bindable_ref(s, oa, ob, i)
            if fields is None:
                # e.g. introEvent(name).Event:Connect  -> wrapper call returning the bindable
                if V[ob - 1] == ")" and s.match[ob - 1] > 0 and T[s.match[ob - 1] - 1] == "name":
                    cidx = s.match[ob - 1]
                    car = s.args(cidx)
                    base["lookup"] = "returned by " + V[cidx - 1] + "()"
                    if car:
                        self.emit(s, "bindable_connects", base, {"name": s.name_source(car[0][0], car[0][1], i)}, line, i)
                        return
                s.unresolved.append({"category": "bindable_connect", "line": line,
                                     "detail": "receiver not resolved to an instance path: " + otext})
                return
            base.update(extra)
            if isinstance(fields["name"], tuple) and fields["name"][0] == "lit":
                bd = s.lookup(V[oa], i) if ob - oa == 1 else None
                if bd and bd.get("fallback_new"):
                    base["created_if_missing"] = True
            self.emit(s, "bindable_connects", base, fields, line, i)
        elif sig in RUN_SIGNALS and (opath == "RunService" or otext.endswith("RunService")):
            s.items.setdefault("run_connects", []).append({"signal": sig, "method": V[i], "line": line,
                                                           "in_function": s.enclosing_named(i),
                                                           "callback": s.text(ar[0][0], ar[0][1], 50) if ar else ""})
        elif opath == "UserInputService":
            s.items.setdefault("uis_connects", []).append({"signal": sig, "method": V[i], "line": line,
                                                           "in_function": s.enclosing_named(i)})
        elif opath in ("GuiService", "ProximityPromptService", "ContextActionService", "StarterGui"):
            s.items.setdefault("service_connects", []).append({"service": opath, "signal": sig, "line": line,
                                                               "in_function": s.enclosing_named(i)})

    def _handler(self, s, rng):
        """Describe an event handler: payload fields read and literal discriminators."""
        T, V = s.T, s.V
        a, b = rng
        f = None
        if T[a] == "kw" and V[a] == "function":
            f = s.funcs_by_start[a]
        elif b - a == 1 and T[a] == "name":
            bd = s.lookup(V[a], a)
            if bd and bd["kind"] == "function":
                f = s.funcs[bd["func"]]
            else:
                return {"handler": V[a]}
        if not f:
            return {"handler": s.text(a, b, 60)}
        out = {"handler": f["full"] or "inline", "handler_line": f["line"], "handler_params": f["params"]}
        if not f["params"]:
            return out
        p = f["params"][0]
        fields, disc, alias = [], {}, {}
        k = f["body"]
        while k < f["end"]:
            if T[k] == "name" and V[k] == p and V[k - 1] not in (".", ":"):
                if V[k + 1] == "." and T[k + 2] == "name":
                    fld = V[k + 2]
                    if fld not in fields:
                        fields.append(fld)
                    if V[k + 3] in ("==", "~=") and T[k + 4] == "str":
                        disc.setdefault(fld, [])
                        if V[k + 4] not in disc[fld]:
                            disc[fld].append(V[k + 4])
                    j = k - 1
                    if V[j] == "(" and V[j - 1] in ("tostring", "tonumber"):
                        j -= 2
                    if V[j] == "=" and T[j - 1] == "name" and V[j - 2] not in (".", ":"):
                        alias[V[j - 1]] = fld
                elif V[k + 1] in ("==", "~=") and T[k + 2] == "str":
                    disc.setdefault("<" + p + ">", [])
                    if V[k + 2] not in disc["<" + p + ">"]:
                        disc["<" + p + ">"].append(V[k + 2])
            elif T[k] == "name" and V[k] in alias and V[k - 1] not in (".", ":") and V[k + 1] in ("==", "~=") and T[k + 2] == "str":
                fld = alias[V[k]]
                disc.setdefault(fld, [])
                if V[k + 2] not in disc[fld]:
                    disc[fld].append(V[k + 2])
            k += 1
        if fields:
            out["payload_fields_read"] = fields
        if disc:
            out["literal_comparisons"] = disc
        return out

    def _compare(self, s, i, prop):
        """`.Name == x` / `.Text == x` (also wrapped: string.upper(o.Text) == x)."""
        T, V, L = s.T, s.V, s.L
        k = i + 1
        while k < s.n and V[k] == ")" and T[k] == "sym":
            k += 1
        if k >= s.n or V[k] not in ("==", "~="):
            # literal on the left:  "X" == o.Name
            ra, rb = s.recv_range(i - 1)
            if ra >= 2 and V[ra - 1] in ("==", "~=") and T[ra - 2] == "str" and prop == "Name":
                self.emit(s, "lookups", {"method": "NameCompare", "receiver": s.text(ra, rb), "receiver_path": None, "root": None},
                          {"name": ("lit", [V[ra - 2]])}, L[i], i)
            return
        wrapped = k > i + 1
        ra, rb = s.recv_range(i - 1)
        rtext = s.text(ra, rb)
        a = k + 1
        b = a + 1
        # right operand: a literal, an identifier or a call
        if T[a] == "name":
            b = a + 1
            while b < s.n and V[b] in (".", ":") and T[b + 1] == "name":
                b += 2
            if b < s.n and V[b] == "(" and s.match[b] > 0:
                b = s.match[b] + 1
        src = s.name_source(a, b, i)
        if prop == "Name":
            if wrapped:
                return
            base = {"method": "NameCompare", "receiver": rtext, "receiver_path": None, "root": None}
            if src[0] == "dyn":
                # comparing two run-time names is not a reserved-name lookup
                return
            base.update(self._receiver_context(s, i, V[ra] if rb - ra == 1 else None))
            self.emit(s, "lookups", base, {"name": src}, L[i], i)
        else:
            base = {"method": "TextCompare", "receiver": rtext, "operator": V[k]}
            # is the Text wrapped in string.upper / string.lower?
            j = ra - 1
            if j >= 3 and V[j] == "(" and V[j - 1] in ("upper", "lower") and V[j - 3] == "string":
                base["transform"] = "string." + V[j - 1]
            if src[0] == "dyn":
                return
            self.emit(s, "text_compares", base, {"text": src}, L[i], i)

    def _receiver_context(self, s, i, rname):
        """For a name compare on `rname`: classes checked with IsA and properties written on the
        same variable inside the innermost enclosing block."""
        if not rname:
            return {}
        T, V = s.T, s.V
        blk = s.blk_of[i]
        a = blk if blk >= 0 else 0
        b = s.block_end.get(blk, s.n) if blk >= 0 else s.n
        isa, writes = [], []
        for k in range(a, min(b, a + 4000)):
            if T[k] == "name" and V[k] == rname and V[k - 1] not in (".", ":"):
                if V[k + 1] == ":" and V[k + 2] == "IsA" and T[k + 4] == "str":
                    if V[k + 4] not in isa:
                        isa.append(V[k + 4])
                elif V[k + 1] == "." and T[k + 2] == "name" and V[k + 3] == "=" and T[k + 3] == "sym":
                    if V[k + 2] not in writes:
                        writes.append(V[k + 2])
        out = {}
        if isa:
            out["receiver_isa"] = isa
        if writes:
            out["receiver_property_writes"] = writes
        return out

    def _text_search(self, s, i, name, prev_sym, ra, rb, rtext, ar, line):
        T, V = s.T, s.V
        if name not in ("find", "match"):
            return
        subject, pattern = None, None
        if prev_sym == "." and rtext == "string" and len(ar) >= 2:
            subject, pattern = ar[0], ar[1]
        elif prev_sym == ":" and ar:
            subject, pattern = (ra, rb), ar[0]
        if not subject:
            return
        stext = s.text(*subject)
        if not re.search(r"\.Text\b", stext):
            return
        src = s.name_source(pattern[0], pattern[1], i)
        if src[0] == "dyn":
            s.unresolved.append({"category": "text_search", "line": line, "detail": "pattern is not a literal: " + src[1]})
            return
        self.emit(s, "text_compares", {"method": "string." + name, "receiver": stext}, {"text": src}, line, i)

    def _service_member(self, s, i):
        T, V = s.T, s.V
        v = V[i]
        k = None
        service = None
        prev_sym = V[i - 1] if i and T[i - 1] == "sym" else ""
        if v == "game" and V[i + 1] == ":" and V[i + 2] == "GetService" and V[i + 3] == "(" and T[i + 4] == "str" and V[i + 5] == ")":
            if V[i + 4] in SERVICES_TRACKED:
                service, k = V[i + 4], i + 6
        elif prev_sym not in (".", ":") and V[i + 1] in (".", ":"):
            bd = s.lookup(v, i)
            if bd and bd["kind"] == "path" and len(bd["segs"]) == 1 and bd["segs"][0] in SERVICES_TRACKED:
                service, k = bd["segs"][0], i + 1
        if not service or k >= s.n or V[k] not in (".", ":") or T[k + 1] != "name":
            return
        member = V[k + 1]
        nxt = V[k + 2] if k + 2 < s.n else ""
        if V[k] == ":":
            kind = "call"
        elif nxt == "=" and T[k + 2] == "sym":
            kind = "write"
        elif nxt == ":" and V[k + 3] in ("Connect", "Once"):
            kind = "connect"
        else:
            kind = "read"
        rec = {"service": service, "member": member, "kind": kind, "line": s.L[i], "in_function": s.enclosing_named(i)}
        if kind == "write":
            rec["value"] = s.text(k + 3, s.expr_end(k + 3), 60)
        s.service_uses.append(rec)

    def _table_name(self, s, i):
        T, V = s.T, s.V
        a = i + 2
        b = s.expr_end(a)
        # which call is this table an argument of?
        k = i - 1
        depth = 0
        open_idx = None
        while k >= 0:
            if T[k] == "sym":
                if V[k] in (")", "}", "]") and s.match[k] >= 0:
                    k = s.match[k] - 1
                    continue
                if V[k] == "{":
                    open_idx = k
                    break
            k -= 1
        callee, cls = None, None
        if open_idx is not None:
            j = open_idx - 1
            # walk back over earlier arguments to the '(' of the call
            while j >= 0 and not (T[j] == "sym" and V[j] == "(" and s.match[j] > open_idx):
                if T[j] == "sym" and V[j] in (")", "}", "]") and s.match[j] >= 0:
                    j = s.match[j] - 1
                    continue
                if T[j] == "sym" and V[j] in ("{", "=") or (T[j] == "kw" and V[j] not in ("nil", "true", "false", "and", "or", "not")):
                    j = -1
                    break
                j -= 1
            if j > 0 and T[j - 1] == "name":
                ca, _ = s.recv_range(j - 1) if V[j - 2] in (".", ":") else (j - 1, j - 1)
                ca = min(ca, j - 1)
                callee = s.text(ca, j)
                ar = s.args(j)
                if ar and ar[0][1] - ar[0][0] == 1 and T[ar[0][0]] == "str" and V[ar[0][0]] in KNOWN_CLASSES and len(ar) > 1 and ar[1][0] == open_idx:
                    cls = V[ar[0][0]]
        base = {"via": "table_field", "callee": callee, "class": cls}
        self.emit(s, "names_assigned", base, {"name": s.name_source(a, b, i)}, s.L[i], i, via="table_field")

    def _name_set(self, s, i):
        """T[x.Name] where T is a literal table: the keys are names this script matches."""
        T, V = s.T, s.V
        m = s.match[i + 1]
        if not (m - 3 >= i + 2 and V[m - 1] == "Name" and V[m - 2] == "."):
            return
        bd = s.lookup(V[i], i)
        if not bd or bd["kind"] != "table":
            if bd is None or bd["kind"] in ("unknown", "decl_only", "param", "dynamic"):
                s.unresolved.append({"category": "lookups", "line": s.L[i],
                                     "detail": "names matched through table %s[...Name], contents not literal" % V[i]})
            return
        keys = []
        for key, fa, fb in s.table_fields(bd["open"]):
            if isinstance(key, str):
                keys.append(key)
            elif key is None and fb - fa == 1 and T[fa] == "str":
                keys.append(V[fa])
        if keys:
            base = {"method": "NameSet", "receiver": s.text(i + 2, m - 2), "receiver_path": None, "root": None,
                    "table": V[i], "table_line": s.L[bd["open"]]}
            base.update(self._receiver_context(s, i, V[i + 2] if m - 2 - (i + 2) == 1 else None))
            self.emit(s, "lookups", base, {"name": ("lit", keys)}, s.L[i], i)

    def _prop_write(self, s, i):
        T, V, L = s.T, s.V, s.L
        prop = V[i - 1]
        ra, rb = s.recv_range(i - 2)
        if ra > 0 and T[ra - 1] == "sym" and V[ra - 1] in (".", ":"):
            return
        rtext = s.text(ra, rb)
        a = i + 1
        b = s.expr_end(a)
        line = L[i]
        bd = s.lookup(V[ra], i) if rb - ra == 1 else None
        inst = bd if bd and (bd["kind"] == "instance" or bd.get("fallback_new")) else None
        if inst is not None:
            cls = inst.get("cls") or inst.get("fallback_new")
            val = s.value(a, b)
            if prop == "Name" and isinstance(val, dict):
                ns = s.name_source(a, b, i)
                if ns[0] == "lit" and len(ns[1]) == 1:
                    val = ns[1][0]
            inst["props"].setdefault(prop, val)
            inst["prop_lines"].setdefault(prop, line)
            inst.setdefault("writes", []).append({"property": prop, "value": val, "line": line})
        if prop == "Name":
            cls = (inst.get("cls") or inst.get("fallback_new")) if inst else None
            self.emit(s, "names_assigned", {"via": "property", "receiver": rtext, "class": cls},
                      {"name": s.name_source(a, b, i)}, line, i)
        elif prop == "Enabled":
            rpath = None
            r = s.resolve(ra, rb, i)
            if r and r["segs"]:
                rpath = path_str(r)
            like, why = "unknown", ""
            if inst is not None:
                cls = inst.get("cls") or inst.get("fallback_new")
                like, why = ("yes", "created here as " + cls) if cls in ("ScreenGui", "BillboardGui", "SurfaceGui") else ("no", "created here as " + str(cls))
            elif rpath and rpath.startswith("Players.LocalPlayer.PlayerGui."):
                like, why = "yes", "child of PlayerGui"
            elif rb - ra == 1:
                fid = s.func_of[i]
                fa = s.funcs[fid]["start"] if fid >= 0 else 0
                fb = s.funcs[fid]["end"] if fid >= 0 else s.n
                classes = []
                for k in range(fa, fb):
                    if T[k] == "name" and V[k] == V[ra] and V[k + 1] == ":" and V[k + 2] == "IsA" and T[k + 4] == "str":
                        classes.append(V[k + 4])
                if any(c in ("ScreenGui", "LayerCollector", "GuiBase2d") for c in classes):
                    like, why = "yes", "IsA(%s) guard in the same function" % ",".join(sorted(set(classes)))
                elif classes:
                    like, why = "no", "IsA(%s) in the same function" % ",".join(sorted(set(classes)))
            item = {"receiver": rtext, "receiver_path": rpath, "value": s.value(a, b), "screengui_like": like,
                    "reason": why, "line": line, "in_function": s.enclosing_named(i)}
            if inst is not None and isinstance(inst["props"].get("Name"), str):
                item["screengui_name"] = inst["props"]["Name"]
            elif rpath and like == "yes":
                item["screengui_name"] = rpath.rsplit(".", 1)[-1]
            s.items.setdefault("enabled_writes", []).append(item)
        elif prop in ("OnInvoke", "OnClientInvoke"):
            base = {"receiver": rtext, "kind": prop}
            base.update(self._handler(s, (a, b)) or {})
            if prop == "OnInvoke":
                fields, extra = self._bindable_ref(s, ra, rb, i)
                if inst is not None:
                    nm = inst["props"].get("Name")
                    fields, extra = {"name": ("lit", [nm]) if isinstance(nm, str) else ("dyn", "unnamed instance")}, {"lookup": "created in this script"}
                if fields is None:
                    fields, extra = {"name": ("dyn", rtext)}, {}
                base.update(extra)
                self.emit(s, "bindable_handlers", base, fields, line, i)
            else:
                self.emit(s, "remote_listens", base, {"remote": self.path_source(s, ra, rb, i)}, line, i)

    def _public_api(self, s):
        m = self.exports.get(s.path)
        if not m:
            return
        T, V = s.T, s.V
        api, seen = [], set()
        for f in s.funcs:
            if f["kind"] == "member" and f["owner"] == m and f["full"] and f["full"].count(".") + f["full"].count(":") == 1:
                if f["name"] not in seen:
                    seen.add(f["name"])
                    api.append({"name": f["name"], "kind": "function", "params": f["params"], "line": f["line"]})
        for i in range(1, s.n - 3):
            if T[i] == "name" and V[i] == m and V[i + 1] == "." and T[i + 2] == "name" and V[i + 3] == "=" and T[i + 3] == "sym" \
                    and V[i - 1] not in (".", ":") and not s.in_table[i]:
                if V[i + 2] not in seen:
                    seen.add(V[i + 2])
                    api.append({"name": V[i + 2], "kind": "field", "line": s.L[i], "value": s.text(i + 4, s.expr_end(i + 4), 60)})
        api.sort(key=lambda x: x["line"])
        s.items["public_api"] = api

    # ---- wrapper expansion -----------------------------------------------------
    def expand(self):
        ext_index = {}
        for s in self.scripts:
            for target, fname, open_idx in s.ext_calls:
                ext_index.setdefault((target, fname), []).append((s, open_idx))
        done = set()
        guard = 0
        while self.work and guard < 200000:
            guard += 1
            s, fid, tpl = self.work.pop()
            f = s.funcs[fid]
            sites = [(s, o) for o in s.calls.get(fid, ())]
            if f["kind"] == "member" and f["owner"] == self.exports.get(s.path):
                sites += ext_index.get((s.path, f["name"]), [])
            tpl["sites"] = tpl.get("sites", 0)
            for cs, open_idx in sites:
                key = (id(tpl), cs.path, open_idx)
                if key in done:
                    continue
                done.add(key)
                tpl["sites"] += 1
                ar = cs.args(open_idx)
                fields = {}
                for fld, src in tpl["fields"].items():
                    if src[0] in ("param", "vararg") and src[1] == fid:
                        idx = src[2]
                        if src[0] == "vararg":
                            vals, bad = [], []
                            for a, b in ar[idx:]:
                                ns = cs.name_source(a, b, open_idx)
                                if ns[0] == "lit":
                                    vals += ns[1]
                                else:
                                    bad.append(cs.text(a, b))
                            if bad:
                                cs.unresolved.append({"category": tpl["cat"], "field": fld, "line": cs.L[open_idx],
                                                      "detail": "non-literal argument to %s(): %s" % (f["name"], ", ".join(bad))})
                            if not vals:
                                fields = None
                                break
                            fields[fld] = ("lit", vals)
                        elif idx >= len(ar):
                            if fld in ("payload", "receiver_path"):
                                fields[fld] = ("none",)
                            else:
                                fields = None  # the name argument is omitted (nil): no lookup happens at this site
                                break
                        else:
                            a, b = ar[idx]
                            if fld == "payload":
                                fields[fld] = self.payload_source(cs, a, b, open_idx)
                            elif fld in ("remote", "receiver_path"):
                                fields[fld] = self.path_source(cs, a, b, open_idx)
                            else:
                                fields[fld] = cs.name_source(a, b, open_idx)
                    else:
                        fields[fld] = src if src[0] not in ("param", "vararg") else ("dyn", "outer parameter")
                if fields is None:
                    continue
                base = dict(tpl["base"])
                base["wrapper_defined"] = "%s:%d" % (s.name, tpl["line"])
                if "receiver_path" in fields and fields["receiver_path"][0] == "path":
                    base["receiver_kind"] = self.receiver_kind("", fields["receiver_path"][1])
                    if "root" in base:
                        base["root"] = fields["receiver_path"][1].split(".")[0]
                self.emit(cs, tpl["cat"], base, fields, cs.L[open_idx], open_idx, via="wrapper %s()" % (f["full"] or f["name"]))
        # wrappers that nobody calls with a literal
        for s in self.scripts:
            for fid, tpls in s.templates.items():
                for tpl in tpls.values():
                    if not tpl.get("sites"):
                        f = s.funcs[fid]
                        s.unresolved.append({"category": tpl["cat"], "line": tpl["line"],
                                             "detail": "name comes from parameter of %s(); no call site found statically" % (f["full"] or f["name"] or "anonymous function")})


# ====================================================================== post-processing
SCREENGUI_PROPS = ("Name", "DisplayOrder", "ResetOnSpawn", "IgnoreGuiInset", "ScreenInsets", "ZIndexBehavior",
                   "Enabled", "ClipToDeviceSafeArea", "SafeAreaCompatibility", "Parent")


def collect_instances(s):
    """ScreenGuis, bindables and ProximityPrompts created in this script."""
    guis, bindables, prompts = [], [], []
    seen = set()
    for lst in s.bind.values():
        for b in lst:
            cls = b.get("cls") if b["kind"] == "instance" else b.get("fallback_new")
            if not cls or id(b) in seen:
                continue
            seen.add(id(b))
            props = b.get("props", {})
            if b["kind"] == "path" and b.get("fallback_new"):
                # `existing or Instance.new(cls)`: the looked-up name is the instance name
                last = b["segs"][-1]
                if isinstance(last, str):
                    props = dict(props); props.setdefault("Name", last)
            rec = {"variable": b["name"], "class": cls, "line": b.get("line"), "factory": b.get("factory"),
                   "adopts_existing": bool(b.get("fallback_new"))}
            if cls in ("ScreenGui", "BillboardGui", "SurfaceGui"):
                for p in SCREENGUI_PROPS:
                    if p in props:
                        rec[p] = props[p]
                rec["enabled_writes"] = [w for w in b.get("writes", []) if w["property"] == "Enabled"]
                rec["property_lines"] = {k: v for k, v in b.get("prop_lines", {}).items() if k in SCREENGUI_PROPS}
                guis.append(rec)
            elif cls in ("BindableEvent", "BindableFunction"):
                rec["Name"] = props.get("Name")
                rec["Parent"] = props.get("Parent")
                bindables.append(rec)
            elif cls == "ProximityPrompt":
                rec["properties"] = {k: v for k, v in props.items()}
                rec["writes"] = b.get("writes", [])
                prompts.append(rec)
    key = lambda r: r["line"] or 0
    return sorted(guis, key=key), sorted(bindables, key=key), sorted(prompts, key=key)


def parse_clientbase(s):
    bd = None
    for b in s.bind.get("entries", ()):
        if b["kind"] == "table":
            bd = b
    if not bd:
        raise SystemExit("ClientBase: local `entries` table not found")
    raw = s.table_to_py(bd["open"])
    entries = []
    for (key, a, b), e in zip(s.table_fields(bd["open"]), raw):
        deps = e.get("dependencies", [])
        entries.append({"name": e.get("name"), "path": e.get("path"),
                        "dependencies": deps if isinstance(deps, list) else [],
                        "tool": e.get("tool"), "line": s.L[a]})
    return entries, s.L[bd["open"]]


def ui_marker_reasons(s):
    reasons = []
    names = set(v for t, v in zip(s.T, s.V) if t == "name")
    strs = set(v for t, v in zip(s.T, s.V) if t == "str")
    for m in UI_MARKERS:
        if m in names or m in strs:
            reasons.append("references " + m)
    hit = sorted(c for c in s.instance_classes if c in UI_CLASSES)
    if hit:
        reasons.append("creates " + ", ".join(hit))
    return reasons


def onboarding_targets(s):
    """Tables of the onboarding client: pages -> cards -> resolver calls."""
    T, V = s.T, s.V

    def table(name):
        for b in s.bind.get(name, ()):
            if b["kind"] == "table":
                return b["open"]
        return None

    missing = []
    out = {"script": s.path, "pages": {}, "cards": {}, "helper_kinds": {}, "missing_tables": missing}
    # helper traits
    local_funcs = {f["name"]: f for f in s.funcs if f["kind"] == "local" and f["name"]}
    direct, callees = {}, {}
    for name, f in local_funcs.items():
        tr, cal = [], []
        for k in range(f["body"], f["end"]):
            if T[k] != "name":
                continue
            v = V[k]
            if v == "Name" and V[k - 1] == "." and V[k + 1] in ("==", "~=") and T[k + 2] == "name":
                tr.append("name")
            elif v == "Text" and V[k - 1] == ".":
                tr.append("text")
            elif v == "FindFirstChild" and V[k + 1] == "(" and T[k + 2] == "name":
                tr.append("child-of-PlayerGui" if V[k - 2] == "playerGui" else "child")
            elif v == "GetAttribute" and T[k + 2] == "str":
                tr.append("attribute:" + V[k + 2])
            elif v == "IsA" and T[k + 2] == "str":
                tr.append("isa:" + V[k + 2])
            elif v in local_funcs and v != name and V[k + 1] == "(" and V[k - 1] not in (".", ":"):
                cal.append(v)
        direct[name], callees[name] = tr, cal

    def traits(name, seen=()):
        res = list(direct.get(name, []))
        for c in callees.get(name, []):
            if c not in seen:
                for t in traits(c, seen + (name,)):
                    if t not in res:
                        res.append(t)
        return list(dict.fromkeys(res))

    def calls_in(a, b):
        res = []
        k = a
        while k < b:
            if T[k] == "name" and V[k + 1] == "(" and s.match[k + 1] > 0 and V[k - 1] not in (".", ":") and V[k] in local_funcs:
                lits, dyn = [], []
                for x, y in s.args(k + 1):
                    if y - x == 1 and T[x] == "str":
                        lits.append(V[x])
                    elif not (y - x == 1 and T[x] == "name"):
                        dyn.append(s.text(x, y, 60))
                if lits:
                    kinds = [t for t in traits(V[k]) if not t.startswith("isa:")]
                    out["helper_kinds"].setdefault(V[k], traits(V[k]))
                    res.append({"helper": V[k], "literals": lits, "match_on": kinds, "line": s.L[k]})
            k += 1
        return res

    def simple(name):
        o = table(name)
        if o is None:
            missing.append(name)
            return {}
        v = s.table_to_py(o)
        return v if isinstance(v, dict) else {"[list]": v}

    copy, pages = simple("copy"), simple("pages")
    placement, action_steps = simple("placement"), simple("actionSteps")
    order = table("pageOrder")
    out["page_order"] = s.table_to_py(order) if order is not None else None
    res_open, sig_open = table("resolvers"), table("pageSignals")
    resolvers, signals = {}, {}
    for nm, o, dest in (("resolvers", res_open, resolvers), ("pageSignals", sig_open, signals)):
        if o is None:
            missing.append(nm)
            continue
        for key, a, b in s.table_fields(o):
            if isinstance(key, str):
                dest[key] = {"line": s.L[a], "targets": calls_in(a, b), "source": s.text(a, b, 400)}
    card_page = {}
    for page, cards in pages.items():
        cards = cards if isinstance(cards, list) else []
        sig = signals.get(page)
        out["pages"][page] = {"cards": cards, "signal_line": sig and sig["line"], "signal_targets": sig["targets"] if sig else None,
                              "signal_source": sig and sig["source"]}
        for c in cards:
            card_page[c] = page
    for page, sig in signals.items():
        if page not in out["pages"]:
            out["pages"][page] = {"cards": [], "signal_line": sig["line"], "signal_targets": sig["targets"], "signal_source": sig["source"]}
    for card in list(dict.fromkeys(list(copy) + list(resolvers) + list(card_page))):
        r = resolvers.get(card)
        out["cards"][card] = {"page": card_page.get(card), "copy": copy.get(card), "placement": placement.get(card),
                              "action_step": action_steps.get(card) is True,
                              "resolver_line": r and r["line"], "targets": r["targets"] if r else None,
                              "resolver_source": r and r["source"]}
    return out


CATS = ["requires", "remote_calls", "remote_listens", "bindable_fires", "bindable_connects", "bindable_invokes",
        "bindable_handlers", "signal_fires", "attribute_reads", "attribute_writes", "attribute_listens",
        "enabled_writes", "names_assigned", "lookups", "text_compares", "render_steps", "run_connects",
        "context_actions", "uis_connects", "service_connects", "audio_bridge", "startergui_core", "public_api"]


def build_contract(s, reasons):
    items = {c: sorted(s.items.get(c, []), key=lambda x: x.get("line", 0)) for c in CATS}
    guis, bindables, prompts = collect_instances(s)
    attrs = items["attribute_reads"] + items["attribute_writes"] + items["attribute_listens"]
    config_reads = [dict(a, access=("read" if a in items["attribute_reads"] else "write" if a in items["attribute_writes"] else "listen"))
                    for a in attrs if a.get("receiver_kind") in ("config", "config?")]
    config_paths = {}
    for lst in s.bind.values():
        for b in lst:
            if b["kind"] == "path":
                p = path_str(b["segs"])
                if p.startswith("ReplicatedStorage.Config"):
                    config_paths.setdefault(p, b.get("line"))
    for a in attrs + items["lookups"]:
        p = a.get("receiver_path")
        if p and p.startswith("ReplicatedStorage.Config"):
            config_paths.setdefault(p, a["line"])
    services = {}
    for u in s.service_uses:
        services.setdefault(u["service"], []).append({k: v for k, v in u.items() if k != "service"})
    player_writes = [a for a in items["attribute_writes"] if a.get("receiver_kind", "").rstrip("?") in ("player", "character", "playerGui")]
    ui_audio = [dict(a, access=("read" if a in items["attribute_reads"] else "write" if a in items["attribute_writes"] else "listen"))
                for a in attrs if isinstance(a.get("name"), str) and a["name"].startswith("UIAudio")]
    contract = {
        "script": s.path, "class": s.cls, "source_file": "classic/sources/" + s.file, "source_lines": s.line_count,
        "included_because": reasons,
        "requires": items["requires"],
        "remotes": {"calls": items["remote_calls"], "listens": items["remote_listens"]},
        "bindables": {"fires": items["bindable_fires"], "connects": items["bindable_connects"],
                      "invokes": items["bindable_invokes"], "handlers": items["bindable_handlers"],
                      "created": bindables, "module_signal_fires": items["signal_fires"]},
        "attributes": {"reads": items["attribute_reads"], "writes": items["attribute_writes"],
                       "listens": items["attribute_listens"]},
        "player_attribute_writes": player_writes,
        "screenguis": {"created": guis, "enabled_writes": items["enabled_writes"]},
        "names": {"assigned": items["names_assigned"], "looked_up": items["lookups"],
                  "text_compared": items["text_compares"]},
        "run_service": {"render_steps": items["render_steps"], "connects": items["run_connects"]},
        "context_actions": items["context_actions"],
        "user_input_service": {"connects": items["uis_connects"], "members_used": services.get("UserInputService", [])},
        "audio": {"bridge_calls": items["audio_bridge"], "ui_audio_attributes": ui_audio},
        "config": {"paths": [{"path": p, "line": l} for p, l in sorted(config_paths.items())], "attribute_reads": config_reads,
                   "child_lookups": [l for l in items["lookups"] if (l.get("receiver_path") or "").startswith("ReplicatedStorage.Config")
                                     and l.get("via", "").startswith("wrapper")]},
        "startergui_core": items["startergui_core"],
        "gui_service": services.get("GuiService", []),
        "other_services": {k: v for k, v in services.items() if k not in ("UserInputService", "GuiService", "RunService")},
        "service_connects": items["service_connects"],
        "proximity_prompts": prompts,
        "instances_created_by_class": dict(sorted(s.instance_classes.items())),
        "public_api": items["public_api"],
        "unresolved": sorted(s.unresolved, key=lambda x: x["line"]),
    }
    return contract


def counts(c):
    return {
        "requires": len(c["requires"]),
        "remote_calls": len(c["remotes"]["calls"]), "remote_listens": len(c["remotes"]["listens"]),
        "bindable_fires": len(c["bindables"]["fires"]), "bindable_connects": len(c["bindables"]["connects"]),
        "bindable_invokes": len(c["bindables"]["invokes"]) + len(c["bindables"]["handlers"]),
        "attr_reads": len(c["attributes"]["reads"]), "attr_writes": len(c["attributes"]["writes"]),
        "attr_listens": len(c["attributes"]["listens"]),
        "screenguis": len(c["screenguis"]["created"]),
        "enabled_writes": len([w for w in c["screenguis"]["enabled_writes"] if w["screengui_like"] == "yes"]),
        "names_assigned": len(c["names"]["assigned"]), "lookups": len(c["names"]["looked_up"]),
        "text_compares": len(c["names"]["text_compared"]),
        "run_bindings": len(c["run_service"]["render_steps"]) + len(c["run_service"]["connects"]),
        "context_actions": len(c["context_actions"]), "uis_connects": len(c["user_input_service"]["connects"]),
        "audio": len(c["audio"]["bridge_calls"]) + len(c["audio"]["ui_audio_attributes"]),
        "config_reads": len(c["config"]["attribute_reads"]) + len(c["config"]["child_lookups"]),
        "unresolved": len(c["unresolved"]),
    }


# ====================================================================== main
def run(write=True):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    KNOWN_CLASSES.clear()
    for e in manifest:
        KNOWN_CLASSES.update(INSTANCE_NEW_RE.findall((SOURCES / e["file"]).read_bytes().decode("utf-8", errors="replace")))
    scripts = [Script(e) for e in manifest]
    ex = Extractor(scripts)
    for s in scripts:
        ex.scan(s)
    ex.expand()
    by_path = ex.by_path

    cb = next(s for s in scripts if s.path.endswith(".ClientBase") and s.cls == "LocalScript")
    entries, entries_line = parse_clientbase(cb)

    # ---- owner set -----------------------------------------------------------
    owners = {}

    def include(path, why):
        if path in by_path:
            owners.setdefault(path, [])
            if why not in owners[path]:
                owners[path].append(why)

    include(cb.path, "composition root (holds the entries table)")
    for e in entries:
        include(e["path"], "ClientBase entry '%s'" % e["name"])
    for s in scripts:
        if s.path.startswith("ReplicatedStorage.Modules.Game.UI."):
            include(s.path, "under ReplicatedStorage.Modules.Game.UI")
        if s.path.startswith("ReplicatedFirst.Loading."):
            include(s.path, "under ReplicatedFirst.Loading")
    for s in scripts:
        if s.path.startswith(CLIENT_ROOTS) and s.path not in owners:
            why = ui_marker_reasons(s)
            if why:
                include(s.path, "client script that is UI-coupled: " + "; ".join(why))
    for p in list(owners):
        for q in by_path[p].items.get("requires", []):
            if q.get("via") == "literal list" and isinstance(q.get("target"), str) and q["target"].startswith(CLIENT_ROOTS):
                include(q["target"], "loaded by %s from a literal name list (line %d)" % (by_path[p].name, q["line"]))
    # client modules required by an owner that create instances or touch attributes of the player
    owner_rule = [
        "1. StarterPlayerScripts.ClientBase itself and every path in its `entries` table (read from source).",
        "2. Every script under ReplicatedStorage.Modules.Game.UI.",
        "3. Every script under ReplicatedFirst.Loading.",
        "4. Any other script under ReplicatedStorage, ReplicatedFirst or StarterPlayer whose code (comments removed) "
        "references PlayerGui, PlayerScripts, ContextActionService, SetCore or SetCoreGuiEnabled, or creates one of: "
        + ", ".join(sorted(UI_CLASSES)) + ".",
        "5. Any client module an owner loads from a literal list of names (`pcall(require, folder:FindFirstChild(name))`): "
        "this is how ActivityClient loads the activity views.",
        "Server scripts (ServerStorage, ServerScriptService) and Workspace scripts get no contract file; they are still "
        "scanned so that cross-reference tables can name them as writers, readers or consumers.",
    ]

    name_count = {}
    for p in owners:
        name_count[by_path[p].name] = name_count.get(by_path[p].name, 0) + 1
    contracts = {}
    for p in sorted(owners):
        s = by_path[p]
        c = build_contract(s, owners[p])
        fname = (s.name if name_count[s.name] == 1 else p) + ".json"
        c["contract_file"] = fname
        contracts[p] = c
    all_contracts = {s.path: (contracts.get(s.path) or build_contract(s, [])) for s in scripts}

    def side(path):
        return "client" if path.startswith(CLIENT_ROOTS) else "server" if path.startswith("Server") else "workspace"

    # ---- requires graph -------------------------------------------------------
    required_by = {}
    for p, c in all_contracts.items():
        for r in c["requires"]:
            if r.get("target"):
                required_by.setdefault(r["target"], [])
                if p not in required_by[r["target"]]:
                    required_by[r["target"]].append(p)

    # ---- reserved names -------------------------------------------------------
    definers, patterns = {}, []
    for p, c in all_contracts.items():
        if side(p) != "client":
            continue
        for a in c["names"]["assigned"]:
            rec = {"script": p, "line": a["line"], "via": a.get("via"), "class": a.get("class"), "callee": a.get("callee")}
            if isinstance(a.get("name"), str):
                definers.setdefault(a["name"], []).append(rec)
            elif a.get("name_pattern"):
                patterns.append(dict(rec, pattern=a["name_pattern"], expr=a.get("name_expr")))
        for g in c["screenguis"]["created"]:
            if isinstance(g.get("Name"), str) and not any(d["script"] == p and d["line"] == g["property_lines"].get("Name") for d in definers.get(g["Name"], [])):
                definers.setdefault(g["Name"], []).append({"script": p, "line": g["property_lines"].get("Name", g["line"]), "via": "factory_props", "class": g["class"], "callee": g.get("factory")})
    consumers = {}
    for p, c in all_contracts.items():
        for l in c["names"]["looked_up"]:
            if not isinstance(l.get("name"), str):
                continue
            if l.get("root") in STATIC_ROOTS:
                continue
            rp = l.get("receiver_path") or ""
            if rp.startswith("Players.LocalPlayer.PlayerScripts") or rp == "Players.LocalPlayer":
                kind = "playerScripts"
            else:
                kind = "gui-or-world"
            consumers.setdefault(l["name"], []).append({"script": p, "line": l["line"], "method": l["method"],
                                                        "receiver": l.get("receiver"), "receiver_path": l.get("receiver_path"),
                                                        "via": l.get("via"), "scope": kind})
    reserved, undefined, self_only = {}, {}, {}
    for name, cons in sorted(consumers.items()):
        defs = definers.get(name, [])
        other = [c for c in cons if not defs or any(d["script"] != c["script"] for d in defs)]
        if defs and any(c["script"] not in {d["script"] for d in defs} for c in cons):
            ext = [c for c in cons if c["script"] not in {d["script"] for d in defs}]
            reserved[name] = {"definers": defs, "consumers": ext,
                              "also_looked_up_by_definer": sorted({c["script"] for c in cons} & {d["script"] for d in defs})}
        elif defs:
            self_only[name] = {"definers": defs, "lookups": [c for c in cons if c["scope"] != "playerScripts"]}
            if not self_only[name]["lookups"]:
                del self_only[name]
        if not defs:
            pat = [p for p in patterns if name.startswith(p["pattern"][:-1]) and len(p["pattern"]) > 1]
            gui_cons = [c for c in cons if c["scope"] != "playerScripts" and side(c["script"]) == "client" and c["script"] in owners
                        and (c["receiver_path"] is None or c["receiver_path"].startswith("Players.LocalPlayer.PlayerGui"))]
            if gui_cons:
                undefined[name] = {"consumers": gui_cons, "possible_pattern_definers": pat}
    reserved_doc = {
        "generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
        "meaning": "An instance name that one script assigns (.Name = \"x\", a Name field in a property table, or a "
                   "created ScreenGui) and a DIFFERENT script looks up (FindFirstChild / WaitForChild / "
                   "FindFirstAncestor with a literal, a .Name == comparison, or a literal name table). Lookups whose "
                   "receiver resolves under ReplicatedStorage, ReplicatedFirst or a server container are left out, "
                   "because no UI owner creates instances there.",
        "limits": [
            "Dotted access (gui.DesignRoot.ModalLayer) is not a lookup this tool can tell from a property read; it is not listed.",
            "A definer found through a Name field in a table literal may be data rather than an instance; check `via` and `callee`.",
            "`names_looked_up_only_by_their_definer` are found and adopted or destroyed by the script that creates them "
            "(typically on start); no other script names them as a literal.",
            "Names in `lookups_without_static_definer` are looked up by an owner but no script assigns them as a literal: "
            "they are Studio-authored, engine-made (TouchGui), retired, or built at run time (see possible_pattern_definers).",
        ],
        "names": reserved,
        "names_looked_up_only_by_their_definer": self_only,
        "lookups_without_static_definer": undefined,
        "name_patterns_built_at_run_time": patterns,
    }

    # ---- player attributes -----------------------------------------------------
    pattrs = {}
    for p, c in all_contracts.items():
        for acc, key in (("reads", "readers"), ("writes", "writers"), ("listens", "listeners")):
            for a in c["attributes"][acc]:
                kind = a.get("receiver_kind", "")
                if kind.rstrip("?") not in ("player", "playerGui", "character"):
                    continue
                if not isinstance(a.get("name"), str):
                    continue
                rec = {"script": p, "line": a["line"], "receiver": a.get("receiver"), "side": side(p),
                       "receiver_certain": not kind.endswith("?")}
                if "value" in a:
                    rec["value"] = a["value"]
                if a.get("via"):
                    rec["via"] = a["via"]
                d = pattrs.setdefault(kind.rstrip("?") + ":" + a["name"], {"attribute": a["name"], "on": kind.rstrip("?"),
                                                                             "writers": [], "readers": [], "listeners": []})
                d[key].append(rec)
    for d in pattrs.values():
        d["writer_scripts"] = sorted({r["script"] for r in d["writers"]})
        d["reader_scripts"] = sorted({r["script"] for r in d["readers"]} | {r["script"] for r in d["listeners"]})
    pattr_doc = {
        "generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
        "meaning": "Attributes on the player, PlayerGui or character, with every writer and reader in all 221 scripts. "
                   "`receiver_certain` is true when the receiver resolves to Players.LocalPlayer (or below); false when "
                   "the tool only matched the variable name (player, owner, character ...). reader_scripts joins reads and "
                   "changed-signal listeners.",
        "attributes": dict(sorted(pattrs.items())),
    }

    # ---- screenguis ------------------------------------------------------------
    sg = []
    for p, c in all_contracts.items():
        for g in c["screenguis"]["created"]:
            nm = g.get("Name")
            rec = dict(g, script=p)
            if isinstance(nm, str):
                rec["looked_up_by"] = [{"script": x["script"], "line": x["line"], "method": x["method"]}
                                       for x in consumers.get(nm, []) if x["script"] != p]
            sg.append(rec)
    foreign_enabled = []
    for p, c in all_contracts.items():
        for w in c["screenguis"]["enabled_writes"]:
            if w["screengui_like"] != "no":
                foreign_enabled.append(dict(w, script=p))
    sg_doc = {
        "generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
        "meaning": "Every ScreenGui (and BillboardGui / SurfaceGui) a script creates, with the properties set on it in "
                   "source, and every `.Enabled =` write whose receiver is, or may be, a ScreenGui. Values that are not "
                   "literals are given as {\"expr\": source text}.",
        "screenguis": sorted(sg, key=lambda r: (r["script"], r["line"] or 0)),
        "enabled_writes": sorted(foreign_enabled, key=lambda r: (r["script"], r["line"])),
    }

    # ---- remotes ---------------------------------------------------------------
    remotes = {}
    for p, c in all_contracts.items():
        for call in c["remotes"]["calls"]:
            rp = call.get("remote") or ("<unresolved> " + str(call.get("remote_expr") or call.get("receiver")))
            r = remotes.setdefault(rp, {"remote": rp, "name": rp.rsplit(".", 1)[-1], "actions": {}, "listeners": []})
            act = call.get("action") if isinstance(call.get("action"), str) else (
                "<no action argument>" if "action" not in call and "first_arg_expr" not in call
                else "<first argument is not an action literal: %s>" % (call.get("first_arg_expr") or call.get("action_expr")))
            a = r["actions"].setdefault(act, {"callers": [], "payload_keys": []})
            a["callers"].append({"script": p, "line": call["line"], "method": call["method"], "via": call.get("via"),
                                 "payload_keys": call.get("payload_keys"), "payload_expr": call.get("payload_expr"),
                                 "payload_literals": call.get("payload_literals"),
                                 "first_arg_expr": call.get("first_arg_expr")})
            for k in call.get("payload_keys") or []:
                if k not in a["payload_keys"]:
                    a["payload_keys"].append(k)
        for l in c["remotes"]["listens"]:
            rp = l.get("remote") or ("<unresolved> " + str(l.get("remote_expr") or l.get("receiver")))
            r = remotes.setdefault(rp, {"remote": rp, "name": rp.rsplit(".", 1)[-1], "actions": {}, "listeners": []})
            r["listeners"].append({"script": p, "line": l["line"], "handler": l.get("handler"),
                                   "payload_fields_read": l.get("payload_fields_read"),
                                   "literal_comparisons": l.get("literal_comparisons")})
    # server side Net specs
    specs = []
    for s in scripts:
        T, V = s.T, s.V
        for i in range(s.n - 4):
            if T[i] == "name" and V[i] == "Net" and V[i + 1] == "." and V[i + 2] in ("invoke", "event") and V[i + 3] == "(" and V[i + 4] == "{" \
                    and not (i and V[i - 1] == "function"):
                spec = s.table_to_py(i + 4)
                if isinstance(spec, dict):
                    acts = spec.get("actions")
                    specs.append({"script": s.path, "line": s.L[i], "kind": "Net." + V[i + 2], "name": spec.get("name"),
                                  "actions": sorted(acts) if isinstance(acts, dict) and "expr" not in acts else None,
                                  "actions_expr": acts.get("expr") if isinstance(acts, dict) and "expr" in acts else None,
                                  "withAction": spec.get("withAction")})
    for r in remotes.values():
        r["server_specs"] = [] if r["remote"].startswith("<") else [sp for sp in specs if sp["name"] == r["name"]]
        declared = set()
        for sp in r["server_specs"]:
            declared |= set(sp["actions"] or [])
        if declared:
            r["client_actions_not_declared_by_server"] = sorted(a for a in r["actions"] if not a.startswith("<") and a not in declared)
            r["server_actions_without_client_caller"] = sorted(declared - set(r["actions"]))
    remotes_doc = {
        "generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
        "meaning": "Per remote: every action name a client passes (first argument of InvokeServer / FireServer, also "
                   "through local wrapper functions), the callers, and the payload keys where the payload is a table "
                   "literal. `server_specs` are Net.invoke / Net.event declarations whose name equals the remote's "
                   "instance name (matched by name only).",
        "remotes": dict(sorted(remotes.items())),
        "server_specs_unmatched": [sp for sp in specs if not any(sp in r["server_specs"] for r in remotes.values())],
    }

    # ---- onboarding ------------------------------------------------------------
    onboard = [s for s in scripts if s.name == "OnboardingClient"]
    onboarding_doc = {"generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
                      "rule": "The onboarding client is the script named OnboardingClient. Its tables copy, pages, "
                              "resolvers, pageSignals, placement, actionSteps and pageOrder are read by name. A target is "
                              "a call inside a resolver or page signal that passes a string literal to a local helper; "
                              "`match_on` is what that helper (and the helpers it calls) compares: instance Name, Text, "
                              "a child of PlayerGui, or attributes."}
    if onboard:
        s = onboard[0]
        c = all_contracts[s.path]
        t = onboarding_targets(s)
        used_names, used_text, used_attrs = {}, {}, {}
        for l in c["names"]["looked_up"]:
            rp = l.get("receiver_path") or ""
            if l.get("root") == "Players" and not rp.startswith("Players.LocalPlayer.PlayerGui"):
                continue
            if isinstance(l.get("name"), str) and l.get("root") not in STATIC_ROOTS:
                used_names.setdefault(l["name"], []).append({"line": l["line"], "method": l["method"], "via": l.get("via"),
                                                             "scope": "world" if l.get("root") == "Workspace" else "gui",
                                                             "in_function": l.get("in_function"),
                                                             "receiver_isa": l.get("receiver_isa"),
                                                             "receiver_property_writes": l.get("receiver_property_writes")})
        for l in c["names"]["text_compared"]:
            if isinstance(l.get("text"), str):
                used_text.setdefault(l["text"], []).append({"line": l["line"], "method": l["method"], "via": l.get("via"),
                                                            "transform": l.get("transform"), "in_function": l.get("in_function")})
        for acc in ("reads", "listens"):
            for a in c["attributes"][acc]:
                if isinstance(a.get("name"), str) and a.get("receiver_kind") not in ("config", "config?"):
                    used_attrs.setdefault(a["name"], []).append({"line": a["line"], "access": acc, "receiver": a.get("receiver"),
                                                                 "receiver_kind": a.get("receiver_kind"),
                                                                 "in_function": a.get("in_function")})
        locks = [l for l in c["names"]["looked_up"] if l["method"] == "NameCompare" and l.get("receiver_property_writes")]
        onboarding_doc.update(t)
        onboarding_doc["names_used"] = dict(sorted(used_names.items()))
        onboarding_doc["texts_used"] = dict(sorted(used_text.items()))
        onboarding_doc["attributes_used"] = dict(sorted(used_attrs.items()))
        onboarding_doc["name_locks"] = [{"name": l["name"], "line": l["line"], "in_function": l.get("in_function"),
                                         "receiver_isa": l.get("receiver_isa"),
                                         "properties_written": l.get("receiver_property_writes")} for l in locks]

    # ---- totals & index ---------------------------------------------------------
    rows = []
    for p in sorted(contracts, key=lambda x: by_path[x].name.lower()):
        rows.append((by_path[p].name, p, counts(contracts[p]), contracts[p]["contract_file"]))
    unresolved_total = sum(r[2]["unresolved"] for r in rows)
    preferred_input = sorted(s.path for s in scripts if "PreferredInput" in s.V)
    summary = {
        "scripts_scanned": len(scripts), "owners": len(contracts),
        "clientbase_entries": len(entries), "clientbase_entries_line": entries_line,
        "reserved_names": len(reserved), "lookups_without_static_definer": len(undefined),
        "names_looked_up_only_by_definer": len(self_only),
        "enabled_writes_unclassified": len([w for w in foreign_enabled if w["screengui_like"] == "unknown"]),
        "player_attributes": len(pattrs), "screenguis": len(sg), "remotes": len(remotes),
        "remote_actions": sum(len(r["actions"]) for r in remotes.values()),
        "onboarding_pages": len(onboarding_doc.get("pages", {})), "onboarding_cards": len(onboarding_doc.get("cards", {})),
        "unresolved": unresolved_total,
        "preferred_input_scripts": preferred_input,
    }
    result = {
        "summary": summary, "entries": entries, "owners": owners, "owner_rule": owner_rule,
        "contracts": contracts, "all_contracts": all_contracts, "required_by": required_by,
        "reserved": reserved_doc, "player_attributes": pattr_doc, "screenguis": sg_doc, "remotes": remotes_doc,
        "onboarding": onboarding_doc, "rows": rows,
    }
    if write:
        OUT.mkdir(parents=True, exist_ok=True)
        keep = {"_reserved_names.json", "_onboarding_targets.json", "_player_attributes.json", "_screenguis.json",
                "_remotes.json", "_clientbase_entries.json", "INDEX.md"} | {c["contract_file"] for c in contracts.values()}
        for old in OUT.glob("*.json"):
            if old.name not in keep:
                old.unlink()

        def dump(name, obj):
            (OUT / name).write_text(json.dumps(obj, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")

        for p, c in contracts.items():
            dump(c["contract_file"], c)
        dump("_reserved_names.json", reserved_doc)
        dump("_onboarding_targets.json", onboarding_doc)
        dump("_player_attributes.json", pattr_doc)
        dump("_screenguis.json", sg_doc)
        dump("_remotes.json", remotes_doc)
        dump("_clientbase_entries.json", {"generated_by": "scripts/ui_restyle/tools/extract_contracts.py",
                                          "source": cb.path, "table_line": entries_line, "entries": entries,
                                          "required_by": {k: sorted(v) for k, v in sorted(required_by.items())}})
        (OUT / "INDEX.md").write_text(index_md(result), encoding="utf-8", newline="\n")
    return result


def index_md(res):
    s = res["summary"]
    out = []
    w = out.append
    w("# Classic UI contracts (generated)")
    w("")
    w("Generated by `scripts/ui_restyle/tools/extract_contracts.py` from `scripts/ui_restyle/classic/sources` "
      "(%d scripts, index `classic/manifest_raw.json`). Do not edit by hand; run the tool again." % s["scripts_scanned"])
    w("The tool reads source text only. It has not run the game, so nothing here is gameplay confirmation.")
    w("")
    w("## Totals")
    w("")
    w("| Table | File | Count |")
    w("|---|---|---|")
    w("| Owner contracts | `<ScriptName>.json` | %d |" % s["owners"])
    w("| ClientBase entries | `_clientbase_entries.json` | %d |" % s["clientbase_entries"])
    w("| Reserved names (defined by one script, looked up by another) | `_reserved_names.json` | %d |" % s["reserved_names"])
    w("| Names an owner looks up that no script assigns as a literal | `_reserved_names.json` | %d |" % s["lookups_without_static_definer"])
    w("| Names looked up only by the script that defines them | `_reserved_names.json` | %d |" % s["names_looked_up_only_by_definer"])
    w("| Player, PlayerGui and character attributes | `_player_attributes.json` | %d |" % s["player_attributes"])
    w("| ScreenGuis created | `_screenguis.json` | %d |" % s["screenguis"])
    w("| Remotes / remote actions | `_remotes.json` | %d / %d |" % (s["remotes"], s["remote_actions"]))
    w("| Onboarding pages / cards | `_onboarding_targets.json` | %d / %d |" % (s["onboarding_pages"], s["onboarding_cards"]))
    w("| Items the tool could not resolve | listed below | %d |" % s["unresolved"])
    w("")
    w("## Which scripts get a contract")
    w("")
    for line in res["owner_rule"]:
        w("- " + line)
    w("")
    w("## Owners")
    w("")
    w("Req = requires. RC/RL = remote calls / listens. BF/BC/BI = bindable fires / connects / invokes and handlers. "
      "AR/AW/AL = attribute reads / writes / changed-signal listens. SG = ScreenGuis created. EN = Enabled writes on a "
      "ScreenGui. NA = names assigned. LU = name lookups. TX = text compares. RS = render steps and RunService connects. "
      "CA = ContextActionService binds. UIS = UserInputService connects. AU = audio bridge calls and UIAudio attributes. "
      "CFG = config attribute reads and config child lookups made through a helper. ? = unresolved.")
    w("")
    w("| Owner | Req | RC | RL | BF | BC | BI | AR | AW | AL | SG | EN | NA | LU | TX | RS | CA | UIS | AU | CFG | ? |")
    w("|---|" + "---|" * 20)
    for name, path, c, fname in res["rows"]:
        w("| [%s](%s) | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % (
            name, fname.replace(" ", "%20"), c["requires"], c["remote_calls"], c["remote_listens"], c["bindable_fires"], c["bindable_connects"],
            c["bindable_invokes"], c["attr_reads"], c["attr_writes"], c["attr_listens"], c["screenguis"],
            c["enabled_writes"], c["names_assigned"], c["lookups"], c["text_compares"], c["run_bindings"],
            c["context_actions"], c["uis_connects"], c["audio"], c["config_reads"], c["unresolved"]))
    w("")
    w("## What the tool cannot see")
    w("")
    w("- Names, actions and attribute names built at run time. Each one is listed below; none is guessed. Where the "
      "source is a literal prefix plus a run-time part, the prefix is reported as a pattern (`Tier*`).")
    w("- Dotted child access (`gui.DesignRoot.ModalLayer`). It reads like a property, so it is not counted as a lookup.")
    w("- A variable is resolved to the nearest earlier assignment in scope. A variable reassigned on another branch "
      "can resolve to the wrong instance; `receiver` keeps the source text so a reader can check.")
    w("- Wrapper functions are followed when the name is a parameter (for example `call(action, payload)` around "
      "`InvokeServer`) or a `...` list. Other indirection (names stored in tables and read later) is not followed.")
    w("- `receiver_kind` ending in `?` was matched by variable name only (`player`, `vehicle`, `config`).")
    w("- Instances authored in Studio are not in the script dump, so a looked-up name with no definer here may still exist in the place.")
    w("- Payload keys are listed only where the payload is a table literal at the call; a payload built earlier is "
      "given as source text in `payload_expr`.")
    w("")
    w("## Enabled writes the tool could not classify")
    w("")
    w("`.Enabled =` on a receiver that is not known to be a ScreenGui (it may be a light, a prompt, a beam or a GUI). "
      "Owners only. Check each one.")
    w("")
    for g in res["screenguis"]["enabled_writes"]:
        if g["screengui_like"] == "unknown" and g["script"] in res["contracts"]:
            w("- `%s:%d` `%s.Enabled = %s`" % (res["contracts"][g["script"]]["source_file"].split("/")[-1], g["line"], g["receiver"],
                                             g["value"]["expr"] if isinstance(g["value"], dict) else json.dumps(g["value"])))
    w("")
    w("## Unresolved items")
    w("")
    w("One line per item: file:line, category, detail. A human has to finish these.")
    w("")
    for name, path, c, fname in res["rows"]:
        un = res["contracts"][path]["unresolved"]
        if not un:
            continue
        w("### %s (%d)" % (name, len(un)))
        w("")
        src = res["contracts"][path]["source_file"]
        for u in un:
            w("- `%s:%d` %s%s: %s" % (src.split("/")[-1], u["line"], u["category"],
                                       ("." + u["field"]) if u.get("field") else "", u["detail"].replace("|", "\\|")))
        w("")
    return "\n".join(out) + "\n"


def main(argv):
    res = run(write="--check" not in argv)
    print(json.dumps(res["summary"], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
