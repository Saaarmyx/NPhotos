// lib/screens/settings/nphotos_about_screen.dart
//
// "Sobre la app" de NPhotos: reutiliza el contenido del kit y le
// encaja la gestión de permisos del núcleo, igual que NFiles. La copia
// local de esa lógica ya no existe: vive en `NexoraCore`.
import 'package:flutter/material.dart';
import 'package:NexoraCore/NexoraCore.dart';
import 'package:NexoraUi/NexoraUi.dart';

import 'nphotos_permissions_screen.dart';
import 'nphotos_settings_screen.dart';

class NPhotosAboutScreen extends StatelessWidget {
  final CorePermissions permissions;

  const NPhotosAboutScreen({super.key, required this.permissions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Sobre la app'),
      body: NAboutContent(
        appInfo: nPhotosAppInfo,
        onPermissionsTap: () => pushNPage(
          context,
          NPhotosPermissionsScreen(permissions: permissions),
        ),
        onRevokePermissionsTap: () => confirmRevokeAllPermissions(context),
      ),
    );
  }
}
