# Garage upgrade card hierarchy refinement

Date: 2026-07-17

Status: guarded presentation-only installer generated from the refreshed and confirmed upgrade-budget mirror; awaiting Studio Play verification.

V1.1 folds the first visual review into the same installer: `MAX LEVEL` now uses the same grey as `POINT LIMIT REACHED`, both terminal status lines sit slightly lower, and `x/x USED` uses an explicit right inset because the shared label helper does not apply caller-provided `AnchorPoint`.

The first V1.1 paste stopped at Command Bar parse line 98 before mutation because a source anchor ended with a table-index bracket beside a normal `]]` long-string terminator. The same installer now uses equals-delimited strings for that anchor.

## Changes

- The shared upgrade-budget panel is enlarged to `480 x 42` virtual pixels.
- `UPGRADE POINTS` and `x/x USED` both use the same 13-pixel shared heading size as module listing-card names.
- Both labels remain inside the budget panel, with allocation pips centred between them.
- The existing popup-clearance contract remains active and the runtime geometry audit still rejects overlap.
- Upgrade cards use the upgrade name as their top heading rather than the source vehicle name.
- The coloured tag shows `LEVEL 0` through `LEVEL 3`: grey, yellow, orange and red.
- The separate `x/x` badge is removed.
- The price position remains green while an upgrade can be purchased. Terminal `MAX LEVEL` and `POINT LIMIT REACHED` states share the same grey treatment and sit slightly lower in the card.
- The bottom effect summary remains while the next point is available, and is blank at maximum level or when the budget is exhausted.
- The centred action popup now says only `UPGRADE`; price remains on the card.

## Safety

This phase changes presentation only. It does not modify upgrade capacities, prices, allocations, performance effects, physical module instances, purchase actions or persistence. All three changed ModuleScripts compile before assignment, use exact one-occurrence anchors, and are restored in memory if the post-install audit fails.

## Next gate

Confirm the desktop hierarchy and popup clearance in Play. The subsequent responsive pass should rescale this same shared renderer for tablet and phone rather than create a mobile-specific copy.
