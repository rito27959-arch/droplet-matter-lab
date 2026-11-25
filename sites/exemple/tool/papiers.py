"""Fonds d'écran pour la page des composants : des nappes de couleur et des formes
nettes, pour que la réfraction du verre se voie. Procédural. Usage : python3 tool/papiers.py"""
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

W, H = 2400, 1600
y, x = np.mgrid[0:H, 0:W].astype(float)

def blob(cx, cy, r, colour, k=1.0):
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    w = np.exp(-d * d * 1.6) * k
    return w[..., None] * np.array(colour, float)[None, None, :], w[..., None]

def field(base, blobs):
    acc = np.zeros((H, W, 3)); wsum = np.full((H, W, 1), 0.35)
    acc += np.array(base, float) * 0.35
    for b in blobs:
        c, w = blob(*b); acc += c; wsum += w
    return acc / wsum

def make(dark):
    if dark:
        img = field((6, 10, 22), [
            (500, 400, 700, (40, 70, 190)), (1700, 300, 650, (150, 50, 120)),
            (1300, 1200, 800, (20, 120, 140)), (2200, 1300, 500, (210, 110, 40)), (200, 1400, 500, (90, 40, 160))])
    else:
        img = field((236, 240, 244), [
            (500, 400, 700, (120, 170, 255)), (1700, 300, 650, (255, 150, 170)),
            (1300, 1200, 800, (120, 220, 200)), (2200, 1300, 500, (255, 200, 110)), (200, 1400, 500, (190, 160, 255))])
    im = Image.fromarray(img.clip(0, 255).astype(np.uint8)).convert('RGBA')
    # Des formes nettes : sans bord net derrière, la réfraction ne se voit pas.
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ink = (255, 255, 255, 70) if dark else (255, 255, 255, 150)
    for i in range(14):
        r = 120 + i * 95
        d.ellipse([1500 - r, 700 - r, 1500 + r, 700 + r], outline=ink, width=3)
    for i in range(0, W, 80):
        d.line([(i, 0), (i - 500, H)], fill=(255, 255, 255, 22 if dark else 45), width=2)
    rng = np.random.default_rng(4)
    for _ in range(26):
        cx, cy, r = rng.integers(0, W), rng.integers(0, H), rng.integers(30, 120)
        col = [(255, 210, 120), (120, 200, 255), (255, 120, 150), (170, 255, 200)][rng.integers(4)]
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (150 if dark else 170,))
    im.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.6)))
    return im.convert('RGB')

make(True).save('public/images/papier-sombre.jpg', quality=86, optimize=True, progressive=True)
make(False).save('public/images/papier-clair.jpg', quality=86, optimize=True, progressive=True)
print('ok')
