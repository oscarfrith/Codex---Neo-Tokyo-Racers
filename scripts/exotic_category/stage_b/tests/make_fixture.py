"""Write tests/fixtures/balance.json: a STAND-IN for scripts/exotic_category/balance/balance.json.

It copies live Piercer donor numbers from the baseline capture so that build_content.py and test_content.py
can run before the real balance data exists. It is marked "fixture": true; an installer built from it refuses
to APPLY. Never use these numbers in the game.

Usage: py -3 scripts/exotic_category/stage_b/tests/make_fixture.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import build_content as bc  # noqa: E402

VARIANT_FIELDS = {"STANDARD": ("Standard", 10), "LIGHTWEIGHT": ("Lightweight", 20), "POWER": ("Power", 30)}


def main():
    ids = bc.load_json(os.path.join(bc.DATA_DIR, "ids.json"))
    reference = bc.capture_reference(bc.load_json(bc.CAPTURE_PATH))
    mesh = bc.load_mesh()
    constants = bc.piercer_cockpit_constants(reference)
    tier_donor = {}
    for cid, attrs in reference["cockpits"].items():
        tier_donor.setdefault(attrs["TargetTier"], cid)
    identity_like = {"CockpitId", "V2PublishedCockpitId", "CategoryId", "DisplayName", "TemplateType", "MenuImage", "PreviewImage",
                     "StandardAudioProfileId"}
    out = {"fixture": True, "_note": "STAND-IN test data copied from Piercer donors. Not balance data. Not installable.", "cockpits": {}, "modules": {}}
    for c in ids["cockpits"]:
        donor = reference["cockpits"][tier_donor[c["tier"]]]
        attrs = {k: v for k, v in donor.items() if k not in constants and k not in identity_like and not k.startswith("Default")}
        attrs.update({"Price": c["price"], "TargetStockPI": c["targetStockPI"], "TargetTier": c["tier"]})
        out["cockpits"][c["cockpitId"]] = {"attributes": attrs, "stockPI": c["targetStockPI"], "stockTier": c["tier"]}
        # The stand-in core modules carry their donor's Price, so that is the core variant price here.
        variant_price = reference["modules"][next(s for s in ids["slots"] if s["kind"] == "core")["attributeDonor"].replace("{VARIANT}", "POWER")]["Price"]
        for slot in ids["slots"]:
            core = slot["kind"] == "core"
            for variant in bc.module_variants(ids, mesh, slot, c["n"]):
                mid = bc.module_id(slot, c["n"], variant)
                donor_id = slot["attributeDonor"].replace("{VARIANT}", variant or "")
                donor_attrs = reference["modules"][donor_id]
                skip = {"ModuleId", "V2PublishedModuleId", "CategoryId", "SourceCockpitId", "ModuleType", "ModuleFolder", "ModuleSlot",
                        "EnginePosition", "RearEngine", "DisplayName", "ModuleName", "TemplateType", "SourceCockpitDisplayName"} | bc.MODULE_PASSTHROUGH
                attrs = {k: v for k, v in donor_attrs.items() if k not in skip}
                if core:
                    attrs["VariantName"], attrs["VariantOrder"] = VARIANT_FIELDS[variant]
                else:  # mesh/INTEGRATION.md E1, E2: locked to the kit's cockpit; a stock slot is a quarter, GT half and EVO the whole core variant price
                    attrs["SourceCockpitId"], attrs["SourceCockpitDisplayName"] = c["cockpitId"], c["displayName"]
                    attrs["VariantName"], attrs["VariantOrder"] = bc.BODY_VARIANT[variant]  # F4
                    if variant:  # F1: a stand-in stat step, one on GT and two on EVO
                        stat = "EngineOutput" if slot["slotId"] == "RearBody" else "Downforce"
                        attrs[stat] = attrs["PerformanceDelta_" + stat] = attrs[stat] + {"GT": 1, "EVO": 2}[variant]
                    if bc.module_variants(ids, mesh, slot, c["n"]) != [None]:
                        attrs["Price"] = {None: variant_price // 4, "GT": variant_price // 2, "EVO": variant_price}[variant]
                entry = {"attributes": attrs}
                if slot["slotId"] in ("FrontBody", "RearBody"):
                    prefix = "Nose" if slot["slotId"] == "FrontBody" else "Deck"
                    entry["upgradePaths"] = [
                        {"PathId": prefix + "Ducting", "attributes": {"DisplayName": prefix + " Ducting", "MaxPoints": 3, "Order": 1, "DeltaFlat_Downforce": 2}},
                        {"PathId": prefix + "Lightening", "attributes": {"DisplayName": prefix + " Lightening", "MaxPoints": 3, "Order": 2, "DeltaFlat_Weight": -3}},
                    ]
                else:
                    entry["upgradePathDonor"] = donor_id
                out["modules"][mid] = entry
    path = os.path.join(HERE, "fixtures", "balance.json")
    with open(path, "w", encoding="ascii", newline="\n") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print("wrote %s (%d cockpits, %d modules)" % (os.path.relpath(path, bc.REPO).replace("\\", "/"), len(out["cockpits"]), len(out["modules"])))


if __name__ == "__main__":
    main()
