# Nexora Photos

Aplicación de fotos Flutter + Rust (Linux y Android) con favoritos y álbumes.

## Arquitectura

```text
lib/                          UI Flutter
├── main.dart                 Entry point + navegación (Galería / Favoritos / Álbumes)
└── src/
    ├── core.dart             StoreController: envuelve la API de Rust, estado global
    ├── pages/                Galería, Favoritos, Álbumes, vista detalle
    ├── widgets/              Grid de miniaturas
    └── rust/                 Código generado por flutter_rust_bridge (¡no editar!)

rust/                         Core nativo en Rust (nexora_core)
└── src/api/mod.rs            PhotoStore: escaneo, EXIF/metadatos, álbumes, favoritos
    store.rs                  Persistencia JSON (favoritos + álbumes)
```

Flutter se conecta a Rust vía FFI con [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)
(package `nexora_core`, plugin `rust_builder` mediante cargokit). Rust es quien lee
el directorio, extrae dimensiones/EXIF y persiste el estado en
`nexora_core.json` (directorio de datos de la app).

## Requisitos

- Flutter (v3.47+)
- Rust toolchain (`rustup`)
- Para Android: Android SDK + `cargo-ndk` y targets `cargo install cargo-ndk`
  y `rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`

## Estado del proyecto

- ✅ Core Rust: escaneo recursivo, metadatos (dimensiones, fecha EXIF, tamaño),
  favoritos y álbumes persistentes (tests en `rust/`)
- ✅ UI Flutter: galería por carpeta, vista detalle swipe, favoritos, álbumes CRUD
- ✅ build + integration test en Linux desktop
- ⏳ Android: estructura lista (permiso `READ_MEDIA_IMAGES` añadido), falta el
  SDK para generar el APK; las rutas del escáner quedan limitadas por el
  `scoped storage` de Android (se puede ampliar con MediaStore o SAF)

## Desarrollo

```sh
# Regenerar bridge tras tocar rust/src/api:
flutter_rust_bridge_codegen generate

# Test del core Rust:
(cd rust && cargo test)

# Análisis statico:
flutter analyze

# App Linux:
flutter run -d linux

# Test de integración (FFI) en Linux:
flutter test integration_test/simple_test.dart -d linux

# APK Android (cuando haya SDK):
flutter build apk --debug
```