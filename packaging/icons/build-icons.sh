#!/usr/bin/env bash
# Genera todos los iconos de NPhotos desde el arte maestro en assets/.
#
# Fuente (la primera que exista, en este orden):
#   assets/NPhotos.svg            (recomendada: vectorial, sin pérdida)
#   assets/NPhotos.png            (raster: usar de >=1024px si es posible)
# Foreground de Android (opcional, mismo orden de preferencia):
#   assets/NPhotos-foreground.svg / assets/NPhotos-foreground.png
#   Si no existe, el foreground reutiliza el icono completo.
#
# Genera:
#   Android  res/mipmap-<dpi>/ic_launcher.png            (48/72/96/144/192)
#   Android  res/mipmap-<dpi>/ic_launcher_foreground.png (108/162/216/324/432)
#   Ubuntu   packaging/linux/icons/hicolor/512x512/apps/NPhotos.png
#
# Uso:
#   ./packaging/icons/build-icons.sh
#
# Requiere: inkscape (solo si la fuente es SVG) o python3 + PIL (para PNG).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASSETS="$ROOT/assets"
RES="$ROOT/android/app/src/main/res"
UBU="$ROOT/packaging/linux/icons/hicolor/512x512/apps"

DENSITIES="mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192"
FG_DENSITIES="mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432"
# Escala del arte dentro del foreground (0.72 = aire para la zona segura).
FG_SCALE="0.72"

fail() { echo "ERROR: $*" >&2; exit 1; }

# --- Resuelve fuente principal ---
if [ -f "$ASSETS/NPhotos.svg" ]; then
  SRC="$ASSETS/NPhotos.svg"
  SRC_KIND="svg"
  command -v inkscape >/dev/null 2>&1 || fail "hay assets/NPhotos.svg pero inkscape no está instalado"
elif [ -f "$ASSETS/NPhotos.png" ]; then
  SRC="$ASSETS/NPhotos.png"
  SRC_KIND="png"
  python3 -c "import PIL" 2>/dev/null || fail "hay assets/NPhotos.png pero falta python3-PIL"
else
  fail "falta el arte maestro: pon assets/NPhotos.svg (ideal) o assets/NPhotos.png"
fi

# --- Resuelve foreground (opcional) ---
FG=""
if [ -f "$ASSETS/NPhotos-foreground.svg" ]; then
  FG="$ASSETS/NPhotos-foreground.svg"
elif [ -f "$ASSETS/NPhotos-foreground.png" ]; then
  FG="$ASSETS/NPhotos-foreground.png"
fi
if [ -z "$FG" ]; then
  echo "==> sin foreground dedicado: se reutiliza el icono completo"
  FG="$SRC"
  FG_KIND="$SRC_KIND"
else
  echo "==> foreground dedicado: $(basename "$FG")"
  case "$FG" in
    *.svg) FG_KIND="svg" ;;
    *) FG_KIND="png" ;;
  esac
fi
echo "==> fuente: $(basename "$SRC")"

render_svg() { # $1=origen $2=salida $3=px
  # OJO inkscape snap: exige rutas absolutas y solo escribe dentro de
  # áreas permitidas (el repo vale, /tmp personalizado no).
  local src dst px
  src="$(realpath "$1")"; dst="$(realpath -m "$2")"; px="$3"
  if inkscape --export-type=png --export-filename="$dst" \
      -w "$px" -h "$px" "$src" >/dev/null 2>&1 && [ -s "$dst" ]; then
    return 0
  fi
  echo "  inkscape falló, probando cairosvg..."
  SRC_IMG="$src" DST_IMG="$dst" PX="$px" python3 - <<'EOF'
import os
import cairosvg
px = int(os.environ["PX"])
cairosvg.svg2png(url=os.environ["SRC_IMG"], write_to=os.environ["DST_IMG"],
                 output_width=px, output_height=px)
EOF
}

render_png() { # $1=origen $2=salida $3=px  (vía PIL)
  SRC_IMG="$1" DST_IMG="$2" PX="$3" python3 - <<'EOF'
import os
from PIL import Image
src = Image.open(os.environ["SRC_IMG"]).convert("RGBA")
px = int(os.environ["PX"])
if src.width < px:
    print(f"  aviso: ampliando {src.width}px -> {px}px (usa un master mayor)")
dst = src.resize((px, px), Image.LANCZOS)
dst.save(os.environ["DST_IMG"])
EOF
}

render() { # $1=origen $2=salida $3=px $4=kind
  if [ "$4" = "svg" ]; then
    render_svg "$1" "$2" "$3"
  else
    render_png "$1" "$2" "$3"
  fi
  [ -s "$2" ] || fail "no se pudo renderizar $2"
}

# --- Android ---
for entry in $DENSITIES; do
  dpi="${entry%%:*}"; px="${entry##*:}"
  render "$SRC" "$RES/mipmap-${dpi}/ic_launcher.png" "$px" "$SRC_KIND"
done
# Foreground con aire: el launcher recorta al ~60% central (zona segura
# de 66dp sobre 108dp). Sin este inset el arte se ve cropeado/con zoom.
for entry in $FG_DENSITIES; do
  dpi="${entry%%:*}"; px="${entry##*:}"
  # Temp junto al destino: inkscape snap no escribe en /tmp personalizado.
  tmp="$(mktemp -p "$RES/mipmap-${dpi}" .fg-tmp.XXXXXX.png)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT
  render "$FG" "$tmp" "$(python3 -c "print(round($px * $FG_SCALE))")" "$FG_KIND"
  SRC_IMG="$tmp" DST_IMG="$RES/mipmap-${dpi}/ic_launcher_foreground.png" PX="$px" python3 - <<'EOF'
import os
from PIL import Image
art = Image.open(os.environ["SRC_IMG"]).convert("RGBA")
px = int(os.environ["PX"])
canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
canvas.paste(art, ((px - art.width) // 2, (px - art.height) // 2), art)
canvas.save(os.environ["DST_IMG"])
EOF
  trap - EXIT
  rm -f "$tmp"
done

# --- Ubuntu ---
mkdir -p "$UBU"
render "$SRC" "$UBU/NPhotos.png" 512 "$SRC_KIND"

echo "==> OK iconos regenerados:"
ls "$RES"/mipmap-*/ic_launcher*.png "$UBU/NPhotos.png"
