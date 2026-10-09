# Garage family, half A: acceptance contract (dealership and customise)

Under `../../CONTRACT.md` (wave 2), `../../API2.md` 5.7 and 6, and the programme contract. Lane: **High-Risk** (spends
Cash, spawns and despawns vehicles). Nothing here is installed. Half B (owned garage, forks) has its own notes.

## Owners, before and after

| Surface | Before, and after with `UIStyle` Classic | After, `UIStyle` Pulse |
|---|---|---|
| Garage session state, navigation, every `GarageInvoke` call, session End, loading generations | `Garage.GarageUI` | `UIPulse.Garage.GarageModel` (started by `GarageClient`, claim `Garage`) |
| Dealership and customise drawing | `UI.GarageBrowserUI`, `UI.GarageWorkspaceUI`, `UI.GarageComponents` | `Garage.GarageScreenView`, `Garage.PaintView`, `Garage.GarageModals` over the kit |
| `CanonicalGarageGui` (40), its scrim (39) and live layer (41), root `CanonicalCanvas` | `GarageComponents.CanonicalHost` | `GarageClient` through `Kit.Layers.Create` |
| The three `Open*` listeners; `GarageEntryMode` clears; `GarageClosedFromDealershipExit`, `FreeRoamVehicleSpawned`, `FreeRoamVehicleExited` | `GarageUI` | `GarageClient` (listeners) and `GarageModel` (the rest) |
| Preview vehicle, preview camera input and step, `PreviewVFXMode` | `GarageUI` over the shared preview modules | `GarageModel` over the same shared modules, unchanged |

Unchanged and shared by both styles: `GarageCatalogClient`, `GarageModuleCardViewModel`, `PreviewVehicleClient`,
`PreviewCameraClient`, `GarageModuleInstancePreviewAdapter`, `GarageVehiclePreviewProfile`, `VehiclePerformanceResolver`,
`PresentationAudioBridge`, `GaragePropertyCatalog`, every server script. No config value is added or changed.

## Must preserve

1. **The remote table.** Exactly the 24 call sites of `actions.json` (generated from the Classic source): same remote,
   action string, payload keys and value sources, behind the one busy flag; nothing retried; nothing sent from a view.
2. **Server authority.** Price, Cash, ownership, locks and validity are the server's. The client shows catalogue prices
   and reply fields, mutes a price it cannot afford by the same comparison Classic makes, and sends a purchase exactly
   where Classic does. No Cash is added, subtracted or predicted.
3. **State and transitions.** The fields of GarageUI line 44; the selectors of 55-74; Drive needs one engine, stabilisers
   and boost; the empty-slot detour and its three returns; the transient preview cleared on every tab change, slot
   change, Back and purchase; entry for the three modes; post-purchase paint; errors as an inline line and a toast.
4. **Names and marks.** `CanonicalGarageGui` > `CanonicalCanvas` > `CanonicalGarageBrowser` / `CanonicalGarageWorkspace`,
   `CanonicalGarageModal`; the text `DEALERSHIP` on a label and on no button; marks `Categories`, `Stats`, `Capacity`,
   `VehicleScroller`, `TutorialCardScroller`, `UpgradeBudget`, `Card`, `Card.AddModules`, `Card.UpgradeModules`,
   `Card.PaintShop`, `Page.CustomisationHome` and the current tab's `Page.<id>`. Saved ids pass through untouched.
5. **Single owners.** One listener per `Open*` event; one `PreviewCamera.BindInput`; `GarageSessionActive` (server-written)
   stays the only garage-open signal, mirrored into `Kit.Presence`.
6. **Performance rules.** The 3D preview is rebuilt only when its inputs change; a selection, tab change or Cash change
   creates and destroys no instance; no `ScreenGui.Enabled` write; the button row sits in `RailButtons`.
7. `start()` claims first, waits only on instances the Classic owner waits on, and never on a remote reply, font or asset.
   It builds no view: the view is mounted on first open inside the protected draw.
8. **No stranded player.** A draw fault ends the session through the Exit sequence with a toast (`GarageModel.Abort`);
   it adds no remote call site.

## Changes the player sees (API2 5.7, programme contract 8)

Tabs Parts / Upgrades / Paint instead of the hub; a Shop / Owned switch instead of the "Owned Modules / Buy Modules"
page; one picker instead of the left card rails; the action on the button row instead of a floating popup; a
confirmation before a vehicle purchase. The full list, with what was dropped, is in `contract_a.json` and `NOTES_a.md` 3.

## Tests (pure; `tests/`, one file per module)

- **Model:** the action table against the generated block; every entry, purchase, equip, upgrade, paint commit,
  property purchase, drive and exit sequence with payload keys and values through fake remotes; refusals (no retry,
  inline line, toast); the busy guard; reply-shape handling; the transition table (tabs, Shop / Owned, detour and its
  returns, Back targets, Drive gating, preview clearing); the preview rebuild rule; tier, rating and price inputs;
  finally "nothing outside the table was sent, and every row was sent".
- **Routes:** tabs, marks against `Kit.Contracts`, sources, Back steps, page keys, artwork rows with and without config.
- **View:** display helpers; every fixture state at R1080 and C844: mounts, instance ceiling, no ScreenGui, a second
  render writes nothing, a selection creates nothing, names and marks present, one page at a time.
- **PaintView, GarageModals, GarageClient, Fixtures:** data builders, sync rules, the owner shape and entry events;
  the unset-channel seed (Classic white); the protected draw (a fault recovers once, never throws).
- **Model, added by the reviewer-fix pass:** the Shop / Owned switch rebuilds the preview; `Abort` runs the Exit
  sequence, closes the client side when End is refused, toasts, and sends nothing without a session.
- **Static:** `py -3 gen_actions.py --check` (call sites of the model equal the Classic call sites).

## Gates in Play (integrator; sandbox window)

The purchase matrix of `NOTES_a.md` 5 with the end-state comparison Classic against Pulse; affordability as stated;
orbit under scrims; Classic onboarding replay of pages 1 to 5 and 9 to 14; the census and churn probes; `delivery-reviewer`
on the whole family with `actions.json`; Oscar confirms one real purchase and has accepted the navigation in the gallery.
