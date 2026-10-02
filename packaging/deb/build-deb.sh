#!/usr/bin/env bash
# Genera NPhotos_<version>_amd64.deb desde el bundle release de Flutter.
#
# Uso:
#   ./packaging/deb/build-deb.sh
#   DEB_MAINTAINER="Nombre <email>" ./packaging/deb/build-deb.sh
#
# Requiere: flutter, dpkg-deb.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//;s/+.*//;s/[[:space:]]//g')"
# Canal desde el sufijo de versión (26.09.28-release -> release).
# Sin sufijo se considera debug.
CANAL="$(echo "$VERSION" | sed -n 's/.*-\(release\|beta\|debug\)$/\1/p')"
CANAL="${CANAL:-debug}"
ARCH="amd64"
MAINTAINER="${DEB_MAINTAINER:-Nexora Labs <nexora@ncloud.com>}"

echo "==> flutter build linux --release"
(cd "$ROOT" && flutter build linux --release)

BUNDLE="$ROOT/build/linux/x64/release/bundle"
if [ ! -x "$BUNDLE/NPhotos" ]; then
  echo "ERROR: no se encontró el binario $BUNDLE/NPhotos" >&2
  exit 1
fi
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> ensamblando paquete $VERSION en $STAGE"
chmod 755 "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/usr/lib/NPhotos" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons"

cat > "$STAGE/DEBIAN/control" <<EOF
# `Package:` va en minúsculas a propósito, aunque el resto de la suite use
# PascalCase: es un campo del formato de Debian, no un nombre de paquete de
# Dart, y dpkg rechaza cualquier carácter en mayúscula ahí. El resto del
# paquete (rutas, binario, .desktop) sí va en PascalCase.
Package: nphotos
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Depends: libgtk-3-0 | libgtk-3-0t64, libblkid1, liblzma5, libglib2.0-0, libmpv2
Description: Visor y organizador de fotos de Nexora
 Explora, organiza y marca como favoritas tus fotos.
EOF

cp -r "$BUNDLE/"* "$STAGE/usr/lib/NPhotos/"
chmod 755 "$STAGE/usr/lib/NPhotos/NPhotos"
ln -s /usr/lib/NPhotos/NPhotos "$STAGE/usr/bin/NPhotos"
cp "$ROOT/packaging/linux/NPhotos.desktop" "$STAGE/usr/share/applications/"
chmod 644 "$STAGE/usr/share/applications/NPhotos.desktop"
cp -r "$ROOT/packaging/linux/icons/"* "$STAGE/usr/share/icons/"
chmod 644 "$STAGE/DEBIAN/control"

OUT="$ROOT/compilaciones/deb/$CANAL/NPhotos_${VERSION}_${ARCH}.deb"
mkdir -p "$(dirname "$OUT")"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT"
echo "==> OK $OUT"
echo "==> instala con: sudo apt install ./$(basename "$OUT")"
