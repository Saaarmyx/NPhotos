````markdown
# NPhotos

> Galería multimedia oficial de la suite Nexora — exploración, álbumes, favoritos, colecciones, visor y papelera con layout adaptativo móvil/desktop.

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Version](https://img.shields.io/badge/Version-26.09.28--release-blue)](./pubspec.yaml)
[![License](https://img.shields.io/badge/License-Private-red)](./pubspec.yaml)
[![Platforms](https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20Web-lightgrey)](https://flutter.dev/multi-platform)

---

## 1. Propósito e Integración

**NPhotos** (`package:nphotos`, `version: 26.09.28-release+1`, `publish_to: none`) es la aplicación final de galería del ecosistema **Nexora**.

Responsabilidad única (SRP): gestionar el **dominio fotográfico local** — escaneo, estado, favoritos, papelera, álbumes y visualización. No define Design System, navegación base ni ajustes globales.

Integración con el monorepo/suite `Nexora`:

- Consume `nexora_ui` por dependencia local de ruta:
- Delega lenguaje visual y shell a `nexora_ui`: `NAppShell`, `AppAppearance` (`NColors.photosAccent`), `NMobileLayout` / `NDesktopLayout`, `ResponsiveLayout`, `NViewerTopBar` / `NViewerBottomBar`, `NButton`, `NCard`, `NEmptyState`, `NStateViews`, `NSpacing`, `NTypography`, `NBreakpoints`.
- Reutiliza pantallas transversales (`NSettingsScreen`, cuenta, personalización) y solo añade `NPhotosSettingsScreen` para ajustes propios.
- Persistencia local aislada con `shared_preferences`; permisos runtime con `permission_handler`; reproducción con `media_kit` / `media_kit_video`.

```yaml
dependencies:
  nexora_ui:
    path: ../NexoraUi
  permission_handler: ^11.3.1
  shared_preferences: ^2.5.5
  share_plus: ^13.3.0
  media_kit: ^1.2.6
  media_kit_video: ^2.0.1
  media_kit_libs_video: ^1.0.7
```
````

## 2. Estructura del Proyecto

```text
nphotos/
├── lib/
│   ├── main.dart                          # Bootstrap: MediaKit + photosAccent + NPhotosApp
│   ├── app/
│   │   └── nphotos_app.dart               # NAppShell + ResponsiveLayout + 4 destinos
│   ├── models/
│   │   ├── photo.dart                     # Entidad inmutable Photo + copyWith
│   │   └── collection.dart                # CollectionKind (iconos, labels)
│   ├── controllers/
│   │   └── gallery_controller.dart        # ChangeNotifier + GalleryState
│   ├── services/
│   │   ├── photo_service.dart             # Escaneo Android/Linux en isolate (compute)
│   │   └── local_store.dart               # Persistencia favoritos + papelera
│   ├── screens/
│   │   ├── gallery/gallery_screen.dart
│   │   ├── gallery/photo_viewer_screen.dart
│   │   ├── albums/albums_screen.dart
│   │   ├── favorites/favorites_screen.dart
│   │   ├── collections/collections_screen.dart
│   │   └── settings/nphotos_settings_screen.dart
│   ├── widgets/
│   │   ├── photo_grid.dart                # Grid responsivo reutilizable
│   │   ├── photo_tile.dart                # Tile Image.file + cache + error
│   │   └── trash_grid.dart                # Grid papelera + restaurar/eliminar
├── test/
│   ├── gallery_controller_test.dart
│   ├── local_store_test.dart
│   └── widget_test.dart
├── android/ linux/ windows/ web/          # Runners multi-plataforma
├── pubspec.yaml
├── analysis_options.yaml                  # include: package:flutter_lints/flutter.yaml
└── README.md
```

## 3. Funcionalidades y Componentes Clave

### Modelos

- `Photo` — `id`, `path`, `name`, `dateTime`, `width/height`, `size`, `isFavorite`, `isTrashed`, `copyWith`, `albumKey` (carpeta padre).
- `CollectionKind` — destinos extra del sidebar desktop, iconos y labels centralizados.

### Estado

- `GalleryController extends ChangeNotifier` — `GalleryState: initial | loading | loaded | permissionDenied | error`.
- Selectores cacheados: `photos`, `visiblePhotos`, `favoritePhotos`, `trashedPhotos`, `albums`.
- Acciones: `fetchPhotos()`, `toggleFavorite(id)`, `moveToTrash(id)`, `restoreFromTrash(id)`, `deletePermanently(id)`, `emptyTrash()`.

### Servicios

- `PhotoService.loadPhotos()` — raíces Android (`DCIM/Pictures/Download`) y Linux (`Pictures/Downloads/Imágenes`), filtrado de ocultos y extensiones `jpg/jpeg/png/webp/gif/heic`, escaneo en `compute`, orden descendente por fecha.
- `LocalStore` — persistencia de `favoriteIds` y `trashedIds` vía `shared_preferences`.

### Widgets / Pantallas

- `NPhotosApp` — fija `AppAppearance.setAccentColor(NColors.photosAccent)`, monta `NAppShell` con 4 `NNavigationDestination`: Fotos, Álbumes, Favoritos, Colecciones.
- `GalleryScreen` — grid 3 cols móvil / 5 cols desktop, estados carga/error/vacío/permiso denegado.
- `PhotoGrid` / `PhotoTile` — `Image.file` con `cacheWidth`, placeholder y vista de error.
- `PhotoViewerScreen` — `PageView` + `InteractiveViewer` (0.8x–4x), compartir (`share_plus`), favorito, enviar a papelera.
- `AlbumsScreen` — agrupación por carpeta, cover + contador, detalle interno con grid.
- `FavoritesScreen` — filtro reactivo sobre `favoritePhotos`.
- `CollectionsScreen` + `CollectionDetailScreen` — colecciones curadas.
- `TrashGrid` + `NPhotosSettingsScreen` — gestión de papelera y ajustes propios con enlace a ajustes globales.

## 4. Guía de Uso Rápido

### Bootstrap de la app

```dart
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:nphotos/app/nphotos_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  AppAppearance.setAccentColor(NColors.photosAccent);
  runApp(const NPhotosApp());
}
```

### Consumo headless (servicio + controlador)

```dart
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:nphotos/models/photo.dart';

Future<void> ejemplo() async {
  final service = PhotoService();
  final List<Photo> photos = await service.loadPhotos();

  final controller = GalleryController(photoService: service);
  await controller.fetchPhotos();

  debugPrint('Total: ${controller.photos.length}');
  debugPrint('Favoritos: ${controller.favoritePhotos.length}');
  debugPrint('Álbumes: ${controller.albums.length}');

  await controller.toggleFavorite(photos.first.id);
  await controller.moveToTrash(photos.last.id);
}
```

### Embeber una pantalla en otro módulo Nexora

```dart
import 'package:flutter/material.dart';
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/screens/gallery/gallery_screen.dart';

class MiSeccion extends StatelessWidget {
  final GalleryController controller;
  const MiSeccion({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GalleryScreen(controller: controller);
  }
}
```

## 5. Desarrollo y Pruebas Locales

| Comando                         | Descripción                                                     |
| ------------------------------- | --------------------------------------------------------------- |
| `flutter pub get`               | Resuelve dependencias, incluye `nexora_ui` por `path`.          |
| `flutter analyze`               | Análisis estático (`flutter_lints`).                            |
| `flutter test`                  | Tests unitarios + widget (`gallery_controller`, `local_store`). |
| `flutter run -d linux`          | Ejecución desktop Linux.                                        |
| `flutter run -d chrome`         | Ejecución web.                                                  |
| `flutter run -d <device_id>`    | Ejecución Android/emulador (ver `flutter devices`).             |
| `flutter build linux --release` | Bundle release Linux.                                           |
| `flutter build apk --release`   | APK release Android.                                            |

```bash
# 1. Desde la raíz del subproyecto
cd nphotos
flutter pub get

# 2. Calidad
flutter analyze
flutter test

# 3. Desarrollo
flutter run -d linux
flutter run -d chrome

# 4. Si cambia NexoraUi, re-sincroniza
cd ../NexoraUi && flutter pub get
cd ../nphotos && flutter pub get
```

Requisitos previos:

- Flutter SDK stable (>= 3.19.0, probado en 3.47.x) + Dart `^3.13.4`.
- Checkout de `../NexoraUi` al mismo nivel del workspace.
- Android: SDK + `flutter doctor --android-licenses`.
- Linux: `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`.

## 6. Estándar de Contribución y Commits

Este módulo exige **Conventional Commits 1.0.0**:

```text
<tipo>[ámbito opcional]: <descripción en minúsculas e imperativo>

[cuerpo opcional]

[pie: BREAKING CHANGE / fixes #issue]
```

Tipos: `feat:`, `fix:`, `refactor:`, `perf:`, `style:`, `docs:`, `test:`, `build:`, `ci:`, `chore:`.

```bash
git commit -m "feat(gallery): grid responsivo con estados de permiso"
git commit -m "fix(android): manejo de permiso denegado permanente"
git commit -m "refactor(controller): cache de albums y favoritos"
git commit -m "docs: actualiza guia de build desktop"
git commit -m "test(controller): cubre papelera y persistencia"
```

> Regla: un commit, una responsabilidad lógica. Si el mensaje necesita «y», son dos commits. Todo PR debe pasar `flutter analyze` y `flutter test` en verde.

## Licencia

Proyecto privado del ecosistema **Nexora** (`publish_to: none`). Uso interno únicamente.

```

```
