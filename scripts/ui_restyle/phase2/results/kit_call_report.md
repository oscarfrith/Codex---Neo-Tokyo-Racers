# Pulse kit call check

Written by `py -3 scripts/ui_restyle/phase2/tools/check_kit_calls.py --write`. It is static analysis of the checked-out sources; nothing here was run in Studio, so a clean row is not a Play confirmation.

- **ERROR**: the kit source and the call site together make a run-time error certain when that line runs.
- **NOTE, suspect**: a concrete mismatch was found, but one step is not certain (the table is built in a variable or a list, the receiver was matched by name, or the kit only warns).
- **NOTE, unchecked**: the call could not be checked; the reason is given.

| Unit | Files | Kit calls | Props literals checked | Set calls checked | ERROR | NOTE suspect | NOTE unchecked |
|---|---|---|---|---|---|---|---|
| race_menu | 4 | 28 | 37 | 20 | 0 | 0 | 0 |
| free_roam | 17 | 81 | 80 | 31 | 0 | 0 | 1 |
| world_map | 7 | 34 | 32 | 13 | 0 | 0 | 7 |
| race_session | 11 | 66 | 94 | 50 | 0 | 0 | 1 |
| race_entry | 6 | 63 | 95 | 48 | 0 | 0 | 6 |
| garage | 18 | 89 | 113 | 62 | 0 | 0 | 10 |
| shell | 8 | 32 | 23 | 11 | 0 | 0 | 5 |
| kit_fixtures | 10 | 46 | 26 | 5 | 0 | 0 | 20 |

## What is checked

Read from the kit source for every exported function, then compared with each call in the screen sources:

- the member exists on the kit module, and is called with `.` not `:`;
- the keys of a props literal (constructor and `Set`, and nested lists such as `Buttons`, `Tabs`, `Rows`, the items of `Rail.SetItems` / `List.SetItems`, the props of `PromptStack.Show`);
- literal values of enumerated props and arguments (variants, sizes, roles, colour roles, tiers, icon names, mark keys, layer names, frames, slot names, presence kinds, asset keys);
- required props and arguments, and literal value types where the kit tests the type;
- the fields and methods read from a component handle;
- keys read from the kit's constant tables (`Tokens.Colour.X`, `Tokens.Space.X`, `Sprites.Icons.Glyphs.X`).

Not checked: values that are not literals (a value read from data, a function result from another module), handles kept in tables indexed at run time, and anything the kit does not validate itself.

## Kit modules read

| Module | Source | Functions | Components with a key set |
|---|---|---|---|
| BigNumber | phase2/kit/k4/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.BigNumber.lua | 3 | New |
| Collections | phase2/kit/k2/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections.lua | 14 | Chip, List, ListRow, Rail, TierBadge, Tile |
| Contracts | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Contracts.lua | 0 | - |
| Controls | phase2/kit/k2/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Controls.lua | 23 | Button, ButtonRow, Dropdown, Header, IconButton, Slider, Stepper, Swatch, Switch, Tabs, _rowPatch |
| Data | phase2/kit/k4/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Data.lua | 14 | CashChip, DeltaChip, FactList, SegmentedBar, StatPanel, StatusCluster |
| Gauge | phase2/kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Gauge.lua | 6 | New |
| Input | phase2/kit/k2/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Input.lua | 11 | - |
| Layers | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Layers.lua | 4 | - |
| Metrics | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Metrics.lua | 6 | - |
| Minimap | phase2/kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Minimap.lua | 5 | New |
| Overlay | phase2/kit/k3/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Overlay.lua | 13 | Modal, PromptBanner, PromptStack, Toast |
| Perf | phase1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Perf.lua | 2 | - |
| Presence | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Presence.lua | 3 | - |
| Sprites | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Sprites.lua | 0 | - |
| Surface | phase2/kit/k2/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Surface.lua | 9 | Divider, Glow, Hairline, Icon, KeyCap, MapIcon, Panel, Scrim, TitleMark |
| Text | phase2/kit/k2/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Text.lua | 10 | Label |
| Tokens | phase2/kit/k1/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens.lua | 2 | - |
| Touch | phase2/kit/k4/after/ReplicatedStorage.Modules.Game.UIPulse.Kit.Touch.lua | 4 | Button |

