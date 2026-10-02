#!/usr/bin/env bash
# Genera los 3 APK de NPhotos (debug, beta, release) en un solo llamado.
#
# Salidas en compilaciones/apk/<canal>/NPhotos_<AA.MM.DD>-<canal>.apk
# (APK único universal por canal).
#
# La base de versión sale de `version:` en pubspec.yaml (solo AA.MM.DD,
# se ignora el sufijo actual) y se inyecta por canal con --build-name,
# así el versionName horneado coincide con la carpeta y el archivo.
#
# Uso:
#   ./packaging/apk/build-apk.sh
#
# Requiere: flutter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PUBSPEC_VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//;s/[[:space:]]//g')"
BASE="$(echo "$PUBSPEC_VERSION" | sed 's/-.*//;s/+.*//')"
BUILDNUM="$(echo "$PUBSPEC_VERSION" | sed -n 's/.*+\([0-9][0-9]*\)$/\1/p')"
BUILDNUM="${BUILDNUM:-1}"

echo "==> base $BASE (build $BUILDNUM)"

for CANAL in debug beta release; do
  VER="${BASE}-${CANAL}"
  OUT_DIR="$ROOT/compilaciones/apk/$CANAL"
  mkdir -p "$OUT_DIR"

  if [ "$CANAL" = "debug" ]; then
    echo "==> [$CANAL] flutter build apk --debug"
    (cd "$ROOT" && flutter build apk --debug --build-name="$VER" --build-number="$BUILDNUM")
    SRC="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
  else
    echo "==> [$CANAL] flutter build apk --release"
    (cd "$ROOT" && flutter build apk --release --build-name="$VER" --build-number="$BUILDNUM")
    SRC="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
  fi

  cp "$SRC" "$OUT_DIR/NPhotos_${VER}.apk"
  echo "==> [$CANAL] OK $OUT_DIR/NPhotos_${VER}.apk"
done

echo "==> compilaciones/apk:"
ls -la "$ROOT"/compilaciones/apk/*/*.apk
