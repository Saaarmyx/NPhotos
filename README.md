# NPhotos

> **App de galería inteligente** — Módulo de gestión, visualización y organización de fotos dentro del ecosistema **Nexora**.

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-red)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Desktop%20%7C%20Mobile%20%7C%20Web-lightgrey)](https://flutter.dev/multi-platform)

---

## Propósito e Integración

**NPhotos** es la aplicación de galería nativa del ecosistema **Nexora**. Su responsabilidad es proporcionar una experiencia fluida y moderna para la exploración, organización y gestión de fotografías y álbumes, integrándose de forma transparente con los servicios compartidos de Nexora (temas, navegación, ajustes, almacenamiento en la nube).

Dentro del monorepo `Nexora`, este subproyecto actúa como **aplicación final (end-user app)** que consume el sistema de diseño `NexoraUI` y expone funcionalidades específicas de multimedia:

- Visualización en cuadrícula y lista con soporte multi-plataforma.
- Gestión de álbumes automática basada en estructura de carpetas.
- Favoritos con persistencia en memoria.
- Configuración avanzada (sincronización cloud, agrupación inteligente, OCR, conversión HEIF).
- Preparado para futura sincronización cloud y escritorio (Linux/Windows/macOS).

---

## Estructura del Proyecto

```text
nphotos/
├── android/                    # Configuración nativa Android (Gradle, Manifest, Kotlin)
├── ios/                        # Configuración nativa iOS (Xcode, Swift)
├── linux/                      # Configuración nativa Linux (CMake, GTK)
├── macos/                      # Configuración nativa macOS (Xcode)
├── windows/                    # Configuración nativa Windows (CMake, MSVC)
├── web/                        # Configuración Web PWA (index.html, manifest, icons)
├── lib/
│   ├── main.dart               # Punto de entrada: inicializa tema/acento y lanza NPhotosApp
│   ├── app/
│   │   └── nphotos_app.dart    # App root: temas, navegación bottom-bar, pantallas, settings
│   ├── models/
│   │   └── photo.dart          # Modelo de dominio Photo con copyWith para inmutabilidad
│   ├── controllers/
│   │   └── gallery_controller.dart  # ChangeNotifier: estado, permisos, álbumes, favoritos
│   ├── services/
│   │   └── photo_service.dart  # Carga de fotos Android/Linux, filtrado, validación
│   └── screens/
│       ├── gallery/
│       │   ├── gallery_screen.dart      # GridView responsiva con estados (carga, error, vacío)
│       │   └── photo_viewer_screen.dart # PageView + InteractiveViewer + bottom bar acciones
│       ├── albums/
│       │   └── albums_screen.dart       # GridView de álbumes + detalle con grid interno
│       ├── favorites/
│       │   └── favorites_screen.dart    # GridView de favoritos con botón quitar favorito
│       └── settings/
│           └── nphotos_settings_screen.dart # Settings específicas + enlace a settings globales
├── test/
│   └── widget_test.dart        # Test de smoke (plantilla por defecto)
├── pubspec.yaml                # Dependencias: flutter, nexora_ui (local), permission_handler, path
├── analysis_options.yaml       # Lints compartidos (flutter_lints)
└── README.md                   # (este archivo)
```

> **Nota:** La arquitectura sigue el patrón **Feature-First** dentro de `lib/screens/`. Cada pantalla es un feature autocontenido que importa exclusivamente de `nexora_ui`, modelos y controladores locales.

---

## Componentes / Funcionalidades Clave

| Área | Descripción |
|------|-------------|
| **Galería (Grid)** | `GalleryScreen` — Cuadrícula responsiva (3 cols Android / 5 cols Desktop) con `Image.file`, cacheWidth 250, manejo de errores y tap a visor. |
| **Visor de Fotos** | `PhotoViewerScreen` — `PageView` + `InteractiveViewer` (zoom 0.8×–4×), AppBar translúcida, BottomAppBar con share/favorite/info. |
| **Álbumes (Lista/Grid)** | `AlbumsScreen` — Grid de álbumes con cover, nombre y contador; navegación a `_AlbumDetailScreen` con grid interno. |
| **Favoritos** | `FavoritesScreen` — Grid filtrado por `isFavorite`, empty state ilustrado, botón overlay para quitar favorito. |
| **Navegación Principal** | Bottom Navigation Bar con 3 destinos: Fotos, Álbumes, Favoritos (`NBottomBarItem` de `nexora_ui`). |
| **Temas & Apariencia** | `AppAppearance` (de `nexora_ui`) controla `accentColor` (`NColors.photosAccent`) y `ThemeMode` (light/dark) reactivos. |
| **Configuración Específica** | `NPhotosSettingsScreen`: nube (sync, descarga automática), organización (ráfagas, rostros), enlace a settings globales de Nexora. |
| **Settings Globales** | `NSettingsScreen` (de `nexora_ui`) con perfil, info de app (`NAboutAppInfo`), grupos adicionales: *Organización inteligente* y *Explorar y compartir*. |
| **Modelo de Datos** | `Photo` (en `lib/models/photo.dart`) — id, path, thumbnailPath, title, fechas, tamaño, isFavorite, dimensiones. |
| **Controlador Central** | `GalleryController` (ChangeNotifier): estado de carga, permisos Android, `fetchPhotos()`, `toggleFavorite()`, getters `photos`, `favoritePhotos`, `albums`. |
| **Servicio de Carga** | `PhotoService`: multi-plataforma (Android/DCIM+Pictures+Download, Linux/Pictures+Downloads+Imágenes), filtrado ocultos, extensiones soportadas, orden por fecha desc. |
| **Desktop (Pausado)** | Código comentado en `nphotos_app.dart` para `ResponsiveLayout` + `NDesktopLayout` (sidebar). |

---

## Guía de Uso Rápido

### Como aplicación standalone

```bash
cd nphotos
flutter pub get
flutter run -d linux   # o -d macos / -d windows / -d chrome / -d android / -d ios
```

### Importando pantallas en otro módulo Nexora

```dart
import 'package:nphotos/screens/gallery/gallery_screen.dart';
import 'package:nphotos/screens/albums/albums_screen.dart';
import 'package:nphotos/screens/favorites/favorites_screen.dart';
import 'package:nphotos/app/nphotos_app.dart'; // Para lanzar la app completa
import 'package:nphotos/controllers/gallery_controller.dart';

// Uso directo de una pantalla dentro de un Navigator propio:
final controller = GalleryController();
await controller.fetchPhotos();

Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => GalleryScreen(controller: controller)),
);
```

### Inicialización manual del tema (si se usa fuera de `main.dart`)

```dart
import 'package:nexora_ui/nexora_ui.dart';

void initializeNPhotosTheme() {
  AppAppearance.setAccentColor(NColors.photosAccent);
  // Opcional: forzar tema
  // AppAppearance.themeMode.value = ThemeMode.dark;
}
```

### Uso del modelo y servicio de forma aislada

```dart
import 'package:nphotos/models/photo.dart';
import 'package:nphotos/services/photo_service.dart';

final service = PhotoService();
final photos = await service.loadPhotos();

for (final photo in photos) {
  print('${photo.title} - ${photo.dateModified} - ${photo.sizeInBytes} bytes');
  final favorite = photo.copyWith(isFavorite: true);
}
```

---

## Desarrollo y Pruebas Locales

| Comando | Descripción |
|---------|-------------|
| `flutter pub get` | Instala dependencias (incluye `nexora_ui` vía `path: ../NexoraUi`). |
| `flutter run -d linux` | Ejecuta en modo debug en Linux (desktop). |
| `flutter run -d macos` | Ejecuta en macOS (requiere Xcode). |
| `flutter run -d windows` | Ejecuta en Windows (requiere Visual Studio + CMake). |
| `flutter run -d chrome` | Ejecuta en navegador (Web/PWA). |
| `flutter run -d <device_id>` | Ejecuta en dispositivo/emulador móvil conectado (`flutter devices`). |
| `flutter test` | Ejecuta tests unitarios/widget (`test/widget_test.dart`). |
| `flutter analyze` | Análisis estático con lints de `flutter_lints`. |
| `flutter build linux --release` | Build de release para Linux (ejecutable en `build/linux/.../release/bundle/`). |
| `flutter build macos --release` | Build de release para macOS (bundle .app). |
| `flutter build windows --release` | Build de release para Windows (ejecutable .exe en `build/windows/.../runner/Release/`). |
| `flutter build apk --release` | Genera APK de release Android (`build/app/outputs/flutter-apk/`). |
| `flutter build appbundle --release` | Genera AAB para Play Store. |
| `flutter build ios --release` | Genera build iOS (requiere Xcode, produce .ipa). |
| `flutter build web --release` | Genera build web estático en `build/web/`. |

### Requisitos previos

- **Flutter SDK** ≥ 3.24 (canal stable).
- **Dart SDK** ≥ 3.5 (incluido en Flutter).
- **NexoraUi** disponible localmente en `../NexoraUi` (mismo nivel de directorio).
- **Android**: Android Studio + SDK + `flutter doctor --android-licenses`.
- **iOS/macOS**: Xcode 15+ + CocoaPods (`sudo gem install cocoapods`).
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libblkid-dev`.
- **Windows**: Visual Studio 2022 + "Desktop development with C++" + CMake.
- **Web**: Chrome/Edge instalado.

### Variables de entorno útiles (Linux)

```bash
export FLUTTER_GPU_THREAD_PRIORITY=high  # Prioridad hilo GPU (opcional)
export ENABLE_FLUTTER_DESKTOP=true       # Habilitado por defecto en Flutter 3.x
```

---

## Escritura de Commits

Este proyecto sigue **Conventional Commits 1.0.0**. Cada commit debe estructurarse así:

```text
<tipo>[ámbito opcional]: <descripción corta en minúsculas>

[cuerpo opcional]

[pie opcional: BREAKING CHANGE / fixes #issue]
```

### Tipos permitidos

| Tipo | Cuándo usarlo |
|------|---------------|
| `feat` | Nueva funcionalidad (pantalla, setting, modelo, servicio). |
| `fix` | Corrección de bug (permiso, carga, render). |
| `refactor` | Reestructuración sin cambio de comportamiento. |
| `style` | Formato, imports, lint fixes. |
| `docs` | Cambios en README, comentarios de código, docstrings. |
| `test` | Añadir/modificar tests unitarios/widget/integration. |
| `chore` | Mantenimiento: deps, scripts, CI, assets. |
| `perf` | Mejora de rendimiento (cache, lazy load, isolate). |
| `build` | Cambios en sistema de build (CMake, Gradle, pubspec). |
| `ci` | Cambios en pipelines CI/CD. |

### Ejemplos

```bash
git commit -m "feat(gallery): implement real photo grid with FutureBuilder"
git commit -m "fix(android): handle runtime permission denial gracefully"
git commit -m "refactor(controller): extract album grouping to AlbumService"
git commit -m "docs: update README with desktop build instructions"
git commit -m "chore(deps): upgrade nexora_ui to latest local changes"
git commit -m "perf(photo_service): add thumbnail caching via isolate"
git commit -m "test(gallery): add golden test for empty state"
```

> **Regla de oro:** *Un commit, una responsabilidad lógica.* Si el mensaje necesita «y», probablemente sean dos commits.

---

## Licencia

Proyecto privado del ecosistema **Nexora**. Uso interno únicamente.