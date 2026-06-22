#!/usr/bin/env python3
"""Extract the eight Hesperus floor-reference tiles into game-ready PNGs."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


TILES = (
    ("01_dock_metal_floor_plate", (34, 134, 360, 460)),
    ("02_dock_metal_floor_plate_damaged", (386, 134, 712, 460)),
    ("03_bazaar_stone_paver", (737, 134, 1063, 460)),
    ("04_bazaar_stone_paver_dirty", (1087, 134, 1413, 460)),
    ("05_catwalk_grate", (33, 542, 359, 868)),
    ("06_catwalk_grate_glow_under", (385, 542, 711, 868)),
    ("07_service_concrete", (736, 542, 1062, 868)),
    ("08_service_concrete_with_stripe", (1087, 542, 1413, 868)),
)

SIZES = (256, 128, 64)


def reduce_to_palette(image: Image.Image) -> Image.Image:
    """Keep the reference's retro palette while avoiding indexed PNG imports."""
    rgb = image.convert("RGB")
    indexed = rgb.quantize(colors=192, method=Image.Quantize.MEDIANCUT)
    return indexed.convert("RGB")


def reconcile_edges(image: Image.Image) -> Image.Image:
    """Make opposite borders identical while preserving the tile interior."""
    result = image.copy()
    pixels = result.load()
    width, height = result.size
    blend_width = max(2, width // 24)

    for inset in range(blend_width):
        strength = 1.0 - inset / blend_width
        left_x = inset
        right_x = width - 1 - inset
        for y in range(height):
            left = pixels[left_x, y]
            right = pixels[right_x, y]
            average = tuple(round((a + b) / 2) for a, b in zip(left, right))
            pixels[left_x, y] = tuple(
                round(channel * strength + original * (1.0 - strength))
                for channel, original in zip(average, left)
            )
            pixels[right_x, y] = tuple(
                round(channel * strength + original * (1.0 - strength))
                for channel, original in zip(average, right)
            )

    for inset in range(blend_width):
        strength = 1.0 - inset / blend_width
        top_y = inset
        bottom_y = height - 1 - inset
        for x in range(width):
            top = pixels[x, top_y]
            bottom = pixels[x, bottom_y]
            average = tuple(round((a + b) / 2) for a, b in zip(top, bottom))
            pixels[x, top_y] = tuple(
                round(channel * strength + original * (1.0 - strength))
                for channel, original in zip(average, top)
            )
            pixels[x, bottom_y] = tuple(
                round(channel * strength + original * (1.0 - strength))
                for channel, original in zip(average, bottom)
            )

    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    args.output.mkdir(parents=True, exist_ok=True)

    generated: dict[int, list[tuple[str, Image.Image]]] = {
        size: [] for size in SIZES
    }

    for name, crop_box in TILES:
        crop = source.crop(crop_box)
        for size in SIZES:
            resized = crop.resize((size, size), Image.Resampling.LANCZOS)
            tile = reduce_to_palette(resized)
            size_dir = args.output / str(size)
            size_dir.mkdir(exist_ok=True)
            tile.save(size_dir / f"{name}_{size}.png", optimize=True)
            seamless_dir = args.output / "seamless" / str(size)
            seamless_dir.mkdir(parents=True, exist_ok=True)
            seamless = reduce_to_palette(reconcile_edges(tile))
            seamless.save(
                seamless_dir / f"{name}_{size}_seamless.png", optimize=True
            )
            generated[size].append((name, tile))

    sheet_tile_size = 256
    label_height = 34
    gutter = 12
    sheet = Image.new(
        "RGB",
        (
            gutter + 4 * (sheet_tile_size + gutter),
            gutter + 2 * (sheet_tile_size + label_height + gutter),
        ),
        "#101315",
    )
    draw = ImageDraw.Draw(sheet)
    for index, (name, tile) in enumerate(generated[256]):
        column = index % 4
        row = index // 4
        x = gutter + column * (sheet_tile_size + gutter)
        y = gutter + row * (sheet_tile_size + label_height + gutter)
        sheet.paste(tile, (x, y))
        draw.text((x, y + sheet_tile_size + 8), name, fill="#a9c985")

    sheet.save(args.output / "hesperus_floor_pack_contact_sheet.png", optimize=True)


if __name__ == "__main__":
    main()
