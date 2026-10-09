# Spike 12 note: attributes at ReplicatedFirst time, and ClientBase before ReplicatedStorage

Status: not run. This is the one unknown the Play-only harness cannot answer. It is scheduled for Phase 1, together
with the latch, because it needs one temporary Edit-mode write.

## The two questions (plan 1.1 and 1.3, Appendix C)

1. When `ReplicatedStorage.Config.UI` arrives on the client at ReplicatedFirst time on a cold start, are its
   attributes already set, or can a script see the instance first and the attributes a moment later?
2. Can `ClientBase` run before ReplicatedStorage has fully arrived?

## Why a late spike cannot answer them

`execute_luau` runs seconds after the client has started. By then everything has replicated, so a read of
`Config.UI:GetAttributes()` only shows the final state. The fact needed is the state at the first instant a
ReplicatedFirst script can reach the folder, and that instant has passed. `12_replication_state_late.lua` records
what can still be read (`game:IsLoaded()`, the `Config.UI` attributes as they are now, `ClientBase.StartupState`).

Second reason: `Config.UI` has **no attributes today** (plan 1.1, read live). There is nothing to observe arriving
until one exists. Adding one is a write to the place in Edit mode, which the spike phase does not make.

## What source already says

- `InitialLoadingAndStartScreenClient` 13 waits for `ReplicatedStorage.Config.UI.LoadingSystem` with three
  unbounded `WaitForChild` calls, then at 15 reads `config:GetAttribute("StartScreenEnabled")` with **no wait for the
  attribute**. This script runs from ReplicatedFirst on every cold start and that read has behaved in every session
  to date. That is the existing evidence that attributes arrive with their instance. It is evidence, not proof:
  the test is `== false`, so a missing attribute would silently take the "enabled" path, which is also the live value.
- `ClientBase` 3 and 4 use `RS:WaitForChild("Modules")` and `WaitForChild("Config"):WaitForChild("Development")`,
  then index `.Core.ClientLifecycle` and `.ClientTools` directly. The resolver at 105 to 109 uses `WaitForChild` on
  every path part. So ClientBase is already written to tolerate late arrival of top-level folders, and the direct
  indexes show that children have so far always been present once their parent was.
- `ClientBase` publishes status strings only (`StartupState` attributes, line 110). There are no timings to read.

Expected answers: (1) yes, attributes are part of the instance's initial replication packet; (2) LocalScripts in
StarterPlayerScripts start after the initial ReplicatedFirst content, and may start before `game:IsLoaded()`; the
latch therefore waits for `Config.UI` with `WaitForChild` and does not rely on `IsLoaded`.

## The minimal one-off experiment (Phase 1, High-Risk lane, inside the latch delivery)

Precondition: the Phase 1 installer is at the point where it adds the four switch attributes to `Config.UI` anyway.
No extra instance is needed.

1. Edit write (already part of Phase 1 APPLY): `Config.UI@UIStyle = "Classic"`.
2. The latch `ReplicatedFirst.UIStyleSwitch`, in its first-require path, records four facts as attributes on its own
   ModuleScript (it already writes its result there, plan 1.2), only when a Studio debug attribute is on:
   - `ProbeUiPresentAtRequire` : was `Config.UI` already present, or did `WaitForChild` yield (compare `os.clock()`
     before and after)
   - `ProbeAttrAtArrival` : `Config.UI:GetAttribute("UIStyle")` read on the same line the folder is first seen
   - `ProbeAttrAfterDefer` : the same read after one `task.defer`
   - `ProbeIsLoadedAtRequire` : `game:IsLoaded()`
3. `ClientBase`'s one protected require of the latch (the Phase 1 edit) adds nothing; a read-only client probe run
   later through `execute_luau` reads the four attributes plus `ClientBase.StartupState`.
4. Run five cold starts: Studio Play (solo), then, with Oscar, one local server with one player, and one published
   private-server join if a publish is approved. Record the four values each time.

Pass: `ProbeAttrAtArrival == "Classic"` on every run. Then the latch reads the attribute directly after
`WaitForChild`, as designed.

Fail (attribute nil at arrival on any run): the latch waits with
`Config.UI:GetAttributeChangedSignal("UIStyle")` **only when the attribute is nil**, bounded by `game:IsLoaded()`
(not by a timer), and then reads once. This is the pre-chosen fallback; it adds no wait in the passing case.

Question 2 is answered by `ProbeUiPresentAtRequire` and `ProbeIsLoadedAtRequire` on the ClientBase side. The design
does not depend on the answer (plan 1.3); the values are recorded so the 15-second "not ready" check can be explained.

## Why not a temporary attribute now

A throwaway attribute on `Config.UI` in Phase 0 would need an Edit write, an install record, a rollback and a second
Classic record (the typed config dump in plan 1.8 would change twice). The latch delivery makes the same write once,
for real, with the reviewer and rollback already in place. Deferring costs nothing: no Phase 0 decision depends on it.
