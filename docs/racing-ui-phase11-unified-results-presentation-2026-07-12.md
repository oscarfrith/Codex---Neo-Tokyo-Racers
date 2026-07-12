# Racing UI Phase 11 - Unified Results Presentation

Replaces only the isolated result-coach client with one semantic 1200x720 shell
for Race and Time Trial results. It preserves Phase 11Y Time Trial exit cleanup,
the confirmed retry action, Race `ExitRaceToStart`, placement rewards, PB writes,
and matchmaking. Existing legacy results and queue panels are suppressed while
the new presentation is visible and restored afterward.

Current Time Trial payloads fully populate medal, reward, best lap, session laps
and PB state. The global table uses the Phase 9A request and keeps its unavailable
state when disabled. Race placement/reward/local finish time are authoritative;
other racers' finish times, vehicle labels, fastest lap and maximum speed remain
`--`/status values until the planned server result-summary telemetry adapter owns
those fields. No competitive values are inferred from the client.
