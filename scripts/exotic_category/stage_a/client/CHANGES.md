# Exotic Stage A: client sources

Target: Space Racers Backup v2, place 133417340424236. Lane: High-Risk. Status: **generated, not installed**.
Before-sources: the `exotic-before` blobs. Live sources were checked against the blobs (length and Adler-32) before and after the test runs; they match.
After-sources: `after/<ScriptName>.lua`, made by `build.py` (exact single-occurrence edits over the blobs, LF, ASCII). Re-running `build.py` gives the same bytes.
`build.py` also writes `before/<ScriptName>.lua`: the blob bytes, sha256 checked against the manifest. `run_checks.lua` uses them after APPLY.

Seven owners change. Twenty-two hunks. No new remote, action, request field, saved field or owner. Every new behaviour needs data that Piercer does not have.

| Owner | Before bytes | After bytes | After sha256 (first 12) |
|---|---:|---:|---|
| `ReplicatedStorage.Modules.Game.UI.GarageWorkspaceUI` | 49461 | 49694 | `a50217bc1209` |
| `ReplicatedStorage.Modules.Game.Garage.GarageUI` | 59132 | 60197 | `5362eef9c37b` |
| `ReplicatedStorage.Modules.Game.UI.GarageBrowserUI` | 22249 | 22271 | `43ef6a5db683` |
| `ReplicatedStorage.Modules.Game.UI.GarageModuleCardViewModel` | 3452 | 4218 | `a35d10da508b` |
| `ReplicatedStorage.Modules.Game.Garage.GarageVehiclePreviewProfile` | 4256 | 4767 | `fdc61964f667` |
| `ReplicatedStorage.Modules.Game.Vehicles.Performance.VehiclePerformanceResolver` | 8544 | 9794 | `9b8b72400bf5` |
| `ReplicatedStorage.Modules.Game.Garage.PreviewCameraClient` | 8122 | 8158 | `b41c3f9e8593` |

Review round 1 (2026-10-02) added hunks U7-U10, B1 and V4 and the `before/` folder. The other four after-sources are byte for byte as first delivered. See "Review round 1" at the end.

Line numbers below are before-source line numbers.

---

## 1. GarageWorkspaceUI

### Hunk W1: two artwork rows (after line 18)

Before:

```lua
	{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBumper",DisplayName="Front Bumper",TargetId="FrontBumper",SortOrder=80,ShowInBuild=true,ShowInCustomise=true},
```

After:

```lua
	{Name="Boost",DisplayName="Boost",TargetId="Boost",SortOrder=70,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBody",DisplayName="Front Body",TargetId="FrontBody",SortOrder=72,ShowInBuild=true,ShowInCustomise=true},
	{Name="RearBody",DisplayName="Rear Body",TargetId="RearBody",SortOrder=74,ShowInBuild=true,ShowInCustomise=true},
	{Name="FrontBumper",DisplayName="Front Bumper",TargetId="FrontBumper",SortOrder=80,ShowInBuild=true,ShowInCustomise=true},
```

Why: the slot cards (Add Modules), the Upgrade rail and the Paint rail are all built from this table. A slot with no row is unreachable.

Piercer unchanged:
- The eleven existing rows are untouched. `Artwork.ForPage` sorts by `SortOrder`; 72 and 74 are unused today (code and live config checked), so the relative order of the old rows cannot change.
- `GarageUI` shows a row only when `slot(art.TargetId)` exists in the current category (lines 329-330, 382-383, 539-540). Piercer has no `FrontBody` or `RearBody` slot, so both rows are skipped on all three pages. Eight slot cards, eight Upgrade rail items, twelve Paint targets, as today.
- `Artwork.ResolveImage(key)` only matches the new rows for the keys `FrontBody` and `RearBody`. No Piercer card or rail item uses those ids.
- `Artwork.Audit` counts config folders against rows. It only runs when `RuntimeAuditEnabled` is true (live: false). With `config_ops.json` installed the count is 13 of 13.

Ten slots: order is Engine1, Engine2, Stabilisers, Boost, FrontBody, RearBody, FrontBumper, RearBumper, SidePods, RearSpoiler (artwork `SortOrder`, not slot `Order`). Layout needs no change: the card carousel and the left rail already scroll with eight (`UpdateHorizontalCardCanvas`, `UpdateCategoryArrows`).

Mobile: there is no separate mobile path. `WorkspaceUI:Layout` calls the same `Shared.LayoutGarageShell` with a touch scale, and the same card and rail components render. No mobile-only slot list exists (all client sources scanned).

