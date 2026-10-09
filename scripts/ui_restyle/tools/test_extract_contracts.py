#!/usr/bin/env python3
"""Pins facts about the Classic source that scripts/ui_restyle/design/fact-check.md already verified
against live Studio, and checks that extract_contracts.py reproduces each one from the dump.

Plain asserts, stdlib only:  py -3 scripts/ui_restyle/tools/test_extract_contracts.py

If one of these fails after a new dump, the Classic source changed (or the extractor regressed).
Do not bend the expectation: read the source line named in the message first.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_contracts as X  # noqa: E402

UI = "ReplicatedStorage.Modules.Game.UI."
RACING = "ReplicatedStorage.Modules.Game.Racing."

RES = X.run(write=False)
ALL = RES["all_contracts"]
OWN = RES["contracts"]
PASSED = []


def by_name(name):
    hits = [c for p, c in ALL.items() if p.rsplit(".", 1)[-1] == name]
    assert len(hits) == 1, "expected one script named %s, found %d" % (name, len(hits))
    return hits[0]


def short(paths):
    return sorted(p.rsplit(".", 1)[-1] for p in paths)


def test(fn):
    fn()
    PASSED.append(fn.__name__)
    return fn


# ---------------------------------------------------------------------------- tokeniser
@test
def tokeniser_handles_comments_and_strings():
    src = 'local a = "x -- not a comment" --[==[ long\ncomment FindFirstChild("No") ]==]\n' \
          "local b = [[\nline]] -- tail FindFirstChild('No')\nlocal c = 'it\\'s'\n"
    T, V, L, S, E = X.tokenize(src)
    strs = [v for t, v in zip(T, V) if t == "str"]
    assert strs == ["x -- not a comment", "line", "it's"], strs
    assert "FindFirstChild" not in V
    assert L[V.index("b")] == 3 and L[V.index("c")] == 5, (L, V)


# ---------------------------------------------------------------------------- inventory
@test
def manifest_is_221_scripts():
    assert RES["summary"]["scripts_scanned"] == 221
    roots = {}
    for p in ALL:
        roots[p.split(".")[0]] = roots.get(p.split(".")[0], 0) + 1
    assert roots == {"ReplicatedStorage": 140, "ServerStorage": 73, "ReplicatedFirst": 4, "Workspace": 2,
                     "ServerScriptService": 1, "StarterPlayer": 1}, roots


@test
def clientbase_has_46_entries_with_listed_edges():
    entries = RES["entries"]
    assert len(entries) == 46, len(entries)
    names = [e["name"] for e in entries]
    assert len(set(names)) == 46 and not any(" " in n or "\n" in n for n in names)
    assert all(e["path"] in ALL for e in entries), [e["path"] for e in entries if e["path"] not in ALL]
    assert all(e["path"].rsplit(".", 1)[-1] == e["name"] for e in entries)
    edges = {e["name"]: e["dependencies"] for e in entries if e["dependencies"]}
    assert edges == {
        "ActivityClient": ["SharedTopNotificationUI"],
        "DealershipIntroClient": ["GarageUI"],
        "GarageEntranceClient": ["LoadingTransitionUI", "GarageUI"],
        "GaragePreviewPresentationClient": ["LightingClient"],
        "RaceEntryPresentationClient": ["LoadingTransitionUI"],
        "OwnedGarageClient": ["LoadingTransitionUI"],
        "OwnedGarageEnvironmentLightingClient": ["LightingClient"],
        "GarageUI": ["DriveSessionClient", "LoadingTransitionUI", "SharedTopNotificationUI"],
        "LightingPreviewClient": ["LightingClient"],
    }, edges
    tools = {e["name"]: e["tool"] for e in entries if e["tool"]}
    assert tools == {"TrailerVehicleCameraClient": "TrailerVehicleCameraEnabled", "LightingPreviewClient": "LightingPreviewEnabled",
                     "TrailerModeClient": "TrailerModeEnabled", "TrailerShotClient": "TrailerShotEnabled"}, tools
    # every entry has a contract, and ClientBase has exactly two require( calls: L3 and L108
    assert all(e["path"] in OWN for e in entries)
    cb = by_name("ClientBase")
    assert [r["line"] for r in cb["requires"]] == [3, 108], cb["requires"]
    assert cb["requires"][0]["target"] == "ReplicatedStorage.Modules.Core.ClientLifecycle"
    assert cb["requires"][1].get("target") is None  # the resolver: a path built at run time
    assert any(n["name"] == "StartupState" and n["line"] == 104 for n in cb["names"]["assigned"])


@test
def racing_ui_components_has_19_requirers():
    got = short(RES["required_by"][UI + "RacingUIComponents"])
    want = sorted([
        "InitialLoadingAndStartScreenClient", "ActivityClient", "GarageUI", "RaceBrowserClient",
        "RaceCountdownPresentationClient", "RaceEntryPresentationClient", "RaceQueueClient",
        "RaceSessionPresentationClient", "RaceTimeTrialResultCoachClient", "DesktopFreeRoamHudUI", "FullMapUI",
        "GarageBrowserUI", "GarageComponents", "GarageInteriorModeUI", "GarageWorkspaceUI", "MobileFreeRoamHudUI",
        "OnboardingClient", "OwnedGarageBrowserUI", "OwnedGarageWorkspaceUI"])
    assert len(got) == 19 and got == want, sorted(set(got) ^ set(want))


@test
def garage_components_has_9_requirers():
    got = short(RES["required_by"][UI + "GarageComponents"])
    want = sorted(["GarageUI", "RaceEntryPresentationClient", "DesktopFreeRoamHudUI", "GarageBrowserUI",
                   "GarageInteriorModeUI", "GarageWorkspaceUI", "MobileFreeRoamHudUI", "OwnedGarageBrowserUI",
                   "OwnedGarageWorkspaceUI"])
    assert len(got) == 9 and got == want, sorted(set(got) ^ set(want))


@test
def classic_owners_requiring_classic_owners():
    def req(name):
        return {(r["line"], r["target"].rsplit(".", 1)[-1]) for r in by_name(name)["requires"] if r.get("target")}
    assert {(13, "GarageBrowserUI"), (13, "GarageWorkspaceUI"), (13, "GarageComponents")} <= req("GarageUI")
    assert req("OwnedGarageClient") == {(9, "OwnedGarageBrowserUI"), (9, "OwnedGarageWorkspaceUI"),
                                        (9, "GarageInteriorModeUI"), (9, "GarageInteriorTransitionUI")}
    assert (52, "OwnedGarageWorkspaceUI") in req("GarageInteriorModeUI")   # fact-check section 4 item 1
    assert req("GarageInteriorTransitionUI") == {(6, "OwnedGarageBrowserUI"), (6, "OwnedGarageWorkspaceUI")}
    # the two HUDs find the map by name, not by require path literal
    for hud, line in (("DesktopFreeRoamHudUI", 960), ("MobileFreeRoamHudUI", 260)):
        hits = [l for l in by_name(hud)["names"]["looked_up"] if l.get("name") == "FullMapUI"]
        assert [h["line"] for h in hits] == [line] and hits[0]["method"] == "FindFirstChild", hits


@test
def loading_scripts_require_lines():
    rt = {r["line"]: r["target"] for r in by_name("LoadingTransitionRuntime")["requires"]}
    assert rt[8] == "ReplicatedFirst.Loading.LoadingScreenView", rt
    st = {r["line"]: r["target"] for r in by_name("InitialLoadingAndStartScreenClient")["requires"]}
    assert st[22] == UI + "RacingUIComponents" and st[21] == "ReplicatedFirst.Loading.LoadingTransitionRuntime", st
    assert by_name("RaceTransitionClient")["requires"] == []


@test
def owned_garage_workspace_ui_shape():
    c = by_name("OwnedGarageWorkspaceUI")
    assert c["source_lines"] in (189, 190), c["source_lines"]
    assert {r["line"] for r in c["requires"]} == {12}
    assert short(r["target"] for r in c["requires"]) == ["GarageComponents", "GarageWorkspaceUI",
                                                         "PresentationAudioBridge", "RacingUIComponents"]
    assert c["screenguis"]["created"] == [] and c["instances_created_by_class"] == {}


@test
def activity_views():
    ac = by_name("ActivityClient")
    views = sorted(r["target"].rsplit(".", 1)[-1] for r in ac["requires"] if r.get("via") == "literal list")
    assert views == ["CourierClientView", "DuelClientView", "PassengerClientView", "TaxiClientView"], views
    for v in ("CourierClientView", "TaxiClientView"):
        assert "JobClient" in short(r["target"] for r in by_name(v)["requires"])
    for v in views + ["JobClient"]:
        assert any(p.endswith("." + v) for p in OWN), v + " has no contract"


# ---------------------------------------------------------------------------- input
@test
def full_map_binds_button_select():
    acts = by_name("FullMapUI")["context_actions"]
    hit = [a for a in acts if "Enum.KeyCode.ButtonSelect" in a.get("inputs", [])]
    assert len(hit) == 1, acts
    a = hit[0]
    assert a["name"] == "FullMapToggle" and a["method"] == "BindActionAtPriority"
    assert a["priority_expr"] == "Enum.ContextActionPriority.High.Value" and a["priority"] == 3000
    assert 715 <= a["line"] <= 723, a["line"]
    steps = [s for s in by_name("FullMapUI")["run_service"]["render_steps"] if s["method"] == "BindToRenderStep"]
    assert [(s["name"], s["priority"]) for s in steps] == [("FullMapUI", 2010)], steps


@test
def set_core_gui_enabled_only_in_trailer_mode_client():
    users = sorted(p.rsplit(".", 1)[-1] for p, c in ALL.items()
                   if any(x["method"] == "SetCoreGuiEnabled" for x in c["startergui_core"]))
    assert users == ["TrailerModeClient"], users


@test
def preferred_input_is_unused():
    assert RES["summary"]["preferred_input_scripts"] == []
    for c in ALL.values():
        assert not any(m["member"] == "PreferredInput" for m in c["user_input_service"]["members_used"])


@test
def touch_gates():
    def reads(name):
        return {(m["member"], m["line"]) for m in by_name(name)["user_input_service"]["members_used"] if m["kind"] == "read"}
    assert ("TouchEnabled", 12) in reads("MobileDriveControlsClient")
    assert ("TouchEnabled", 13) in reads("MobileFreeRoamHudUI")
    d = reads("DesktopFreeRoamHudUI")
    assert {m for m, l in d if 16 <= l <= 19} == {"TouchEnabled", "KeyboardEnabled", "MouseEnabled"}, d


@test
def foundation_confirmation_overlay():
    f = by_name("ResponsiveUIFoundation")
    g = [x for x in f["screenguis"]["created"] if x.get("Name") == "SharedConfirmationOverlay"]
    assert len(g) == 1 and g[0]["DisplayOrder"] == 1250 and 326 <= g[0]["line"] <= 332, g
    binds = [a for a in f["context_actions"] if a["method"] == "BindActionAtPriority"]
    assert len(binds) == 1 and binds[0]["priority"] == 10000, binds
    assert binds[0]["inputs"] == ["Enum.KeyCode.Escape", "Enum.KeyCode.ButtonB"]
    # the action name is built at run time: reported as a pattern, never as a guessed name
    assert binds[0]["name"] is None and binds[0]["name_pattern"] == "SharedConfirmationExit_*"
    assert {"ProjectEconomy", "BindReplicatedCash"} <= {a["name"] for a in f["public_api"]}


# ---------------------------------------------------------------------------- onboarding
@test
def onboarding_locks_gui_buttons_named_car_race_garage():
    locks = RES["onboarding"]["name_locks"]
    assert sorted(l["name"] for l in locks) == ["Car", "Garage", "Race"], locks
    for l in locks:
        assert l["in_function"] == "applyLocks" and l["line"] == 669
        assert l["receiver_isa"] == ["GuiButton"]
        assert l["properties_written"] == ["Active", "Selectable", "AutoButtonColor"]


@test
def onboarding_targets_table():
    ob = RES["onboarding"]
    assert ob["missing_tables"] == []
    assert len(ob["pages"]) == 19 and len(ob["page_order"]) == 19, (len(ob["pages"]), ob["page_order"])
    assert ob["pages"]["CustomisationHome"]["cards"] == ["J1", "J2", "J3"]
    ids = [ob["cards"][c]["targets"][0]["literals"] for c in ("J1", "J2", "J3")]
    assert ids == [["AddModules"], ["UpgradeModules"], ["PaintShop"]], ids
    assert "attribute:CanonicalGarageCardId" in ob["cards"]["J1"]["targets"][0]["match_on"]
    assert ob["pages"]["CustomisationHome"]["signal_targets"][0]["match_on"] == ["attribute:TutorialWorkspace", "attribute:TutorialPageId"]
    assert ob["cards"]["O1"]["targets"][0] == {"helper": "textGroup", "literals": ["TIME TRIAL", "RACE"], "match_on": ["text"], "line": 196}
    assert ob["cards"]["Q1"]["targets"][0]["literals"] == ["TierE", "TierD", "TierC", "TierB", "TierA", "TierS"]
    assert set(ob["texts_used"]) == {"DEALERSHIP", "RACE", "TIME TRIAL"}, sorted(ob["texts_used"])
    need = {"Car", "Race", "Garage", "CardContent", "TeleportToStart", "LapSelector", "PrizeSummary", "MedalTargets",
            "RaceFormat", "DriftLeft", "DriftRight", "Boost", "AccessControls", "CanonicalGarageGui", "CanonicalCanvas",
            "CanonicalGarageBrowser", "RaceBrowser", "RaceEntryPresentation", "OwnedGarageBrowser", "TierE", "TierS"}
    assert need <= set(ob["names_used"]), sorted(need - set(ob["names_used"]))
    assert {"CanonicalGarageCard", "CanonicalGarageCardId", "TutorialWorkspace", "TutorialPageId",
            "MobileMajorMenuOpen"} <= set(ob["attributes_used"])
    # every card of every page has a resolver
    for page, rec in ob["pages"].items():
        for card in rec["cards"]:
            assert ob["cards"][card]["targets"], (page, card)


# ---------------------------------------------------------------------------- attributes
@test
def mobile_major_menu_open_writer_and_four_readers():
    a = RES["player_attributes"]["attributes"]["player:MobileMajorMenuOpen"]
    assert short(a["writer_scripts"]) == ["MobileFreeRoamHudUI"], a["writer_scripts"]
    assert short(a["reader_scripts"]) == ["FullMapUI", "GarageInteriorModeUI", "MobileDriveControlsClient", "OnboardingClient"]
    # FullMapUI names the attribute in a literal list at L450 and reads it in the loop at L454
    assert any(r["script"].endswith("FullMapUI") and r["line"] == 454 and r.get("via") == "literal list" for r in a["readers"]), a["readers"]
    for name in ("MobileFreeRoamCarMenuOpen", "MobileControlMode"):
        w = RES["player_attributes"]["attributes"]["player:" + name]["writer_scripts"]
        assert UI + "MobileFreeRoamHudUI" in w, (name, w)


# ---------------------------------------------------------------------------- modules
@test
def route_guide_public_api():
    api = by_name("RouteGuide")["public_api"]
    assert [a["name"] for a in api] == ["Changed", "Arrived", "SetDestination", "Clear", "GetActive", "Destinations",
                                        "SetDestinationById", "Update", "newMapRenderer"], [a["name"] for a in api]
    get_active = next(a for a in api if a["name"] == "GetActive")
    assert get_active["line"] == 89 and get_active["params"] == []


@test
def canonical_host_screengui():
    g = by_name("GarageComponents")["screenguis"]["created"]
    assert len(g) == 1 and g[0]["Name"] == "CanonicalGarageGui" and g[0]["DisplayOrder"] == 40 and g[0]["Enabled"] is True
    assert 298 <= g[0]["line"] <= 301
    users = RES["reserved"]["names"]["CanonicalGarageGui"]["consumers"]
    assert "OnboardingClient" in short(u["script"] for u in users)


@test
def free_roam_exit_button_client_is_a_no_op():
    c = by_name("FreeRoamVehicleExitButtonClient")
    assert not any(X.counts(c).values()), X.counts(c)


@test
def time_trial_server_prompt_style_default():
    p = by_name("TimeTrialServer")["proximity_prompts"]
    lines = sorted(w["line"] for x in p for w in x["writes"]
                   if w["property"] == "Style" and w["value"] == {"expr": "Enum.ProximityPromptStyle.Default"})
    assert lines == [1298, 1311], lines


# ---------------------------------------------------------------------------- cross-reference tables
@test
def reserved_names_cover_what_source_supports():
    names = RES["reserved"]["names"]
    for n in ("DesktopFreeRoamHud", "DesignRoot", "ModalLayer", "Controls", "CarPanel", "Minimap", "DriftLeft", "DriftRight",
              "Boost", "RaceBrowser", "CardContent", "TeleportToStart", "RaceEntryPresentation", "LapSelector", "PrizeSummary",
              "MedalTargets", "RaceFormat", "CanonicalGarageGui", "CanonicalCanvas", "CanonicalGarageBrowser",
              "CanonicalGarageWorkspace", "OwnedGarageBrowser", "AccessControls", "SharedTopNotification",
              "LoadingSafeContent", "Car", "Race", "Garage"):
        assert n in names, n + " missing from _reserved_names"
        assert names[n]["definers"] and names[n]["consumers"]
        assert not ({d["script"] for d in names[n]["definers"]} >= {c["script"] for c in names[n]["consumers"]})
    # Names on the plan's hand list (2.3) that the dump does NOT support as "looked up by another script":
    # only their own definer looks them up (find-and-destroy or adopt on start).
    own = RES["reserved"]["names_looked_up_only_by_their_definer"]
    for n in ("MobileDriveControls_Phase1", "ActivityHud", "SharedConfirmationOverlay"):
        assert n not in names and n in own, n
    # TierE..TierS are looked up by onboarding but assigned as "Tier" .. <run-time value>: reported, not guessed.
    und = RES["reserved"]["lookups_without_static_definer"]
    for n in ("TierE", "TierD", "TierC", "TierB", "TierA", "TierS"):
        assert n not in names and n in und, n
        pats = {(p["script"].rsplit(".", 1)[-1], p["pattern"]) for p in und[n]["possible_pattern_definers"]}
        assert ("RaceEntryPresentationClient", "Tier*") in pats, pats


@test
def screenguis_table():
    sg = {g["Name"]: g for g in RES["screenguis"]["screenguis"] if isinstance(g.get("Name"), str)}
    want = {"DesktopFreeRoamHud": 85, "MobileFreeRoamHud_Phase1": 88, "MobileDriveControls_Phase1": 96, "ActivityHud": 84,
            "RaceBrowser": 170, "RaceEntryPresentation": 180, "OwnedGarageBrowser": 171, "CanonicalGarageGui": 40,
            "SharedTopNotification": 1100, "SharedConfirmationOverlay": 1250, "RaceCountdown": 205, "SharedInRaceHUD": 155,
            "UnifiedRaceResults": 220, "RaceQueueBanner": 190}
    for name, order in want.items():
        assert name in sg, name
        assert sg[name]["DisplayOrder"] == order, (name, sg[name]["DisplayOrder"])
        assert sg[name]["ResetOnSpawn"] is False, name
    assert sg["FullMap"]["Enabled"] is False
    assert {"LoadingBackground", "LoadingSafeContent", "Onboarding"} <= set(sg)


@test
def remotes_table():
    rem = RES["remotes"]["remotes"]
    onb = rem["ReplicatedStorage.Remotes.Onboarding.OnboardingInvoke"]
    assert set(onb["actions"]) == {"GetState", "MarkSeen"} and onb["actions"]["MarkSeen"]["payload_keys"] == ["PageId"]
    assert onb["client_actions_not_declared_by_server"] == []
    tp = rem["ReplicatedStorage.Remotes.UI.FreeRoamHudTeleportInvoke"]["actions"]["TeleportToDealership"]
    assert short({c["script"] for c in tp["callers"]}) == ["DesktopFreeRoamHudUI", "InitialLoadingAndStartScreenClient", "MobileFreeRoamHudUI"]
    rb = rem["ReplicatedStorage.Remotes.Racing.RaceBrowserTeleportInvoke"]["actions"]["TeleportToRaceStart"]
    assert rb["payload_keys"] == ["EventId", "Mode"]
    # actions reached through a local wrapper (call(action, payload) around InvokeServer) are resolved
    q = rem["ReplicatedStorage.Remotes.Racing.RaceQueueRequest"]["actions"]
    assert q["JoinQueue"]["payload_keys"] == ["EventId", "VehicleId"] and "wrapper" in q["JoinQueue"]["callers"][0]["via"]
    ack = [r for k, r in rem.items() if "AcknowledgeStagingReady" in r["actions"]]
    assert len(ack) == 1 and short({c["script"] for c in ack[0]["actions"]["AcknowledgeStagingReady"]["callers"]}) == ["RaceTransitionClient"]
    # no client action is missing from a matching server Net spec
    for name, r in rem.items():
        assert not r.get("client_actions_not_declared_by_server"), (name, r["client_actions_not_declared_by_server"])


@test
def unresolved_items_are_reported_not_guessed():
    total = 0
    for p, c in OWN.items():
        for u in c["unresolved"]:
            total += 1
            assert isinstance(u["line"], int) and u["line"] >= 1 and u["detail"], (p, u)
        for cat in ("assigned", "looked_up"):
            for item in c["names"][cat]:
                assert "name" in item, (p, item)
                if item["name"] is None:
                    assert item.get("name_expr"), (p, item)
    assert total == RES["summary"]["unresolved"] and total > 0


@test
def written_files_match_a_fresh_run():
    out = X.OUT
    if not (out / "INDEX.md").exists():
        raise AssertionError("contracts not written yet: run extract_contracts.py first")
    for name, obj in (("_reserved_names.json", RES["reserved"]), ("_player_attributes.json", RES["player_attributes"]),
                      ("_screenguis.json", RES["screenguis"]), ("_remotes.json", RES["remotes"]),
                      ("_onboarding_targets.json", RES["onboarding"])):
        assert json.loads((out / name).read_text(encoding="utf-8")) == json.loads(json.dumps(obj)), name + " is stale"
    files = {p.name for p in out.glob("*.json") if not p.name.startswith("_")}
    assert files == {c["contract_file"] for c in OWN.values()}, files ^ {c["contract_file"] for c in OWN.values()}
    for c in OWN.values():
        assert json.loads((out / c["contract_file"]).read_text(encoding="utf-8")) == json.loads(json.dumps(c)), c["contract_file"]
    assert (out / "INDEX.md").read_text(encoding="utf-8") == X.index_md(RES)


if __name__ == "__main__":
    print("%d tests passed" % len(PASSED))
    print(json.dumps(RES["summary"]))
