#!/usr/bin/env python3
"""Static lint for the Pulse wave-2 sources: the Phase 1 rules (phase1/lint_phase1.py, API1 section 11) extended
with API2 6.6 (coding rules) and 6.7 (hard safety rules).

    py -3 lint_phase2.py [unit ...] [--json] [--accept file] [--show-exempt]      (--show-exempt lists kept fork lines)
    py -3 lint_phase2.py --path <folder or file> [...]      lint loose files as one unit named "path"

unit is kit or a family folder name; with none, every unit that has files is linted. Output is grouped by unit.
Exit code 1 when there is an open finding (or nothing to lint); 0 otherwise.

Accepting a reviewed exception: --accept <file> (default integrator/lint_accept.json when it exists):
    {"accept": [{"file": "<file name or glob>", "rule": "<rule>", "line": 12, "contains": "text of the message",
                 "reason": "why it is right", "reviewer": "who read it"}]}
file and rule are required, reason is required, line and contains narrow the match. Accepted findings are still
listed. An inline `-- lint-ok: <rule> <reason>` comment (the Phase 1 mechanism) is honoured for style rules only:
a safety rule (SAFETY_RULES below) can be accepted through the accept file alone, so an agent cannot wave one through.

It is a tokeniser plus pattern scanner, not a Luau compiler. Not checked here: compile, yields, whole-pixel
geometry, pixel literals, retries, busy guards, connection hygiene (rule 9). Those are the Edit harness, the
parity check and the reviewer. Stdlib only; reads text, never Studio.
"""
from __future__ import annotations

import fnmatch
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402

sys.path.insert(0, common.PHASE1)
import lint_phase1 as base  # noqa: E402

