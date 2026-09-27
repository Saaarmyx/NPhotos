#!/usr/bin/env python3
"""Aplica assets/vectors/*.svg como iconos finales de NPhotos.

Lee:
  assets/vectors/nphotos.svg       (variante default)
  assets/vectors/nphotos-light.svg (variante clara)
  assets/vectors/nphotos-dark.svg  (variante oscura)

Genera (vía inkscape, rutas absolutas por el confinamiento snap):
  - android mipmap-<dpi>/ic_launcher[|_light|_dark].png  (48/72/96/144/192)
  - android mipmap-<dpi>/ic_launcher_foreground[|_light|_dark].png
    (glifo sin fondo, 108/162/216/324/432) para el icono adaptativo
  - packaging/linux/icons/hicolor/<16..512>/apps/nphotos.png
  - packaging/linux/icons/scalable/apps/nphotos.svg (copia del default)
"""
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "assets" / "vectors"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
HICOLOR = ROOT / "packaging" / "linux" / "icons" / "hicolor"
SCALABLE = ROOT / "packaging" / "linux" / "icons" / "scalable" / "apps"

VARIANTS = {"": "nphotos.svg", "_light": "nphotos-light.svg",
            "_dark": "nphotos-dark.svg"}
ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144,
                  "xxxhdpi": 192}
ANDROID_FG = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
              "xxxhdpi": 432}
LINUX_SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def rasterize(src: Path, size: int, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["inkscape", "--export-type=png",
         "-w", str(size), "-h", str(size),
         "-o", str(dest), str(src)],
        check=True, capture_output=True,
    )
    print(f"OK {dest.relative_to(ROOT)}")


def foreground_svg(src: Path) -> Path:
    """SVG con solo el glifo (sin el rectángulo de fondo)."""
    lines = [
        line for line in src.read_text().splitlines()
        if '<rect width="1024" height="1024"' not in line
    ]
    tmp = src.parent / f".{src.stem}-fg.svg"
    tmp.write_text("\n".join(lines) + "\n")
    return tmp


def main() -> None:
    tmp_files = []
    try:
        for suffix, name in VARIANTS.items():
            src = SRC / name
            if not src.exists():
                raise SystemExit(f"Falta {src}")
            fg = foreground_svg(src)
            tmp_files.append(fg)
            for dpi, px in ANDROID_LEGACY.items():
                rasterize(src, px,
                          RES / f"mipmap-{dpi}" / f"ic_launcher{suffix}.png")
            for dpi, px in ANDROID_FG.items():
                rasterize(fg, px,
                          RES / f"mipmap-{dpi}" /
                          f"ic_launcher_foreground{suffix}.png")
            if suffix == "":
                for px in LINUX_SIZES:
                    rasterize(src, px,
                              HICOLOR / f"{px}x{px}" / "apps" / "nphotos.png")
        SCALABLE.mkdir(parents=True, exist_ok=True)
        shutil.copy(SRC / "nphotos.svg", SCALABLE / "nphotos.svg")
        print(f"OK { (SCALABLE / 'nphotos.svg').relative_to(ROOT)}")
    finally:
        for tmp in tmp_files:
            tmp.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
