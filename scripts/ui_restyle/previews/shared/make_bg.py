"""Placeholder scenery for the previews: the accepted mockups, with their brightest UI blocks
painted out, scaled to 1920x1080 and heavily blurred. Not game art. Run: py -3 make_bg.py"""
import os
from PIL import Image, ImageDraw, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "..", "..", "assets", "ui", "mockups", "pulse_restyle")
JOBS = {  # name: (file, [(x0,y0,x1,y1,(r,g,b))...]) in 1200x675 mockup pixels
    "city": ("01-free-roam.jpg", [(30,30,330,356,(70,52,60)),(826,34,1168,130,(60,48,62)),(906,84,960,130,(60,48,62)),(990,470,1100,600,(40,36,44)),(550,240,820,310,(70,60,70))]),
    "garage": ("04-customise-parts.jpg", [(968,410,1142,584,(24,22,44)),(850,36,1160,84,(18,16,40)),(836,94,1140,352,(22,20,48)),(936,594,1140,650,(14,12,24)),(60,40,390,120,(20,20,60))]),
    "race": ("09-race-hud-sketch.jpg", [(908,34,1168,176,(28,16,60)),(30,30,180,176,(24,14,52)),(490,28,740,134,(26,16,58)),(990,480,1110,590,(16,13,30))]),
    "dealer": ("07-dealership-sketch.jpg", [(56,408,1200,586,(18,15,48)),(836,92,1142,332,(26,20,70)),(740,594,890,652,(12,10,36)),(262,412,486,584,(22,18,60)),(888,594,1142,652,(12,10,36)),(850,36,1160,84,(18,14,48)),(60,36,340,112,(16,13,46))]),
}
os.makedirs(os.path.join(HERE, "bg"), exist_ok=True)
for name, (f, rects) in JOBS.items():
    im = Image.open(os.path.join(SRC, f)).convert("RGB")
    d = ImageDraw.Draw(im)
    for x0, y0, x1, y1, c in rects:
        d.rectangle([x0, y0, x1, y1], fill=c)
    im = im.resize((1920, 1080), Image.LANCZOS).filter(ImageFilter.GaussianBlur(26))
    im.save(os.path.join(HERE, "bg", name + ".jpg"), quality=82)
    print("wrote", name)
