---
description: Turn a design idea into an implementable design contract (no implementation)
argument-hint: <feature, screen or system to design>
---
Design task: $ARGUMENTS

Act as game and UI designer for Space Racers, then hand a buildable contract to the developer workflow. No implementation.
1. Read docs/01_game_overview.md, the relevant reference docs (docs/README.md), and existing design systems: racing-ui-design-system-2026-07-11.md, ui-free-roam-pc-design-system-2026-07-10.md, shared-responsive-ui-foundation-v1.md, shared-vehicle-card-system-v1.md. Reuse their components and tokens; note any exception explicitly.
2. If it helps, capture the current state with screen_capture (Edit) and refer to it.
3. Write the player goal, flow (entry → states → exit), PC / touch (LandscapeSensor) / controller inputs, reused components, new config attributes for tuning, economy/persistence impact, and what is out of scope.
4. Save it as docs/design/<short-name>.md using the docs/15 contract headings, marked "Design - not approved".
5. List two or three open design questions for the user. Visual mockups are best iterated in the Claude app; link any accepted mockup files under assets/ui/mockups.
