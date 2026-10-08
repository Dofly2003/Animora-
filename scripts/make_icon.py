"""Draws the Animora icon: a keyframe diamond landing at the end of a bouncing-ball arc.

Run with `python scripts/make_icon.py` (needs Pillow). Writes assets/icon/icon-<size>.png.
Drawn at 1024 px and scaled down, so the small toolbar sizes stay smooth.
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
BACKGROUND = (36, 30, 52, 255)
ORANGE = (255, 170, 40, 255)
WHITE = (240, 236, 228)
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"


def arc_point(t: float) -> tuple[float, float]:
    """Parabola from bottom left over a peak to bottom right (t from 0 to 1)."""
    left, right, ground, peak = 165, 835, 790, 225
    x = left + (right - left) * t
    y = ground - (ground - peak) * 4 * t * (1 - t)
    return x, y


def draw() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    base = ImageDraw.Draw(image)
    base.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=230, fill=BACKGROUND)

    # Faint motion path.
    path = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    path_draw = ImageDraw.Draw(path)
    points = [arc_point(i / 100 * 0.95) for i in range(101)]
    path_draw.line(points, fill=(*WHITE, 70), width=30, joint="curve")
    image.alpha_composite(path)

    # Trail: the ball's earlier positions, growing and brightening towards the key.
    trail = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    trail_draw = ImageDraw.Draw(trail)
    for t, radius, alpha in ((0.12, 40, 90), (0.32, 52, 135), (0.52, 64, 185), (0.72, 76, 230)):
        x, y = arc_point(t)
        trail_draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*WHITE, alpha))
    image.alpha_composite(trail)

    # The keyframe: a diamond where the ball lands.
    x, y = arc_point(0.95)
    half = 150
    diamond = [(x, y - half), (x + half, y), (x, y + half), (x - half, y)]
    ImageDraw.Draw(image).polygon(diamond, fill=ORANGE)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw()
    for size in (1024, 512, 256, 64, 32, 16):
        target = master if size == SIZE else master.resize((size, size), Image.LANCZOS)
        target.save(OUT / f"icon-{size}.png")
    print(f"Wrote icons to {OUT}")


if __name__ == "__main__":
    main()
