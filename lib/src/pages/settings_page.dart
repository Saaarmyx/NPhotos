import 'package:flutter/material.dart';

import '../core.dart';
import '../pages/secure_folder_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _managePin() async {
    final controller = await StoreController.instance();
    final pinSet = await controller.pinIsSet();
    if (!mounted) return;
    if (!pinSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configura el PIN desde la sección Carpeta segura'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SecureFolderPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Config')),
      body: ListView(
        children: [
          const _SectionHeader('Apariencia'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeMode,
            builder: (context, mode, _) => ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema'),
              subtitle: Wrap(
                spacing: 8,
                children: [
                  for (final (label, value) in const [
                    ('Claro', ThemeMode.light),
                    ('Oscuro', ThemeMode.dark),
                    ('Sistema', ThemeMode.system),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: mode == value,
                      onSelected: (_) => appThemeMode.value = value,
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('Seguridad'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Carpeta segura'),
            subtitle: const Text('Configurar o cambiar el PIN'),
            onTap: _managePin,
          ),
          const Divider(),
          const _SectionHeader('Almacenamiento'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Papelera'),
            subtitle: const Text('Gestionar elementos eliminados'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Puedes gestionar la papelera desde su sección'),
                ),
              );
            },
          ),
          const Divider(),
          const _SectionHeader('Acerca de'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Nexora Photos'),
            subtitle: Text('Flutter + Rust (flutter_rust_bridge)'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}