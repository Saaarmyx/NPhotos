// lib/screens/settings/nphotos_about_screen.dart
//
// "Sobre la app" de NPhotos: reutiliza el contenido del kit pero con
// callbacks funcionales (permisos reales y revocado vía ajustes).
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import 'nphotos_permissions.dart';
import 'nphotos_settings_screen.dart';

class NPhotosAboutScreen extends StatelessWidget {
  const NPhotosAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Sobre la app'),
      body: NAboutContent(
        appInfo: nPhotosAppInfo,
        onPermissionsTap: () => pushNPage(
          context,
          const NPhotosPermissionsScreen(),
        ),
        onRevokePermissionsTap: () => confirmRevokeAllPermissions(context),
      ),
    );
  }
}
