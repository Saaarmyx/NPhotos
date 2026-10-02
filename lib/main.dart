import 'package:NexoraCore/NexoraCore.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/nphotos_app.dart';
import 'services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final store = await LocalStore.load();
  store.applyAppearance();

  // Un solo servicio de permisos para toda la app: lo comparten la
  // pantalla de móvil, el panel de escritorio y "Sobre la app", y así
  // un cambio hecho en un sitio se ve en los otros.
  final permissions = CorePermissions();
  await permissions.refresh();

  runApp(NPhotosApp(store: store, permissions: permissions));
}
