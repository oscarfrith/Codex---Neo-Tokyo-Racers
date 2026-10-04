"""Modern Muscle concept round (2026-10-04): six hover muscle cars, front and rear three-quarter.

    py -3 scripts/exotic_category/categories/muscle/concepts/make_concepts.py front
    py -3 scripts/exotic_category/categories/muscle/concepts/make_concepts.py rear

Writes prompts and full-size PNGs under output/muscle-concepts-2026-10-04/ (not committed) and 1000 px JPEGs
under docs/design/vehicle-categories/img/muscle-modern/. Images come from the Codex image tool through
scripts/vehicle_blockouts/gen_image.py. The rear view takes the front image as a reference, so run front first.
Each car copies one real modern muscle car and maps its parts onto the seven module slots.
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
The car HOVERS about half a metre above the floor. It has NO wheels, NO tyres, NO rims and no hover rings or discs. Every wheel arch is closed by a flush body panel, and a jet thruster nozzle hangs under each corner pointing straight down, glowing {thrust} with heat haze and a soft glow on the floor.
Jet hardware is visible and part of the design:
- Front engine: {front_engine}
- Rear engine: {rear_engine}
- Corner lift thrusters: {thrusters}
- Overdrive afterburners where the exhausts would be: {boost}
Body:
- Nose: {nose}
- Tail: {tail}
- Wing: {wing}
- Signature detail: {motif}
The body is clearly modular: thin dark shadow gaps divide it into a nose clip, a bonnet engine module, the cabin, a rear haunch and tail module, sill burner modules and the wing, like parts that could be unbolted and swapped.
Two-tone paint on every panel: {paint}. Deep glossy metallic flake paint, satin black and carbon details, dark tinted glass.
Mood: exciting, sleek, modern, low, wide and menacing. Sharp crisp body lines.
Setting: dark studio with a glossy wet floor reflection, cool rim light, faint neon city glow far behind. The whole car is in frame.
No logos, no badges, no lettering, no numbers, no number plates, no text of any kind. No people."""

FRONT = "Camera: low front three-quarter view from the car's front left corner, showing the nose, bonnet and left side."
REAR = ("Reference 1 is the front view of this exact car. Draw the SAME car, same paint, same parts and same proportions, from behind.\n"
        "Camera: low rear three-quarter view from the car's rear right corner, showing the tail, rear engine nozzles, wing and right side. Afterburners lit.")

