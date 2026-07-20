# New System Contract Template

Use this template for Standard and High-Risk work under `docs/14_new_system_readiness_standard.md`. The assistant derives it from the request and current mirror; the user is not expected to write the technical specification.

Keep Standard contracts compact. Expand the marked sections only for High-Risk or genuinely complex work. Use `N/A` with a short reason when a concern does not apply.

```text
System/change:
Delivery lane and reason:
Goal:
Current confirmed baseline:

Required changes:
Must preserve:
Explicit exclusions:

Canonical owners:
- State:
- Geometry/visibility (if UI/world presentation):
- Preview/runtime attachment:
- Persistence/authoritative mutation:

Inputs, outputs and dependencies:
Entry, transitions, exit and cleanup:
Client/server authority and remote validation:
Stable IDs, saved schema/API version and migration impact:
Expected scale and bounded performance budget:
Mobile, touch, controller and accessibility coverage:
Streaming/open-world behaviour:
Failure, cancellation, retry and observability:

Shared components/contracts to reuse:
Implementation/installer and rollback approach:

Verification matrix:
- Static/install:
- Runtime transitions and cleanup:
- Multi-client/security (if applicable):
- Save/rejoin/migration (if applicable):
- Device/performance/streaming (if applicable):

Readiness scorecard exceptions or deferred risks:
Done when:
```

## Lane Guidance

### Standard

Normally answer each relevant field in one concise line. The purpose is to prevent hidden ownership and lifecycle mistakes, not to create a long design document.

### High-Risk

Include explicit invariants, threat cases, migration/rollback semantics, representative load targets and runtime evidence. If ownership or the live persistence boundary is uncertain, audit it before implementation.

