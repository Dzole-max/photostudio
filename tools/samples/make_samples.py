"""Generates the bundled sample photo sets ("Try a sample book"): a wedding in
Ohrid and a trip to Zanzibar, as illustrated placeholder photos. Each set has
a manifest with capture time, GPS, face boxes and labels, standing in for the
EXIF data and on-device ML results a real gallery would give.

The sets deliberately contain a burst, near-duplicates and a blurry frame so
curation has something to set aside.

Usage: python tools/samples/make_samples.py   (requires Pillow)
Output: apps/mobile/assets/samples/<set>/*.jpg + manifest.json
        packages/layout_spec/fixtures/sample_<set>.json (manifest copy for tests)
"""

import json
import zlib
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps" / "mobile" / "assets" / "samples"
FIX = ROOT / "packages" / "layout_spec" / "fixtures"

SKIN = [(233, 196, 170), (214, 168, 132), (176, 122, 88), (120, 82, 58), (245, 212, 190)]
HAIR = [(40, 30, 25), (90, 60, 40), (150, 110, 70), (20, 18, 16), (200, 160, 110)]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Scene:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        # Warm neutral ground so no scene ever shows unpainted black.
        self.img = Image.new("RGB", (w, h), (226, 214, 196))
        self.d = ImageDraw.Draw(self.img)
        self.r = random.Random(seed)
        self.faces = []

    # --- backgrounds -----------------------------------------------------
    def gradient(self, top, bottom, y0=0, y1=None):
        y1 = self.h if y1 is None else y1
        for y in range(y0, y1):
            t = (y - y0) / max(1, y1 - y0 - 1)
            self.d.line([(0, y), (self.w, y)], fill=lerp(top, bottom, t))

    def sun(self, cx, cy, r, color, glow=True):
        if glow:
            for i in range(6, 0, -1):
                rr = r * (1 + i * 0.35)
                c = lerp(color, self.img.getpixel((min(self.w - 1, int(cx + rr)), int(cy)))[:3], 0.5 + i * 0.07)
                self.d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c)
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)

    def sea(self, y, top, bottom, waves=(255, 255, 255)):
        self.gradient(top, bottom, y, self.h)
        for i in range(40):
            wy = y + (self.h - y) * (i / 40) ** 1.6
            x = self.r.random() * self.w
            ln = self.w * (0.02 + 0.05 * i / 40)
            self.d.line([(x, wy), (x + ln, wy)], fill=lerp(waves, top, 0.55), width=max(1, int(i / 10)))

    def sand(self, y, color, curve=0.04):
        pts = [(0, self.h)]
        for i in range(0, 41):
            x = self.w * i / 40
            pts.append((x, y + math.sin(i / 40 * math.pi * 1.3) * self.h * curve))
        pts.append((self.w, self.h))
        self.d.polygon(pts, fill=color)

    def hills(self, y, color, amp=0.08, freq=2.0, phase=0.0):
        pts = [(0, self.h)]
        for i in range(0, 81):
            x = self.w * i / 80
            yy = y - (math.sin(i / 80 * math.pi * freq + phase) * 0.5 + 0.5) * self.h * amp
            yy -= math.sin(i / 80 * math.pi * freq * 3.1 + phase) * self.h * amp * 0.15
            pts.append((x, yy))
        pts.append((self.w, self.h))
        self.d.polygon(pts, fill=color)

    # --- objects -----------------------------------------------------------
    def palm(self, x, base, height, color=(40, 60, 45)):
        lean = self.r.uniform(-0.15, 0.15) * height
        top = (x + lean, base - height)
        self.d.line([(x, base), top], fill=(70, 55, 40), width=max(3, int(height * 0.035)))
        for a in range(0, 360, 45):
            ang = math.radians(a + self.r.uniform(-10, 10))
            ln = height * 0.38
            end = (top[0] + math.cos(ang) * ln, top[1] + math.sin(ang) * ln * 0.55 + ln * 0.18)
            mid = ((top[0] + end[0]) / 2, (top[1] + end[1]) / 2 - ln * 0.12)
            self.d.polygon([top, mid, end, (mid[0], mid[1] + ln * 0.08)], fill=color)

    def building(self, x, y, w, h, wall, trim, windows=True, door=False):
        self.d.rectangle([x, y, x + w, y + h], fill=wall)
        self.d.rectangle([x, y, x + w, y + h * 0.04], fill=trim)
        if windows:
            cols = max(1, int(w / (self.w * 0.05)))
            rows = max(1, int(h / (self.h * 0.12)))
            for c in range(cols):
                for rr in range(rows):
                    wx = x + w * (c + 0.3) / cols
                    wy = y + h * (rr + 0.25) / (rows + 0.4)
                    ww, wh = w / cols * 0.4, h / rows * 0.35
                    self.d.rectangle([wx, wy, wx + ww, wy + wh], fill=lerp(trim, (30, 30, 30), 0.4))
        if door:
            dw, dh = w * 0.3, h * 0.35
            dx = x + (w - dw) / 2
            self.d.rectangle([dx, y + h - dh, dx + dw, y + h], fill=(90, 55, 30))

    def carved_door(self):
        w, h = self.w, self.h
        self.gradient((214, 196, 170), (190, 170, 140))
        dx0, dx1 = w * 0.22, w * 0.78
        dy0, dy1 = h * 0.12, h * 0.95
        self.d.rectangle([dx0 - w * 0.04, dy0 - h * 0.03, dx1 + w * 0.04, dy1], fill=(120, 80, 50))
        self.d.rectangle([dx0, dy0, dx1, dy1], fill=(96, 60, 34))
        self.d.line([((dx0 + dx1) / 2, dy0), ((dx0 + dx1) / 2, dy1)], fill=(60, 36, 20), width=int(w * 0.012))
        for row in range(6):
            for col in range(2):
                cx = dx0 + (dx1 - dx0) * (0.25 + col * 0.5)
                cy = dy0 + (dy1 - dy0) * (0.12 + row * 0.15)
                r = w * 0.025
                self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(190, 150, 80))
        self.d.pieslice([dx0, dy0 - h * 0.12, dx1, dy0 + h * 0.12], 180, 360, fill=(110, 70, 40))

    def boat(self, x, y, size, hull=(90, 60, 40), sail=(240, 232, 214)):
        self.d.polygon([(x - size, y), (x + size, y), (x + size * 0.7, y + size * 0.25), (x - size * 0.7, y + size * 0.25)], fill=hull)
        self.d.line([(x, y), (x, y - size * 1.1)], fill=(60, 45, 35), width=max(2, int(size * 0.04)))
        self.d.polygon([(x, y - size * 1.1), (x + size * 0.9, y - size * 0.1), (x, y - size * 0.05)], fill=sail)

    def tree(self, x, base, h, color):
        self.d.line([(x, base), (x, base - h * 0.4)], fill=(70, 50, 35), width=max(3, int(h * 0.05)))
        for i in range(3):
            r = h * (0.32 - i * 0.07)
            cy = base - h * (0.45 + i * 0.18)
            self.d.ellipse([x - r, cy - r, x + r, cy + r], fill=lerp(color, (255, 255, 255), i * 0.08))

    def person(self, cx, base, height, outfit, skin=None, hair=None, veil=False, eyes=0.95, smile=0.8):
        skin = skin or self.r.choice(SKIN)
        hair = hair or self.r.choice(HAIR)
        head_r = height * 0.11
        head_cy = base - height + head_r
        body_top = head_cy + head_r * 0.9
        # body
        self.d.polygon(
            [(cx - height * 0.16, base), (cx + height * 0.16, base), (cx + height * 0.12, body_top + height * 0.08),
             (cx, body_top), (cx - height * 0.12, body_top + height * 0.08)],
            fill=outfit,
        )
        if veil:
            self.d.polygon([(cx - head_r * 1.1, head_cy - head_r * 0.8), (cx + head_r * 1.1, head_cy - head_r * 0.8), (cx + height * 0.2, base - height * 0.3), (cx - height * 0.2, base - height * 0.3)], fill=(250, 248, 244))
        # hair + head
        self.d.ellipse([cx - head_r * 1.08, head_cy - head_r * 1.12, cx + head_r * 1.08, head_cy + head_r * 0.7], fill=hair)
        self.d.ellipse([cx - head_r * 0.92, head_cy - head_r, cx + head_r * 0.92, head_cy + head_r], fill=skin)
        if eyes > 0.5:
            er = head_r * 0.09
            for ex in (-0.33, 0.33):
                self.d.ellipse([cx + ex * head_r - er, head_cy - head_r * 0.1 - er, cx + ex * head_r + er, head_cy - head_r * 0.1 + er], fill=(40, 30, 30))
        else:
            for ex in (-0.33, 0.33):
                self.d.line([(cx + ex * head_r - head_r * 0.12, head_cy - head_r * 0.1), (cx + ex * head_r + head_r * 0.12, head_cy - head_r * 0.1)], fill=(40, 30, 30), width=max(1, int(head_r * 0.06)))
        self.d.arc([cx - head_r * 0.35, head_cy + head_r * 0.1, cx + head_r * 0.35, head_cy + head_r * 0.55], 20, 160, fill=(150, 70, 60), width=max(1, int(head_r * 0.07)))
        box = [(cx - head_r) / self.w, (head_cy - head_r) / self.h, 2 * head_r / self.w, 2 * head_r / self.h]
        self.faces.append({"x": round(box[0], 4), "y": round(box[1], 4), "w": round(box[2], 4), "h": round(box[3], 4),
                           "eyesOpen": eyes, "smile": smile})

    def lights(self, y, color=(255, 214, 140)):
        for row in range(2):
            pts = []
            for i in range(0, 41):
                x = self.w * i / 40
                yy = y + row * self.h * 0.06 + math.sin(i / 40 * math.pi * 3) * self.h * 0.03
                pts.append((x, yy))
            self.d.line(pts, fill=(60, 50, 40), width=2)
            for x, yy in pts[::2]:
                r = self.w * 0.006
                self.d.ellipse([x - r, yy, x + r, yy + 2 * r], fill=color)

    def church(self, x, base, size, wall=(206, 150, 110)):
        w = size
        self.d.rectangle([x - w * 0.5, base - w * 0.5, x + w * 0.5, base], fill=wall)
        self.d.polygon([(x - w * 0.55, base - w * 0.5), (x + w * 0.55, base - w * 0.5), (x, base - w * 0.85)], fill=(150, 80, 60))
        self.d.ellipse([x - w * 0.18, base - w * 1.05, x + w * 0.18, base - w * 0.7], fill=wall)
        self.d.rectangle([x - w * 0.02, base - w * 1.22, x + w * 0.02, base - w * 1.02], fill=(90, 70, 50))

    def flowers(self, cx, cy, r, colors):
        for i in range(26):
            a = self.r.random() * math.tau
            d = r * math.sqrt(self.r.random())
            x, y = cx + math.cos(a) * d, cy + math.sin(a) * d
            fr = r * self.r.uniform(0.16, 0.26)
            self.d.ellipse([x - fr, y - fr, x + fr, y + fr], fill=self.r.choice(colors))
            self.d.ellipse([x - fr * 0.3, y - fr * 0.3, x + fr * 0.3, y + fr * 0.3], fill=(250, 230, 150))

    def texture(self, amount=6):
        """Gentle paper-like noise so hashing/sharpness have real detail."""
        noise = Image.effect_noise((self.w // 4, self.h // 4), amount).resize((self.w, self.h)).convert("RGB")
        self.img = Image.blend(self.img, noise, 0.04)
        self.d = ImageDraw.Draw(self.img)


# ---------------------------------------------------------------------------
# Scene recipes


def ohrid_lake(s, sunset=False):
    sky = ((248, 196, 150), (250, 226, 200)) if sunset else ((150, 190, 222), (222, 234, 240))
    s.gradient(sky[0], sky[1], 0, int(s.h * 0.55))
    if sunset:
        s.sun(s.w * 0.72, s.h * 0.42, s.w * 0.04, (255, 236, 200))
    s.hills(int(s.h * 0.55), (110, 130, 140) if not sunset else (140, 110, 120), amp=0.12, freq=1.3, phase=0.8)
    s.sea(int(s.h * 0.55), (90, 140, 170) if not sunset else (200, 150, 140), (40, 90, 120) if not sunset else (120, 90, 110))


def wedding_set():
    L, P, S = (3000, 2000), (2000, 3000), (2400, 2400)
    items = []

    def add(name, size, time, recipe, labels, lat=41.1172, lng=20.8016, seed=0, post=None):
        s = Scene(size[0], size[1], seed or zlib.crc32(name.encode()) % 10000)
        recipe(s)
        s.texture()
        img = s.img if post is None else post(s.img)
        items.append((name, img, time, lat, lng, s.faces, labels))
        return s

    def getting_ready(s):
        s.gradient((244, 232, 220), (226, 210, 196))
        s.d.rectangle([s.w * 0.55, s.h * 0.08, s.w * 0.92, s.h * 0.55], fill=(252, 248, 240))
        s.d.line([(s.w * 0.735, s.h * 0.08), (s.w * 0.735, s.h * 0.55)], fill=(220, 206, 190), width=8)
        s.person(s.w * 0.38, s.h * 1.02, s.h * 0.78, (250, 248, 244), skin=SKIN[0], hair=HAIR[1])

    def rings(s):
        s.gradient((236, 228, 222), (214, 204, 196))
        # Linen weave under the rings.
        for i in range(0, s.w, 9):
            s.d.line([(i, 0), (i, s.h)], fill=(224, 214, 204), width=2)
        for i in range(0, s.h, 9):
            s.d.line([(0, i), (s.w, i)], fill=(228, 219, 210), width=2)
        for i, c in enumerate([(212, 175, 95), (230, 205, 140)]):
            cx, cy, r = s.w * (0.44 + i * 0.13), s.h * 0.52, s.w * 0.1
            s.d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=int(s.w * 0.018))
        s.d.ellipse([s.w * 0.55, s.h * 0.4, s.w * 0.58, s.h * 0.43], fill=(250, 250, 255))

    def bouquet(s):
        s.gradient((240, 236, 228), (222, 214, 202))
        s.d.polygon([(s.w * 0.45, s.h * 0.55), (s.w * 0.55, s.h * 0.55), (s.w * 0.52, s.h * 0.95), (s.w * 0.48, s.h * 0.95)], fill=(96, 120, 80))
        s.flowers(s.w * 0.5, s.h * 0.42, s.w * 0.3, [(250, 250, 250), (242, 200, 200), (230, 170, 170), (250, 236, 220)])

    def bride_mother(s, shift=0.0):
        s.gradient((238, 226, 214), (218, 200, 186))
        s.person(s.w * (0.36 + shift), s.h * 1.02, s.h * 0.74, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * (0.68 + shift), s.h * 1.02, s.h * 0.66, (120, 90, 120), skin=SKIN[4], hair=HAIR[4])

    def groom(s):
        s.gradient((210, 214, 218), (180, 186, 192))
        s.person(s.w * 0.5, s.h * 1.02, s.h * 0.8, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])
        s.d.polygon([(s.w * 0.48, s.h * 0.42), (s.w * 0.52, s.h * 0.42), (s.w * 0.5, s.h * 0.5)], fill=(250, 250, 250))

    def church_lake(s):
        ohrid_lake(s)
        s.hills(int(s.h * 0.72), (120, 110, 90), amp=0.2, freq=0.6, phase=2.4)
        s.church(s.w * 0.62, s.h * 0.56, s.w * 0.14)

    def altar(s):
        s.gradient((230, 214, 190), (200, 176, 146))
        s.d.rectangle([s.w * 0.3, s.h * 0.1, s.w * 0.7, s.h * 0.65], fill=(214, 186, 140))
        s.d.ellipse([s.w * 0.43, s.h * 0.14, s.w * 0.57, s.h * 0.34], fill=(236, 214, 160))
        s.person(s.w * 0.4, s.h * 1.0, s.h * 0.62, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.6, s.h * 1.0, s.h * 0.66, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def guests(s):
        s.gradient((190, 214, 230), (230, 236, 236), 0, int(s.h * 0.5))
        s.hills(int(s.h * 0.5), (120, 150, 110), amp=0.05)
        s.sand(int(s.h * 0.75), (160, 180, 120), curve=0.01)
        for i in range(8):
            x = s.w * (0.1 + i * 0.113)
            s.person(x, s.h * (0.98 - (i % 2) * 0.06), s.h * (0.46 + (i % 3) * 0.03),
                     s.r.choice([(120, 140, 170), (170, 110, 110), (90, 90, 100), (200, 180, 150), (110, 130, 100)]))

    def exit_confetti(s):
        s.gradient((200, 222, 236), (238, 240, 240), 0, int(s.h * 0.6))
        s.building(s.w * 0.05, s.h * 0.2, s.w * 0.9, s.h * 0.5, (214, 190, 160), (170, 130, 100), windows=True, door=True)
        s.sand(int(s.h * 0.7), (180, 170, 150), curve=0.0)
        s.person(s.w * 0.42, s.h * 1.0, s.h * 0.58, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.58, s.h * 1.0, s.h * 0.62, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])
        for _ in range(160):
            x, y = s.r.random() * s.w, s.r.random() * s.h * 0.7
            r = s.w * 0.004
            s.d.ellipse([x - r, y - r, x + r, y + r], fill=s.r.choice([(250, 250, 250), (240, 200, 200), (250, 230, 170)]))

    def lake_couple(s, dx=0.0):
        ohrid_lake(s, sunset=True)
        s.person(s.w * (0.4 + dx), s.h * 1.0, s.h * 0.62, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * (0.55 + dx), s.h * 1.0, s.h * 0.66, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def close_portrait(s):
        s.gradient((240, 206, 170), (230, 180, 150))
        s.person(s.w * 0.36, s.h * 1.05, s.h * 0.95, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.68, s.h * 1.05, s.h * 1.0, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def panorama(s):
        ohrid_lake(s)
        for i in range(9):
            x = s.w * (0.08 + i * 0.05)
            s.building(x, s.h * (0.46 - (i % 3) * 0.04), s.w * 0.045, s.h * 0.12, (236, 226, 210), (170, 90, 70), windows=False)
        s.church(s.w * 0.78, s.h * 0.52, s.w * 0.06)

    def pier(s):
        ohrid_lake(s, sunset=True)
        s.d.polygon([(s.w * 0.3, s.h), (s.w * 0.7, s.h), (s.w * 0.54, s.h * 0.58), (s.w * 0.46, s.h * 0.58)], fill=(120, 90, 70))
        s.person(s.w * 0.48, s.h * 0.72, s.h * 0.2, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.53, s.h * 0.72, s.h * 0.22, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def reception(s):
        s.gradient((40, 36, 60), (80, 60, 70))
        s.lights(int(s.h * 0.12))
        for i in range(4):
            x = s.w * (0.15 + i * 0.23)
            s.d.ellipse([x - s.w * 0.08, s.h * 0.62, x + s.w * 0.08, s.h * 0.78], fill=(245, 240, 232))
            s.flowers(x, s.h * 0.6, s.w * 0.03, [(250, 250, 250), (242, 200, 200)])

    def first_dance(s):
        s.gradient((50, 40, 70), (110, 80, 90))
        s.lights(int(s.h * 0.1))
        s.sun(s.w * 0.5, s.h * 0.3, s.w * 0.05, (255, 230, 180))
        s.person(s.w * 0.45, s.h * 1.0, s.h * 0.62, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.56, s.h * 1.0, s.h * 0.66, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def cake(s):
        s.gradient((236, 226, 220), (210, 196, 186))
        for i, (w, h) in enumerate([(0.6, 0.18), (0.45, 0.16), (0.3, 0.14)]):
            y = s.h * (0.84 - sum([0.18, 0.16, 0.14][:i + 1]))
            s.d.rectangle([s.w * (0.5 - w / 2), y, s.w * (0.5 + w / 2), y + s.h * h], fill=(252, 250, 246))
            s.d.line([(s.w * (0.5 - w / 2), y + s.h * h * 0.2), (s.w * (0.5 + w / 2), y + s.h * h * 0.2)], fill=(214, 186, 130), width=6)
        s.flowers(s.w * 0.5, s.h * 0.34, s.w * 0.07, [(242, 200, 200), (250, 250, 250)])

    def dancing(s):
        s.gradient((60, 40, 80), (120, 70, 90))
        s.lights(int(s.h * 0.08), (250, 190, 200))
        for i in range(5):
            s.person(s.w * (0.12 + i * 0.19), s.h * (1.0 - (i % 2) * 0.04), s.h * 0.55,
                     s.r.choice([(170, 110, 130), (90, 110, 150), (200, 170, 120), (60, 60, 70)]), smile=0.9)

    def toast(s):
        s.gradient((70, 56, 60), (130, 100, 90))
        for i in range(4):
            x = s.w * (0.3 + i * 0.13)
            s.d.polygon([(x - s.w * 0.04, s.h * 0.35), (x + s.w * 0.04, s.h * 0.35), (x + s.w * 0.02, s.h * 0.55), (x - s.w * 0.02, s.h * 0.55)], fill=(245, 225, 170))
            s.d.line([(x, s.h * 0.55), (x, s.h * 0.72)], fill=(230, 230, 230), width=6)

    def sparklers(s):
        s.gradient((20, 22, 40), (50, 40, 60))
        for _ in range(400):
            x, y = s.r.random() * s.w, s.r.random() * s.h * 0.6
            s.d.point((x, y), fill=(255, 230, 180))
        s.person(s.w * 0.44, s.h * 1.0, s.h * 0.58, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.57, s.h * 1.0, s.h * 0.62, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def bride_veil(s):
        ohrid_lake(s, sunset=True)
        s.person(s.w * 0.5, s.h * 1.02, s.h * 0.8, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)

    def old_town(s):
        s.gradient((170, 200, 226), (226, 234, 238), 0, int(s.h * 0.4))
        s.building(0, s.h * 0.2, s.w * 0.45, s.h * 0.8, (236, 226, 210), (120, 70, 50))
        s.building(s.w * 0.55, s.h * 0.28, s.w * 0.45, s.h * 0.72, (224, 210, 190), (120, 70, 50), door=True)
        s.d.polygon([(s.w * 0.45, s.h), (s.w * 0.55, s.h), (s.w * 0.52, s.h * 0.5), (s.w * 0.48, s.h * 0.5)], fill=(170, 160, 150))

    blur = lambda im: im.filter(ImageFilter.GaussianBlur(14))
    kaneo = dict(lat=41.1110, lng=20.7880)
    add("w01", P, "2026-08-15T09:40:00", getting_ready, [("bride", 0.82), ("gown", 0.7)])
    add("w02", S, "2026-08-15T09:52:00", rings, [("jewelry", 0.9), ("wedding", 0.64)])
    add("w03", P, "2026-08-15T10:05:00", bouquet, [("bouquet", 0.93), ("flower", 0.95)])
    add("w04", P, "2026-08-15T10:20:00", lambda s: bride_mother(s), [("bride", 0.8), ("veil", 0.74)], seed=41)
    add("w05", P, "2026-08-15T10:20:02", lambda s: bride_mother(s, 0.012), [("bride", 0.8), ("veil", 0.72)], seed=41)
    add("w06", P, "2026-08-15T11:00:00", groom, [("suit", 0.91)])
    add("w24", P, "2026-08-15T13:00:00", old_town, [("building", 0.88), ("street", 0.8)])
    add("w07", L, "2026-08-15T14:30:00", church_lake, [("ceremony", 0.62), ("building", 0.9), ("lake", 0.86), ("sky", 0.8)], **kaneo)
    add("w08", L, "2026-08-15T14:45:00", altar, [("wedding", 0.88), ("ceremony", 0.84), ("gown", 0.8)], **kaneo)
    add("w09", L, "2026-08-15T15:05:00", guests, [("crowd", 0.84), ("suit", 0.62)], **kaneo)
    add("w10", L, "2026-08-15T15:20:00", exit_confetti, [("wedding", 0.86), ("gown", 0.7)], **kaneo)
    add("w23", P, "2026-08-15T16:50:00", bride_veil, [("bride", 0.9), ("veil", 0.88), ("lake", 0.7)])
    add("w11", L, "2026-08-15T17:10:00", lambda s: lake_couple(s), [("wedding", 0.9), ("lake", 0.84), ("sky", 0.82)], seed=77)
    add("w12", L, "2026-08-15T17:12:00", lambda s: lake_couple(s, 0.006), [("wedding", 0.9), ("lake", 0.84), ("sky", 0.8)], seed=77)
    add("w13", P, "2026-08-15T17:30:00", close_portrait, [("bride", 0.86), ("veil", 0.8)])
    add("w14", (4200, 1750), "2026-08-15T17:45:00", panorama, [("lake", 0.93), ("sky", 0.9), ("building", 0.66)])
    add("w15", L, "2026-08-15T18:10:00", pier, [("lake", 0.9), ("sky", 0.84), ("wedding", 0.6)])
    add("w16", L, "2026-08-15T18:20:00", lambda s: lake_couple(s, 0.1), [("lake", 0.8)], seed=90, post=blur)
    add("w17", L, "2026-08-15T19:30:00", reception, [("party", 0.82), ("table", 0.8)])
    add("w18", L, "2026-08-15T20:00:00", first_dance, [("dance", 0.84), ("gown", 0.76), ("wedding", 0.7)])
    add("w19", P, "2026-08-15T20:30:00", cake, [("cake", 0.95), ("wedding", 0.8)])
    add("w20", L, "2026-08-15T21:00:00", dancing, [("dance", 0.9), ("party", 0.86)])
    add("w21", S, "2026-08-15T21:30:00", toast, [("drink", 0.84), ("party", 0.7)])
    add("w22", L, "2026-08-15T22:15:00", sparklers, [("wedding", 0.7), ("night", 0.84)])

    def window_view(s):
        s.gradient((236, 226, 214), (220, 206, 190))
        s.d.rectangle([s.w * 0.12, s.h * 0.1, s.w * 0.88, s.h * 0.78], fill=(160, 150, 140))
        inner = Scene(int(s.w * 0.72), int(s.h * 0.64), 5)
        ohrid_lake(inner)
        s.img.paste(inner.img, (int(s.w * 0.14), int(s.h * 0.12)))
        s.d = ImageDraw.Draw(s.img)
        s.d.line([(s.w * 0.5, s.h * 0.12), (s.w * 0.5, s.h * 0.76)], fill=(236, 226, 214), width=12)

    def group(s, n, outfits, bg=((238, 226, 214), (218, 200, 186)), height=0.62):
        s.gradient(*bg)
        for i in range(n):
            x = s.w * (0.5 + (i - (n - 1) / 2) * min(0.2, 0.86 / n))
            s.person(x, s.h * (1.0 - (i % 2) * 0.03), s.h * (height - (i % 2) * 0.04), outfits[i % len(outfits)])

    def shoes(s):
        s.gradient((230, 222, 214), (206, 196, 186))
        # Wooden floorboards.
        for i in range(0, s.h, int(s.h * 0.06)):
            s.d.line([(0, i), (s.w, i)], fill=(196, 180, 162), width=4)
            for j in range(3):
                x = s.r.random() * s.w
                s.d.line([(x, i), (x, i + s.h * 0.06)], fill=(196, 180, 162), width=3)
        for i in range(2):
            x = s.w * (0.35 + i * 0.22)
            s.d.polygon([(x, s.h * 0.6), (x + s.w * 0.18, s.h * 0.62), (x + s.w * 0.2, s.h * 0.7), (x - s.w * 0.02, s.h * 0.7)], fill=(236, 210, 190))
            s.d.line([(x + s.w * 0.16, s.h * 0.62), (x + s.w * 0.17, s.h * 0.8)], fill=(200, 170, 150), width=10)

    def rings_close(s):
        s.gradient((230, 206, 180), (210, 180, 150))
        s.d.ellipse([s.w * 0.2, s.h * 0.45, s.w * 0.8, s.h * 0.75], fill=(233, 196, 170))
        s.d.ellipse([s.w * 0.42, s.h * 0.5, s.w * 0.58, s.h * 0.6], outline=(212, 175, 95), width=18)
        s.person(s.w * 0.3, s.h * 0.42, s.h * 0.34, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.72, s.h * 0.42, s.h * 0.36, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def boat_ride(s):
        ohrid_lake(s)
        s.boat(s.w * 0.5, s.h * 0.72, s.w * 0.18, hull=(150, 110, 70), sail=(250, 248, 244))
        s.person(s.w * 0.46, s.h * 0.73, s.h * 0.14, (250, 248, 244), skin=SKIN[0], hair=HAIR[1])
        s.person(s.w * 0.54, s.h * 0.73, s.h * 0.15, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def old_town_walk(s):
        old_town(s)
        s.person(s.w * 0.46, s.h * 0.95, s.h * 0.34, (250, 248, 244), skin=SKIN[0], hair=HAIR[1], veil=True)
        s.person(s.w * 0.56, s.h * 0.95, s.h * 0.36, (40, 44, 58), skin=SKIN[1], hair=HAIR[0])

    def lake_silhouette(s):
        ohrid_lake(s, sunset=True)
        s.hills(int(s.h * 0.62), (90, 70, 80), amp=0.1, freq=0.8, phase=1.1)

    def candles(s):
        s.gradient((50, 40, 50), (90, 70, 70))
        for i in range(5):
            x = s.w * (0.18 + i * 0.16)
            h = s.h * (0.2 + (i % 2) * 0.1)
            s.d.rectangle([x - s.w * 0.03, s.h * 0.8 - h, x + s.w * 0.03, s.h * 0.8], fill=(245, 236, 220))
            s.sun(x, s.h * 0.8 - h - s.h * 0.03, s.w * 0.012, (255, 214, 140))

    def speech(s):
        s.gradient((60, 44, 60), (110, 80, 80))
        s.lights(int(s.h * 0.1))
        s.person(s.w * 0.5, s.h * 1.02, s.h * 0.7, (90, 100, 120), skin=SKIN[2], hair=HAIR[3])

    def night_lake(s):
        s.gradient((20, 24, 50), (40, 50, 80), 0, int(s.h * 0.55))
        s.hills(int(s.h * 0.55), (30, 30, 40), amp=0.1, freq=1.2)
        s.sea(int(s.h * 0.55), (40, 50, 80), (20, 24, 40), waves=(255, 214, 140))
        for i in range(30):
            x = s.w * s.r.random()
            s.d.ellipse([x, s.h * 0.5, x + 6, s.h * 0.5 + 6], fill=(255, 214, 140))

    wed_outfits = [(170, 110, 130), (90, 110, 150), (200, 170, 120), (60, 60, 70), (120, 140, 110)]
    add("w25", L, "2026-08-15T09:30:00", window_view, [("lake", 0.84), ("window", 0.8)])
    add("w26", L, "2026-08-15T10:40:00", lambda s: group(s, 3, [(242, 200, 200), (250, 248, 244), (242, 200, 200)]), [("bride", 0.7), ("dress", 0.8)])
    add("w27", L, "2026-08-15T11:15:00", lambda s: group(s, 3, [(40, 44, 58), (60, 64, 80)], bg=((210, 214, 218), (180, 186, 192))), [("suit", 0.9)])
    add("w28", S, "2026-08-15T11:40:00", shoes, [("shoe", 0.9), ("wedding", 0.62)])
    add("w29", L, "2026-08-15T14:10:00", lambda s: group(s, 4, wed_outfits, bg=((200, 222, 236), (236, 238, 236)), height=0.5), [("crowd", 0.8)], **kaneo)
    add("w30", P, "2026-08-15T14:50:00", rings_close, [("wedding", 0.9), ("ceremony", 0.8), ("jewelry", 0.7)], **kaneo)
    add("w32", L, "2026-08-15T15:40:00", lambda s: group(s, 10, wed_outfits, height=0.42), [("crowd", 0.9), ("wedding", 0.66)], **kaneo)
    add("w33", L, "2026-08-15T16:30:00", boat_ride, [("lake", 0.9), ("boat", 0.84)])
    add("w34", P, "2026-08-15T17:20:00", old_town_walk, [("building", 0.8), ("wedding", 0.7)])
    add("w35", L, "2026-08-15T17:55:00", lake_silhouette, [("lake", 0.9), ("sky", 0.92)])
    add("w36", S, "2026-08-15T19:10:00", candles, [("candle", 0.9), ("table", 0.8)])
    add("w37", L, "2026-08-15T20:15:00", speech, [("party", 0.8)])
    add("w38", L, "2026-08-15T21:10:00", lambda s: group(s, 2, [(110, 80, 120), (60, 60, 70)], bg=((60, 40, 80), (120, 70, 90))), [("dance", 0.88)])
    add("w39", L, "2026-08-15T22:00:00", night_lake, [("lake", 0.8), ("night", 0.9)])
    add("w40", P, "2026-08-15T22:40:00", first_dance, [("dance", 0.86), ("gown", 0.7)], seed=404)
    return items


def zanzibar_sky(s, sunset=False):
    if sunset:
        s.gradient((252, 180, 120), (250, 222, 180), 0, int(s.h * 0.6))
    else:
        s.gradient((110, 190, 226), (210, 238, 244), 0, int(s.h * 0.6))


def travel_set():
    L, P, S = (3000, 2000), (2000, 3000), (2400, 2400)
    items = []
    places = {
        "stone": (-6.1622, 39.1921),
        "nungwi": (-5.7264, 39.2988),
        "jozani": (-6.2656, 39.4169),
    }

    def add(name, size, time, place, recipe, labels, seed=0, post=None):
        s = Scene(size[0], size[1], seed or zlib.crc32(name.encode()) % 10000)
        recipe(s)
        s.texture()
        img = s.img if post is None else post(s.img)
        rnd = random.Random(name)
        lat, lng = places[place]
        items.append((name, img, time, lat + rnd.uniform(-0.004, 0.004), lng + rnd.uniform(-0.004, 0.004), s.faces, labels))

    def alley(s):
        s.gradient((150, 200, 230), (220, 236, 240), 0, int(s.h * 0.3))
        s.d.rectangle([0, s.h * 0.3, s.w, s.h], fill=(200, 184, 160))
        s.building(0, s.h * 0.05, s.w * 0.36, s.h * 0.95, (226, 206, 176), (160, 110, 70))
        s.building(s.w * 0.64, s.h * 0.1, s.w * 0.36, s.h * 0.9, (214, 192, 162), (140, 90, 60), door=True)
        s.d.polygon([(s.w * 0.36, s.h), (s.w * 0.64, s.h), (s.w * 0.56, s.h * 0.4), (s.w * 0.44, s.h * 0.4)], fill=(180, 160, 140))

    def spices(s):
        s.gradient((120, 80, 50), (90, 60, 40))
        cols = [(214, 120, 40), (190, 50, 40), (230, 190, 60), (120, 90, 50), (160, 120, 60), (90, 110, 50)]
        for i in range(12):
            x = s.w * (0.08 + (i % 4) * 0.23)
            y = s.h * (0.2 + (i // 4) * 0.27)
            s.d.ellipse([x, y, x + s.w * 0.18, y + s.h * 0.18], fill=(200, 180, 150))
            s.d.ellipse([x + s.w * 0.02, y + s.h * 0.02, x + s.w * 0.16, y + s.h * 0.14], fill=cols[i % len(cols)])

    def forodhani(s):
        zanzibar_sky(s, sunset=True)
        s.sun(s.w * 0.3, s.h * 0.5, s.w * 0.035, (255, 240, 210))
        s.sea(int(s.h * 0.6), (230, 150, 110), (110, 90, 100))
        s.boat(s.w * 0.7, s.h * 0.66, s.w * 0.06, sail=(250, 236, 214))

    def rooftop(s, shift=0.0):
        zanzibar_sky(s)
        for i in range(7):
            x = s.w * (i * 0.15 - 0.03 + shift)
            h = s.h * (0.35 + (i % 3) * 0.08)
            s.building(x, s.h - h, s.w * 0.15, h, (230, 216, 196), (150, 110, 80))
        s.sea(int(s.h * 0.62), (70, 170, 190), (40, 120, 150))
        for i in range(7):
            x = s.w * (i * 0.15 - 0.03 + shift)
            h = s.h * (0.3 + (i % 3) * 0.06)
            s.building(x, s.h - h, s.w * 0.14, h, (236, 224, 206), (160, 110, 80))

    def selfie(s):
        zanzibar_sky(s)
        s.building(0, s.h * 0.3, s.w, s.h * 0.7, (226, 206, 176), (160, 110, 70), door=True)
        s.person(s.w * 0.35, s.h * 1.05, s.h * 0.85, (60, 120, 140), skin=SKIN[1], hair=HAIR[0])
        s.person(s.w * 0.68, s.h * 1.05, s.h * 0.8, (220, 160, 110), skin=SKIN[0], hair=HAIR[2])

    def harbour(s, dusk=False):
        zanzibar_sky(s, sunset=dusk)
        if dusk:
            s.sun(s.w * 0.2, s.h * 0.45, s.w * 0.03, (255, 240, 210))
        s.sea(int(s.h * 0.5), (70, 170, 190), (40, 120, 150))
        for i in range(3):
            s.boat(s.w * (0.25 + i * 0.25), s.h * (0.62 + i * 0.05), s.w * (0.05 + i * 0.01))

    def forest(s):
        s.gradient((150, 190, 140), (70, 110, 70))
        for i in range(14):
            s.tree(s.w * s.r.random(), s.h * (0.7 + s.r.random() * 0.3), s.h * s.r.uniform(0.5, 0.9), (50 + i * 3, 110 + i * 4, 60))
        s.d.polygon([(s.w * 0.4, s.h), (s.w * 0.6, s.h), (s.w * 0.52, s.h * 0.55), (s.w * 0.48, s.h * 0.55)], fill=(150, 120, 80))

    def monkey(s):
        s.gradient((90, 130, 80), (50, 80, 50))
        s.d.line([(0, s.h * 0.6), (s.w, s.h * 0.5)], fill=(90, 70, 50), width=int(s.h * 0.05))
        cx, cy = s.w * 0.5, s.h * 0.42
        s.d.ellipse([cx - s.w * 0.12, cy - s.h * 0.04, cx + s.w * 0.12, cy + s.h * 0.14], fill=(160, 70, 40))
        s.d.ellipse([cx - s.w * 0.07, cy - s.h * 0.18, cx + s.w * 0.07, cy], fill=(60, 40, 30))
        s.d.ellipse([cx - s.w * 0.04, cy - s.h * 0.13, cx + s.w * 0.04, cy - s.h * 0.03], fill=(200, 170, 150))
        s.d.line([(cx + s.w * 0.1, cy + s.h * 0.1), (cx + s.w * 0.3, cy + s.h * 0.35)], fill=(160, 70, 40), width=int(s.w * 0.02))

    def mangrove(s):
        s.gradient((170, 210, 190), (120, 160, 130), 0, int(s.h * 0.55))
        s.sea(int(s.h * 0.55), (90, 120, 90), (60, 80, 60), waves=(180, 200, 170))
        for i in range(10):
            s.tree(s.w * (0.05 + i * 0.1), s.h * 0.6, s.h * 0.4, (60, 110, 60))
        s.d.rectangle([s.w * 0.1, s.h * 0.75, s.w * 0.9, s.h * 0.8], fill=(140, 110, 80))

    def hikers(s):
        forest(s)
        s.person(s.w * 0.42, s.h * 0.98, s.h * 0.5, (200, 120, 60), skin=SKIN[0], hair=HAIR[2])
        s.person(s.w * 0.58, s.h * 0.98, s.h * 0.54, (60, 100, 140), skin=SKIN[1], hair=HAIR[0])

    def beach(s, sunset=False):
        zanzibar_sky(s, sunset)
        if sunset:
            s.sun(s.w * 0.62, s.h * 0.48, s.w * 0.04, (255, 244, 220))
        s.sea(int(s.h * 0.52), (90, 210, 210) if not sunset else (230, 160, 120), (40, 170, 190) if not sunset else (130, 100, 110))
        s.sand(int(s.h * 0.78), (242, 228, 196) if not sunset else (220, 180, 150))

    def palms_beach(s):
        beach(s)
        for i in range(3):
            s.palm(s.w * (0.12 + i * 0.1), s.h * 0.85, s.h * (0.55 + i * 0.05))

    def dhow(s):
        beach(s, sunset=True)
        s.boat(s.w * 0.45, s.h * 0.6, s.w * 0.12, hull=(60, 40, 40), sail=(70, 50, 50))

    def couple_beach(s, shift=0.0):
        beach(s)
        s.person(s.w * (0.42 + shift), s.h * 1.0, s.h * 0.55, (240, 240, 236), skin=SKIN[0], hair=HAIR[2])
        s.person(s.w * (0.57 + shift), s.h * 1.0, s.h * 0.58, (60, 120, 140), skin=SKIN[1], hair=HAIR[0])

    def palms_portrait(s):
        zanzibar_sky(s)
        s.sea(int(s.h * 0.6), (90, 210, 210), (40, 170, 190))
        s.sand(int(s.h * 0.82), (242, 228, 196))
        for i in range(2):
            s.palm(s.w * (0.35 + i * 0.35), s.h * 0.9, s.h * (0.7 - i * 0.12))

    def underwater(s):
        s.gradient((80, 200, 210), (20, 90, 130))
        for _ in range(30):
            x, y, r = s.r.random() * s.w, s.r.random() * s.h, s.w * s.r.uniform(0.01, 0.04)
            s.d.ellipse([x - r, y - r * 0.5, x + r, y + r * 0.5], fill=s.r.choice([(250, 190, 80), (240, 120, 80), (250, 250, 250)]))
        s.sand(int(s.h * 0.85), (220, 210, 170))

    def silhouette(s):
        beach(s, sunset=True)
        for i, x in enumerate((0.45, 0.55)):
            s.person(s.w * x, s.h * 0.98, s.h * 0.5, (40, 30, 30), skin=(60, 40, 40), hair=(30, 20, 20), eyes=0.0)
        s.faces.clear()  # backlit: no detectable faces

    def beach_bar(s):
        beach(s, sunset=True)
        s.d.polygon([(s.w * 0.05, s.h * 0.45), (s.w * 0.45, s.h * 0.45), (s.w * 0.25, s.h * 0.25)], fill=(170, 130, 80))
        s.d.rectangle([s.w * 0.08, s.h * 0.45, s.w * 0.42, s.h * 0.78], fill=(150, 110, 70))

    def panorama_beach(s):
        beach(s)
        for i in range(5):
            s.palm(s.w * (0.04 + i * 0.05), s.h * 0.9, s.h * (0.6 + (i % 2) * 0.08))
        s.boat(s.w * 0.7, s.h * 0.56, s.w * 0.03)

    def sand_ripples(s):
        s.gradient((244, 230, 200), (226, 206, 170))
        for i in range(30):
            y = s.h * i / 30
            s.d.arc([-s.w * 0.2, y, s.w * 1.2, y + s.h * 0.2], 190, 350, fill=(210, 188, 150), width=6)

    def footprints(s):
        sand_ripples(s)
        for i in range(10):
            x = s.w * (0.4 + (i % 2) * 0.1)
            y = s.h * (0.95 - i * 0.09)
            s.d.ellipse([x, y, x + s.w * 0.05, y + s.h * 0.06], fill=(190, 166, 130))

    blur = lambda im: im.filter(ImageFilter.GaussianBlur(16))
    add("t01", P, "2026-07-03T10:15:00", "stone", lambda s: s.carved_door(), [("door", 0.92), ("building", 0.9)])
    add("t02", P, "2026-07-03T11:02:00", "stone", alley, [("building", 0.9), ("street", 0.86)])
    add("t03", L, "2026-07-03T12:30:00", "stone", spices, [("market", 0.88), ("food", 0.8)])
    add("t06", P, "2026-07-04T09:40:00", "stone", selfie, [("building", 0.7)])
    add("t05", L, "2026-07-04T16:20:00", "stone", lambda s: rooftop(s), [("building", 0.92), ("sky", 0.86), ("sea", 0.8)], seed=55)
    add("t09", L, "2026-07-04T16:21:00", "stone", lambda s: rooftop(s, 0.004), [("building", 0.92), ("sky", 0.86)], seed=55)
    add("t04", L, "2026-07-04T18:30:00", "stone", forodhani, [("sea", 0.9), ("sky", 0.9), ("boat", 0.8)])
    add("t08", L, "2026-07-05T08:45:00", "stone", harbour, [("boat", 0.92), ("sea", 0.88)])
    add("t14", L, "2026-07-06T11:30:00", "nungwi", lambda s: beach(s), [("beach", 0.95), ("sea", 0.94), ("sky", 0.92)])
    add("t18", P, "2026-07-06T13:10:00", "nungwi", palms_portrait, [("beach", 0.8), ("tree", 0.84)])
    add("t17", L, "2026-07-06T16:00:00", "nungwi", lambda s: couple_beach(s), [("beach", 0.9), ("sea", 0.86)], seed=71)
    add("t23", L, "2026-07-06T16:00:01", "nungwi", lambda s: couple_beach(s, 0.01), [("beach", 0.9)], seed=71)
    add("t15", L, "2026-07-06T18:40:00", "nungwi", dhow, [("boat", 0.9), ("sea", 0.88), ("sky", 0.9)])
    add("t19", S, "2026-07-07T10:30:00", "nungwi", underwater, [("water", 0.9), ("fish", 0.82)])
    add("t16", (4200, 1750), "2026-07-07T12:00:00", "nungwi", panorama_beach, [("beach", 0.94), ("sea", 0.92), ("sky", 0.9)])
    add("t22", L, "2026-07-07T12:05:00", "nungwi", lambda s: beach(s), [("sea", 0.8)], seed=93, post=blur)
    add("t20", L, "2026-07-08T18:50:00", "nungwi", silhouette, [("beach", 0.84), ("sky", 0.9)])
    add("t21", L, "2026-07-09T19:30:00", "nungwi", beach_bar, [("beach", 0.8), ("drink", 0.6)])
    add("t24", L, "2026-07-10T09:00:00", "nungwi", palms_beach, [("beach", 0.92), ("tree", 0.86), ("sea", 0.9)])
    add("t25", S, "2026-07-10T09:30:00", "nungwi", sand_ripples, [("sand", 0.9), ("beach", 0.8)])
    add("t10", P, "2026-07-11T10:00:00", "jozani", forest, [("forest", 0.94), ("tree", 0.92)])
    add("t11", L, "2026-07-11T10:40:00", "jozani", monkey, [("animal", 0.9), ("monkey", 0.86)])
    add("t13", L, "2026-07-11T11:20:00", "jozani", hikers, [("forest", 0.9), ("tree", 0.84)])
    add("t12", L, "2026-07-12T09:15:00", "jozani", mangrove, [("tree", 0.84), ("water", 0.8)])
    add("t26", P, "2026-07-12T12:00:00", "jozani", footprints, [("sand", 0.9), ("beach", 0.7)])

    def coffee(s):
        zanzibar_sky(s)
        s.building(0, s.h * 0.55, s.w, s.h * 0.45, (230, 216, 196), (150, 110, 80), windows=False)
        s.d.ellipse([s.w * 0.35, s.h * 0.62, s.w * 0.65, s.h * 0.72], fill=(250, 248, 244))
        s.d.ellipse([s.w * 0.4, s.h * 0.6, s.w * 0.6, s.h * 0.67], fill=(110, 70, 40))

    def night_market(s):
        s.gradient((30, 30, 60), (70, 50, 70))
        s.lights(int(s.h * 0.15))
        for i in range(5):
            x = s.w * (0.05 + i * 0.19)
            s.d.rectangle([x, s.h * 0.55, x + s.w * 0.16, s.h * 0.75], fill=(150, 100, 60))
            for j in range(4):
                s.sun(x + s.w * (0.03 + j * 0.035), s.h * 0.53, s.w * 0.012, (240, 190, 90), glow=False)

    def fort(s):
        zanzibar_sky(s)
        s.sand(int(s.h * 0.55), (226, 210, 180), curve=0.0)
        s.d.rectangle([s.w * 0.1, s.h * 0.35, s.w * 0.9, s.h], fill=(190, 150, 110))
        for i in range(10):
            x = s.w * (0.1 + i * 0.08)
            s.d.rectangle([x, s.h * 0.3, x + s.w * 0.04, s.h * 0.36], fill=(190, 150, 110))
        s.d.rectangle([s.w * 0.44, s.h * 0.6, s.w * 0.56, s.h], fill=(90, 60, 40))

    def lighthouse(s):
        beach(s, sunset=True)
        s.d.polygon([(s.w * 0.72, s.h * 0.7), (s.w * 0.8, s.h * 0.7), (s.w * 0.785, s.h * 0.25), (s.w * 0.735, s.h * 0.25)], fill=(250, 248, 244))
        s.d.rectangle([s.w * 0.73, s.h * 0.2, s.w * 0.79, s.h * 0.25], fill=(190, 60, 50))

    def football(s):
        beach(s)
        for i in range(4):
            s.person(s.w * (0.2 + i * 0.2), s.h * (0.95 - (i % 2) * 0.05), s.h * 0.38, s.r.choice([(200, 80, 60), (60, 120, 180), (240, 200, 80)]), skin=SKIN[3], hair=HAIR[3])
        s.d.ellipse([s.w * 0.5, s.h * 0.85, s.w * 0.53, s.h * 0.89], fill=(250, 250, 250))

    def hammock(s):
        palms_beach(s)
        s.d.arc([s.w * 0.12, s.h * 0.5, s.w * 0.32, s.h * 0.7], 0, 180, fill=(220, 120, 80), width=24)

    def low_tide(s):
        beach(s)
        s.sand(int(s.h * 0.6), (230, 214, 180))
        for i in range(4):
            s.boat(s.w * (0.2 + i * 0.2), s.h * (0.75 + (i % 2) * 0.06), s.w * 0.05)

    def seafood(s):
        s.gradient((60, 44, 40), (110, 80, 60))
        s.d.ellipse([s.w * 0.15, s.h * 0.3, s.w * 0.85, s.h * 0.8], fill=(245, 240, 232))
        for i in range(6):
            a = i / 6 * math.tau
            x, y = s.w * 0.5 + math.cos(a) * s.w * 0.2, s.h * 0.55 + math.sin(a) * s.h * 0.14
            s.d.ellipse([x - 50, y - 30, x + 50, y + 30], fill=(230, 120, 80))

    def snorkel_boat(s):
        beach(s)
        s.boat(s.w * 0.5, s.h * 0.62, s.w * 0.14, hull=(40, 110, 150))
        s.person(s.w * 0.47, s.h * 0.63, s.h * 0.12, (240, 200, 80), skin=SKIN[0], hair=HAIR[2])
        s.person(s.w * 0.53, s.h * 0.63, s.h * 0.13, (60, 120, 140), skin=SKIN[1], hair=HAIR[0])

    def butterfly(s):
        s.gradient((120, 160, 100), (70, 110, 70))
        s.flowers(s.w * 0.5, s.h * 0.6, s.w * 0.3, [(240, 120, 150), (250, 200, 80), (250, 250, 250)])
        s.d.polygon([(s.w * 0.5, s.h * 0.3), (s.w * 0.4, s.h * 0.22), (s.w * 0.42, s.h * 0.36)], fill=(240, 150, 40))
        s.d.polygon([(s.w * 0.5, s.h * 0.3), (s.w * 0.6, s.h * 0.22), (s.w * 0.58, s.h * 0.36)], fill=(240, 150, 40))

    def spice_farm(s):
        forest(s)
        for i in range(6):
            x = s.w * (0.1 + i * 0.15)
            s.d.ellipse([x, s.h * 0.78, x + s.w * 0.1, s.h * 0.86], fill=(200, 130, 60))

    def plane_window(s):
        s.gradient((200, 200, 205), (170, 170, 178))
        s.d.rounded_rectangle([s.w * 0.25, s.h * 0.15, s.w * 0.75, s.h * 0.85], radius=int(s.w * 0.2), fill=(90, 190, 220))
        inner = Scene(int(s.w * 0.4), int(s.h * 0.55), 9)
        inner.gradient((140, 200, 230), (220, 240, 246), 0, int(inner.h * 0.4))
        inner.sea(int(inner.h * 0.4), (60, 200, 210), (30, 150, 180))
        inner.sand(int(inner.h * 0.75), (242, 228, 196))
        s.img.paste(inner.img, (int(s.w * 0.3), int(s.h * 0.22)))
        s.d = ImageDraw.Draw(s.img)

    add("t27", S, "2026-07-04T08:30:00", "stone", coffee, [("drink", 0.8), ("building", 0.7)])
    add("t28", L, "2026-07-04T20:00:00", "stone", night_market, [("market", 0.9), ("food", 0.84), ("night", 0.8)])
    add("t30", L, "2026-07-05T11:00:00", "stone", fort, [("building", 0.92), ("sky", 0.8)])
    add("t29", L, "2026-07-05T18:00:00", "stone", lambda s: harbour(s, dusk=True), [("boat", 0.9), ("sea", 0.86), ("sky", 0.8)], seed=291)
    add("t33", P, "2026-07-06T13:40:00", "nungwi", hammock, [("beach", 0.9), ("tree", 0.8)])
    add("t31", L, "2026-07-07T17:00:00", "nungwi", lighthouse, [("building", 0.8), ("sea", 0.84), ("sky", 0.9)])
    add("t32", L, "2026-07-08T16:30:00", "nungwi", football, [("beach", 0.9), ("sport", 0.84)])
    add("t34", L, "2026-07-09T08:00:00", "nungwi", low_tide, [("boat", 0.9), ("beach", 0.9)])
    add("t35", P, "2026-07-09T18:30:00", "nungwi", couple_beach, [("beach", 0.9), ("sky", 0.8)], seed=353)
    add("t36", L, "2026-07-09T20:30:00", "nungwi", seafood, [("food", 0.94)])
    add("t37", L, "2026-07-10T10:00:00", "nungwi", snorkel_boat, [("boat", 0.9), ("sea", 0.9)])
    add("t38", P, "2026-07-11T11:40:00", "jozani", mangrove, [("tree", 0.84), ("water", 0.8)], seed=383)
    add("t39", S, "2026-07-11T12:10:00", "jozani", butterfly, [("flower", 0.9), ("animal", 0.7)])
    add("t40", L, "2026-07-12T10:00:00", "jozani", spice_farm, [("forest", 0.8), ("food", 0.6)])
    add("t41", P, "2026-07-12T17:00:00", "jozani", plane_window, [("window", 0.8), ("sea", 0.7)])
    return items


def write(set_name, items):
    out = APP / set_name
    out.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, img, time, lat, lng, faces, labels in items:
        path = out / f"{name}.jpg"
        img.save(path, "JPEG", quality=86, optimize=True, progressive=True)
        manifest.append({
            "id": name,
            "file": f"assets/samples/{set_name}/{name}.jpg",
            "width": img.width,
            "height": img.height,
            "takenAt": time,
            "lat": round(lat, 5),
            "lng": round(lng, 5),
            "faces": faces,
            "labels": [{"text": t, "confidence": c} for t, c in labels],
        })
    data = {"set": set_name, "photos": manifest}
    (out / "manifest.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    FIX.mkdir(parents=True, exist_ok=True)
    (FIX / f"sample_{set_name}.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    size = sum(p.stat().st_size for p in out.glob("*.jpg"))
    print(f"{set_name}: {len(items)} photos, {size / 1e6:.1f} MB")


if __name__ == "__main__":
    write("wedding", wedding_set())
    write("travel", travel_set())
