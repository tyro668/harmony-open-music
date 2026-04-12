from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ENTRY_MEDIA_DIR = ROOT / "entry" / "src" / "main" / "resources" / "base" / "media"
APP_SCOPE_MEDIA_DIR = ROOT / "AppScope" / "resources" / "base" / "media"

MASTER_SIZE = 1024
START_ICON_SIZE = 512


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 6:
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return (r, g, b, alpha)
    if len(hex_color) == 8:
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        a = int(hex_color[6:8], 16)
        return (r, g, b, a)
    raise ValueError(f"Unsupported color: {hex_color}")


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(c1: tuple[int, int, int, int], c2: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
        int(lerp(c1[3], c2[3], t)),
    )


def diagonal_gradient(size: int, stops: Iterable[tuple[float, tuple[int, int, int, int]]]) -> Image.Image:
    stops = list(stops)
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            lower = stops[0]
            upper = stops[-1]
            for index in range(len(stops) - 1):
                start = stops[index]
                end = stops[index + 1]
                if start[0] <= t <= end[0]:
                    lower = start
                    upper = end
                    break
            span = max(upper[0] - lower[0], 1e-6)
            local_t = (t - lower[0]) / span
            pixels[x, y] = blend(lower[1], upper[1], local_t)
    return image


def radial_glow(size: int, center: tuple[float, float], radius: float, color: tuple[int, int, int, int]) -> Image.Image:
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx = int(size * center[0])
    cy = int(size * center[1])
    r = int(size * radius)
    glow_draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    return glow.filter(ImageFilter.GaussianBlur(radius=int(r * 0.42)))


def create_background(size: int) -> Image.Image:
    base = diagonal_gradient(
        size,
        [
            (0.0, rgba("#163E5C")),
            (0.54, rgba("#1A6C82")),
            (1.0, rgba("#0B1D2C")),
        ],
    )
    for layer in [
        radial_glow(size, (0.24, 0.20), 0.34, rgba("#86F1FF", 112)),
        radial_glow(size, (0.78, 0.78), 0.28, rgba("#092034", 134)),
    ]:
        base = Image.alpha_composite(base, layer)

    draw = ImageDraw.Draw(base)

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(
        (-120, 96, int(size * 0.78), int(size * 0.34)),
        radius=120,
        fill=rgba("#FFFFFF", 34),
    )
    highlight = highlight.rotate(-18, resample=Image.Resampling.BICUBIC, center=(size // 2, size // 2))
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=24))
    base = Image.alpha_composite(base, highlight)

    rim = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    rim_draw.arc((54, 54, size - 54, size - 54), start=214, end=336, fill=rgba("#D9F8FF", 28), width=4)
    rim = rim.filter(ImageFilter.GaussianBlur(radius=2))
    base = Image.alpha_composite(base, rim)

    return base


def ring_mask(size: int, outer_box: tuple[int, int, int, int], inner_box: tuple[int, int, int, int]) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse(outer_box, fill=255)
    draw.ellipse(inner_box, fill=0)
    return mask


def draw_note_glyph(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    stem = (548, 290, 610, 635)
    draw.rounded_rectangle(stem, radius=28, fill=rgba("#13293A", 255))

    beam = [(575, 305), (758, 248), (780, 315), (598, 370)]
    draw.polygon(beam, fill=rgba("#6DE7FF", 255))

    shadow_beam = [(570, 332), (748, 278), (760, 315), (585, 370)]
    draw.polygon(shadow_beam, fill=rgba("#1C4862", 162))

    draw.ellipse((428, 545, 610, 727), fill=rgba("#13293A", 255))
    draw.ellipse((616, 486, 760, 630), fill=rgba("#0F2131", 238))

    draw.ellipse((462, 577, 505, 620), fill=rgba("#7DEAFF", 236))
    draw.rounded_rectangle((628, 520, 687, 548), radius=14, fill=rgba("#B4F4FF", 210))


def create_foreground(size: int) -> Image.Image:
    foreground = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((202, 206, 822, 826), fill=rgba("#08131F", 64))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=22))
    foreground = Image.alpha_composite(foreground, shadow)

    outer_box = (224, 224, 800, 800)
    inner_box = (346, 346, 678, 678)
    ring_fill = Image.new("RGBA", (size, size), rgba("#F7FBFD", 248))
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring.paste(ring_fill, mask=ring_mask(size, outer_box, inner_box))
    foreground = Image.alpha_composite(foreground, ring)

    label = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    label_draw = ImageDraw.Draw(label)
    label_draw.ellipse((380, 380, 644, 644), fill=rgba("#153449", 244))
    label_draw.ellipse((402, 402, 622, 622), outline=rgba("#73E2F8", 86), width=4)
    label_draw.ellipse((494, 494, 530, 530), fill=rgba("#F7FBFD", 236))
    foreground = Image.alpha_composite(foreground, label)

    grooves = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grooves_draw = ImageDraw.Draw(grooves)
    for radius, alpha in [(226, 28), (250, 22)]:
        grooves_draw.arc((512 - radius, 512 - radius, 512 + radius, 512 + radius), start=206, end=336,
                         fill=rgba("#FFFFFF", alpha), width=3)
    foreground = Image.alpha_composite(foreground, grooves)

    glyph = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_note_glyph(glyph)
    foreground = Image.alpha_composite(foreground, glyph)

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.arc((266, 266, 758, 758), start=216, end=264, fill=rgba("#FFFFFF", 72), width=9)
    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=4))
    foreground = Image.alpha_composite(foreground, highlight)

    return foreground


def composite_icon(background: Image.Image, foreground: Image.Image, size: int) -> Image.Image:
    combined = Image.alpha_composite(background, foreground)
    if combined.size != (size, size):
        combined = combined.resize((size, size), Image.Resampling.LANCZOS)
    return combined


def save_png(image: Image.Image, path: Path) -> None:
    image.save(path, format="PNG", optimize=True)


def main() -> None:
    background = create_background(MASTER_SIZE)
    foreground = create_foreground(MASTER_SIZE)
    start_icon = composite_icon(background, foreground, START_ICON_SIZE)

    save_png(background, ENTRY_MEDIA_DIR / "entry_icon_background.png")
    save_png(foreground, ENTRY_MEDIA_DIR / "entry_icon_foreground.png")
    save_png(start_icon, ENTRY_MEDIA_DIR / "startIcon_app.png")

    save_png(background, APP_SCOPE_MEDIA_DIR / "app_icon_background.png")
    save_png(foreground, APP_SCOPE_MEDIA_DIR / "app_icon_foreground.png")


if __name__ == "__main__":
    main()
