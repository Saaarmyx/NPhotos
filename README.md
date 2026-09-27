# NPhotos

> Galería inteligente del ecosistema Nexora — exploración, álbumes, favoritos, colecciones y papelera con diseño adaptativo móvil/desktop.

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-red)](./pubspec.yaml)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Desktop%20%7C%20Mobile-lightgrey)](https://flutter.dev/multi-platform)

---

## Propósito e Integración

**NPhotos** (`package:nphotos`, `v1.0.0+1`) es la **Galería oficial** del monocontenedor / suite `Nexora`.

Actúa como **aplicación final de usuario** dentro del ecosistema: consume el kit de UI `nexora_ui` por dependencia local (`path: ../NexoraUi`) y aporta el dominio multimedia, mientras el lenguaje visual, navegación y pantallas de sistema viven en el paquete compartido:

- `NAppShell` + `AppAppearance` (`NColors.photosAccent`) como raíz y tema reactivo.
- `NMobileLayout` / `NDesktopLayout` + `ResponsiveLayout` para navegación adaptativa.
- `NSettingsScreen`, cuenta, personalización y acerca de reutilizados del kit.
- NPhotos solo implementa galería, álbumes, favoritos, colecciones, visor y persistencia local (`shared_preferences`).

---

## Estructura del Proyecto

```text
nphotos/
├── lib/
│   ├── main.dart                     # Entrada: fija photosAccent y lanza NPhotosApp
│   ├── app/
│   │   └── nphotos_app.dart          # NAppShell + ResponsiveLayout + 4 destinos + sidebar desktop
│   ├── models/
│   │   ├── photo.dart                # Entidad inmutable Photo + copyWith
│   │   └── collection.dart           # CollectionKind (iconos, labels, detalle)
│   ├── controllers/
│   │   └── gallery_controller.dart   # ChangeNotifier: estado, favoritos, papelera, álbumes
│   ├── services/
│   │   ├── photo_service.dart        # Escaneo Android/Linux en isolate (compute)
│   │   └── local_store.dart          # Persistencia favoritos + papelera (shared_preferences)
│   ├── screens/
│   │   ├── gallery/
│   │   │   ├── gallery_screen.dart        # Grid responsivo + estados carga/error/vacío
│   │   │   └── photo_viewer_screen.dart   # Visor PageView + zoom + acciones
│   │   ├── albums/
│   │   │   └── albums_screen.dart         # Álbumes por carpeta + detalle interno
│   │   ├── favorites/
│   │   │   └── favorites_screen.dart      # Grid filtrado por isFavorite
│   │   ├── collections/
│   │   │   └── collections_screen.dart    # Colecciones + CollectionDetailScreen
│   │   └── settings/
│   │       └── nphotos_settings_screen.dart # Ajustes propios + enlace a settings globales
│   └── widgets/
│       ├── photo_grid.dart           # Grid reutilizable
│       └── photo_tile.dart           # Tile con Image.file + cache + error
├── test/
│   ├── gallery_controller_test.dart  # Lógica favoritos/papelera/álbumes
│   ├── local_store_test.dart         # Persistencia local
│   └── widget_test.dart              # Smoke test
├── android/ linux/ windows/ web/     # Runners nativos multi-plataforma
├── pubspec.yaml                      # Deps: nexora_ui (path), permission_handler, path, shared_preferences
├── analysis_options.yaml             # flutter_lints
└── README.md                         # (este archivo)
```

---

## Componentes / Funcionalidades Clave

- **Galería:** `GalleryScreen` + `PhotoGrid` / `PhotoTile` — cuadrícula responsiva (3 cols móvil / 5 cols desktop), `Image.file` con `cacheWidth`, estados de carga, error, vacío y permiso denegado.
- **Visor:** `PhotoViewerScreen` — `PageView` + `InteractiveViewer` (zoom 0.8x–4x), chrome de `nexora_ui` (`NViewerTopBar` / `NViewerBottomBar`), compartir, favorito, papelera.
- **Álbumes:** `AlbumsScreen` — agrupación por carpeta (`GalleryController.albums`), cover + contador, detalle con grid interno.
- **Favoritos:** `FavoritesScreen` — filtro reactivo `favoritePhotos`, toggle con persistencia, empty state ilustrado.
- **Colecciones:** `CollectionsScreen` + `CollectionDetailScreen` — destinos extra del sidebar desktop vía `CollectionKind`.
- **Navegación:** 4 destinos unificados `NNavigationDestination` (Fotos, Álbumes, Favoritos, Colecciones), `NMobileLayout` (bottom bar) + `NDesktopLayout` (sidebar con ancho auto-ajustado).
- **Estado central:** `GalleryController` (`GalleryState`: initial/loading/loaded/permissionDenied/error), `fetchPhotos()`, `toggleFavorite()`, `moveToTrash()` / `restoreFromTrash()` / `deletePermanently()` / `emptyTrash()`, cachés de derivados.
- **Servicios:** `PhotoService` — raíces Android (`DCIM`/`Pictures`/`Download`) y Linux (`Pictures`/`Downloads`/`Imágenes`), filtrado de ocultos y extensiones (`jpg/jpeg/png/webp/gif/heic`), escaneo en isolate con `compute`, orden por fecha desc; `LocalStore` — favoritos y papelera persistentes.
- **Tokens y átomos:** Reutilizados de `nexora_ui` — `NColors`, `NSpacing`, `NTypography`, `NBreakpoints`, `NButton`, `NCard`, `NEmptyState`, `NStateViews`, `ThemeAware`.

---

## Guía de Uso Rápido

### Lanzar la aplicación

```dart
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:nphotos/app/nphotos_app.dart';

void main() {
  AppAppearance.setAccentColor(NColors.photosAccent);
  runApp(const NPhotosApp());
}
```

### Consumir controlador, modelo y servicio de forma aislada

```dart
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:nphotos/models/photo.dart';

// 1. Carga directa del servicio (sin UI)
final service = PhotoService();
final List<Photo> photos = await service.loadPhotos();

// 2. Controlador reactivo (para widgets)
final controller = GalleryController(photoService: service);
await controller.fetchPhotos();

print('Total: ${controller.photos.length}');
print('Favoritos: ${controller.favoritePhotos.length}');
print('Álbumes: ${controller.albums.length}');

// 3. Acciones
await controller.toggleFavorite(photos.first.id);
await controller.moveToTrash(photos.last.id);
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

---

## Desarrollo y Pruebas Locales

| Comando | Descripción |
|---------|-------------|
| `flutter pub get` | Instala dependencias (incluye `nexora_ui` vía `path: ../NexoraUi`). |
| `flutter run -d linux` | Ejecuta en modo desarrollo en Linux (desktop). |
| `flutter run -d chrome` | Ejecuta en Web. |
| `flutter run -d <device_id>` | Ejecuta en móvil/emulador (`flutter devices`). |
| `flutter test` | Ejecuta tests (`gallery_controller_test`, `local_store_test`). |
| `flutter analyze` | Análisis estático con `flutter_lints`. |
| `flutter build linux --release` | Bundle release Linux (`build/linux/.../release/bundle/`). |
| `flutter build apk --release` | APK release Android (`build/app/outputs/flutter-apk/`). |

### Flujo recomendado

```bash
# 1. Desde la raíz del subproyecto
cd nphotos
flutter pub get

# 2. Verificar calidad
flutter analyze
flutter test

# 3. Desarrollo desktop
flutter run -d linux

# 4. Si cambiaste NexoraUi, re-sincroniza
cd ../NexoraUi && flutter pub get
cd ../nphotos && flutter pub get
flutter run -d linux
```

### Requisitos previos

- **Flutter SDK** >= 3.19.0 (probado en 3.47.5, canal stable).
- **Dart SDK** ^3.13.4 (incluido en Flutter).
- **NexoraUi** disponible en `../NexoraUi` (mismo nivel del workspace).
- **Android:** Android Studio + SDK + `flutter doctor --android-licenses` (permisos `photos` / `storage` vía `permission_handler`).
- **Linux:** `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`.
- Paquete privado (`publish_to: none`): no se publica en pub.dev.

---

## Escritura de Commits

Este subproyecto sigue estrictamente el estándar **Conventional Commits 1.0.0**:

```text
<tipo>[ámbito opcional]: <descripción corta en minúsculas>

[cuerpo opcional]

[pie opcional: BREAKING CHANGE / fixes #issue]
```

Tipos permitidos: `feat`, `fix`, `refactor`, `style`, `docs`, `test`, `chore`, `perf`, `build`, `ci`.

```bash
git commit -m "feat(gallery): implement real photo grid with FutureBuilder"
git commit -m "fix(android): handle runtime permission denial gracefully"
git commit -m "refactor(controller): extract album grouping to AlbumService"
git commit -m "docs: update README with desktop build instructions"
git commit -m "test(controller): cover trash and favorites persistence"
```

> Regla de oro: *un commit, una responsabilidad lógica.* Si el mensaje necesita «y», probablemente sean dos commits.

---

## Licencia

Proyecto privado del ecosistema **Nexora**. Uso interno únicamente.
