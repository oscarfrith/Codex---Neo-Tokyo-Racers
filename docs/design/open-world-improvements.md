# Open-world improvements (suggestions)

Status: **Design - not approved.** Written 2026-09-26 alongside the map and world-jobs refinements. The ideas draw on GTA V/Online, Forza Horizon, Need for Speed Heat/Unbound, The Crew and Burnout Paradise. They are ranked by value against effort for Space Racers today. Each one reuses existing owners: MapMarkers, RouteGuide, ActivityService/ActivityPayout, ProgressionService and ActivityHud.

## Tier 1: small, high value (build on this batch)

1. **Map filters and a "nearest" cycle** (GTA). The legend entries on the full map toggle categories (Jobs / Races / Places / Players). Controller LB/RB, or keys Q/E, cycles the cursor between icons of the selected kind. Mostly MapUI work, and needs no new data.
2. **Discovery fog / districts** (Forza Horizon, Burnout).
   - The full map starts dimmed. Districts reveal as you drive through them, with a one-time Cash/XP "DISTRICT DISCOVERED" toast.
   - It rewards exploration and gives new players a goal.
   - It needs a small saved set of district ids (additive profile field), district polygons in Config and a mask overlay on the map.
3. **Speed traps, speed zones and danger signs** (Forza Horizon). These are fixed roadside points or segments with a star rating (for example 150/180/210 mph). Each best result is saved and shown on the map, with a friend's best shown as a ghost number. They are cheap to build, very replayable, and make the road graph and map icons pay off. This was already on the queue as "Speed Cams".
4. **Job chains without auto-start.** After a job, the three nearest offers flash on the minimap for 5 s, with a "NEXT FARE 420m" chip. This keeps the "find the next one yourself" rule while cutting dead time. A small streak bonus applies if you pick up the next job within 60 s.
5. **Arrival flair** (NFS/GTA). The route line turns into a short pulse ahead of the car in the last 200 studs, and the destination gets a vertical light beam in the world, visible from far away. This fixes the most common complaint about GPS routes, which is overshooting the stop.
6. **Photo mode** (every modern racer). A free camera, a few colour filters and a hide-HUD toggle. It helps retention and social sharing (screenshots and thumbnails), and it is low-risk because it is client-only.

## Tier 2: medium, strong retention

7. **Street reputation and district heat** (NFS Heat). Racing or dueling in a district raises its "heat". High heat spawns patrol drones that give chase, and escaping pays a multiplier on the night's earnings. It adds risk and reward to free roam; it needs a server-owned chase NPC and a new owner, so it is High-Risk.
8. **Daily and weekly contracts** (GTA Online Dailies, Forza Accolades). Three daily objectives, such as "deliver 2 parcels" or "win a duel", shown in JOBS. The reward is XP plus Cash through ActivityPayout (new reason). It is a proven retention loop and reuses the ActivityService signals. This is the "Daily Dispatch" idea from the design doc.
9. **Businesses / owned properties** (GTA Online). Buy a courier depot or a taxi rank. Owning one raises job pay in that district and adds a passive trickle that has to be collected in person. It is a long-term Cash sink that feeds the Robux-for-Cash packs. High-Risk: it touches economy and persistence.
10. **Crew / convoy** (The Crew). A party of 2–4 players shares a route, earns a small bonus for driving near each other, and can start the same job together (passengers split the fare). It reuses PassengerService and duels' pairing code.
11. **Radio and ambient life.** In-car radio with 2–3 stations (licensed or original tracks, with volume in Settings), plus roadside NPC pedestrians and flying traffic lanes (visual only). This is the biggest "world feels alive" gain per effort. Traffic must stay client-side so it does not cost server physics.

## Tier 3: larger features

12. **Showcase events** (Forza Horizon). Scheduled spectacles, such as a race against a sky-train or a stunt run through a stadium. They need authored content and a server event scheduler.
13. **Player-made routes** (Forza EventLab-lite). Place checkpoints on the full map with the new waypoint tools, then save and share a route as a custom time trial. It reuses the route graph, TimeTrial and the waypoint UI. It is moderation-safe because it has no free text; routes get a generated name.
14. **Stunt jumps and hidden collectibles** (GTA stunt jumps, Burnout billboards). Smashable neon billboards and marked ramps. There is one-time Cash for each, a counter in Driver Rank, and 100% completion rewards a unique livery. It is cheap per item but needs world placement work.
15. **Vehicle mastery trees** (Forza Car Mastery). Driving a car earns points in that car's tree, which unlock small perks (tyre smoke colour, +2% job pay in this car, a horn). This gives a reason to own more than one car, which supports the dealership economy.

## Map and navigation extras (fit this batch cheaply)

- Show the **road name / district** under the minimap (GTA). This needs a name per road-graph edge; the generator can seed names by district.
- Add **distance and ETA** on the waypoint chip and on legend hover.
- **Zoom the minimap out with speed** (GTA/NFS). At high speed the minimap shows further ahead. This is one config curve in the HUD.
- **Upcoming-turn arrow** (GTA V's audio-GPS equivalent): a small chevron in the route chip showing the next turn direction and distance, computed from the route polyline.
- **Other players' activity icons.** A player on a taxi job shows the taxi icon on others' maps. This helps social RP and would come from a replicated Player attribute.

## Recommended next three

After this batch, I recommend these three:

1. Speed traps and speed zones (3).
2. Daily contracts (8).
3. Speed-based minimap zoom plus the turn arrow (map extras).

All three reuse the owners being built now, have little persistence risk, and each adds a daily reason to drive around the map.
