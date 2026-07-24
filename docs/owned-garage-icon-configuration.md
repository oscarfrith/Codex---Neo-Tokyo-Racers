# Owned Garage Icon Configuration

**Status:** V1.1 user-confirmed working and represented in the complete `2026-07-23 22:22:32/33` Studio mirror; the installer is recovery-only for this exact scope  
**Installer:** `scripts/roblox_owned_garage_icon_config_v1.lua`  
**Revision:** `NTR_OWNED_GARAGE_ICON_CONFIG_V1_1_LOCATION_SCALE`

## Designer Location

After installing, edit icons here in Roblox Studio:

```text
ReplicatedStorage
  NeoTokyoRacers
    Config
      UI
        GarageReplacement
          OwnedGarageIcons
```

Each child Folder contains String attributes. Set a value to either `rbxassetid://123456789` or a numeric Roblox image asset ID. Restart Play after changing icons because browser and HUD buttons resolve some images during controller startup.

## Complete Icon Map

| Folder | Attributes |
|---|---|
| `Modes` | `DisplayCars`, `BuildGarage`, `StyleGarage` |
| `Families` | `Structure`, `Decorations`, `Lighting` |
| `StructureLocations` | `FrontWall`, `LeftWall`, `RightWall`, `BackWall`, `Floor`, `Ceiling` |
| `DecorationLocations` | `WorkshopWall`, `StorageWall`, `HangoutBay`, `FeatureCorner`, `IdentityWall`, `DisplayPlatforms` |
| `Navigation` | `Back`, `Exit` |
| `Access` | `Private`, `FriendsOnly`, `InviteOnly`, `Public`, `Invite` |
| `Browser` | `Enter`, `Exit`, `Cancel` |
| `Economy` | `Capacity` |
| `Actions` | `InstallAsset` |
| `Sizing` | `StructureLocationImageZoom`, `DecorationLocationImageZoom` |

Both `Sizing` values default to `1.0`, exactly twice the confirmed shared navigation-card value of `0.5`. They are independent Number attributes bounded by the controller to `0.2–1.5`, so Structure and Decoration location artwork can be tuned separately without changing the root Modes, Families, vehicle cards or finish controls.

The three Modes and three Families are seeded with the currently confirmed dealership/customisation icons. Navigation is seeded from the confirmed Back/Exit icons. Specific location and optional action/HUD/browser values begin blank.

Blank Structure or Decoration location values use their family icon. Blank `InstallAsset` uses Decorations. Blank Access and Browser values retain their existing glyphs. Blank Economy Capacity retains the current shared garage icon. Clearing an optional value therefore does not produce a broken image.

## Ownership Boundaries

This folder controls owned-garage category/location/navigation/access/browser icons only. It does not own:

- vehicle card images, which come from the authoritative vehicle summaries/catalogue;
- the garage browser hero image, which comes from each property definition's `Image` field;
- shared lock artwork, cash `+`, empty-space `+`, material cards or colour controls;
- free-roam Garage/Map/Settings icons, which remain in their existing free-roam UI config.

The installer changes four existing presentation consumers only: owned management, the shared capacity icon seam, interior Access/Invite HUD and My Garages browser. It adds no UI owner, remote, saved field, economy action or runtime gameplay state.

## Verification

1. Run the installer in Studio Edit mode. From the already-installed V1 state, require `PASS sourceWrites=1 groups=10 icons=30 sizing=2 structureZoom=1 decorationZoom=1`. A first install directly from Phase 14 V2.2 reports `sourceWrites=4` instead.
2. Set visibly different temporary images on one Mode, every Structure location and every Decoration location.
3. Restart Play, enter the garage and check the management root, Build/Style family cards and both location rails.
4. Check Back/Exit, capacity, Access modes, Invite and My Garages Enter/Exit/Cancel.
5. Clear one location attribute and confirm it returns to the family icon rather than becoming blank.
6. Repeat at a phone viewport and regress Display Cars, purchase/equip, Style save/cancel and garage entry/exit.
7. Confirm the Structure and Decoration location icons are twice their previous size while root/family icons remain unchanged. If needed, tune the two Number attributes independently and restart Play.
8. Refresh the complete Studio mirror after confirmation.

Rollback is the confirmed Phase 14 V2.2 Studio history point. A failed installer restores all four exact source snapshots, existing icon attributes and any pre-existing config folders; a newly created icon root is removed.
