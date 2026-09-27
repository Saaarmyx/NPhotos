#!/usr/bin/env bash
# Genera nphotos_<version>_amd64.deb desde el bundle release de Flutter.
#
# Uso:
#   ./packaging/deb/build-deb.sh
#   DEB_MAINTAINER="Nombre <email>" ./packaging/deb/build-deb.sh
#
# Requiere: flutter, dpkg-deb.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//;s/+.*//;s/[[:space:]]//g')"
ARCH="amd64"
MAINTAINER="${DEB_MAINTAINER:-Nexora Labs <nexora@ncloud.com>}"

echo "==> flutter build linux --release"
(cd "$ROOT" && flutter build linux --release)

BUNDLE="$ROOT/build/linux/x64/release/bundle"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> ensamblando paquete $VERSION en $STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/usr/lib/nphotos" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: nphotos
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Depends: libgtk-3-0 | libgtk-3-0t64
Description: Visor y organizador de fotos de Nexora
 Explora, organiza y marca como favoritas tus fotos.
EOF

cp -r "$BUNDLE/"* "$STAGE/usr/lib/nphotos/"
ln -s /usr/lib/nphotos/nphotos "$STAGE/usr/bin/nphotos"
cp "$ROOT/packaging/linux/nphotos.desktop" "$STAGE/usr/share/applications/"
cp -r "$ROOT/packaging/linux/icons/"* "$STAGE/usr/share/icons/"

OUT="$ROOT/nphotos_${VERSION}_${ARCH}.deb"
dpkg-deb --build "$STAGE" "$OUT"
echo "==> OK $OUT"
