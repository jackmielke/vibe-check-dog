from PIL import Image, ImageDraw, ImageFilter

N = 4096                      # work big, downsample at the end
FUR       = (139, 121, 108)
FUR_DARK  = (103,  88,  79)
FUR_LIGHT = (202, 186, 171)
SNOUT     = ( 41,  35,  37)
CAP       = ( 27,  30,  46)
CAP_LIFT  = ( 43,  47,  66)
BG_TOP    = (255, 190,  92)
BG_BOT    = (243, 154,  48)

u = N * 0.0040                # one design unit (matches DogView's 240pt box)

def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        px[0, y] = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return img.resize((size, size))

def ellipse(d, cx, cy, w, h, fill):
    d.ellipse([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], fill=fill)

def rounded(d, cx, cy, w, h, r, fill):
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=r, fill=fill)

def rotated_ellipse(layer, cx, cy, w, h, deg, fill):
    """Draw an ellipse rotated about its own centre onto `layer`."""
    pad = int(max(w, h) * 1.6)
    tile = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    td.ellipse([(pad - w) / 2, (pad - h) / 2, (pad + w) / 2, (pad + h) / 2], fill=fill)
    tile = tile.rotate(deg, resample=Image.BICUBIC)
    layer.alpha_composite(tile, (int(cx - pad / 2), int(cy - pad / 2)))

# ---- foreground: the dog's head, on its own transparent layer ---------------
fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(fg)
cx, cy = N / 2, N / 2

# ears (behind the skull)
for side in (-1, 1):
    rotated_ellipse(fg, cx + side * 86 * u, cy + 0 * u, 50 * u, 82 * u, -side * 20, FUR_DARK)

d = ImageDraw.Draw(fg)
ellipse(d, cx, cy, 174 * u, 158 * u, FUR)                 # skull
ellipse(d, cx, cy + 36 * u, 116 * u, 82 * u, FUR_LIGHT)   # muzzle
rounded(d, cx, cy + 16 * u, 42 * u, 30 * u, 13 * u, SNOUT)  # nose

# nostrils
for side in (-1, 1):
    rounded(d, cx + side * 8.5 * u, cy + 17 * u, 5 * u, 10 * u, 2.5 * u, FUR_LIGHT)

# unamused mouth
d.line([(cx - 32 * u, cy + 52 * u), (cx - 16 * u, cy + 44 * u),
        (cx, cy + 45 * u),
        (cx + 16 * u, cy + 44 * u), (cx + 32 * u, cy + 52 * u)],
       fill=SNOUT, width=int(4.5 * u), joint="curve")

# eyes: a dark disc with a heavy lid over the top 42%
for side in (-1, 1):
    ex, ey = cx + side * 34 * u, cy - 14 * u
    eye = Image.new("RGBA", (int(30 * u), int(30 * u)), (0, 0, 0, 0))
    ed = ImageDraw.Draw(eye)
    ed.ellipse([u, u, 29 * u, 29 * u], fill=SNOUT)
    ed.ellipse([6 * u, 5 * u, 13 * u, 12 * u], fill=(248, 244, 236))     # catchlight
    ed.rectangle([0, 0, 30 * u, 13 * u], fill=FUR)                       # lid
    mask = Image.new("L", eye.size, 0)
    ImageDraw.Draw(mask).ellipse([u, u, 29 * u, 29 * u], fill=255)
    eye.putalpha(mask)
    fg.alpha_composite(eye, (int(ex - 15 * u), int(ey - 15 * u)))

d = ImageDraw.Draw(fg)
# brows
for side in (-1, 1):
    brow = Image.new("RGBA", (int(70 * u), int(40 * u)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(brow)
    bd.rounded_rectangle([14 * u, 14 * u, 56 * u, 26 * u], radius=6 * u, fill=FUR_DARK)
    brow = brow.rotate(-side * 9, resample=Image.BICUBIC)
    fg.alpha_composite(brow, (int(cx + side * 36 * u - 35 * u), int(cy - 38 * u - 20 * u)))

d = ImageDraw.Draw(fg)
ellipse(d, cx, cy - 64 * u, 178 * u, 94 * u, CAP)          # crown
ellipse(d, cx, cy - 46 * u, 190 * u, 44 * u, CAP)          # brim
ellipse(d, cx, cy - 108 * u, 14 * u, 14 * u, CAP_LIFT)     # button

# ---- compose onto the background, auto-centred ------------------------------
bg = gradient(N, BG_TOP, BG_BOT).convert("RGBA")
bbox = fg.split()[3].getbbox()
art = fg.crop(bbox)
target = int(N * 0.78)
scale = target / max(art.width, art.height)
art = art.resize((int(art.width * scale), int(art.height * scale)), Image.LANCZOS)
ox = (N - art.width) // 2
oy = (N - art.height) // 2

shadow = art.split()[3].point(lambda v: int(v * 0.30)).filter(ImageFilter.GaussianBlur(N * 0.016))
bg.paste(Image.new("RGBA", art.size, (90, 45, 0, 255)), (ox, oy + int(N * 0.018)), shadow)
bg.alpha_composite(art, (ox, oy))

bg.convert("RGB").resize((1024, 1024), Image.LANCZOS).save("AppIcon-1024.png")
print("wrote AppIcon-1024.png")