### Not extracted

None. Every exported function that takes `props` has a key set for its constructor and for its Set.

## Against the assembled kit copy

The same units checked against `install/00_kit/after` alone (what the last assembly holds), to catch a screen that relies on a kit working copy that has not been assembled yet.

No difference: every ERROR and suspect NOTE is the same against both copies.

## race_menu

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (0)

None.

## free_roam

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (1)

| File | Line | Why it was not checked |
|---|---|---|
| Map.MapIcons.lua | 181 | `item.Component` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Surface.MapIcon) |

## world_map

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (7)

| File | Line | Why it was not checked |
|---|---|---|
| Dev.Fixtures.WorldMap.lua | 190 | Overlay.PromptStack handle .Show: bannerProps is not a table literal, so its keys are not checked (the value is computed (`PromptRules.BannerProps(family, item)`)) |
| World.WorldPromptView.lua | 212 | Overlay.PromptStack handle .Show: bannerProps is not a table literal, so its keys are not checked (the value is computed (`props()`)) |
| World.WorldPromptView.lua | 217 | Overlay.PromptStack handle .Show: bannerProps is not a table literal, so its keys are not checked (the value is computed (`props()`)) |
| WorldMap.FullMapView.lua | 168 | Kit.Controls.Button: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| WorldMap.FullMapView.lua | 397 | `row.Icon` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Collections.Tile, Controls.Button, Controls.IconButton, Surface.Icon, Surface.KeyCap, Surface.MapIcon) |
| WorldMap.FullMapView.lua | 398 | `row.Label` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Controls.Button, Surface.KeyCap, Text.Label) |
| WorldMap.FullMapView.lua | 501 | Surface.MapIcon handle .Set: patch is not a table literal, so its keys are not checked (the value is computed (`shown and ARROW_SHOW or ARROW_HIDE`)) |

## race_session

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (1)

| File | Line | Why it was not checked |
|---|---|---|
| RaceSession.ResultsView.lua | 446 | Data.FactList handle .SetRows: rows is not a table literal, so what it holds is not checked (the value comes from `rows`) |

## race_entry

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (6)

| File | Line | Why it was not checked |
|---|---|---|
| RaceEntry.RecordsView.lua | 114 | `item.Panel` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Surface.Panel) |
| RaceEntry.SetupView.lua | 141 | Data.FactList handle .SetRows: rows is not a table literal, so what it holds is not checked (the value is the parameter `rows`) |
| RaceEntry.SetupView.lua | 285 | `item.Panel` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Surface.Panel) |
| RaceEntry.SetupView.lua | 291 | `item.Panel` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Surface.Panel) |
| RaceEntry.SetupView.lua | 385 | Kit.Controls.ButtonRow: props.Buttons is not a table literal, so what it holds is not checked (the value is the parameter `buttons`) |
| RaceEntry.SetupView.lua | 536 | `fact` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Controls.Button, Surface.KeyCap, Text.Label) |

## garage

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (10)

