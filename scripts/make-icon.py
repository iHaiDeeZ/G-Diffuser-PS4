# PS4 app icon (sce_sys/icon0.png, 512x512 opaque): G-Diffuser's own icon
# (assets/branding/gdiffuser-icon.png in the G-Diffuser tree), centred on black.
#   python make-icon.py <gdiffuser-icon.png> <out icon0.png>
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
S = 512
logo = Image.open(src).convert("RGBA")
logo.thumbnail((448, 448), Image.LANCZOS)
img = Image.new("RGBA", (S, S), (0, 0, 0, 255))
img.alpha_composite(logo, ((S - logo.width) // 2, (S - logo.height) // 2))
img.convert("RGB").save(out)
print("wrote", out, img.size)
