import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_button.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/trash_item_tile.dart';

class SecureFolderPage extends StatefulWidget {
  const SecureFolderPage({super.key});

  @override
  State<SecureFolderPage> createState() => _SecureFolderPageState();
}

class _SecureFolderPageState extends State<SecureFolderPage>
    with AutomaticKeepAliveClientMixin {
  bool? _pinSet;
  bool _unlocked = false;
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = await StoreController.instance();
    final pinSet = await controller.pinIsSet();
    if (!mounted) return;
    setState(() => _pinSet = pinSet);
    if (!pinSet) return;
    final pin = await showPinDialog(context, title: 'Unlock Secure Folder');
    if (!mounted || pin == null) return;
    final ok = await controller.verifyPin(pin);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      return;
    }
    setState(() => _unlocked = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = await StoreController.instance();
    await controller.refreshSecure();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setupPin() async {
    final first = await showPinDialog(context, title: 'Create PIN');
    if (first == null || !mounted) return;
    final second = await showPinDialog(context, title: 'Repeat the PIN');
    if (second == null || !mounted) return;
    if (first != second) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pins do not match')));
      }
      return;
    }
    final controller = await StoreController.instance();
    await controller.setPin(first);
    if (mounted) {
      setState(() {
        _pinSet = true;
        _unlocked = true;
      });
      await _load();
    }
  }

  Future<void> _changePin() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final current = await showPinDialog(context, title: 'Current PIN');
    if (current == null || !mounted) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    if (!mounted) return;
    final next = await showPinDialog(context, title: 'New PIN');
    if (next == null || !mounted) return;
    await controller.setPin(next);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN updated')));
    }
  }

  Future<void> _clearPin() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final current = await showPinDialog(context, title: 'Current PIN');
    if (current == null) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    await controller.clearPin();
    if (mounted) {
      setState(() {
        _pinSet = false;
        _unlocked = true;
      });
    }
  }

  Future<void> _restore(MovedEntry entry) async {
    final controller = await StoreController.instance();
    await controller.restoreSecure(entry);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restored to your library')));
    }
  }

  Future<void> _delete(MovedEntry entry) async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from Secure Folder'),
        content: Text('Delete "${entry.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NXColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteSecureItem(entry);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_pinSet == null) {
      return const NPhotosLoadingState();
    }
    if (_pinSet == false) {
      return NPhotosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Protect with a PIN',
        subtitle: 'Move private photos here so only you (with your PIN) can see them.',
        actionLabel: 'Set up PIN',
        onAction: _setupPin,
      );
    }
    if (!_unlocked) {
      return NPhotosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Secure Folder locked',
        subtitle: 'Tap Unlock and enter your PIN to see your protected photos.',
        actionLabel: 'Unlock',
        onAction: _bootstrap,
      );
    }
    return FutureBuilder<StoreController>(
      future: StoreController.instance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const NPhotosLoadingState();
        }
        final controller = snapshot.data!;
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (_loading && controller.secureItems.isEmpty) {
              return const NPhotosLoadingState();
            }
            final items = controller.secureItems;
            if (items.isEmpty) {
              return NPhotosEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Secure Folder is empty',
                subtitle:
                    'Move photos here from Photos using the context menu.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NXSpace.s24,
                    NXSpace.s12,
                    NXSpace.s24,
                    NXSpace.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NPhotosButton.ghost(
                        label: 'Change PIN',
                        icon: Icons.password_rounded,
                        onPressed: _changePin,
                      ),
                      const SizedBox(width: NXSpace.s8),
                      NPhotosButton.secondary(
                        label: 'Disable PIN',
                        icon: Icons.lock_open_outlined,
                        onPressed: _clearPin,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      NXSpace.s24,
                      NXSpace.s4,
                      NXSpace.s24,
                      NXSpace.s32,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: NXSpace.s8),
                    itemBuilder: (context, i) => TrashItemTile(
                      entry: items[i],
                      onRestore: () => _restore(items[i]),
                      onDeletePermanent: () => _delete(items[i]),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