| File | Line | Why it was not checked |
|---|---|---|
| Garage.GarageModals.lua | 178 | Collections.List handle .SetItems: list is not a table literal, so what it holds is not checked (the value comes from the variable `rows`, which is not one plain literal) |
| Garage.OwnedGarageDeskView.lua | 358 | Collections.Rail handle .SetItems: list is not a table literal, so what it holds is not checked (the value comes from the variable `items`, which is not one plain literal) |
| Garage.OwnedGarageDeskView.lua | 455 | `tabs` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Collections.List, Collections.ListRow, Collections.Rail, Collections.TierBadge) |
| Garage.OwnedGarageDeskView.lua | 484 | `tabs` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Controls.Tabs) |
| Garage.OwnedGarageDeskView.lua | 487 | `tabs` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Collections.List, Collections.ListRow, Collections.Rail, Collections.TierBadge) |
| Garage.OwnedGarageDeskView.lua | 496 | `self._paint.panel` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Collections.List, Collections.ListRow, Collections.Rail, Collections.TierBadge) |
| Garage.OwnedGarageDeskView.lua | 607 | `paint.sliders[1]` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Controls.Slider, Controls.Stepper, Data.SegmentedBar) |
| Garage.OwnedGarageDeskView.lua | 608 | `paint.sliders[2]` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Controls.Slider) |
| Garage.OwnedGarageDeskView.lua | 609 | `paint.sliders[3]` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Controls.Slider) |
| Garage.PaintView.lua | 192 | `slider` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Controls.Slider) |

## shell

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (5)

| File | Line | Why it was not checked |
|---|---|---|
| Shell.OnboardingView.lua | 263 | `card.Title` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Text.Label) |
| Shell.OnboardingView.lua | 264 | `card.Hint` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Text.Label) |
| Shell.OnboardingView.lua | 265 | `card.Value` could not be traced to a kit component, so this Set is not checked (the patch is valid for: Text.Label) |
| Shell.OnboardingView.lua | 287 | `card.Value` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Text.Label) |
| Shell.OnboardingView.lua | 288 | `card.Hint` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Controls.Button, Surface.KeyCap, Text.Label) |

## kit_fixtures

### ERROR (0)

None.

### NOTE, suspect (0)

None.

### NOTE, unchecked (20)

| File | Line | Why it was not checked |
|---|---|---|
| Dev.Fixtures.BigNumber.lua | 6 | Kit.BigNumber.New: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Collections.lua | 102 | Collections.Rail handle .SetItems: list is not a table literal, so what it holds is not checked (the value is computed (`props.Items or {}`)) |
| Dev.Fixtures.Collections.lua | 107 | Kit.Controls.Tabs: props is not a table literal, so its keys are not checked (the value is computed (`props.Segment`)) |
| Dev.Fixtures.Collections.lua | 122 | Collections.List handle .SetItems: list is not a table literal, so what it holds is not checked (the value is computed (`props.Items or {}`)) |
| Dev.Fixtures.Controls.lua | 420 | Kit.Controls.Dropdown: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Data.lua | 38 | Kit.Data.SegmentedBar: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Data.lua | 42 | Kit.Data.DeltaChip: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Data.lua | 46 | Kit.Data.StatPanel: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Data.lua | 50 | Kit.Data.FactList: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Overlay.lua | 138 | `status` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Controls.Button, Surface.KeyCap, Text.Label) |
| Dev.Fixtures.Overlay.lua | 246 | `status` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Collections.Chip, Controls.Button, Surface.KeyCap, Text.Label) |
| Dev.Fixtures.Surface.lua | 63 | Kit.Surface.Panel: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Surface.lua | 70 | Kit.Surface.Hairline: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Surface.lua | 83 | Kit.Surface.Glow: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Surface.lua | 88 | Kit.Surface.Icon: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Surface.lua | 93 | Kit.Surface.MapIcon: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Surface.lua | 173 | `icon` could not be traced to a kit component, so this Set is not checked (the patch is valid for: BigNumber.New, Controls.Swatch, Surface.Glow, Surface.Hairline, Surface.Icon, Surface.MapIcon) |
| Dev.Fixtures.Surface.lua | 227 | Kit.Surface.Scrim: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Text.lua | 237 | Kit.Text.Label: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |
| Dev.Fixtures.Touch.lua | 6 | Kit.Touch.Button: props is not a table literal, so its keys are not checked (the value is the parameter `props`) |

