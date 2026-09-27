// screens/settings/nphotos_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class NPhotosSettingsScreen extends StatelessWidget {
  const NPhotosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Configuración de NPhotos'),
      body: ListView(
        padding: const EdgeInsets.all(NSpacing.spaceMd),
        children: [
          NSettingsGroupCard(
            title: 'Nube',
            items: [
              NSettingsItemData(
                title: 'Descargar fotos automáticamente',
                icon: Icons.cloud_download_outlined,
                trailingWidget: Switch(value: true, onChanged: (_) {}),
              ),
              NSettingsItemData(
                title: 'Álbumes a sincronizar',
                icon: Icons.photo_album_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: NSpacing.spaceMd),
          NSettingsGroupCard(
            title: 'Organización',
            items: [
              NSettingsItemData(
                title: 'Agrupar fotos en ráfaga',
                icon: Icons.burst_mode_outlined,
                onTap: () {},
              ),
              NSettingsItemData(
                title: 'Agrupar rostros similares',
                icon: Icons.face_retouching_natural_outlined,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: NSpacing.spaceMd),
          NSettingsOptionCard(
            icon: Icons.settings_outlined,
            title: 'Configuración general de Nexora',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NSettingsScreen(
                  profileData: UserProfileData(
                    name: 'Usuario',
                    email: 'usuario@nexora.dev',
                    avatarUrl: '',
                    storageUsedGb: 45.2,
                    storageTotalGb: 100,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
