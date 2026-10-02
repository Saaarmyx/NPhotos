// test/permisos_test_helper.dart
//
// Servicio de permisos para tests.
//
// `CorePermissions()` sin argumentos mira `Platform.isAndroid`, así que en
// Linux (donde corren los tests) siempre cae en `systemManaged` y no deja
// ejercitar la máquina de estados. Se fuerza `hasRuntimePermissions` a
// `false` para que la UI de permisos se pueda montar y comprobar sin
// sistema detrás.
import 'package:NexoraCore/NexoraCore.dart';

/// Servicio listo para usar en un test.
CorePermissions testPermissions() =>
    CorePermissions(hasRuntimePermissions: false);
