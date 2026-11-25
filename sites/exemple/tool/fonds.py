"""Génère les deux fonds de la vitre : ville au crépuscule (sombre) et jour couvert (clair).
Procédural, sans photo : aucune question de droits. Usage : python3 tool/fonds.py"""
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

W, H = 2400, 1500
rng = np.random.default_rng(11)

def gradient(top, mid, bottom, split=0.62):
    y = np.linspace(0, 1, H)[:, None]
    t, m, b = (np.array(c, float) for c in (top, mid, bottom))
    a = np.clip(y / split, 0, 1)[..., None]
    c = np.where(y[..., None] < split, t + (m - t) * a, m + (b - m) * np.clip((y - split) / (1 - split), 0, 1)[..., None])
    return np.repeat(c, W, axis=1)

def skyline(draw, base, colour, window, lit, count, hmin, hmax, wmin, wmax):
    x = -40
    while x < W:
        w = rng.integers(wmin, wmax); h = rng.integers(hmin, hmax)
        draw.rectangle([x, base - h, x + w, H], fill=colour)
        if window:
            for wy in range(base - h + 18, base - 10, 22):
                for wx in range(x + 10, x + w - 10, 16):
                    if rng.random() < lit:
                        draw.rectangle([wx, wy, wx + 6, wy + 9], fill=window[rng.integers(len(window))])
        x += w + rng.integers(2, 30)

def bokeh(img, n, colours, rmin, rmax, ymin, ymax, alpha):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        r = rng.integers(rmin, rmax); x = rng.integers(0, W); y = rng.integers(ymin, ymax)
        c = colours[rng.integers(len(colours))]
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (int(alpha * (0.5 + rng.random() * 0.5)),))
    layer = layer.filter(ImageFilter.GaussianBlur(2.5))
    # Lumière additive : les disques s'éclairent l'un l'autre au lieu de se masquer.
    base = np.asarray(img).astype(float)
    l = np.asarray(layer).astype(float)
    add = l[..., :3] * (l[..., 3:4] / 255.0)
    out = base.copy(); out[..., :3] = 255 - (255 - base[..., :3]) * (255 - add) / 255
    img.paste(Image.fromarray(out.clip(0, 255).astype(np.uint8)))

def make(dark):
    if dark:
        sky = gradient((8, 14, 30), (44, 38, 64), (92, 52, 50))
    else:
        sky = gradient((196, 206, 216), (220, 226, 231), (206, 210, 212))
    img = Image.fromarray(sky.astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(img)
    if dark:
        skyline(d, 1040, (22, 24, 40), [(255, 200, 120), (255, 226, 170), (170, 210, 255)], 0.18, 0, 260, 620, 90, 220)
        skyline(d, 1180, (12, 13, 22), [(255, 190, 110), (255, 240, 200)], 0.22, 0, 180, 520, 120, 260)
    else:
        skyline(d, 1040, (168, 178, 188), None, 0, 0, 260, 620, 90, 220)
        skyline(d, 1180, (136, 146, 156), [(250, 236, 200)], 0.05, 0, 180, 520, 120, 260)
    # La mise au point est sur la vitre : la ville derrière est floue.
    img = img.filter(ImageFilter.GaussianBlur(7))
    if dark:
        bokeh(img, 70, [(255, 160, 70), (255, 205, 140), (230, 70, 60), (110, 180, 255), (255, 240, 220)], 22, 80, 1080, 1500, 90)
        bokeh(img, 50, [(255, 190, 120), (200, 220, 255)], 5, 12, 650, 1150, 140)
    else:
        bokeh(img, 26, [(255, 246, 220), (255, 230, 180), (255, 255, 255)], 24, 70, 1100, 1500, 50)
    return img.convert('RGB').filter(ImageFilter.GaussianBlur(1.5))

make(True).save('public/images/vitre-sombre.jpg', quality=84, optimize=True, progressive=True)
make(False).save('public/images/vitre-clair.jpg', quality=84, optimize=True, progressive=True)
print('ok')
