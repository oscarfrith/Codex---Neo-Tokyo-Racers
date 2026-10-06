"""Direction-coded cubemap (RGB = xyz) used once to check the face convention in Studio."""
import numpy as np
from PIL import Image
from pathlib import Path
from cube import FACES, directions
out = Path(__file__).resolve().parent / 'debug'; out.mkdir(exist_ok=True)
for face in FACES:
    d = directions(face, 256)
    Image.fromarray((np.clip(d * 0.5 + 0.5, 0, 1) * 255).astype(np.uint8)).save(out / f'debug_{face}.png')
print('ok')
