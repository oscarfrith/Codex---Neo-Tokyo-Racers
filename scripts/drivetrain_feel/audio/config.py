"""drivetrain_feel audio part: config rows (format in CONTRACT.md section 2).

Everything goes on the existing profile folder ReplicatedStorage.Config.Audio.VehicleProfiles.EXOTIC_V10_AUDIO.
No new instances. Every new attribute is a number (switches are 0/1, never booleans) or an asset-id string, and
each has a <Name>_RaisingThisDoes string beside it.

Audio tuning is read when the vehicle's sound graph is built. After editing any value during Play, raise
ProfileRevision by 1 so the running graph rebuilds (the existing rule for this profile). Do that in Play only: a
ProfileRevision or TurboWhistleAssetId saved in Edit that is neither its before nor its after value below makes the
installer's ROLLBACK and re-APPLY block (see NOTES.md, open risk 12).

Values equal the code defaults in VehicleAudioCatalog feelDefaults, except ReactorEnabled (code default 0, because
it repurposes the TurboWhistle slot; the Exotic sets 1).

ShiftVentMinStrength is deliberately not set on the profile: the audio vent then follows the vent flame's threshold,
ReplicatedStorage.Config.Vehicles.StabiliserVFX@ShiftVentMinStrength (camerafx part), so one knob drives both.
"""

PROFILE = ["ReplicatedStorage", "Config", "Audio", "VehicleProfiles", "EXOTIC_V10_AUDIO"]

INSTANCES = []

