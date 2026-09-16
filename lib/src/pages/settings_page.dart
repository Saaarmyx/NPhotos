import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../core.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pinSet
              ? 'Manage your PIN from the Secure Folder section'
              : 'Set up your PIN from the Secure Folder section',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        NXSpace.s24,
        NXSpace.s20,
        NXSpace.s24,
        NXSpace.s32,
      ),
      children: [
        Text('Settings', style: NXText.sectionTitle(context)),
        const SizedBox(height: NXSpace.s4),
        Text(
          'Appearance, security and storage',
          style: NXText.metadata(context).copyWith(color: palette.textBody),
        ),
        const SizedBox(height: NXSpace.s24),
        _SettingsGroup(
          title: 'APPEARANCE',
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: appThemeMode,
              builder: (context, mode, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RowTitle(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'The NEXORA look for every mood',
                  ),
                  const SizedBox(height: NXSpace.s12),
                  _ThemePicker(mode: mode),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: NXSpace.s16),
        _SettingsGroup(
          title: 'SECURITY',
          children: [
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Secure Folder',
              subtitle: 'Set up or change your PIN from its section',
              onTap: _managePin,
            ),
          ],
        ),
        const SizedBox(height: NXSpace.s16),
        _SettingsGroup(title: 'LIBRARY', children: [const _HiddenPhotosTile()]),
        const SizedBox(height: NXSpace.s16),
        _SettingsGroup(
          title: 'ABOUT',
          children: const [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Nexora Photos',
              subtitle: 'Flutter + Rust (flutter_rust_bridge) · NEXORA',
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final options = const [
      (ThemeMode.light, 'Light'),
      (ThemeMode.dark, 'Dark'),
      (ThemeMode.system, 'System'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(NXRadius.radius12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => appThemeMode.value = value,
                  child: AnimatedContainer(
                    duration: NXTransition.base,
                    curve: NXTransition.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: NXSpace.s10),
                    decoration: BoxDecoration(
                      color: mode == value
                          ? palette.active
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(NXRadius.radius12),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: NXText.albumName(context).copyWith(
                        color: mode == value
                            ? NXColors.primary
                            : palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: NXSpace.s4, bottom: NXSpace.s8),
          child: Text(
            title,
            style: NXText.muted(context)
                .copyWith(color: palette.textMuted, letterSpacing: 1.6),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(NXRadius.radius16),
            border: Border.all(color: palette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: palette.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RowTitle extends StatelessWidget {
  const _RowTitle({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(NXSpace.s16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: NXColors.primary),
          const SizedBox(width: NXSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NXText.albumName(context)),
                if (subtitle != null) ...[
                  const SizedBox(height: NXSpace.s2),
                  Text(
                    subtitle!,
                    style: NXText.muted(context)
                        .copyWith(color: NexoraPalette.of(context).textBody),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenPhotosTile extends StatefulWidget {
  const _HiddenPhotosTile();

  @override
  State<_HiddenPhotosTile> createState() => _HiddenPhotosTileState();
}

class _HiddenPhotosTileState extends State<_HiddenPhotosTile> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<String>> _load() async {
    final controller = await StoreController.instance();
    return controller.hiddenPaths;
  }

  Future<void> _reveal(String path) async {
    final controller = await StoreController.instance();
    await controller.unhidePath(path);
    if (mounted) {
      setState(() => _future = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo restored to the library')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snapshot) {
        final paths = snapshot.data ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(NXSpace.s16),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 20,
                    color: NXColors.primary,
                  ),
                  const SizedBox(width: NXSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hidden Photos', style: NXText.albumName(context)),
                        const SizedBox(height: NXSpace.s2),
                        Text(
                          paths.isEmpty
                              ? 'Nothing hidden'
                              : '${paths.length} '
                                    '${paths.length == 1 ? 'item' : 'items'} '
                                    'hidden from the archive',
                          style: NXText.muted(context)
                              .copyWith(color: palette.textBody),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final path in paths) ...[
              Divider(height: 1, color: palette.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NXSpace.s16,
                  NXSpace.s4,
                  NXSpace.s8,
                  NXSpace.s4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        path.split(Platform.pathSeparator).isNotEmpty
                            ? path.split(Platform.pathSeparator).last
                            : path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NXText.muted(context)
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _reveal(path),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Show'),
                      style: TextButton.styleFrom(
                        foregroundColor: NXColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(NXSpace.s16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: NXColors.primary),
            const SizedBox(width: NXSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NXText.albumName(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: NXSpace.s2),
                    Text(
                      subtitle!,
                      style: NXText.muted(context)
                          .copyWith(color: palette.textBody),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
