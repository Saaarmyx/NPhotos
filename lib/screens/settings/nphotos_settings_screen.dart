// screens/settings/nphotos_settings_screen.dart
//
// Fuente única de datos de configuración de NPhotos.
//
// - [nPhotosProfileData] y [nPhotosAppInfo]: datos compartidos entre la ruta
//   móvil y el panel lateral de escritorio.
// - [NPhotosSettingsScreen]: ruta móvil a pantalla completa. Delegación total
//   al kit ([NSettingsScreen]) para que cualquier cambio en NexoraUi se
//   propague sin duplicar layout. El escritorio NO usa esta ruta: usa
//   `NSettingsSidePanel` como `trailingPanel` de `NDesktopLayout` (ver
//   `nphotos_app.dart`), igual que el showcase del kit.
//
// Nota release 26.09.28: sin secciones propias. Las que había (Nube,
// Organización inteligente, Explorar y compartir) eran botones muertos
// sin backend ni lógica; se eliminaron para producción. Volver a añadir
// solo con funcionalidad real detrás.
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

/// Datos de perfil compartidos (móvil + panel desktop).
const nPhotosProfileData = UserProfileData(
  name: 'Nexora Labs',
  email: 'nexora@ncloud.com',
  avatarUrl: '',
  storageUsedGb: 1.2,
  storageTotalGb: 256,
);

/// Info de app compartida (móvil + panel desktop).
/// Mantener sincronizada con `version:` de pubspec (esquema Nexora
/// AA.MM.DD-canal: 26.09.28-beta | 26.09.28-release | 26.09.28-debug).
const nPhotosAppInfo = NAboutAppInfo(
  appName: 'NPhotos',
  version: '26.09.28-release',
  buildNumber: '1',
);

/// Ruta móvil de ajustes: delegación directa al kit.
///
/// No incluye [ResponsiveLayout] a propósito: esta ruta solo se empuja en
/// móvil. En escritorio los ajustes viven en el panel lateral derecho.
class NPhotosSettingsScreen extends StatelessWidget {
  const NPhotosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // La sección "General" (Cuenta, Personalización, Acerca de) la aporta
    // el kit. Si NexoraUi cambia su base o su layout móvil, esta pantalla
    // lo hereda sin tocar NPhotos.
    return const NSettingsScreen(
      profileData: nPhotosProfileData,
      appInfo: nPhotosAppInfo,
    );
  }
}