---

## 2. GarageUI

### Hunk U1: slot label helper (new line after line 63)

After (new line):

```lua
local function slotLabel(s,art) local label=tostring(s and s.RailLabel or ""); if label~="" then return label end; return art.DisplayName end
```

### Hunk U2: Add Modules slot card (line 332)

Before: `...,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,...`
After: `...,ImageKey=art.TargetId,DisplayName=slotLabel(s,art),Badge=installed and "EQUIPPED" or nil,...`

### Hunk U3: Upgrade rail item (line 385)

Before: `table.insert(c.LeftItems,{Id=s.SlotId,Text=art.DisplayName,ImageKey=art.TargetId,...`
After: `table.insert(c.LeftItems,{Id=s.SlotId,Text=slotLabel(s,art),ImageKey=art.TargetId,...`

### Hunk U4: Paint rail item (line 541)

Before: `Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,...`
After: `Text=id=="THRUST_COLOR" and "Thrust" or slotLabel(slot(id),art),ImageKey=art.TargetId,...`

Why (U1-U4): the Exotic slot labels ("Main Turbine", "Nose", "Engine Deck", ...) arrive as the slot field `RailLabel`. These are the only three places a slot label is drawn. No GarageUI message names a slot.

Piercer unchanged: Piercer slots have no `RailLabel`, so `slotLabel` returns `art.DisplayName`, the same string as today. For the non-slot paint targets (`ALL`, `Cockpit`) `slot(id)` is nil and the artwork label is returned. `"Thrust"` and the Underglow item are untouched. An empty `RailLabel` counts as absent.

### Hunk U5: owned module card (line 347) and Hunk U6: shop module card (line 353)

Before (both): `{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,...`
After (both): `{Id=row.Id,CardKind="Listing",VehicleName=row.Title,Variant=row.Tag,...`

Why: the card's top line and tag come from the new row fields (section 3). `DisplayName=row.Variant` stays; the card only uses it when there is no tag.

Piercer unchanged: for a module without `CardTitle`, `row.Title == row.VehicleName` and `row.Tag == row.Variant` (same values, not recomputed). The card receives identical props. Order, footer, price, badge, lock and actions are not touched.

### Hunk U7: which categories are listed (two new lines and a comment after line 57)

After (new lines, directly after `currentCategory`):

```lua
-- A category the server marks PurchaseDisabled is not on sale. The dealership leaves it out; Customisation keeps it for a player who owns one of its vehicles.
local function categoryListed(c) if c.PurchaseDisabled~=true then return true end; if State.ShopMode~="Customisation" then return false end; local p=State.Profile or {}; for _,vehicle in pairs(p.Vehicles or {}) do local item=vehicle.CockpitInstanceId and p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local id=item and tostring(item.TemplateId or "") or ""; for _,k in ipairs(c.Cockpits or {}) do if id~="" and tostring(k.CockpitId)==id then return true end end end; return false end
local function listedCategories() local result={}; for _,c in ipairs(allCategories()) do if categoryListed(c) then table.insert(result,c) end end; return result end
```

### Hunk U8: the ALL list (line 58, `combinedCategory`)

Before: `...; for _,source in ipairs(allCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do ...`
After: `...; for _,source in ipairs(listedCategories()) do for _,cockpit in ipairs(source.Cockpits or {}) do ...`

### Hunk U9: the browser's category (line 59, `browserCategory`)

Before: `local function browserCategory() return State.BrowseAll and combinedCategory() or currentCategory() end`
After: `local function browserCategory() local c=currentCategory(); if State.BrowseAll or (c and not categoryListed(c)) then return combinedCategory() end; return c end`

### Hunk U10: the category buttons (line 186, `browser:Show`)

Before: `...,Category=browserCategory(),Cash=State.Profile.Cash,...`
After: `...,Category=browserCategory(),Categories=listedCategories(),Cash=State.Profile.Cash,...`

Why (U7-U10): INTERFACE says owned vehicles are never hidden or blocked. With the flag off, an owner's garage still needs the Exotic category data (slots, modules, cockpits), so the server has to keep sending the category, marked as not on sale. These hunks are the client half: a category with `PurchaseDisabled=true` is never offered in the dealership (ALL list, category buttons, category tab) and is shown in Customisation only to a player who owns one of its vehicles. Outside the browser nothing changes: `currentCategory()` resolves the vehicle's own category, so the slot rail, Add Modules, Upgrade and Paint work for the owned vehicle. GarageUI owns the rule; the browser only draws the list it is given.