# (name, value, what raising it feels like / what 0 does)
_TUNING = [
    # Rev source: engine rpm from the gearbox (FeelRpm) instead of speed.
    ("RpmRevEnabled", 1,
     "Switch (0/1). 1: while the car's gearbox runs, the engine voice follows its rpm (gears, shifts, limiter). 0: the old speed-shaped rev for every car and none of the gearbox sounds."),
    ("RevRpmMin", 1000,
     "Engine rpm placed at the bottom of the rev-layer range. Raising it lowers every pitch at a given rpm (idle sounds deeper); keep it near the idle rpm."),
    ("RevRpmMax", 8600,
     "Engine rpm placed at the top of the rev-layer range when RevRpmMaxFromCar is 0 (or the car gives no limiter). Raising it lowers the pitch at every rpm, so redline sounds less screaming; lowering it pushes the top loops higher."),
    ("RevRpmMaxFromCar", 1,
     "Switch (0/1). 1: the top of the rev-layer range is the car's own limiter rpm (Drivetrain.<class>@LimiterRpm, via FeelLimiterRpm or GearForSpeed), so retuning the limiter keeps redline at the top loop. 0: RevRpmMax is used for every car."),
    ("RevRpmSmoothingSeconds", 0.02,
     "Time constant (s) the engine pitch takes to follow rpm. Raising it softens and blurs revs, blips and shifts; near 0 the pitch tracks rpm exactly."),
    ("RemoteRevSmoothingSeconds", 0.06,
     "Time constant (s) for other players' cars, which update at 15 Hz. Raising it glides their shifts more; lowering it makes their rpm drops step."),

    # Shifts.
    ("ShiftAudioEnabled", 1,
     "Switch (0/1). 1: shifts drop the rev, dip the volume, blip on downshifts, clunk and vent. 0: the pitch just follows rpm with no shift effects (the reactor chirp has its own switch)."),
    ("ShiftDropSeconds", 0.035,
     "How long (s) an upshift takes to fall to the new gear's rpm. Raising it makes upshifts slurred and lazy; lowering it makes them snap like a fast dual-clutch. Without a predicted landing it can fall no faster than the engine rpm itself. Needs ShiftDropMaxSeconds above 0."),
    ("ShiftDropMaxSeconds", 0.25,
     "Longest time (s) the upshift drop may run; it also ends as soon as the engine rpm stops falling. Raising it allows longer drops on slow shifts; 0 turns the drop shaping off, so the pitch follows FeelRpm down with RevRpmSmoothingSeconds and ShiftDropSeconds does nothing."),
    ("ShiftDipDb", 5,
     "Engine volume dip (dB) during an upshift cut at full strength. Raising it makes each upshift a harder, more obvious gap; 0 removes the dip."),
    ("ShiftDipMinSeconds", 0.07,
     "Shortest upshift dip (s), so a 30 Hz phone update still shows it. Raising it lengthens every dip; 0 lets the dip end as soon as the cut ends."),
    ("ShiftDipMaxSeconds", 0.25,
     "Longest upshift dip (s) even if the cut stays on. Raising it allows longer gaps on slow shifts; lowering it caps the gap."),
    ("ShiftDipAttackSeconds", 0.008,
     "How fast (s) the volume falls into the dip. Raising it softens the start of the gap; lowering it makes it a sharp cut."),
    ("ShiftDipReleaseSeconds", 0.05,
     "How fast (s) the volume returns after the dip. Raising it makes the engine swell back in slowly; lowering it snaps it back."),
    ("DownshiftBlipRev", 0.08,
     "Extra rev (0..1 of the range) added by the throttle blip on each downshift. Raising it gives a louder, higher rev-match bark; 0 removes the blip."),
    ("DownshiftBlipSeconds", 0.12,
     "Length (s) of the downshift blip. Raising it makes a longer, lazier blip; lowering it makes a short stab."),
    ("DownshiftBlipLoad", 1,
     "Engine load (0..1) forced during the blip, so the tip-in bark fires. Raising it makes the blip sound on-throttle and barky; 0 keeps the blip on the coast sound."),
    ("ShiftCrackleEnabled", 1,
     "Switch (0/1). 1: a hard upshift (strength at or above Config.Vehicles.StabiliserVFX@ShiftVentMinStrength, the vent flame's threshold) with no ShiftVent sound fires one exhaust pop directly (never through FeelPopRevision). 0: no crackle on upshifts."),
    ("ShiftCracklePop", 0.55,
     "Strength (0..1) of that upshift crackle pop. Raising it makes it louder; at 0.8 or more it becomes a bang. 0 is silent."),
    ("ShiftPitchJitter", 0.03,
     "Random pitch spread (fraction) of the shift clunk and vent. Raising it makes repeated shifts sound less identical; 0 plays them the same every time."),

    # Engine sub-bus (local car only).
    ("EngineBusEnabled", 1,
     "Switch (0/1). 1: the player's own engine runs through a small effects bus (load sweep, EQ tilt, limiter stutter, shift dip). 0: no bus is built; the engine is wired straight out as before and the dip goes on the voices."),
    ("EngineSweepLowHz", 350,
     "Centre (Hz) of the resonant peak with no load. Raising it moves the off-throttle resonance up into a nasal honk; lowering it puts it into the body."),
    ("EngineSweepHighHz", 2600,
     "Centre (Hz) of the resonant peak at full load and rpm. Raising it gives a brighter, more screaming sweep under throttle; lowering it keeps the sweep throaty."),
    ("EngineSweepRevShare", 0.4,
     "Share (0..1) of the sweep position that comes from rpm rather than load. Raising it makes the resonance climb through each gear; 0 makes it follow the throttle only."),
    ("EngineSweepDb", 3,
     "Height (dB) of the resonant peak at full load. Raising it makes the sweep a strong wah; 0 removes it."),
    ("EngineSweepQ", 1.6,
     "Sharpness of the resonant peak. Raising it makes a narrow, whistling resonance; lowering it makes a broad, gentle colour."),
    ("EngineTiltLowOffDb", -1,
     "Low band (dB) on overrun. Raising it keeps more body when coasting; lowering it thins the overrun."),
    ("EngineTiltLowOnDb", 2,
     "Low band (dB) at full load. Raising it makes full throttle heavier and boomier; 0 adds no weight."),
    ("EngineTiltMidOffDb", -0.5,
     "Mid band (dB) on overrun. Raising it keeps more rasp when coasting; lowering it softens the overrun."),
    ("EngineTiltMidOnDb", 1.5,
     "Mid band (dB) at full load, where the grit sits. Raising it makes full throttle grittier and more forward; 0 adds none."),
    ("EngineTiltHighOffDb", -4,
     "High band (dB) on overrun. Raising it keeps the overrun bright; lowering it muffles the engine more when you lift."),
    ("EngineTiltHighOnDb", 0,
     "High band (dB) at full load. Raising it adds fizz and edge under throttle; lowering it darkens full throttle."),

    # Limiter.
    ("LimiterTremoloEnabled", 1,
     "Switch (0/1). 1: bouncing off the limiter stutters the engine (tremolo on the bus). 0: no stutter (the rpm still bounces)."),
    ("LimiterNearRpm", 200,
     "How close (rpm) to the limiter the stutter may start. Raising it lets the stutter begin earlier; 0 needs the rpm at the limiter itself."),
    ("LimiterHoldSeconds", 0.1,
     "How long (s) the stutter stays on after the last limiter bounce, so it does not flicker. Raising it keeps it going longer; 0 follows each cut only."),
    ("LimiterTremoloHz", 13.3,
     "Stutter rate (Hz); 13.3 matches the default limiter cycle (0.03 s on, 0.045 s cut). Raising it buzzes faster; lowering it chops slower."),
    ("LimiterTremoloDepth", 0.7,
     "How deep (0..1) each stutter dip goes. Raising it makes a harder on-off bounce; 0 is no stutter."),
    ("LimiterTremoloDuty", 0.4,
     "Share (0..1) of each stutter cycle spent at full volume (0.4 = the default limiter on-time share). Raising it makes the gaps shorter."),
    ("LimiterTremoloSquare", 0.6,
     "How square (0..1) the stutter wave is. Raising it makes a choppier, harder gate; 0 is a smooth wobble."),

    # Reactor whine (the sci-fi line) in the TurboWhistle slot.
    ("ReactorEnabled", 1,
     "Switch (0/1). 1: the TurboWhistle slot (TurboWhistleAssetId, now turbine_high) is the reactor whine that follows road speed, silent unless the gearbox runs; TurboWhistleGain, TurboWhistlePitchMin and TurboWhistlePitchMax are then ignored (Reactor* values replace them; TurboWhistlePitch still scales the pitch). 0 does NOT silence it: the slot reverts to the old spool-driven turbo whistle and plays turbine_high as a whistle at TurboWhistleGain; to silence it, set ReactorGain to 0 instead (or clear TurboWhistleAssetId)."),
    ("ReactorGain", 0.16,
     "Reactor whine level at full load; while ReactorEnabled is 1 it replaces TurboWhistleGain. Raising it makes the sci-fi layer louder against the engine; 0 silences it (the way to turn the reactor off)."),
    ("ReactorLoadFloor", 0.25,
     "Share (0..1) of the reactor level kept off throttle. Raising it keeps the whine steady when coasting; 0 lets it vanish when you lift."),
    ("ReactorFullMph", 200,
     "Road speed (mph) where the reactor reaches its top pitch. Raising it makes the pitch climb more slowly with speed; lowering it tops out sooner."),
    ("ReactorPitchMin", 0.7,
     "Reactor pitch (playback speed) at standstill; replaces TurboWhistlePitchMin while ReactorEnabled is 1. Raising it starts the whine higher; lowering it starts deeper."),
    ("ReactorPitchMax", 1.4,
     "Reactor pitch at ReactorFullMph; replaces TurboWhistlePitchMax while ReactorEnabled is 1. Raising it gives a higher scream at speed; set equal to ReactorPitchMin for a fixed pitch."),
    ("ReactorChirpDepth", 0.03,
     "Pitch dip (fraction) the reactor takes on each shift. Raising it makes a more obvious capacitor chirp; 0 removes it."),
    ("ReactorChirpSeconds", 0.08,
     "Length (s) of the shift chirp. Raising it makes a slower swoop; lowering it a quick blip."),
    ("ReactorOverdriveGain", 0.4,
     "Extra reactor level (fraction) while boosting past top-gear redline (Overdrive). Raising it makes Overdrive scream louder; 0 adds nothing."),

    # Spin and the sci-fi line.
    ("SpinStrainGain", 1,
     "How strongly a spin-out (FeelSpin) drives the stabiliser strain sound. Raising it makes spins groan sooner and louder; 0 leaves the strain (and its engine duck) on sideways slip only."),
    ("SpinDuckScale", 1,
     "Share (0..1) of the spin strain that also ducks the engine (by up to SlipDuckDb). Lowering it keeps the free-revving engine audible under a loud spin groan; 0 means a spin never ducks the engine (sideways slip still does)."),
    ("SciFiRpmShare", 0,
     "Share (0..1) of rpm in the sci-fi line (turbine pair, boost loop and boost body pitch). 0 keeps them smooth with road speed like an electric motor; 1 makes them saw-tooth with the gears."),

    # Other players' cars.
    ("RemoteGearsEnabled", 1,
     "Switch (0/1). 1: other players' cars with a gearbox derive gear and rpm from their speed, so their engine pitch steps through the gears (no network change). 0: they keep the old smooth speed rev."),
    ("RemoteVoiceLowFraction", 0.4,
     "Fraction of redline the lowest in-gear voice of another car covers: with the idle voice kept, the highest loop that can still pitch down to it; otherwise the loop nearest it. Raising it sharpens the top end; lowering it gives more low-mid body."),
    ("RemoteVoiceHighFraction", 1,
     "Fraction of redline the highest of another car's engine voices sits at. Lowering it moves the voices toward the mid range."),
    ("RemoteIdleVoice", 1,
     "Switch (0/1). 1: another car with a gearbox keeps its idle loop as one of its three voices (fading out between 1.2x and 1.8x idle rpm), so a parked or idling car, including your own after you get out, sounds like idle; the other two cover the gears (V10: On5000 and On8000). 0: all three voices cover the gears and an idling car plays the lowest one at its pitch floor (a low on-load drone)."),
]