UIP = common.UIP_DOT
NEW_KIT = ("Sprites", "Presence", "BigNumber", "Data", "Gauge", "Minimap", "Touch")
KIT_NAMES = tuple(base.KIT_NAMES) + tuple(n for n in NEW_KIT if n not in base.KIT_NAMES)
ANY_KIT = {"Kit." + name for name in KIT_NAMES}
CORE_KIT = {"Core.ConnectionScope", "Core.ConfigReader"}
# API2 2.1. Kit.Layers keeps the latch (API1 section 8: Layers.Switch); "Dynamic" is a require of a variable.
KIT_DEPS = {
    "Switch": set(),
    "Routes": {"Switch", "Dynamic"},
    "NoOp": set(),
    "Kit.Sprites": set(), "Kit.Contracts": set(), "Kit.Perf": set(), "Kit.Presence": set(),
    "Kit.Tokens": {"Kit.Sprites"},
    "Kit.Metrics": {"Kit.Tokens"},
    "Kit.Layers": {"Kit.Tokens", "Kit.Metrics", "Kit.Contracts", "Switch"},
    "Kit.Text": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics"},
    "Kit.Surface": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics"},
    "Kit.Input": {"Kit.Tokens", "Kit.Metrics", "Kit.Contracts"},
    "Kit.BigNumber": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics"},
    "Kit.Controls": {"Kit.Tokens", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.Input"},
    "Kit.Collections": {"Kit.Tokens", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.Input"},
    "Kit.Data": {"Kit.Tokens", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.Input", "Kit.Controls",
                 "Kit.Collections", "Kit.BigNumber", "Shared:ResponsiveUIFoundation"},
    "Kit.Gauge": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.BigNumber", "Kit.Perf"},
    "Kit.Minimap": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics", "Kit.Text", "Kit.Surface", "Kit.BigNumber", "Kit.Perf"},
    "Kit.Touch": {"Kit.Tokens", "Kit.Sprites", "Kit.Metrics", "Kit.Surface"},
    "Kit.Overlay": ANY_KIT - {"Kit.Gauge", "Kit.Minimap", "Kit.Touch", "Kit.Overlay"},
    "Toasts.ToastClient": {"Kit.Layers", "Kit.Text", "Kit.Overlay", "Routes"} | CORE_KIT,
    "Dev.Gallery": ANY_KIT | CORE_KIT | {"Dynamic", "Fixtures"},
}
# API2 6.6 rule 1: the shared, look-free Classic modules a family may require. Core.* is handled apart.
SHARED = {"GarageCatalogClient", "GarageModuleCardViewModel", "RaceConfigReader", "RouteGuide", "MapMarkers",
          "MapMath", "MapTileSet", "FreeRoamMapPlayerMarkers", "GameplayInputGate", "MobileDriveInputState",
          "PresentationAudioBridge", "OnboardingGuideTrailRenderer",
          # "the preview and camera modules" (read as: the non-entry preview/camera modules of the garage)
          "PreviewCameraClient", "PreviewVehicleClient", "GarageModuleInstancePreviewAdapter",
          "GarageVehiclePreviewProfile", "VehiclePreviewVFXClient"}
# FreeRoam.ActivityHudClient hosts the five shared activity views exactly as ActivityClient does (API2 section 4).
ACTIVITY_VIEWS = {"JobClient", "TaxiClientView", "PassengerClientView", "CourierClientView", "DuelClientView"}
NEVER = {"GarageComponents", "RacingUIComponents", "UITheme", "MapIconLayer", "ResponsiveUIFoundation"}
FORK_KEEPS_REQUIRE = {"RaceSession.RouteGuideClient"}
# API2 1.1, "Used by": the modules that may name an asset key (Tokens and Sprites always may).
ASSET_USERS = {
    "IconSheet": {"Kit.Surface", "Kit.Controls", "Kit.Collections", "Kit.Overlay", "Kit.Data"}, "MapIconSheet": {"Kit.Surface"},
    "GlowSoft": {"Kit.Surface"}, "GlowTight": {"Kit.Surface"}, "GlowLine": {"Kit.Surface"},
    "Digits256": {"Kit.BigNumber"}, "Digits128": {"Kit.BigNumber"}, "DigitsPunct": {"Kit.BigNumber"},
    "GaugeTrack": {"Kit.Gauge"}, "GaugeTicks": {"Kit.Gauge"}, "GaugeGlow": {"Kit.Gauge"}, "GaugeArc": {"Kit.Gauge"},
    "BoostArc": {"Kit.Gauge"},
    "MinimapRing": {"Kit.Minimap"}, "MinimapVignette": {"Kit.Minimap"}, "MapPlayerArrow": {"Kit.Minimap"},
    "RankArc": {"Kit.Minimap", "Kit.Touch"}, "SegmentStrip": {"Kit.Data"},
    "TitleSlash": {"Kit.Surface", "Kit.Controls", "Kit.Overlay"},
    "ChequerCorner": {"World.*", "WorldMap.*"}, "KeyCap": {"Kit.Surface", "Kit.Overlay"},
}
for _control in ("Accelerate", "Brake", "Turn", "Drift", "Boost"):
    ASSET_USERS["Touch" + _control] = {"Kit.Touch"}
    ASSET_USERS["Touch" + _control + "Pressed"] = {"Kit.Touch"}
REMOVED_ASSETS = {"GaugeRing", "MinimapRankRing", "TouchControls", "TouchControls2", "TitleMark"}
GUI_CLASSES = {"ScreenGui", "BillboardGui", "SurfaceGui", "Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel",
               "ImageButton", "ScrollingFrame", "ViewportFrame", "CanvasGroup", "VideoFrame", "UIListLayout",
               "UIGridLayout", "UIPadding", "UIScale", "UICorner", "UIStroke", "UIGradient", "UIAspectRatioConstraint",
               "UISizeConstraint", "UIFlexItem"}
BANNED_SERVICES = {"DataStoreService", "MarketplaceService", "MemoryStoreService", "MessagingService"}
BANNED_CALLS = {"GetDataStore", "GetOrderedDataStore", "GetGlobalDataStore", "PromptProductPurchase", "PromptPurchase",
                "PromptGamePassPurchase", "PromptPremiumPurchase", "PromptSubscriptionPurchase"}
REMOTE_CLASSES = {"RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent"}
BINDABLE_CLASSES = {"BindableEvent", "BindableFunction"}
PRESENCE_READS = {"FindFirstChild", "WaitForChild", "FindFirstChildOfClass", "FindFirstChildWhichIsA", "GetAttribute",
                  "GetChildren", "GetDescendants", "FindFirstAncestor"}
WRAPPER_NAMES = {"call"}                                # API2 6.2: one call(remote, action, payload) function
KEPT_EXEMPT = {"banned-class", "uiscale", "textscaled", "tween-size", "colour-literal", "font-literal",
               "asset-literal", "screengui-enabled"}  # API2 6.6 rule 4: rules 5 and 6 (9 is not linted) + Enabled
# A kept fork line is Classic text, byte for byte (build_forks.py checks the Classic hash). Rules outside rule 4's
# list still fire there (a kept RenderStepped, a kept warn without the Pulse prefix, a header that is Classic's
# line 1): they are listed as "kept" for the reviewer and do not fail the unit. What a kept line may NOT do is
# require Classic (only RaceSession.RouteGuideClient keeps its require), so these stay open:
KEPT_STILL_OPEN = {"dependency", "classic-require", "classic-path", "cross-entry-require", "size", "line-ends", "locals"}
SAFETY_RULES = {"remote-new", "remote-action", "remote-action-owner", "remote-action-server-only", "remote-payload-key", "remote-dynamic-action",
                "remote-outside-model", "remote-name", "bindable-new", "bindable-name", "banned-service",
                "classic-require", "classic-path", "cross-entry-require", "screengui-enabled", "screengui-new",
                "trap-name", "view-side-effect", "dependency"}
REDONE = {"header", "unknown-module", "dependency", "core-require", "classic-path", "classic-require", "trap-name",
          "asset-literal"}
ASSET_LITERAL = re.compile(r"rbx(assetid|thumb)://\w|rbxasset://\w|roblox\.com/asset/?\?id=\d")

Finding = base.Finding


def configure_base():
    """Points the Phase 1 scanner at the wave-2 tables. This process owns the imported module."""
    base.KIT_NAMES = KIT_NAMES
    base.ANY_KIT = ANY_KIT
    base.ALLOWED_DEPS = {key: {dep for dep in deps if not dep.startswith("Shared:")} for key, deps in KIT_DEPS.items()}
    base.FIXTURE_DEPS = set(ANY_KIT)
    base.ALLOW_UICORNER = {"Kit.Minimap"}
    base.ALLOW_UISCALE = {"Kit.Text", "Dev.Gallery", "FreeRoam.ActivityHudClient"}
    base.ALLOW_COLOUR = {"Kit.Tokens", "Kit.Sprites"}
    base.ALLOW_FONT = {"Kit.Tokens", "Kit.Text", "Kit.Sprites"}
    base.ALLOW_ASSET = {"Kit.Tokens", "Kit.Sprites"}
    base.module_id = module_id


def module_id(instance_path):
    """Short id for the rule tables; None for an edited Classic script (size and line ends only)."""
    if instance_path == common.LATCH_PATH:
        return "Switch"
    if instance_path.startswith(UIP):
        return instance_path[len(UIP):]
    if instance_path in common.classic_manifest() or instance_path == common.CLIENTBASE_PATH:
        return None
    return instance_path


configure_base()

_CACHE = {}


def classic_facts():
    """Facts read once from classic/contracts: every remote action and payload key, remote path names, bindable
    names, the Classic script names, the ClientBase entry names and which contract file belongs to which script."""
    if "facts" in _CACHE:
        return _CACHE["facts"]
    facts = {"actions": {}, "remote_words": set(), "bindable_words": set(), "contract_of": {}, "by_file": {},
             "server_actions": set(), "remote_names": set()}
    remotes = common.read_json(os.path.join(common.CONTRACTS, "_remotes.json"))["remotes"]
    for key, row in remotes.items():
        for word in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", key + " " + str(row.get("name", ""))):
            facts["remote_words"].add(word)
        facts["remote_names"].update(part.strip().split(".")[-1] for part in re.split(r"[|:]", key) if "." in part)
        if isinstance(row.get("name"), str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", row["name"]):
            facts["remote_names"].add(row["name"])
        for spec in row.get("server_specs") or []:
            facts["server_actions"].update(spec.get("actions") or [])
        for action, detail in (row.get("actions") or {}).items():
            action = None if action == "<no action argument>" else action
            keys = facts["actions"].setdefault(action, {"keys": set(), "known": False})
            if detail.get("payload_keys") is not None:
                keys["known"] = True
                keys["keys"].update(detail["payload_keys"])
            for caller in detail.get("callers") or []:
                if caller.get("payload_keys") is not None:
                    keys["known"] = True
                    keys["keys"].update(caller["payload_keys"])
    for name in sorted(os.listdir(common.CONTRACTS)):
        if not name.endswith(".json") or name.startswith("_"):
            continue
        contract = common.read_json(os.path.join(common.CONTRACTS, name))
        facts["by_file"][name[:-5]] = contract
        facts["contract_of"][contract["script"]] = contract
        bindables = contract.get("bindables", {})
        for group in ("fires", "connects", "invokes", "handlers"):
            for item in bindables.get(group, []):
                if isinstance(item.get("name"), str):
                    facts["bindable_words"].add(item["name"])
                if isinstance(item.get("lookup"), str):
                    facts["bindable_words"].update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", item["lookup"]))
        for item in bindables.get("created", []):
            if isinstance(item.get("Name"), str):
                facts["bindable_words"].add(item["Name"])
        for item in contract.get("names", {}).get("assigned", []):
            if item.get("class") in BINDABLE_CLASSES and isinstance(item.get("name"), str):
                facts["bindable_words"].add(item["name"])
    facts["classic_names"] = {}
    for path in common.classic_manifest():
        facts["classic_names"].setdefault(path.split(".")[-1], []).append(path)
    facts["entries"] = {entry["name"]: entry["path"] for entry in common.clientbase_entries()}
    _CACHE["facts"] = facts
    return facts


def classic_contract(name_or_path):
    """Contract of a Classic owner given a ClientBase entry name, a script name or a full script path."""
    facts = classic_facts()
    if name_or_path in facts["contract_of"]:
        return facts["contract_of"][name_or_path]
    path = facts["entries"].get(name_or_path)
    if path in facts["contract_of"]:
        return facts["contract_of"][path]
    return facts["by_file"].get(name_or_path) or facts["by_file"].get(str(name_or_path).split(".")[-1])


def remote_scope(owner_names):
    """Actions and payload keys of the given Classic owners and of the Classic modules they require (transitive,
    client UI modules only). -> {"actions": {action or None: {"keys": set, "known": bool}}, "owners": [script]}."""
    facts = classic_facts()
    scope = {"actions": {}, "owners": [], "unknown": []}
    seen, queue = set(), list(owner_names)
    while queue:
        name = queue.pop()
        contract = classic_contract(name)
        if contract is None:
            if name in owner_names:
                scope["unknown"].append(name)
            continue
        if contract["script"] in seen:
            continue
        seen.add(contract["script"])
        scope["owners"].append(contract["script"])
        for call in contract["remotes"]["calls"]:
            entry = scope["actions"].setdefault(call.get("action"), {"keys": set(), "known": False})
            if call.get("payload_keys") is not None:
                entry["known"] = True
                entry["keys"].update(call["payload_keys"])
        for item in contract.get("requires", []):
            target = item.get("target")
            if isinstance(target, str) and target in facts["contract_of"] and target not in seen:
                queue.append(target)
    # _remotes.json joins wrapper call sites the per-owner list may show without keys.
    for action, entry in scope["actions"].items():
        joined = facts["actions"].get(action)
        if joined and not entry["known"] and joined["known"]:
            entry["known"], entry["keys"] = True, set(joined["keys"])
    return scope


class Context:
    """What one lint_source call needs to know about the unit around the file."""

    def __init__(self, unit="path", known=None, entries=None, scope=None, forks=None, phase1=None, units_of=None):
        self.unit = unit
        self.known = known or {}            # module id -> True for every Pulse module that exists (any unit)
        self.entries = entries or set()     # module ids that are entry targets (Routes swap / add)
        self.scope = scope                  # remote_scope(...) of the family, or None (no contract.json)
        self.forks = forks or {}            # instance path -> set of NEW after-lines (fork-built files)
        self.phase1 = phase1 if phase1 is not None else set(common.phase1_sources())
        self.units_of = units_of or {}


def block_ends(toks):
    """{index of a while / repeat keyword: index of the token that ends its loop}."""
    ends, stack = {}, []
    pending_while = []
    for i, tok in enumerate(toks):
        if tok.type != "kw":
            continue
        v = tok.value
        if v == "while":
            pending_while.append(i)
        elif v == "for":
            pending_while.append(None)
        elif v == "function":
            stack.append(("func", None))
        elif v == "do":
            opener = pending_while.pop() if pending_while else None
            stack.append(("loop", opener))
        elif v == "repeat":
            stack.append(("repeat", i))
        elif v == "if":
            prev = toks[i - 1] if i else None
            top = stack[-1] if stack else None
            is_expr = prev is not None and (
                (prev.type == "sym" and prev.value in base.EXPR_PREV_SYMS)
                or (prev.type == "kw" and prev.value in ("return", "and", "or", "not"))
                or (prev.type == "kw" and prev.value in ("then", "else", "elseif") and top is not None and top[0] == "ifexpr"))
            stack.append(("ifexpr" if is_expr else "if", [False]))
        elif v in ("then", "else", "elseif"):
            while stack and stack[-1][0] == "ifexpr" and stack[-1][1][0]:
                stack.pop()
            if v == "else" and stack and stack[-1][0] == "ifexpr":
                stack[-1][1][0] = True
        elif v == "until":
            while stack and stack[-1][0] == "ifexpr":
                stack.pop()
            if stack and stack[-1][0] == "repeat":
                ends[stack.pop()[1]] = i
        elif v == "end":
            while stack and stack[-1][0] == "ifexpr":
                stack.pop()
            if stack:
                kind, opener = stack.pop()
                if kind == "loop" and opener is not None:
                    ends[opener] = i
    return ends


def loop_literals(toks, index, names, inits):
    """The string literals a require inside `for _, name in ipairs(LIST)` ranges over, when LIST is a local table of
    string literals and `name` is used in the require argument; None otherwise."""
    for k in range(index - 1, max(-1, index - 400), -1):
        if toks[k].type == "kw" and toks[k].value == "for":
            j, variables = k + 1, []
            while j < index and not (toks[j].type == "kw" and toks[j].value in ("in", "do")):
                if toks[j].type == "name":
                    variables.append(toks[j].value)
                j += 1
            if not (set(variables) & names) or j >= index or toks[j].value != "in":
                continue
            listed = [t.value for t in toks[j + 1:j + 6] if t.type == "name" and t.value not in ("ipairs", "pairs")]
            for _, const, init in reversed(list(inits)):
                if listed and const == listed[0] and init and init[0].type == "sym" and init[0].value == "{":
                    strings = [t.value for t in init if t.type == "str"]
                    others = [t for t in init if t.type not in ("str", "sym")]
                    return strings if strings and not others else None
            return None
    return None


def enclosing_function(toks, func_of, index):
    """-> (name of the nearest named function around token index, or "", parameter names of every function around it).
    A remote call usually sits in pcall(function() ... end) inside call(remote, action, payload)."""
    owner, name, params = func_of[index], "", []
    while owner >= 0:
        own_name, own_params = function_head(toks, owner)
        name = name or own_name
        params.extend(own_params)
        owner = func_of[owner]
    return name, params


def function_head(toks, owner):
    """-> (declared name or "", [parameter names]) of the function whose keyword is toks[owner]."""
    j, parts = owner + 1, []
    while j < len(toks) and (toks[j].type == "name" or (toks[j].type == "sym" and toks[j].value in ".:")):
        parts.append(toks[j].value)
        j += 1
    name = "".join(parts)
    if not name and owner >= 2 and toks[owner - 1].type == "sym" and toks[owner - 1].value == "=":
        k, back = owner - 2, []
        while k >= 0 and (toks[k].type == "name" or (toks[k].type == "sym" and toks[k].value == ".")):
            back.append(toks[k].value)
            k -= 1
        name = "".join(reversed(back))
    params = []
    if j < len(toks) and toks[j].type == "sym" and toks[j].value == "(":
        depth = 0
        while j < len(toks):
            tok = toks[j]
            if tok.type == "sym" and tok.value == "(":
                depth += 1
            elif tok.type == "sym" and tok.value == ")":
                depth -= 1
                if depth == 0:
                    break
            elif tok.type == "name" and depth == 1 and toks[j - 1].type == "sym" and toks[j - 1].value in ("(", ","):
                params.append(tok.value)
            j += 1
    return name, params


def action_argument(toks, args, remote_names, direct):
    """-> (action or None, index of the payload "{" or None) for one call site, or None when the action is not a
    literal. Shapes: remote:InvokeServer("Action", {...}); remote:FireServer({...}) (no action argument, direct
    only); call(remote, "Action", {...}); call("RemoteName", "Action", {...})."""
    def literal(k):
        a, b = args[k]
        return toks[a].value if b - a == 1 and toks[a].type == "str" else None

    def table(k):
        a, b = args[k]
        return a if b > a and toks[a].type == "sym" and toks[a].value == "{" else None

    if direct and args and table(0) is not None:
        return None, table(0)
    at = None
    for k in range(min(3, len(args))):
        value = literal(k)
        if value is None:
            continue
        if value in remote_names and k + 1 < len(args) and not direct:
            continue                                    # call("GarageInvoke", "Action", ...): the remote's name
        at = k
        break
    if at is None:
        return None
    payload = next((table(k) for k in range(at + 1, len(args)) if table(k) is not None), None)
    return literal(at), payload


def table_keys(toks, open_idx, close_idx, func_end):
    """Field names of a table literal toks[open_idx] == "{"; None when a key is computed."""
    keys = []
    for a, b in base.split_args(toks, open_idx, close_idx, func_end):
        if b - a >= 2 and toks[a].type == "name" and toks[a + 1].type == "sym" and toks[a + 1].value == "=":
            keys.append(toks[a].value)
        elif b - a >= 4 and toks[a].type == "sym" and toks[a].value == "[" and toks[a + 1].type == "str" \
                and toks[a + 2].value == "]" and toks[a + 3].value == "=":
            keys.append(toks[a + 1].value)
        elif b > a and toks[a].type == "sym" and toks[a].value == "[":
            return None
    return keys


def lint_source(file_name, text, raw=None, context=None):
    """Lint one source. file_name is `<full instance path>.lua`. Returns a list of Finding; a finding on a kept
    fork line that API2 6.6 rule 4 exempts has .exempt set and is not open."""
    context = context or Context()
    path = file_name[:-4] if file_name.endswith(".lua") else file_name
    mod = module_id(path)
    found = [f for f in base.lint_source(file_name, text, raw) if f.rule not in REDONE
             and not (mod == "Kit.Minimap" and f.rule == "banned-class" and "CanvasGroup" in f.message)]   # API2 6.6 rule 2
    for finding in found:
        finding.inline = finding.accepted
        finding.accepted = False
    if mod is None:
        return finish(found, file_name, text, context, path)

    def add(line, rule, message):
        finding = Finding(file_name, line, rule, message)
        finding.inline = False
        found.append(finding)

    toks, comments = base.tokenize(text)
    func_of, func_end = base.structure(toks)
    n = len(toks)
    facts = classic_facts()
    is_kit = mod.startswith("Kit.") or mod in ("Switch", "Routes", "NoOp")
    is_fixture = mod.startswith("Dev.")
    is_family = not is_kit and not is_fixture and mod != "Toasts.ToastClient"
    leaf = mod.split(".")[-1]
    is_model = is_family and leaf.endswith("Model")
    is_view = is_family and leaf.endswith("View")
    new_lines = context.forks.get(path)

    def val(i):
        return toks[i].value if 0 <= i < n else None

    def is_sym(i, value):
        return 0 <= i < n and toks[i].type == "sym" and toks[i].value == value

    def is_call(i):                     # toks[i] is a method or field name directly followed by "("
        return is_sym(i + 1, "(") and (is_sym(i - 1, ":") or is_sym(i - 1, "."))

    # -- header (API2 6.6) ------------------------------------------------------------------------
    lines = text.split("\n")
    if not lines[0].startswith("-- Owns "):
        add(1, "header", "line 1 must start with `-- Owns `")
    phases = ("phase1", "phase2") if path in context.phase1 else ("phase2",)
    wanted = ["-- Pulse UI (%s). %s. Requires: " % (phase, path) for phase in phases]
    second = lines[1] if len(lines) > 1 else ""
    if not any(second.startswith(w) and second[len(w):].strip() for w in wanted):
        add(2, "header", "line 2 must be `%s<names or none>.`" % wanted[-1])
    if mod.startswith("Kit.") and mod not in KIT_DEPS:
        add(1, "unknown-module", "%s has no row in API2 2.1" % mod)

    # -- requires (API2 2.1 and 6.6 rule 1) -------------------------------------------------------
    if mod in KIT_DEPS:
        allowed = KIT_DEPS[mod]
    elif is_fixture:
        allowed = ANY_KIT | CORE_KIT
    else:
        allowed = (({"Kit.Presence", "Kit.Data"} if is_model else ANY_KIT) | {"Routes"})
    inits = base.local_initialisers(toks)
    by_leaf = {}
    for known in context.known:
        by_leaf.setdefault(known.split(".")[-1], []).append(known)
    for i, tok in enumerate(toks):
        if not (tok.type == "name" and tok.value == "require" and is_sym(i + 1, "(")
                and not (is_sym(i - 1, ".") or is_sym(i - 1, ":"))):
            continue
        close = base.match_paren(toks, i + 1, func_end)
        arg = toks[i + 2:close]
        dep = base.classify_require(arg, i, inits)
        shown = "".join(t.value if t.type != "str" else repr(t.value) for t in arg)
        kept = new_lines is not None and tok.line not in new_lines
        if kept and mod in FORK_KEEPS_REQUIRE:
            continue                                        # API2 6.6 rule 1: this fork keeps its Classic require
        if dep == "Dynamic" or dep.startswith("Unknown:"):
            # A helper such as `local function shared(name) ... require(folder:FindFirstChild(name)) end`: the modules
            # are the literal arguments of its call sites.
            helper, helper_params = enclosing_function(toks, func_of, i)
            helper = helper.replace(":", ".").split(".")[-1]
            used = {t.value for t in arg if t.type == "name"} | set(base.expand_words(arg, i, inits))
            if helper and helper_params and used & set(helper_params):
                sites = [k for k in range(n - 2) if toks[k].type == "name" and toks[k].value == helper and is_sym(k + 1, "(")
                         and val(k - 1) != "function" and toks[k + 2].type == "str"]
                if sites:
                    for k in sites:
                        literal = toks[k + 2].value.split(".")[-1]
                        if literal in NEVER or not (literal in SHARED or literal in by_leaf
                                                    or (mod == "FreeRoam.ActivityHudClient" and literal in ACTIVITY_VIEWS)):
                            add(toks[k].line, "classic-require", "%s(%r): not a shared module API2 6.6 rule 1 lists" % (helper, toks[k + 2].value))
                        elif not is_family and literal in SHARED:
                            add(toks[k].line, "classic-require", "%s(%r): only a family module may require a shared module" % (helper, literal))
                    continue
        if dep == "Dynamic" or dep.startswith("Unknown:"):
            # `for _, name in ipairs(ORDER) do require(folder:WaitForChild(name)) end` with ORDER a literal list.
            listed = loop_literals(toks, i, {t.value for t in arg if t.type == "name"}, inits)
            if listed is not None:
                for literal in listed:
                    if literal in NEVER or not (literal in SHARED or literal in by_leaf
                                                or (mod == "FreeRoam.ActivityHudClient" and literal in ACTIVITY_VIEWS)):
                        add(tok.line, "classic-require", "require of %r from a name list: not a Pulse module or a shared module "
                            "API2 6.6 rule 1 lists" % literal)
                continue
        if dep == "Dynamic":
            if "Dynamic" not in allowed and mod not in ("FreeRoam.ActivityHudClient", "Kit.Data"):
                add(tok.line, "dependency", "require(%s): a require of a variable cannot be checked; name the module" % shown)
            continue
        if dep.startswith("Core."):
            if not is_family and not is_fixture and dep not in allowed:
                add(tok.line, "dependency", "%s may not require %s (API2 2.1)" % (mod, dep))
            elif is_fixture and dep not in CORE_KIT:
                add(tok.line, "dependency", "%s may not require %s (fixtures: ConnectionScope, ConfigReader)" % (mod, dep))
            continue
        if dep == "Fixtures":
            if "Fixtures" not in allowed:
                add(tok.line, "dependency", "%s may not require a fixture module" % mod)
            continue
        if not dep.startswith("Unknown:"):
            if dep not in allowed:
                why = "a model requires no Kit module except Presence and Data (API2 6.2)" if is_model and dep.startswith("Kit.") \
                    else "API2 2.1"
                add(tok.line, "dependency", "%s may not require %s (%s)" % (mod, dep, why))
            continue
        words = dep[len("Unknown:"):].split(".")
        name = words[-1]
        if name in NEVER and not (name == "ResponsiveUIFoundation" and "Shared:ResponsiveUIFoundation" in allowed):
            add(tok.line, "classic-require", "require(%s): %s is never required by Pulse (API2 6.6 rule 1)" % (shown, name))
        elif name == "ResponsiveUIFoundation":
            continue                                        # Kit.Data, API2 3.5
        elif name in by_leaf and (is_family or is_fixture):
            targets = by_leaf[name]
            same_folder = [t for t in targets if t.rsplit(".", 1)[0] == mod.rsplit(".", 1)[0]]
            target = (same_folder or targets)[0]
            if target in context.entries and target != mod and not is_fixture:
                add(tok.line, "cross-entry-require", "require(%s): %s is an entry; reach another entry through "
                    "Routes.Resolve (API2 section 4)" % (shown, target))
        elif name in SHARED or (mod == "FreeRoam.ActivityHudClient" and name in ACTIVITY_VIEWS):
            if not is_family:
                add(tok.line, "classic-require", "require(%s): only a family module may require the shared module %s" % (shown, name))
        elif name in facts["classic_names"] or name in facts["entries"]:
            add(tok.line, "classic-require", "require(%s): %s is a Classic module API2 6.6 rule 1 does not list as shared" % (shown, name))
        else:
            add(tok.line, "dependency", "require(%s): not a Pulse module of this wave, a listed shared module or Core" % shown)

    # -- token rules ------------------------------------------------------------------------------
    wrappers = set(WRAPPER_NAMES)
    remote_sites = []                    # (index of FireServer / InvokeServer)
    for i, tok in enumerate(toks):
        if tok.type == "name" and tok.value in ("FireServer", "InvokeServer") and is_sym(i - 1, ":") and is_sym(i + 1, "("):
            remote_sites.append(i)
            name, params = enclosing_function(toks, func_of, i)
            close = base.match_paren(toks, i + 1, func_end)
            args = base.split_args(toks, i + 1, close, func_end)
            if args and args[0][1] - args[0][0] == 1 and toks[args[0][0]].type == "name" and toks[args[0][0]].value in params:
                wrappers.add(name.replace(":", ".").split(".")[-1])

    def check_action(line, action, payload_open, how):
        scope = context.scope
        globally = facts["actions"].get(action)
        entry = scope["actions"].get(action) if scope else globally
        if entry is None:
            if globally is None and action in facts["server_actions"]:
                add(line, "remote-action-server-only", "%s sends action %r: the server accepts it, but no Classic client sends "
                    "it; it needs a line in API2 section 5 (API2 6.7: no new remote action)" % (how, action))
            elif globally is None:
                add(line, "remote-action", "%s sends action %s, which no Classic client sends (API2 6.7: no new remote action)" % (
                    how, repr(action) if action is not None else "<no action argument>"))
            else:
                add(line, "remote-action-owner", "%s sends action %r; Classic sends it, but not from an owner this family "
                    "replaces (%s)" % (how, action, ", ".join(o.split(".")[-1] for o in scope["owners"]) or "none"))
            return
        if payload_open is None or not entry["known"]:
            return
        keys = table_keys(toks, payload_open, base.match_paren(toks, payload_open, func_end), func_end)
        for key in keys or []:
            if key not in entry["keys"]:
                add(toks[payload_open].line, "remote-payload-key", "%s action %r: payload key %r is not sent by Classic (keys: %s)" % (
                    how, action, key, ", ".join(sorted(entry["keys"])) or "none"))

    def scan_call(open_idx, how, line):
        close = base.match_paren(toks, open_idx, func_end)
        args = base.split_args(toks, open_idx, close, func_end)
        found_action = action_argument(toks, args, facts["remote_names"], direct=how.startswith(":"))
        if found_action is None:
            return False
        action, payload = found_action
        check_action(line, action, payload, how)
        return True

    for i in remote_sites:
        tok = toks[i]
        if is_kit or is_fixture:
            add(tok.line, "remote-outside-model", "%s in %s: kit and gallery modules never call a remote" % (tok.value, mod))
            continue
        if is_view:
            add(tok.line, "view-side-effect", "%s in a view (API2 6.2: no remote, attribute write or bindable in a view)" % tok.value)
        name, params = enclosing_function(toks, func_of, i)
        if not scan_call(i + 1, ":" + tok.value, tok.line):
            close = base.match_paren(toks, i + 1, func_end)
            args = base.split_args(toks, i + 1, close, func_end)
            first_is_param = bool(args) and args[0][1] - args[0][0] == 1 and toks[args[0][0]].value in params
            if not first_is_param:
                add(tok.line, "remote-dynamic-action", ":%s with an action that is not a literal and not the parameter of a "
                    "call(remote, action, payload) wrapper; it cannot be checked against the Classic contract" % tok.value)
    for i, tok in enumerate(toks):
        t, v = tok.type, tok.value
        if t == "name" and v in wrappers and is_sym(i + 1, "(") and val(i - 1) != "function" \
                and not (is_sym(i - 1, ".") and val(i - 2) in ("pcall", "task", "coroutine")):
            if not is_kit and not is_fixture:
                scan_call(i + 1, v + "()", tok.line)
        if t == "name" and v in ("invoke", "event", "fire", "request") and is_sym(i - 1, ".") and val(i - 2) == "Net" and is_sym(i + 1, "("):
            scan_call(i + 1, "Net." + v, tok.line)
        if t == "name" and v == "Instance" and is_sym(i + 1, ".") and val(i + 2) == "new" and is_sym(i + 3, "(") \
                and i + 4 < n and toks[i + 4].type == "str":
            klass = toks[i + 4].value
            if klass in REMOTE_CLASSES:
                add(tok.line, "remote-new", "Instance.new(%r): no remote is created by this wave (API2 6.7)" % klass)
            elif klass in BINDABLE_CLASSES:
                # the variable the instance lands in: the name before the nearest "=" on the same line
                variable, k = None, i - 1
                while k > 0 and toks[k].line == tok.line and not is_sym(k, "="):
                    k -= 1
                if is_sym(k, "=") and toks[k - 1].type == "name":
                    variable = toks[k - 1].value
                close = base.match_paren(toks, i + 3, func_end)
                parented = len(base.split_args(toks, i + 3, close, func_end)) > 1 or variable is None
                names = []
                for k in range(n - 4):
                    if variable and toks[k].type == "name" and toks[k].value == variable and is_sym(k + 1, ".") and is_sym(k + 3, "="):
                        if val(k + 2) == "Parent":
                            parented = True
                        elif val(k + 2) == "Name":
                            if toks[k + 4].type == "str":
                                names.append(toks[k + 4].value)
                            elif toks[k + 4].type == "name":
                                names.extend(init[0].value for _, const, init in inits
                                             if const == toks[k + 4].value and len(init) == 1 and init[0].type == "str")
                # An unparented BindableEvent is a private Luau signal (API2 6.2), not a Runtime bindable.
                if parented and not names:
                    add(tok.line, "bindable-new", "Instance.new(%r) is parented but has no literal Name on the same variable; a "
                        "bindable may only be created under a name Classic already uses (API2 6.7)" % klass)
                for name in names if parented else []:
                    if name not in facts["bindable_words"]:
                        add(tok.line, "bindable-new", "new bindable %r: no Classic contract lists that name (API2 6.7)" % name)
            elif klass in GUI_CLASSES and is_model:
                add(tok.line, "model-gui", "Instance.new(%r) in a model; a model creates no GuiObject (API2 6.2)" % klass)
        if (t == "name" or t == "str") and v in BANNED_SERVICES:
            add(tok.line, "banned-service", "%s is not used by this wave (API2 6.7: no saved field, no purchase prompt)" % v)
        if t == "name" and v in BANNED_CALLS and is_call(i):
            add(tok.line, "banned-service", "%s is not called by this wave (API2 6.7)" % v)
        if t == "name" and v in ("WaitForChild", "FindFirstChild") and is_sym(i - 1, ":") and is_sym(i + 1, "(") \
                and i + 2 < n and toks[i + 2].type == "str":
            back = [toks[k].value for k in range(max(0, i - 16), i) if toks[k].line >= tok.line - 1]
            statement = []
            for word in reversed(back):
                if word in ("local", "=", "then", "do", "return", ","):
                    break
                statement.append(word)
            if any(w.lower() == "remotes" for w in statement) and toks[i + 2].value not in facts["remote_words"]:
                add(tok.line, "remote-name", "%r is looked up under Remotes but no Classic contract names it (API2 6.7)" % toks[i + 2].value)
            if any(w.lower() == "runtime" for w in statement) and toks[i + 2].value not in facts["bindable_words"] and toks[i + 2].value != "Runtime":
                add(tok.line, "bindable-name", "%r is looked up under Runtime but no Classic contract names it (API2 6.7)" % toks[i + 2].value)
        if is_view and t == "name" and is_sym(i - 1, ":") and is_sym(i + 1, "(") and v in ("Fire", "Invoke", "SetAttribute"):
            add(tok.line, "view-side-effect", ":%s in a view (API2 6.2: no remote, attribute write or bindable in a view)" % v)
        # asset keys (API2 1.1): Asset("Key"), Assets.Key, Assets["Key"]
        key = None
        if t == "str" and (v in ASSET_USERS or v in REMOVED_ASSETS):
            if (is_sym(i - 1, "(") and val(i - 2) == "Asset") or (is_sym(i - 1, "[") and val(i - 2) == "Assets"):
                key = v
        elif t == "name" and (v in ASSET_USERS or v in REMOVED_ASSETS) and is_sym(i - 1, ".") and val(i - 2) == "Assets":
            key = v
        if key and mod not in ("Kit.Tokens", "Kit.Sprites"):
            if key in REMOVED_ASSETS:
                add(tok.line, "asset-key", "asset key %s was removed in wave 2 (API2 1.1)" % key)
            elif not any(fnmatch.fnmatchcase(mod, user) for user in ASSET_USERS[key]):
                add(tok.line, "asset-key", "asset key %s is used only by %s (API2 1.1)" % (key, ", ".join(sorted(ASSET_USERS[key]))))
        # Classic names that are never touched (Kit.Contracts holds names as data, as in Phase 1)
        keeps_require = mod in FORK_KEEPS_REQUIRE and new_lines is not None and tok.line not in new_lines
        if t == "name" and v in NEVER and not (v == "ResponsiveUIFoundation" and mod == "Kit.Data") and not keeps_require:
            add(tok.line, "classic-require", "names the Classic module %s" % v)
        if t == "str":
            for name in NEVER:
                if re.search(r"\b%s\b" % name, v) and mod != "Kit.Contracts" and not keeps_require \
                        and not (name == "ResponsiveUIFoundation" and mod == "Kit.Data"):
                    add(tok.line, "classic-require", "names the Classic module %s" % name)
            for match in re.finditer(r"ReplicatedStorage\.Modules\.Game\.(?!UIPulse\b)[\w.]+", v):
                target = match.group(0).rstrip(".").split(".")[-1]
                if target in facts["classic_names"] and target not in SHARED and target not in NEVER and mod != "Kit.Contracts" \
                        and not (mod == "FreeRoam.ActivityHudClient" and target in ACTIVITY_VIEWS):
                    add(tok.line, "classic-path", "string names a Classic module path: %r" % match.group(0))
            # A trap name matters where it becomes an instance name: .Name = "x", Name = "x" in a property table, or
            # the name given to Layers.Create. Claim names and FreeRoamHudPresentationMode owner keys are data.
            naming = (is_sym(i - 1, "=") and val(i - 2) == "Name") or (
                is_sym(i - 1, "(") and val(i - 2) in ("Create", "Stage") and val(i - 4) == "Layers")
            if v in base.TRAP_NAMES and naming and mod != "Kit.Contracts":
                add(tok.line, "trap-name", "trap name %r used as an instance name" % v)
            if ASSET_LITERAL.search(v) and mod not in base.ALLOW_ASSET:
                add(tok.line, "asset-literal", "asset id outside Kit.Tokens and Kit.Sprites")

    # -- polling loops (API2 6.6 rule 5) ----------------------------------------------------------
    for start, end in sorted(block_ends(toks).items()):
        body = range(start + 1, end)
        waits = any(toks[k].type == "name" and toks[k].value == "wait" and is_sym(k + 1, "(") for k in body)
        reads = [toks[k].value for k in body if toks[k].type == "name" and toks[k].value in PRESENCE_READS and is_call(k)]
        if waits and reads:
            add(toks[start].line, "poll-loop", "a loop that waits and calls %s: no loop polls for presence (API2 6.6 rule 5)" % reads[0])
    return finish(found, file_name, text, context, path)


def finish(found, file_name, text, context, path):
    new_lines = context.forks.get(path)
    for finding in found:
        on_kept = new_lines is not None and finding.line not in new_lines
        finding.exempt = bool(on_kept and finding.rule in KEPT_EXEMPT)
        finding.kept = bool(on_kept and not finding.exempt and finding.rule not in KEPT_STILL_OPEN)
        inline = getattr(finding, "inline", False)
        finding.accepted = bool(inline and finding.rule not in SAFETY_RULES)
        finding.note = "inline lint-ok" if finding.accepted else (
            "inline lint-ok ignored: safety rule, use the accept file" if inline else "")
    if module_id(path) is None and path in common.classic_manifest():
        pass            # an edited Classic script: the reviewer reads its diff (CONTRACT section 2)
    found.sort(key=lambda f: (f.line, f.rule))
    return found


def load_accept(path):
    if not path or not os.path.isfile(path):
        return []
    data = common.read_json(path)
    rows = data.get("accept") if isinstance(data, dict) else data
    problems = []
    for index, row in enumerate(rows or []):
        if not isinstance(row, dict) or not row.get("file") or not row.get("rule") or not str(row.get("reason", "")).strip():
            problems.append("accept[%d]: file, rule and reason are required" % index)
    if problems:
        raise common.ToolError("%s is not a valid accept file" % path, problems)
    return [dict(row, _used=0) for row in rows or []]


def apply_accept(findings, accept):
    for finding in findings:
        if finding.accepted or getattr(finding, "exempt", False) or getattr(finding, "kept", False):
            continue
        for row in accept:
            if not fnmatch.fnmatchcase(finding.file, row["file"]) and row["file"] != finding.file:
                continue
            if row["rule"] != finding.rule:
                continue
            if "line" in row and row["line"] != finding.line:
                continue
            if row.get("contains") and row["contains"] not in finding.message:
                continue
            finding.accepted = True
            finding.note = "accepted: %s%s" % (row["reason"], " (%s)" % row["reviewer"] if row.get("reviewer") else "")
            row["_used"] += 1
            break


def all_known(layout):
    """({module id: unit}, {entry module ids}) over Phase 1, the kit and every family that has files."""
    known = {}
    for path in common.phase1_sources():
        if module_id(path):
            known[module_id(path)] = "phase1"
    kit, _, _, _ = common.kit_sources(layout)
    for path in kit:
        if module_id(path):
            known[module_id(path)] = "kit"
    known.setdefault("NoOp", "kit")
    entries = {"Toasts.ToastClient", "Dev.Gallery"}
    for family in common.FAMILIES:
        sources, _, _ = common.family_sources(layout, family)
        for path in sources:
            if module_id(path):
                known[module_id(path)] = family
        for _, data in common.fragments(layout.family_dir(family), "routes"):
            if isinstance(data, dict):
                targets = list((data.get("swap") or {}).values()) if isinstance(data.get("swap"), dict) else []
                targets += [row.get("path") for row in data.get("add") or [] if isinstance(row, dict)]
                for target in targets:
                    if isinstance(target, str) and target.startswith(UIP):
                        entries.add(target[len(UIP):])
    return known, entries


def unit_files(layout, unit):
    """-> ({path: file}, {path: set of new lines}, [notes])."""
    notes = []
    if unit == "kit":
        sources, _, problems, present = common.kit_sources(layout)
        notes.extend(problems)
        noop = os.path.join(layout.integrator, "UIPulse.NoOp.lua")
        if os.path.isfile(noop):
            sources.setdefault(common.NOOP_PATH, noop)
        return sources, {}, notes
    sources, _, fork_records = common.family_sources(layout, unit)
    forks_dir = os.path.join(layout.family_dir(unit), "forks")
    declared = [n for n in os.listdir(forks_dir) if n.endswith(".json")] if os.path.isdir(forks_dir) else []
    if declared and not fork_records:
        notes.append("forks/*.json present but not built: run build_forks.py %s first (fork files are linted as "
                     "ordinary sources until then)" % unit)
    import build_forks
    return sources, {path: build_forks.new_line_set(record) for path, record in fork_records.items()}, notes


def lint_unit(layout, unit, known=None, entries=None):
    """-> {"unit", "files", "findings": [Finding], "notes": [str]}."""
    if known is None:
        known, entries = all_known(layout)
    sources, forks, notes = unit_files(layout, unit)
    scope = None
    if unit in common.FAMILIES:
        try:
            owners = common.family_contract(layout.family_dir(unit))
        except common.ToolError as error:
            owners = []
            notes.append(error.title)
        replaced = []
        for owner in owners:
            replaced.extend(owner.get("replaces") or [])
        fork_index = os.path.join(layout.forks_out(unit), "forks.json")
        if replaced and os.path.isfile(fork_index):
            replaced.extend(record["source"] for record in common.read_json(fork_index)["forks"])
        if replaced:
            scope = remote_scope(replaced)
            for name in scope["unknown"]:
                notes.append("contract.json replaces %r, which has no Classic contract file" % name)
        elif sources:
            notes.append("no contract.json (or no \"replaces\"): remote actions are checked against every Classic "
                         "contract, not against the owners this family replaces")
    context = Context(unit=unit, known=known, entries=entries, scope=scope, forks=forks)
    findings = []
    for path in sorted(sources):
        raw = common.read_bytes(sources[path])
        findings.extend(lint_source(path + ".lua", raw.decode("utf-8", errors="replace"), raw, context))
    findings = resolve_remote_steps(sources, findings)
    return {"unit": unit, "files": len(sources), "findings": findings, "notes": notes}


def step_violations(toks, func_end, names, start, seen):
    """[(line, what)] inside the function at `start` and the same-file functions it calls (API1 rule 7)."""
    out = []
    if start in seen:
        return out
    seen.add(start)
    n = len(toks)

    def sym(i, value):
        return 0 <= i < n and toks[i].type == "sym" and toks[i].value == value

    for k in range(start + 1, func_end[start]):
        tk = toks[k]
        if tk.type != "name":
            continue
        if tk.value in base.STEP_FORBIDDEN and (sym(k - 1, ".") or sym(k - 1, ":")):
            out.append((tk.line, tk.value))
        elif tk.value == "Instance" and sym(k + 1, ".") and k + 2 < n and toks[k + 2].value == "new":
            out.append((tk.line, "Instance.new"))
        elif not sym(k - 1, ".") and not sym(k - 1, ":"):
            parts, j = [tk.value], k + 1
            while (sym(j, ".") or sym(j, ":")) and j + 1 < n and toks[j + 1].type == "name":
                parts.append(toks[j + 1].value)
                j += 2
            target = names.get(".".join(parts))
            if target is not None and sym(j, "("):
                out.extend(step_violations(toks, func_end, names, target, seen))
    return out


def resolve_remote_steps(sources, findings):
    """A step passed to Perf.Bind as `view.Step` is declared in another module of the unit. Finds every function of
    that member name in the unit, scans it, and replaces the "cannot find the step function" finding."""
    parsed = {}

    def parse(path):
        if path not in parsed:
            text = common.read_bytes(sources[path]).decode("utf-8", errors="replace")
            toks, _ = base.tokenize(text)
            _, func_end = base.structure(toks)
            parsed[path] = (toks, func_end, base.function_names(toks, func_end))
        return parsed[path]

    out = []
    for finding in findings:
        path = finding.file[:-4]
        if finding.rule != "perf-step" or "cannot find the step function" not in finding.message or path not in sources:
            out.append(finding)
            continue
        toks, func_end, _ = parse(path)
        member = None
        for i, tok in enumerate(toks):
            if tok.line == finding.line and tok.type == "name" and tok.value == "Bind" and i >= 2 and toks[i - 2].value == "Perf":
                close = base.match_paren(toks, i + 1, func_end)
                args = base.split_args(toks, i + 1, close, func_end)
                if len(args) >= 3 and toks[args[2][1] - 1].type == "name" and args[2][1] - args[2][0] >= 3:
                    member = toks[args[2][1] - 1].value
        hits, violations = [], []
        for other in sorted(sources) if member else []:
            if other in common.classic_manifest():
                continue                                    # an edited Classic script is not a Pulse view
            o_toks, o_end, o_names = parse(other)
            for name, start in o_names.items():
                if name.split(".")[-1] == member and other != path:
                    hits.append("%s:%d" % (common.short(other), o_toks[start].line))
                    for line, what in step_violations(o_toks, o_end, o_names, start, set()):
                        violations.append((other, line, what))
        if not hits:
            out.append(finding)
            continue
        for other, line, what in violations:
            made = Finding(other + ".lua", line, "perf-step", "%s inside a Perf.Bind step (bound at %s:%d)" % (
                what, common.short(path), finding.line))
            made.inline, made.exempt, made.kept, made.note = False, False, False, ""
            out.append(made)
    return out


def summarise(result):
    open_findings = [f for f in result["findings"] if is_open(f)]
    return {"files": result["files"], "open": len(open_findings),
            "accepted": sum(1 for f in result["findings"] if f.accepted),
            "exempt": sum(1 for f in result["findings"] if f.exempt),
            "kept": sum(1 for f in result["findings"] if f.kept)}


def is_open(finding):
    return not finding.accepted and not finding.exempt and not finding.kept


def main(argv):
    layout, positional, options = common.parse_args(argv, flags=("--json", "--show-exempt"), values=("--accept", "--path"))
    accept_path = options.get("--accept") or os.path.join(layout.integrator, "lint_accept.json")
    if "--accept" in options and not os.path.isfile(accept_path):
        raise common.ToolError("accept file %s does not exist" % accept_path)
    accept = load_accept(accept_path)
    results = []
    if "--path" in options:
        files = {}
        for item in [options["--path"]] + positional:
            files.update(common.lua_files(item) if os.path.isdir(item) else {os.path.basename(item)[:-4]: item})
        known, entries = all_known(layout)
        for path in files:
            if module_id(path):
                known.setdefault(module_id(path), "path")
        context = Context(unit="path", known=known, entries=entries)
        findings = []
        for path in sorted(files):
            raw = common.read_bytes(files[path])
            findings.extend(lint_source(path + ".lua", raw.decode("utf-8", errors="replace"), raw, context))
        results.append({"unit": "path", "files": len(files), "findings": findings, "notes": []})
    else:
        for unit in positional:
            if unit not in ORDERED_UNITS:
                raise common.ToolError("unknown unit %r" % unit, ["units: " + ", ".join(ORDERED_UNITS)])
        known, entries = all_known(layout)
        for unit in positional or ORDERED_UNITS:
            result = lint_unit(layout, unit, known, entries)
            if result["files"] or positional:
                results.append(result)
    for result in results:
        apply_accept(result["findings"], accept)
    total_open = sum(summarise(r)["open"] for r in results)
    total_files = sum(r["files"] for r in results)
    stale = [row for row in accept if not row["_used"]]
    if "--json" in options:
        print(json.dumps({"units": [dict(summarise(r), unit=r["unit"], notes=r["notes"], findings=[
            dict(f.as_dict(), exempt=f.exempt, kept=f.kept, note=f.note) for f in r["findings"]]) for r in results],
            "open": total_open, "staleAccept": [{k: v for k, v in row.items() if k != "_used"} for row in stale]}, indent=1))
    else:
        for result in results:
            counts = summarise(result)
            print("== %s: %d files, %d findings, %d accepted; kept fork lines: %d exempt by API2 6.6 rule 4, %d to review" % (
                result["unit"], counts["files"], counts["open"], counts["accepted"], counts["exempt"], counts["kept"]))
            for note in result["notes"]:
                print("   note: " + note)
            for finding in result["findings"]:
                if (finding.exempt or finding.kept) and "--show-exempt" not in options:
                    continue
                mark = " (exempt: kept fork line)" if finding.exempt else " (kept fork line: review, not counted)" if finding.kept \
                    else (" (%s)" % finding.note if finding.note else "")
                print("%s:%d: [%s] %s%s" % (finding.file, finding.line, finding.rule, finding.message, mark))
            if not result["files"]:
                print("   nothing to lint: no source files found for this unit")
        for row in stale:
            print("stale accept entry (matched nothing): %s [%s]" % (row["file"], row["rule"]))
        print("%d files, %d open findings" % (total_files, total_open))
    return 1 if total_open or not total_files else 0


ORDERED_UNITS = ["kit"] + common.FAMILIES

if __name__ == "__main__":
    common.run_main(main)