The ownership test follows `Browser:Rows` exactly (vehicle, its cockpit instance, the template id found in the category's cockpits), so a category button appears exactly when the category would have at least one row.

**The server half is not built yet.** See "Flag off with an owned Exotic" below. Until the server sends `PurchaseDisabled`, U7-U10 and B1 do nothing.

Piercer unchanged: no Piercer category has `PurchaseDisabled`, so `categoryListed` returns true on its first test and never reads the profile. `listedCategories()` is then a new list holding the same category tables in the same order as `allCategories()`, so `combinedCategory()` copies the same cockpits in the same order, and `browserCategory()` returns the same value as the old expression for every `BrowseAll` / `CategoryId` combination, including an empty catalogue (`nil` as before). `currentCategory()`, `categoryById` and `allCategories` are untouched. Checked against the before source by `tests.lua` (the shipped lines are extracted and run).

GarageUI compiles after the change (checked with `loadstring` in Studio; three extra locals in `Client.start`: `slotLabel`, `categoryListed`, `listedCategories`; a rough count gives about 121 against the limit of 200).

**U5 and U6 need the view-model change, and U10 is drawn by B1. Install all seven sources together.**

---

## 2b. GarageBrowserUI

### Hunk B1: category buttons (line 115, `Browser:Show`)

Before: `local categories={}; for _,c in ipairs((context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end; ...`
After: `local categories={}; for _,c in ipairs(context.Categories or (context.State.Catalog and context.State.Catalog.Categories) or {}) do table.insert(categories,c) end; ...`

Why: the browser read the whole catalogue for its buttons, so a category that is not on sale would still get a button. It now draws the list GarageUI passes (U10). `Browser:Rows` is not changed: it only ever receives the category GarageUI chose (U8, U9).

Piercer unchanged: GarageUI is the only caller (live `script_grep`). For a Piercer-only catalogue it passes the same category tables in the same order; the copy, the sort and the button loop are untouched, so the same buttons appear in the same order. Without `context.Categories` the expression is today's. The rest of the file is byte for byte the before source (asserted by `tests.lua`).

---

## 3. GarageModuleCardViewModel

### Hunk V1: `ViewModel.CardText` (new, before `ViewModel.Owned`)

```lua
-- Card text. Title is the module CardTitle when it has one, else the source vehicle name as before.
-- Tag is the variant as before; a module with a CardTitle shows its own VariantName (never "Level n").
function ViewModel.CardText(row)
	local module=row.Module; local title=tostring(module and module.CardTitle or ""); local explicit=tostring(module and module.VariantName or "")
	row.Title=title~="" and title or row.VehicleName
	row.Tag=(title~="" and explicit~="" and not string.match(explicit,"^Level %d+$")) and explicit or row.Variant
	return row
end
```

### Hunk V2 (line 29, owned rows) and Hunk V3 (line 47, shop rows)

Before: `table.insert(rows,{ ...row... })`
After: `table.insert(rows,ViewModel.CardText({ ...the same row, byte for byte... }))`

Why: a card title from the module's own `CardTitle`. Rows keep `VehicleName` and `Variant` exactly as before because the sort comparators and the lock line (`BUY <VEHICLE> TO UNLOCK`) use them. `Title` and `Tag` are display-only additions.

Piercer unchanged: the row constructors are untouched, so every existing field has the same value, and the two sort functions are untouched, so the order is the same. Piercer modules have no `CardTitle`, so `Title = VehicleName` and `Tag = Variant`, and `ViewModel.Variant` takes the same path as before (V4 below).

### Hunk V4: `ViewModel.Variant` (two new lines after line 8)

Before:

```lua
	if explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end
	local name=string.lower(tostring(module and (module.DisplayName or module.ModuleId) or ""))
```

After:

```lua
	if explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end
	-- A module with a CardTitle is named freely, so its name is never read as a variant.
	if tostring(module and module.CardTitle or "")~="" then return "Standard" end
	local name=string.lower(tostring(module and (module.DisplayName or module.ModuleId) or ""))
```

Why: `row.Variant` is the sort key (and the card's fallback text). It is found by searching the display name for "power" or "lightweight" when `VariantName` is not one of the three. A titled module has a free-text name, so that search could give a sort key that disagrees with the shown tag: a part named "Power Scoop" with `VariantName="Track"` would show TRACK and sort as Power. The name of a titled module is now never searched. Its variant is its explicit `VariantName` when that is one of the three, else Standard.

Piercer unchanged: a module without `CardTitle` skips the new line and runs the same statements as before. `tests.lua` compares `Variant` before against after for Piercer modules and for odd names.

Tag and sort key for a module with `CardTitle`:
- Exotic core modules: `VariantName` is Standard, Lightweight or Power. Same tag, colour and sort key as a Piercer family module.
- Exotic body modules: no `VariantName` attribute (checked in `balance/balance.json`: 36 of 36), so the server sends its derived value, which is `Standard` for these ids. The card reads `SHOVEL NOSE` / `STANDARD` and sorts as Standard.
- "Level n" (the server's derived value for ids containing `LVL`) is never shown; the tag is Standard.
- A title that contains "power" or "lightweight" never turns a body part's tag or sort key into a variant.
- If Stage B wants the kit name as the tag ("TRACK", "WEDGE"), set `VariantName` on the body modules. The tag shows it and the sort key stays Standard. No further code change is needed.

---

## 4. GarageVehiclePreviewProfile

### Hunk P1 (lines 28-36): optional defaults in `defaultModules`

Before:

```lua
local function defaultModules(cockpit)
	cockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId
	return {
		Engine1=engine,
		Engine2=cockpit.DefaultRearEngineModuleId or cockpit.DefaultEngineBModuleId or engine,
		Stabilisers=cockpit.DefaultStabilisersModuleId or cockpit.DefaultStabiliserModuleId,
		Boost=cockpit.DefaultBoostModuleId,
	}
end
```

After:

```lua
-- Default<X>ModuleId keys the four legacy slots own. Any other Default<SlotId>ModuleId key is an optional default for that slot.
local legacyDefaultKeys={Engine=true,FrontEngine=true,RearEngine=true,EngineB=true,Stabilisers=true,Stabiliser=true,Boost=true,Engine1=true,Engine2=true}
local function defaultModules(cockpit)
	cockpit=cockpit or {}; local engine=cockpit.DefaultFrontEngineModuleId or cockpit.DefaultEngineModuleId
	local result={
		Engine1=engine,
		Engine2=cockpit.DefaultRearEngineModuleId or cockpit.DefaultEngineBModuleId or engine,
		Stabilisers=cockpit.DefaultStabilisersModuleId or cockpit.DefaultStabiliserModuleId,
		Boost=cockpit.DefaultBoostModuleId,
	}
	for key,moduleId in pairs(cockpit) do
		local slotId=typeof(key)=="string" and string.match(key,"^Default(.+)ModuleId$")
		if slotId and not legacyDefaultKeys[slotId] then result[slotId]=moduleId end
	end
	return result
end
```

Why: the dealership preview of an unowned Exotic must show all ten default modules. `cockpit` is the server catalogue cockpit, which carries every primitive attribute of the model.

Piercer unchanged: the four legacy expressions are untouched. The six live Piercer cockpits carry exactly the seven legacy `Default*ModuleId` names (capture checked), all of which are in `legacyDefaultKeys`, so the loop adds nothing. `Default*Color` keys do not match the pattern. The existing `cleanModules` still drops nil and empty values.

---

## 5. VehiclePerformanceResolver

### Hunk R1 (after line 15): legacy name set

```lua
-- Any other Default<SlotId>ModuleId key is an optional default for that slot. Piercer cockpits have none.
local legacyDefaultNames={}
for slotId,names in pairs(defaultNames) do legacyDefaultNames["Default"..slotId.."ModuleId"]=true; for _,name in ipairs(names) do legacyDefaultNames[name]=true end end
```

### Hunk R2 (before `Resolver.DefaultBuild`, line 66): `optionalDefaults`

```lua
local function optionalDefaults(cockpit,template)
	local order,ids={},{}
	for _,source in ipairs({cockpit or false,template or false}) do
		local fields=typeof(source)=="Instance" and source:GetAttributes() or source
		if typeof(fields)=="table" then
			for key,value in pairs(fields) do
				local slotId=typeof(key)=="string" and not legacyDefaultNames[key] and string.match(key,"^Default(.+)ModuleId$")
				if slotId and ids[slotId]==nil and tostring(value)~="" then ids[slotId]=tostring(value); table.insert(order,slotId) end
			end
		end
	end
	table.sort(order); return order,ids
end
```

### Hunk R3 (new line after line 69, inside `DefaultBuild`)

```lua
	local order,ids=optionalDefaults(cockpit,template); for _,slotId in ipairs(order) do local module=findTemplate(root,"ModuleId",ids[slotId]); if module then bySlot[slotId]=module; table.insert(modules,module) end end
```

Why (R1-R3): the dealership rating (`Resolver.Factory`) and the module rating reference build (`Resolver.ModuleRating`) must include the body defaults of an Exotic. The caller's cockpit is read first, then the generated record, the same precedence as the legacy `first(cockpit,names) or first(template,names)`.

Piercer unchanged:
- The `defaultNames` table and the mandatory loop on line 69 are untouched. The four legacy defaults are still required, with the same failure message.
- The new defaults are **not** mandatory: a cockpit without such keys adds nothing, and a named module that is missing or retired is skipped.
- Piercer cockpits (server catalogue and `VehicleCatalogData` record) have only the seven legacy names, so `order` is empty and `modules` / `bySlot` are built by the same insertions in the same order as today. The floating-point sum order in `CalculateComponents` is therefore identical.
- Optional defaults are appended in sorted slot order, so an Exotic result does not depend on table iteration order.

### Hunk R4 (line 99, `ModuleRating`)

Before:

```lua
	local reference=findTemplate(root,"CockpitId","bruiser_01"); local cockpit,defaults,bySlot=Resolver.DefaultBuild(root,reference); if not cockpit then return 0 end
```

After:

```lua
	local referenceId=tostring(attributeOrField(template,"RatingReferenceCockpitId") or ""); if referenceId=="" then referenceId="bruiser_01" end
	local reference=findTemplate(root,"CockpitId",referenceId); local cockpit,defaults,bySlot=Resolver.DefaultBuild(root,reference); if not cockpit then return 0 end
```

Why: an Exotic module is rated on an Exotic reference chassis (`exotic_03`), where its slot has a default to swap out. `template` is the module's `VehicleCatalogData` record.

Piercer unchanged: no Piercer record has `RatingReferenceCockpitId`, so the reference is `bruiser_01` as today. The cache key is unchanged (the reference is a function of the module).

---

## 6. PreviewCameraClient

### Hunk C1 (line 10)

Before: `...,RearBumper="Rear",FrontBumper="Front"}`
After: `...,RearBumper="Rear",FrontBumper="Front",FrontBody="Front",RearBody="Rear45"}`

Why: without entries both new slots use the front-quarter view, so the Engine Deck would be shown from the front.

Piercer unchanged: the eleven existing entries are untouched, and a Piercer never has a `FrontBody` or `RearBody` section.

---

## Config (`config_ops.json`)

Two folders under `ReplicatedStorage.Config.UI.GarageReplacement.ModuleArtwork`, with the same six attributes as the eleven live entries (`DisplayName`, `Image`, `ShowInBuild`, `ShowInCustomise`, `SortOrder`, `TargetId`):

| Folder | DisplayName | TargetId | SortOrder | Image (reused, no upload) |
|---|---|---|---:|---|
| `FrontBody` | Front Body | FrontBody | 72 | `rbxassetid://76594522686468` (the live `FrontBumper` image) |
| `RearBody` | Rear Body | RearBody | 74 | `rbxassetid://136042248946525` (the live `RearBumper` image) |

They only supply the card image. Without them the two cards still work, with a blank image.

---

## Flag off with an owned Exotic

INTERFACE says "Owned vehicles are never hidden or blocked". The server keeps that promise for actions. The garage UI cannot keep it alone, because the Stage A server source leaves a flagged-off category out of the catalogue for every player (`stage_a/server/after/GarageCatalogService.lua`, hunk GC4). The client has no other source for that category's slots, modules and cockpit names.

What happens today with the delivered server source, flag off, for a player who owns an Exotic:

- Customisation browser: the owned Exotic is not listed (`Browser:Rows` cannot find its cockpit).
- If the Exotic is the current vehicle: the pages show the first category's slots and modules (Piercer). Its installed modules do not resolve, and Nose and Engine Deck cannot be reached.
- Race entry (`RaceEntryPresentationClient`, not changed): the vehicle is listed with its cockpit id as the name and `OTHER` as the category.
- Nothing is lost or saved wrongly. Turning the flag on again restores everything.

The fix has two halves.

1. Client (done here, U7-U10 and B1): a category with `PurchaseDisabled=true` is never sold and is shown only to its owners, in Customisation.
2. Server and contract (**not done; outside this folder**): `GarageCatalogService` GC4 keeps a flagged-off category in the payload and sets `category.PurchaseDisabled = true` on it, instead of leaving it out. Both buy actions already refuse. A category that is on sale must not carry the field, so the Piercer payload stays byte for byte the same. INTERFACE.md row `FeatureFlag` and the contract need the new wording, and the server test "categories with flag off" changes from one category to two.

With both halves installed, flag off: the dealership shows Piercer only; a player without an Exotic sees no Exotic button or row anywhere; an owner sees the Exotic in Customisation with ten slots, can repaint, upgrade and swap owned modules, and gets "Module unavailable." from the server when trying to buy an Exotic module. Race entry shows the right name and category with no client change.

Until the server half is installed, the flag must not be turned off once any profile owns an Exotic. That is the reviewer's option (a), and it stays the rule if the server half is not approved. The client hunks are harmless in that case: nothing sends the field.

Cost of the server half, for the decision: the Exotic category data is sent to every client even while the flag is off. It is not shown, but it is readable in memory. The generated `VehicleCatalogData` chunks already replicate the same records once Stage B is installed.

---

## Evidence

Run in Studio (Edit, read-only, 2026-10-02) with `run_checks.lua`: before = live Source, after = `after/*.lua`. Live Source equals `before/<Name>.lua` for all seven owners.

- `tests.lua`, after against before: 20 of 20 pass. After only: 20 of 20 pass. Both sides served from `after/` and `before/` (the post-APPLY form): 20 of 20 pass.
- Control run (before sources passed as after): 15 of 20 fail, as they should. The five that pass are the four Piercer-only preview, rating and slot checks and the compile check.
- `parity.lua` on live data, real calculator, before against after, results exactly equal (run on the first delivery; not run again in review round 1, because `VehiclePerformanceResolver` and `GarageVehiclePreviewProfile`, the only two sources it loads, are byte for byte the same files):
  - dealership rating for all six Piercer cockpits in three call forms: `bruiser_01=C 525, bruiser_02=E 202, bruiser_03=D 374, bruiser_04=B 662, bruiser_05=A 787, bruiser_06=S 925`;
  - module rating for all 116 Piercer records (84 rated; the same 84 again with one upgrade point);
  - dealership preview profile for all six Piercer cockpits.
- `feature_installer.build` accepts `config_ops.json` + `ops.json` against the `exotic-before` capture (9 operations, in memory only; no installer was written).
- `build.py` run twice gives the same bytes for every after-source, `ops.json` and `config_ops.json`.
- Cross-folder data (`balance/balance.json`, `catalogue/catalogue_gen.lua`, `performance_phase3/catalogue.py`, `stage_b/build_content.py`, the server after-sources): `CardTitle` equals `DisplayName` and `RatingReferenceCockpitId="exotic_03"` on all 108 modules; all six cockpits carry the seven legacy and the six new `Default<Slot>ModuleId` names; slots carry `RailLabel`; the generated record lists carry the six new default names and `RatingReferenceCockpitId`. No mismatch with the client readers.

Not tested: anything in Play. The GarageUI render loops are closures and cannot be run without the whole UI, so the slot filter is modelled in `tests.lua`, and the shipped `slotLabel` line and the shipped category helper lines (`allCategories` to `browserCategory`) are extracted and run on their own. The browser button loop is checked by text and by running the shipped list expression.

`parity.lua` note for the integrator: it never calls `require`, but it does load the live calculation modules with `loadstring` into a private cache. `run_checks.lua` has a `RUN_PARITY` switch; set it to false to run only the pure tests.

---

## Review round 1 (2026-10-02)

| Finding | Result |
|---|---|
| Medium: flag off with an owned Exotic hides and mis-renders the owned vehicle | Right. Client half fixed (U7-U10, B1, four new tests). Server half and contract wording are outside this folder; see "Flag off with an owned Exotic". |
| Low: `run_checks.lua` post-APPLY mode needs a `before/` folder that was not delivered | Right. Fixed: `build.py` writes `before/<Name>.lua` from the verified blob; `run_checks.lua` also reports any difference between live Source and the served files. |
| Low: shown tag and sort key can disagree for a module with `CardTitle` | Right as a mechanism, fixed (V4). The example given cannot happen with server data: the server always sends a `VariantName` and sends `Standard` for a body part id, and `ViewModel.Variant` returns an explicit `Standard` before it looks at the name. The real case was a custom `VariantName` (a kit name, which this file offers as an option) on a part whose name contains "power" or "lightweight". No Stage B data check is needed now. |
