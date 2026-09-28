# NPhotos

> Galería multimedia oficial de la suite **Nexora** — exploración, álbumes, favoritos, colecciones, visor y papelera con layout adaptativo móvil/desktop.

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-26.09.28--release-blue)](./pubspec.yaml)
[![License](https://img.shields.io/badge/License-Private-red)](#estándar-de-contribución-y-commits)
[![Platforms](https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20Web-lightgrey?logo=flutter&logoColor=black)](https://flutter.dev/multi-platform)

---

## 1. Propósito e Integración

**NPhotos** (`package:nphotos`, `version: 26.09.28-release+1`, `publish_to: none`) es la aplicación de galería del ecosistema **Nexora**.

Responsabilidad única (SRP): el **dominio fotográfico local** — escaneo de medios, estado, favoritos, papelera, álbumes, colecciones y visualización. No define Design System, ni navegación base, ni persistencia compartida; eso vive en el kit.

### Interacción con el monorepo

- **Consume el Design System** por dependencia local de ruta, no por copia:

  ```yaml
  dependencies:
    nexora_ui:
      path: ../NexoraUi
  ```

- **Delega el lenguaje visual al kit:** `NAppShell`, `AppAppearance` (acento `NColors.photosAccent`), `NMobileLayout` / `NDesktopLayout`, `NZoomGrid`, `NResponsiveGrid`, `NImageTile`, `NZoomableImage`, `NActionBar`, `NActionSheet`, `NConfirmDialog`, `NRenameDialog`, `NEmptyState`, `NSettingsScreen`.
- **No duplica componentes del kit.** Si una primitiva visual nace en esta app y se generaliza, se sube a `nexora_ui` y aquí se consume por importación. Las reglas de dominio (qué insignias tiene una foto, qué es un álbum de sistema) sí se quedan aquí.
- **Aisla la persistencia:** `LocalStore` sobre `shared_preferences` (favoritos, papelera, pins, preferencias de álbum, appearance, snapshot de escaneo).
- **Permisos en runtime** con `permission_handler`; **reproducción de vídeo** con `media_kit`; **compartir** con `share_plus`; **EXIF/GPS** con `exif` (Dart puro, sin canal de plataforma).

### Dependencias de plataforma

```yaml
dependencies:
  permission_handler: ^11.3.1
  path: ^1.9.0
  shared_preferences: ^2.5.5
  share_plus: ^13.3.0
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
  exif: ^3.3.0
  path_provider: ^2.1.6
  device_info_plus: ^13.2.0
```

---

## 2. Estructura del Proyecto

```text
nphotos/
├── lib/
│   ├── main.dart                     # Bootstrap: MediaKit + LocalStore + appearance
│   ├── app/
│   │   └── nphotos_app.dart          # Shell, destinos, popups por pantalla, selección
│   ├── controllers/
│   │   ├── gallery_controller.dart   # Estado de medios, filtros, pins, batches
│   │   └── selection_controller.dart # Multi-selección (fotos / álbumes)
│   ├── models/
│   │   ├── photo.dart                # Entidad foto/vídeo (EXIF, GPS, flags)
│   │   └── collection.dart           # Colecciones y agrupación
│   ├── screens/
│   │   ├── gallery/                  # gallery_screen, photo_viewer_screen
│   │   ├── albums/                   # albums_screen, album_detail_screen
│   │   ├── collections/              # collections_screen (+ CollectionDetailScreen)
│   │   ├── favorites/ videos/ trash/ # Pantallas dedicadas
│   │   └── settings/                 # Ajustes, Permisos, Acerca de
│   ├── services/
│   │   ├── photo_service.dart        # Escaneo por directorios (Android/Linux)
│   │   ├── media_probe.dart          # Duración y tipo de medio
│   │   ├── local_store.dart          # Persistencia + appearance
│   │   └── private_vault.dart        # Cofre privado (v1 sin autenticación)
│   ├── utils/
│   │   └── photo_viewer.dart         # openPhotoViewer + sharePhotos
│   └── widgets/                      # Adaptadores de dominio sobre primitivas del kit
├── test/                             # 10 suites: controladores, local store, pantallas
├── android/ linux/ windows/ web/     # Plataformas habilitadas
├── assets/                           # nphotos.svg
└── packaging/                        # Scripts de APK, DEB, iconos
```

**Criterio de ubicación:** si el widget conoce `Photo`, `Album` o un `Controller`, vive en `lib/`. Si solo sabe pintar, pertenece a `nexora_ui`.

---

## 3. Funcionalidades y Componentes Clave

### Modelos (`lib/models/`)

| Elemento | Responsabilidad |
| --- | --- |
| `Photo` | Entidad única foto/vídeo: ruta, id, fecha de captura y agregación, EXIF, GPS, flags de dominio (motion, HD, selfie, favorito, vídeo). |
| `CollectionKind` / `CollectionGroup` | Colecciones tipadas (recientes, personas, lugares, documentos, HD, privado, álbumes ocultos) con su agrupación. |

### Controladores (`lib/controllers/`)

- **`GalleryController`** — fuente única de verdad del estado de medios. Cubre el ciclo `GalleryState` (`initial` → `permissionDenied` → `loading` → `loaded` → `error`), escaneo e hidratación silenciosa desde caché, watcher de carpetas, y las vistas derivadas `visiblePhotos` / `visibleGroups`. Expone los modos `GallerySort` (día de captura / de agregación), `GalleryViewMode` (por fecha / compacta), `GalleryFilter` (todas / cámara) y `AlbumsViewMode` (parrilla / lista), `CollectionsViewMode` (compacta / agrupada).
  - Operaciones de dominio: `toggleFavorite`, `moveToTrash`, `restoreFromTrash`, `deletePermanently`, `emptyTrash` y sus variantes `…Batch`.
  - Álbumes: `renameAlbum`, `setAlbumCover`, `setAlbumHidden`, `deleteAlbum`, `togglePin` (máx. 4).
  - Privado: `loadPrivate`, `moveToPrivate`, `restoreFromPrivate`.
- **`SelectionController`** — multi-selección separada del estado de medios, para que seleccionar no dispare re-escaneos. `SelectionKind` distingue selección de fotos y de álbumes.

### Servicios (`lib/services/`)

- **`PhotoService`** — descubrimiento de medios por directorios con raíz distinta en Android y Ubuntu, deduplicado y carga en isolate (`compute`).
- **`MediaProbe`** — duración y clase de medio sin decodificar el archivo.
- **`LocalStore`** — persistencia en `shared_preferences`: favoritos, papelera con fecha, pins, preferencias por álbum (`AlbumPrefs`), origen de la bóveda privada, snapshot del escaneo, onboarding, usuario, avatar, acento, `ThemeMode`, estilo de barra y perfil de rendimiento.
- **`PrivateVault`** — mueve medios a un directorio privado. Declarado en la UI como v1: **sin autenticación**.

### Pantallas (`lib/screens/`)

- **Galería** — rejilla con pinch-to-zoom, agrupada por día o compacta, orden y filtro, búsqueda, y entrada a selección con pulsación larga. Inserción incremental de fotos nuevas sin parpadeo.
- **Visor** — pantalla completa con zoom focal de doble toque, pinch, rotación, ajuste que llena la pantalla, chrome auto-ocultable (5 s o al tocar) y descarte al encoger. El swipe se bloquea mientras hay zoom. **Confirmación obligatoria antes de mandar a la papelera.**
- **Álbumes** — pines (por defecto *Cámara* + *Capturas*), filas de sistema, vistas de parrilla/lista, y hoja de acciones por álbum: fijar, renombrar, cambiar carátula, ocultar y eliminar. Las carátulas propias se tiñen con el color de acento; solo las de sistema (Favoritos, Vídeos, Papelera) conservan el suyo.
- **Colecciones** — recientes (7 días), personas, lugares (con sección GPS), documentos, HD, privado y álbumes ocultos. Modo compacto (una sola lista) o agrupado (tarjetas con título).
- **Favoritos / Vídeos / Papelera** — pantallas dedicadas con soporte de selección por lote.
- **Ajustes** — `NPhotosSettingsScreen` sobre las pantallas del kit, más `NPhotosPermissionsScreen` (fotos y medios, ubicación de medios, ubicación, notificaciones) con reversión abriendo los ajustes del sistema, y `NPhotosAboutScreen`.

### Widgets adaptadores (`lib/widgets/`)

Envoltorios finos con la regla de dominio; el render es del kit.

- **`PhotoTile`** — mapea `Photo` a `NImageTile` y decide las insignias: favorito arriba a la derecha, play + duración abajo al centro en vídeos, y hasta dos iconos de estado (motion > HD/+50MP > selfie) abajo a la izquierda en fotos. En modo selección sustituye todo por el overlay de check.
- **`SelectionActionBar`** — barra inferior de acciones en lote sobre `NActionBar`.
- **`album_actions_sheet.dart`** — hoja de acciones de álbum/pin sobre `NActionSheet`, con el diálogo de renombrar y el selector de carátula.
- **`trash_grid.dart`** — parrilla de papelera y confirmación destructiva.

### Utilidades (`lib/utils/photo_viewer.dart`)

- `openPhotoViewer(context, controller:, photos:, initialId:)` — visor a pantalla completa desde cualquier pantalla, resuelto por id para no depender del índice.
- `sharePhotos(context, photos)` — compartir varios archivos con degradado a archivos individuales si la plataforma rechaza la selección múltiple.

---

## 4. Guía de Uso Rápido

### Bootstrap de la aplicación

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nphotos/app/nphotos_app.dart';
import 'package:nphotos/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // La apariencia (acento + ThemeMode) se aplica antes del primer frame
  // para evitar el parpadeo de tema.
  final store = await LocalStore.load();
  store.applyAppearance();

  runApp(NPhotosApp(store: store));
}
```

`NPhotosApp` delega en el `NAppShell` del kit, así que el tema, el `MaterialApp` y el layout responsive son los del Design System:

```dart
class NPhotosApp extends StatelessWidget {
  final LocalStore? store;

  const NPhotosApp({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    return NAppShell(title: 'NPhotos', home: NPhotosHome(store: store));
  }
}
```

### Consumir el controlador de galería

```dart
import 'dart:async';

import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/services/photo_service.dart';

Future<GalleryController> bootstrapGallery() async {
  // Sin argumentos usa `PhotoService()` y el `LocalStore` por defecto.
  // `photoService` se inyecta para escanear un árbol concreto (tests).
  final controller = GalleryController(photoService: PhotoService());

  await controller.startWatching();
  unawaited(controller.fetchPhotos(silent: true));

  return controller;
}
```

Ese es el ciclo de vida real en la app (`NPhotosHomeState`): se observan las carpetas y se refresca en silencio, de modo que las fotos nuevas aparecen solas sin recompilar.

### Abrir el visor desde cualquier pantalla

```dart
import 'package:nphotos/utils/photo_viewer.dart';

onTap: () => openPhotoViewer(
  context,
  controller: controller,
  photos: album.photos,
  initialId: photo.id,   // mejor que initialIndex: la lista puede venir filtrada
),
```

### Usar las primitivas de imagen del kit

La app no reimplementa tiles ni visores; compone los del kit y añade solo la regla de dominio:

```dart
import 'package:nexora_ui/nexora_ui.dart';
import 'package:nphotos/widgets/photo_tile.dart';

// Rejilla con pinch-to-zoom. `newIds` marca las fotos nuevas para que
// aparezcan con animación en vez de saltar; el número de columnas es
// estado local de la pantalla, no del controlador.
NZoomGrid(
  itemCount: visible.length,
  initialColumns: _columns,
  idForIndex: (index) => visible[index].id,
  newIds: controller.lastInsertedIds,
  onColumnsChanged: (columns) => setState(() => _columns = columns),
  itemBuilder: (context, index) => PhotoTile(
    photo: visible[index],
    // `null` = fuera del modo selección: la celda no lleva overlay.
    selected: selection.isSelected(visible[index].id) ? true : null,
  ),
);

// Hoja de acciones: la app declara los datos, el kit los pinta.
NActionSheet(
  title: album.name,
  items: [
    NActionSheetItem(
      icon: Icons.drive_file_rename_outline,
      label: 'Cambiar nombre',
      onTap: () => Navigator.of(context).pop(AlbumAction.rename),
    ),
    NActionSheetItem(
      icon: Icons.delete_outline,
      label: 'Eliminar álbum',
      destructive: true,
      onTap: () => Navigator.of(context).pop(AlbumAction.delete),
    ),
  ],
);
```

---

## 5. Desarrollo y Pruebas Locales

### Requisitos

- Flutter SDK `3.47+` / Dart `3.13+`
- Kit **NexoraUi** clonado como directorio hermano (consumo por `path: ../NexoraUi`)

### Dependencias

```bash
flutter pub get
```

> Si cambias el `pubspec.yaml` de `NexoraUi`, vuelve a ejecutar `flutter pub get` aquí. Sin eso la resolución falla al no encontrar la versión nueva de las dependencias del kit.

### Análisis estático

```bash
flutter analyze
```

### Pruebas

```bash
# Suite completa
flutter test

# Un archivo por vez (recomendado con poca RAM: en paralelo el runner
# se queda sin memoria y los tests mueren con OOM)
flutter test test/albums_collections_test.dart
flutter test test/selection_test.dart
```

> En tests de widget, **toda E/S real de disco va dentro de `tester.runAsync`**. El reloj falso de `testWidgets` no la completa y el test se cuelga hasta morir por tiempo.

### Ejecución local

```bash
# Android (dispositivo o emulador conectado)
flutter run -d <device_id>

# Linux (desktop)
flutter run -d linux

# Web
flutter run -d chrome

# Elegir destino de forma interactiva
flutter run
```

### Build

```bash
flutter build apk --release
flutter build linux --release
```

### Android: core library desugaring (obligatorio)

`nexora_ui` depende de `flutter_local_notifications`, que usa APIs de `java.time` ausentes por debajo de la API 26. Sin desugaring el build falla en `checkDebugAarMetadata`:

```kotlin
// android/app/build.gradle.kts
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
```

### Empaquetado

Los scripts de `packaging/` cubren APK, DEB, iconos y artefactos de Linux:

```bash
cat packaging/README.md
```

---

## 6. Estándar de Contributing y Commits

Este proyecto se desarrolla bajo **Conventional Commits**. Los mensajes de commit son la fuente de verdad del historial y **deben seguir la especificación**, sin excepciones:

```text
<tipo>(<ámbito>): <descripción en imperativo y minúsculas>

tipos:  feat | fix | refactor | docs | style | test | perf | build | ci | chore | revert
```

Ejemplos válidos:

```text
feat(gallery): añade filtro por álbum de cámara
fix(viewer): bloquea el swipe mientras hay zoom aplicado
refactor(kit): extrae NImageTile fuera de la galería
docs(readme): documenta el core library desugaring en Android
test(selection): cubre las operaciones por lote de la papelera
chore(deps): sube share_plus a ^13.3.0
```

Reglas adicionales del repositorio:

- **Sin `git add .` ni `git add -A`.** Se agregan archivos explícitos, para que nada generado (`build/`, `venv/`, artefactos de firma) acabe en un commit por accidente.
- El cuerpo del mensaje explica el **porqué**; el resumen explica el **qué**.
- Un commit = un cambio con sentido. Si el mensaje necesita una "y", probablemente son dos commits.
- Nótese `git diff` antes de confirmar: `nphotos` y `NexoraUi` son paquetes independientes del monorepo y se versionan por separado.

---

## 7. Licencia

**Propietario y de uso interno.** Suite privada del ecosistema Nexora. Todos los derechos reservados.
