#!/usr/bin/env python3
"""Genera los iconos de NPhotos a partir de un archivo SVG.

Renderiza un archivo SVG (y opcionalmente variantes _light/_dark) en múltiples
tamaños y los vuelca en:
  - android/app/src/main/res/mipmap-<dpi>/ic_launcher[_light|_dark].png
  - packaging/linux/icons/hicolor/<size>/apps/nphotos.png
"""
import io
from pathlib import Path
import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent  # nphotos/
RES = ROOT / "android/app/src/main/res"
HICOLOR = ROOT / "packaging/linux/icons/hicolor"
ASSETS_SVG = ROOT / "assets" / "vectors"  # Carpeta donde guardas tus SVG

# (sufijo en el launcher de Android, sufijo para buscar el archivo SVG)
VARIANTS = {
    "": "",
    "_light": "_light",
    "_dark": "_dark",
}

ANDROID_DPIS = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def svg_to_image(svg_path: Path, size: int) -> Image.Image:
    """Convierte un archivo SVG a un objeto PIL.Image rasterizado a 'size' píxeles."""
    png_data = cairosvg.svg2png(
        url=str(svg_path),
        output_width=size,
        output_height=size,
    )
    return Image.open(io.BytesIO(png_data))


def main() -> None:
    for android_suffix, svg_suffix in VARIANTS.items():
        # Busca el SVG específico de la variante; si no existe, usa el por defecto
        svg_path = ASSETS_SVG / f"nphotos{svg_suffix}.svg"
        if not svg_path.exists():
            svg_path = ASSETS_SVG / "nphotos.svg"

        if not svg_path.exists():
            print(f"ADVERTENCIA: No se encontró ningún SVG en {svg_path}")
            continue

        print(f"Usando SVG: {svg_path.name}")
        master = svg_to_image(svg_path, 1024)

        # Generar iconos para Android
        for dpi, px in ANDROID_DPIS.items():
            out = RES / f"mipmap-{dpi}" / f"ic_launcher{android_suffix}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            master.resize((px, px), Image.LANCZOS).save(out)
            print(f"OK {out}")

        # Generar iconos para Linux (solo aplicamos el icono principal/default)
        if android_suffix == "":
            for px in LINUX_SIZES:
                out = HICOLOR / f"{px}x{px}" / "apps" / "nphotos.png"
                out.parent.mkdir(parents=True, exist_ok=True)
                master.resize((px, px), Image.LANCZOS).save(out)
                print(f"OK {out}")


if __name__ == "__main__":
    main()