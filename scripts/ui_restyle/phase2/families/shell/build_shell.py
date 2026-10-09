"""Shell family: offline assembly and checks. Writes only inside this folder. Run: py -3 build_shell.py [--check]

1. before/  : byte copies of the two edited ReplicatedFirst scripts from classic/sources.
2. after/   : the two edits exactly as API2 5.8 states them, each verified with a diff.
3. after/ReplicatedFirst.Loading.StartScreenPulse.lua : hand assembly of forks/StartScreenPulse.json for review
              (the integrator's fork tool is the authority); kept lines verified byte for byte.
4. Target tables of OnboardingModel against classic/contracts/_onboarding_targets.json, and the generated
   expected block of the model test.
--check writes nothing and fails if a file on disk differs.
"""
import difflib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESTYLE = HERE.parents[2]
SOURCES = RESTYLE / "classic" / "sources"
CHECK = "--check" in sys.argv
problems = []

RUNTIME = "ReplicatedFirst.Loading.LoadingTransitionRuntime.lua"
INITIAL = "ReplicatedFirst.Loading.InitialLoadingAndStartScreenClient.lua"

RUNTIME_OLD_8 = 'local View = require(game:GetService("ReplicatedFirst"):WaitForChild("Loading"):WaitForChild("LoadingScreenView"))'
RUNTIME_NEW = [
    'local okStyle, pulseShell = pcall(function() return require(game:GetService("ReplicatedFirst"):FindFirstChild("UIStyleSwitch")).Active("Shell") end)',
    'local View = require(game:GetService("ReplicatedFirst"):WaitForChild("Loading"):WaitForChild((okStyle and pulseShell) and "LoadingScreenViewPulse" or "LoadingScreenView"))',
]
INITIAL_NEW = [
    'local okStyle, pulseShell = pcall(function() return require(ReplicatedFirst:FindFirstChild("UIStyleSwitch")).Active("Shell") end)',
    'if okStyle and pulseShell then require(packageFolder:WaitForChild("StartScreenPulse")).Run(); return end',
]


def put(path: Path, data: bytes):
    if CHECK:
        if not path.exists() or path.read_bytes() != data:
            problems.append(f"{path.relative_to(HERE)} differs from the build")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def lines_of(data: bytes):
    assert b"\r" not in data, "CR in source"
    text = data.decode("utf-8")
    assert text.endswith("\n")
    return text[:-1].split("\n")


def join(lines):
    return ("\n".join(lines) + "\n").encode("utf-8")


def opcodes(before, after):
    return [op for op in difflib.SequenceMatcher(None, before, after, autojunk=False).get_opcodes() if op[0] != "equal"]


# 1 and 2 ---------------------------------------------------------------------------------------------------
runtime_before = (SOURCES / RUNTIME).read_bytes()
initial_before = (SOURCES / INITIAL).read_bytes()
put(HERE / "before" / RUNTIME, runtime_before)
put(HERE / "before" / INITIAL, initial_before)

rt = lines_of(runtime_before)
assert rt[7] == RUNTIME_OLD_8, "LoadingTransitionRuntime line 8 is not the recorded text"
rt_after = rt[:7] + RUNTIME_NEW + rt[8:]
put(HERE / "after" / RUNTIME, join(rt_after))
ops = opcodes(rt, rt_after)
assert ops == [("replace", 7, 8, 7, 9)], ops
print(f"edit 1 {RUNTIME}: line 8 -> 2 lines; {len(rt)} -> {len(rt_after)} lines; diff = one hunk, 1 removed, 2 added: OK")

il = lines_of(initial_before)
assert il[17] == "end" and il[18] == "" and il[14].startswith('if config:GetAttribute("StartScreenEnabled") == false'), "line 15-19 anchor"
il_after = il[:18] + INITIAL_NEW + il[18:]
put(HERE / "after" / INITIAL, join(il_after))
ops = opcodes(il, il_after)
assert ops == [("insert", 18, 18, 18, 20)], ops
print(f"edit 2 {INITIAL}: 2 lines inserted after line 18; {len(il)} -> {len(il_after)} lines; diff = one hunk, 0 removed, 2 added: OK")

# 3 ---------------------------------------------------------------------------------------------------------
fork = json.loads((HERE / "forks" / "StartScreenPulse.json").read_text(encoding="utf-8"))
assert fork["source"] + ".lua" == INITIAL
spans = sorted(fork["replace"], key=lambda s: s["lines"][0])
out, kept, cursor = [], [], 1
for span in spans:
    first, last = span["lines"]
    assert first >= cursor and last >= first, span
    for number in range(cursor, first):
        out.append(il[number - 1])
        kept.append(number)
    out.extend(lines_of((HERE / "forks" / span["with"]).read_bytes()))
    cursor = last + 1
