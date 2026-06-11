#!/usr/bin/env python3
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = ROOT / "assets" / "appicon"
MASTER_PNG = ASSET_DIR / "AppIcon-1024.png"
ICONSET_DIR = ASSET_DIR / "AppIcon.iconset"
ICNS_PATH = ASSET_DIR / "AppIcon.icns"


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def gradient_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()

    top = (23, 29, 41)
    bottom = (13, 16, 25)
    glow = (39, 196, 164)

    for y in range(size):
        for x in range(size):
            ty = y / (size - 1)
            tx = x / (size - 1)
            r = int(lerp(top[0], bottom[0], ty))
            g = int(lerp(top[1], bottom[1], ty))
            b = int(lerp(top[2], bottom[2], ty))

            dx = tx - 0.72
            dy = ty - 0.22
            dist = math.sqrt(dx * dx + dy * dy)
            boost = max(0.0, 1.0 - dist * 2.2)
            r = min(255, int(r + glow[0] * boost * 0.15))
            g = min(255, int(g + glow[1] * boost * 0.18))
            b = min(255, int(b + glow[2] * boost * 0.12))
            pixels[x, y] = (r, g, b, 255)

    return image


def build_master_icon() -> Image.Image:
    size = 1024
    image = gradient_background(size)

    # soft bloom
    bloom = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bloom_draw = ImageDraw.Draw(bloom)
    bloom_draw.ellipse((540, 90, 980, 530), fill=(48, 218, 179, 80))
    bloom_draw.ellipse((60, 500, 520, 980), fill=(55, 115, 255, 45))
    bloom = bloom.filter(ImageFilter.GaussianBlur(80))
    image.alpha_composite(bloom)

    draw = ImageDraw.Draw(image)

    # glass panel
    draw.rounded_rectangle((120, 150, 904, 874), radius=180, fill=(255, 255, 255, 26), outline=(255, 255, 255, 42), width=2)

    # symbol geometry
    accent_a = (59, 130, 246, 255)
    accent_b = (46, 204, 164, 255)
    accent_c = (240, 248, 255, 255)

    stroke = 54
    nodes = {
        "left": (268, 512),
        "top": (488, 318),
        "bottom": (488, 706),
        "right": (760, 512),
    }

    # connection strokes with shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    for start, end in (("left", "top"), ("left", "bottom"), ("top", "right"), ("bottom", "right")):
        sdraw.line((nodes[start], nodes[end]), fill=(0, 0, 0, 150), width=stroke + 18, joint="curve")
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    image.alpha_composite(shadow)

    draw.line((nodes["left"], nodes["top"]), fill=accent_a, width=stroke, joint="curve")
    draw.line((nodes["left"], nodes["bottom"]), fill=accent_a, width=stroke, joint="curve")
    draw.line((nodes["top"], nodes["right"]), fill=accent_b, width=stroke, joint="curve")
    draw.line((nodes["bottom"], nodes["right"]), fill=accent_b, width=stroke, joint="curve")

    # node rings
    for key, color in (("left", accent_c), ("top", accent_c), ("bottom", accent_c), ("right", accent_c)):
        x, y = nodes[key]
        draw.ellipse((x - 58, y - 58, x + 58, y + 58), fill=(11, 17, 26, 235))
        draw.ellipse((x - 46, y - 46, x + 46, y + 46), fill=color)

    # subtle merge arrow cue
    draw.rounded_rectangle((668, 458, 840, 566), radius=54, fill=(255, 255, 255, 24))
    draw.polygon([(718, 512), (780, 468), (780, 495), (824, 495), (824, 529), (780, 529), (780, 556)], fill=(255, 255, 255, 210))

    mask = rounded_rect_mask(size, 230)
    output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    output.paste(image, (0, 0), mask)
    return output


def ensure_iconset(master: Image.Image) -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, px in sizes:
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(ICONSET_DIR / filename)


def build_icns() -> None:
    subprocess.run(
        ["/usr/bin/iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_PATH)],
        check=True,
    )


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    master = build_master_icon()
    master.save(MASTER_PNG)
    ensure_iconset(master)
    build_icns()
    print(ICNS_PATH)


if __name__ == "__main__":
    main()
