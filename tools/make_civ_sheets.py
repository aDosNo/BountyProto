#!/usr/bin/env python3
"""Build game-ready 8-way sprite strips from the civilian rat turnarounds.

The source images generated for this NPC are horizontal sheets with eight full
figures and two narrow partial seam artifacts. This exporter keeps the full
figures, drops the seam artifacts, keys the black background to alpha, and packs
the frames for directional_sprite_3d.gd:

    N, NE, E, SE, S, SW, W, NW

Usage:
    python3 tools/make_civ_sheets.py
    python3 tools/make_civ_sheets.py sand_source.png teal_source.png

Default sources:
    art/sprites/npc/source/civ_rat_sand_source.png
    art/sprites/npc/source/civ_rat_teal_source.png
"""
import sys, pathlib, colorsys
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "art" / "sprites" / "npc" / "source"
SOURCES = {
    "civ_rat_sand_sheet": pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE_DIR / "civ_rat_sand_source.png",
    "civ_rat_teal_sheet": pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else SOURCE_DIR / "civ_rat_teal_source.png",
}
OUT = ROOT / "art" / "sprites" / "npc"

# Source full-figure order is front, left quarter, left profile, left rear,
# back, right rear, right profile, right quarter. Reorder to N,NE,E,SE,S,SW,W,NW.
ORDER = [0, 7, 6, 5, 4, 3, 2, 1]
PAD = 4
MIN_FIGURE_WIDTH = 48
TUNIC_BAND = dict(h=0.47, s=0.55)   # approved teal remap target


def tunic_band_remap(img: Image.Image) -> Image.Image:
    """Per-material palette swap: olive-leaning saturated mid-value band -> teal,
    value preserved so every shading cluster survives."""
    w, h = img.size
    lum = img.convert("L")
    flat = img.copy()
    flat.paste((25, 25, 25), (0, 0), lum.point(lambda x: 255 if x < 40 else 0))
    q = flat.quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()[:64 * 3]
    entries = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]
    new = []
    for c in entries:
        hh, ss, vv = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
        if vv >= 0.13 and hh >= 0.1055 and ss >= 0.50 and 0.30 <= vv <= 0.65:
            r, g, b = colorsys.hsv_to_rgb(TUNIC_BAND["h"], TUNIC_BAND["s"], vv)
            new.extend((int(r * 255), int(g * 255), int(b * 255)))
        else:
            new.extend(c)
    q2 = q.copy()
    q2.putpalette(new + pal[len(new):])
    return q2.convert("RGB")


def key_background(img: Image.Image) -> Image.Image:
    """Flood-fill the contiguous dark background to transparent from the
    borders, leaving dark pixels INSIDE the figures (eyes, outlines) intact."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2),
             (w // 4, 0), (3 * w // 4, 0), (w // 4, h - 1), (3 * w // 4, h - 1),
             (w // 4, h // 2), (3 * w // 4, h // 2), (w // 2, h // 2)]
    for s in seeds:
        try:
            ImageDraw.floodfill(rgba, s, (0, 0, 0, 0), thresh=26)
        except Exception:
            pass
    return rgba


def figure_boxes(keyed: Image.Image) -> list[tuple[int, int, int, int]]:
    """Find full figures by column occupancy. Narrow partials are discarded."""
    w, h = keyed.size
    px = keyed.load()
    occupied = []
    for x in range(w):
        has_pixel = False
        for y in range(h):
            r, g, b, a = px[x, y]
            if a > 10 and max(r, g, b) > 32:
                has_pixel = True
                break
        occupied.append(has_pixel)

    runs = []
    start = None
    for x, active in enumerate(occupied + [False]):
        if active and start is None:
            start = x
        elif not active and start is not None:
            if x - start >= MIN_FIGURE_WIDTH:
                runs.append((start, x))
            start = None

    boxes = []
    for x0, x1 in runs:
        crop = keyed.crop((x0, 0, x1, h))
        box = crop.getbbox()
        if box:
            boxes.append((x0 + box[0], box[1], x0 + box[2], box[3]))
    if len(boxes) != 8:
        raise RuntimeError(f"expected 8 full figures, found {len(boxes)}: {boxes}")
    return boxes


def build_sheet(keyed: Image.Image, boxes: list[tuple[int, int, int, int]]) -> tuple[Image.Image, int]:
    fw = max(b[2] - b[0] for b in boxes)
    fh = max(b[3] - b[1] for b in boxes)
    CW, CH = fw + PAD * 2, fh + PAD * 2
    sheet = Image.new("RGBA", (CW * 8, CH), (0, 0, 0, 0))
    for col, idx in enumerate(ORDER):
        b = boxes[idx]
        fr = keyed.crop(b)
        x = col * CW + (CW - fr.width) // 2
        y = CH - PAD - fr.height
        sheet.paste(fr, (x, y), fr)
    return sheet, fh


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, src_path in SOURCES.items():
        if not src_path.exists():
            sys.exit(f"source sheet not found: {src_path}")
        keyed = key_background(Image.open(src_path).convert("RGBA"))
        boxes = figure_boxes(keyed)
        sheet, fh = build_sheet(keyed, boxes)
        dst = OUT / f"{name}.png"
        sheet.save(dst, optimize=True)
        print(f"wrote {dst}  {sheet.size}  figure={fh}px"
              f"  pixel_size_for_1.75m={1.75 / fh:.6f}")


if __name__ == "__main__":
    main()
