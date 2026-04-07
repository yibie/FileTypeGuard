from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ICONSET = Path("FileTypeGuard/Resources/Assets.xcassets/AppIcon.appiconset")
ICONSET.mkdir(parents=True, exist_ok=True)

SPECS = [
    (16, "icon_16.png"),
    (32, "icon_16@2x.png"),
    (32, "icon_32.png"),
    (64, "icon_32@2x.png"),
    (128, "icon_128.png"),
    (256, "icon_128@2x.png"),
    (256, "icon_256.png"),
    (512, "icon_256@2x.png"),
    (512, "icon_512.png"),
    (1024, "icon_512@2x.png"),
]

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
base = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(base)

# Rounded base with layered gradients for a modern macOS-style silhouette.
margin = 66
radius = 228
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle((margin, margin, SIZE - margin, SIZE - margin), radius=radius, fill=255)

for y in range(SIZE):
    t = y / (SIZE - 1)
    if t < 0.42:
        top = (116, 189, 255)
        mid = (72, 115, 245)
        blend = t / 0.42
        color = tuple(int(top[i] * (1 - blend) + mid[i] * blend) for i in range(3))
    else:
        mid = (72, 115, 245)
        bottom = (79, 61, 214)
        blend = (t - 0.42) / 0.58
        color = tuple(int(mid[i] * (1 - blend) + bottom[i] * blend) for i in range(3))
    ImageDraw.Draw(base).line((0, y, SIZE, y), fill=color + (255,))

# Soft radial light.
light = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ld = ImageDraw.Draw(light)
ld.ellipse((120, 70, 920, 760), fill=(255, 255, 255, 84))
light = light.filter(ImageFilter.GaussianBlur(90))
base = Image.alpha_composite(base, light)

# Top highlight strip.
highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hd = ImageDraw.Draw(highlight)
hd.rounded_rectangle((128, 110, 896, 420), radius=180, fill=(255, 255, 255, 60))
highlight = highlight.filter(ImageFilter.GaussianBlur(70))
base = Image.alpha_composite(base, highlight)

# Apply mask and a subtle outer shadow.
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((margin + 8, margin + 24, SIZE - margin + 8, SIZE - margin + 24), radius=radius, fill=(8, 14, 44, 85))
shadow = shadow.filter(ImageFilter.GaussianBlur(40))
img = Image.alpha_composite(img, shadow)
img = Image.alpha_composite(img, Image.composite(base, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask))

# Inner border.
border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bd = ImageDraw.Draw(border)
bd.rounded_rectangle((margin, margin, SIZE - margin, SIZE - margin), radius=radius, outline=(255, 255, 255, 80), width=4)
img = Image.alpha_composite(img, border)

# Floating document card.
card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
cd = ImageDraw.Draw(card)
card_box = (240, 190, 710, 800)
fold = 118
card_shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
csd = ImageDraw.Draw(card_shadow)
csd.rounded_rectangle((card_box[0] + 12, card_box[1] + 28, card_box[2] + 12, card_box[3] + 28), radius=110, fill=(14, 22, 60, 70))
card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(30))
img = Image.alpha_composite(img, card_shadow)

cd.rounded_rectangle(card_box, radius=96, fill=(250, 252, 255, 255))
cd.polygon([(card_box[2] - fold, card_box[1]), (card_box[2], card_box[1]), (card_box[2], card_box[1] + fold)], fill=(219, 231, 255, 255))
cd.line((card_box[2] - fold, card_box[1], card_box[2] - fold, card_box[1] + fold), fill=(190, 205, 244, 255), width=6)
cd.line((card_box[2] - fold, card_box[1] + fold, card_box[2], card_box[1] + fold), fill=(190, 205, 244, 255), width=6)

# Document lines.
for y in (330, 408, 486):
    cd.rounded_rectangle((330, y, 610, y + 24), radius=12, fill=(198, 212, 240, 255))
cd.rounded_rectangle((330, 580, 530, 648), radius=20, fill=(95, 129, 240, 255))

# Small extension chips for file-type hint.
chip_colors = [(255, 191, 82, 255), (112, 215, 174, 255), (255, 129, 147, 255)]
for i, color in enumerate(chip_colors):
    x = 330 + i * 88
    cd.rounded_rectangle((x, 695, x + 62, 735), radius=16, fill=color)

img = Image.alpha_composite(img, card)

# Shield badge.
shield = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shd = ImageDraw.Draw(shield)
shield_shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ssd = ImageDraw.Draw(shield_shadow)
path = [(670, 405), (835, 405), (875, 465), (860, 642), (752, 770), (645, 642), (630, 465)]
ssd.polygon([(x + 10, y + 24) for x, y in path], fill=(7, 14, 40, 95))
shield_shadow = shield_shadow.filter(ImageFilter.GaussianBlur(28))
img = Image.alpha_composite(img, shield_shadow)

# Shield gradient.
shield_fill = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
mask2 = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask2).polygon(path, fill=255)
for y in range(360, 790):
    t = (y - 360) / 430
    top = (116, 208, 255)
    bottom = (48, 120, 246)
    color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    ImageDraw.Draw(shield_fill).line((600, y, 910, y), fill=color + (255,))
shine = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(shine).ellipse((620, 390, 860, 590), fill=(255, 255, 255, 60))
shine = shine.filter(ImageFilter.GaussianBlur(40))
shield_fill = Image.alpha_composite(shield_fill, shine)
img = Image.alpha_composite(img, Image.composite(shield_fill, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), mask2))

shd.polygon(path, outline=(255, 255, 255, 90), width=4)
# Check mark.
shd.line((700, 575, 742, 622), fill=(255, 255, 255, 255), width=30)
shd.line((742, 622, 818, 530), fill=(255, 255, 255, 255), width=30)
img = Image.alpha_composite(img, shield)

# Very subtle vignette for depth.
vignette = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
vd = ImageDraw.Draw(vignette)
vd.ellipse((40, 30, 984, 994), outline=(8, 12, 34, 24), width=60)
vignette = vignette.filter(ImageFilter.GaussianBlur(30))
img = Image.alpha_composite(img, vignette)

# Export all icon sizes from the same master to keep them consistent across Dock, Launchpad, Spotlight.
for size, filename in SPECS:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(ICONSET / filename)

print(f"Generated {len(SPECS)} app icon renditions in {ICONSET}")