# New one-shot slots, blank (silent, no player) until synthesised sounds are uploaded.
_SLOTS = [
    ("ShiftThunk1", 0.5, "first shift clunk (dry clack-thump, alternates with ShiftThunk2)"),
    ("ShiftThunk2", 0.5, "second shift clunk (alternates with ShiftThunk1)"),
    ("ShiftVent1", 0.55, "first hard-upshift vent crackle (alternates with ShiftVent2; replaces the pop crackle when filled)"),
    ("ShiftVent2", 0.55, "second hard-upshift vent crackle (alternates with ShiftVent1)"),
]

ATTRIBUTES = [
    # The reactor whine uses the already-uploaded turbine_high loop until a reactor_whine upload replaces it.
    (PROFILE, "TurboWhistleAssetId", "rbxassetid://126900976760387"),
    # Rebuilds a running Exotic sound graph so the new values apply (36 at capture).
    (PROFILE, "ProfileRevision", 37),
]
for _name, _value, _text in _TUNING:
    ATTRIBUTES.append((PROFILE, _name, _value))
    ATTRIBUTES.append((PROFILE, _name + "_RaisingThisDoes", _text))
for _layer, _gain, _what in _SLOTS:
    ATTRIBUTES.append((PROFILE, _layer + "AssetId", ""))
    ATTRIBUTES.append((PROFILE, _layer + "AssetId_RaisingThisDoes",
                       "Roblox audio id for the " + _what + ". Blank is silent and creates no player."))
    ATTRIBUTES.append((PROFILE, _layer + "Gain", _gain))
    ATTRIBUTES.append((PROFILE, _layer + "Gain_RaisingThisDoes",
                       "Level of the " + _what + " at full shift strength. Raising it makes it louder; 0 silences it."))
    ATTRIBUTES.append((PROFILE, _layer + "Pitch", 1))
    ATTRIBUTES.append((PROFILE, _layer + "Pitch_RaisingThisDoes",
                       "Playback speed of the " + _what + ". Raising it makes it higher and shorter; lowering it deeper and longer."))
