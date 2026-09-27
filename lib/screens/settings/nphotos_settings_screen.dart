// screens/settings/nphotos_settings_screen.dart
//
// Fuente única de configuración de NPhotos.
//
// - Las secciones propias viven en [_photoSections]: añadir configuración
//   nueva es añadir una entrada a esa lista.
// - El renderizado es del kit en ambas ramas: móvil con [NSettingsScreen]
//   (página completa) y desktop con [NSettingsContent] centrado. La sección
//   base "General" (Cuenta, Personalización, Acerca de) la aporta el kit en
//   las dos ramas vía [NSettingsScreen.resolveSections].
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

/// Ancho máximo del contenido de ajustes en desktop.
const _kDesktopMaxWidth = 720.0;

class NPhotosSettingsScreen extends StatefulWidget {
  const NPhotosSettingsScreen({super.key});

  @override
  State<NPhotosSettingsScreen> createState() => _NPhotosSettingsScreenState();
}

class _NPhotosSettingsScreenState extends State<NPhotosSettingsScreen> {
  static const _profileData = UserProfileData(
    name: 'Nexora Labs',
    email: 'nexora@ncloud.com',
    avatarUrl: '',
    storageUsedGb: 1.2,
    storageTotalGb: 256,
  );

  static const _appInfo = NAboutAppInfo(
    appName: 'NPhotos',
    version: '0.1.0',
    buildNumber: '1',
  );

  bool _autoDownload = true;

  /// Secciones propias de NPhotos. Punto único de extensión: para añadir
  /// más configuración, añadir aquí un [NSettingsSection] o un item.
  List<NSettingsSection> get _photoSections => [
    NSettingsSection(
      title: 'Nube',
      items: [
        NSwitchItem(
          icon: Icons.cloud_download_outlined,
          title: 'Descargar fotos automáticamente',
          subtitle: 'Guarda una copia local de tus fotos de la nube',
          value: _autoDownload,
          onChanged: (value) => setState(() => _autoDownload = value),
        ),
        NNavigationItem.standard(
          icon: Icons.photo_album_outlined,
          title: 'Álbumes a sincronizar',
          // TODO: navegar a la selección de álbumes sincronizados.
          onTap: () {},
        ),
      ],
    ),
    NSettingsSection(
      title: 'Organización inteligente',
      items: [
        NNavigationItem.standard(
          icon: Icons.auto_awesome_outlined,
          title: 'Seleccionar mejor foto',
          // TODO: implementar selección de mejor foto.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.face_retouching_natural_outlined,
          title: 'Agrupar rostros similares',
          // TODO: implementar agrupación de rostros.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.burst_mode_outlined,
          title: 'Agrupar fotos en ráfaga',
          // TODO: implementar agrupación en ráfaga.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.calendar_today_outlined,
          title: 'Un día como hoy',
          // TODO: implementar vista "Un día como hoy".
          onTap: _noop,
        ),
      ],
    ),
    NSettingsSection(
      title: 'Explorar y compartir',
      items: [
        NNavigationItem.standard(
          icon: Icons.visibility_off_outlined,
          title: 'Ver álbumes ocultos',
          // TODO: implementar álbumes ocultos.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.text_fields_outlined,
          title: 'Reconocer texto en imágenes',
          // TODO: implementar OCR.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.transform_outlined,
          title: 'Convertir HEIF antes de enviar',
          // TODO: implementar conversión HEIF.
          onTap: _noop,
        ),
        NNavigationItem.standard(
          icon: Icons.share_outlined,
          title: 'Compartir de forma segura',
          // TODO: implementar compartir seguro.
          onTap: _noop,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Shell compartido: garantiza que móvil y desktop resuelvan las mismas
    // secciones (propias + base "General" del kit).
    final shell = NSettingsScreen(
      profileData: _profileData,
      appInfo: _appInfo,
      additionalSections: _photoSections,
    );

    return ResponsiveLayout(
      mobileLayout: shell,
      desktopLayout: Builder(
        builder: (context) => Scaffold(
          appBar: const NSecondaryTopBar(title: 'Configuración'),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kDesktopMaxWidth),
              child: NSettingsContent(
                profileData: _profileData,
                sections: shell.resolveSections(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}