CARS = [
    {"key": "01-brawler", "real": "Dodge Challenger R/T Scat Pack Widebody (2023), a tall, long, boxy two-door coupe with a short upright notchback rear window",
     "thrust": "amber-white",
     "nose": "blunt upright nose with a narrow full-width slot grille and four round halo lamps set deep inside it",
     "front_engine": "a twin-nostril shaker turbine standing through a hole in the long flat bonnet, with the headlights mounted in its front fascia",
     "rear_engine": "two large round turbine barrels side by side set into the flat tail panel",
     "thrusters": "chunky round turbine cans, one under each corner",
     "boost": "long chrome side pipes running under each sill, ending in flared afterburner tips ahead of the rear arch",
     "tail": "flat square-cut tail with one full-width red light bar",
     "wing": "small one-piece ducktail lip on the boot edge",
     "motif": "a wide satin black stripe across the bonnet and tail, and boxy flared arches",
     "paint": "deep plum purple primary with satin black stripes and lower body"},
    {"key": "02-slingshot", "real": "Chevrolet Camaro SS (2022), a low two-door coupe with a chopped roof, tiny side windows and very high shoulders",
     "thrust": "ice blue",
     "nose": "low wedge nose with thin horizontal slit headlights above a huge open lower mouth",
     "front_engine": "a low flat heat-extractor turbine with a wide slot intake sunk into the bonnet, slit headlights on its leading edge",
     "rear_engine": "one wide flat slot burner across the tail between the lamps",
     "thrusters": "angular rectangular vectoring nozzles, one under each corner",
     "boost": "flat slot burners flush in each sill, just ahead of the rear arch",
     "tail": "short chopped Kamm tail with four small rectangular red lamps",
     "wing": "thin blade wing on two short uprights",
     "motif": "sharp creased shoulders and a black bonnet insert around the turbine",
     "paint": "bright yellow primary with gloss black bonnet insert, roof and sills"},
    {"key": "03-stallion", "real": "Ford Mustang GT fastback (2024, S650), a long-bonnet two-door fastback with a sloping roof",
     "thrust": "cyan-white",
     "nose": "forward-leaning shark nose with a large hexagonal grille and three-bar LED headlights",
     "front_engine": "a central ram-air turbine with a round intake between two bonnet heat-extractor vents, three-bar headlights on the engine module fascia",
     "rear_engine": "exactly FOUR small round jet nozzles arranged as a square, two on the left stacked and two on the right stacked, at the four corners of a recessed black tail bay (not two big nozzles)",
     "thrusters": "slim round jets on short struts, one under each corner",
     "boost": "short flared megaphone burners exiting the sill behind each front arch",
     "tail": "concave tail panel with three vertical red light bars on each side",
     "wing": "low, small raised pedestal spoiler close to the boot lid, body colour (not a tall racing wing)",
     "motif": "twin white racing stripes over the bonnet, roof and tail, and a fastback roofline",
     "paint": "vivid blue primary with white twin stripes and black lower body"},
    {"key": "04-blackjack", "real": "Cadillac CT5-V Blackwing (2023), a muscular four-door sports saloon with a formal upright roof and long boot",
     "thrust": "violet-white",
     "nose": "shield-shaped mesh grille flanked by tall vertical LED blade headlights",
     "front_engine": "a carbon power-dome bonnet with twin slot intakes feeding a hidden turbine, vertical blade headlights on the engine module corners",
     "rear_engine": "two turbines stacked one above the other in the centre of the tail",
     "thrusters": "half-skirted triple small nozzles under each corner",
     "boost": "three slim pipes grouped under each sill, in bare titanium",
     "tail": "upright tail with tall vertical red blade lamps at each edge and a carbon diffuser",
     "wing": "low carbon lip with a small upturned gurney edge",
     "motif": "bronze pinstripe along the shoulder, carbon bonnet dome and four doors",
     "paint": "dark emerald green primary with exposed carbon and bronze accents"},
    {"key": "05-voltage", "real": "Dodge Charger Daytona coupe (2024), a wide fastback coupe with a blunt nose and a hatchback tail",
     "thrust": "electric white-blue",
     "nose": "blunt flat nose with a pass-through wing: air flows through an open slot between the nose and the bonnet, and one thin full-width white light bar",
     "front_engine": "a flat twin-rotor turbine visible inside the pass-through nose slot, the full-width light bar on its front edge",
     "rear_engine": "one huge central turbine nozzle framed by the tail lamp ring",
     "thrusters": "flat rectangular thrust paddles on short struts under each corner",
     "boost": "a pair of short fat tubes under each sill",
     "tail": "smooth fastback hatch ending in one continuous red light ring around the whole tail panel",
     "wing": "an integrated lip on the fastback with a raised active flap",
     "motif": "clean slab sides with one sharp shoulder line, black roof flowing into the hatch",
     "paint": "bright red primary with gloss black roof, hatch and nose slot"},
    {"key": "06-apex", "real": "Ford Mustang GTD (2025), a very wide carbon-bodied track fastback with huge vented fenders",
     "thrust": "orange-white",
     "nose": "wide gaping grille over a long flat carbon splitter with canards, slim angry headlights",
     "front_engine": "a bonnet with two large louvred extractor vents and an exposed turbine between them, slim headlights on the engine module",
     "rear_engine": "two big titanium afterburner nozzles close together in the centre of the tail, above a deep finned diffuser",
     "thrusters": "long jets on struts standing proud of the body, behind louvred fender vents",
     "boost": "two slim tubes slung under each carbon sill",
     "tail": "wide tail with three-bar lamps pushed to the edges and an open mesh panel showing the engine",
     "wing": "tall swan-neck racing wing hung from above on two uprights",
     "motif": "louvred vents on top of all four fenders and much wider hips than the cabin",
     "paint": "satin gunmetal grey primary with exposed carbon and bright orange accents"},
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
