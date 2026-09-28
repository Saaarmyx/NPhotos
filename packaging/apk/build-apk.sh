#!/usr/bin/env bash
# Genera los APK de NPhotos en compilaciones/apk/<canal>/.
#
# Uso:
#   ./packaging/apk/build-apk.sh
#
# El canal se deduce del sufijo de `version:` en pubspec.yaml
# (26.09.28-release -> release, -beta -> beta, -debug o sin sufijo -> debug):
#   - debug: flutter build apk --debug (APK único)
#   - beta/release: flutter build apk --release --split-per-abi
#
# Requiere: flutter.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version:[[:space:]]*//;s/+.*//;s/[[:space:]]//g')"
CANAL="$(echo "$VERSION" | sed -n 's/.*-\(release\|beta\|debug\)$/\1/p')"
CANAL="${CANAL:-debug}"

OUT_DIR="$ROOT/compilaciones/apk/$CANAL"
mkdir -p "$OUT_DIR"

if [ "$CANAL" = "debug" ]; then
  echo "==> flutter build apk --debug"
  (cd "$ROOT" && flutter build apk --debug)
  SRC="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
  cp "$SRC" "$OUT_DIR/nphotos_${VERSION}_debug.apk"
else
  echo "==> flutter build apk --release --split-per-abi"
  (cd "$ROOT" && flutter build apk --release --split-per-abi)
  for abi in arm64-v8a armeabi-v7a x86_64; do
    SRC="$ROOT/build/app/outputs/flutter-apk/app-${abi}-release.apk"
    if [ -f "$SRC" ]; then
      cp "$SRC" "$OUT_DIR/nphotos_${VERSION}_${abi}.apk"
    fi
  done
fi

echo "==> OK $OUT_DIR"
ls -la "$OUT_DIR"
