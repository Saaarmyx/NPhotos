import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
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
  List<MovedEntry> _items = const [];
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
    final pin = await showPinDialog(context, title: 'Desbloquear carpeta segura');
    if (!mounted) return;
    if (pin == null) return;
    final ok = await controller.verifyPin(pin);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrecto')),
      );
      return;
    }
    setState(() => _unlocked = true);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final controller = await StoreController.instance();
    final items = await controller.listSecure();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _setupPin() async {
    final first = await showPinDialog(context, title: 'Crear PIN');
    if (first == null || !mounted) return;
    final second = await showPinDialog(context, title: 'Repite el PIN');
    if (second == null || !mounted) return;
    if (first != second) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los PIN no coinciden')),
        );
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
    final current = await showPinDialog(context, title: 'PIN actual');
    if (current == null || !mounted) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto')),
        );
      }
      return;
    }
    if (!mounted) return;
    final next = await showPinDialog(context, title: 'Nuevo PIN');
    if (next == null || !mounted) return;
    await controller.setPin(next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado')),
      );
    }
  }

  Future<void> _clearPin() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final current = await showPinDialog(context, title: 'PIN actual');
    if (current == null) return;
    if (!await controller.verifyPin(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto')),
        );
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
    await controller.rescan();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored to your library')),
      );
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
            style: FilledButton.styleFrom(
              backgroundColor: NXColors.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteSecureItem(entry);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NXSpace.s20),
          child: SectionHeader(
            title: 'Secure Folder',
            subtitle: _pinSet == true && _unlocked
                ? '${_items.length} ${_items.length == 1 ? 'item' : 'items'} protected'
                : _pinSet == true
                    ? 'Locked with a PIN'
                    : 'Protect photos with a PIN',
            padding: const EdgeInsets.fromLTRB(
              NXSpace.s24,
              0,
              NXSpace.s24,
              NXSpace.s16,
            ),
            trailing: _pinSet == true
                ? PopupMenuButton<String>(
                    color: NexoraPalette.of(context).elevated,
                    surfaceTintColor: Colors.transparent,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      if (value == 'change') _changePin();
                      if (value == 'clear') _clearPin();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'change', child: Text('Cambiar PIN')),
                      PopupMenuItem(value: 'clear', child: Text('Desactivar PIN')),
                    ],
                  )
                : null,
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_pinSet == null) {
      return const NPhotosLoadingState();
    }
    if (_pinSet == false) {
      return NPhotosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Protect with a PIN',
        subtitle:
            'Move private photos here so only you (with your PIN) can see them.',
        actionLabel: 'Set up PIN',
        onAction: _setupPin,
      );
    }
    if (!_unlocked) {
      return NPhotosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Secure Folder locked',
        subtitle: 'Reopen the section and enter your PIN to unlock it.',
      );
    }
    if (_loading) {
      return const NPhotosLoadingState();
    }
    if (_items.isEmpty) {
      return NPhotosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Secure Folder is empty',
        subtitle: 'Move photos here from Photos using the context menu.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        NXSpace.s24,
        NXSpace.s4,
        NXSpace.s24,
        NXSpace.s32,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: NXSpace.s8),
      itemBuilder: (context, i) => TrashItemTile(
        entry: _items[i],
        onRestore: () => _restore(_items[i]),
        onDeletePermanent: () => _delete(_items[i]),
      ),
    );
  }
}