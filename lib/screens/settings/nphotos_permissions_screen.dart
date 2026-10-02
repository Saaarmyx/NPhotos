// lib/screens/settings/nphotos_permissions_screen.dart
//
// Gestión de permisos de NPhotos.
//
// La lógica (estado, solicitud, revocado, revocar-todo) vive en
// `NexoraCore`: estaba duplicada en NPhotos y NFiles y ahora hay una sola
// implementación para las dos apps. Aquí solo se monta la pantalla.
import 'package:flutter/material.dart';
import 'package:NexoraCore/NexoraCore.dart';
import 'package:NexoraUi/NexoraUi.dart';

/// Pantalla completa de permisos.
///
/// [permissions] lo inyecta la app (lo crea `main()` y lo comparte con la
/// ruta de escritorio) para que la pantalla no tenga que abrir un canal
/// nuevo con el servicio: el mismo objeto que ya está escuchando la UI.
class NPhotosPermissionsScreen extends StatelessWidget {
  final CorePermissions permissions;

  const NPhotosPermissionsScreen({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Gestión de permisos'),
      body: CorePermissionsContent(permissions: permissions),
    );
  }
}
