# Packaging NPhotos: compilaciones por canal (release/beta/debug)

Las salidas van a `compilaciones/` (ignorada por git):

```
compilaciones/
  apk/release|beta|debug/
  deb/release|beta|debug/
```

El canal se deduce del sufijo de `version:` en pubspec.yaml
(`26.09.28-release` → `release`, `-beta` → `beta`, `-debug` o sin
sufijo → `debug`).

## 1. El icono: un solo PNG por plataforma

## 1. El icono: un solo PNG por plataforma

Release 26.09.28: un único icono, sin variantes claro/oscuro ni SVG.
Si hay que cambiar el diseño, sustituir el PNG en su resolución y listo.

| Pieza | Ruta |
|---|---|
| Android adaptativo (API 26+) | `android/.../res/mipmap-anydpi-v26/ic_launcher.xml` (fondo `@color/ic_launcher_background` + `foreground`) |
| Android glifo + legacy | `res/mipmap-<mdpi…xxxhdpi>/ic_launcher_foreground.png` e `ic_launcher.png` (48/72/96/144/192px) |
| Fondo adaptativo | `res/values/colors.xml` (`ic_launcher_background`) |
| Linux hicolor | `packaging/linux/icons/hicolor/512x512/apps/nphotos.png` (el escritorio escala hacia abajo) |
| `.desktop` | `packaging/linux/nphotos.desktop` |

## 2. APK Android

```bash
./packaging/apk/build-apk.sh
```

Copia los APK a `compilaciones/apk/<canal>/` como
`nphotos_<versión>_<abi>.apk` (`debug`: APK único; `beta`/`release`:
uno por ABI con `--split-per-abi`).

**Firma release** (una vez):

```bash
keytool -genkey -v -keystore ~/keystores/nphotos-release.jks \
  -alias nphotos -keyalg RSA -keysize 2048 -validity 10000
cp android/key.properties.example android/key.properties  # y rellenar
```

Sin `android/key.properties`, la release se firma con clave debug (aviso,
no apto para Play Store). `applicationId`: `com.nexora.nphotos`.

## 3. .deb Ubuntu

```bash
./packaging/deb/build-deb.sh
# o con mantenedor propio:
DEB_MAINTAINER="Nombre <email>" ./packaging/deb/build-deb.sh
```

Genera `compilaciones/deb/<canal>/nphotos_<versión>_amd64.deb`: binario en
`/usr/lib/nphotos`, enlace en `/usr/bin/nphotos`, `.desktop` en
`/usr/share/applications` e iconos en `/usr/share/icons`. Instalar con
`sudo apt install ./nphotos_*_amd64.deb`
(`Depends: libgtk-3-0 | libgtk-3-0t64, libblkid1, liblzma5, libglib2.0-0, libmpv2`).
