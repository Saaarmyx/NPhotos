# Packaging NPhotos: iconos, APK y .deb

## 1. El icono: especificaciones

Fuente de verdad: `assets/vectors/nphotos.svg` (+ `-light`, `-dark`).
Reglas para el diseño:

* **Master**: SVG de **1024×1024**, diseño plano y simple, **sin texto**
  (ilegible en pequeño). Elemento principal centrado ocupando ~60-70%.
* **Zona segura Android**: el icono adaptativo recorta con máscaras
  (círculo, squircle…); nada importante fuera del **círculo central de 66dp**
  sobre los 108dp del lienzo. El glifo debe venir **sin fondo** para el
  `foreground` (el fondo lo pone el color del adaptativo).
* **Fondo a sangre**: el fondo debe llegar hasta el borde (el launcher
  recorta, no añade).
* **Variantes** (selector experimental): `default` (fondo marca + glifo
  claro), `light` (fondo claro + glifo oscuro), `dark` (fondo casi negro +
  glifo claro). Además capa **monocromo** (silueta a un color) para los
  iconos temáticos de Android 13+ (reutiliza el `foreground`).

Aplicar cambios al arte: `python3 packaging/icons/apply_artwork.py`
(rasteriza con inkscape legacy + foregrounds + hicolor y copia el SVG
escalable). `packaging/icons/generar_iconos.py` es una alternativa con
cairosvg para legacy + hicolor.

### Dónde vive cada cosa

| Pieza | Ruta |
|---|---|
| Vectores adaptativos (API 26+) | `android/.../res/mipmap-anydpi-v26/ic_launcher[_light\|_dark].xml` |
| Glifo sin fondo (foreground) | `res/mipmap-<dpi>/ic_launcher_foreground[_light\|_dark].png` |
| Fondos adaptativos | `res/values/colors.xml` (`ic_launcher_background[_light\|_dark]`) |
| PNG legacy (API <26) | `res/mipmap-<mdpi…xxxhdpi>/ic_launcher[_light\|_dark].png` (48/72/96/144/192px) |
| Aliases del selector | `AndroidManifest.xml` (`.LauncherLight`, `.LauncherDark`) |
| Linux hicolor | `packaging/linux/icons/hicolor/<16…512>/apps/nphotos.png` |
| Linux escalable + `.desktop` | `packaging/linux/icons/scalable/apps/nphotos.svg`, `packaging/linux/nphotos.desktop` |

Regenerar los PNG tras cambiar el diseño: `python3 packaging/icons/apply_artwork.py`
(o `flutter_launcher_icons` con el arte final).

### Selector experimental de iconos

El manifiesto declara `.LauncherLight`/`.LauncherDark` **deshabilitados**;
la actividad principal sigue siendo el icono default. El futuro conmutador
(Nexora: `AppIconVariant`) debe, vía platform channel:

```kotlin
val pm = context.packageManager
// 1. Desactivar los tres componentes launcher:
//    ".MainActivity", ".LauncherLight", ".LauncherDark"
// 2. Activar solo el elegido:
pm.setComponentEnabledSetting(
    ComponentName(context, "com.nexora.nphotos.LauncherDark"),
    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
    PackageManager.DONT_KILL_APP,
)
```

## 2. APK Android

```bash
# Debug (firma debug automática)
flutter build apk --debug
# Release por ABI (recomendado para distribuir)
flutter build apk --release --split-per-abi
```

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

Genera `nphotos_<versión>_amd64.deb`: binario en `/usr/lib/nphotos`,
enlace en `/usr/bin/nphotos`, `.desktop` en `/usr/share/applications` e
iconos en `/usr/share/icons`. Instalar con `sudo dpkg -i nphotos_*_amd64.deb`
(`Depends: libgtk-3-0`).
