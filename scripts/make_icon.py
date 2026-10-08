"""Draws the Animora icon variants.

Run with `python scripts/make_icon.py [variant]` (needs Pillow). Variants:
  apex     an "A" made of two tapered strokes, a keyframe diamond at its peak
  swoosh   a tapered motion swoosh landing in a keyframe diamond
  speed    a keyframe diamond with three speed lines
Writes assets/icon/icon-<size>.png for the chosen variant (default: swoosh, the official icon) and
assets/icon/variants.png comparing all of them. Drawn at 2048 px and scaled down.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 2048
TOP = (52, 40, 86)  # background gradient, top
BOTTOM = (24, 20, 40)  # background gradient, bottom
WHITE = (246, 242, 234)
AMBER_TOP = (255, 200, 80)
AMBER_BOTTOM = (245, 130, 30)
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"


def gradient(top, bottom) -> Image.Image:
    strip = Image.new("RGBA", (1, SIZE))
    for y in range(SIZE):
        t = y / (SIZE - 1)
        strip.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return strip.resize((SIZE, SIZE))


def background() -> Image.Image:
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=460, fill=255)
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    image.paste(gradient(TOP, BOTTOM), (0, 0), mask)
    return image


def paint(image: Image.Image, shape: list):
    """Fills a polygon with the amber keyframe gradient."""
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    image.paste(gradient(AMBER_TOP, AMBER_BOTTOM), (0, 0), mask)


def diamond(cx: float, cy: float, half: float) -> list:
    return [(cx, cy - half), (cx + half, cy), (cx, cy + half), (cx - half, cy)]


def tapered(points: list, start_width: float, end_width: float) -> list:
    """Outline of a stroke along `points` whose width goes from start to end."""
    left, right = [], []
    for i, (x, y) in enumerate(points):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, len(points) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        w = (start_width + (end_width - start_width) * i / (len(points) - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def stroke(image: Image.Image, points: list, start_width: float, end_width: float, alpha=255):
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.polygon(tapered(points, start_width, end_width), fill=(*WHITE, alpha))
    r = end_width / 2
    x, y = points[-1]
    draw.ellipse((x - r, y - r, x + r, y + r), fill=(*WHITE, alpha))
    image.alpha_composite(layer)


def bezier(p0, p1, p2, steps=120) -> list:
    return [
        (
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1],
        )
        for t in (i / steps for i in range(steps + 1))
    ]


def apex() -> Image.Image:
    image = background()
    peak = (1024, 820)
    stroke(image, bezier((540, 1600), (782, 1210), peak), 190, 150)
    stroke(image, bezier((1508, 1600), (1266, 1210), peak), 190, 150, alpha=130)
    paint(image, diamond(peak[0], peak[1] - 60, 290))
    return image


def swoosh() -> Image.Image:
    image = background()
    stroke(image, bezier((360, 1580), (620, 520), (1150, 880)), 20, 170)
    paint(image, diamond(1370, 1060, 380))
    return image


def speed() -> Image.Image:
    image = background()
    for y, x0, width in ((820, 300, 70), (1024, 200, 90), (1228, 300, 70)):
        stroke(image, [(x0 + i * 6, y) for i in range(100)], width * 0.3, width, alpha=200)
    paint(image, diamond(1300, 1024, 460))
    return image


VARIANTS = {"apex": apex, "swoosh": swoosh, "speed": speed}


def main() -> None:
    choice = sys.argv[1] if len(sys.argv) > 1 else "swoosh"
    OUT.mkdir(parents=True, exist_ok=True)

    # Comparison sheet: each variant large, at 32 px and at 16 px (scaled up 2x).
    sheet = Image.new("RGBA", (300 * len(VARIANTS), 330), (60, 60, 60, 255))
    for index, (name, make) in enumerate(VARIANTS.items()):
        icon = make()
        x = index * 300 + 22
        sheet.alpha_composite(icon.resize((256, 256), Image.LANCZOS), (x, 10))
        small = icon.resize((32, 32), Image.LANCZOS).resize((64, 64), Image.NEAREST)
        tiny = icon.resize((16, 16), Image.LANCZOS).resize((32, 32), Image.NEAREST)
        sheet.alpha_composite(small, (x + 60, 266))
        sheet.alpha_composite(tiny, (x + 150, 282))
        if name == choice:
            for size in (1024, 512, 256, 64, 32, 16):
                icon.resize((size, size), Image.LANCZOS).save(OUT / f"icon-{size}.png")
    sheet.save(OUT / "variants.png")
    print(f"Wrote {choice} icons and variants.png to {OUT}")


if __name__ == "__main__":
    main()