for number in range(cursor, len(il) + 1):
    out.append(il[number - 1])
    kept.append(number)
start_after = join(out)
put(HERE / "after" / "ReplicatedFirst.Loading.StartScreenPulse.lua", start_after)

# Kept lines survive in order, byte for byte: removing each replacement block from the assembly gives back exactly the
# Classic lines outside the declared spans.
declared = [tuple(s["lines"]) for s in spans]
declared_set = set()
for a, b in declared:
    declared_set.update(range(a, b + 1))
rebuilt, position = [], 0
cursor = 1
for span in spans:
    first, last = span["lines"]
    count = first - cursor
    rebuilt.extend(out[position:position + count])
    position += count + len(lines_of((HERE / "forks" / span["with"]).read_bytes()))
    cursor = last + 1
rebuilt.extend(out[position:])
if rebuilt != [il[n - 1] for n in range(1, len(il) + 1) if n not in declared_set]:
    problems.append("fork: kept lines are not the Classic lines outside the declared spans")
deleted = declared
kept_text = "\n".join(il[n - 1] for n in kept)
for needle in ('player:SetAttribute("StartScreenActive", true)', 'player:SetAttribute("StartScreenActive", false)',
               'config:SetAttribute("TimeoutSeconds", 86400)', 'config:SetAttribute("TimeoutSeconds", originalTimeout)',
               'artwork:SetAttribute("Enabled", false)', 'remote:InvokeServer("TeleportToDealership")', "exited:Fire()",
               'api:Handle(action, { Generation = generation', "ReplicatedFirst:RemoveDefaultLoadingScreen()"):
    if needle not in kept_text:
        problems.append(f"fork: kept text lost: {needle}")
if kept_text.count('SetAttribute("StartScreenActive"') != 3:
    problems.append("fork: expected the three StartScreenActive writes of Classic 52, 82, 297 in kept lines")
replaced_text = "\n".join(il[n - 1] for n in sorted(declared_set))
assembled = start_after.decode("utf-8")
for name in ("Workspace", "UserInputService", "packageFolder", "UI\\."):
    body = "\n".join(il[n - 1] for n in kept)
    if re.search(r'(?<!["\w.:])' + name + r'(?!")', body):
        problems.append(f"fork: kept lines still use {name}, which the header does not declare")
for call in ("InvokeServer", ":Fire(", "SetAttribute"):
    if assembled.count(call) != sum(il[n - 1].count(call) for n in kept):
        problems.append(f"fork: replacement spans add or the assembly loses a {call} call")
print(f"fork StartScreenPulse: {len(kept)} Classic lines kept, spans {declared}; diff deletes {deleted}: "
      + ("OK" if not problems else "see problems"))

# 4 ---------------------------------------------------------------------------------------------------------
targets = json.loads((RESTYLE / "classic" / "contracts" / "_onboarding_targets.json").read_text(encoding="utf-8"))
model = (HERE / "after" / "ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingModel.lua").read_text(encoding="utf-8")


def strings(text):
    return re.findall(r'"([^"]*)"', text)


def block(name):
    match = re.search(r"\nModel\." + name + r" = table\.freeze\(\{\n(.*?)\n\}\)\n", model, re.S)
    assert match, name
    return match.group(1)


# pages, order, placement, action steps, copy
pages = {m.group(1): strings(m.group(2)) for m in re.finditer(r"(\w+) = table\.freeze\(\{ (.*?) \}\)", block("Pages"))}
expect_pages = {k: v["cards"] for k, v in targets["pages"].items()}
if pages != expect_pages:
    problems.append("model: Pages differ from the contract")
if strings(block("PageOrder")) != targets["page_order"]:
    problems.append("model: PageOrder differs from the contract")
copy = dict(re.findall(r'(\w+) = "((?:[^"\\]|\\.)*)"', block("Copy")))
if copy != {k: v["copy"] for k, v in targets["cards"].items()}:
    problems.append("model: Copy differs from the contract")
placement = dict(re.findall(r'(\w+) = "(\w+)"', block("Placement")))
if placement != {k: v["placement"] for k, v in targets["cards"].items() if v["placement"]}:
    problems.append("model: Placement differs from the contract")
actions = set(re.findall(r"(\w+) = true", re.search(r"Model\.ActionSteps = table\.freeze\(\{(.*?)\}\)", model).group(1)))
if actions != {k for k, v in targets["cards"].items() if v["action_step"]}:
    problems.append("model: ActionSteps differ from the contract")

