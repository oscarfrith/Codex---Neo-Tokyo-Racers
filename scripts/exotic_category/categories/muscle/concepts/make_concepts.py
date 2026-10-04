"""Modern Muscle concept rounds (2026-10-04): six hover muscle cars, front and rear three-quarter.

    py -3 scripts/exotic_category/categories/muscle/concepts/make_concepts.py front [key ...]
    py -3 scripts/exotic_category/categories/muscle/concepts/make_concepts.py rear  [key ...]

Writes prompts and full-size PNGs under output/muscle-concepts-2026-10-04/ (not committed) and 1000 px JPEGs
under docs/design/vehicle-categories/img/muscle-modern/. Images come from the Codex image tool through
scripts/vehicle_blockouts/gen_image.py. The rear view takes the front image as a reference, so run front first.

Round 2 (file prefix r2-): the Exotic module layout (four corner engine pods, sideways drift thrusters in the
sills, overdrive at the centre rear) drawn as muscle cars, and kept as far from the Exotic look as possible:
tall, boxy, long bonnet, real cabin, square bolted-on pods, bare metal hardware, bonnet turbine.
Round 1 (bonnet engine, lift jets under blanked arches) is in git history at 88d7fe4.
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", ".."))
OUT = os.path.join(REPO, "output", "muscle-concepts-2026-10-04")
DOCS = os.path.join(REPO, "docs", "design", "vehicle-categories", "img", "muscle-modern")
GEN = os.path.join(REPO, "scripts", "vehicle_blockouts", "gen_image.py")

SHARED = """Automotive concept art, photoreal studio render of a HOVER muscle car for a futuristic street racing game.
It is closely based on the {real}: copy that car's proportions, roofline, glasshouse, grille shape and light signature, then make it slightly more futuristic.
It must read as an American muscle car, NOT a low supercar: tall, upright, heavy and boxy, a long bonnet with the cabin set back, a real cabin with pillars and side windows, slab sides, a high beltline, hard straight creases, and a nose-down raked stance.
The car HOVERS about half a metre above the floor. It has NO wheels, NO tyres, NO rims and no rings or discs. Where the four wheels would be there are four separate ENGINE PODS instead: square-shouldered, blocky, industrial jet engine boxes with flat faces, bolted to the body and separated from it by a clear dark gap, with bare metal turbine hardware, heat shields and bolts showing. The pod sides are solid flat panels with no wheel arch opening and no circular shape. The two rear pods are bigger than the two front pods. Each pod glows {thrust} underneath with heat haze on the floor.
Jet hardware, all clearly visible:
- Front engine pods (front corners): {front_pods}
- Rear engine pods (rear corners): {rear_pods}
- Drift thrusters: {thrusters}, set into the sill between the front and rear pods on each side, pointing straight out SIDEWAYS, with short flames shooting sideways.
- Overdrive afterburners at the centre of the tail under the bumper, where the exhaust tips would be: {boost}
- Bonnet turbine: {bonnet}
Body:
- Nose: {nose}
- Tail: {tail}
- Wing: {wing}
- Signature detail: {motif}
The body is clearly modular: thin dark shadow gaps divide it into a nose clip with the bonnet, the cabin, a tail module, four engine pods, sill thruster modules and the wing, like parts that could be unbolted and swapped.
Two-tone paint on every panel and pod: {paint}. Deep glossy metallic flake paint, chrome and bare metal jet hardware, satin black details, dark tinted glass.
Mood: exciting, sleek, modern, wide and menacing. Sharp crisp body lines.
Setting: dark studio with a glossy wet floor reflection, cool rim light, faint neon city glow far behind. The whole car is in frame.
No logos, no badges, no emblems in the grille, no lettering, no numbers, no number plates, no text of any kind. No people."""

FRONT = "Camera: low front three-quarter view from the car's front left corner, showing the nose, bonnet, both left engine pods and the left sill thrusters."
REAR = ("Reference 1 is the front view of this exact car. Draw the SAME car, same paint, same parts and same proportions, from behind.\n"
        "Camera: low rear three-quarter view from the car's rear right corner, showing the tail, the big rear engine pod nozzles firing backwards, the centre overdrive afterburners, the wing, and the right sill thrusters firing sideways.")

CARS = [
    {"key": "r2-01-enforcer", "real": "Dodge Charger R/T four-door sedan (2019), a big plain four-door saloon with scalloped doors and a fast rear window",
     "thrust": "amber-white",
     "nose": "wide thin crosshair grille with slim squinting headlights, plain honest bumper",
     "front_pods": "plain square box pods with the slim headlights on their front faces and a small grilled exit on the outer side",
     "rear_pods": "taller square box pods, each ending in one plain round nozzle firing backwards",
     "thrusters": "two plain round steel pipes per side",
     "boost": "two small round tips",
     "bonnet": "none yet, only a shallow central bonnet bulge with a small intake slot (this is the entry car)",
     "tail": "one continuous red racetrack light loop around the tail panel",
     "wing": "small body-colour lip spoiler",
     "motif": "steel bull bar across the nose and a plain black lower body, like an unmarked pursuit car",
     "paint": "gloss white primary with satin black lower body and pods"},
    {"key": "r2-02-outlaw", "real": "Holden HSV Maloo ute (2017), a low two-door coupe utility: a muscle car cab with an open pickup load bed behind it",
     "thrust": "orange-white",
     "nose": "wide low grille with twin nostrils and angular headlights, deep chin",
     "front_pods": "chunky wedge-fronted box pods with the angular headlights on their front faces and a vertical vent on the outer side",
     "rear_pods": "long box pods running the length of the load bed sides, each ending in a rectangular nozzle firing backwards",
     "thrusters": "one wide rectangular slot per side",
     "boost": "a single wide flat burner",
     "bonnet": "a low twin-snorkel ram intake turbine on the bonnet",
     "tail": "flat tailgate with tall vertical lamps at the edges and an open load bed holding a hard tonneau cover with a sail plane behind the cab",
     "wing": "a low hoop bar over the load bed just behind the cab",
     "motif": "the open pickup bed and the sail-plane buttresses behind the cab",
     "paint": "burnt orange primary with gloss black bonnet, tonneau and pods"},
    {"key": "r2-03-slingshot", "real": "Chevrolet Camaro SS (2022), a two-door coupe with a chopped roof, tiny side windows and very high shoulders",
     "thrust": "ice blue",
     "nose": "wedge nose with thin horizontal slit headlights above a huge open lower mouth",
     "front_pods": "sharp faceted angular pods with the slit headlights wrapping onto their front faces and gill slots on the outer side",
     "rear_pods": "wide faceted pods with high square shoulders, each ending in a flat wide slot nozzle firing backwards",
     "thrusters": "three small square vectoring nozzles in a row per side",
     "boost": "four small square tips in a row",
     "bonnet": "a low flat heat-extractor turbine with a wide slot intake sunk into a black bonnet insert",
     "tail": "short chopped Kamm tail with four small rectangular red lamps",
     "wing": "thin blade wing on two short uprights",
     "motif": "sharp creased shoulders, gloss black roof and bonnet insert",
     "paint": "bright yellow primary with gloss black bonnet insert, roof and pod faces"},
    {"key": "r2-04-stallion", "real": "Ford Mustang GT fastback (2024, S650), a long-bonnet two-door fastback with a sloping roof",
     "thrust": "cyan-white",
     "nose": "forward-leaning shark nose with a large hexagonal grille and three-bar LED headlights",
     "front_pods": "smooth-topped square pods with the three-bar headlights on their front faces and a side-exit megaphone pipe on the outer side",
     "rear_pods": "broad-hipped square pods, each ending in two stacked round nozzles firing backwards",
     "thrusters": "one flared megaphone pipe per side",
     "boost": "two large round tips set wide apart",
     "bonnet": "a round ram-air turbine standing up through the centre of the bonnet between two heat-extractor vents",
     "tail": "concave tail panel with three vertical red light bars on each side",
     "wing": "low pedestal spoiler close to the boot lid, body colour",
     "motif": "twin white racing stripes over the bonnet, roof and tail, and a fastback roofline",
     "paint": "vivid blue primary with white twin stripes and black lower body"},
    {"key": "r2-05-blackjack", "real": "Cadillac CT5-V Blackwing (2023), a muscular four-door sports saloon with a formal upright roof and long boot",
     "thrust": "violet-white",
     "nose": "shield-shaped mesh grille flanked by tall vertical LED blade headlights",
     "front_pods": "tall narrow carbon box pods with the vertical blade headlights on their front edges and bronze heat-shield plates on the outer side",
     "rear_pods": "tall carbon box pods with vertical red blade lamps on their rear edges, each ending in two stacked rectangular nozzles firing backwards",
     "thrusters": "three slim bare titanium pipes grouped per side",
     "boost": "four round titanium tips in two stacked pairs",
     "bonnet": "a carbon power dome with twin slot intakes and a low turbine showing between them",
     "tail": "upright tail with a carbon diffuser, the vertical lamps carried on the rear pods",
     "wing": "low carbon lip with a small upturned edge",
     "motif": "bronze pinstripe along the shoulder, carbon bonnet dome and four doors",
     "paint": "dark emerald green primary with exposed carbon and bronze accents"},
    {"key": "r2-06-brawler", "real": "Dodge Challenger SRT Demon Widebody (2023), a huge, long, boxy two-door coupe with a short upright notchback rear window",
     "thrust": "red-orange",
     "nose": "blunt upright nose with a narrow full-width slot grille and four round halo lamps set deep inside it",
     "front_pods": "massive boxy flared pods with one halo lamp pair on each front face and a huge open side-exit pipe on the outer side",
     "rear_pods": "enormous square drag-car pods, far bigger than the front ones, each ending in one giant round turbine barrel firing backwards",
     "thrusters": "two fat chrome bazooka tubes per side",
     "boost": "two huge round chrome barrels close together",
     "bonnet": "a giant twin-barrel shaker turbine standing tall through a hole in the long flat bonnet, the biggest of any car",
     "tail": "flat square-cut tail with one full-width red light bar",
     "wing": "small one-piece ducktail lip on the boot edge",
     "motif": "a wide satin black stripe across the bonnet and tail, drag-car rake with the tail high",
     "paint": "deep plum purple primary with satin black stripes, pods and lower body"},
]


def run(car, view):
    os.makedirs(os.path.join(OUT, "prompts"), exist_ok=True)
    os.makedirs(DOCS, exist_ok=True)
    name = "%s-%s" % (car["key"], view)
    prompt = SHARED.format(**car) + "\n" + (FRONT if view == "front" else REAR)
    prompt_path = os.path.join(OUT, "prompts", name + ".txt")
    with open(prompt_path, "w", encoding="utf-8") as handle:
        handle.write(prompt)
    args = [sys.executable, GEN, os.path.join(OUT, name + ".png"), prompt_path, "--jpg", os.path.join(DOCS, name + ".jpg")]
    if view == "rear":
        args += ["--ref", os.path.join(OUT, car["key"] + "-front.png")]
    proc = subprocess.run(args, cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return name, proc.returncode, (proc.stdout + proc.stderr).strip().splitlines()[-1:] or [""]


def main():
    view = sys.argv[1]
    assert view in ("front", "rear")
    only = sys.argv[2:]
    cars = [c for c in CARS if not only or c["key"] in only]
    with ThreadPoolExecutor(max_workers=6) as pool:
        for name, code, tail in pool.map(lambda c: run(c, view), cars):
            print(name, "ok" if code == 0 else "FAILED", tail[0][:160])


if __name__ == "__main__":
    main()
