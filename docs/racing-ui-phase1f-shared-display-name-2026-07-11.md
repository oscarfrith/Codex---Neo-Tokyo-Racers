# Racing UI Phase 1F - Shared Display Name

**Created:** 2026-07-11  
**Status:** Generated; awaiting Studio install/verification

Run in Edit mode:

```text
scripts/roblox_racing_ui_phase1f_shared_display_name.lua
```

The installer seeds this attribute from the Race Catalog `DisplayName` that was
already edited:

```text
ReplicatedStorage.NeoTokyoRacers.Config.Racing.RaceCatalog
  .<Event>.SharedMenuDisplayName
```

`SharedMenuDisplayName` becomes the explicit menu-facing owner. An isolated
`RaceDisplayNameService_Active` synchronizes it to the Race event's
`DisplayName`, every matching Time Trial event, and the matching world route.
Summary-driven entry, browser, queue, HUD, and new-result payloads therefore use
one name without patching their individual clients/services.

After installation, restart Play and confirm the Race Browser, entry menu,
countdown/HUD, queue, and a newly completed result use the same name.

