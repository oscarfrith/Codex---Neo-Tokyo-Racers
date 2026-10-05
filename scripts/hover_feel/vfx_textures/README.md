# Exotic VFX textures

Procedural particle, beam and trail textures for the Exotic hover cars. Regenerate with

    py -3 scripts/hover_feel/vfx_textures/make_textures.py

(numpy only, about 40 s, fixed seeds). Pass texture names to rebuild only those. Output goes to
`output/vfx_textures/exotic/`: the PNGs, `manifest.json` (layout, frames, looping, tiling, emitter
notes), `verification.json` (the numeric checks) and `contact_sheet.png` (review image).

Convention: RGB is white/grey luminance and alpha is the shape, so the emitter Color does the
tinting. Flipbook frames read left to right, top to bottom, and every frame has a 4 px fully
transparent margin. Beam and trail strips tile along U (image width).

| File | What it is | How it is made |
| --- | --- | --- |
| fire_loop.png | 8x8 looping side-on flame tongue | Round-bottomed teardrop envelope bent by a warp field and eaten by fbm erosion that strengthens with height (tears the tip into wisps). Both fields scroll up by whole noise periods and are periodic in time, so the loop is exact. |
| fireball_burst.png | 8x8 one-shot explosion | Radial ball plus billow fbm (cauliflower lobes) in a noise domain that expands with the radius; a swirl warp rolls it, then the radial term fades and an erosion threshold rises so it breaks into wisps. Luminance = decaying heat + gradient-lit smoke, forced to fall after frame 1. |
| smoke_puff.png | 8x8 one-shot smoke/dust puff | Same cloud model as the fireball without heat: luminance is fake top-left lighting from the density gradient with dark creases between lobes. |
| dust_wisp.png | 4x4 looping ground dust | Anisotropic ridged fbm (long in X, thin in Y), domain-warped, scrolled one noise period per loop inside a flat lens envelope. |
| arc_flipbook.png | 4x4, sixteen different bolts | Midpoint-displacement polylines through the frame centre with tapering forks, rendered from exact segment distance: thin gaussian core plus wide glow, 3x supersampled. |
| shock_ring.png | Shockwave ring | Hard outer edge, crisp line, exponential inner haze; fbm sampled on a circle wobbles the radius and breaks the haze into radial streaks. |
| glow_soft.png | Radial glow | Gaussian core plus wide halo, windowed to reach zero, dithered against banding. |
| hover_pad.png | Top-down repulsor pad | Analytic polar shapes (rings, tick scale, segmented and dashed arcs) plus a hexagon grid with some lit cells in the middle band, then a small bloom. |
| spark_streak.png | Vertical spark, head at top | Gaussian cross-section that tapers in width and brightness from head to tail, round head cap, small head glow. |
| ember.png | Ember dot | Disc whose edge radius is perturbed by fbm, hot centre, faint halo. |
| jet_core.png | Beam: exhaust core | Two-gaussian V profile; U-periodic stretched fbm modulates brightness and breathes the width. |
| shock_diamonds.png | Beam: mach diamonds | Four identical 128 px cells: soft diamond node with a hot disk, crossing oblique-shock lines, thin core and a plume edge that pinches between nodes. |
| heat_streak.png | Beam: afterburner sheath | Warped ridged fbm, long in U, under a wide soft profile; low alpha so it layers over jet_core. |
| energy_ribbon.png | Trail: light ribbon | Hairline core and soft body, four comet-shaped pulses per tile and dashed edge rails. |

Tuning: each `make_*` function is self-contained. Noise that has to loop or tile uses the
periodic `fbm` with an integer period on that axis; keep `period * 2^(octaves-1) <= 256` there.