# card targets: helper + literals, in source order
expected_cards = {}
for card, info in targets["cards"].items():
    helpers = []
    literals = []
    for t in info["targets"]:
        if t["helper"] not in helpers:
            helpers.append(t["helper"])
        literals.extend(t["literals"])
    assert len(helpers) == 1, (card, helpers)
    expected_cards[card] = (helpers[0], literals)
got_cards = {}
tb = block("Targets")
for m in re.finditer(r"(\w+) = (group|cards|scrollerCards|target)\((.*?)\)(?=,)", tb):
    card, fn, args = m.group(1), m.group(2), m.group(3)
    if fn == "group":
        got_cards[card] = ("group", strings(args))
    elif fn == "cards":
        got_cards[card] = ("cardGroup", strings(args))
    elif fn == "scrollerCards":
        got_cards[card] = ("visibleScrollerCards", strings(args))
    else:
        helper = strings(args)[0]
        first_list = re.search(r"\{ (.*?) \}", args).group(1)
        got_cards[card] = (helper, strings(first_list))
if got_cards != expected_cards:
    for card in sorted(set(got_cards) | set(expected_cards)):
        if got_cards.get(card) != expected_cards.get(card):
            problems.append(f"model: target {card}: {got_cards.get(card)} != contract {expected_cards.get(card)}")

expected_signals = {}
for page, info in targets["pages"].items():
    literals = []
    for t in info["signal_targets"]:
        literals.extend(t["literals"])
    expected_signals[page] = literals
got_signals = {}
sb = block("PageSignals")
for m in re.finditer(r"(\w+) = (workspacePage|signal)\((.*)\),", sb):
    page, fn, args = m.group(1), m.group(2), m.group(3)
    if fn == "workspacePage":
        got_signals[page] = strings(args)
    else:
        got_signals[page] = strings(re.match(r"\{(.*?)\}", args).group(1))
if got_signals != expected_signals:
    for page in sorted(set(got_signals) | set(expected_signals)):
        if got_signals.get(page) != expected_signals.get(page):
            problems.append(f"model: signal {page}: {got_signals.get(page)} != contract {expected_signals.get(page)}")
print(f"targets: {len(got_cards)} cards and {len(got_signals)} pages compared with _onboarding_targets.json: "
      + ("OK" if not any(p.startswith("model") for p in problems) else "see problems"))

# The expected block of the model test (the Studio harness cannot read the JSON).
def lua_list(items):
    return "{ " + ", ".join(json.dumps(i) for i in items) + " }" if items else "{}"


gen = ["	-- BEGIN GENERATED EXPECTED", "	local EXPECTED = {",
       "		PageOrder = " + lua_list(targets["page_order"]) + ",", "		Pages = {"]
for page in targets["page_order"]:
    gen.append(f"			{page} = {{ Cards = {lua_list(expect_pages[page])}, Signal = {lua_list(expected_signals[page])} }},")
gen.append("		},")
gen.append("		Cards = {")
for card, (helper, literals) in expected_cards.items():
    info = targets["cards"][card]
    gen.append(f"			{card} = {{ Page = {json.dumps(info['page'])}, Helper = {json.dumps(helper)}, Literals = {lua_list(literals)}, "
               f"Action = {'true' if info['action_step'] else 'false'}, Placement = {json.dumps(info['placement']) if info['placement'] else 'nil'}, "
               f"Copy = {json.dumps(info['copy'])} }},")
gen.append("		},")
gen.append("	}")
gen.append("	-- END GENERATED EXPECTED")
test_path = HERE / "tests" / "ReplicatedStorage.Modules.Game.UIPulse.Shell.OnboardingModel_test.lua"
test_text = test_path.read_text(encoding="utf-8")
start = test_text.index("	-- BEGIN GENERATED EXPECTED")
finish = test_text.index("	-- END GENERATED EXPECTED") + len("	-- END GENERATED EXPECTED")
put(test_path, (test_text[:start] + chr(10).join(gen) + test_text[finish:]).encode("utf-8"))
print(f"contract counts: {len(targets['pages'])} pages, {len(targets['cards'])} cards")

for path in sorted((HERE / "after").glob("*.lua")):
    data = path.read_bytes()
    if b"\r" in data:
        problems.append(f"{path.name}: CR line ends")
    if len(data.decode('utf-8')) > 150000:
        problems.append(f"{path.name}: over 150,000 characters")

if problems:
    print("PROBLEMS:")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print("build_shell: all checks passed" + (" (check mode)" if CHECK else ""))
