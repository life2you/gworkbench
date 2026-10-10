#!/usr/bin/env python3
# /// script
# dependencies = ["pillow"]
# ///
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
ASSET_DIR = ROOT / "assets" / "appicon"
MASTER_PNG = ASSET_DIR / "AppIcon-1024.png"
ICONSET_DIR = ASSET_DIR / "AppIcon.iconset"
ICNS_PATH = ASSET_DIR / "AppIcon.icns"


def make_squircle_mask(size: int, radius: int) -> Image.Image:
    """Create a pristine antialiased squircle mask using 2x supersampling."""
    scale = 2
    big_size = size * scale
    mask = Image.new("L", (big_size, big_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, big_size - 1, big_size - 1),
        radius=radius * scale,
        fill=255,
    )
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def draw_capsule_line(
    draw: ImageDraw.ImageDraw,
    p1: tuple[float, float],
    p2: tuple[float, float],
    width: float,
    fill: tuple[int, int, int, int],
) -> None:
    """Draw a smooth line segment with rounded capsule ends."""
    draw.line([p1, p2], fill=fill, width=int(width))
    r = width / 2.0
    draw.ellipse((p1[0] - r, p1[1] - r, p1[0] + r, p1[1] + r), fill=fill)
    draw.ellipse((p2[0] - r, p2[1] - r, p2[0] + r, p2[1] + r), fill=fill)


def render_base_card(canvas_size: int = 1024) -> Image.Image:
    """Render macOS HIG compliant squircle card with subtle ambient shadow."""
    image = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    card_x0, card_y0 = 96, 96
    card_x1, card_y1 = 928, 928
    card_w = card_x1 - card_x0
    card_h = card_y1 - card_y0
    card_radius = 186

    # 1. Natural ambient drop shadow
    shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        (card_x0, card_y0 + 24, card_x1, card_y1 + 24),
        radius=card_radius,
        fill=(15, 23, 42, 40),
    )
    sdraw.rounded_rectangle(
        (card_x0, card_y0 + 8, card_x1, card_y1 + 8),
        radius=card_radius,
        fill=(15, 23, 42, 35),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    image.alpha_composite(shadow)

    # 2. Main card background (Light, ultra clean minimal gradient)
    card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    cpixels = card.load()
    top_color = (255, 255, 255)
    bottom_color = (244, 246, 250)

    for y in range(card_h):
        t = y / (card_h - 1)
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        for x in range(card_w):
            cpixels[x, y] = (r, g, b, 255)

    card_mask = make_squircle_mask(card_w, card_radius)
    card_cut = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    card_cut.paste(card, (0, 0), card_mask)

    # Crisp card border
    cdraw = ImageDraw.Draw(card_cut)
    cdraw.rounded_rectangle(
        (0, 0, card_w - 1, card_h - 1),
        radius=card_radius,
        outline=(210, 218, 228, 210),
        width=2,
    )

    image.paste(card_cut, (card_x0, card_y0), card_cut)
    return image


def build_master_icon() -> Image.Image:
    """Build the 1024x1024 master icon using the C-2 two-tone minimal geometry."""
    base = render_base_card()

    scale = 2
    render_size = 1024 * scale
    canvas = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    cx, cy = 512 * scale, 512 * scale
    span_x = 230 * scale
    span_y = 180 * scale

    p_left = (cx - span_x, cy)
    p_top = (cx, cy - span_y)
    p_bottom = (cx, cy + span_y)
    p_right = (cx + span_x, cy)

    stroke_width = 46 * scale

    # Two-tone palette: Royal Blue (Branching/Worktrees) and Emerald (Merged/Ready)
    c_blue = (37, 99, 235, 255)   # #2563EB
    c_green = (16, 185, 129, 255)  # #10B981

    # 1. Subtle soft shadow under connecting tracks
    shadow_layer = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow_layer)
    s_fill = (15, 23, 42, 45)
    for p1, p2 in [(p_left, p_top), (p_left, p_bottom), (p_top, p_right), (p_bottom, p_right)]:
        sdraw.line(
            [p1, (p2[0], p2[1] + 6 * scale)],
            fill=s_fill,
            width=int(stroke_width + 8 * scale),
            joint="curve",
        )
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(12 * scale))
    canvas.alpha_composite(shadow_layer)

    # 2. Connecting lines: Left half is Blue (split), Right half is Emerald (merge)
    draw_capsule_line(draw, p_left, p_top, stroke_width, c_blue)
    draw_capsule_line(draw, p_left, p_bottom, stroke_width, c_blue)
    draw_capsule_line(draw, p_top, p_right, stroke_width, c_green)
    draw_capsule_line(draw, p_bottom, p_right, stroke_width, c_green)

    nodes = [
        (p_left, c_blue),
        (p_top, c_blue),
        (p_bottom, c_blue),
        (p_right, c_green),
    ]

    outer_r = 54 * scale
    inner_r = 28 * scale

    # 3. Node drop shadows
    n_shadow = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    ns_draw = ImageDraw.Draw(n_shadow)
    for pt, _ in nodes:
        x, y = pt
        ns_draw.ellipse(
            (x - outer_r, y - outer_r + 8 * scale, x + outer_r, y + outer_r + 8 * scale),
            fill=(15, 23, 42, 60),
        )
    n_shadow = n_shadow.filter(ImageFilter.GaussianBlur(8 * scale))
    canvas.alpha_composite(n_shadow)

    # 4. Node discs (outer color ring + inner crisp white center)
    for pt, col in nodes:
        x, y = pt
        draw.ellipse((x - outer_r, y - outer_r, x + outer_r, y + outer_r), fill=col)
        draw.ellipse(
            (x - inner_r, y - inner_r, x + inner_r, y + inner_r),
            fill=(255, 255, 255, 255),
        )

    scaled_art = canvas.resize((1024, 1024), Image.Resampling.LANCZOS)
    base.alpha_composite(scaled_art)
    return base


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
    print(f"Generated master PNG: {MASTER_PNG}")
    print(f"Generated ICNS: {ICNS_PATH}")


if __name__ == "__main__":
    main()
