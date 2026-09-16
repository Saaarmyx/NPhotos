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
        Text(
          'Settings',
          style: NXText.sectionTitle(context),
        ),
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
                      color: mode == value ? palette.active : Colors.transparent,
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
            style: NXText.muted(context).copyWith(color: palette.textMuted, letterSpacing: 1.6),
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
                      style: NXText.muted(context).copyWith(color: palette.textBody),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: palette.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}