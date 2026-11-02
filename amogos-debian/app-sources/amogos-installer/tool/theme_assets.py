# Deterministic UI sprites supply the dark-red Plymouth rail and its red sliding light.
import pathlib
from PIL import Image, ImageDraw

folder = pathlib.Path(__file__).resolve().parents[1] / "boot/plymouth/amogos2pro"
folder.mkdir(parents=True, exist_ok=True)
rail = Image.new("RGBA", (264, 8))
ImageDraw.Draw(rail).rounded_rectangle((0, 0, 263, 7), radius=4, fill=(46, 9, 12, 255))
rail.save(folder / "rail.png")
slider = Image.new("RGBA", (62, 8))
mask = Image.new("L", slider.size)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 61, 7), radius=4, fill=255)
for x in range(62):
    t = x / 61
    color = tuple(round(a + (b - a) * t) for a, b in zip((245, 35, 44), (180, 0, 12)))
    ImageDraw.Draw(slider).line((x, 0, x, 7), fill=(*color, 255))
slider.putalpha(mask)
slider.save(folder / "slider.png")
