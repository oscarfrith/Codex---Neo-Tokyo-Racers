#!/usr/bin/env python3
"""Static lint for the Pulse Phase 1 after-sources (API.md section 11, CONTRACT E2).

    py -3 lint_phase1.py [--json] [path ...]

With no path it lints <phase1>/after/*.lua. A path may be a folder or a .lua file. Exit code 1 when
there is a finding. Stdlib only; reads text, never Studio.

It is a tokeniser plus pattern scanner (the approach of tools/extract_contracts.py), not a Luau
compiler. Comments and string contents never trigger a code rule. A finding can be accepted on its
line with a trailing comment `-- lint-ok: <rule> <reason>`; accepted findings are still listed.

Not checked here (needs Studio): compile, whole-pixel geometry, pixel literals, yields, globals.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

MAX_CHARS = 150_000
MAX_LOCALS = 180
UIP = "ReplicatedStorage.Modules.Game.UIPulse."
LATCH = "ReplicatedFirst.UIStyleSwitch"
KIT_NAMES = ("Tokens", "Contracts", "Perf", "Metrics", "Layers", "Text", "Surface", "Input",
             "Controls", "Collections", "Overlay")
ANY_KIT = {"Kit." + name for name in KIT_NAMES}
CORE_ALLOWED = {"Core.ConnectionScope", "Core.ConfigReader"}
# API.md section 1. "Dynamic" is a require of a variable (Routes.Resolve, the gallery's fixture loop).
ALLOWED_DEPS = {
    "Switch": set(),
    "Routes": {"Switch", "Dynamic"},
    "Kit.Tokens": set(), "Kit.Contracts": set(), "Kit.Perf": set(),
    "Kit.Metrics": {"Kit.Tokens"},
    "Kit.Layers": {"Kit.Tokens", "Kit.Metrics", "Kit.Contracts", "Switch"},
    "Kit.Text": {"Kit.Tokens", "Kit.Metrics"},
    "Kit.Surface": {"Kit.Tokens", "Kit.Metrics"},
    "Kit.Input": {"Kit.Tokens", "Kit.Metrics", "Kit.Contracts"},
    "Kit.Controls": {"Kit.Tokens", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.Input"},
    "Kit.Collections": {"Kit.Tokens", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.Input"},
    "Kit.Overlay": {"Kit.Tokens", "Kit.Metrics", "Kit.Layers", "Kit.Text", "Kit.Surface", "Kit.Input",
                    "Kit.Controls"},
    "Toasts.ToastClient": {"Kit.Layers", "Kit.Text", "Kit.Overlay", "Routes"} | CORE_ALLOWED,
    "Dev.Gallery": ANY_KIT | CORE_ALLOWED | {"Dynamic", "Fixtures"},
}
FIXTURE_DEPS = set(ANY_KIT)

CLASSIC_MODULES = ("GarageComponents", "RacingUIComponents", "ResponsiveUIFoundation", "UITheme")
BANNED_CLASSES = ("UIStroke", "UICorner", "CanvasGroup")
ALLOW_UICORNER: set = set()                       # API.md 11.5 allows none
ALLOW_UISCALE = {"Kit.Text", "Dev.Gallery"}       # the Text.Label holder and the gallery StageHolder
ALLOW_SCREENGUI = {"Kit.Layers"}
ALLOW_COLOUR = {"Kit.Tokens"}
ALLOW_FONT = {"Kit.Tokens", "Kit.Text"}           # Text.Font builds the faces from the token family
ALLOW_ASSET = {"Kit.Tokens"}
ALLOW_FRAME_SIGNAL = {"Kit.Perf"}
ALLOW_LISTENER = {"Kit.Metrics"}
ALLOW_TRAP = {"Kit.Contracts"}                    # holds the names as data
CLASS_READERS = {"IsA", "FindFirstChildOfClass", "FindFirstChildWhichIsA", "FindFirstAncestorOfClass",
                 "FindFirstAncestorWhichIsA"}
TRAP_NAMES = {
    "DriveHUD", "TouchGui", "DrivingSpeedEffect",
    # RaceLifecyclePresentationClient legacyNames (the kill list)
    "RaceHud", "RaceHud_Phase3", "RaceCheckpointBadge_Phase5D", "RaceQueue_Phase8",
    "RaceSessionControls_Phase8C", "RaceSessionControls_Phase8D", "RaceResults_Phase4",
    "TimeTrialResultCoach", "RaceEntry", "RaceEntryProbe", "TimeTrialPersonalBestBoard",
    # trap descendants
    "GarageRoot", "DealershipRoot", "CustomisationRoot", "CustomizationRoot",
}
LOCKED_BUTTON_NAMES = {"Car", "Race", "Garage"}
STEP_FORBIDDEN = {"FindFirstChild", "WaitForChild", "GetAttribute", "GetDescendants", "GetChildren"}
FRAME_SIGNALS = {"RenderStepped", "Heartbeat", "BindToRenderStep"}
METRICS_LISTENERS = {"ViewportSize", "TopbarInset", "PreferredInput", "PreferredTextSize"}
REQUIRE_NOISE = {"script", "Parent", "game", "GetService", "WaitForChild", "FindFirstChild",
                 "ReplicatedStorage", "ReplicatedFirst", "Modules", "Game", "UIPulse"}

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
EXPR_PREV_SYMS = {"=", "(", ",", "{", "[", "..", "+", "-", "*", "/", "//", "%", "^", "==", "~=", "<", ">",
                  "<=", ">=", "+=", "-=", "*=", "/=", "..=", ":", "::", "->", "|", "&"}


class Tok:
    __slots__ = ("type", "value", "line")

    def __init__(self, kind, value, line):
        self.type, self.value, self.line = kind, value, line

    def __repr__(self):
        return f"{self.type}:{self.value!r}@{self.line}"


def tokenize(src: str):
    """Return (tokens, comments). Token types: name, kw, str, num, sym. Comments are (line, text)."""
    toks, comments = [], []
    pos, line, n = 0, 1, len(src)
    while pos < n:
        m = TOKEN_RE.match(src, pos)
        if not m:
            pos += 1
            continue
        kind, end = m.lastgroup, m.end()
        if kind == "ws":
            pass
        elif kind == "com":
            comments.append((line, src[pos:end]))
        elif kind in ("lcom", "lstr"):
            eq = m.group("lceq") if kind == "lcom" else m.group("lseq")
            close = src.find("]" + eq + "]", end)
            stop = n if close < 0 else close + len(eq) + 2
            body = src[end:close if close >= 0 else n]
            if kind == "lstr":
                toks.append(Tok("str", body.lstrip("\r").removeprefix("\n"), line))
            else:
                comments.append((line, body))
            end = stop
        elif kind in ("dq", "sq", "bt"):
            toks.append(Tok("str", src[pos + 1:end - 1], line))
        elif kind == "num":
            toks.append(Tok("num", src[pos:end], line))
        elif kind == "name":
            value = src[pos:end]
            toks.append(Tok("kw" if value in KEYWORDS else "name", value, line))
        else:
            toks.append(Tok("sym", src[pos:end], line))
        line += src.count("\n", pos, end)
        pos = end
    return toks, comments


def structure(toks):
    """Return (func_of, func_end). func_of[i] is the index of the `function` keyword that owns token i
    (-1 for the main chunk); func_end maps a `function` keyword index to its `end` index."""
    n = len(toks)
    func_of = [-1] * n
    func_end = {}
    stack = []    # [kind, index, has_else]; kind: func, block, if, ifexpr, repeat
    fstack = []

    def drop_ifexprs():
        while stack and stack[-1][0] == "ifexpr":
            stack.pop()

    for i, tok in enumerate(toks):
        func_of[i] = fstack[-1] if fstack else -1
        if tok.type != "kw":
            continue
        v = tok.value
        if v == "function":
            stack.append(["func", i, False])
            fstack.append(i)
        elif v in ("do", "repeat"):
            stack.append(["repeat" if v == "repeat" else "block", i, False])
        elif v == "if":
            prev = toks[i - 1] if i else None
            top = stack[-1] if stack else None
            is_expr = prev is not None and (
                (prev.type == "sym" and prev.value in EXPR_PREV_SYMS)
                or (prev.type == "kw" and prev.value in ("return", "and", "or", "not"))
                or (prev.type == "kw" and prev.value in ("then", "else", "elseif")
                    and top is not None and top[0] == "ifexpr"))
            stack.append(["ifexpr" if is_expr else "if", i, False])
        elif v in ("then", "else", "elseif"):
            while stack and stack[-1][0] == "ifexpr" and stack[-1][2]:
                stack.pop()             # a finished if-expression left on the stack
            if v == "else" and stack and stack[-1][0] == "ifexpr":
                stack[-1][2] = True
        elif v == "until":
            drop_ifexprs()
            if stack and stack[-1][0] == "repeat":
                stack.pop()
        elif v == "end":
            drop_ifexprs()
            if stack:
                kind, idx, _ = stack.pop()
                if kind == "func":
                    func_end[idx] = i
                    if fstack:
                        fstack.pop()
    for idx in fstack:                  # unterminated source: close at the last token
        func_end.setdefault(idx, n - 1)
    return func_of, func_end


def match_paren(toks, open_idx, func_end):
    """Index of the bracket that closes toks[open_idx]; skips whole function bodies."""
    pairs = {"(": ")", "{": "}", "[": "]"}
    depth, i, n = 0, open_idx, len(toks)
    while i < n:
        tok = toks[i]
        if tok.type == "kw" and tok.value == "function" and i in func_end and i != open_idx:
            i = func_end[i] + 1
            continue
        if tok.type == "sym":
            if tok.value in pairs:
                depth += 1
            elif tok.value in (")", "}", "]"):
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    return n - 1


def split_args(toks, open_idx, close_idx, func_end):
    """Top-level argument ranges [(start, end_exclusive)] of a call."""
    args, start, depth, i = [], open_idx + 1, 0, open_idx + 1
    while i < close_idx:
        tok = toks[i]
        if tok.type == "kw" and tok.value == "function" and i in func_end:
            i = func_end[i] + 1
            continue
        if tok.type == "sym":
            if tok.value in "({[":
                depth += 1
            elif tok.value in ")}]":
                depth -= 1
            elif tok.value == "," and depth == 0:
                args.append((start, i))
                start = i + 1
        i += 1
    if start < close_idx:
        args.append((start, close_idx))
    return args


def function_names(toks, func_end):
    """Map a dotted function name to its `function` keyword index, for functions declared in the file."""
    names = {}
    for idx in func_end:
        j = idx + 1
        parts = []
        while j < len(toks) and (toks[j].type == "name" or (toks[j].type == "sym" and toks[j].value in ".:")):
            parts.append(toks[j].value)
            j += 1
        if parts:
            names["".join(parts).replace(":", ".")] = idx
            continue
        # anonymous: `name = function`, `local name = function`, `a.b = function`
        if idx >= 2 and toks[idx - 1].type == "sym" and toks[idx - 1].value == "=":
            k = idx - 2
            parts = []
            while k >= 0 and (toks[k].type == "name" or (toks[k].type == "sym" and toks[k].value == ".")):
                parts.append(toks[k].value)
                k -= 1
            if parts:
                names["".join(reversed(parts))] = idx
    return names


def count_local_names(toks, i):
    """Names declared by the `local` statement at toks[i]."""
    n = len(toks)
    j = i + 1
    if j < n and toks[j].type == "kw" and toks[j].value == "function":
        return 1
    count = 0
    while j < n and toks[j].type == "name":
        count += 1
        last_line = toks[j].line
        j += 1
        if j < n and toks[j].type == "sym" and toks[j].value == ":":       # skip a type annotation
            j += 1
            depth = 0
            while j < n:
                tok = toks[j]
                if tok.type == "sym" and tok.value in ("(", "{", "[", "<"):
                    depth += 1
                elif tok.type == "sym" and tok.value in (")", "}", "]", ">"):
                    depth -= 1
                elif depth <= 0 and tok.type == "sym" and tok.value in (",", "="):
                    break
                elif depth <= 0 and (tok.type == "kw" and tok.value != "nil" or tok.line > last_line):
                    break
                last_line = tok.line
                j += 1
        if j < n and toks[j].type == "sym" and toks[j].value == ",":
            j += 1
            continue
        break
    return count


def locals_per_function(toks, func_of, func_end):
    """Upper bound of local names per function (declared locals, parameters, loop variables)."""
    counts = {}
    n = len(toks)
    for i, tok in enumerate(toks):
        if tok.type != "kw":
            continue
        if tok.value == "local":
            counts[func_of[i]] = counts.get(func_of[i], 0) + count_local_names(toks, i)
        elif tok.value == "function" and i in func_end:
            j = i + 1
            method = False
            while j < n and not (toks[j].type == "sym" and toks[j].value == "("):
                method = method or (toks[j].type == "sym" and toks[j].value == ":")
                j += 1
            close = match_paren(toks, j, func_end) if j < n else j
            params = 1 if method else 0
            for a, b in split_args(toks, j, close, func_end):
                if a < b and toks[a].type == "name":
                    params += 1
            counts[i] = counts.get(i, 0) + params
        elif tok.value == "for":
            j, names = i + 1, 0
            while j < n and not (toks[j].type == "kw" and toks[j].value == "in") \
                    and not (toks[j].type == "sym" and toks[j].value == "="):
                if toks[j].type == "name" and toks[j - 1].value in ("for", ","):
                    names += 1
                j += 1
            counts[func_of[i]] = counts.get(func_of[i], 0) + names + 3
    return counts


def module_id(instance_path: str):
    """Short id used by the rule tables, or None for a source that is not a Pulse module."""
    if instance_path == LATCH:
        return "Switch"
    if instance_path.startswith(UIP):
        return instance_path[len(UIP):]
    return None


def local_initialisers(toks):
    """[(token index, name, initialiser tokens)] for each `local name = <expr>` (one name, to the line end)."""
    out = []
    n = len(toks)
    for i, tok in enumerate(toks):
        if tok.type == "kw" and tok.value == "local" and i + 2 < n and toks[i + 1].type == "name" \
                and toks[i + 2].type == "sym" and toks[i + 2].value == "=":
            j, depth = i + 3, 0
            while j < n:
                t = toks[j]
                if depth <= 0 and j > i + 3 and t.line > toks[j - 1].line:
                    break
                if t.type == "sym" and t.value in ("(", "{", "["):
                    depth += 1
                elif t.type == "sym" and t.value in (")", "}", "]"):
                    depth -= 1
                j += 1
            out.append((i, toks[i + 1].value, toks[i + 3:j]))
    return out


def expand_words(arg, before, inits, depth=0):
    """Names and strings of an expression, with local variables replaced by what they were set to."""
    words = []
    for k, t in enumerate(arg):
        if t.type == "str":
            words.append(t.value)
        elif t.type == "name":
            member = k > 0 and arg[k - 1].type == "sym" and arg[k - 1].value in (".", ":")
            source = None
            if not member and depth < 4 and t.value not in REQUIRE_NOISE:
                for idx, name, init in inits:
                    if name == t.value and idx < before:
                        source = (idx, init)
            if source:
                words.extend(expand_words(source[1], source[0], inits, depth + 1))
            else:
                words.append(t.value)
    return words


def classify_require(arg, before=0, inits=()):
    """Dependency id for the argument tokens of one require call."""
    words = expand_words(arg, before, inits)
    if len(arg) == 1 and arg[0].type == "name" and words == [arg[0].value]:
        return "Dynamic"
    rest = [w for w in words if w not in REQUIRE_NOISE]
    if not rest:
        return "Dynamic"
    last = rest[-1]
    if last == "UIStyleSwitch":
        return "Switch"
    if "Core" in rest:
        return "Core." + last
    if "Fixtures" in rest:
        return "Fixtures"
    if last in KIT_NAMES:
        return "Kit." + last
    if last == "Routes":
        return "Routes"
    return "Unknown:" + ".".join(rest)


class Finding:
    def __init__(self, file, line, rule, message, accepted=False):
        self.file, self.line, self.rule, self.message, self.accepted = file, line, rule, message, accepted

    def as_dict(self):
        return {"file": self.file, "line": self.line, "rule": self.rule, "message": self.message,
                "accepted": self.accepted}

    def __str__(self):
        mark = " (accepted)" if self.accepted else ""
        return f"{self.file}:{self.line}: [{self.rule}] {self.message}{mark}"


def lint_source(file_name: str, text: str, raw: bytes | None = None):
    """Lint one source. file_name is `<full instance path>.lua`. Returns a list of Finding."""
    path = file_name[:-4] if file_name.endswith(".lua") else file_name
    mod = module_id(path)
    found = []

    def add(line, rule, message):
        found.append(Finding(file_name, line, rule, message))

    if len(text) > MAX_CHARS:
        add(1, "size", f"{len(text)} characters; the limit is {MAX_CHARS}")
    if b"\r" in (raw if raw is not None else text.encode("utf-8")):
        add(1, "line-ends", "contains CR; sources are LF only")
    if mod is None:
        return found      # ClientBase and other non-Pulse sources: size and line ends only

    toks, comments = tokenize(text)
    func_of, func_end = structure(toks)
    n = len(toks)

    def val(i):
        return toks[i].value if 0 <= i < n else None

    def is_sym(i, value):
        return 0 <= i < n and toks[i].type == "sym" and toks[i].value == value

    # -- header ---------------------------------------------------------------------------------
    lines = text.split("\n")
    if not lines[0].startswith("-- Owns "):
        add(1, "header", "line 1 must start with `-- Owns `")
    want = f"-- Pulse UI (phase1). {path}. Requires: "
    if len(lines) < 2 or not lines[1].startswith(want) or not lines[1][len(want):].strip():
        add(2, "header", f"line 2 must be `{want}<names or none>.`")
    for line, body in comments:
        if body.startswith("--!nocheck"):
            add(line, "nocheck", "--!nocheck is not allowed")
    if mod not in ALLOWED_DEPS and not mod.startswith("Dev.Fixtures."):
        add(1, "unknown-module", f"{mod} has no row in API.md section 1")

    # -- requires and dependency edges ------------------------------------------------------------
    allowed = FIXTURE_DEPS if mod.startswith("Dev.Fixtures.") else ALLOWED_DEPS.get(mod, set())
    inits = local_initialisers(toks)
    for i, tok in enumerate(toks):
        if tok.type == "name" and tok.value == "require" and is_sym(i + 1, "(") \
                and not (is_sym(i - 1, ".") or is_sym(i - 1, ":")):
            close = match_paren(toks, i + 1, func_end)
            arg = toks[i + 2:close]
            dep = classify_require(arg, i, inits)
            shown = "".join(t.value if t.type != "str" else repr(t.value) for t in arg)
            if dep.startswith("Unknown:"):
                add(tok.line, "dependency", f"require({shown}) is not a module API.md section 1 lists")
            elif dep.startswith("Core.") and dep not in CORE_ALLOWED:
                add(tok.line, "core-require", f"{dep} may not be required by Pulse (only ConnectionScope, ConfigReader)")
            elif dep not in allowed:
                add(tok.line, "dependency", f"{mod} may not require {dep} (API.md section 1)")
            elif mod.startswith("Kit.") and dep.startswith("Kit.") \
                    and [t.value for t in arg] != ["script", ".", "Parent", ".", dep[4:]]:
                add(tok.line, "require-form", f"Kit modules use require(script.Parent.{dep[4:]}), found require({shown})")

    # -- token rules ------------------------------------------------------------------------------
    last_str = None     # (index, value) of the previous string token
    for i, tok in enumerate(toks):
        t, v = tok.type, tok.value
        if t == "str":
            reader = (is_sym(i - 1, "(") and val(i - 2) in CLASS_READERS) or val(i - 1) in ("==", "~=")
            if "Modules.Game.UI." in v or re.search(r"ReplicatedStorage\.Modules\.Game\.(?!UIPulse\b)", v):
                add(tok.line, "classic-path", f"string names a Classic path: {v!r}")
            if v == "UI" and last_str and last_str[1] == "Game" and i - last_str[0] <= 8:
                add(tok.line, "classic-path", "walks to Modules.Game.UI")
            for name in CLASSIC_MODULES:
                if re.search(rf"\b{name}\b", v):
                    add(tok.line, "classic-require", f"names the Classic module {name}")
            if v == "ScreenGui" and not reader and mod not in ALLOW_SCREENGUI:
                add(tok.line, "screengui-new", "only Kit.Layers creates a ScreenGui")
            if v in BANNED_CLASSES and not reader and not (v == "UICorner" and mod in ALLOW_UICORNER):
                add(tok.line, "banned-class", f"{v} is not used in Pulse")
            if v == "UIScale" and not reader and mod not in ALLOW_UISCALE:
                add(tok.line, "uiscale", "UIScale only in the Text.Label holder and the gallery StageHolder")
            if v == "TextScaled":
                add(tok.line, "textscaled", "TextScaled is not used")
            if v in TRAP_NAMES and mod not in ALLOW_TRAP:
                add(tok.line, "trap-name", f"trap name {v!r}")
            if v in LOCKED_BUTTON_NAMES and is_sym(i - 1, "=") and val(i - 2) == "Name" and mod != "Kit.Contracts":
                add(tok.line, "locked-name", f"an instance named {v!r} needs Input.Mark, not a typed name")
            if ("rbxassetid://" in v or "rbxasset://" in v or "roblox.com/asset" in v) and mod not in ALLOW_ASSET:
                add(tok.line, "asset-literal", "asset id outside Kit.Tokens")
            if v in FRAME_SIGNALS and mod not in ALLOW_FRAME_SIGNAL:
                add(tok.line, "frame-signal", f"{v} outside Kit.Perf")
            if v in METRICS_LISTENERS and not reader and mod not in ALLOW_LISTENER:
                add(tok.line, "metrics-listener", f"only Kit.Metrics listens to {v}")
            last_str = (i, v)
            continue
        if t != "name":
            continue
        if v in CLASSIC_MODULES:
            add(tok.line, "classic-require", f"names the Classic module {v}")
        if v == "UI" and is_sym(i - 1, ".") and val(i - 2) == "Game" and is_sym(i - 3, ".") and val(i - 4) == "Modules":
            add(tok.line, "classic-path", "walks to Modules.Game.UI")
        if v == "TextScaled":
            add(tok.line, "textscaled", "TextScaled is not used")
        if v in FRAME_SIGNALS and mod not in ALLOW_FRAME_SIGNAL:
            add(tok.line, "frame-signal", f"{v} outside Kit.Perf")
        if v == "Enabled" and is_sym(i - 1, ".") and is_sym(i + 1, "=") and mod != "Kit.Perf" and val(i - 2) != "Perf":
            add(tok.line, "screengui-enabled", "write to .Enabled; layers show and hide through Root.Visible")
        if v == "Color3" and is_sym(i + 1, ".") and mod not in ALLOW_COLOUR:
            maker = val(i + 2)
            if maker in ("fromRGB", "fromHex", "fromHSV"):
                add(tok.line, "colour-literal", f"Color3.{maker} outside Kit.Tokens")
            elif maker == "new" and is_sym(i + 3, "("):
                close = match_paren(toks, i + 3, func_end)
                inner = toks[i + 4:close]
                if any(not ((x.type == "num" and x.value in ("0", "1")) or (x.type == "sym" and x.value == ","))
                       for x in inner):
                    add(tok.line, "colour-literal", "Color3.new with values other than 0 and 1 outside Kit.Tokens")
        if mod not in ALLOW_FONT:
            if v == "Font" and is_sym(i + 1, ".") and val(i + 2) in ("new", "fromEnum", "fromName", "fromId"):
                add(tok.line, "font-literal", "Font built outside Kit.Tokens and Kit.Text; use Text.Font(role)")
            if v == "Font" and is_sym(i - 1, ".") and val(i - 2) == "Enum" and is_sym(i + 1, "."):
                add(tok.line, "font-literal", "Enum.Font outside Kit.Tokens and Kit.Text")
        if v == "Create" and is_sym(i - 1, ":") and is_sym(i + 1, "("):
            close = match_paren(toks, i + 1, func_end)
            for k in range(i + 2, close):
                if toks[k].type == "name" and toks[k].value in ("TextSize", "Scale") and is_sym(k + 1, "="):
                    add(toks[k].line, "tween-size", f"tween of {toks[k].value}")
        if v == "warn" and is_sym(i + 1, "(") and not is_sym(i - 1, ".") and i + 2 < n and toks[i + 2].type == "str" \
                and not toks[i + 2].value.startswith("[Pulse."):
            add(tok.line, "warn-prefix", "warnings start with [Pulse.<Module>]")

    # -- Perf.Bind steps --------------------------------------------------------------------------
    names = function_names(toks, func_end)

    def scan_step(start, seen, origin_line):
        if start in seen:
            return
        seen.add(start)
        for k in range(start + 1, func_end[start]):
            tk = toks[k]
            if tk.type != "name":
                continue
            if tk.value in STEP_FORBIDDEN and (is_sym(k - 1, ".") or is_sym(k - 1, ":")):
                add(tk.line, "perf-step", f"{tk.value} inside a Perf.Bind step (bound at line {origin_line})")
            elif tk.value == "Instance" and is_sym(k + 1, ".") and val(k + 2) == "new":
                add(tk.line, "perf-step", f"Instance.new inside a Perf.Bind step (bound at line {origin_line})")
            elif not is_sym(k - 1, ".") and not is_sym(k - 1, ":"):
                parts, j = [tk.value], k + 1          # a call of a function declared in this file
                while (is_sym(j, ".") or is_sym(j, ":")) and j + 1 < n and toks[j + 1].type == "name":
                    parts.append(toks[j + 1].value)
                    j += 2
                target = names.get(".".join(parts))
                if target is not None and is_sym(j, "("):
                    scan_step(target, seen, origin_line)

    for i, tok in enumerate(toks):
        if tok.type == "name" and tok.value == "Bind" and is_sym(i - 1, ".") and val(i - 2) == "Perf" \
                and is_sym(i + 1, "(") and val(i - 3) != "function":      # a call, not the definition
            close = match_paren(toks, i + 1, func_end)
            args = split_args(toks, i + 1, close, func_end)
            if len(args) < 3:
                add(tok.line, "perf-step", "Perf.Bind needs (name, layerRoot, step)")
                continue
            a, b = args[2]
            if toks[a].type == "kw" and toks[a].value == "function" and a in func_end:
                scan_step(a, set(), tok.line)
            else:
                target = names.get("".join(t.value for t in toks[a:b]))
                if target is None:
                    add(tok.line, "perf-step", "cannot find the step function in this file; pass a function declared here")
                else:
                    scan_step(target, set(), tok.line)

    # -- locals per function ----------------------------------------------------------------------
    for owner, count in sorted(locals_per_function(toks, func_of, func_end).items()):
        if count > MAX_LOCALS:
            line = toks[owner].line if owner >= 0 else 1
            where = "the main chunk" if owner < 0 else "one function"
            add(line, "locals", f"about {count} locals in {where}; keep under {MAX_LOCALS} (Luau stops at 200)")

    # -- accepted findings ------------------------------------------------------------------------
    accepted = {}
    for line, body in comments:
        m = re.search(r"lint-ok:\s*([a-z-]+)", body)
        if m:
            accepted.setdefault(line, set()).add(m.group(1))
    for finding in found:
        if finding.rule in accepted.get(finding.line, ()):
            finding.accepted = True
    return found


def lint_paths(paths):
    found = []
    files = []
    for p in paths:
        p = Path(p)
        files.extend(sorted(p.glob("*.lua")) if p.is_dir() else [p])
    for f in files:
        raw = f.read_bytes()
        found.extend(lint_source(f.name, raw.decode("utf-8", errors="replace"), raw))
    return files, found


def default_after():
    here = Path(__file__).resolve()
    for parent in here.parents:
        if parent.name == "phase1":
            return parent / "after"
    return here.parent / "after"


def main(argv):
    as_json = "--json" in argv
    paths = [a for a in argv if not a.startswith("--")] or [default_after()]
    files, found = lint_paths(paths)
    open_findings = [f for f in found if not f.accepted]
    if as_json:
        print(json.dumps({"files": len(files), "findings": [f.as_dict() for f in found],
                          "open": len(open_findings)}, indent=1))
    else:
        for f in found:
            print(f)
        print(f"{len(files)} files, {len(open_findings)} findings, {len(found) - len(open_findings)} accepted")
    return 1 if open_findings or not files else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
