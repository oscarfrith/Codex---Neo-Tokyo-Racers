#!/usr/bin/env python3
"""Static checker for calls into the Pulse UI kit (phase2).

Reads the kit modules (UIPulse.Kit.*) and works out, from the kit source alone, what each exported
function accepts: the prop keys of a component and of its Set, enumerated string values, value types,
required keys, the methods and fields of the handle it returns. It then reads every screen source of a
family (and the kit's own fixtures) and reports calls that would fail when they run.

It is a tokeniser plus a small summary analysis, not a Luau interpreter (the tokeniser follows
scripts/ui_restyle/tools/extract_contracts.py). ERROR is reserved for what the two source texts make
certain; anything that depends on a value built at run time is a NOTE with its reason.

Usage:  py -3 scripts/ui_restyle/phase2/tools/check_kit_calls.py [--unit <family>]... [--json]
                [--kit working|assembled] [--write] [--model]
        --unit   race_menu | free_roam | world_map | race_session | race_entry | garage | shell | kit_fixtures
                 (repeatable; default: all of them)
        --json   print the findings as JSON instead of text
        --kit    working (default): kit/k*/after where a module has a working copy, else install/00_kit/after;
                 assembled: install/00_kit/after only
        --write  write results/kit_call_report.md and .json (always the full run, both kit copies compared)
        --model  print what was extracted from the kit and stop
Exit code 1 when there is at least one ERROR, 2 for a bad argument. Stdlib only. No Studio access, no network.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PHASE2 = HERE.parent
UI_RESTYLE = PHASE2.parent
REPO = UI_RESTYLE.parent.parent
FAMILIES = ["race_menu", "free_roam", "world_map", "race_session", "race_entry", "garage", "shell"]
FIXTURES_UNIT = "kit_fixtures"
KIT_RE = re.compile(r"UIPulse\.Kit\.([A-Za-z0-9_]+)\.lua$")
FIXTURE_RE = re.compile(r"UIPulse\.Dev\.Fixtures\.[A-Za-z0-9_]+\.lua$")

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
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
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
ESC_RE = re.compile(r"\\(z\s*|\n|x[0-9a-fA-F]{2}|\d{1,3}|u\{[0-9a-fA-F]+\}|.)", re.S)


def _unescape(body):
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


def tokenize(src):
    """Parallel lists (types, values, lines, starts, ends); comments dropped.
    types: name, kw, str, istr (backtick string), num, sym."""
    T, V, L, S, E = [], [], [], [], []
    pos, line, n = 0, 1, len(src)
    while pos < n:
        m = TOKEN_RE.match(src, pos)
        if not m:
            pos += 1
            continue
        kind = m.lastgroup
        end = m.end()
        if kind in ("ws", "com"):
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


EXPR_SYMS = {"=", "(", ",", "{", "[", "..", "+", "-", "*", "/", "//", "%", "^", "==", "~=", "<", ">", "<=",
             ">=", "+=", "-=", "*=", "/=", "..=", "//=", "%=", "^=", "#", "::", ":"}
EXPR_KWS = {"return", "and", "or", "not"}
OPEN = {"(": ")", "{": "}", "[": "]"}
CLOSE = {")", "}", "]"}


class Fn:
    __slots__ = ("fid", "tok", "close", "parent", "params", "vararg", "name", "localname", "path", "colon",
                 "field", "target", "pclose")

    def __init__(self):
        self.params = []
        self.vararg = False
        self.name = "?"
        self.localname = None   # local function N / local N = function
        self.path = None        # function A.B.C -> ["A","B","C"]
        self.colon = False
        self.field = None       # table constructor key, or last name of an assignment target
        self.target = None      # "A.B" for A.B = function
        self.parent = None


class Lua:
    """One tokenised source with its block, bracket, function and declaration structure."""

    def __init__(self, src, label=""):
        self.src = src
        self.label = label
        self.T, self.V, self.L, self.S, self.E = tokenize(src)
        self.n = len(self.T)
        self._blocks()
        self._brackets()
        self._functions()
        self._decls()
        self._assigns()

    # -- structure ---------------------------------------------------------------------------
    def kw(self, i, v):
        return 0 <= i < self.n and self.T[i] == "kw" and self.V[i] == v

    def sym(self, i, v):
        return 0 <= i < self.n and self.T[i] == "sym" and self.V[i] == v

    def isname(self, i, v=None):
        return 0 <= i < self.n and self.T[i] == "name" and (v is None or self.V[i] == v)

    def _blocks(self):
        T, V, n = self.T, self.V, self.n
        self.close = {}            # opener token -> its end/until token
        self.is_ifexpr = [False] * n
        self.exprkw = [False] * n  # then/elseif/else of an if-expression
        self.ifs = {}              # statement if token -> {"clauses": [(kw, then)], "else": idx|None, "end": idx}
        self.block_of = [0] * n    # innermost block opener token (-1 = file)
        stack = []
        cur = -1
        for i in range(n):
            self.block_of[i] = cur
            if T[i] != "kw":
                continue
            v = V[i]
            if v == "function" or v == "do" or v == "repeat":
                stack.append([v, i]); cur = i
            elif v == "if":
                p = i - 1
                expr = p >= 0 and ((T[p] == "sym" and V[p] in EXPR_SYMS) or (T[p] == "kw" and V[p] in EXPR_KWS)
                                   or self.exprkw[p])
                if expr:
                    self.is_ifexpr[i] = True
                    stack.append(["ifexpr", i])
                else:
                    stack.append(["if", i]); cur = i
                    self.ifs[i] = {"clauses": [[i, None]], "else": None, "end": None}
            elif v in ("then", "elseif", "else"):
                top = None
                for entry in reversed(stack):
                    if entry[0] in ("if", "ifexpr"):
                        top = entry
                    break
                if top is None:
                    continue
                if top[0] == "ifexpr":
                    self.exprkw[i] = True
                    if v == "else":
                        stack.pop()
                else:
                    rec = self.ifs[top[1]]
                    if v == "then":
                        rec["clauses"][-1][1] = i
                    elif v == "elseif":
                        rec["clauses"].append([i, None])
                    else:
                        rec["else"] = i
            elif v == "end" or v == "until":
                while stack and stack[-1][0] == "ifexpr":
                    stack.pop()
                if stack:
                    kind, start = stack.pop()
                    self.close[start] = i
                    if kind == "if":
                        self.ifs[start]["end"] = i
                    self.block_of[i] = start
                cur = -1
                for entry in reversed(stack):
                    if entry[0] != "ifexpr":
                        cur = entry[1]
                        break
        for entry in stack:
            self.close.setdefault(entry[1], n - 1)

    def _brackets(self):
        T, V, n = self.T, self.V, self.n
        self.mate = {}
        self.encl = [None] * n  # innermost enclosing bracket or function: (kind, index)
        stack = []
        fn_close = {c: o for o, c in self.close.items() if V[o] == "function"}
        for i in range(n):
            if i in fn_close and stack and stack[-1][0] == "F":
                stack.pop()
            self.encl[i] = stack[-1] if stack else None
            if T[i] == "kw" and V[i] == "function":
                stack.append(("F", i))
            elif T[i] == "sym":
                if V[i] in OPEN:
                    stack.append((V[i], i))
                elif V[i] in CLOSE:
                    while stack and stack[-1][0] != "F" and OPEN[stack[-1][0]] != V[i]:
                        stack.pop()
                    if stack and stack[-1][0] != "F":
                        o = stack.pop()[1]
                        self.mate[o] = i
                        self.mate[i] = o
                        self.encl[i] = stack[-1] if stack else None

    def _functions(self):
        T, V, n = self.T, self.V, self.n
        root = Fn()
        root.fid, root.tok, root.close, root.name, root.pclose = 0, -1, n, "<file>", -1
        self.fns = [root]
        self.fn_by_tok = {}
        self.fn_at = [0] * n
        stack = [0]
        ends = {}
        for i in range(n):
            while len(stack) > 1 and i > self.fns[stack[-1]].close:
                stack.pop()
            if T[i] == "kw" and V[i] == "function":
                f = Fn()
                f.fid = len(self.fns)
                f.tok = i
                f.close = self.close.get(i, n - 1)
                f.parent = stack[-1]
                j = i + 1
                if self.isname(j):
                    path = [V[j]]
                    j += 1
                    while j + 1 < n and T[j] == "sym" and V[j] in (".", ":") and self.isname(j + 1):
                        if V[j] == ":":
                            f.colon = True
                        path.append(V[j + 1])
                        j += 2
                    if self.kw(i - 1, "local"):
                        f.localname = path[0]
                    else:
                        f.path = path
                        if len(path) == 1:
                            f.localname = path[0]  # function name() at file level behaves like a global
                    f.name = ".".join(path)
                    f.field = path[-1]
                else:
                    # anonymous: look back for `X =`, `A.B =`, `Key =`
                    p = i - 1
                    if self.sym(p, "="):
                        q = p - 1
                        names = []
                        while q >= 0:
                            if self.isname(q):
                                names.append(V[q])
                                if self.sym(q - 1, "."):
                                    q -= 2
                                    continue
                            break
                        names.reverse()
                        if names:
                            f.name = ".".join(names)
                            f.field = names[-1]
                            if len(names) == 1:
                                enc = self.encl[p]
                                if not (enc and enc[0] == "{"):
                                    f.localname = names[0]
                            else:
                                f.target = f.name
                while j < n and not self.sym(j, "("):
                    j += 1
                pc = self.mate.get(j, j)
                f.pclose = pc
                for (a, b) in self.split_commas(j + 1, pc):
                    if self.sym(a, "..."):
                        f.vararg = True
                    elif self.isname(a):
                        f.params.append(V[a])
                self.fns.append(f)
                self.fn_by_tok[i] = f.fid
                stack.append(f.fid)
            self.fn_at[i] = stack[-1]

    def split_commas(self, a, b):
        """Top-level comma split of the token range [a, b)."""
        out = []
        i = start = a
        angle = 0
        while i < b:
            if self.T[i] == "sym":
                v = self.V[i]
                if v in OPEN and i in self.mate:
                    i = self.mate[i] + 1
                    continue
                if v == "<":
                    angle += 1
                elif v == ">" and angle:
                    angle -= 1
                elif v == "," and angle == 0:
                    out.append((start, i))
                    start = i + 1
            elif self.kw(i, "function") and i in self.close:
                i = self.close[i] + 1
                continue
            i += 1
        if start < b:
            out.append((start, b))
        return out

    def ancestors(self, fid):
        out = []
        while fid is not None:
            out.append(fid)
            fid = self.fns[fid].parent
        return out

    def is_inside(self, fid, anc):
        return anc in self.ancestors(fid)

    def own_range(self, fid):
        f = self.fns[fid]
        return (0, self.n) if fid == 0 else (f.pclose + 1, f.close)

    def own_tokens(self, fid):
        a, b = self.own_range(fid)
        i = a
        while i < b:
            if self.T[i] == "kw" and self.V[i] == "function" and i in self.fn_by_tok and self.fn_by_tok[i] != fid:
                i = self.close.get(i, i) + 1
                continue
            yield i
            i += 1

    def children(self, fid):
        return [f.fid for f in self.fns if f.parent == fid and f.fid != 0]

    # -- expressions -------------------------------------------------------------------------
    def expr_end(self, i, lim):
        T, V = self.T, self.V
        operand = False
        while i < lim:
            t, v = T[i], V[i]
            if t == "kw":
                if v == "function":
                    if operand:
                        break
                    i = self.close.get(i, lim - 1) + 1
                    operand = True
                elif v == "if":
                    if self.is_ifexpr[i] and not operand:
                        i += 1
                    else:
                        break
                elif v in ("then", "else", "elseif"):
                    if self.exprkw[i]:
                        i += 1
                        operand = False
                    else:
                        break
                elif v in ("and", "or", "not"):
                    i += 1
                    operand = False
                elif v in ("true", "false", "nil"):
                    if operand:
                        break
                    operand = True
                    i += 1
                else:
                    break
            elif t == "sym":
                if v in OPEN:
                    m = self.mate.get(i)
                    if m is None:
                        break
                    if v == "[" and not operand:
                        break
                    i = m + 1
                    operand = True
                elif v in CLOSE or v in (",", ";", "="):
                    break
                elif v == "...":
                    if operand:
                        break
                    operand = True
                    i += 1
                elif v in ("+=", "-=", "*=", "/=", "..=", "//=", "%=", "^="):
                    break
                else:
                    i += 1
                    operand = False
            else:
                if operand:
                    if t == "str" and i > 0 and T[i - 1] == "name":
                        i += 1  # f"..." call sugar
                        continue
                    break
                operand = True
                i += 1
        return i

    def expr_list(self, i, lim):
        out = []
        while i < lim:
            e = self.expr_end(i, lim)
            if e == i:
                break
            out.append((i, e))
            if self.sym(e, ","):
                i = e + 1
            else:
                break
        return out

    def strip(self, a, b):
        while b - a >= 2 and self.sym(a, "(") and self.mate.get(a) == b - 1:
            a, b = a + 1, b - 1
        return a, b

    def top_split(self, a, b, word):
        """Split [a,b) on a top-level keyword (and/or); None when the keyword is not there."""
        parts = []
        i = start = a
        while i < b:
            if self.T[i] == "sym" and self.V[i] in OPEN and i in self.mate:
                i = self.mate[i] + 1
                continue
            if self.kw(i, "function") and i in self.close:
                i = self.close[i] + 1
                continue
            if self.kw(i, word):
                parts.append((start, i))
                start = i + 1
            i += 1
        if not parts:
            return None
        parts.append((start, b))
        return parts

    def has_top_kw(self, a, b, words):
        i = a
        while i < b:
            if self.T[i] == "sym" and self.V[i] in OPEN and i in self.mate:
                i = self.mate[i] + 1
                continue
            if self.kw(i, "function") and i in self.close:
                i = self.close[i] + 1
                continue
            if self.T[i] == "kw" and self.V[i] in words:
                return True
            i += 1
        return False

    def parse_table(self, o):
        """Entries of the table constructor opening at o: (kind, key, key_index, vstart, vend).
        kind: named | pos | dyn."""
        c = self.mate.get(o)
        out = []
        if c is None:
            return out
        i = o + 1
        while i < c:
            kind, key, ki, vs = "pos", None, i, i
            if self.isname(i) and self.sym(i + 1, "="):
                kind, key, vs = "named", self.V[i], i + 2
            elif self.sym(i, "[") and i in self.mate and self.sym(self.mate[i] + 1, "="):
                m = self.mate[i]
                if m == i + 2 and self.T[i + 1] == "str":
                    kind, key = "named", self.V[i + 1]
                else:
                    kind = "dyn"
                vs = m + 2
            ve = self.expr_end(vs, c)
            if ve <= vs:
                ve = vs + 1
            out.append((kind, key, ki, vs, ve))
            i = ve
            while i < c and not (self.sym(i, ",") or self.sym(i, ";")):
                i += 1  # resynchronise after anything not understood
            i += 1
        return out

    def text(self, a, b, limit=160):
        if a >= b or a >= self.n:
            return ""
        s = self.src[self.S[a]:self.E[min(b, self.n) - 1]]
        s = " ".join(s.split())
        return s if len(s) <= limit else s[:limit - 3] + "..."

    def chain_start(self, i):
        """Given a NAME token, walk back over `.NAME` links to the first name of its chain."""
        while i >= 2 and self.sym(i - 1, ".") and self.isname(i - 2):
            i -= 2
        return i

    def parse_chain(self, i, lim=None):
        """Steps of the primary expression starting at NAME token i. Returns (steps, end)."""
        lim = self.n if lim is None else lim
        steps = [("name", self.V[i], i)]
        j = i + 1
        while j < lim:
            if self.sym(j, ".") and self.isname(j + 1):
                steps.append(("field", self.V[j + 1], j + 1))
                j += 2
            elif self.sym(j, ":") and self.isname(j + 1) and (self.sym(j + 2, "(") or self.sym(j + 2, "{")
                                                             or (j + 2 < self.n and self.T[j + 2] == "str")):
                steps.append(("method", self.V[j + 1], j + 1))
                j += 2
            elif self.sym(j, "(") and j in self.mate:
                m = self.mate[j]
                steps.append(("call", self.expr_list(j + 1, m), j, m))
                j = m + 1
            elif self.sym(j, "{") and j in self.mate and steps[-1][0] in ("name", "field", "method"):
                m = self.mate[j]
                steps.append(("call", [(j, m + 1)], j, m))
                j = m + 1
            elif self.sym(j, "[") and j in self.mate:
                m = self.mate[j]
                steps.append(("index", (j + 1, m), j))
                j = m + 1
            else:
                break
        return steps, j

    # -- declarations ------------------------------------------------------------------------
    def _scope_end(self, i):
        b = self.block_of[i]
        return self.n if b < 0 else self.close.get(b, self.n)

    def _decls(self):
        """self.decls[name] = list of dicts: pos, fid, kind (local|localfn|for), scope (a, b), ..."""
        T, V, n = self.T, self.V, self.n
        self.decls = {}
        self.local_stmts = []  # (local token, [names], [expr ranges])
        i = 0
        while i < n:
            if T[i] == "kw" and V[i] == "local":
                if self.kw(i + 1, "function"):
                    fid = self.fn_by_tok.get(i + 1)
                    if fid and self.isname(i + 2):
                        self.decls.setdefault(V[i + 2], []).append(
                            {"pos": i, "fid": self.fn_at[i], "kind": "localfn", "fn": fid,
                             "scope": (i, self._scope_end(i))})
                    i += 2
                    continue
                names = []
                j = i + 1
                while self.isname(j):
                    names.append(V[j])
                    j += 1
                    if self.sym(j, ":"):  # type annotation
                        j += 1
                        while j < n:
                            if T[j] == "sym" and V[j] in OPEN and j in self.mate:
                                j = self.mate[j] + 1
                            elif (T[j] == "name" and (self.sym(j - 1, ":") or self.sym(j - 1, ".") or self.sym(j - 1, "|")
                                                       or self.sym(j - 1, "&") or self.sym(j - 1, "->"))) \
                                    or (T[j] == "sym" and V[j] in ("?", ".", "|", "&", "->", "<", ">")) \
                                    or (T[j] in ("str",) and self.sym(j - 1, "|")) or self.kw(j, "nil") \
                                    or (T[j] == "name" and self.sym(j - 1, "<")) or (T[j] == "name" and self.sym(j - 1, ",") and False):
                                j += 1
                            else:
                                break
                    if self.sym(j, ","):
                        j += 1
                    else:
                        break
                exprs = []
                if self.sym(j, "="):
                    exprs = self.expr_list(j + 1, n)
                self.local_stmts.append((i, names, exprs))
                after = exprs[-1][1] if exprs else j
                for k, name in enumerate(names):
                    self.decls.setdefault(name, []).append(
                        {"pos": after - 1, "at": i, "fid": self.fn_at[i], "kind": "local",
                         "expr": exprs[k] if k < len(exprs) else None, "single": len(exprs) == len(names) or k < len(exprs) - 0,
                         "scope": (after - 1, self._scope_end(i))})
                i = max(j, i + 1)
                continue
            if T[i] == "kw" and V[i] == "for":
                j = i + 1
                names = []
                while self.isname(j):
                    names.append(V[j])
                    j += 1
                    if self.sym(j, ":"):
                        j += 1
                        while j < n and not (self.sym(j, ",") or self.kw(j, "in") or self.sym(j, "=")):
                            j += 1
                    if self.sym(j, ","):
                        j += 1
                    else:
                        break
                do = j
                while do < n and not self.kw(do, "do"):
                    if T[do] == "sym" and V[do] in OPEN and do in self.mate:
                        do = self.mate[do]
                    elif self.kw(do, "function") and do in self.close:
                        do = self.close[do]
                    do += 1
                if self.kw(j, "in") and do < n:
                    a, b = j + 1, do
                    how = "bare"
                    if self.isname(a) and V[a] in ("ipairs", "pairs") and self.sym(a + 1, "(") and self.mate.get(a + 1) == b - 1:
                        how = V[a]
                        a, b = a + 2, b - 1
                    for k, name in enumerate(names):
                        self.decls.setdefault(name, []).append(
                            {"pos": do, "fid": self.fn_at[i], "kind": "for", "how": how, "index": k,
                             "count": len(names), "expr": (a, b), "scope": (do, self.close.get(do, n))})
                i = j
                continue
            i += 1

    def find_decl(self, name, pos, fid):
        """Nearest visible declaration of a local name at token pos, searching fid then its ancestors.
        Returns (decl, owner_fid) or (("param", index), owner_fid) or (None, None)."""
        cands = self.decls.get(name, ())
        for f in self.ancestors(fid):
            best = None
            for d in cands:
                if d["fid"] == f and d["scope"][0] < pos <= d["scope"][1]:
                    if best is None or d["pos"] > best["pos"]:
                        best = d
            if best is not None:
                return best, f
            fn = self.fns[f]
            if name in fn.params:
                return ("param", fn.params.index(name)), f
        return None, None

    def _assigns(self):
        """Statement assignments: self.assigns[target] = [(pos, fid, (a, b))]; self.dyn_assign[base] = True."""
        T, V, n = self.T, self.V, self.n
        self.assigns = {}
        self.dyn_assign = {}
        for i in range(n):
            if not (T[i] == "sym" and V[i] == "="):
                continue
            enc = self.encl[i]
            if enc and enc[0] != "F":
                continue
            q = i - 1
            ok = True
            while True:
                # one operand, read backwards: NAME | ...[x] | ...(x)
                if q >= 0 and T[q] == "name":
                    q -= 1
                elif q >= 0 and T[q] == "sym" and V[q] in ("]", ")") and q in self.mate:
                    q = self.mate[q] - 1
                    if q >= 0 and (T[q] == "name" or (T[q] == "sym" and V[q] in ("]", ")"))):
                        continue
                    ok = False
                    break
                else:
                    ok = False
                    break
                if q >= 0 and T[q] == "sym" and V[q] in (".", ":", ","):
                    q -= 1
                    continue
                break
            if not ok:
                continue
            start = q + 1
            if start >= i or self.kw(start - 1, "local") or self.kw(start - 1, "for"):
                continue
            targets = self.split_commas(start, i)
            exprs = self.expr_list(i + 1, n)
            for k, (a, b) in enumerate(targets):
                if a >= b or not self.isname(a):
                    continue
                plain = all((self.T[x] == "name") if (x - a) % 2 == 0 else self.sym(x, ".") for x in range(a, b))
                if plain:
                    tgt = ".".join(V[x] for x in range(a, b, 2))
                    rhs = exprs[k] if k < len(exprs) else None
                    self.assigns.setdefault(tgt, []).append((a, self.fn_at[a], rhs))
                else:
                    # X.a[expr] = ... : remember the plain prefix
                    x = a
                    names = [V[a]]
                    x += 1
                    while self.sym(x, ".") and self.isname(x + 1) and x + 1 < b:
                        names.append(V[x + 1])
                        x += 2
                    if self.sym(x, "["):
                        self.dyn_assign.setdefault(".".join(names), []).append((a, self.fn_at[a], x))


# =================================================================================================
# Kit model
# =================================================================================================

class TableVal:
    """A table the kit source spells out: named keys (with the token range of each value), positional
    values, plus keys added by a key-set helper or a loop."""
    _next = 0

    def __init__(self, mod, entries=None):
        TableVal._next += 1
        self.id = TableVal._next
        self.mod = mod
        self.named = {}
        self.items = []
        self.extra = set()
        self.open = False
        self.label = ""
        for (kind, key, _ki, vs, ve) in entries or ():
            if kind == "named":
                self.named[key] = (vs, ve)
            elif kind == "pos":
                self.items.append((vs, ve))
            else:
                self.open = True

    def keys(self):
        return set(self.named) | self.extra

    def strs(self):
        P = self.mod.P
        return [P.V[a] for (a, b) in self.items if b - a == 1 and P.T[a] == "str"]


class Check:
    __slots__ = ("kind", "values", "sev", "src", "label", "allow_false", "msg")

    def __init__(self, kind, values=None, sev="error", src=None, label="", allow_false=False, msg=""):
        self.kind = kind          # keys | value | type | req
        self.values = frozenset(values) if values is not None else None
        self.sev = sev
        self.src = src            # (module, line)
        self.label = label
        self.allow_false = allow_false
        self.msg = msg

    def key(self):
        return (self.kind, self.values, self.sev, self.src, self.allow_false)


class Summary:
    def __init__(self):
        self.sites = {}      # (rootfid, idx, path) -> {check.key(): Check}
        self.methods = {}    # name -> {"sites": {(idx, path): {key: Check}}, "params": [...], "vararg": bool}
        self.fields = set()
        self.ftypes = {}     # field -> (module, function): the field holds that component's handle
        self.open = False
        self.handle = False

    def add(self, root, idx, path, check):
        self.sites.setdefault((root, idx, tuple(path)), {})[check.key()] = check


class KitModule:
    def __init__(self, name, path, src):
        self.name = name
        self.path = path
        self.P = Lua(src, name)
        self.aliases = {}       # local name -> kit module name
        self.table_name = None
        self.exports = {}       # name -> ("fn", fid) | ("expr", (a, b))
        self.nested = {}        # ("A", "B") -> (a, b) for M.A.B = expr
        self.problems = []
        self._scan()

    def _scan(self):
        P = self.P
        T, V = P.T, P.V
        # module table: the last file-level return
        ret = None
        for i in range(P.n - 1, -1, -1):
            if P.kw(i, "return") and P.fn_at[i] == 0 and P.block_of[i] == -1:
                ret = i
                break
        if ret is not None:
            a, b = ret + 1, P.expr_end(ret + 1, P.n)
            if P.isname(a, "table") and P.sym(a + 1, ".") and P.sym(a + 3, "("):
                a, b = a + 4, P.mate.get(a + 3, b)
            if b - a == 1 and P.isname(a):
                self.table_name = V[a]
        if self.table_name is None:
            self.problems.append("no `return <ModuleTable>` at file level")
            return
        for (i, names, exprs) in P.local_stmts:
            if P.fn_at[i] != 0:
                continue
            for k, name in enumerate(names):
                if k >= len(exprs):
                    continue
                a, b = exprs[k]
                if P.isname(a, "require") and P.sym(a + 1, "("):
                    m = P.mate.get(a + 1, b)
                    last = None
                    for x in range(a + 2, m):
                        if T[x] in ("name", "str") and not P.isname(x, "WaitForChild") and not P.isname(x, "FindFirstChild"):
                            last = V[x]
                    if last:
                        self.aliases[name] = last
                elif name == self.table_name and P.sym(a, "{") or (name == self.table_name and P.isname(a, "table")):
                    o = a if P.sym(a, "{") else a + 4
                    if P.sym(o, "{"):
                        for (kind, key, _ki, vs, ve) in P.parse_table(o):
                            if kind == "named":
                                self._export(key, vs, ve)
        tn = self.table_name
        for f in P.fns[1:]:
            if f.path and f.path[0] == tn and len(f.path) == 2 and f.parent == 0:
                self.exports[f.path[1]] = ("fn", f.fid)
        for tgt, lst in P.assigns.items():
            parts = tgt.split(".")
            if parts[0] != tn or len(parts) < 2:
                continue
            for (pos, fid, rhs) in lst:
                if fid != 0 or rhs is None:
                    continue
                if len(parts) == 2:
                    self._export(parts[1], rhs[0], rhs[1])
                else:
                    self.nested[tuple(parts[1:])] = rhs

    def _export(self, key, vs, ve):
        P = self.P
        if P.kw(vs, "function") and vs in P.fn_by_tok:
            self.exports[key] = ("fn", P.fn_by_tok[vs])
            return
        if ve - vs == 1 and P.isname(vs):
            d, owner = P.find_decl(P.V[vs], vs, 0)
            if isinstance(d, dict) and d["kind"] == "localfn":
                self.exports[key] = ("fn", d["fn"])
                return
            if isinstance(d, dict) and d["kind"] == "local" and d["expr"] and P.kw(d["expr"][0], "function"):
                fid = P.fn_by_tok.get(d["expr"][0])
                if fid:
                    self.exports[key] = ("fn", fid)
                    return
        self.exports[key] = ("expr", (vs, ve))


TYPE_FNS = ("type", "typeof")
WARN_FNS = ("warn", "warnOnce")


class Kit:
    def __init__(self, sources):
        """sources: {module name: (path label, text)}"""
        self.mods = {}
        for name, (path, text) in sorted(sources.items()):
            self.mods[name] = KitModule(name, path, text)
        self._memo = {}
        self._busy = set()
        self._evbusy = set()
        self._fnsum = {}
        self.unparsed = {}   # module -> [reasons]
        self.model = {}
        self._build()

    # -- evaluation of kit expressions ---------------------------------------------------------
    def ev(self, mod, a, b, fid, ctx):
        """Value of the expression [a,b) in function fid of mod.
        ("org", rootfid, idx, path, tainted) | TableVal | ("mod", name) | ("fn", mod, fid) | ("str", s) |
        ("bool", v) | None"""
        P = mod.P
        a, b = P.strip(a, b)
        if a >= b:
            return None
        key = (mod.name, a, b, fid, ctx)
        if key in self._evbusy:
            return None
        self._evbusy.add(key)
        try:
            return self._ev(mod, a, b, fid, ctx)
        finally:
            self._evbusy.discard(key)

    def _ev(self, mod, a, b, fid, ctx):
        P = mod.P
        T, V = P.T, P.V
        if b - a == 1:
            if T[a] == "str":
                return ("str", V[a])
            if T[a] == "kw" and V[a] in ("true", "false"):
                return ("bool", V[a] == "true")
            if T[a] == "name":
                return self.lookup(mod, V[a], a, fid, ctx)
            return None
        if P.sym(a, "{") and P.mate.get(a) == b - 1:
            tv = TableVal(mod, P.parse_table(a))
            tv.id = ("lit", mod.name, a)
            return tv
        if P.kw(a, "function") and P.close.get(a) == b - 1:
            return ("fn", mod, P.fn_by_tok[a])
        parts = P.top_split(a, b, "or")
        if parts and not P.has_top_kw(a, b, ("and", "if")):
            first = self.ev(mod, parts[0][0], parts[0][1], fid, ctx)
            if isinstance(first, TableVal) or (isinstance(first, tuple) and first[0] == "org"):
                return first
            return None
        if parts and len(parts) == 2 and parts[1][1] - parts[1][0] == 1 and P.kw(parts[1][0], "nil"):
            ands = P.top_split(parts[0][0], parts[0][1], "and")
            if ands:
                v = self.ev(mod, ands[-1][0], ands[-1][1], fid, ctx)
                if isinstance(v, tuple) and v[0] == "org":
                    return ("org", v[1], v[2], v[3], (v[4] or 0) | 2)   # used only when the condition holds
            return None
        if T[a] != "name" or P.has_top_kw(a, b, ("and", "or", "if", "not")):
            return None
        steps, end = P.parse_chain(a, b)
        if end != b:
            return None
        if len(steps) == 2 and steps[1][0] == "index":
            d, owner = P.find_decl(V[a], a, fid)
            if isinstance(d, dict) and d["kind"] == "local":
                writes = [(pos, f2, br) for (pos, f2, br) in P.dyn_assign.get(V[a], ())
                          if br == pos + 1 and P.find_decl(V[a], pos, f2)[0] is d]
                if len(writes) == 1:
                    pos, f2, br = writes[0]
                    eq = P.mate.get(br, br) + 1
                    if P.sym(eq, "="):
                        return self.ev(mod, eq + 1, P.expr_end(eq + 1, P.n), f2, ctx)
        if V[a] == "table" and len(steps) == 3 and steps[1][0] == "field" and steps[1][1] in ("freeze", "clone") \
                and steps[2][0] == "call" and steps[2][1]:
            x, y = steps[2][1][0]
            return self.ev(mod, x, y, fid, ctx)
        cur = self.lookup(mod, V[a], a, fid, ctx)
        for st in steps[1:]:
            if cur is None:
                return None
            kind = st[0]
            name = None
            if kind == "field":
                name = st[1]
            elif kind == "index":
                x, y = st[1]
                if y - x == 1 and T[x] == "str":
                    name = V[x]
                else:
                    return None
            if name is not None:
                cur = self.field(cur, name)
            elif kind == "call":
                cur = self.call_value(mod, cur, st[1], fid, ctx)
            else:
                return None
        return cur

    def field(self, cur, name):
        if isinstance(cur, TableVal):
            rng = cur.named.get(name)
            if rng is None:
                return None
            sub = self.ev(cur.mod, rng[0], rng[1], 0, ())
            if isinstance(sub, TableVal) and not sub.label:
                sub.label = (cur.label + "." if cur.label else "") + name
            return sub
        if isinstance(cur, tuple):
            if cur[0] == "rec":
                return cur[1].get(name)
            if cur[0] == "org":
                return ("org", cur[1], cur[2], cur[3] + (name,), cur[4])
            if cur[0] == "mod":
                return self.export_value(cur[1], name)
        return None

    def export_value(self, modname, name):
        m = self.mods.get(modname)
        if m is None:
            return None
        ex = m.exports.get(name)
        if ex is None:
            return None
        if ex[0] == "fn":
            return ("fn", m, ex[1])
        val = self.ev(m, ex[1][0], ex[1][1], 0, ())
        if isinstance(val, TableVal):
            if not val.label:
                val.label = modname + "." + name
            for path, rng in m.nested.items():
                if path[0] == name and len(path) == 2:
                    val.named.setdefault(path[1], rng)
        return val

    def call_value(self, mod, callee, args, fid, ctx):
        if not (isinstance(callee, tuple) and callee[0] == "fn"):
            return None
        cm, cf = callee[1], callee[2]
        CP = cm.P
        # a key-set helper: builds {name = true} from a list
        builds = False
        for i in CP.own_tokens(cf):
            if CP.sym(i, "[") and CP.isname(i - 1) and CP.isname(i + 1) and CP.sym(i + 2, "]") and CP.sym(i + 3, "=") \
                    and CP.kw(i + 4, "true"):
                builds = True
                break
        if builds and args:
            src = self.ev(mod, args[0][0], args[0][1], fid, ctx)
            if isinstance(src, TableVal):
                tv = TableVal(cm)
                tv.id = ("keyset", mod.name, args[0][0])
                tv.extra |= set(src.strs()) | set(src.named)
                a, b = CP.own_range(cf)
                for i in CP.own_tokens(cf):
                    if CP.sym(i, "{") and i in CP.mate:
                        for (kind, key, _ki, _vs, _ve) in CP.parse_table(i):
                            if kind == "named":
                                tv.extra.add(key)
                    if CP.kw(i, "in"):
                        j = i + 1
                        if CP.isname(j) and CP.V[j] in ("ipairs", "pairs") and CP.sym(j + 1, "("):
                            j += 2
                        if CP.isname(j) and CP.V[j] not in CP.fns[cf].params:
                            other = self.lookup(cm, CP.V[j], j, cf, ())
                            if isinstance(other, TableVal):
                                tv.extra |= set(other.strs())
                return tv
            return None
        # a function whose one return is a table literal: { Variant = spec.Variant or "Default", ... }
        rets = [i for i in CP.own_tokens(cf) if CP.kw(i, "return")]
        if len(rets) == 1 and CP.sym(rets[0] + 1, "{") and (rets[0] + 1) in CP.mate \
                and CP.expr_end(rets[0] + 1, CP.fns[cf].close + 1) == CP.mate[rets[0] + 1] + 1:
            rec = {}
            argv = None
            for (kind, key, _ki, vs, ve) in CP.parse_table(rets[0] + 1):
                if kind != "named":
                    continue
                v = self.ev(cm, vs, ve, cf, ())
                if isinstance(v, tuple) and v[0] == "org" and v[1] == cf and v[2] < len(args):
                    if argv is None:
                        argv = [self.ev(mod, x, y, fid, ctx) for (x, y) in args]
                    o = argv[v[2]]
                    if isinstance(o, tuple) and o[0] == "org":
                        rec[key] = ("org", o[1], o[2], o[3] + v[3], o[4] or v[4])
            if rec:
                return ("rec", rec)
        # a local helper that returns a table built from one argument (readProps, table.clone wrappers)
        if cm is mod and cf not in [e[1] for e in mod.exports.values() if e[0] == "fn"]:
            orgs = []
            for j, (x, y) in enumerate(args):
                v = self.ev(mod, x, y, fid, ctx)
                if isinstance(v, tuple) and v[0] == "org":
                    orgs.append((j, v))
            if len(orgs) == 1:
                j, o = orgs[0]
                if not o[3]:
                    return ("org", o[1], o[2], o[3], True)   # a table built from the props table
                if j in self._passthrough(cm, cf):
                    return o                                 # the helper hands its argument back
        return None

    def _passthrough(self, cm, cf):
        """Parameter indexes a function returns unchanged (`return value`)."""
        key = ("pt", cm.name, cf)
        if key not in self._fnsum:
            CP = cm.P
            f = CP.fns[cf]
            out = set()
            for i in CP.own_tokens(cf):
                if CP.kw(i, "return") and CP.isname(i + 1) and CP.V[i + 1] in f.params \
                        and CP.expr_end(i + 1, f.close + 1) == i + 2:
                    out.add(f.params.index(CP.V[i + 1]))
            self._fnsum[key] = out
        return self._fnsum[key]

    def lookup(self, mod, name, pos, fid, ctx):
        P = mod.P
        d, owner = P.find_decl(name, pos, fid)
        if d is None:
            if name in mod.aliases:
                return ("mod", mod.aliases[name]) if mod.aliases[name] in self.mods else None
            if name == mod.table_name:
                return ("mod", mod.name)
            return None
        if isinstance(d, tuple):
            for (k, v) in ctx:
                if k == (owner, d[1]):
                    return v
            return ("org", owner, d[1], (), False)
        if d["kind"] == "localfn":
            return ("fn", mod, d["fn"])
        if d["kind"] == "for":
            base = self.ev(mod, d["expr"][0], d["expr"][1], owner, ctx)
            if d["how"] == "ipairs":
                step = "*" if d["index"] == 1 else None
            elif d["how"] == "pairs":
                step = "#key" if d["index"] == 0 else "*"
            else:
                step = "#key" if d["index"] == 0 else "*"
                if d["count"] == 1:
                    step = "#key"
            if step is None:
                return None
            if isinstance(base, tuple) and base[0] == "org":
                return ("org", base[1], base[2], base[3] + (step,), base[4])
            if isinstance(base, TableVal) and step == "*":
                return ("elems", base)
            return None
        if d["expr"] is None:
            if name == mod.table_name:
                return ("mod", mod.name)
            return None
        a, b = d["expr"]
        if name == mod.table_name and owner == 0:
            return ("mod", mod.name)
        if name in mod.aliases and owner == 0:
            return ("mod", mod.aliases[name]) if mod.aliases[name] in self.mods else None
        val = self.ev(mod, a, b, owner, ctx)
        if isinstance(val, TableVal):
            if not val.label:
                val.label = name
            if not val.named and not val.items and not val.extra:
                self._fill_derived(mod, name, d, owner, ctx, val)
        return val

    def _fill_derived(self, mod, name, d, owner, ctx, tv):
        """`local t = {}` then `t[k] = ...` for k looping over a list the source spells out."""
        P = mod.P
        a, b = d["scope"]
        any_unknown = False
        for i in range(a, min(b, P.n)):
            if P.isname(i, name) and P.sym(i + 1, "[") and not P.sym(i - 1, ".") and (i + 1) in P.mate:
                m = P.mate[i + 1]
                if not P.sym(m + 1, "="):
                    continue
                if m == i + 3 and P.isname(i + 2):
                    v = self.lookup(mod, P.V[i + 2], i + 2, P.fn_at[i], ctx)
                    if isinstance(v, tuple) and v[0] == "elems":
                        tv.extra |= set(v[1].strs())
                        continue
                elif m == i + 3 and P.T[i + 2] == "str":
                    tv.extra.add(P.V[i + 2])
                    continue
                any_unknown = True
            elif P.isname(i, name) and P.sym(i + 1, ".") and P.isname(i + 2) and P.sym(i + 3, "=") and not P.sym(i - 1, "."):
                tv.extra.add(P.V[i + 2])
        if any_unknown:
            tv.open = True

    # -- sites ---------------------------------------------------------------------------------
    def _set_of(self, mod, a, b, fid, ctx):
        """The key set of the table expression [a,b), or None."""
        v = self.ev(mod, a, b, fid, ctx)
        if isinstance(v, TableVal) and not v.open and v.keys():
            return v
        return None

    def _pred(self, mod, callee):
        """A local predicate `return ... T[param] ~= nil`: the TableVal, or None."""
        if not (isinstance(callee, tuple) and callee[0] == "fn"):
            return None
        cm, cf = callee[1], callee[2]
        CP = cm.P
        f = CP.fns[cf]
        a, b = CP.own_range(cf)
        if len(f.params) != 1 or not CP.kw(a, "return"):
            return None
        e = CP.expr_end(a + 1, b)
        if e != b:
            return None
        found = None
        for i in range(a + 1, b):
            if CP.sym(i, "[") and CP.isname(i + 1, f.params[0]) and CP.sym(i + 2, "]") and CP.isname(i - 1):
                s = CP.chain_start(i - 1)
                tv = self._set_of(cm, s, i, cf, ())
                if tv is None or found is not None:
                    return None
                found = tv
        return found

    def _org(self, mod, a, b, fid, ctx):
        v = self.ev(mod, a, b, fid, ctx)
        if isinstance(v, tuple) and v[0] == "org":
            return v
        return None

    VALUE_MSG = re.compile(r"unknown|must be|no slot|is \\?\"|not a valid|invalid|is not in", re.I)

    def _msg(self, P, i):
        """The string literals of the call at NAME token i (error(...), warn(...), assert(...))."""
        m = P.mate.get(i + 1)
        if m is None:
            return ""
        return " ".join(P.V[x] for x in range(i + 2, m) if P.T[x] == "str")

    @staticmethod
    def _in_if(P, i, fid):
        """Is token i inside an if statement of function fid (so that it may not run)?"""
        top = P.fns[fid].tok
        b = P.block_of[i]
        while b >= 0 and b != top:
            if P.V[b] == "if":
                return True
            b = P.block_of[b]
        return False

    def _cond_sites(self, mod, fid, ctx, a, b, sev, line, add, prior=(), msg="", cond_if=False):
        """Sites of the condition tokens [a,b) that lead to an error. prior: earlier clause conditions of the
        same if chain."""
        P = mod.P
        T, V = P.T, P.V
        src = (mod.name, line)
        nilguard = set()   # origins compared with nil in this or an earlier clause

        def note_nil(x, y):
            for i in range(x, y):
                if P.kw(i, "nil") and (P.sym(i - 1, "==") or P.sym(i - 1, "~=")) and P.isname(i - 2):
                    s = P.chain_start(i - 2)
                    o = self._org(mod, s, i - 1, fid, ctx)
                    if o:
                        nilguard.add(o[1:4])
        note_nil(a, b)
        for (x, y) in prior:
            note_nil(x, y)

        def vadd(o, check):
            if self.VALUE_MSG.search(msg or ""):
                add(o, check)

        # membership: T[V] == nil | T[V] ~= true | not T[V] | not pred(V)
        for i in range(a, b):
            if P.sym(i, "[") and i in P.mate and P.isname(i - 1):
                m = P.mate[i]
                if m >= b:
                    continue
                s = P.chain_start(i - 1)
                neg = (P.sym(m + 1, "==") and P.kw(m + 2, "nil")) or (P.sym(m + 1, "~=") and P.kw(m + 2, "true")) \
                    or (P.kw(s - 1, "not") and not P.sym(m + 1, ".") and not P.sym(m + 1, "==") and not P.sym(m + 1, "~="))
                if not neg:
                    continue
                tv = self._set_of(mod, s, i, fid, ctx)
                o = self._org(mod, i + 1, m, fid, ctx)
                if tv is not None and o is not None:
                    vadd(o, Check("value", tv.keys(), sev, src, tv.label, msg=msg))
            if P.kw(i, "not") and P.isname(i + 1) and P.sym(i + 2, "(") and (i + 2) in P.mate and not P.sym(i, "."):
                callee = self.lookup(mod, V[i + 1], i + 1, fid, ctx)
                tv = self._pred(mod, callee)
                m = P.mate[i + 2]
                if tv is not None and m < b:
                    o = self._org(mod, i + 3, m, fid, ctx)
                    if o is not None:
                        vadd(o, Check("value", tv.keys(), sev, src, tv.label, msg=msg))
        # a local that holds T[V], tested for nil
        s2, e2 = P.strip(a, b)
        cand = None
        if e2 - s2 == 2 and P.kw(s2, "not") and P.isname(s2 + 1):
            cand = s2 + 1
        elif e2 - s2 == 3 and P.isname(s2) and P.sym(s2 + 1, "==") and P.kw(s2 + 2, "nil"):
            cand = s2
        if cand is not None:
            d, owner = P.find_decl(V[cand], cand, fid)
            if isinstance(d, dict) and d["kind"] == "local" and d["expr"]:
                x, y = d["expr"]
                hits = [i for i in range(x, y) if P.sym(i, "[") and i in P.mate and P.isname(i - 1)]
                if len(hits) == 1:
                    i = hits[0]
                    m = P.mate[i]
                    s = P.chain_start(i - 1)
                    rest_ok = (s == x and m == y - 1) or (
                        P.isname(x, "type") and P.kw(s - 1, "and") and m + 1 < y and P.kw(m + 1, "or") and P.kw(m + 2, "nil"))
                    if rest_ok:
                        tv = self._set_of(mod, s, i, owner, ctx)
                        o = self._org(mod, i + 1, m, owner, ctx)
                        if tv is not None and o is not None:
                            vadd(o, Check("value", tv.keys(), sev, src, tv.label, msg=msg))
        # literal comparison chain: V ~= "A" and V ~= "B" ...
        terms = P.top_split(s2, e2, "and") or [(s2, e2)]
        lits, subject, ok = set(), None, True
        for (x, y) in terms:
            x, y = P.strip(x, y)
            if y - x >= 3 and P.sym(y - 2, "~=") and (T[y - 1] == "str" or P.kw(y - 1, "nil")):
                o = self._org(mod, x, y - 2, fid, ctx)
                if o is None:
                    ok = False
                    break
                if subject is None:
                    subject = o
                elif subject[1:4] != o[1:4]:
                    ok = False
                    break
                if T[y - 1] == "str":
                    lits.add(V[y - 1])
            else:
                ok = False
                break
        if ok and subject is not None and lits and not P.has_top_kw(s2, e2, ("or",)):
            for (x, y) in prior:  # earlier `V == "X"` branches of the same chain are accepted values too
                for i in range(x, y):
                    if T[i] == "str" and P.sym(i - 1, "==") and P.isname(i - 2):
                        o = self._org(mod, P.chain_start(i - 2), i - 1, fid, ctx)
                        if o and o[1:4] == subject[1:4]:
                            lits.add(V[i])
            vadd(subject, Check("value", lits, sev, src, "literals in the kit source", msg=msg))
        # types: type(V) ~= "t"
        types = {}
        falsy = set()
        bad = set()
        for i in range(a, b):
            if P.isname(i) and V[i] in TYPE_FNS and P.sym(i + 1, "(") and (i + 1) in P.mate and not P.sym(i - 1, "."):
                m = P.mate[i + 1]
                o = self._org(mod, i + 2, m, fid, ctx)
                if o is None:
                    continue
                if P.sym(m + 1, "~=") and m + 2 < b and T[m + 2] == "str":
                    types.setdefault(o[1:4], (o, set()))[1].add(V[m + 2])
                else:
                    bad.add(o[1:4])
            if P.kw(i, "false") and P.sym(i - 1, "~=") and P.isname(i - 2):
                o = self._org(mod, P.chain_start(i - 2), i - 1, fid, ctx)
                if o:
                    falsy.add(o[1:4])
        for k, (o, ts) in types.items():
            if k in bad:
                continue
            add(o, Check("type", ts, sev, src, "type", allow_false=k in falsy))
            if k not in nilguard and not o[4] and o[3] and sev == "error" and not cond_if:
                add(o, Check("req", None, sev, src, "required"))
        # required: exactly `V == nil`
        if e2 - s2 >= 3 and P.sym(e2 - 2, "==") and P.kw(e2 - 1, "nil") and not P.has_top_kw(s2, e2, ("and", "or")):
            o = self._org(mod, s2, e2 - 2, fid, ctx)
            if o is not None and not o[4] and sev == "error" and not cond_if:
                add(o, Check("req", None, sev, src, "required"))

    def _rejects(self, mod, fid, ctx):
        """Sites of a validator: `if <cond> then return false, "reason" end`. {(idx, path): {key: Check}}"""
        key = ("rej", mod.name, fid, ctx)
        if key in self._fnsum:
            return self._fnsum[key]
        self._fnsum[key] = {}
        P = mod.P
        out = {}

        def add(o, check):
            if o[1] == fid and not o[4] and check.kind == "value":
                out.setdefault((o[2], o[3]), {})[check.key()] = check
        for i in P.own_tokens(fid):
            if P.kw(i, "if") and i in P.ifs and not self._in_if(P, i, fid):
                for (kwi, then) in P.ifs[i]["clauses"]:
                    if then is not None and P.kw(then + 1, "return") and P.kw(then + 2, "false"):
                        e = P.expr_list(then + 2, P.n)
                        msg = " ".join(P.V[x] for (a, b) in e for x in range(a, b) if P.T[x] == "str")
                        self._cond_sites(mod, fid, ctx, kwi + 1, then, "error", P.L[then + 1], add, (), msg, False)
        self._fnsum[key] = out
        return out

    def _first_call(self, P, i):
        """Is the statement at token i a call to error / warn? Returns severity or None."""
        if P.isname(i) and P.sym(i + 1, "("):
            if P.V[i] == "error":
                return "error"
            if P.V[i] in WARN_FNS:
                return "warn"
        return None

    def summary(self, mod, fid, ctx=()):
        key = (mod.name, fid, ctx)
        if key in self._memo:
            return self._memo[key]
        if key in self._busy:
            return Summary()
        self._busy.add(key)
        try:
            s = self._summary(mod, fid, ctx)
        finally:
            self._busy.discard(key)
        self._memo[key] = s
        return s

    def _summary(self, mod, fid, ctx):
        P = mod.P
        T, V = P.T, P.V
        S = Summary()
        f = P.fns[fid]
        lineage = set(P.ancestors(fid))

        def add(o, check):
            root, idx, path, tainted = o[1], o[2], o[3], o[4]
            if path and path[-1] == "#key":
                if check.kind != "value":
                    return
                check = Check("keys", check.values, check.sev, check.src, check.label)
                path = path[:-1]
            if "#key" in path:
                return
            if tainted and (not path or (check.kind == "req" and len(path) < 2)):
                return  # a table rebuilt from the props: its defaults may fill a top-level key
            if isinstance(tainted, int) and not isinstance(tainted, bool) and tainted & 2:
                if check.kind == "req":
                    return
                if check.sev == "error":
                    check = Check(check.kind, check.values, "cond", check.src, check.label, check.allow_false, check.msg)
            if check.kind == "req" and path and path[-1] == "*":
                return
            S.add(root, idx, path, check)

        own = list(P.own_tokens(fid))
        ownset = set(own)
        # 1. if statements whose branch starts with error(...)
        for i in own:
            if T[i] == "kw" and V[i] == "if" and i in P.ifs:
                rec = P.ifs[i]
                prior = []
                clauses = rec["clauses"]
                for ci, (kwi, then) in enumerate(clauses):
                    if then is None:
                        continue
                    sev = self._first_call(P, then + 1)
                    nested = self._in_if(P, i, fid)
                    if sev == "error" and then - kwi == 3 and P.kw(kwi + 1, "not") and P.isname(kwi + 2):
                        # local ok, reason = Validator(x); if not ok then error(...)
                        d, owner = P.find_decl(V[kwi + 2], kwi + 2, fid)
                        if isinstance(d, dict) and d["kind"] == "local" and d.get("expr") and P.sym(d["expr"][1] - 1, ")"):
                            x, y = d["expr"]
                            o_ = P.mate.get(y - 1)
                            if o_ is not None and P.isname(o_ - 1) and P.chain_start(o_ - 1) == x:
                                callee = self.ev(mod, x, o_, owner, ctx)
                                if isinstance(callee, tuple) and callee[0] == "fn":
                                    cargs = P.expr_list(o_ + 1, y - 1)
                                    for (idx, path), checks in self._rejects(callee[1], callee[2], ()).items():
                                        if idx < len(cargs):
                                            o = self._org(mod, cargs[idx][0], cargs[idx][1], owner, ctx)
                                            if o is not None:
                                                for c in checks.values():
                                                    add(("org", o[1], o[2], o[3] + path, o[4]), c)
                    if sev:
                        self._cond_sites(mod, fid, ctx, kwi + 1, then, sev, P.L[then + 1], add, tuple(prior),
                                         self._msg(P, then + 1), nested)
                    elif P.kw(then + 1, "if") and (then + 1) in P.ifs:
                        # if V == nil then if guard then error(...)
                        inner = P.ifs[then + 1]["clauses"][0]
                        if inner[1] is not None and self._first_call(P, inner[1] + 1) == "error" and inner[1] - inner[0] == 2:
                            g = self.ev(mod, inner[0] + 1, inner[1], fid, ctx)
                            if g == ("bool", True):
                                self._cond_sites(mod, fid, ctx, kwi + 1, then, "error", P.L[inner[1] + 1], add,
                                                 tuple(prior), self._msg(P, inner[1] + 1), nested)
                    # `if V ~= nil then ... elseif guard then error("... required")`
                    if ci > 0 and sev == "error" and then - kwi == 2 and P.isname(kwi + 1):
                        c0 = clauses[0]
                        if c0[1] is not None and c0[1] - c0[0] >= 4 and P.sym(c0[1] - 2, "~=") and P.kw(c0[1] - 1, "nil") \
                                and not P.has_top_kw(c0[0] + 1, c0[1], ("and", "or")) and not nested:
                            g = self.ev(mod, kwi + 1, then, fid, ctx)
                            o = self._org(mod, c0[0] + 1, c0[1] - 2, fid, ctx)
                            if g == ("bool", True) and o is not None:
                                add(o, Check("req", None, "error", (mod.name, P.L[then + 1]), "required"))
                    prior.append((kwi + 1, then))
                el = rec["else"]
                if el is not None and self._first_call(P, el + 1) == "error":
                    # every branch compares one value with literals; anything else throws
                    lits, subject, ok = set(), None, True
                    for (kwi, then) in clauses:
                        if then is None:
                            ok = False
                            break
                        for (x, y) in (P.top_split(kwi + 1, then, "or") or [(kwi + 1, then)]):
                            x, y = P.strip(x, y)
                            if y - x >= 3 and P.sym(y - 2, "==") and T[y - 1] == "str":
                                o = self._org(mod, x, y - 2, fid, ctx)
                                if o is None or (subject is not None and subject[1:4] != o[1:4]):
                                    ok = False
                                    break
                                subject = o
                                lits.add(V[y - 1])
                            else:
                                ok = False
                                break
                        if not ok:
                            break
                    if ok and subject is not None and lits and self.VALUE_MSG.search(self._msg(P, el + 1)):
                        add(subject, Check("value", lits, "error", (mod.name, P.L[el + 1]), "literals in the kit source",
                                           msg=self._msg(P, el + 1)))
        # 2. assert(T[V], ...) / assert(type(V) == "t", ...)
        for i in own:
            if P.isname(i, "assert") and P.sym(i + 1, "(") and (i + 1) in P.mate and not P.sym(i - 1, "."):
                args = P.expr_list(i + 2, P.mate[i + 1])
                if not args:
                    continue
                amsg = self._msg(P, i)
                nested = self._in_if(P, i, fid)
                for (x, y) in (P.top_split(args[0][0], args[0][1], "and") or [args[0]]):
                    x, y = P.strip(x, y)
                    src = (mod.name, P.L[i])
                    if P.sym(y - 1, "]") and (y - 1) in P.mate and P.isname(x):
                        o_ = P.mate[y - 1]
                        if P.chain_start(o_ - 1) == x:
                            tv = self._set_of(mod, x, o_, fid, ctx)
                            o = self._org(mod, o_ + 1, y - 1, fid, ctx)
                            if tv is not None and o is not None and self.VALUE_MSG.search(amsg):
                                add(o, Check("value", tv.keys(), "error", src, tv.label, msg=amsg))
                    elif P.isname(x) and V[x] in TYPE_FNS and P.sym(x + 1, "(") and P.mate.get(x + 1) == y - 3 \
                            and P.sym(y - 2, "==") and T[y - 1] == "str":
                        o = self._org(mod, x + 2, y - 3, fid, ctx)
                        if o is not None:
                            add(o, Check("type", {V[y - 1]}, "error", src, "type"))
                            if not o[4] and not nested:
                                add(o, Check("req", None, "error", src, "required"))
        # 3. a function that compares one parameter with literals and ends in error(...)
        if fid != 0 and f.close - 1 in P.mate and P.sym(f.close - 1, ")"):
            o_ = P.mate[f.close - 1]
            if P.isname(o_ - 1, "error") and P.block_of[o_ - 1] == f.tok and (o_ - 1) in ownset:
                by = {}
                for i in own:
                    if T[i] == "str" and P.sym(i - 1, "==") and P.isname(i - 2) and not P.sym(i - 3, "."):
                        if V[i - 2] in f.params and P.find_decl(V[i - 2], i - 2, fid)[1] == fid:
                            by.setdefault(V[i - 2], set()).add(V[i])
                named = {V[x] for x in range(o_ + 1, f.close - 1) if P.isname(x) and V[x] in by}
                if len(named) == 1:
                    by = {k: v for k, v in by.items() if k in named}
                if len(by) == 1 and self.VALUE_MSG.search(self._msg(P, o_ - 1)):
                    (pname, lits), = by.items()
                    d, owner = P.find_decl(pname, f.close - 1, fid)
                    if isinstance(d, tuple):
                        add(("org", fid, d[1], (), False),
                            Check("value", lits, "error", (mod.name, P.L[o_ - 1]), "literals in the kit source"))
        # 4. calls
        for i in own:
            if not (P.sym(i, "(") and i in P.mate and P.isname(i - 1)):
                continue
            s = P.chain_start(i - 1)
            if P.sym(s - 1, ":") or P.kw(s - 1, "function") or (P.sym(s - 1, ".") and not P.isname(s - 2)):
                continue
            if s == i - 1 and V[s] in ("error", "assert", "type", "typeof", "tostring", "ipairs", "pairs", "require"):
                continue
            callee = self.ev(mod, s, i, fid, ctx)
            if not (isinstance(callee, tuple) and callee[0] == "fn"):
                continue
            cm, cf = callee[1], callee[2]
            args = P.expr_list(i + 1, P.mate[i])
            vals = [self.ev(mod, x, y, fid, ctx) for (x, y) in args]
            cfn = cm.P.fns[cf]
            keep = set(cm.P.ancestors(cf)) if cm is mod else set()
            nctx = [(k, v) for (k, v) in ctx if cm is mod and k[0] in keep and k[0] != cf]
            for j, v in enumerate(vals):
                inline = P.sym(P.strip(*args[j])[0], "{")  # props written at the call are data, not a definition
                if j < len(cfn.params) and ((isinstance(v, TableVal) and not inline) or (isinstance(v, tuple) and v[0] == "bool")):
                    nctx.append(((cf, j), v))
            nctx = tuple(sorted(nctx, key=lambda kv: kv[0]))
            sub = self.summary(cm, cf, nctx)
            for (root, idx, path), checks in sub.sites.items():
                if root == cf:
                    if idx >= len(vals):
                        continue
                    o = vals[idx]
                    if isinstance(o, TableVal) and o.mod is mod and path and path[0] in o.named \
                            and isinstance(o.id, tuple) and o.id[0] == "lit":
                        # props the kit itself writes as a literal: { Icon = state.Icon }
                        rng = o.named[path[0]]
                        o = self.ev(mod, rng[0], rng[1], fid, ctx)
                        path = path[1:]
                    elif isinstance(o, tuple) and o[0] == "rec" and path and path[0] in o[1]:
                        o = o[1][path[0]]
                        path = path[1:]
                    if not (isinstance(o, tuple) and o[0] == "org"):
                        continue
                    guarded = self._in_if(P, i, fid)
                    for c in checks.values():
                        if c.kind == "req" and guarded and not path:
                            continue  # the caller guards the call
                        add(("org", o[1], o[2], o[3] + path, o[4]), c)
                elif cm is mod and root in lineage:
                    for c in checks.values():
                        S.add(root, idx, path, c)
        # 5. nested functions: what they check on our own (closure) variables holds for us too
        kids = P.children(fid)
        for k in kids:
            sub = self.summary(mod, k, ctx)
            for (root, idx, path), checks in sub.sites.items():
                if root in lineage:
                    for c in checks.values():
                        if c.kind == "req":
                            continue
                        S.add(root, idx, path, c)
        # 6. the handle this function returns
        if fid != 0:
            self._handle(mod, fid, ctx, S, own, kids)
        return S

    def _comp_of(self, mod, a, b, fid, ctx, depth=0):
        """(module, function) when the expression [a,b) is the handle of an exported kit component."""
        P = mod.P
        a, b = P.strip(a, b)
        if depth > 4 or a >= b:
            return None
        if b - a == 1 and P.isname(a):
            d, owner = P.find_decl(P.V[a], a, fid)
            if isinstance(d, dict) and d["kind"] == "local":
                cands = []
                if d.get("expr"):
                    cands.append((d["expr"], owner))
                for (pos, f2, rhs) in P.assigns.get(P.V[a], ()):
                    if rhs and d["scope"][0] < pos <= d["scope"][1] and P.find_decl(P.V[a], pos, f2)[0] is d:
                        cands.append((rhs, f2))
                found = {self._comp_of(mod, r[0], r[1], f2, ctx, depth + 1) for (r, f2) in cands
                         if not (r[1] - r[0] == 1 and P.kw(r[0], "nil"))}
                if len(found) == 1:
                    return found.pop()
            return None
        if not (P.isname(a) and P.sym(b - 1, ")")):
            return None
        o_ = P.mate.get(b - 1)
        if o_ is None or not P.isname(o_ - 1) or P.chain_start(o_ - 1) != a:
            return None
        callee = self.ev(mod, a, o_, fid, ctx)
        if not (isinstance(callee, tuple) and callee[0] == "fn"):
            return None
        cm, cf = callee[1], callee[2]
        for ex, val in cm.exports.items():
            if val == ("fn", cf):
                return (cm.name, ex) if self.summary(cm, cf, ()).handle else None
        return None

    def _method_ret(self, mod, kid, host, ctx):
        """(module, function) when a handle method returns a component: `return T[k]` with `T[..] = comp`."""
        P = mod.P
        a, b = P.own_range(kid)
        found = set()
        for i in P.own_tokens(kid):
            if not P.kw(i, "return"):
                continue
            x, y = i + 1, P.expr_end(i + 1, b + 1)
            if y <= x or P.kw(x, "nil"):
                continue
            if P.isname(x) and P.sym(x + 1, "[") and P.mate.get(x + 1) == y - 1:
                name = P.V[x]
                d, _o = P.find_decl(name, x, kid)
                got = set()
                for (pos, f2, br) in P.dyn_assign.get(name, ()):
                    if P.find_decl(name, pos, f2)[0] is not d:
                        continue
                    eq = P.mate.get(br, br) + 1
                    if not P.sym(eq, "="):
                        continue
                    e = P.expr_end(eq + 1, P.n)
                    if e - eq == 2 and P.kw(eq + 1, "nil"):
                        continue
                    got.add(self._comp_of(mod, eq + 1, e, f2, ctx))
                found |= got or {None}
            else:
                found.add(self._comp_of(mod, x, y, kid, ctx))
        if len(found) == 1:
            return found.pop()
        return None

    def _item_rule(self, mod, host, kid, ctx):
        """Sites for a method that takes a list of items which the component later copies, minus some keys,
        into the props of a pooled child built by a local builder:
            for _, item in ipairs(list) ... T[k] = item            (the method)
            for name, value in pairs(item) do if name ~= "Key" then copy[name] = value   (anywhere in the host)
            buildChild(parent, props, ...)                          (a local builder with a key set)
        Returns {(0, ("*",) + path): {key: Check}}."""
        P = mod.P
        T, V = P.T, P.V
        f = P.fns[kid]
        if not f.params:
            return {}
        iterates = any(d["kind"] == "for" and d["fid"] == kid and d["how"] == "ipairs" and d["index"] == 1
                       and d["expr"][1] - d["expr"][0] == 1 and V[d["expr"][0]] == f.params[0]
                       for lst in P.decls.values() for d in lst)
        if not iterates:
            return {}
        h = P.fns[host]
        excluded = set()
        copies = False
        for i in range(h.tok, h.close):
            if P.kw(i, "for") and P.isname(i + 1) and P.sym(i + 2, ",") and P.isname(i + 3) and P.kw(i + 4, "in") \
                    and P.isname(i + 5, "pairs") and P.sym(i + 6, "("):
                do = P.mate.get(i + 6, i) + 1
                if not (P.kw(do, "do") and P.kw(do + 1, "if")):
                    continue
                rec = P.ifs.get(do + 1)
                if not rec or rec["clauses"][0][1] is None or len(rec["clauses"]) != 1 or rec["else"] is not None:
                    continue
                then = rec["clauses"][0][1]
                keys = set()
                ok = True
                for (x, y) in (P.top_split(do + 2, then, "and") or [(do + 2, then)]):
                    if y - x == 3 and P.isname(x, V[i + 1]) and P.sym(x + 1, "~=") and T[x + 2] == "str":
                        keys.add(V[x + 2])
                    else:
                        ok = False
                body = then + 1
                if ok and P.isname(body) and P.sym(body + 1, "[") and P.isname(body + 2, V[i + 1]) and P.sym(body + 3, "]") \
                        and P.sym(body + 4, "=") and P.isname(body + 5, V[i + 3]):
                    copies = True
                    excluded |= keys
        if not copies:
            return {}
        exported = {val[1] for val in mod.exports.values() if val[0] == "fn"}
        builders = {}
        for i in range(h.tok, h.close):
            if P.isname(i) and P.sym(i + 1, "(") and not P.sym(i - 1, ".") and not P.sym(i - 1, ":") and not P.kw(i - 1, "function"):
                d, owner = P.find_decl(V[i], i, P.fn_at[i])
                if isinstance(d, dict) and d["kind"] == "localfn" and owner == 0 and d["fn"] not in exported:
                    sub = self.summary(mod, d["fn"], ())
                    for (root, idx, path), checks in sub.sites.items():
                        if root == d["fn"] and not path and any(c.kind == "keys" for c in checks.values()):
                            builders[d["fn"]] = idx
        if len(builders) != 1:
            return {}
        (b, bidx), = builders.items()
        sub = self.summary(mod, b, ())
        out = {}
        for (root, idx, path), checks in sub.sites.items():
            if root != b or idx != bidx:
                continue
            for c in checks.values():
                if c.kind == "keys" and not path:
                    c2 = Check("keys", set(c.values) | excluded, c.sev, c.src, c.label)
                elif c.kind in ("value", "type") and path:
                    c2 = c
                else:
                    continue
                out.setdefault((0, ("*",) + path), {})[c2.key()] = c2
        return out

    def _handle(self, mod, fid, ctx, S, own, kids):
        P = mod.P
        T, V = P.T, P.V
        a, b = P.own_range(fid)
        names = []
        derived = []
        literal = None
        for i in own:
            if not P.kw(i, "return"):
                continue
            x = i + 1
            y = P.expr_end(x, b + 1)
            if y <= x or P.kw(x, "nil"):
                continue
            if y - x == 1 and P.isname(x):
                names.append((V[x], x))
            elif P.sym(x, "{") and P.mate.get(x) == y - 1:
                literal = x
            elif P.isname(x) and P.sym(y - 1, ")"):
                derived.append((x, y))
            else:
                return

        def method(name, kid):
            kf = P.fns[kid]
            sub = self.summary(mod, kid, ctx)
            entry = S.methods.setdefault(name, {"sites": {}, "params": list(kf.params), "vararg": kf.vararg,
                                                "colon": kf.colon, "returns": None})
            for (root, idx, path), checks in sub.sites.items():
                if root == kid:
                    entry["sites"].setdefault((idx, path), {}).update(checks)
            entry["returns"] = self._method_ret(mod, kid, fid, ctx)
            for k2, checks in self._item_rule(mod, fid, kid, ctx).items():
                entry["sites"].setdefault(k2, {}).update(checks)

        def from_table(o):
            for (kind, key, _ki, vs, ve) in P.parse_table(o):
                if kind == "named":
                    S.fields.add(key)
                    if P.kw(vs, "function") and vs in P.fn_by_tok:
                        method(key, P.fn_by_tok[vs])
                    elif ve - vs == 1 and P.isname(vs):
                        d, _o = P.find_decl(V[vs], vs, fid)
                        if isinstance(d, dict) and d["kind"] == "localfn":
                            method(key, d["fn"])
                elif kind == "dyn":
                    S.open = True

        def from_call(x, y):
            m = y - 1
            o_ = P.mate.get(m)
            if o_ is None or not P.isname(o_ - 1):
                S.open = True
                return
            s = P.chain_start(o_ - 1)
            callee = self.ev(mod, s, o_, fid, ctx) if s >= x else None
            if not (isinstance(callee, tuple) and callee[0] == "fn"):
                S.open = True
                return
            cm, cf = callee[1], callee[2]
            args = P.expr_list(o_ + 1, m)
            vals = [self.ev(mod, p, q, fid, ctx) for (p, q) in args]
            cfn = cm.P.fns[cf]
            keep = set(cm.P.ancestors(cf)) if cm is mod else set()
            nctx = [(k, v) for (k, v) in ctx if cm is mod and k[0] in keep and k[0] != cf]
            for j, v in enumerate(vals):
                if j < len(cfn.params) and (isinstance(v, TableVal) or (isinstance(v, tuple) and v[0] == "bool")):
                    nctx.append(((cf, j), v))
            sub = self.summary(cm, cf, tuple(sorted(nctx, key=lambda kv: kv[0])))
            if not sub.handle:
                S.open = True
                return
            S.handle = True
            S.fields |= sub.fields
            S.ftypes.update(sub.ftypes)
            S.open = S.open or sub.open
            for name, entry in sub.methods.items():
                mine = S.methods.setdefault(name, {"sites": {}, "params": entry["params"], "vararg": entry["vararg"],
                                                   "colon": entry.get("colon", False),
                                                   "returns": entry.get("returns")})
                for k, checks in entry["sites"].items():
                    mine["sites"].setdefault(k, {}).update(checks)

        if literal is not None:
            S.handle = True
            from_table(literal)
        for (x, y) in derived:
            from_call(x, y)
        seen = set()
        for (name, pos) in names:
            if name in seen:
                continue
            seen.add(name)
            d, owner = P.find_decl(name, pos, fid)
            if not (isinstance(d, dict) and d["kind"] == "local" and owner == fid):
                continue
            if d["expr"] is None:
                continue
            x, y = P.strip(*d["expr"])
            if P.sym(x, "{") and P.mate.get(x) == y - 1:
                S.handle = True
                from_table(x)
            elif P.isname(x) and P.sym(y - 1, ")") and not P.isname(x, "Instance") and not P.isname(x, "setmetatable"):
                before = S.open
                from_call(x, y)
                if not S.handle:
                    S.open = before
                    continue
            else:
                continue
            # fields and methods written onto the handle inside this function
            fa, fb = P.fns[fid].tok, P.fns[fid].close
            for k in kids:
                kf = P.fns[k]
                if kf.path and len(kf.path) == 2 and kf.path[0] == name:
                    S.fields.add(kf.path[1])
                    method(kf.path[1], k)
                elif kf.target and kf.target.startswith(name + ".") and kf.target.count(".") == 1:
                    S.fields.add(kf.field)
                    method(kf.field, k)
            for tgt, lst in P.assigns.items():
                parts = tgt.split(".")
                if parts[0] != name or len(parts) != 2:
                    continue
                for (pos2, f2, rhs) in lst:
                    if fa < pos2 < fb and P.find_decl(name, pos2, f2)[0] is d:
                        S.fields.add(parts[1])
                        if rhs and not (rhs[1] - rhs[0] == 1 and P.kw(rhs[0], "nil")):
                            ct = self._comp_of(mod, rhs[0], rhs[1], f2, ctx)
                            if ct and S.ftypes.get(parts[1], ct) == ct:
                                S.ftypes[parts[1]] = ct
                            else:
                                S.ftypes[parts[1]] = None
                        if rhs and rhs[1] - rhs[0] == 1 and P.isname(rhs[0]):
                            dd, _o = P.find_decl(V[rhs[0]], rhs[0], f2)
                            if isinstance(dd, dict) and dd["kind"] == "localfn":
                                method(parts[1], dd["fn"])
            for (pos2, f2, _x) in P.dyn_assign.get(name, ()):
                if fa < pos2 < fb and P.find_decl(name, pos2, f2)[0] is d:
                    S.open = True
            for x2 in range(d["scope"][0] + 1, fb):
                # the handle handed to another function may gain fields there
                if P.isname(x2, name) and (P.sym(x2 - 1, "(") or P.sym(x2 - 1, ",")) \
                        and (P.sym(x2 + 1, ")") or P.sym(x2 + 1, ",")):
                    enc = P.encl[x2]
                    if enc and enc[0] == "(" and P.isname(enc[1] - 1) and P.find_decl(name, x2, P.fn_at[x2])[0] is d:
                        S.open = True

    # -- the model the screen checker uses -------------------------------------------------------
    def _build(self):
        for name, mod in self.mods.items():
            if mod.problems:
                self.unparsed[name] = list(mod.problems)
            entry = {"path": mod.path, "functions": {}, "values": {}}
            self.model[name] = entry
            for ex, val in sorted(mod.exports.items()):
                if val[0] == "fn":
                    f = mod.P.fns[val[1]]
                    summ = self.summary(mod, val[1], ())
                    sites = {}
                    for (root, idx, path), checks in summ.sites.items():
                        if root == val[1]:
                            sites.setdefault((idx, path), {}).update(checks)
                    entry["functions"][ex] = {
                        "params": list(f.params), "vararg": f.vararg, "colon": f.colon, "sites": sites,
                        "handle": summ.handle, "methods": summ.methods, "fields": set(summ.fields), "open": summ.open,
                        "ftypes": {k: v for k, v in summ.ftypes.items() if v},
                        "line": mod.P.L[f.tok],
                    }
                else:
                    tv = self.export_value(name, ex)
                    entry["values"][ex] = tv if isinstance(tv, TableVal) else None
        # modules whose components take props but for which no key set was found
        for name, entry in self.model.items():
            mod = self.mods[name]
            for fn, info in entry["functions"].items():
                if fn.startswith("_") or "props" not in info["params"]:
                    continue
                idx = info["params"].index("props")
                has = any(c.kind == "keys" for c in info["sites"].get((idx, ()), {}).values())
                if not has:
                    self.unparsed.setdefault(name, []).append(
                        f"{fn}: takes props but no accepted key set could be extracted")
                elif info["handle"] and "Set" in info["methods"]:
                    setsites = info["methods"]["Set"]["sites"].get((0, ()), {})
                    if not any(c.kind == "keys" for c in setsites.values()):
                        self.unparsed.setdefault(name, []).append(f"{fn}.Set: no accepted key set could be extracted")

    def method_index(self):
        """{method name: [(module, function, entry)]} for handle methods that check their arguments."""
        if "methods" not in self._fnsum:
            out = {}
            for modname, entry in self.model.items():
                for fn, info in entry["functions"].items():
                    for mname, m in info["methods"].items():
                        if any(c.kind in ("value", "keys") for checks in m["sites"].values() for c in checks.values()):
                            out.setdefault(mname, []).append((modname, fn, m))
            self._fnsum["methods"] = out
        return self._fnsum["methods"]

    def key_sets(self):
        """Every key set a component or one of its methods accepts."""
        if "keysets" not in self._fnsum:
            out = []
            for entry in self.model.values():
                for info in entry["functions"].values():
                    groups = [info["sites"]] + [m["sites"] for m in info["methods"].values()]
                    for sites in groups:
                        for checks in sites.values():
                            for c in checks.values():
                                if c.kind == "keys" and set(c.values) not in out:
                                    out.append(set(c.values))
            self._fnsum["keysets"] = out
        return self._fnsum["keysets"]

    def value_union(self):
        """{prop name: every value any component accepts for a prop of that name}"""
        if "union" not in self._fnsum:
            out = {}

            def take(sites):
                for (idx, path), checks in sites.items():
                    if path and path[-1] != "*":
                        for c in checks.values():
                            if c.kind == "value":
                                out.setdefault(path[-1], set()).update(c.values)
            for entry in self.model.values():
                for info in entry["functions"].values():
                    take(info["sites"])
                    for m in info["methods"].values():
                        take(m["sites"])
            self._fnsum["union"] = out
        return self._fnsum["union"]

    def describe(self):
        """A plain dict of the extracted model (for --model and the report)."""
        out = {}
        for name, entry in sorted(self.model.items()):
            fns = {}
            for fn, info in sorted(entry["functions"].items()):
                fns[fn] = {
                    "params": info["params"] + (["..."] if info["vararg"] else []),
                    "args": _sites_dict(info["sites"]),
                    "handle": info["handle"],
                    "open": info["open"],
                    "fields": sorted(info["fields"]),
                    "field_components": {k: "%s.%s" % v for k, v in sorted(info["ftypes"].items())},
                    "methods": {m: {"params": e["params"], "args": _sites_dict(e["sites"]),
                                    "returns": ("%s.%s" % e["returns"]) if e.get("returns") else None}
                                for m, e in sorted(info["methods"].items())},
                }
            vals = {k: (sorted(v.keys()) if v is not None else None) for k, v in sorted(entry["values"].items())}
            out[name] = {"path": entry["path"], "functions": fns, "values": vals}
        return out


def _path_text(idx, path):
    return "arg%d" % (idx + 1) + "".join("[]" if p == "*" else "." + p for p in path)


def _sites_dict(sites):
    out = {}
    for (idx, path), checks in sorted(sites.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        lst = []
        for c in checks.values():
            d = {"check": c.kind, "severity": c.sev, "kit_line": c.src[1] if c.src else None}
            if c.values is not None:
                d["accepted"] = sorted(c.values)
            if c.label:
                d["from"] = c.label
            lst.append(d)
        out[_path_text(idx, path)] = sorted(lst, key=lambda d: (d["check"], d.get("kit_line") or 0))
    return out


# =================================================================================================
# Screen checker
# =================================================================================================

class Finding:
    __slots__ = ("level", "kind", "family", "file", "line", "call", "what", "accepted", "kit")

    def __init__(self, level, kind, family, file, line, call, what, accepted=None, kit=None):
        self.level, self.kind, self.family, self.file, self.line = level, kind, family, file, line
        self.call, self.what, self.accepted, self.kit = call, what, accepted, kit

    def as_dict(self):
        return {"level": self.level, "kind": self.kind, "family": self.family, "file": self.file, "line": self.line,
                "call": self.call, "what": self.what, "accepted": self.accepted, "kit": self.kit}


NILV = ("nil",)
CYCLE = ("cycle",)


class Screen:
    """One screen source checked against the kit model."""

    def __init__(self, kit, text, family, relpath):
        self.kit = kit
        self.P = Lua(text, relpath)
        self.family = family
        self.file = relpath
        self.findings = {}
        self._var_memo = {}
        self._var_busy = set()
        self._fn_memo = {}
        self._fn_busy = set()
        self._quiet = 0
        self.stats = {"kit_calls": 0, "props_checked": 0, "set_calls": 0}
        self._counted = set()
        self._checked = set()   # table literals whose keys were checked against a kit key set

    # -- reporting -----------------------------------------------------------------------------
    def report(self, level, kind, pos, call, what, accepted=None, kitsrc=None):
        if self._quiet:
            self._trial.append((level, kind, pos, call, what, accepted, kitsrc))
            return
        P = self.P
        line = P.L[pos] if 0 <= pos < P.n else 0
        key = (line, what)
        prev = self.findings.get(key)
        if prev is not None and (prev.level == "ERROR" or level != "ERROR"):
            return
        acc = sorted(accepted) if accepted is not None else None
        kitref = None
        if kitsrc:
            kitref = "Kit.%s:%d" % kitsrc
        self.findings[key] = Finding(level, kind, self.family, self.file, line, P.text(call[0], call[1]), what, acc, kitref)

    # -- values --------------------------------------------------------------------------------
    def fev(self, a, b, fid):
        P = self.P
        T, V = P.T, P.V
        a, b = P.strip(a, b)
        if a >= b:
            return None
        if b - a == 1:
            if T[a] == "kw" and V[a] in ("nil", "false"):
                return NILV
            if T[a] == "name":
                return self.var(V[a], a, fid)
            if T[a] == "str":
                return ("str", V[a])
            return None
        if P.sym(a, "{") and P.mate.get(a) == b - 1:
            bag = {}
            for (kind, key, _ki, vs, ve) in P.parse_table(a):
                if kind == "named":
                    v = self.fev(vs, ve, fid)
                    if v is not None and v[0] in ("mod", "bag", "fn", "comp", "tbl"):
                        bag[key] = v
            if bag:
                return ("bag", bag, None)
            return ("lit", a, None)
        if P.kw(a, "function") and P.close.get(a) == b - 1:
            return ("fnref", P.fn_by_tok[a])
        parts = P.top_split(a, b, "or")
        if parts and not P.has_top_kw(a, b, ("and", "if")):
            for (x, y) in parts:
                v = self.fev(x, y, fid)
                if v is not None and v != NILV:
                    return v
            return None
        if T[a] != "name" or P.has_top_kw(a, b, ("and", "or", "if", "not")):
            return None
        steps, end = P.parse_chain(a, b)
        if end != b:
            return None
        v = self.walk(steps, fid, a, b)
        if v is None and len(steps) == 2 and steps[1][0] == "field" and steps[1][1] in self.kit.mods \
                and re.search(r"(?i)kit", steps[0][1]):
            return ("mod", steps[1][1], True)  # `kit.Text` where kit is handed in from elsewhere
        return v

    def var(self, name, pos, fid):
        """Value of a plain local name at pos."""
        P = self.P
        d, owner = P.find_decl(name, pos, fid)
        if isinstance(d, tuple):
            return self.param(owner, d[1]) or self.soft(name)
        if d is None:
            cands = [(p, f, rhs) for (p, f, rhs) in P.assigns.get(name, ())]
            ident = ("g", name)
        else:
            if d["kind"] == "localfn":
                return ("fnref", d["fn"])
            if d["kind"] == "for":
                return None
            ident = ("d", name, d["pos"])
            cands = []
            if d.get("expr") is not None:
                cands.append((d["pos"], d["fid"], d["expr"]))
            a, b = d["scope"]
            for (p, f, rhs) in P.assigns.get(name, ()):
                if a < p <= b and P.find_decl(name, p, f)[0] is d:
                    cands.append((p, f, rhs))
        if ident in self._var_memo:
            v = self._var_memo[ident]
        elif ident in self._var_busy:
            return CYCLE
        else:
            self._var_busy.add(ident)
            try:
                v = self.merge([self.assigned(rhs, f) for (_p, f, rhs) in cands])
            finally:
                self._var_busy.discard(ident)
            self._var_memo[ident] = v
        if v is None and d is None:
            return self.soft(name)
        if v is not None and v[0] in ("lit", "bag") and (len(v) < 3 or v[2] is None):
            v = (v[0], v[1], name)   # fields added later are found as <name>.<field>
        return v

    def param(self, fid, idx):
        """Value of a parameter of a local function, when every call in the file passes the same component."""
        P = self.P
        f = P.fns[fid]
        dotted = None
        if f.path and len(f.path) == 2 and not f.colon:
            dotted = f.path
        elif f.target and f.target.count(".") == 1:
            dotted = f.target.split(".")
        elif not f.localname:
            return None
        ident = ("p", fid, idx)
        if ident in self._var_memo:
            return self._var_memo[ident]
        if ident in self._var_busy:
            return None
        pname = f.params[idx]
        if any(P.find_decl(pname, p_, f_)[1] == fid for (p_, f_, _r) in P.assigns.get(pname, ())):
            return None  # the function reassigns it
        self._var_busy.add(ident)
        try:
            vals = []
            for i in range(P.n if dotted else 0):
                # M.fn(...) : every use of the dotted name in this file
                if not (P.isname(i, dotted[0]) and P.sym(i + 1, ".") and P.isname(i + 2, dotted[1])) or P.sym(i - 1, "."):
                    continue
                if P.kw(i - 1, "function") or P.sym(i + 3, "="):
                    continue
                if P.sym(i + 3, "(") and (i + 3) in P.mate:
                    args = P.expr_list(i + 4, P.mate[i + 3])
                    vals.append(self.fev(args[idx][0], args[idx][1], P.fn_at[i]) if idx < len(args) else NILV)
                else:
                    vals.append(None)
            if dotted and not vals:
                vals.append(None)  # only called from other files
            for i in range(0 if dotted else P.n):
                if not P.isname(i, f.localname) or P.sym(i - 1, ".") or P.sym(i - 1, ":") or P.kw(i - 1, "function"):
                    continue
                d2, _o = P.find_decl(f.localname, i, P.fn_at[i])
                mine = (isinstance(d2, dict) and d2.get("fn") == fid) or (
                    isinstance(d2, dict) and d2["kind"] == "local" and d2.get("expr")
                    and P.fn_by_tok.get(d2["expr"][0]) == fid)
                if not mine:
                    continue
                if P.sym(i + 1, "(") and (i + 1) in P.mate:
                    args = P.expr_list(i + 2, P.mate[i + 1])
                    vals.append(self.fev(args[idx][0], args[idx][1], P.fn_at[i]) if idx < len(args) else NILV)
                elif not (P.kw(i - 1, "local") and P.sym(i + 1, "=")):
                    vals.append(None)  # the function is passed around; its callers are not all visible
            v = self.merge(vals) if vals else None
            if v is not None and v[0] not in ("comp", "multi", "mod", "bag"):
                v = None
        finally:
            self._var_busy.discard(ident)
        self._var_memo[ident] = v
        return v

    def assigned(self, rhs, fid):
        """Value of one assignment. A bare parameter that cannot be traced (a test seam such as
        `function M._setKit(replacement) cache = replacement end`) says nothing about the variable."""
        if not rhs:
            return None
        v = self.fev(rhs[0], rhs[1], fid)
        P = self.P
        if v is None and rhs[1] - rhs[0] == 1 and P.isname(rhs[0])                 and isinstance(P.find_decl(P.V[rhs[0]], rhs[0], fid)[0], tuple):
            return CYCLE
        return v

    def soft(self, name):
        if name in self.kit.mods and name not in ("Text", "Data", "Input", "Touch"):
            return ("mod", name, True)
        return None

    def merge(self, vals):
        vals = [v for v in vals if v != NILV and v != CYCLE]
        if not vals or any(v is None for v in vals):
            return None
        first = vals[0]
        if all(self.same(first, v) for v in vals[1:]):
            return first
        if all(v[0] == "comp" for v in vals):
            uniq = []
            for v in vals:
                if not any(self.same(v, u) for u in uniq):
                    uniq.append(v)
            return ("multi", uniq)
        return None

    @staticmethod
    def same(x, y):
        if x[0] != y[0]:
            return False
        if x[0] in ("mod", "comp"):
            return x[1:3] == y[1:3] if x[0] == "comp" else x[1] == y[1]
        if x[0] == "bag":
            return set(x[1]) == set(y[1])
        if x[0] == "lit":
            return x[1] == y[1]
        return x == y

    def dotted(self, target):
        """Value of a dotted target (self._kit, View._kit) from every assignment in the file."""
        P = self.P
        ident = ("t", target)
        if ident in self._var_memo:
            return self._var_memo[ident]
        if ident in self._var_busy:
            return CYCLE
        lst = P.assigns.get(target)
        fns = [f for f in P.fns[1:] if f.name == target and (f.path or f.target)]
        if not lst and not fns:
            return None
        self._var_busy.add(ident)
        try:
            vals = [self.assigned(rhs, f) for (_p, f, rhs) in (lst or ())]
            vals += [("fnref", f.fid) for f in fns]
            if len(fns) > 1:
                v = None
            else:
                v = self.merge(vals)
        finally:
            self._var_busy.discard(ident)
        self._var_memo[ident] = v
        return v

    def set_wrapper(self, fid):
        """(component parameter index, patch parameter index) when the function calls `component.Set(patch)`,
        with patch a parameter or a table copied key by key from a parameter."""
        key = ("sw", fid)
        if key in self._fn_memo:
            return self._fn_memo[key]
        P = self.P
        f = P.fns[fid]
        out = None
        a, b = P.own_range(fid)
        for i in range(a, b):
            if P.isname(i) and P.sym(i + 1, ".") and P.isname(i + 2, "Set") and P.sym(i + 3, "(") and P.isname(i + 4) \
                    and P.sym(i + 5, ")") and not P.sym(i - 1, ".") and P.V[i] in f.params:
                if P.find_decl(P.V[i], i, P.fn_at[i])[1] != fid:
                    continue
                arg = P.V[i + 4]
                d, owner = P.find_decl(arg, i + 4, P.fn_at[i])
                if isinstance(d, tuple) and owner == fid:
                    out = (f.params.index(P.V[i]), d[1])
                    break
                if isinstance(d, dict) and d["kind"] == "local":
                    # for key, value in pairs(props) do ... delta[key] = value
                    for j in range(a, i):
                        if P.kw(j, "for") and P.isname(j + 1) and P.sym(j + 2, ",") and P.isname(j + 3) and P.kw(j + 4, "in") \
                                and P.isname(j + 5, "pairs") and P.sym(j + 6, "(") and P.isname(j + 7) and P.sym(j + 8, ")") \
                                and P.V[j + 7] in f.params:
                            do = j + 9
                            end = P.close.get(do, do)
                            for k in range(do, end):
                                if P.isname(k, arg) and P.sym(k + 1, "[") and P.isname(k + 2, P.V[j + 1]) and P.sym(k + 3, "]") \
                                        and P.sym(k + 4, "=") and P.isname(k + 5, P.V[j + 3]):
                                    out = (f.params.index(P.V[i]), f.params.index(P.V[j + 7]))
                    if out:
                        break
        self._fn_memo[key] = out
        return out

    def fn_value(self, fid):
        """What a screen function returns: (value, wrap) with wrap = (mod, fn, {kit arg: own param})."""
        if fid in self._fn_memo:
            return self._fn_memo[fid]
        if fid in self._fn_busy:
            return (None, None)
        self._fn_busy.add(fid)
        P = self.P
        vals, wrap = [], None
        try:
            f = P.fns[fid]
            a, b = P.own_range(fid)
            for i in P.own_tokens(fid):
                if not P.kw(i, "return"):
                    continue
                x = i + 1
                y = P.expr_end(x, b + 1)
                if y <= x:
                    vals.append(NILV)
                    continue
                if y - x == 1 and P.isname(x) and P.V[x] in f.params and P.find_decl(P.V[x], x, fid)[1] == fid                         and not P.assigns.get(P.V[x]):
                    vals.append(("pass", f.params.index(P.V[x])))
                    continue
                v = self.fev(x, y, fid)
                vals.append(v)
                if v is not None and v[0] == "comp" and P.isname(x) and P.sym(y - 1, ")"):
                    o_ = P.mate.get(y - 1)
                    args = P.expr_list(o_ + 1, y - 1) if o_ else []
                    mapping = {}
                    for j, (p, q) in enumerate(args):
                        if q - p == 1 and P.isname(p) and P.V[p] in f.params and P.find_decl(P.V[p], p, fid)[1] == fid:
                            mapping[j] = f.params.index(P.V[p])
                    if mapping:
                        wrap = (v[1], v[2], mapping)
            v = self.merge(vals) if vals else None
            if v is not None and v[0] == "multi":
                v = None
            if v is None or v[0] != "comp":
                wrap = None
        finally:
            self._fn_busy.discard(fid)
        self._fn_memo[fid] = (v, wrap)
        return (v, wrap)

    # -- chains --------------------------------------------------------------------------------
    def walk(self, steps, fid, a, b):
        P = self.P
        V = P.V
        kit = self.kit
        name = steps[0][1]
        call = (a, b)
        k = 1
        if name == "require" and len(steps) >= 2 and steps[1][0] == "call":
            cur = self.require(steps[1], fid)
            k = 2
        else:
            cur = self.var(name, a, fid)
            if cur is None and name in kit.mods and steps[1][0] == "field" \
                    and (steps[1][1] in kit.model[name]["functions"] or steps[1][1] in kit.model[name]["values"]) \
                    and P.find_decl(name, a, fid)[0] is not None:
                cur = ("mod", name, True)  # a parameter or local named after the kit module
        prefix = name
        while k < len(steps):
            st = steps[k]
            kind = st[0]
            nxt = steps[k + 1] if k + 1 < len(steps) else None
            if kind == "field" or (kind == "index" and st[1][1] - st[1][0] == 1 and P.T[st[1][0]] == "str"):
                fname = st[1] if kind == "field" else V[st[1][0]]
                pos = st[2]
                prefix = prefix + "." + fname if prefix else None
                if cur == CYCLE:
                    cur = None
                if cur is not None and cur[0] in ("lit", "bag"):
                    if len(cur) > 2 and cur[2]:
                        prefix = cur[2] + "." + fname
                    hit = cur[1].get(fname) if cur[0] == "bag" else None
                    cur = hit if hit is not None else (self.dotted(prefix) if prefix else None)
                elif cur is None or cur == NILV or cur[0] in ("str", "fnref", "modinst"):
                    cur = self.dotted(prefix) if prefix else None
                    if cur is None and fname in kit.mods and nxt and nxt[0] == "field":
                        m = kit.model[fname]
                        if nxt[1] in m["functions"] or nxt[1] in m["values"]:
                            cur = ("mod", fname, True)
                elif cur[0] == "mod":
                    cur = self.member(cur, fname, pos, nxt, call)
                elif cur[0] == "kitfolder":
                    if fname in kit.mods:
                        cur = ("modinst", fname)
                    else:
                        if fname[:1].isupper():
                            self.report("NOTE", "unchecked", pos, call,
                                        "Kit.%s is not among the kit sources read; calls into it are not checked" % fname)
                        cur = None
                elif cur[0] == "tbl":
                    cur = self.tbl_field(cur, fname, pos, nxt, call)
                elif cur[0] in ("comp", "multi"):
                    cur = self.handle_field(cur, fname, pos, nxt, call)
                else:
                    cur = None
            elif kind == "index":
                cur = None
                prefix = None
            elif kind == "method":
                pos = st[2]
                mname = st[1]
                args = nxt[1] if nxt and nxt[0] == "call" else []
                if cur is not None and cur[0] == "kitfolder" and mname in ("WaitForChild", "FindFirstChild") and args \
                        and P.T[args[0][0]] == "str":
                    n2 = V[args[0][0]]
                    cur = ("modinst", n2) if n2 in kit.mods else None
                elif mname in ("WaitForChild", "FindFirstChild") and args and P.T[args[0][0]] == "str" \
                        and V[args[0][0]] == "Kit" and args[0][1] - args[0][0] == 1:
                    cur = ("kitfolder",)
                elif cur is not None and cur[0] == "mod" and not (len(cur) > 2 and cur[2]):
                    info = kit.model[cur[1]]["functions"].get(mname)
                    if info is not None and not info["colon"]:
                        self.report("ERROR", "colon", pos, call,
                                    "Kit.%s.%s is called with ':' but is declared with '.'; every argument shifts by one"
                                    % (cur[1], mname), None, (cur[1], info["line"]))
                    cur = None
                elif cur is not None and cur[0] == "comp":
                    info = self.comp_info(cur)
                    entry = info["methods"].get(mname) if info else None
                    if entry is not None and not entry.get("colon"):
                        self.report("ERROR", "colon", pos, call,
                                    "%s handle method %s is called with ':' but is declared with '.'; the handle "
                                    "itself arrives as the first argument" % (self.comp_name(cur), mname))
                    cur = None
                else:
                    cur = None
                    fns = [f for f in P.fns[1:] if f.field == mname and f.path and len(f.path) == 2]
                    if len(fns) == 1 and args:
                        ret, _w = self.fn_value(fns[0].fid)
                        if ret is not None and ret[0] == "pass" and ret[1] < len(args):
                            cur = self.fev(args[ret[1]][0], args[ret[1]][1], fid)
                prefix = None
                k += 1  # the call that belongs to the method
            elif kind == "call":
                args = st[1]
                pos = st[2]
                if cur is None or cur == NILV:
                    prev = steps[k - 1]
                    if prev[0] == "field" and prev[1] == "Set" and len(args) == 1 and P.sym(args[0][0], "{"):
                        self.unresolved_set(args[0], prev[2], call)
                    elif prev[0] == "field" and prev[1] != "Set" and k >= 2:
                        self.unresolved_method(prev[1], args, pos, (call[0], st[3] + 1))
                    cur = None
                elif cur[0] == "member":
                    cur = self.kit_call(cur[1], cur[2], args, pos, call, fid)
                elif cur[0] == "hmethod":
                    comp, mname = cur[1], cur[2]
                    self.method_call(comp, mname, args, pos, call, fid)
                    cur = None
                    if comp[0] == "comp":
                        ret = self.comp_info(comp)["methods"][mname].get("returns")
                        if ret:
                            cur = ("comp",) + tuple(ret)
                elif cur[0] == "fnref":
                    ret, wrap = self.fn_value(cur[1])
                    if wrap:
                        self.wrapped_call(wrap, args, pos, call, fid)
                    sw = self.set_wrapper(cur[1])
                    if sw and max(sw) < len(args):
                        comp = self.fev(args[sw[0]][0], args[sw[0]][1], fid)
                        patch_arg = args[sw[1]]
                        if comp is not None and comp[0] in ("comp", "multi") and all(
                                "Set" in (self.comp_info(c_) or {"methods": {}})["methods"]
                                for c_ in (comp[1] if comp[0] == "multi" else [comp])):
                            self.method_call(comp, "Set", [patch_arg], pos, call, fid)
                        elif P.sym(P.strip(*patch_arg)[0], "{"):
                            self.unresolved_set(P.strip(*patch_arg), pos + 1, call,
                                                P.text(args[sw[0]][0], args[sw[0]][1], 60))
                    if ret is not None and ret[0] == "pass":
                        ret = self.fev(args[ret[1]][0], args[ret[1]][1], fid) if ret[1] < len(args) else None
                    cur = ret
                else:
                    cur = None
                prefix = None
            k += 1
        if cur is not None and cur[0] in ("member", "hmethod"):
            return None
        return cur

    def require(self, st, fid):
        P = self.P
        args = st[1]
        if not args:
            return None
        a, b = args[0]
        v = self.fev(a, b, fid)
        if v is not None and v[0] == "modinst":
            return ("mod", v[1])
        # textual fallback: require(<something>.Kit.<Name>) or a variable named kit / folder
        last, has_kit = None, False
        for x in range(a, b):
            if P.T[x] in ("name", "str") and P.V[x] not in ("WaitForChild", "FindFirstChild"):
                if P.V[x] == "Kit":
                    has_kit = True
                last = P.V[x]
        base = P.V[a] if P.isname(a) else ""
        if last in self.kit.mods and last != base and (has_kit or re.fullmatch(r"(?i)kit|kitfolder|folder", base)):
            if has_kit or self.var(base, a, fid) in (None, ("kitfolder",)):
                return ("mod", last)
        return None

    def member(self, cur, fname, pos, nxt, call):
        modname = cur[1]
        soft = len(cur) > 2 and cur[2]
        m = self.kit.model[modname]
        if fname in m["functions"]:
            return ("member", modname, fname)
        if fname in m["values"]:
            tv = m["values"][fname]
            return ("tbl", tv, "%s.%s" % (modname, fname)) if tv is not None else None
        if modname in self.kit.unparsed and any("return" in p for p in self.kit.unparsed[modname]):
            return None
        names = sorted(n for n in list(m["functions"]) + list(m["values"]) if not n.startswith("_"))
        if soft:
            self.report("NOTE", "suspect", pos, call,
                        "%s.%s: Kit.%s exports no such member (receiver assumed to be the kit module from its name)"
                        % (modname, fname, modname), names, None)
            return None
        if nxt is not None and nxt[0] in ("call", "field", "index", "method"):
            how = "call" if nxt[0] == "call" else "index"
            self.report("ERROR", "export", pos, call,
                        "Kit.%s has no member %s; this is an attempt to %s nil" % (modname, fname, how), names, None)
        elif self.P.kw(pos + 1, "or") or self.P.sym(pos + 1, "==") or self.P.sym(pos + 1, "~="):
            self.report("NOTE", "suspect", pos, call,
                        "Kit.%s has no member %s; the value read is nil (guarded or compared here)" % (modname, fname),
                        names, None)
        else:
            self.report("ERROR", "export", pos, call,
                        "Kit.%s has no member %s; the value read is nil" % (modname, fname), names, None)
        return None

    def tbl_field(self, cur, fname, pos, nxt, call):
        tv, label = cur[1], cur[2]
        if fname in tv.named:
            sub = self.kit.field(tv, fname)
            return ("tbl", sub, label + "." + fname) if isinstance(sub, TableVal) else None
        if tv.open or not tv.named or fname in tv.extra:
            return None
        P = self.P
        end = call[1]
        j = pos + 1
        guarded = P.kw(j, "or") or P.sym(j, "==") or P.sym(j, "~=") or P.sym(pos - (2 * label.count(".") + 3), "==") \
            or P.sym(j, "=")
        if P.sym(j, "="):
            return None
        if nxt is not None and nxt[0] in ("call", "field", "index", "method"):
            self.report("ERROR", "token", pos, call,
                        "Kit %s has no key %s; this is an attempt to index nil" % (label, fname), tv.keys(), None)
        elif guarded:
            self.report("NOTE", "suspect", pos, call,
                        "Kit %s has no key %s; the value read is nil (guarded or compared here)" % (label, fname),
                        tv.keys(), None)
        else:
            self.report("ERROR", "token", pos, call,
                        "Kit %s has no key %s; the value read is nil" % (label, fname), tv.keys(), None)
        return None

    def comp_info(self, comp):
        return self.kit.model[comp[1]]["functions"].get(comp[2])

    @staticmethod
    def comp_name(comp):
        return "%s.%s" % (comp[1], comp[2])

    def handle_field(self, cur, fname, pos, nxt, call):
        comps = cur[1] if cur[0] == "multi" else [cur]
        infos = [self.comp_info(c) for c in comps]
        if any(i is None for i in infos):
            return None
        if cur[0] == "multi":
            if all(fname in i["methods"] for i in infos) and nxt and nxt[0] == "call":
                return ("hmethod", cur, fname)
            return None
        info = infos[0]
        if fname in info["methods"] and nxt and nxt[0] == "call":
            return ("hmethod", cur, fname)
        if fname in info["ftypes"]:
            return ("comp",) + tuple(info["ftypes"][fname])
        if fname in info["fields"] or info["open"]:
            return None
        if "Destroy" not in info["methods"] and "Set" not in info["methods"]:
            return None  # a plain data table, not a component handle
        if self.P.sym(pos + 1, "="):
            return None  # the screen stores its own field on the handle
        fields = sorted(info["fields"])
        if nxt is not None and nxt[0] in ("call", "field", "index", "method"):
            how = "call" if nxt[0] == "call" else "index"
            self.report("ERROR", "handle", pos, call,
                        "the handle of Kit.%s has no field %s; this is an attempt to %s nil"
                        % (self.comp_name(cur), fname, how), fields, None)
        else:
            self.report("NOTE", "suspect", pos, call,
                        "the handle of Kit.%s has no field %s; the value read is nil" % (self.comp_name(cur), fname),
                        fields, None)
        return None

    # -- calls ---------------------------------------------------------------------------------
    def kit_call(self, modname, fname, args, pos, call, fid):
        info = self.kit.model[modname]["functions"][fname]
        if ("k", pos) not in self._counted and not self._quiet:
            self._counted.add(("k", pos))
            self.stats["kit_calls"] += 1
        label = "Kit.%s.%s" % (modname, fname)
        if not info["vararg"] and len(args) > len(info["params"]):
            self.report("NOTE", "suspect", pos, call,
                        "%s takes %d argument(s) (%s) but %d are passed; the extra ones are ignored"
                        % (label, len(info["params"]), ", ".join(info["params"]), len(args)), None, (modname, info["line"]))
        self.check_args(label, info["sites"], info["params"], args, pos, call, fid, modname)
        if "scope" in info["params"] and len(args) <= info["params"].index("scope") and info["handle"] \
                and not any(c.kind == "req" for c in info["sites"].get((info["params"].index("scope"), ()), {}).values()):
            self.report("NOTE", "suspect", pos, call,
                        "%s is called without its scope argument (%s); the kit connects through scope while it builds"
                        % (label, ", ".join(info["params"])), None, (modname, info["line"]))
        if info["handle"]:
            return ("comp", modname, fname)
        return None

    def method_call(self, comp, mname, args, pos, call, fid):
        comps = comp[1] if comp[0] == "multi" else [comp]
        if mname == "Set" and ("s", pos) not in self._counted and not self._quiet:
            self._counted.add(("s", pos))
            self.stats["set_calls"] += 1
        if len(comps) == 1:
            c = comps[0]
            entry = self.comp_info(c)["methods"][mname]
            self.check_args("%s handle .%s" % (self.comp_name(c), mname), entry["sites"], entry["params"], args, pos,
                            call, fid, c[1])
            return
        # several components may be behind this name: an ERROR only when it fails for every one of them
        trials = []
        for c in comps:
            entry = self.comp_info(c)["methods"][mname]
            self._quiet += 1
            saved = getattr(self, "_trial", None)
            self._trial = []
            try:
                self.check_args("%s handle .%s" % (self.comp_name(c), mname), entry["sites"], entry["params"], args,
                                pos, call, fid, c[1])
                trials.append(self._trial)
            finally:
                self._trial = saved
                self._quiet -= 1
        names = ", ".join(self.comp_name(c) for c in comps)

        def bad(tr):
            return {(t[2], t[4].split(": ", 1)[-1]): t for t in tr if t[0] == "ERROR" or t[1] == "suspect"}
        # Only what every candidate refuses is reported: which component the name holds and which list it is
        # given usually follow the same condition (compact: a Rail and tile items; else a List and row items).
        common = set(bad(trials[0]))
        for tr in trials[1:]:
            common &= set(bad(tr))
        first = bad(trials[0])
        for key in sorted(common, key=lambda k: (k[0], k[1])):
            level, kind, p, cl, what, acc, ks = first[key]
            self.report(level, kind, p, cl, "%s handle .%s: %s (the name may hold any of: %s; each refuses this)"
                        % (" / ".join(self.comp_name(c) for c in comps), mname, key[1], names), acc, ks)
        for tr in trials:
            for (level, kind, p, cl, what, acc, ks) in tr:
                if kind == "unchecked":
                    self.report(level, kind, p, cl, what, acc, ks)
            break

    def wrapped_call(self, wrap, args, pos, call, fid):
        modname, fname, mapping = wrap
        info = self.kit.model[modname]["functions"].get(fname)
        if info is None:
            return
        sites = {}
        for (idx, path), checks in info["sites"].items():
            if idx in mapping:
                sites[(mapping[idx], path)] = {k: c for k, c in checks.items() if c.kind != "req" or path}
        nparams = max(list(mapping.values()) + [len(args) - 1]) + 1
        self.check_args("Kit.%s.%s (through a local wrapper)" % (modname, fname), sites, ["?"] * nparams, args, pos,
                        call, fid, modname)

    def unresolved_method(self, mname, args, pos, call):
        """A call such as layer.Slot("X") on a receiver that was not traced: a NOTE when the literal
        arguments are refused by every kit handle that has a method of that name."""
        P = self.P
        cands = self.kit.method_index().get(mname)
        if not cands or not args:
            return
        fid = P.fn_at[pos]
        if not any(P.T[P.strip(x, y)[0]] == "str" or P.sym(P.strip(x, y)[0], "{")
                   or self.list_node(x, y, fid) is not None for (x, y) in args):
            return
        failures = []
        for (modname, fn, entry) in cands:
            self._quiet += 1
            saved = getattr(self, "_trial", None)
            self._trial = []
            try:
                self.check_args("%s.%s handle .%s" % (modname, fn, mname), entry["sites"], entry["params"], args, pos,
                                call, fid, modname)
                bad = [t for t in self._trial if t[0] == "ERROR" or t[1] == "suspect"]
            finally:
                self._trial = saved
                self._quiet -= 1
            if not bad or any(not ("unknown key" in t[4] or "not an accepted value" in t[4]) for t in bad):
                return  # accepted, or simply not this kind of object
            failures.append(bad[0])
        level, kind, p_, cl, what, acc, ks = failures[0]
        names = ", ".join(sorted({"%s.%s" % (m_, f_) for (m_, f_, _e) in cands})[:6])
        recv = P.text(call[0], pos - 2, 60)
        self.report("NOTE", "suspect", pos, call,
                    "`%s` could not be traced to a kit component, but every kit handle with a %s method (%s) refuses "
                    "this call: %s" % (recv, mname, names, what.split(": ", 1)[-1]), acc, ks)

    def unresolved_set(self, arg, pos, call, recv=None):
        P = self.P
        keys = [key for (kind, key, _ki, _vs, _ve) in P.parse_table(arg[0]) if kind == "named"]
        if not keys:
            return
        fits, keyfits = [], []
        fid = P.fn_at[pos]
        for modname, m in self.kit.model.items():
            for fn, info in m["functions"].items():
                entry = info["methods"].get("Set")
                if not entry:
                    continue
                if not any(c.kind == "keys" and all(k in c.values for k in keys)
                           for c in entry["sites"].get((0, ()), {}).values()):
                    continue
                keyfits.append("%s.%s" % (modname, fn))
                self._quiet += 1
                saved = getattr(self, "_trial", None)
                self._trial = []
                try:
                    self.check_args("x", entry["sites"], entry["params"], [arg], pos, call, fid, modname)
                    bad = [t for t in self._trial if t[0] == "ERROR"]
                finally:
                    self._trial = saved
                    self._quiet -= 1
                if not bad:
                    fits.append("%s.%s" % (modname, fn))
        recv = recv or P.text(call[0], pos - 1, 60)
        if fits:
            self.report("NOTE", "unchecked", pos, call,
                        "`%s` could not be traced to a kit component, so this Set is not checked (the patch is valid "
                        "for: %s)" % (recv, ", ".join(sorted(set(fits))[:6])))
        elif keyfits:
            self.report("NOTE", "suspect", pos, call,
                        "`%s` could not be traced to a kit component; its keys fit %s but a value in the patch is not "
                        "accepted by any of them" % (recv, ", ".join(sorted(set(keyfits))[:6])))
        else:
            self.report("NOTE", "suspect", pos, call,
                        "`%s` could not be traced to a kit component; no kit component's Set accepts all of: %s"
                        % (recv, ", ".join(keys)))

    # -- argument checks -------------------------------------------------------------------------
    def file_fn(self, a, o_, fid):
        """The function of this file that the callee tokens [a, o_) name, or None."""
        P = self.P
        if o_ - a == 1:
            d, owner = P.find_decl(P.V[a], a, fid)
            if isinstance(d, dict) and d["kind"] == "localfn":
                return d["fn"]
            if isinstance(d, dict) and d["kind"] == "local" and d.get("expr") and P.kw(d["expr"][0], "function"):
                return P.fn_by_tok.get(d["expr"][0])
            return None
        if not all(P.isname(x) if (x - a) % 2 == 0 else P.sym(x, ".") for x in range(a, o_)):
            return None
        name = ".".join(P.V[x] for x in range(a, o_, 2))
        fns = [f for f in P.fns[1:] if f.name == name and (f.path or f.target)]
        return fns[0].fid if len(fns) == 1 else None

    def returned_nodes(self, target, depth):
        """Nodes of every non-nil return of a function of this file; None when one is not understood."""
        P = self.P
        out = []
        ra, rb = P.own_range(target)
        for i in P.own_tokens(target):
            if P.kw(i, "return"):
                e = P.expr_end(i + 1, rb + 1)
                if e <= i + 1 or (e == i + 2 and P.kw(i + 1, "nil")):
                    continue
                nd = self.node(i + 1, e, target, depth + 1)
                if nd[0] == "alts":
                    out += nd[1]
                elif nd[0] == "table":
                    out.append(nd)
                else:
                    return None
        return out

    def node(self, a, b, fid, depth=0):
        """Classify an argument or value expression.
        ("table", open, certain, extra_keys, name) | ("alts", [table nodes]) | ("str", [values], certain) |
        ("type", name) | ("absent",) | ("unknown", reason)"""
        P = self.P
        T, V = P.T, P.V
        a, b = P.strip(a, b)
        if a >= b:
            return ("absent",)
        if depth <= 3 and P.isname(a) and P.sym(b - 1, ")") and b - a > 2:
            o_ = P.mate.get(b - 1)
            if o_ is not None and P.isname(o_ - 1) and P.chain_start(o_ - 1) == a:
                target = self.file_fn(a, o_, fid)
                if target is not None:
                    nodes = self.returned_nodes(target, depth)
                    if nodes:
                        nodes = [("table", n[1], False, n[3] if len(n) > 3 else (),
                                  "the table returned by `%s`" % P.text(a, o_, 50)) for n in nodes]
                        return nodes[0] if len(nodes) == 1 else ("alts", nodes)
        if P.sym(a, "{") and P.mate.get(a) == b - 1:
            return ("table", a, True, ())
        if b - a == 1:
            if T[a] == "str":
                return ("str", [V[a]], True)
            if T[a] == "num":
                return ("type", "number")
            if T[a] == "kw" and V[a] in ("true", "false"):
                return ("type", "boolean", V[a])
            if T[a] == "kw" and V[a] == "nil":
                return ("absent",)
            if T[a] == "name":
                d, owner = P.find_decl(V[a], a, fid)
                if isinstance(d, dict) and d["kind"] == "local" and depth <= 3:
                    # every value the variable is given is a table literal (or a call that returns one)
                    cands = [(d["expr"], d["fid"])] if d.get("expr") is not None else []
                    cands += [(r, f) for (p_, f, r) in P.assigns.get(V[a], ())
                              if r and d["scope"][0] < p_ <= d["scope"][1] and P.find_decl(V[a], p_, f)[0] is d]
                    if len(cands) > 1 or (cands and P.sym(P.strip(*cands[0][0])[1] - 1, ")")):
                        nodes = []
                        for (r, f) in cands:
                            if r[1] - r[0] == 1 and P.kw(r[0], "nil"):
                                continue
                            nd = self.node(r[0], r[1], f, depth + 1)
                            if nd[0] == "alts":
                                nodes += nd[1]
                            elif nd[0] == "table":
                                nodes.append(nd)
                            else:
                                nodes = None
                                break
                        if nodes:
                            nodes = [("table", n[1], False, n[3] if len(n) > 3 else (), n[4] if len(n) > 4 and n[4] else V[a])
                                     for n in nodes]
                            return nodes[0] if len(nodes) == 1 else ("alts", nodes)
                if isinstance(d, dict) and d["kind"] == "local" and d.get("expr") is not None:
                    x, y = P.strip(*d["expr"])
                    others = [p for (p, f, _r) in P.assigns.get(V[a], ()) if d["scope"][0] < p <= d["scope"][1]
                              and P.find_decl(V[a], p, f)[0] is d]
                    if y - x == 1 and T[x] == "str" and not others:
                        return ("str", [V[x]], True)
                    if y - x == 1 and T[x] == "num" and not others:
                        return ("type", "number")
                    if P.sym(x, "{") and P.mate.get(x) == y - 1 and not others:
                        extra = []
                        for tgt, lst in P.assigns.items():
                            parts = tgt.split(".")
                            if len(parts) == 2 and parts[0] == V[a]:
                                for (p, f, _r) in lst:
                                    if d["scope"][0] < p < a and P.find_decl(V[a], p, f)[0] is d:
                                        extra.append((parts[1], p, _r, f))
                        return ("table", x, False, tuple(extra), V[a])
                    return ("unknown", "the value comes from the variable `%s`, which is not one plain literal" % V[a])
                if isinstance(d, tuple):
                    return ("unknown", "the value is the parameter `%s`" % V[a])
                return ("unknown", "the value comes from `%s`" % V[a])
            return ("unknown", "not a literal")
        if P.kw(a, "function") and P.close.get(a) == b - 1:
            return ("type", "function")
        if b - a == 3 and P.isname(a) and P.sym(a + 1, ".") and P.isname(a + 2):
            d, owner = P.find_decl(V[a], a, fid)
            if isinstance(d, dict) and d["kind"] == "for" and d["index"] == d["count"] - 1 and d["count"] == 2 \
                    and d["expr"][1] - d["expr"][0] == 1 and P.isname(d["expr"][0]):
                lname = V[d["expr"][0]]
                d2, _o2 = P.find_decl(lname, d["expr"][0], d["fid"])
                if isinstance(d2, dict) and d2["kind"] == "local" and d2.get("expr") is not None and not P.assigns.get(lname) \
                        and not P.dyn_assign.get(lname):
                    x, y = P.strip(*d2["expr"])
                    if P.isname(x, "table") and P.isname(x + 2, "freeze") and P.sym(x + 3, "("):
                        x, y = P.strip(x + 4, P.mate.get(x + 3, y))
                    if P.sym(x, "{") and P.mate.get(x) == y - 1:
                        vals, ok = [], True
                        for (kind, key, ki, vs, ve) in P.parse_table(x):
                            vs, ve = P.strip(vs, ve)
                            if P.isname(vs, "table") and P.isname(vs + 2, "freeze") and P.sym(vs + 3, "("):
                                vs, ve = P.strip(vs + 4, P.mate.get(vs + 3, ve))
                            if kind != "pos" or not (P.sym(vs, "{") and P.mate.get(vs) == ve - 1):
                                ok = False
                                break
                            for (k2, key2, _ki2, vs2, ve2) in P.parse_table(vs):
                                if k2 == "named" and key2 == V[a + 2]:
                                    if ve2 - vs2 == 1 and T[vs2] == "str":
                                        vals.append(V[vs2])
                                    else:
                                        ok = False
                        if ok and vals:
                            return ("str", sorted(set(vals)), True)
            if isinstance(d, dict) and d["kind"] == "local" and d.get("expr") is not None and d["fid"] == 0 \
                    and not P.assigns.get(V[a]) and not P.assigns.get(V[a] + "." + V[a + 2]):
                x, y = P.strip(*d["expr"])
                if P.isname(x, "table") and P.isname(x + 2, "freeze") and P.sym(x + 3, "("):
                    x, y = P.strip(x + 4, P.mate.get(x + 3, y))
                if P.sym(x, "{") and P.mate.get(x) == y - 1:
                    for (kind, key, ki, vs, ve) in P.parse_table(x):
                        if kind == "named" and key == V[a + 2] and ve - vs == 1 and T[vs] == "str":
                            return ("str", [V[vs]], True)
        # A and "x" or "y"  /  if c then "x" else "y"
        strs = []
        i = a
        plain = True
        while i < b:
            if T[i] == "sym" and V[i] in OPEN and i in P.mate:
                i = P.mate[i] + 1
                continue
            if P.kw(i, "function") and i in P.close:
                i = P.close[i] + 1
                plain = False
                continue
            if T[i] == "str":
                before_ok = i == a or P.kw(i - 1, "and") or P.kw(i - 1, "or") or (P.exprkw[i - 1] and V[i - 1] in ("then", "else"))
                after_ok = i + 1 == b or P.kw(i + 1, "or") or (i + 1 < P.n and P.exprkw[i + 1] and V[i + 1] in ("else", "elseif"))
                if before_ok and after_ok:
                    strs.append(V[i])
                elif not (P.sym(i - 1, "==") or P.sym(i - 1, "~=") or P.sym(i + 1, "==") or P.sym(i + 1, "~=")):
                    plain = False
            i += 1
        if strs and (P.has_top_kw(a, b, ("or",)) or P.is_ifexpr[a]):
            # the last alternative decides whether every branch is a literal
            last_literal = T[b - 1] == "str"
            if last_literal and plain:
                return ("str", strs, False)
            return ("strs?", strs)
        return ("unknown", "the value is computed (`%s`)" % P.text(a, b, 60))

    def list_node(self, a, b, fid, depth=0):
        """("list", [element nodes], described) for a list the file builds itself, else None.
        Accepts: a local `t = {}` filled by table.insert(t, x) / t[i] = x; a call to a local function that
        returns such a list; `c and f() or g()` over those."""
        P = self.P
        T, V = P.T, P.V
        a, b = P.strip(a, b)
        if depth > 3 or a >= b:
            return None
        if P.has_top_kw(a, b, ("and", "or")) and not P.has_top_kw(a, b, ("if", "not")):
            parts = P.top_split(a, b, "or") or [(a, b)]
            elems, names = [], []
            for (x, y) in parts:
                sub = P.top_split(x, y, "and")
                if sub:
                    x, y = sub[-1]
                ln = self.list_node(x, y, fid, depth + 1)
                if ln is None:
                    x2, y2 = P.strip(x, y)
                    if P.sym(x2, "{") and P.mate.get(x2) == y2 - 1 and x2 + 1 == y2 - 1:
                        continue  # an empty list
                    return None
                elems += ln[1]
                names.append(ln[2])
            return ("list", elems, " or ".join(names)) if names else None
        if b - a == 1 and P.isname(a):
            name = V[a]
            d, owner = P.find_decl(name, a, fid)
            if not (isinstance(d, dict) and d["kind"] == "local" and d.get("expr")):
                return None
            x, y = P.strip(*d["expr"])
            if not (P.sym(x, "{") and P.mate.get(x) == y - 1):
                return self.list_node(x, y, d["fid"], depth + 1) if P.sym(y - 1, ")") else None
            if any(d["scope"][0] < p_ <= d["scope"][1] and P.find_decl(name, p_, f_)[0] is d
                   for (p_, f_, _r) in P.assigns.get(name, ())):
                return None
            elems = []
            for (kind, key, ki, vs, ve) in P.parse_table(x):
                if kind != "pos":
                    return None
                elems.append(self.node(vs, ve, d["fid"]))
            lo, hi = d["scope"]
            for i in range(lo, min(hi, P.n)):
                if P.isname(i, "table") and P.sym(i + 1, ".") and P.isname(i + 2, "insert") and P.sym(i + 3, "(") \
                        and P.isname(i + 4, name) and P.sym(i + 5, ",") and P.find_decl(name, i + 4, P.fn_at[i])[0] is d:
                    args = P.expr_list(i + 4, P.mate.get(i + 3, i + 4))
                    if len(args) == 2:
                        elems.append(self.node(args[1][0], args[1][1], P.fn_at[i]))
                    elif len(args) == 3:
                        elems.append(self.node(args[2][0], args[2][1], P.fn_at[i]))
            for (pos2, f2, br) in P.dyn_assign.get(name, ()):
                if lo < pos2 <= hi and P.find_decl(name, pos2, f2)[0] is d and br == pos2 + 1:
                    eq = P.mate.get(br, br) + 1
                    if P.sym(eq, "="):
                        elems.append(self.node(eq + 1, P.expr_end(eq + 1, P.n), f2))
            return ("list", elems, "the list `%s`" % name)
        if P.isname(a) and P.sym(b - 1, ")"):
            o_ = P.mate.get(b - 1)
            if o_ is None or not P.isname(o_ - 1) or P.chain_start(o_ - 1) != a:
                return None
            if o_ - a == 1:
                d, owner = P.find_decl(V[a], a, fid)
                target = None
                if isinstance(d, dict) and d["kind"] == "localfn":
                    target = d["fn"]
                elif isinstance(d, dict) and d["kind"] == "local" and d.get("expr") and P.kw(d["expr"][0], "function"):
                    target = P.fn_by_tok.get(d["expr"][0])
            else:
                name = ".".join(V[x] for x in range(a, o_, 2))
                fns = [f for f in P.fns[1:] if f.name == name and (f.path or f.target)]
                target = fns[0].fid if len(fns) == 1 else None
            if target is None:
                return None
            ret, _w = self.fn_value(target)
            if ret is not None and ret[0] == "pass":
                # the function hands one of its arguments back (after touching the items)
                cargs = P.expr_list(o_ + 1, b - 1)
                if ret[1] < len(cargs):
                    return self.list_node(cargs[ret[1]][0], cargs[ret[1]][1], fid, depth + 1)
                return None
            elems, found = [], False
            ra, rb = P.own_range(target)
            for i in P.own_tokens(target):
                if P.kw(i, "return"):
                    e = P.expr_end(i + 1, rb + 1)
                    if e <= i + 1:
                        continue
                    ln = self.list_node(i + 1, e, target, depth + 1)
                    if ln is None:
                        x2, y2 = P.strip(i + 1, e)
                        if P.sym(x2, "{") and P.mate.get(x2) == y2 - 1 and x2 + 1 == y2 - 1:
                            continue
                        return None
                    elems += ln[1]
                    found = True
            return ("list", elems, "the list returned by `%s`" % P.text(a, o_, 50)) if found else None
        return None

    def check_args(self, label, sites, params, args, pos, call, fid, modname):
        P = self.P
        unknown_reported = set()
        by_arg = {}
        for (idx, path), checks in sites.items():
            by_arg.setdefault(idx, []).append((path, checks))
        for idx, lst in sorted(by_arg.items()):
            pname = params[idx] if idx < len(params) else "arg%d" % (idx + 1)
            if idx < len(args):
                root = self.node(args[idx][0], args[idx][1], fid)
                if root[0] in ("unknown", "table") and any(path and path[0] == "*" for path, _c in lst):
                    ln = self.list_node(args[idx][0], args[idx][1], fid)
                    if ln is not None:
                        root = ln
            else:
                root = ("absent",)
            for path, checks in sorted(lst, key=lambda pc: len(pc[0])):
                for (nd, where, certain) in self.descend(root, path, pname, fid):
                    for c in checks.values():
                        self.apply(label, c, nd, where, certain, pos, call, unknown_reported, modname, idx, path, fid)

    def descend(self, root, path, pname, fid, certain=True):
        """Yield (node, description, certain) for every literal reachable at path under root."""
        P = self.P
        if root[0] == "alts":
            for alt in root[1]:
                yield from self.descend(alt, path, pname, fid, False)
            return
        if not path:
            yield (root, pname, certain)
            return
        if root[0] == "list":
            if path[0] == "*":
                for n, el in enumerate(root[1], 1):
                    yield from self.descend(el, path[1:], "an item of %s" % root[2], fid, False)
            return
        if root[0] != "table":
            if root[0] == "unknown":
                yield (("unknown-parent", root[1]), pname, certain)
            return
        certain = certain and root[2]
        entries = P.parse_table(root[1])
        fid = P.fn_at[root[1]]  # names inside the literal belong to the function that wrote it
        step = path[0]
        if step == "*":
            n = 0
            for (kind, key, ki, vs, ve) in entries:
                if kind == "pos":
                    n += 1
                    yield from self.descend(self.node(vs, ve, fid), path[1:], "%s[%d]" % (pname, n), fid, certain)
            return
        if len(path) > 1 and path[1] == "*":
            for (kind, key, ki, vs, ve) in entries:
                if kind == "named" and key == step:
                    ln = self.list_node(vs, ve, fid)
                    if ln is not None and not self.P.sym(self.P.strip(vs, ve)[0], "{"):
                        yield from self.descend(ln, path[1:], "%s.%s" % (pname, step), fid, False)
                        return
        found = None
        dyn = False
        for (kind, key, ki, vs, ve) in entries:
            if kind == "named" and key == step:
                found = (vs, ve)
            elif kind == "dyn":
                dyn = True
        late = [e for e in root[3] if e[0] == step] if len(root) > 3 else []
        where = "%s.%s" % (pname, step)
        for e in late:
            if len(e) > 3 and e[2]:
                yield from self.descend(self.node(e[2][0], e[2][1], e[3]), path[1:], where, e[3], False)
        if found is None:
            if dyn or late:
                return
            if len(path) == 1:
                yield (("missing", root[1]), where, certain)
            return
        yield from self.descend(self.node(found[0], found[1], fid), path[1:], where, fid, certain)

    def apply(self, label, c, nd, where, certain, pos, call, unknown_reported, modname, idx, path, fid):
        P = self.P
        level = "ERROR" if (c.sev == "error" and certain) else "NOTE"
        kind = {"keys": "prop", "value": "value", "type": "type", "req": "required"}[c.kind] if level == "ERROR" else "suspect"
        soften = {"error": "", "warn": " (the kit warns here and carries on)",
                  "cond": " (the kit reads this value only in some states, so it is not certain to throw)"}[c.sev]
        via = "" if certain else " (built in a variable or a list, so this is not certain)"
        if nd[0] in ("unknown", "unknown-parent"):
            if (c.kind == "keys" or (nd[0] == "unknown-parent" and c.kind == "value"))                     and ("u", pos, idx, where) not in unknown_reported:
                unknown_reported.add(("u", pos, idx, where))
                what = "its keys are" if nd[0] == "unknown" else "what it holds is"
                self.report("NOTE", "unchecked", pos, call,
                            "%s: %s is not a table literal, so %s not checked (%s)" % (label, where, what, nd[1]),
                            None, c.src)
            return
        if c.kind == "keys":
            if nd[0] != "table":
                return
            if ("p", pos, idx, path) not in self._counted and not self._quiet and not path:
                self._counted.add(("p", pos, idx, path))
                self.stats["props_checked"] += 1
            self._checked.add(nd[1])
            tcertain = certain and nd[2]
            lvl = "ERROR" if (c.sev == "error" and tcertain) else "NOTE"
            knd = "prop" if lvl == "ERROR" else "suspect"
            v2 = "" if tcertain else " (built in a variable or a list, so this is not certain)"
            for (ek, key, ki, vs, ve) in P.parse_table(nd[1]):
                if ek == "named" and key not in c.values:
                    self.report(lvl, knd, ki, call, "%s: %s has unknown key %s%s%s" % (label, where, key, soften, v2),
                                c.values, c.src)
                elif ek == "dyn":
                    self.report("NOTE", "unchecked", ki, call,
                                "%s: %s has a computed key (`%s`), which is not checked" % (label, where, P.text(ki, vs - 1, 50)),
                                c.values, c.src)
            for e in (nd[3] if len(nd) > 3 else ()):
                key, p2 = e[0], e[1]
                if key not in c.values:
                    self.report("NOTE", "suspect", p2, (p2 - 2, P.expr_end(p2 + 2, P.n)),
                                "%s: key %s is added to the props variable `%s` and is not accepted%s"
                                % (label, key, nd[4], soften), c.values, c.src)
            return
        if c.kind == "value":
            if nd[0] == "str":
                sure = certain and nd[2]
                for s in nd[1]:
                    if s == "" or s in c.values:
                        continue
                    lvl = "ERROR" if (c.sev == "error" and certain) else "NOTE"
                    extra = "" if nd[2] else " (one branch of a conditional value)"
                    self.report(lvl, "value" if lvl == "ERROR" else "suspect", pos, call,
                                "%s: %s = \"%s\" is not an accepted value%s%s%s" % (label, where, s, extra, soften, via),
                                c.values, c.src)
            elif nd[0] == "strs?":
                for s in nd[1]:
                    if s != "" and s not in c.values:
                        self.report("NOTE", "suspect", pos, call,
                                    "%s: %s may be \"%s\", which is not an accepted value%s" % (label, where, s, soften),
                                    c.values, c.src)
            return
        if c.kind == "type":
            got = None
            if nd[0] == "str":
                got = "string" if nd[2] else None
            elif nd[0] == "table":
                got = "table"
            elif nd[0] == "type":
                got = nd[1]
                if got == "boolean" and c.allow_false and nd[2] == "false":
                    return
            if got is None:
                return
            if got in c.values:
                return
            if any(v not in ("string", "number", "boolean", "table", "function", "nil") for v in c.values):
                if got in ("table", "function") and not ({"Instance", "Color3", "Vector2", "UDim2", "EnumItem"} & set(c.values)):
                    return
            self.report(level, "type" if level == "ERROR" else "suspect", pos, call,
                        "%s: %s is a %s but the kit requires %s%s%s"
                        % (label, where, got, " or ".join(sorted(c.values)), soften, via), c.values, c.src)
            return
        if c.kind == "req":
            if nd[0] == "missing" or (nd[0] == "absent"):
                self.report(level, "required" if level == "ERROR" else "suspect", pos, call,
                            "%s: %s is required and is not given%s" % (label, where, via), None, c.src)

    # -- driver --------------------------------------------------------------------------------
    def seed_folders(self):
        """Names assigned from an expression that ends in `.Kit` / WaitForChild("Kit") are the kit folder."""
        P = self.P
        marks = {}
        for (i, names, exprs) in P.local_stmts:
            for k, name in enumerate(names):
                if k < len(exprs):
                    a, b = exprs[k]
                    if (P.isname(b - 1, "Kit") and P.sym(b - 2, ".")) or (
                            P.sym(b - 1, ")") and P.T[b - 2] == "str" and P.V[b - 2] == "Kit" and P.sym(b - 3, "(")):
                        marks[("d", name, None)] = True
                        for d in P.decls.get(name, ()):
                            if d["kind"] == "local" and d.get("at") == i:
                                self._var_memo[("d", name, d["pos"])] = ("kitfolder",)
        for tgt, lst in P.assigns.items():
            for (p, f, rhs) in lst:
                if rhs and ((P.isname(rhs[1] - 1, "Kit") and P.sym(rhs[1] - 2, ".")) or (
                        P.sym(rhs[1] - 1, ")") and P.T[rhs[1] - 2] == "str" and P.V[rhs[1] - 2] == "Kit")):
                    if "." not in tgt and P.find_decl(tgt, p, f)[0] is None:
                        self._var_memo[("g", tgt)] = ("kitfolder",)

    def run(self):
        P = self.P
        self.seed_folders()
        for i in range(P.n):
            if P.T[i] != "name":
                continue
            if P.sym(i - 1, ".") or P.sym(i - 1, ":"):
                continue
            if P.kw(i - 1, "function") or (P.kw(i - 2, "local") and P.kw(i - 1, "function")):
                continue
            enc = P.encl[i]
            if P.sym(i + 1, "=") and enc and enc[0] == "{":
                continue  # a table key
            steps, end = P.parse_chain(i)
            if len(steps) < 2:
                continue
            self.walk(steps, P.fn_at[i], i, end)
        self.sweep()
        return sorted(self.findings.values(), key=lambda f: (f.line, f.level, f.what))

    # Keys whose values the kit enumerates wherever they appear in props. A string under one of these keys in
    # a table that never reached a checked call is compared with every set the kit accepts for that key.
    SWEEP_KEYS = ("Icon", "Role", "Colour", "Variant", "Tier", "MarkKey", "ChipKind", "ChipRightKind")
    SWEEP_ANYWHERE = ("Icon", "MarkKey")

    def sweep(self):
        P = self.P
        union = self.kit.value_union()
        keysets = self.kit.key_sets()
        for o in range(P.n):
            if not (P.sym(o, "{") and o in P.mate) or o in self._checked:
                continue
            entries = P.parse_table(o)
            named = {key for (kind, key, _ki, _vs, _ve) in entries if kind == "named"}
            if not named:
                continue
            shaped = any(named <= ks | {"Key", "Id"} for ks in keysets)   # else a data row, not props
            for (kind, key, ki, vs, ve) in entries:
                if kind != "named" or key not in union or key not in self.SWEEP_KEYS:
                    continue
                if not shaped and key not in self.SWEEP_ANYWHERE:
                    continue
                if not (ve - vs == 1 and P.T[vs] == "str") or P.V[vs] == "" or P.V[vs] in union[key]:
                    continue
                if "://" in P.V[vs]:
                    continue  # an asset id, not a glyph name
                self.report("NOTE", "suspect", ki, (ki, ve),
                            "%s = \"%s\" sits in a table that was not traced into a kit call; no kit component accepts "
                            "that value for %s" % (key, P.V[vs], key), union[key], None)


# =================================================================================================
# Files, report, CLI
# =================================================================================================

def kit_sources(phase2=PHASE2, which="working"):
    """{module: (label, text)}: the working copy under kit/k*/after when there is one, else the assembled
    copy under install/00_kit/after, else the phase1 copy (modules phase2 did not rewrite).
    which="assembled" leaves the working copies out."""
    out = {}
    order = [phase2.parent / "phase1" / "after", phase2 / "install" / "00_kit" / "after"]
    if which == "working":
        order += sorted((phase2 / "kit").glob("k*/after")) if (phase2 / "kit").is_dir() else []
    for folder in order:
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.lua")):
            m = KIT_RE.search(path.name)
            if m:
                out[m.group(1)] = (path.relative_to(phase2.parent).as_posix(), path.read_text(encoding="utf-8"))
    return out


def unit_files(unit, phase2=PHASE2):
    files = {}
    if unit == FIXTURES_UNIT:
        order = [phase2 / "install" / "00_kit" / "after"]
        order += sorted((phase2 / "kit").glob("k*/after")) if (phase2 / "kit").is_dir() else []
        for folder in order:
            if folder.is_dir():
                for path in sorted(folder.glob("*.lua")):
                    if FIXTURE_RE.search(path.name):
                        files[path.name] = path
    else:
        folder = phase2 / "families" / unit / "after"
        if folder.is_dir():
            for path in sorted(folder.glob("*.lua")):
                if not KIT_RE.search(path.name):
                    files[path.name] = path
    return [files[k] for k in sorted(files)]


def check_text(kit, text, family, relpath):
    scr = Screen(kit, text, family, relpath)
    return scr.run(), scr.stats


def run_units(units, phase2=PHASE2, which="working"):
    kit = Kit(kit_sources(phase2, which))
    findings, stats = [], {}
    for unit in units:
        st = {"files": 0, "kit_calls": 0, "props_checked": 0, "set_calls": 0}
        for path in unit_files(unit, phase2):
            rel = path.relative_to(phase2.parent).as_posix()
            fs, s = check_text(kit, path.read_text(encoding="utf-8"), unit, rel)
            findings += fs
            st["files"] += 1
            for k in ("kit_calls", "props_checked", "set_calls"):
                st[k] += s[k]
        stats[unit] = st
    return kit, findings, stats


def counts(findings, units):
    out = {u: {"ERROR": 0, "NOTE": 0, "NOTE_suspect": 0} for u in units}
    for f in findings:
        out[f.family][f.level] += 1
        if f.level == "NOTE" and f.kind == "suspect":
            out[f.family]["NOTE_suspect"] += 1
    return out


def short_file(path):
    name = path.rsplit("/", 1)[-1]
    for prefix in ("ReplicatedStorage.Modules.Game.UIPulse.", "ReplicatedStorage.Modules.Game.", "StarterPlayer.StarterPlayerScripts."):
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def accepted_text(acc, limit=28):
    if acc is None:
        return ""
    if len(acc) <= limit:
        return ", ".join(acc)
    return ", ".join(acc[:limit]) + ", ... (%d in all; full list in the .json)" % len(acc)


def render_md(kit, findings, stats, units, other=None):
    """other: (label, findings of the same units against the other kit copy) or None."""
    c = counts(findings, units)
    L = []
    L.append("# Pulse kit call check")
    L.append("")
    L.append("Written by `py -3 scripts/ui_restyle/phase2/tools/check_kit_calls.py --write`. It is static analysis of the "
             "checked-out sources; nothing here was run in Studio, so a clean row is not a Play confirmation.")
    L.append("")
    L.append("- **ERROR**: the kit source and the call site together make a run-time error certain when that line runs.")
    L.append("- **NOTE, suspect**: a concrete mismatch was found, but one step is not certain (the table is built in a "
             "variable or a list, the receiver was matched by name, or the kit only warns).")
    L.append("- **NOTE, unchecked**: the call could not be checked; the reason is given.")
    L.append("")
    L.append("| Unit | Files | Kit calls | Props literals checked | Set calls checked | ERROR | NOTE suspect | NOTE unchecked |")
    L.append("|---|---|---|---|---|---|---|---|")
    for u in units:
        s = stats[u]
        L.append("| %s | %d | %d | %d | %d | %d | %d | %d |" % (
            u, s["files"], s["kit_calls"], s["props_checked"], s["set_calls"], c[u]["ERROR"], c[u]["NOTE_suspect"],
            c[u]["NOTE"] - c[u]["NOTE_suspect"]))
    L.append("")
    L.append("## What is checked")
    L.append("")
    L.append("Read from the kit source for every exported function, then compared with each call in the screen sources:")
    L.append("")
    L.append("- the member exists on the kit module, and is called with `.` not `:`;")
    L.append("- the keys of a props literal (constructor and `Set`, and nested lists such as `Buttons`, `Tabs`, `Rows`, "
             "the items of `Rail.SetItems` / `List.SetItems`, the props of `PromptStack.Show`);")
    L.append("- literal values of enumerated props and arguments (variants, sizes, roles, colour roles, tiers, icon "
             "names, mark keys, layer names, frames, slot names, presence kinds, asset keys);")
    L.append("- required props and arguments, and literal value types where the kit tests the type;")
    L.append("- the fields and methods read from a component handle;")
    L.append("- keys read from the kit's constant tables (`Tokens.Colour.X`, `Tokens.Space.X`, `Sprites.Icons.Glyphs.X`).")
    L.append("")
    L.append("Not checked: values that are not literals (a value read from data, a function result from another "
             "module), handles kept in tables indexed at run time, and anything the kit does not validate itself.")
    L.append("")
    L.append("## Kit modules read")
    L.append("")
    L.append("| Module | Source | Functions | Components with a key set |")
    L.append("|---|---|---|---|")
    for name, entry in sorted(kit.model.items()):
        comps = [fn for fn, info in entry["functions"].items()
                 if any(ch.kind == "keys" for (i, p), cs in info["sites"].items() if not p for ch in cs.values())]
        L.append("| %s | %s | %d | %s |" % (name, entry["path"], len(entry["functions"]), ", ".join(sorted(comps)) or "-"))
    L.append("")
    L.append("### Not extracted")
    L.append("")
    if kit.unparsed:
        for name, reasons in sorted(kit.unparsed.items()):
            for r in reasons:
                L.append("- Kit.%s: %s" % (name, r))
    else:
        L.append("None. Every exported function that takes `props` has a key set for its constructor and for its Set.")
    L.append("")
    if other is not None:
        label, ofind = other

        def keyset(fs):
            return {(f.family, f.file, f.what): f for f in fs if f.level == "ERROR" or f.kind == "suspect"}
        mine, theirs = keyset(findings), keyset(ofind)
        only = [theirs[k] for k in sorted(theirs) if k not in mine]
        gone = [mine[k] for k in sorted(mine) if k not in theirs]
        L.append("## Against the %s kit copy" % label)
        L.append("")
        L.append("The same units checked against `install/00_kit/after` alone (what the last assembly holds), to catch a "
                 "screen that relies on a kit working copy that has not been assembled yet.")
        L.append("")
        if not only and not gone:
            L.append("No difference: every ERROR and suspect NOTE is the same against both copies.")
        for f in only:
            L.append("- only against the %s copy: %s **%s:%d** %s" % (label, f.level, short_file(f.file), f.line, f.what))
        for f in gone:
            L.append("- only against the working copy: %s **%s:%d** %s" % (f.level, short_file(f.file), f.line, f.what))
        L.append("")
    for u in units:
        fs = [f for f in findings if f.family == u]
        L.append("## %s" % u)
        L.append("")
        errs = [f for f in fs if f.level == "ERROR"]
        sus = [f for f in fs if f.level == "NOTE" and f.kind == "suspect"]
        unc = [f for f in fs if f.level == "NOTE" and f.kind != "suspect"]
        L.append("### ERROR (%d)" % len(errs))
        L.append("")
        if not errs:
            L.append("None.")
            L.append("")
        for f in errs:
            L.append("- **%s:%d** %s" % (short_file(f.file), f.line, f.what))
            L.append("  - call: `%s`" % f.call.replace("`", "'"))
            if f.accepted is not None:
                L.append("  - accepted: %s" % accepted_text(f.accepted))
            if f.kit:
                L.append("  - kit check: %s" % f.kit)
        if errs:
            L.append("")
        L.append("### NOTE, suspect (%d)" % len(sus))
        L.append("")
        if not sus:
            L.append("None.")
            L.append("")
        for f in sus:
            L.append("- **%s:%d** %s" % (short_file(f.file), f.line, f.what))
            L.append("  - call: `%s`" % f.call.replace("`", "'"))
            if f.accepted is not None:
                L.append("  - accepted: %s" % accepted_text(f.accepted))
        if sus:
            L.append("")
        L.append("### NOTE, unchecked (%d)" % len(unc))
        L.append("")
        if not unc:
            L.append("None.")
            L.append("")
        else:
            L.append("| File | Line | Why it was not checked |")
            L.append("|---|---|---|")
            for f in unc:
                L.append("| %s | %d | %s |" % (short_file(f.file), f.line, f.what.replace("|", "\\|")))
            L.append("")
    return "\n".join(L) + "\n"


def known_units(phase2=PHASE2):
    extra = []
    fam = phase2 / "families"
    if fam.is_dir():
        extra = sorted(d.name for d in fam.iterdir() if (d / "after").is_dir() and d.name not in FAMILIES)
    return [u for u in FAMILIES if (fam / u / "after").is_dir()] + extra + [FIXTURES_UNIT]


def main(argv, phase2=PHASE2):
    units, as_json, write, model, which = [], False, False, False, "working"
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--unit" and i + 1 < len(argv):
            units.append(argv[i + 1])
            i += 1
        elif a.startswith("--unit="):
            units.append(a.split("=", 1)[1])
        elif a == "--kit" and i + 1 < len(argv):
            which = argv[i + 1]
            i += 1
        elif a.startswith("--kit="):
            which = a.split("=", 1)[1]
        elif a == "--json":
            as_json = True
        elif a == "--write":
            write = True
        elif a == "--model":
            model = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            print("unknown argument: " + a, file=sys.stderr)
            return 2
        i += 1
    if which not in ("working", "assembled"):
        print("--kit takes working or assembled", file=sys.stderr)
        return 2
    known = known_units(phase2)
    for u in units:
        if u not in known:
            print("unknown unit %s (known: %s)" % (u, ", ".join(known)), file=sys.stderr)
            return 2
    if model:
        kit = Kit(kit_sources(phase2, which))
        print(json.dumps({"model": kit.describe(), "unparsed": kit.unparsed}, indent=1))
        return 0
    if write:
        units, which = known, "working"   # the report is always the whole run
    units = units or known
    kit, findings, stats = run_units(units, phase2, which)
    c = counts(findings, units)
    payload = {
        "tool": "scripts/ui_restyle/phase2/tools/check_kit_calls.py",
        "kit": which,
        "units": units,
        "counts": c,
        "stats": stats,
        "kit_sources": {name: entry["path"] for name, entry in sorted(kit.model.items())},
        "kit_not_extracted": kit.unparsed,
        "findings": [f.as_dict() for f in findings],
    }
    if write:
        _k2, ofind, _s2 = run_units(units, phase2, "assembled")
        payload["assembled_copy_findings"] = [f.as_dict() for f in ofind if f.level == "ERROR" or f.kind == "suspect"]
        out = phase2 / "results"
        out.mkdir(exist_ok=True)
        (out / "kit_call_report.json").write_text(json.dumps(payload, indent=1) + "\n", encoding="utf-8", newline="\n")
        (out / "kit_call_report.md").write_text(render_md(kit, findings, stats, units, ("assembled", ofind)),
                                                encoding="utf-8", newline="\n")
    if as_json:
        print(json.dumps(payload, indent=1))
    else:
        for f in findings:
            if f.level == "ERROR" or f.kind == "suspect":
                print("%s %s %s:%d  %s" % (f.level, f.family, short_file(f.file), f.line, f.what))
                print("      %s" % f.call)
                if f.accepted is not None:
                    print("      accepted: %s" % accepted_text(f.accepted))
        for u in units:
            print("%-13s ERROR %3d   NOTE %3d (suspect %d)   kit calls %d" % (
                u, c[u]["ERROR"], c[u]["NOTE"], c[u]["NOTE_suspect"], stats[u]["kit_calls"]))
        for name, reasons in sorted(kit.unparsed.items()):
            for r in reasons:
                print("not extracted: Kit.%s: %s" % (name, r))
    return 1 if any(f.level == "ERROR" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
